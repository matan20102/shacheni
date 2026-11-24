-- Private inquiries to the committee show in the bell: a new inquiry (or a
-- resident writing again) for the committee, and the committee's answer for the
-- resident. Only the subject is shown, never the message. Same as before
-- otherwise.

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
      'entrances', coalesce(s.entrance_count, 1), 'code', b.join_code,
      'open_reports', case when m.is_building_admin then (select count(*) from public.board_report r
        where r.building_id = b.id and r.status = 'open') else 0 end,
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
    -- Board and parking updates need a current membership; a declined request or
    -- a removal is exactly the update a former member still has to see.
    'notifications', coalesce((select jsonb_agg(x.data order by x.created_at desc, x.id) from (
      select n.id, n.created_at, jsonb_build_object(
        'id', n.id, 'type', n.type, 'building_id', n.building_id, 'building_name', b.name,
        'entity_id', n.entity_id, 'created_at', n.created_at,
        'text', case
          when n.type in ('board.reply', 'board.report') then
            (select left(bp.body, 80) from public.board_post bp where bp.id = n.entity_id and bp.deleted_at is null)
          when n.type like 'parking.%' then
            (select coalesce(cs.removed_label, ps.label) from public.community_parking_offer o
              join public.community_parking_space cs on cs.space_id = o.space_id
              join public.parking_space ps on ps.id = o.space_id where o.id = n.entity_id)
          when n.type in ('committee.inquiry', 'committee.inquiry_reply') then
            (select i.subject from public.committee_inquiry i where i.id = n.entity_id) end,
        'starts_at', case when n.type like 'parking.%' then
          (select o.starts_at from public.community_parking_offer o where o.id = n.entity_id) end) data
      from public.notification n join public.building b on b.id = n.building_id
      where n.user_id = u and n.read_at is null
        and n.type in ('community.application_rejected', 'community.member_removed', 'board.reply',
          'board.report', 'parking.booked', 'parking.booking_cancelled', 'parking.offer_cancelled',
          'committee.inquiry', 'committee.inquiry_reply')
        and (n.type in ('community.application_rejected', 'community.member_removed')
          or (b.status = 'active' and exists(select 1 from public.community_member m
            where m.building_id = n.building_id and m.user_id = u and m.status = 'approved'
              and (n.type <> 'board.report' or m.is_building_admin)
              -- A new inquiry is for whoever is on the committee now; a deleted
              -- inquiry (its author deleted the account) leaves no update behind.
              and (n.type <> 'committee.inquiry' or m.is_building_admin or m.is_committee)
              and (n.type not in ('committee.inquiry', 'committee.inquiry_reply')
                or exists(select 1 from public.committee_inquiry i where i.id = n.entity_id)))))
      order by n.created_at desc, n.id limit 50) x), '[]'),
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
