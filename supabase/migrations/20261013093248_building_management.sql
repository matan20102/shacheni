-- Additive building-management foundation. Legacy memberships/RPCs stay intact.
-- Reuses building/apartment/profile identities; separate membership approvals allow
-- several buildings and a staged migration of the old application.

create table public.community_settings (
  building_id uuid primary key references public.building(id),
  entrance_count integer not null default 1 check (entrance_count between 1 and 20)
);
create table public.community_member (
  id uuid primary key default gen_random_uuid(),
  building_id uuid not null references public.building(id),
  apartment_id uuid not null,
  user_id uuid not null references public.profile(id),
  status text not null default 'pending' check (status in ('pending', 'approved', 'rejected', 'withdrawn')),
  floor text check (char_length(floor) <= 20),
  entrance text check (char_length(entrance) <= 20),
  requires_apartment_approval boolean not null default false,
  building_approved boolean not null default false,
  apartment_approved boolean not null default false,
  building_approved_by uuid references public.profile(id),
  apartment_approved_by uuid references public.profile(id),
  is_building_admin boolean not null default false,
  is_committee boolean not null default false,
  is_apartment_admin boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  foreign key (apartment_id, building_id) references public.apartment(id, building_id),
  unique (building_id, user_id),
  check (status <> 'approved' or (building_approved and (not requires_apartment_approval or apartment_approved))),
  check (status = 'approved' or not (is_building_admin or is_committee or is_apartment_admin))
);
create index community_member_user_idx on public.community_member(user_id, status);
create index community_member_apartment_idx on public.community_member(apartment_id, status);
create index community_member_pending_idx on public.community_member(building_id, created_at) where status = 'pending';
create unique index community_one_apartment_admin on public.community_member(apartment_id)
  where status = 'approved' and is_apartment_admin;

-- Existing buildings/memberships are deliberately not enrolled automatically:
-- legacy permission changes cannot leave a copied authorization stale.
-- New buildings opt into this module atomically through ba_create.

create table public.board_post (
  id uuid primary key default gen_random_uuid(),
  building_id uuid not null references public.building(id),
  author_id uuid not null references public.profile(id),
  apartment text not null,
  kind text not null check (kind in ('notice', 'request')),
  body text not null check (char_length(btrim(body)) between 1 and 2000),
  pinned boolean not null default false,
  closed boolean not null default false,
  deleted_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, building_id)
);
create index board_post_feed_idx on public.board_post(building_id, pinned desc, created_at desc) where deleted_at is null;
create index board_post_author_idx on public.board_post(author_id);
create table public.board_reply (
  id uuid primary key default gen_random_uuid(),
  building_id uuid not null,
  post_id uuid not null,
  author_id uuid not null references public.profile(id),
  body text not null check (char_length(btrim(body)) between 1 and 1000),
  created_at timestamptz not null default now(),
  foreign key (post_id, building_id) references public.board_post(id, building_id)
);
create index board_reply_post_idx on public.board_reply(post_id, created_at);
create index board_reply_author_idx on public.board_reply(author_id);
create table public.board_reaction (
  building_id uuid not null,
  post_id uuid not null,
  user_id uuid not null references public.profile(id),
  emoji text not null check (emoji in ('💚', '🙌', '😊')),
  primary key (post_id, user_id, emoji),
  foreign key (post_id, building_id) references public.board_post(id, building_id)
);
create index board_reaction_user_idx on public.board_reaction(user_id);
create index board_reply_building_idx on public.board_reply(building_id);
create index board_reaction_building_idx on public.board_reaction(building_id);

-- Privileged implementations live in non-exposed app; public endpoints are invokers.
create function app.ba_resident(b uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select (select auth.uid()) is not null and exists (
    select 1 from public.community_member m join public.building bl on bl.id = m.building_id
    where m.building_id = b and m.user_id = (select auth.uid()) and m.status = 'approved' and bl.status = 'active')
    and app.has_accepted_current('terms_of_service') and app.has_accepted_current('privacy_policy')
$$;
create function app.ba_admin(b uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select app.ba_resident(b) and exists(select 1 from public.community_member
    where building_id = b and user_id = (select auth.uid()) and status = 'approved' and is_building_admin)
$$;
create function app.ba_apartment_admin(a uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select (select auth.uid()) is not null and exists(select 1 from public.community_member m
    where m.apartment_id = a and m.user_id = (select auth.uid()) and m.status = 'approved'
      and m.is_apartment_admin and app.ba_resident(m.building_id))
$$;
create function app.ba_read_post(p uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select (select auth.uid()) is not null and exists(select 1 from public.board_post
    where id = p and deleted_at is null and app.ba_resident(building_id))
$$;

alter table public.community_settings enable row level security;
alter table public.community_member enable row level security;
alter table public.board_post enable row level security;
alter table public.board_reply enable row level security;
alter table public.board_reaction enable row level security;
revoke all on public.community_settings, public.community_member, public.board_post, public.board_reply, public.board_reaction
  from public, anon, authenticated;
grant select on public.community_settings, public.community_member, public.board_post, public.board_reply, public.board_reaction to authenticated;
create policy community_settings_read on public.community_settings for select to authenticated using (app.ba_resident(building_id));
create policy community_member_read on public.community_member for select to authenticated
  using (user_id = (select auth.uid()) or app.ba_admin(building_id) or app.ba_apartment_admin(apartment_id));
create policy board_post_read on public.board_post for select to authenticated using (deleted_at is null and app.ba_resident(building_id));
create policy board_reply_read on public.board_reply for select to authenticated using (app.ba_read_post(post_id));
create policy board_reaction_read on public.board_reaction for select to authenticated using (app.ba_read_post(post_id));

create function app.ba_state() returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare u uuid := app.require_user();
begin
  perform app.require_terms();
  return jsonb_build_object(
    'homes', coalesce((select jsonb_agg(jsonb_build_object(
      'id', b.id, 'name', b.name, 'address', b.address, 'apartment', a.number,
      'entrances', coalesce(s.entrance_count, 1), 'code', case when m.is_building_admin then b.join_code else '' end,
      'is_admin', m.is_building_admin, 'is_committee', m.is_committee, 'is_apartment_admin', m.is_apartment_admin)
      order by m.created_at) from public.community_member m join public.building b on b.id = m.building_id
      join public.apartment a on a.id = m.apartment_id left join public.community_settings s on s.building_id = b.id
      where m.user_id = u and m.status = 'approved' and b.status = 'active'), '[]'),
    'applications', coalesce((select jsonb_agg(jsonb_build_object(
      'id', m.id, 'building_id', b.id, 'building_name', b.name, 'building_address', b.address,
      'apartment', a.number, 'floor', m.floor, 'entrance', m.entrance,
      'apartment_has_admin', m.requires_apartment_approval,
      'building_approved', m.building_approved, 'apartment_approved', m.apartment_approved,
      'mine', m.user_id = u, 'applicant_name', p.full_name,
      'can_approve_building', app.ba_admin(m.building_id),
      'can_approve_apartment', app.ba_apartment_admin(m.apartment_id)) order by m.created_at)
      from public.community_member m join public.building b on b.id = m.building_id
      join public.apartment a on a.id = m.apartment_id join public.profile p on p.id = m.user_id
      where m.status = 'pending' and b.status = 'active' and
        (m.user_id = u or app.ba_admin(m.building_id) or app.ba_apartment_admin(m.apartment_id))), '[]'));
end $$;

create function app.ba_create(p_address text, p_name text, p_apartment text, p_entrances int) returns uuid
language plpgsql volatile security definer set search_path = '' as $$
declare u uuid := app.require_user(); b uuid; a uuid;
  display_name text := coalesce(nullif(btrim(p_name), ''), btrim(p_address));
begin
  perform app.require_terms();
  if coalesce(char_length(btrim(p_address)), 0) not between 1 and 100
    or coalesce(char_length(display_name), 0) not between 1 and 100
    or coalesce(char_length(btrim(p_apartment)), 0) not between 1 and 20
    or p_entrances is null or p_entrances not between 1 and 20 then raise exception 'INVALID_ARGUMENT'; end if;
  insert into public.building(name, address, declared_apartment_count, declared_parking_count,
    status, join_code, join_code_rotated_at, created_by, activated_at)
    values(display_name, btrim(p_address), 1, 0, 'active', app.new_join_code(), now(), u, now()) returning id into b;
  insert into public.community_settings(building_id, entrance_count) values(b, p_entrances);
  insert into public.apartment(building_id, number) values(b, btrim(p_apartment)) returning id into a;
  insert into public.community_member(building_id, apartment_id, user_id, status, building_approved,
    building_approved_by, is_building_admin, is_committee, is_apartment_admin)
    values(b, a, u, 'approved', true, u, true, true, true);
  perform app.audit(b, 'community.create_building', 'building', b);
  return b;
end $$;

create function app.ba_resolve(p_code text) returns jsonb
language plpgsql volatile security definer set search_path = '' as $$
declare u uuid := app.require_user(); b public.building;
begin
  perform app.require_terms();
  if (select count(*) from public.join_code_attempt where user_id = u and kind = 'code'
      and not succeeded and created_at > now() - interval '1 hour') >= 10 then raise exception 'RATE_LIMITED'; end if;
  select bl.* into b from public.building bl join public.community_settings s on s.building_id = bl.id
    where bl.join_code = upper(btrim(p_code)) and bl.status = 'active';
  insert into public.join_code_attempt(user_id, succeeded, kind) values(u, b.id is not null, 'code');
  if b.id is null then return null; end if;
  return jsonb_build_object('id', b.id, 'name', b.name, 'address', b.address,
    'entrances', coalesce((select entrance_count from public.community_settings where building_id = b.id), 1));
end $$;

create function app.ba_join(p_code text, p_apartment text, p_floor text, p_entrance text) returns uuid
language plpgsql volatile security definer set search_path = '' as $$
declare u uuid := app.require_user(); b uuid; a uuid; m uuid; old_status text; needs_admin boolean;
begin
  perform app.require_terms();
  if coalesce(char_length(btrim(p_apartment)), 0) not between 1 and 20
    or coalesce(char_length(p_floor), 0) > 20 or coalesce(char_length(p_entrance), 0) > 20 then raise exception 'INVALID_ARGUMENT'; end if;
  b := (app.ba_resolve(p_code)->>'id')::uuid;
  if b is null then return null; end if; -- keep failed code attempts committed
  -- Same lock order for submit and approve: building, member, apartment.
  perform 1 from public.building where id = b for update;
  select id, status into m, old_status from public.community_member where building_id = b and user_id = u for update;
  if old_status in ('pending', 'approved') then raise exception 'ALREADY_APPLIED'; end if;
  insert into public.apartment(building_id, number) values(b, btrim(p_apartment))
    on conflict (building_id, number) do update set number = excluded.number returning id into a;
  needs_admin := exists(select 1 from public.community_member where apartment_id = a and status = 'approved' and is_apartment_admin);
  insert into public.community_member(building_id, apartment_id, user_id, floor, entrance, requires_apartment_approval)
    values(b, a, u, nullif(btrim(p_floor), ''), nullif(btrim(p_entrance), ''), needs_admin)
    on conflict (building_id, user_id) do update set apartment_id = excluded.apartment_id, status = 'pending',
      floor = excluded.floor, entrance = excluded.entrance, requires_apartment_approval = excluded.requires_apartment_approval,
      building_approved = false, apartment_approved = false, building_approved_by = null, apartment_approved_by = null, updated_at = now()
    returning id into m;
  perform app.notify(cm.user_id, b, 'community.application_received', jsonb_build_object('apartment', btrim(p_apartment)), '/home', m)
    from public.community_member cm where cm.building_id = b and cm.status = 'approved'
      and (cm.is_building_admin or (cm.apartment_id = a and cm.is_apartment_admin));
  perform app.audit(b, 'community.join', 'community_member', m);
  return m;
end $$;

create function app.ba_approve(p_member uuid, p_role text) returns void
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
    update public.community_member set requires_apartment_approval = true where apartment_id = m.apartment_id and status = 'pending';
    perform app.notify(m.user_id, b, 'community.application_approved', '{}', '/home', p_member);
  end if;
  perform app.audit(b, 'community.approve_' || p_role, 'community_member', p_member);
end $$;

create function app.ba_withdraw(p_member uuid) returns void
language plpgsql volatile security definer set search_path = '' as $$
declare u uuid := app.require_user(); b uuid;
begin
  perform app.require_terms();
  update public.community_member set status = 'withdrawn', updated_at = now()
    where id = p_member and user_id = u and status = 'pending' returning building_id into b;
  if b is null then raise exception 'ACCESS_DENIED'; end if;
  perform app.audit(b, 'community.withdraw', 'community_member', p_member);
end $$;

create function app.ba_board(p_building uuid) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare u uuid := app.require_user();
begin
  if not app.ba_resident(p_building) then raise exception 'ACCESS_DENIED'; end if;
  return coalesce((select jsonb_agg(jsonb_build_object(
    'id', p.id, 'building_id', p.building_id, 'author', coalesce(nullif(pr.full_name, ''), 'שכן'),
    'mine', p.author_id = u, 'apartment', p.apartment, 'text', p.body, 'kind', p.kind,
    'created_at', p.created_at, 'pinned', p.pinned, 'closed', p.closed,
    'replies', coalesce((select jsonb_agg(jsonb_build_object('author', coalesce(nullif(rp.full_name, ''), 'שכן'),
      'text', r.body) order by r.created_at) from public.board_reply r join public.profile rp on rp.id = r.author_id where r.post_id = p.id), '[]'),
    'reactions', coalesce((select jsonb_object_agg(x.emoji, x.n) from (select emoji, count(*) n from public.board_reaction where post_id = p.id group by emoji) x), '{}'),
    'my_reactions', coalesce((select jsonb_agg(emoji) from public.board_reaction where post_id = p.id and user_id = u), '[]')
    ) order by p.pinned desc, p.created_at desc)
    from (select * from public.board_post where building_id = p_building and deleted_at is null order by pinned desc, created_at desc limit 100) p
    join public.profile pr on pr.id = p.author_id), '[]');
end $$;

create function app.ba_publish(p_building uuid, p_body text, p_kind text) returns uuid
language plpgsql volatile security definer set search_path = '' as $$
declare u uuid := app.require_user(); p uuid; apartment_number text;
begin
  if not app.ba_resident(p_building) then raise exception 'ACCESS_DENIED'; end if;
  if coalesce(char_length(btrim(p_body)), 0) not between 1 and 2000 or p_kind is null or p_kind not in ('notice', 'request') then raise exception 'INVALID_ARGUMENT'; end if;
  select a.number into apartment_number from public.community_member m join public.apartment a on a.id = m.apartment_id
    where m.building_id = p_building and m.user_id = u and m.status = 'approved';
  insert into public.board_post(building_id, author_id, apartment, kind, body) values(p_building, u, apartment_number, p_kind, btrim(p_body)) returning id into p;
  perform app.audit(p_building, 'board.publish', 'board_post', p);
  return p;
end $$;

create function app.ba_post_action(p_post uuid, p_action text, p_text text, p_emoji text) returns void
language plpgsql volatile security definer set search_path = '' as $$
declare u uuid := app.require_user(); p public.board_post;
begin
  select * into p from public.board_post where id = p_post and deleted_at is null for update;
  if p.id is null or not app.ba_resident(p.building_id) then raise exception 'ACCESS_DENIED'; end if;
  if p_action in ('edit', 'close') and p.author_id <> u then raise exception 'ACCESS_DENIED'; end if;
  if p_action = 'pin' and not app.ba_admin(p.building_id) then raise exception 'ACCESS_DENIED'; end if;
  if p_action = 'delete' and p.author_id <> u and not app.ba_admin(p.building_id) then raise exception 'ACCESS_DENIED'; end if;
  case p_action
    when 'edit' then
      if coalesce(char_length(btrim(p_text)), 0) not between 1 and 2000 then raise exception 'INVALID_ARGUMENT'; end if;
      update public.board_post set body = btrim(p_text), updated_at = now() where id = p_post;
    when 'close' then update public.board_post set closed = not closed, updated_at = now() where id = p_post;
    when 'pin' then update public.board_post set pinned = not pinned, updated_at = now() where id = p_post;
    when 'delete' then update public.board_post set deleted_at = now(), updated_at = now() where id = p_post;
    when 'reply' then
      if p.closed then raise exception 'POST_CLOSED'; end if;
      if coalesce(char_length(btrim(p_text)), 0) not between 1 and 1000 then raise exception 'INVALID_ARGUMENT'; end if;
      insert into public.board_reply(building_id, post_id, author_id, body) values(p.building_id, p_post, u, btrim(p_text));
    when 'react' then
      if p_emoji is null or p_emoji not in ('💚', '🙌', '😊') then raise exception 'INVALID_ARGUMENT'; end if;
      delete from public.board_reaction where post_id = p_post and user_id = u and emoji = p_emoji;
      if not found then insert into public.board_reaction(building_id, post_id, user_id, emoji) values(p.building_id, p_post, u, p_emoji); end if;
    else raise exception 'INVALID_ARGUMENT';
  end case;
  if p_action in ('edit', 'close', 'pin', 'delete') then perform app.audit(p.building_id, 'board.' || p_action, 'board_post', p_post); end if;
end $$;

create function public.ba_state() returns jsonb language sql stable security invoker set search_path = '' as $$ select app.ba_state() $$;
create function public.ba_create(p_address text, p_name text default null, p_apartment text default '1', p_entrances int default 1)
  returns uuid language sql volatile security invoker set search_path = '' as $$ select app.ba_create(p_address, p_name, p_apartment, p_entrances) $$;
create function public.ba_resolve(p_code text) returns jsonb language sql volatile security invoker set search_path = '' as $$ select app.ba_resolve(p_code) $$;
create function public.ba_join(p_code text, p_apartment text, p_floor text default null, p_entrance text default null)
  returns uuid language sql volatile security invoker set search_path = '' as $$ select app.ba_join(p_code, p_apartment, p_floor, p_entrance) $$;
create function public.ba_approve(p_member uuid, p_role text) returns void language sql volatile security invoker set search_path = '' as $$ select app.ba_approve(p_member, p_role) $$;
create function public.ba_withdraw(p_member uuid) returns void language sql volatile security invoker set search_path = '' as $$ select app.ba_withdraw(p_member) $$;
create function public.ba_board(p_building uuid) returns jsonb language sql stable security invoker set search_path = '' as $$ select app.ba_board(p_building) $$;
create function public.ba_publish(p_building uuid, p_body text, p_kind text) returns uuid language sql volatile security invoker set search_path = '' as $$ select app.ba_publish(p_building, p_body, p_kind) $$;
create function public.ba_post_action(p_post uuid, p_action text, p_text text default null, p_emoji text default null)
  returns void language sql volatile security invoker set search_path = '' as $$ select app.ba_post_action(p_post, p_action, p_text, p_emoji) $$;

-- Restrict ONLY newly introduced functions. Existing app helper grants stay intact.
do $$ declare f record; begin
  for f in select p.oid::regprocedure as signature from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname in ('app', 'public') and p.proname like 'ba\_%' escape '\' loop
    execute format('revoke all on function %s from public, anon, authenticated', f.signature);
    execute format('grant execute on function %s to authenticated', f.signature);
  end loop;
end $$;
