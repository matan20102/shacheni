-- Cover complete composite foreign keys while replacing narrower indexes.
-- Keep the booking lookup scoped to both resource and building.
create index community_parking_space_apartment_building_idx on public.community_parking_space(apartment_id,building_id);
drop index public.community_parking_space_apartment_idx;
create index community_parking_offer_space_building_idx on public.community_parking_offer(space_id,building_id);
drop index public.community_parking_offer_space_idx;
create index community_parking_booking_offer_building_idx on public.community_parking_booking(offer_id,building_id,created_at desc);
drop index public.community_parking_booking_offer_idx;

create or replace function app.ba_parking(p_building uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare a uuid; u uuid:=app.require_user();
begin
  perform app.require_terms();
  if not app.ba_resident(p_building) then raise exception 'ACCESS_DENIED'; end if;
  select apartment_id into a from public.community_member where building_id=p_building and user_id=u and status='approved';
  return jsonb_build_object(
    'spaces',coalesce((select jsonb_agg(jsonb_build_object('id',s.space_id,'label',p.label,'level',coalesce(p.level,''),'notes',coalesce(p.notes,'')) order by p.label)
      from public.community_parking_space s join public.parking_space p on p.id=s.space_id where s.building_id=p_building and s.apartment_id=a),'[]'),
    'offers',coalesce((select jsonb_agg(row.data order by row.starts_at,row.id) from (
      select o.id,o.starts_at,jsonb_build_object(
        'id',o.id,'space_id',o.space_id,'label',p.label,'level',coalesce(p.level,''),'notes',coalesce(p.notes,''),
        'apartment',coalesce(d.number,apt.number),'starts_at',o.starts_at,'ends_at',o.ends_at,'status',o.status,
        'own_space',s.apartment_id=a,'my_booking',r.requester_id=u,'booking_status',r.status,
        'booker_name',case when s.apartment_id=a or r.requester_id=u then profile.full_name else null end,
        'can_book',o.status='available' and s.apartment_id<>a and exists(select 1 from public.community_member m where m.apartment_id=s.apartment_id and m.status='approved'),
        'can_cancel',o.status<>'cancelled' and (s.apartment_id=a or (r.requester_id=u and r.status='confirmed'))
      ) data
      from public.community_parking_offer o join public.community_parking_space s on s.space_id=o.space_id
      join public.parking_space p on p.id=s.space_id join public.apartment apt on apt.id=s.apartment_id
      left join public.community_apartment d on d.apartment_id=apt.id
      left join lateral (select * from public.community_parking_booking bk where bk.offer_id=o.id and bk.building_id=o.building_id
        and (bk.status='confirmed' or bk.requester_id=u) order by (bk.status='confirmed') desc,bk.created_at desc,bk.id limit 1) r on true
      left join public.profile profile on profile.id=r.requester_id
      where o.building_id=p_building and o.ends_at>now()
        and (s.apartment_id=a or r.requester_id=u or (o.status='available' and exists(select 1 from public.community_member m where m.apartment_id=s.apartment_id and m.status='approved')))
      order by (s.apartment_id=a or r.requester_id=u) desc nulls last,o.starts_at,o.id limit 200
    ) row),'[]'));
end $$;
