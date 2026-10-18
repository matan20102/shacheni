-- Account editing and reversible building lifecycle. No existing building is archived.
alter table public.community_settings add column archived_at timestamptz;

create function app.ba_update_profile(p_name text, p_phone text) returns void
language plpgsql volatile security definer set search_path = '' as $$
declare u uuid := app.require_user(); phone text;
begin
  perform app.require_terms();
  if coalesce(char_length(btrim(p_name)), 0) not between 2 and 100 then raise exception 'INVALID_ARGUMENT'; end if;
  if nullif(btrim(p_phone), '') is not null then
    phone := app.normalize_il_mobile(p_phone);
    if phone is null then raise exception 'PHONE_INVALID'; end if;
  end if;
  update public.profile set full_name = btrim(p_name), phone_e164 = phone where id = u;
  if not found then raise exception 'ACCESS_DENIED'; end if;
  perform app.audit(null, 'community.profile_updated', 'profile', u);
exception when unique_violation then raise exception 'PHONE_TAKEN';
end $$;

create function app.ba_leave(p_building uuid) returns void
language plpgsql volatile security definer set search_path = '' as $$
declare u uuid := app.require_user(); m public.community_member; active boolean; successor uuid;
begin
  perform app.require_terms();
  -- Serialize leaving, joining, approving and archiving in the same order.
  select status = 'active' into active from public.building where id = p_building for update;
  select * into m from public.community_member
    where building_id = p_building and user_id = u and status = 'approved' for update;
  if not found then raise exception 'ACCESS_DENIED'; end if;
  if active and m.is_building_admin and not exists(select 1 from public.community_member
    where building_id = p_building and status = 'approved' and is_building_admin and id <> m.id)
    then raise exception 'LAST_BUILDING_ADMIN'; end if;
  perform 1 from public.apartment where id = m.apartment_id for update;
  update public.community_member set status = 'withdrawn', is_building_admin = false,
    is_committee = false, is_apartment_admin = false, updated_at = now() where id = m.id;
  if m.is_apartment_admin then
    select id into successor from public.community_member
      where apartment_id = m.apartment_id and status = 'approved' order by created_at, id limit 1;
    if successor is not null then
      update public.community_member set is_apartment_admin = true, updated_at = now() where id = successor;
      perform app.audit(p_building, 'community.apartment_admin_succession', 'community_member', successor);
    else
      -- The old household no longer has an approver. Ask the building manager
      -- to review pending applicants again under the new-apartment rule.
      update public.community_member set requires_apartment_approval = false,
        building_approved = false, apartment_approved = false,
        building_approved_by = null, apartment_approved_by = null, updated_at = now()
        where apartment_id = m.apartment_id and status = 'pending';
    end if;
  end if;
  perform app.audit(p_building, 'community.leave', 'community_member', m.id);
end $$;

create function app.ba_archive(p_building uuid) returns void
language plpgsql volatile security definer set search_path = '' as $$
begin
  perform app.require_user(); perform app.require_terms();
  perform 1 from public.building where id = p_building and status = 'active' for update;
  if not found or not app.ba_admin(p_building) then raise exception 'ACCESS_DENIED'; end if;
  update public.community_settings set archived_at = now() where building_id = p_building;
  update public.building set status = 'suspended' where id = p_building;
  perform app.audit(p_building, 'community.archive', 'building', p_building);
end $$;

create function public.ba_update_profile(p_name text, p_phone text) returns void
language sql volatile security invoker set search_path = '' as $$ select app.ba_update_profile(p_name, p_phone) $$;
create function public.ba_leave(p_building uuid) returns void
language sql volatile security invoker set search_path = '' as $$ select app.ba_leave(p_building) $$;
create function public.ba_archive(p_building uuid) returns void
language sql volatile security invoker set search_path = '' as $$ select app.ba_archive(p_building) $$;
revoke all on function app.ba_update_profile(text, text), public.ba_update_profile(text, text),
  app.ba_leave(uuid), public.ba_leave(uuid), app.ba_archive(uuid), public.ba_archive(uuid) from public, anon, authenticated;
grant execute on function app.ba_update_profile(text, text), public.ba_update_profile(text, text),
  app.ba_leave(uuid), public.ba_leave(uuid), app.ba_archive(uuid), public.ba_archive(uuid) to authenticated;

-- Only an actual acceptance is an unread update for the applicant.
-- Incoming requests remain actionable for their building/apartment managers.
create or replace function app.ba_state() returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare u uuid := app.require_user();
begin
  perform app.require_terms();
  return jsonb_build_object(
    'profile', (select jsonb_build_object('full_name', p.full_name, 'phone', coalesce(p.phone_e164, ''), 'email', coalesce(a.email, ''))
      from public.profile p join auth.users a on a.id = p.id where p.id = u),
    'homes', coalesce((select jsonb_agg(jsonb_build_object(
      'id', b.id, 'name', b.name, 'address', b.address, 'apartment', coalesce(d.number, a.number), 'entrance', coalesce(nullif(d.entrance, ''), m.entrance), 'household_name', coalesce(h.display_name, ''),
      'entrances', coalesce(s.entrance_count, 1), 'code', case when m.is_building_admin then b.join_code else '' end,
      'is_admin', m.is_building_admin, 'is_committee', m.is_committee, 'is_apartment_admin', m.is_apartment_admin)
      order by m.created_at) from public.community_member m join public.building b on b.id = m.building_id
      join public.apartment a on a.id = m.apartment_id left join public.community_settings s on s.building_id = b.id
      left join public.community_household h on h.apartment_id = a.id
      left join public.community_apartment d on d.apartment_id = a.id
      where m.user_id = u and m.status = 'approved' and b.status = 'active'), '[]'),
    'approval_updates', coalesce((select jsonb_agg(jsonb_build_object(
      'id', x.id, 'building_id', x.building_id, 'building_name', x.building_name) order by x.created_at desc, x.id)
      from (select n.id, n.building_id, b.name building_name, n.created_at
        from public.notification n join public.building b on b.id = n.building_id
        join public.community_member m on m.id = n.entity_id and m.building_id = b.id
        where n.user_id = u and m.user_id = u and m.status = 'approved' and b.status = 'active'
          and n.type = 'community.application_approved' and n.read_at is null
        order by n.created_at desc, n.id limit 100) x), '[]'),
    'applications', coalesce((select jsonb_agg(jsonb_build_object(
      'id', m.id, 'building_id', b.id, 'building_name', b.name, 'building_address', b.address,
      'apartment', coalesce(d.number, a.number), 'floor', m.floor, 'entrance', m.entrance,
      'apartment_has_admin', m.requires_apartment_approval,
      'building_approved', m.building_approved, 'apartment_approved', m.apartment_approved,
      'mine', m.user_id = u, 'applicant_name', p.full_name,
      'can_approve_building', app.ba_admin(m.building_id),
      'can_approve_apartment', app.ba_apartment_admin(m.apartment_id)) order by m.created_at)
      from public.community_member m join public.building b on b.id = m.building_id
      join public.apartment a on a.id = m.apartment_id left join public.community_apartment d on d.apartment_id = a.id
      join public.profile p on p.id = m.user_id
      where m.status = 'pending' and b.status = 'active' and
        (m.user_id = u or app.ba_admin(m.building_id) or app.ba_apartment_admin(m.apartment_id))), '[]'));
end $$;

-- Re-check active state after acquiring the archive/join lock.
create or replace function app.ba_submit_home(p_code text, p_apartment text, p_floor text, p_entrance text, p_household_name text) returns uuid
language plpgsql volatile security definer set search_path = '' as $$
declare u uuid := app.require_user(); b uuid; a uuid; m uuid; old_status text; needs_admin boolean;
  n text := app.ba_normalize_apartment(p_apartment); e text := btrim(coalesce(p_entrance, '')); requested_name text;
begin
  perform app.require_terms();
  if coalesce(char_length(n), 0) not between 1 and 20 or char_length(e) > 20
    or coalesce(char_length(p_floor), 0) > 20 or char_length(btrim(coalesce(p_household_name, ''))) > 60 then raise exception 'INVALID_ARGUMENT'; end if;
  b := (app.ba_resolve(p_code)->>'id')::uuid;
  if b is null then return null; end if;
  perform 1 from public.building where id = b and status = 'active' for update;
  if not found then raise exception 'ACCESS_DENIED'; end if;
  select id, status into m, old_status from public.community_member where building_id = b and user_id = u for update;
  if old_status in ('pending', 'approved') then raise exception 'ALREADY_APPLIED'; end if;
  select d.apartment_id into a from public.community_apartment d where d.building_id = b and d.number = n;
  if a is null then
    -- Adopt old apartments that have not entered the directory, without moving an existing entrance.
    select ap.id into a from public.apartment ap where ap.building_id = b and ap.number = n
        and not exists(select 1 from public.community_apartment d where d.apartment_id = ap.id);
    if a is null then
      -- Legacy number remains unique per building; the directory is the visible identity.
      insert into public.apartment(building_id, number)
        values(b, case when exists(select 1 from public.apartment where building_id = b and number = n)
          then '@' || substr(replace(gen_random_uuid()::text, '-', ''), 1, 19) else n end) returning id into a;
    end if;
    insert into public.community_apartment(apartment_id, building_id, number, entrance) values(a, b, n, e);
  end if;
  select coalesce(nullif(d.entrance, ''), e) into e from public.community_apartment d where d.apartment_id = a;
  perform 1 from public.apartment where id = a for update;
  needs_admin := exists(select 1 from public.community_member where apartment_id = a and status = 'approved' and is_apartment_admin);
  requested_name := case when exists(select 1 from public.community_member where apartment_id = a and status = 'approved')
    then null else nullif(btrim(p_household_name), '') end;
  insert into public.community_member(building_id, apartment_id, user_id, floor, entrance, requires_apartment_approval, requested_household_name)
    values(b, a, u, nullif(btrim(p_floor), ''), nullif(e, ''), needs_admin, requested_name)
    on conflict (building_id, user_id) do update set apartment_id = excluded.apartment_id, status = 'pending',
      floor = excluded.floor, entrance = excluded.entrance, requires_apartment_approval = excluded.requires_apartment_approval,
      requested_household_name = excluded.requested_household_name,
      building_approved = false, apartment_approved = false, building_approved_by = null, apartment_approved_by = null, updated_at = now()
    returning id into m;
  perform app.notify(cm.user_id, b, 'community.application_received', jsonb_build_object('apartment', n, 'entrance', nullif(e, '')), '/home', m)
    from public.community_member cm where cm.building_id = b and cm.status = 'approved'
      and (cm.is_building_admin or (cm.apartment_id = a and cm.is_apartment_admin));
  perform app.audit(b, 'community.join', 'community_member', m);
  return m;
end $$;
