create function app.ba_approve_member(p_member uuid, p_role text, p_platform boolean) returns void
language plpgsql volatile security definer set search_path = '' as $$
declare u uuid := app.require_user(); b uuid; m public.community_member; needs_admin boolean; complete boolean;
begin
  perform app.require_terms();
  if p_platform and not app.is_platform_admin() then raise exception 'ACCESS_DENIED'; end if;
  select building_id into b from public.community_member where id = p_member;
  if b is null then raise exception 'ACCESS_DENIED'; end if;
  perform 1 from public.building where id = b and status = 'active' for update;
  if not found then raise exception 'ACCESS_DENIED'; end if;
  select * into m from public.community_member where id = p_member for update;
  perform 1 from public.apartment where id = m.apartment_id for update;
  if p_role = 'building' then
    if not (app.ba_admin(b) or p_platform) then raise exception 'ACCESS_DENIED'; end if;
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

revoke all on function app.ba_approve_member(uuid,text,boolean) from public,anon,authenticated;
create or replace function app.ba_approve(p_member uuid,p_role text) returns void
language sql volatile security definer set search_path = '' as $$select app.ba_approve_member(p_member,p_role,false)$$;

-- Resident directory and defined platform operations. Platform grants are
-- provisioned separately against confirmed Auth identities, never client emails.
create index audit_log_community_feed_idx on public.audit_log(created_at desc,id)
  where action like 'community.%';
create function app.ba_residents(p_building uuid) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  perform app.require_user(); perform app.require_terms();
  if not app.ba_resident(p_building) then raise exception 'ACCESS_DENIED'; end if;
  return coalesce((select jsonb_agg(jsonb_build_object(
    'id', m.id, 'name', p.full_name, 'apartment', coalesce(d.number,a.number),
    'household', coalesce(h.display_name,''), 'is_admin', m.is_building_admin,
    'is_apartment_admin', m.is_apartment_admin, 'mine', m.user_id=(select auth.uid()))
    order by case when coalesce(d.number,a.number) ~ '^[0-9]+$' then coalesce(d.number,a.number)::numeric end nulls last,
      coalesce(d.number,a.number), m.is_apartment_admin desc, m.created_at, m.id)
    from public.community_member m join public.profile p on p.id=m.user_id
    join public.apartment a on a.id=m.apartment_id
    left join public.community_apartment d on d.apartment_id=a.id
    left join public.community_household h on h.apartment_id=a.id
    where m.building_id=p_building and m.status='approved'), '[]');
end $$;

create function app.ba_set_admin(p_member uuid, p_admin boolean) returns void
language plpgsql volatile security definer set search_path = '' as $$
declare b uuid; m public.community_member;
begin
  perform app.require_user(); perform app.require_terms();
  if p_admin is null then raise exception 'INVALID_ARGUMENT'; end if;
  select building_id into b from public.community_member where id=p_member;
  perform 1 from public.building where id=b and status='active' for update;
  if not found or not app.ba_admin(b) then raise exception 'ACCESS_DENIED'; end if;
  select * into m from public.community_member where id=p_member for update;
  if m.status<>'approved' then raise exception 'INVALID_STATE'; end if;
  if m.is_building_admin=p_admin then return; end if;
  if not p_admin and not exists(select 1 from public.community_member
    where building_id=b and status='approved' and is_building_admin and id<>m.id)
    then raise exception 'LAST_BUILDING_ADMIN'; end if;
  update public.community_member set is_building_admin=p_admin,updated_at=now() where id=m.id;
  perform app.audit(b,case when p_admin then 'community.building_admin_granted' else 'community.building_admin_revoked' end,'community_member',m.id);
end $$;

create function app.ba_require_platform() returns void
language plpgsql stable security definer set search_path = '' as $$
begin
  perform app.require_user(); perform app.require_terms();
  if not app.is_platform_admin() then raise exception 'ACCESS_DENIED'; end if;
end $$;

create function app.ba_console(p_kind text, p_query text default '', p_offset integer default 0) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare q text := '%' || btrim(coalesce(p_query,'')) || '%'; rows jsonb;
begin
  perform app.ba_require_platform();
  if p_offset is null or p_offset<0 or p_offset>100000 or char_length(q)>102 then raise exception 'INVALID_ARGUMENT'; end if;
  if p_kind='users' then
    select coalesce(jsonb_agg(x.data order by x.created_at desc,x.id),'[]') into rows from (
      select p.id,p.created_at,jsonb_build_object('id',p.id,'name',p.full_name,'email',a.email,
        'phone',p.phone_e164,'created_at',p.created_at,'is_admin',exists(select 1 from public.platform_admin x where x.user_id=p.id),
        'homes',(select count(*) from public.community_member m join public.building b on b.id=m.building_id
          where m.user_id=p.id and m.status='approved' and b.status='active')) data
      from public.profile p join auth.users a on a.id=p.id where p.deleted_at is null and a.email_confirmed_at is not null
        and (p.full_name ilike q or a.email ilike q) order by p.created_at desc,p.id limit 26 offset p_offset) x;
  elsif p_kind='buildings' then
    select coalesce(jsonb_agg(x.data order by x.created_at desc,x.id),'[]') into rows from (
      select b.id,b.created_at,jsonb_build_object('id',b.id,'name',b.name,'address',b.address,'status',b.status,
        'archived',s.archived_at is not null,'residents',(select count(*) from public.community_member m where m.building_id=b.id and m.status='approved'),
        'pending',(select count(*) from public.community_member m where m.building_id=b.id and m.status='pending'),
        'has_admin',exists(select 1 from public.community_member m where m.building_id=b.id and m.status='approved' and m.is_building_admin)) data
      from public.building b join public.community_settings s on s.building_id=b.id
      where b.name ilike q or b.address ilike q order by b.created_at desc,b.id limit 26 offset p_offset) x;
  elsif p_kind='applications' then
    select coalesce(jsonb_agg(x.data order by x.created_at desc,x.id),'[]') into rows from (
      select m.id,m.created_at,jsonb_build_object('id',m.id,'name',p.full_name,'building',b.name,'apartment',coalesce(d.number,a.number),
        'building_approved',m.building_approved,'apartment_approved',m.apartment_approved,'needs_apartment',m.requires_apartment_approval) data
      from public.community_member m join public.building b on b.id=m.building_id
      join public.profile p on p.id=m.user_id join public.apartment a on a.id=m.apartment_id
      left join public.community_apartment d on d.apartment_id=a.id
      where m.status='pending' and b.status='active' and (p.full_name ilike q or b.name ilike q or coalesce(d.number,a.number) ilike q)
      order by m.created_at desc,m.id limit 26 offset p_offset) x;
  elsif p_kind='audit' then
    select coalesce(jsonb_agg(x.data order by x.created_at desc,x.id),'[]') into rows from (
      select l.id,l.created_at,jsonb_build_object('id',l.id,'action',l.action,'actor',coalesce(p.full_name,'מערכת'),
        'building',coalesce(b.name,''),'note',coalesce(l.note,''),'created_at',l.created_at,'target_id',l.target_id) data
      from public.audit_log l left join public.profile p on p.id=l.actor_id left join public.building b on b.id=l.building_id
      where l.action like 'community.%' and (l.action ilike q or p.full_name ilike q or b.name ilike q or l.note ilike q)
      order by l.created_at desc,l.id limit 26 offset p_offset) x;
  else raise exception 'INVALID_ARGUMENT'; end if;
  return jsonb_build_object('items',rows,'has_more',jsonb_array_length(rows)>25);
end $$;

create function app.ba_console_action(p_action text,p_id uuid,p_note text) returns void
language plpgsql volatile security definer set search_path = '' as $$
declare b uuid; archived timestamptz;
begin
  perform app.ba_require_platform();
  if coalesce(char_length(btrim(p_note)),0) not between 3 and 300 then raise exception 'INVALID_ARGUMENT'; end if;
  if p_action='approve_building' then
    perform app.ba_approve_member(p_id,'building',true);
    select building_id into b from public.community_member where id=p_id;
  elsif p_action in ('archive','restore') then
    b:=p_id;
    perform 1 from public.building where id=b for update;
    select archived_at into archived from public.community_settings where building_id=b for update;
    if not found then raise exception 'ACCESS_DENIED'; end if;
    if p_action='archive' then
      if archived is not null or not exists(select 1 from public.building where id=b and status='active') then raise exception 'INVALID_STATE'; end if;
      update public.community_settings set archived_at=now() where building_id=b;
      update public.building set status='suspended' where id=b;
    else
      if archived is null then raise exception 'INVALID_STATE'; end if;
      if not exists(select 1 from public.community_member where building_id=b and status='approved' and is_building_admin)
        then raise exception 'BUILDING_NEEDS_ADMIN'; end if;
      update public.community_settings set archived_at=null where building_id=b;
      update public.building set status='active' where id=b;
    end if;
  else raise exception 'INVALID_ARGUMENT'; end if;
  perform app.audit(b,'community.console_'||p_action,case when p_action='approve_building' then 'community_member' else 'building' end,p_id,btrim(p_note));
end $$;

create function public.ba_residents(p_building uuid) returns jsonb
language sql stable security invoker set search_path = '' as $$select app.ba_residents(p_building)$$;
create function public.ba_set_admin(p_member uuid,p_admin boolean) returns void
language sql volatile security invoker set search_path = '' as $$select app.ba_set_admin(p_member,p_admin)$$;
create function public.ba_console(p_kind text,p_query text default '',p_offset integer default 0) returns jsonb
language sql stable security invoker set search_path = '' as $$select app.ba_console(p_kind,p_query,p_offset)$$;
create function public.ba_console_action(p_action text,p_id uuid,p_note text) returns void
language sql volatile security invoker set search_path = '' as $$select app.ba_console_action(p_action,p_id,p_note)$$;
revoke all on function app.ba_require_platform(),app.ba_residents(uuid),app.ba_set_admin(uuid,boolean),app.ba_console(text,text,integer),app.ba_console_action(text,uuid,text),
 public.ba_residents(uuid),public.ba_set_admin(uuid,boolean),public.ba_console(text,text,integer),public.ba_console_action(text,uuid,text) from public,anon,authenticated;
grant execute on function app.ba_residents(uuid),app.ba_set_admin(uuid,boolean),app.ba_console(text,text,integer),app.ba_console_action(text,uuid,text),
 public.ba_residents(uuid),public.ba_set_admin(uuid,boolean),public.ba_console(text,text,integer),public.ba_console_action(text,uuid,text) to authenticated;

create or replace function app.ba_state() returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare u uuid := app.require_user();
begin
  perform app.require_terms();
  return jsonb_build_object(
    'is_platform_admin', app.is_platform_admin(),
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
