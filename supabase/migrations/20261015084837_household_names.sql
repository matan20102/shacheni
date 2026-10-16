-- Add optional apartment names without changing legacy apartment permissions.
create table public.community_household (
  apartment_id uuid primary key,
  building_id uuid not null,
  display_name text not null check (char_length(btrim(display_name)) between 1 and 60),
  updated_by uuid not null references public.profile(id),
  updated_at timestamptz not null default now(),
  foreign key (apartment_id, building_id) references public.apartment(id, building_id)
);
create index community_household_building_idx on public.community_household(building_id, apartment_id);
create index community_household_updated_by_idx on public.community_household(updated_by);
alter table public.community_household enable row level security;
revoke all on public.community_household from public, anon, authenticated;
grant select on public.community_household to authenticated;
create policy household_read on public.community_household for select to authenticated
  using (app.ba_resident(building_id) and exists (
    select 1 from public.community_member m
    where m.apartment_id = community_household.apartment_id
      and m.user_id = (select auth.uid()) and m.status = 'approved'));

create function app.ba_set_household(p_building uuid, p_name text) returns void
language plpgsql volatile security definer set search_path = '' as $$
declare u uuid := app.require_user(); a uuid; label text := btrim(coalesce(p_name, ''));
begin
  perform app.require_terms();
  if char_length(label) > 60 then raise exception 'INVALID_ARGUMENT'; end if;
  -- Same lock order as membership approval: building, member, apartment.
  perform 1 from public.building where id = p_building and status = 'active' for update;
  if not found then raise exception 'ACCESS_DENIED'; end if;
  select m.apartment_id into a from public.community_member m
    where m.building_id = p_building and m.user_id = u and m.status = 'approved' and m.is_apartment_admin
    for update;
  if not found then raise exception 'ACCESS_DENIED'; end if;
  perform 1 from public.apartment where id = a for update;
  if label = '' then
    delete from public.community_household where apartment_id = a;
  else
    insert into public.community_household(apartment_id, building_id, display_name, updated_by)
      values(a, p_building, label, u)
      on conflict(apartment_id) do update set display_name = excluded.display_name,
        updated_by = excluded.updated_by, updated_at = now();
  end if;
  perform app.audit(p_building, 'community.rename_household', 'apartment', a);
end $$;

create function app.ba_create_home(p_address text, p_name text, p_apartment text, p_entrances int, p_household_name text) returns uuid
language plpgsql volatile security definer set search_path = '' as $$
declare b uuid;
begin
  perform app.require_user();
  perform app.require_terms();
  if p_entrances is null or p_entrances not between 1 and 9
    or char_length(btrim(coalesce(p_household_name, ''))) > 60 then raise exception 'INVALID_ARGUMENT'; end if;
  b := app.ba_create(p_address, p_name, p_apartment, p_entrances);
  if nullif(btrim(p_household_name), '') is not null then
    perform app.ba_set_household(b, p_household_name);
  end if;
  return b;
end $$;

create function public.ba_set_household(p_building uuid, p_name text) returns void
language sql volatile security invoker set search_path = '' as $$ select app.ba_set_household(p_building, p_name) $$;
create function public.ba_create_home(p_address text, p_name text default null, p_apartment text default '1', p_entrances int default 1, p_household_name text default null) returns uuid
language sql volatile security invoker set search_path = '' as $$ select app.ba_create_home(p_address, p_name, p_apartment, p_entrances, p_household_name) $$;

revoke all on function app.ba_set_household(uuid,text), public.ba_set_household(uuid,text),
  app.ba_create_home(text,text,text,int,text), public.ba_create_home(text,text,text,int,text) from public, anon, authenticated;
grant execute on function app.ba_set_household(uuid,text), public.ba_set_household(uuid,text),
  app.ba_create_home(text,text,text,int,text), public.ba_create_home(text,text,text,int,text) to authenticated;

create or replace function app.ba_state() returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare u uuid := app.require_user();
begin
  perform app.require_terms();
  return jsonb_build_object(
    'homes', coalesce((select jsonb_agg(jsonb_build_object(
      'id', b.id, 'name', b.name, 'address', b.address, 'apartment', a.number, 'household_name', coalesce(h.display_name, ''),
      'entrances', coalesce(s.entrance_count, 1), 'code', case when m.is_building_admin then b.join_code else '' end,
      'is_admin', m.is_building_admin, 'is_committee', m.is_committee, 'is_apartment_admin', m.is_apartment_admin)
      order by m.created_at) from public.community_member m join public.building b on b.id = m.building_id
      join public.apartment a on a.id = m.apartment_id left join public.community_settings s on s.building_id = b.id
      left join public.community_household h on h.apartment_id = a.id
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

