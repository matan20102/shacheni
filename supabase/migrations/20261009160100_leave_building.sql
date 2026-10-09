-- leave_building: an approved resident leaves (moving out). Afterwards they can join another
-- building (or this one again) with a fresh application and approval.
--   blocked  while anything is in progress with a neighbor (ACTIVE_COMMITMENTS)
--   cleaned  parking assignments end; own open listings / package requests / pending booking
--            requests / pending offers are cancelled
--   kept     history, ratings, transactions; a building-admin role is separate and stays

create function public.leave_building()
returns void language plpgsql volatile security definer set search_path = ''
as $$
declare
  uid uuid := app.require_user();
  m public.building_membership;
begin
  select * into m from public.building_membership
  where user_id = uid and status = 'approved' for update;
  if not found then
    raise exception 'NOT_A_RESIDENT';
  end if;

  if exists (select 1 from public.transactions t
             where t.building_id = m.building_id and uid in (t.payer_id, t.payee_id)
               and t.status in ('in_progress', 'awaiting_settlement', 'disputed'))
     or exists (select 1 from public.parking_reservation r
                where r.building_id = m.building_id and uid in (r.owner_id, r.requester_id)
                  and r.status in ('accepted', 'confirmed', 'active'))
     or exists (select 1 from public.delivery_request d
                where d.building_id = m.building_id and d.requester_id = uid
                  and d.status in ('accepted', 'collected', 'delivered', 'disputed'))
     or exists (select 1 from public.delivery_request d
                join public.delivery_offer o on o.id = d.accepted_offer_id
                where d.building_id = m.building_id and o.helper_id = uid
                  and d.status in ('accepted', 'collected', 'delivered', 'disputed'))
  then
    raise exception 'ACTIVE_COMMITMENTS';
  end if;

  -- Requests to my listings, then the listings themselves
  update public.parking_reservation r
  set status = 'cancelled', cancelled_at = now(), cancelled_by = uid, cancel_reason = 'owner left the building'
  where r.building_id = m.building_id and r.owner_id = uid and r.status = 'requested';
  update public.parking_listing
  set status = 'cancelled', cancelled_at = now(), cancel_reason = 'owner left the building'
  where building_id = m.building_id and owner_id = uid and status in ('available', 'reserved');
  -- My pending booking requests
  update public.parking_reservation
  set status = 'cancelled', cancelled_at = now(), cancelled_by = uid, cancel_reason = 'requester left the building'
  where building_id = m.building_id and requester_id = uid and status = 'requested';
  -- My open package requests (and the offers on them), my pending offers
  update public.delivery_offer o
  set status = 'expired', responded_at = now()
  from public.delivery_request d
  where o.request_id = d.id and d.building_id = m.building_id and d.requester_id = uid
    and d.status in ('open', 'offer_received') and o.status = 'pending';
  update public.delivery_request
  set status = 'cancelled', cancelled_at = now(), cancelled_by = uid, cancel_reason = 'requester left the building'
  where building_id = m.building_id and requester_id = uid and status in ('open', 'offer_received');
  update public.delivery_offer
  set status = 'withdrawn', responded_at = now()
  where building_id = m.building_id and helper_id = uid and status = 'pending';
  -- Parking: end what I hold, drop what I asked for
  update public.parking_assignment
  set status = 'ended', ended_at = now(), ended_by = uid, end_reason = 'left the building'
  where membership_id = m.id and status = 'active';
  update public.parking_assignment set status = 'withdrawn'
  where membership_id = m.id and status = 'requested';

  update public.building_membership set status = 'left' where id = m.id;
  insert into public.membership_event (building_id, membership_id, actor_id, type)
  values (m.building_id, m.id, uid, 'left');
  perform app.notify_building_admins(m.building_id, 'membership.left',
    jsonb_build_object('name', (select full_name from public.profile where id = uid)), '/admin/residents', m.id);
end
$$;

revoke execute on function public.leave_building() from public, anon;
grant execute on function public.leave_building() to authenticated;

-- Applications list: residents who left are history, not applications.
create or replace function public.admin_list_applications(p_building uuid)
returns jsonb language plpgsql stable security definer set search_path = ''
as $$
declare
  uid uuid := app.require_user();
begin
  if not app.is_building_admin(p_building) then
    raise exception 'NOT_BUILDING_ADMIN';
  end if;
  return coalesce((
    select jsonb_agg(row_to_json(r)::jsonb order by r.submitted_at desc)
    from (
      select m.id, m.user_id, p.full_name, p.phone_e164 as phone, a.number as apartment, m.status,
             m.updated_at as submitted_at, m.applicant_note, m.info_request_message, m.info_response,
             m.status_reason, m.flags, (m.user_id = uid) as is_self,
             (select count(*) from public.building_membership o
              where o.apartment_id = m.apartment_id and o.status = 'approved' and o.id <> m.id) as apartment_residents,
             coalesce((
               select jsonb_agg(jsonb_build_object(
                 'assignment_id', pa.id, 'space_id', s.id, 'label', s.label, 'status', pa.status,
                 'held_by_other', exists (select 1 from public.parking_assignment x
                                          where x.parking_space_id = s.id and x.status = 'active'
                                            and x.membership_id <> m.id)) order by s.label)
               from public.parking_assignment pa
               join public.parking_space s on s.id = pa.parking_space_id
               where pa.membership_id = m.id and pa.status in ('requested', 'active', 'rejected')), '[]') as spaces
      from public.building_membership m
      join public.profile p on p.id = m.user_id
      join public.apartment a on a.id = m.apartment_id
      where m.building_id = p_building and m.status not in ('withdrawn', 'left')
    ) r), '[]');
end
$$;
