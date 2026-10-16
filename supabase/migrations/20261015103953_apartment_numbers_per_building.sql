-- Follow-up clarification: numbering is unique across the building, not per entrance.
-- Only the disposable CHECK fixture had duplicate demo numbers; real homes are untouched.
update public.community_apartment d set number = '24'
where d.number = '12' and d.entrance = 'ב' and exists(select 1 from public.building b
  where b.id = d.building_id and b.settings->>'community_test_fixture' = 'join-check');
update public.apartment a set number = d.number from public.community_apartment d, public.building b
where a.id = d.apartment_id and b.id = d.building_id and d.number = '24'
  and b.settings->>'community_test_fixture' = 'join-check';
update public.community_settings s set entrance_count = 5 from public.building b
where b.id = s.building_id and b.settings->>'community_test_fixture' = 'join-check';
alter table public.community_apartment drop constraint community_apartment_building_id_number_entrance_key;
alter table public.community_apartment add constraint community_apartment_building_number_key unique(building_id, number);

create or replace function app.ba_apartment_status(p_code text, p_apartment text, p_entrance text) returns jsonb
language plpgsql volatile security definer set search_path = '' as $$
declare b uuid; a uuid; n text := app.ba_normalize_apartment(p_apartment); e text := btrim(coalesce(p_entrance, ''));
begin
  perform app.require_user(); perform app.require_terms();
  if n is null or n !~ '^[0-9]{1,20}$' or char_length(e) > 20 then raise exception 'INVALID_ARGUMENT'; end if;
  b := (app.ba_resolve(p_code)->>'id')::uuid;
  if b is null then return null; end if;
  select d.apartment_id into a from public.community_apartment d
    where d.building_id = b and d.number = n;
  if a is null then
    select ap.id into a from public.apartment ap where ap.building_id = b and ap.number = n
      and not exists(select 1 from public.community_apartment d where d.apartment_id = ap.id);
  end if;
  return jsonb_build_object(
    'exists', exists(select 1 from public.community_member m where m.apartment_id = a and m.status = 'approved'),
    'has_admin', exists(select 1 from public.community_member m where m.apartment_id = a and m.status = 'approved' and m.is_apartment_admin));
end $$;

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
  perform 1 from public.building where id = b for update;
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


create or replace function app.ba_approve(p_member uuid, p_role text) returns void
language plpgsql volatile security definer set search_path = '' as $$
declare u uuid := app.require_user(); b uuid; m public.community_member; needs_admin boolean; complete boolean;
begin
  perform app.require_terms();
  select building_id into b from public.community_member where id = p_member;
  if b is null then raise exception 'ACCESS_DENIED'; end if;
  perform 1 from public.building where id = b and status = 'active' for update;
  if not found then raise exception 'ACCESS_DENIED'; end if;
  select * into m from public.community_member where id = p_member for update;
  perform 1 from public.apartment where id = m.apartment_id for update;
  if p_role = 'building' then
    if not app.ba_admin(b) then raise exception 'ACCESS_DENIED'; end if;
  elsif p_role = 'apartment' then
    if not app.ba_apartment_admin(m.apartment_id) then raise exception 'ACCESS_DENIED'; end if;
  else raise exception 'INVALID_ARGUMENT'; end if;
  if m.status <> 'pending' then raise exception 'INVALID_STATE'; end if;
  -- Re-check at approval time: two requests for a new apartment cannot both become its first admin.
  needs_admin := exists(select 1 from public.community_member where apartment_id = m.apartment_id and status = 'approved' and is_apartment_admin);
  m.building_approved := m.building_approved or p_role = 'building';
  m.apartment_approved := m.apartment_approved or p_role = 'apartment';
  complete := m.building_approved and (not needs_admin or m.apartment_approved);
  update public.community_member set building_approved = m.building_approved, apartment_approved = m.apartment_approved,
    building_approved_by = case when p_role = 'building' then u else building_approved_by end,
    apartment_approved_by = case when p_role = 'apartment' then u else apartment_approved_by end,
    requires_apartment_approval = needs_admin, status = case when complete then 'approved' else 'pending' end,
    is_apartment_admin = complete and not needs_admin, updated_at = now() where id = p_member;
  if complete then
    if not needs_admin and m.requested_household_name is not null then
      insert into public.community_household(apartment_id, building_id, display_name, updated_by)
        values(m.apartment_id, b, m.requested_household_name, m.user_id)
        on conflict(apartment_id) do nothing;
    end if;
    update public.community_member set requested_household_name = null where apartment_id = m.apartment_id and requested_household_name is not null;
    update public.community_member set requires_apartment_approval = true where apartment_id = m.apartment_id and status = 'pending';
    perform app.notify(m.user_id, b, 'community.application_approved', '{}', '/home', p_member);
  end if;
  perform app.audit(b, 'community.approve_' || p_role, 'community_member', p_member);
end $$;

