-- Only an actual acceptance is an unread update for the applicant.
-- Incoming requests remain actionable for their building/apartment managers.
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


create function app.ba_read_approval_updates(p_ids uuid[]) returns void
language plpgsql volatile security definer set search_path = '' as $$
declare u uuid := app.require_user();
begin
  perform app.require_terms();
  if p_ids is null or coalesce(cardinality(p_ids), 0) > 100 then raise exception 'INVALID_ARGUMENT'; end if;
  update public.notification set read_at = now()
    where id = any(p_ids) and user_id = u and type = 'community.application_approved' and read_at is null;
end $$;
create function public.ba_read_approval_updates(p_ids uuid[]) returns void
language sql volatile security invoker set search_path = '' as $$ select app.ba_read_approval_updates(p_ids) $$;
revoke all on function app.ba_read_approval_updates(uuid[]), public.ba_read_approval_updates(uuid[]) from public, anon, authenticated;
grant execute on function app.ba_read_approval_updates(uuid[]), public.ba_read_approval_updates(uuid[]) to authenticated;
