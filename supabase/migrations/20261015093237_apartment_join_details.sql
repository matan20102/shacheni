-- Apartment discovery discloses status only, never residents or family names.
-- The directory keeps entrance identity separate from the legacy apartment key.
create table public.community_apartment (
  apartment_id uuid primary key,
  building_id uuid not null,
  number text not null check (char_length(number) between 1 and 20),
  entrance text not null default '' check (char_length(entrance) <= 20),
  foreign key (apartment_id, building_id) references public.apartment(id, building_id),
  unique (building_id, number, entrance)
);
insert into public.community_apartment(apartment_id, building_id, number, entrance)
select a.id, a.building_id, a.number, coalesce((select nullif(btrim(m.entrance), '')
  from public.community_member m where m.apartment_id = a.id
  order by (m.status = 'approved') desc, m.created_at limit 1), '')
from public.apartment a where exists(select 1 from public.community_member m where m.apartment_id = a.id);
alter table public.community_apartment enable row level security;
revoke all on public.community_apartment from public, anon, authenticated;
grant select on public.community_apartment to authenticated;
create policy community_apartment_read on public.community_apartment for select to authenticated
  using (app.ba_resident(building_id) and exists(select 1 from public.community_member m
    where m.apartment_id = community_apartment.apartment_id and m.user_id = (select auth.uid()) and m.status = 'approved'));
alter table public.community_member add column requested_household_name text
  check (char_length(btrim(requested_household_name)) between 1 and 60);

create function app.ba_normalize_apartment(p_number text) returns text
language sql immutable strict set search_path = '' as $$
  select case when btrim(p_number) ~ '^[0-9]+$'
    then coalesce(nullif(ltrim(btrim(p_number), '0'), ''), '0') else btrim(p_number) end
$$;

create or replace function app.ba_resolve(p_code text) returns jsonb
language plpgsql volatile security definer set search_path = '' as $$
declare u uuid := app.require_user(); b public.building;
begin
  perform app.require_terms();
  if (select count(*) from public.join_code_attempt where user_id = u and kind = 'code'
      and not succeeded and created_at > now() - interval '1 hour') >= 10 then raise exception 'RATE_LIMITED'; end if;
  select bl.* into b from public.building bl join public.community_settings s on s.building_id = bl.id
    where bl.status = 'active' and (bl.join_code = upper(btrim(p_code))
      or (upper(btrim(p_code)) = 'CHECK' and bl.settings->>'community_test_fixture' = 'join-check'));
  insert into public.join_code_attempt(user_id, succeeded, kind) values(u, b.id is not null, 'code');
  if b.id is null then return null; end if;
  return jsonb_build_object('id', b.id, 'name', b.name, 'address', b.address,
    'entrances', coalesce((select entrance_count from public.community_settings where building_id = b.id), 1));
end $$;

create function app.ba_apartment_status(p_code text, p_apartment text, p_entrance text) returns jsonb
language plpgsql volatile security definer set search_path = '' as $$
declare b uuid; a uuid; n text := app.ba_normalize_apartment(p_apartment); e text := btrim(coalesce(p_entrance, ''));
begin
  perform app.require_user(); perform app.require_terms();
  if n is null or n !~ '^[0-9]{1,20}$' or char_length(e) > 20 then raise exception 'INVALID_ARGUMENT'; end if;
  b := (app.ba_resolve(p_code)->>'id')::uuid;
  if b is null then return null; end if;
  select d.apartment_id into a from public.community_apartment d
    where d.building_id = b and d.number = n and d.entrance = e;
  if a is null and e = '' then
    select ap.id into a from public.apartment ap where ap.building_id = b and ap.number = n
      and not exists(select 1 from public.community_apartment d where d.apartment_id = ap.id);
  end if;
  return jsonb_build_object(
    'exists', exists(select 1 from public.community_member m where m.apartment_id = a and m.status = 'approved'),
    'has_admin', exists(select 1 from public.community_member m where m.apartment_id = a and m.status = 'approved' and m.is_apartment_admin));
end $$;

create function app.ba_submit_home(p_code text, p_apartment text, p_floor text, p_entrance text, p_household_name text) returns uuid
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
  select d.apartment_id into a from public.community_apartment d where d.building_id = b and d.number = n and d.entrance = e;
  if a is null then
    -- Adopt old apartments that have not entered the directory, without moving an existing entrance.
    if e = '' then
      select ap.id into a from public.apartment ap where ap.building_id = b and ap.number = n
        and not exists(select 1 from public.community_apartment d where d.apartment_id = ap.id);
    end if;
    if a is null then
      -- Legacy number remains unique per building; the directory is the visible identity.
      insert into public.apartment(building_id, number)
        values(b, case when exists(select 1 from public.apartment where building_id = b and number = n)
          then '@' || substr(replace(gen_random_uuid()::text, '-', ''), 1, 19) else n end) returning id into a;
    end if;
    insert into public.community_apartment(apartment_id, building_id, number, entrance) values(a, b, n, e);
  end if;
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

-- Old clients retain their API; new clients require numeric apartment numbers.
create or replace function app.ba_join(p_code text, p_apartment text, p_floor text, p_entrance text) returns uuid
language sql volatile security definer set search_path = '' as $$
  select app.ba_submit_home(p_code, p_apartment, p_floor, p_entrance, null)
$$;
create function app.ba_apply_home(p_code text, p_apartment text, p_floor text, p_entrance text, p_household_name text) returns uuid
language plpgsql volatile security definer set search_path = '' as $$
begin
  perform app.require_user(); perform app.require_terms();
  if coalesce(btrim(p_apartment), '') !~ '^[0-9]{1,20}$' then raise exception 'INVALID_ARGUMENT'; end if;
  return app.ba_submit_home(p_code, p_apartment, p_floor, p_entrance, p_household_name);
end $$;

create function app.ba_create_home_v2(p_address text, p_name text, p_apartment text, p_entrances int, p_household_name text, p_entrance text) returns uuid
language plpgsql volatile security definer set search_path = '' as $$
declare b uuid; a uuid; n text := app.ba_normalize_apartment(p_apartment); e text := btrim(coalesce(p_entrance, ''));
begin
  perform app.require_user(); perform app.require_terms();
  if n is null or n !~ '^[0-9]{1,20}$' or char_length(e) > 20 then raise exception 'INVALID_ARGUMENT'; end if;
  b := app.ba_create_home(p_address, p_name, n, p_entrances, p_household_name);
  select apartment_id into a from public.community_member where building_id = b and user_id = auth.uid();
  insert into public.community_apartment(apartment_id, building_id, number, entrance) values(a, b, n, e);
  update public.community_member set entrance = nullif(e, '') where apartment_id = a;
  return b;
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
    update public.community_member set requested_household_name = null where apartment_id = m.apartment_id;
    update public.community_member set requires_apartment_approval = true where apartment_id = m.apartment_id and status = 'pending';
    perform app.notify(m.user_id, b, 'community.application_approved', '{}', '/home', p_member);
  end if;
  perform app.audit(b, 'community.approve_' || p_role, 'community_member', p_member);
end $$;

create or replace function app.ba_state() returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare u uuid := app.require_user();
begin
  perform app.require_terms();
  return jsonb_build_object(
    'homes', coalesce((select jsonb_agg(jsonb_build_object(
      'id', b.id, 'name', b.name, 'address', b.address, 'apartment', coalesce(d.number, a.number), 'entrance', coalesce(nullif(d.entrance, ''), m.entrance), 'household_name', coalesce(h.display_name, ''),
      'entrances', coalesce(s.entrance_count, 1), 'code', case when m.is_building_admin then b.join_code else '' end,
      'is_admin', m.is_building_admin, 'is_committee', m.is_committee, 'is_apartment_admin', m.is_apartment_admin)
      order by m.created_at) from public.community_member m join public.building b on b.id = m.building_id
      join public.apartment a on a.id = m.apartment_id left join public.community_settings s on s.building_id = b.id
      left join public.community_household h on h.apartment_id = a.id
      left join public.community_apartment d on d.apartment_id = a.id
      where m.user_id = u and m.status = 'approved' and b.status = 'active'), '[]'),
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

create or replace function app.ba_publish(p_building uuid, p_body text, p_kind text) returns uuid
language plpgsql volatile security definer set search_path = '' as $$
declare u uuid := app.require_user(); p uuid; apartment_number text;
begin
  if not app.ba_resident(p_building) then raise exception 'ACCESS_DENIED'; end if;
  if coalesce(char_length(btrim(p_body)), 0) not between 1 and 2000 or p_kind is null or p_kind not in ('notice', 'request') then raise exception 'INVALID_ARGUMENT'; end if;
  select coalesce(d.number, a.number) || case when nullif(d.entrance, '') is null then '' else ' · כניסה ' || d.entrance end into apartment_number from public.community_member m join public.apartment a on a.id = m.apartment_id
    left join public.community_apartment d on d.apartment_id = a.id
    where m.building_id = p_building and m.user_id = u and m.status = 'approved';
  insert into public.board_post(building_id, author_id, apartment, kind, body) values(p_building, u, apartment_number, p_kind, btrim(p_body)) returning id into p;
  perform app.audit(p_building, 'board.publish', 'board_post', p);
  return p;
end $$;

create function public.ba_apartment_status(p_code text, p_apartment text, p_entrance text default null) returns jsonb
language sql volatile security invoker set search_path = '' as $$ select app.ba_apartment_status(p_code, p_apartment, p_entrance) $$;
create function public.ba_apply_home(p_code text, p_apartment text, p_floor text default null, p_entrance text default null, p_household_name text default null) returns uuid
language sql volatile security invoker set search_path = '' as $$ select app.ba_apply_home(p_code, p_apartment, p_floor, p_entrance, p_household_name) $$;
create function public.ba_create_home_v2(p_address text, p_name text default null, p_apartment text default '1', p_entrances int default 1, p_household_name text default null, p_entrance text default null) returns uuid
language sql volatile security invoker set search_path = '' as $$ select app.ba_create_home_v2(p_address, p_name, p_apartment, p_entrances, p_household_name, p_entrance) $$;
revoke all on function app.ba_normalize_apartment(text), app.ba_submit_home(text,text,text,text,text) from public, anon, authenticated;
revoke all on function app.ba_apartment_status(text,text,text), public.ba_apartment_status(text,text,text),
  app.ba_apply_home(text,text,text,text,text), public.ba_apply_home(text,text,text,text,text),
  app.ba_create_home_v2(text,text,text,int,text,text), public.ba_create_home_v2(text,text,text,int,text,text) from public, anon, authenticated;
grant execute on function app.ba_apartment_status(text,text,text), public.ba_apartment_status(text,text,text),
  app.ba_apply_home(text,text,text,text,text), public.ba_apply_home(text,text,text,text,text),
  app.ba_create_home_v2(text,text,text,int,text,text), public.ba_create_home_v2(text,text,text,int,text,text) to authenticated;
