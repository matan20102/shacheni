-- Parking: edit and remove a space, publish several windows at once, a history
-- view, and updates to the other household when a window is booked or cancelled.

alter table public.community_parking_space add column removed_at timestamptz, add column removed_label text;

create or replace function app.ba_parking_add(p_building uuid, p_label text, p_level text, p_notes text) returns uuid
language plpgsql volatile security definer set search_path = '' as $$
declare a uuid := app.ba_parking_actor(p_building); s uuid; v_label text := btrim(p_label);
begin
  if coalesce(char_length(v_label), 0) not between 1 and 20 or char_length(coalesce(p_level, '')) > 20
    or char_length(coalesce(p_notes, '')) > 200 or position('~' in v_label) > 0 then raise exception 'INVALID_ARGUMENT'; end if;
  if exists(select 1 from public.parking_space p where p.building_id = p_building and lower(btrim(p.label)) = lower(v_label))
    then raise exception 'PARKING_LABEL_TAKEN'; end if;
  insert into public.parking_space(building_id, label, level, notes)
    values(p_building, v_label, nullif(btrim(p_level), ''), nullif(btrim(p_notes), '')) returning id into s;
  insert into public.community_parking_space(space_id, building_id, apartment_id, label_key, created_by)
    values(s, p_building, a, lower(v_label), auth.uid());
  perform app.audit(p_building, 'community.parking_added', 'parking_space', s);
  return s;
exception when unique_violation then raise exception 'PARKING_LABEL_TAKEN';
end $$;

create function app.ba_parking_update(p_space uuid, p_label text, p_level text, p_notes text) returns void
language plpgsql volatile security definer set search_path = '' as $$
declare s public.community_parking_space; a uuid; v_label text := btrim(p_label);
begin
  select * into s from public.community_parking_space where space_id = p_space and removed_at is null;
  a := app.ba_parking_actor(s.building_id);
  if s.apartment_id <> a then raise exception 'ACCESS_DENIED'; end if;
  if coalesce(char_length(v_label), 0) not between 1 and 20 or char_length(coalesce(p_level, '')) > 20
    or char_length(coalesce(p_notes, '')) > 200 or position('~' in v_label) > 0 then raise exception 'INVALID_ARGUMENT'; end if;
  if exists(select 1 from public.parking_space p where p.building_id = s.building_id and p.id <> p_space
    and lower(btrim(p.label)) = lower(v_label)) then raise exception 'PARKING_LABEL_TAKEN'; end if;
  update public.parking_space set label = v_label, level = nullif(btrim(p_level), ''),
    notes = nullif(btrim(p_notes), '') where id = p_space;
  update public.community_parking_space set label_key = lower(v_label) where space_id = p_space;
  perform app.audit(s.building_id, 'community.parking_updated', 'parking_space', p_space);
exception when unique_violation then raise exception 'PARKING_LABEL_TAKEN';
end $$;

-- Past windows stay as history, so the space is retired and its label is freed.
create function app.ba_parking_remove(p_space uuid) returns void
language plpgsql volatile security definer set search_path = '' as $$
declare s public.community_parking_space; a uuid; retired text;
begin
  select * into s from public.community_parking_space where space_id = p_space and removed_at is null;
  a := app.ba_parking_actor(s.building_id);
  if s.apartment_id <> a then raise exception 'ACCESS_DENIED'; end if;
  if exists(select 1 from public.community_parking_offer o
    where o.space_id = p_space and o.status = 'booked' and o.ends_at > now())
    then raise exception 'PARKING_HAS_BOOKING'; end if;
  update public.community_parking_offer set status = 'cancelled', cancelled_at = now()
    where space_id = p_space and status = 'available' and ends_at > now();
  retired := left(s.label_key, 11) || '~' || left(p_space::text, 8);
  update public.community_parking_space cs set removed_at = now(), label_key = retired,
    removed_label = (select label from public.parking_space where id = p_space) where cs.space_id = p_space;
  update public.parking_space set is_active = false, label = retired where id = p_space;
  perform app.audit(s.building_id, 'community.parking_removed', 'parking_space', p_space);
end $$;

create or replace function app.ba_parking_publish(p_space uuid, p_start timestamptz, p_end timestamptz) returns uuid
language plpgsql volatile security definer set search_path = '' as $$
declare s public.community_parking_space; a uuid; o uuid;
begin
  select * into s from public.community_parking_space where space_id = p_space and removed_at is null;
  a := app.ba_parking_actor(s.building_id);
  if s.apartment_id <> a then raise exception 'ACCESS_DENIED'; end if;
  if p_start is null or p_end is null or p_start < now() - interval '5 minutes' or p_start > now() + interval '90 days'
    or p_end <= p_start or p_end <= now() or p_end - p_start > interval '90 days' then raise exception 'INVALID_TIME_RANGE'; end if;
  insert into public.community_parking_offer(building_id, space_id, starts_at, ends_at, created_by)
    values(s.building_id, p_space, p_start, p_end, auth.uid()) returning id into o;
  perform app.audit(s.building_id, 'community.parking_published', 'community_parking_offer', o);
  return o;
exception when exclusion_violation then raise exception 'PARKING_OVERLAP';
end $$;

-- A repeating availability is sent as concrete windows, so the device's own
-- time zone decides what "every weekday at 08:00" means. All or nothing.
create function app.ba_parking_publish_series(p_space uuid, p_starts timestamptz[], p_ends timestamptz[]) returns integer
language plpgsql volatile security definer set search_path = '' as $$
declare n integer := coalesce(cardinality(p_starts), 0);
begin
  if n < 1 or n > 31 or n <> coalesce(cardinality(p_ends), 0) then raise exception 'INVALID_ARGUMENT'; end if;
  for i in 1..n loop
    perform app.ba_parking_publish(p_space, p_starts[i], p_ends[i]);
  end loop;
  return n;
end $$;

create or replace function app.ba_parking_book(p_offer uuid) returns uuid
language plpgsql volatile security definer set search_path = '' as $$
declare b uuid; a uuid; owner_apartment uuid; o public.community_parking_offer; booking uuid;
begin
  select building_id into b from public.community_parking_offer where id = p_offer;
  a := app.ba_parking_actor(b);
  select * into strict o from public.community_parking_offer where id = p_offer for update;
  select apartment_id into owner_apartment from public.community_parking_space where space_id = o.space_id;
  if owner_apartment = a then raise exception 'OWN_PARKING'; end if;
  if o.ends_at <= now() then raise exception 'PARKING_EXPIRED'; end if;
  if not exists(select 1 from public.community_member where apartment_id = owner_apartment and status = 'approved')
    then raise exception 'PARKING_UNAVAILABLE'; end if;
  -- A network retry by the winner returns the original booking.
  select id into booking from public.community_parking_booking where offer_id = p_offer and status = 'confirmed' and requester_id = auth.uid();
  if booking is not null then return booking; end if;
  if o.status <> 'available' then raise exception 'PARKING_UNAVAILABLE'; end if;
  insert into public.community_parking_booking(building_id, offer_id, requester_id) values(b, p_offer, auth.uid()) returning id into booking;
  update public.community_parking_offer set status = 'booked' where id = p_offer;
  perform app.notify(cm.user_id, b, 'parking.booked', '{}', '/parking', p_offer)
    from public.community_member cm where cm.apartment_id = owner_apartment and cm.status = 'approved';
  perform app.audit(b, 'community.parking_booked', 'community_parking_offer', p_offer);
  return booking;
end $$;

create or replace function app.ba_parking_cancel(p_offer uuid) returns void
language plpgsql volatile security definer set search_path = '' as $$
declare b uuid; a uuid; o public.community_parking_offer; owns boolean; owner_apartment uuid;
  booking public.community_parking_booking;
begin
  select building_id into b from public.community_parking_offer where id = p_offer;
  a := app.ba_parking_actor(b);
  select * into strict o from public.community_parking_offer where id = p_offer for update;
  select apartment_id into owner_apartment from public.community_parking_space where space_id = o.space_id;
  owns := owner_apartment = a;
  select * into booking from public.community_parking_booking where offer_id = p_offer and status = 'confirmed' for update;
  if not owns and (booking.id is null or booking.requester_id <> auth.uid()) then raise exception 'ACCESS_DENIED'; end if;
  if o.ends_at <= now() then raise exception 'PARKING_EXPIRED'; end if;
  if o.status = 'cancelled' then return; end if;
  update public.community_parking_booking set status = 'cancelled', cancelled_at = now(), cancelled_by = auth.uid() where id = booking.id;
  update public.community_parking_offer set status = case when owns then 'cancelled' else 'available' end,
    cancelled_at = case when owns then now() else null end where id = p_offer;
  if owns and booking.id is not null then
    perform app.notify(booking.requester_id, b, 'parking.offer_cancelled', '{}', '/parking', p_offer);
  elsif not owns then
    perform app.notify(cm.user_id, b, 'parking.booking_cancelled', '{}', '/parking', p_offer)
      from public.community_member cm where cm.apartment_id = owner_apartment and cm.status = 'approved';
  end if;
  perform app.audit(b, case when owns then 'community.parking_offer_cancelled' else 'community.parking_booking_cancelled' end, 'community_parking_offer', p_offer);
end $$;

create or replace function app.ba_parking(p_building uuid) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare a uuid; u uuid := app.require_user();
begin
  perform app.require_terms();
  if not app.ba_resident(p_building) then raise exception 'ACCESS_DENIED'; end if;
  select apartment_id into a from public.community_member where building_id = p_building and user_id = u and status = 'approved';
  return jsonb_build_object(
    'spaces', coalesce((select jsonb_agg(jsonb_build_object('id', s.space_id, 'label', p.label, 'level', coalesce(p.level, ''), 'notes', coalesce(p.notes, '')) order by p.label)
      from public.community_parking_space s join public.parking_space p on p.id = s.space_id
      where s.building_id = p_building and s.apartment_id = a and s.removed_at is null), '[]'),
    'offers', coalesce((select jsonb_agg(row.data order by row.starts_at, row.id) from (
      select o.id, o.starts_at, jsonb_build_object(
        'id', o.id, 'space_id', o.space_id, 'label', coalesce(s.removed_label, p.label), 'level', coalesce(p.level, ''), 'notes', coalesce(p.notes, ''),
        'apartment', coalesce(d.number, apt.number), 'starts_at', o.starts_at, 'ends_at', o.ends_at, 'status', o.status,
        'own_space', s.apartment_id = a, 'my_booking', r.requester_id = u, 'booking_status', r.status,
        'booker_name', case when s.apartment_id = a or r.requester_id = u then profile.full_name else null end,
        'can_book', o.status = 'available' and s.apartment_id <> a and exists(select 1 from public.community_member m where m.apartment_id = s.apartment_id and m.status = 'approved'),
        'can_cancel', o.status <> 'cancelled' and (s.apartment_id = a or (r.requester_id = u and r.status = 'confirmed'))
      ) data
      from public.community_parking_offer o join public.community_parking_space s on s.space_id = o.space_id
      join public.parking_space p on p.id = s.space_id join public.apartment apt on apt.id = s.apartment_id
      left join public.community_apartment d on d.apartment_id = apt.id
      left join lateral (select * from public.community_parking_booking bk where bk.offer_id = o.id and bk.building_id = o.building_id
        and (bk.status = 'confirmed' or bk.requester_id = u) order by (bk.status = 'confirmed') desc, bk.created_at desc, bk.id limit 1) r on true
      left join public.profile profile on profile.id = r.requester_id
      where o.building_id = p_building and o.ends_at > now()
        and (s.apartment_id = a or r.requester_id = u or (o.status = 'available' and exists(select 1 from public.community_member m where m.apartment_id = s.apartment_id and m.status = 'approved')))
      order by (s.apartment_id = a or r.requester_id = u) desc nulls last, o.starts_at, o.id limit 200
    ) row), '[]'));
end $$;

-- Ended or cancelled windows of the caller's household, and the caller's own bookings.
create function app.ba_parking_history(p_building uuid) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare a uuid; u uuid := app.require_user();
begin
  perform app.require_terms();
  if not app.ba_resident(p_building) then raise exception 'ACCESS_DENIED'; end if;
  select apartment_id into a from public.community_member where building_id = p_building and user_id = u and status = 'approved';
  return coalesce((select jsonb_agg(x.data order by x.starts_at desc, x.id) from (
    select o.id, o.starts_at, jsonb_build_object(
      'id', o.id, 'label', coalesce(s.removed_label, p.label), 'apartment', coalesce(d.number, apt.number),
      'starts_at', o.starts_at, 'ends_at', o.ends_at, 'status', o.status,
      'own_space', s.apartment_id = a, 'booking_status', r.status,
      'booker_name', case when r.id is not null then coalesce(nullif(pf.full_name, ''), 'שכן') end) data
    from public.community_parking_offer o join public.community_parking_space s on s.space_id = o.space_id
    join public.parking_space p on p.id = s.space_id join public.apartment apt on apt.id = s.apartment_id
    left join public.community_apartment d on d.apartment_id = apt.id
    left join lateral (select * from public.community_parking_booking bk where bk.offer_id = o.id and bk.building_id = o.building_id
      and (s.apartment_id = a or bk.requester_id = u)
      order by (bk.status = 'confirmed') desc, bk.created_at desc, bk.id limit 1) r on true
    left join public.profile pf on pf.id = r.requester_id
    where o.building_id = p_building and (o.ends_at <= now() or o.status = 'cancelled')
      and (s.apartment_id = a or r.requester_id = u)
    order by o.starts_at desc, o.id limit 50) x), '[]');
end $$;

create function public.ba_parking_update(p_space uuid, p_label text, p_level text default '', p_notes text default '')
  returns void language sql volatile security invoker set search_path = '' as $$ select app.ba_parking_update(p_space, p_label, p_level, p_notes) $$;
create function public.ba_parking_remove(p_space uuid)
  returns void language sql volatile security invoker set search_path = '' as $$ select app.ba_parking_remove(p_space) $$;
create function public.ba_parking_publish_series(p_space uuid, p_starts timestamptz[], p_ends timestamptz[])
  returns integer language sql volatile security invoker set search_path = '' as $$ select app.ba_parking_publish_series(p_space, p_starts, p_ends) $$;
create function public.ba_parking_history(p_building uuid)
  returns jsonb language sql stable security invoker set search_path = '' as $$ select app.ba_parking_history(p_building) $$;

revoke all on function app.ba_parking_update(uuid, text, text, text), public.ba_parking_update(uuid, text, text, text),
  app.ba_parking_remove(uuid), public.ba_parking_remove(uuid),
  app.ba_parking_publish_series(uuid, timestamptz[], timestamptz[]), public.ba_parking_publish_series(uuid, timestamptz[], timestamptz[]),
  app.ba_parking_history(uuid), public.ba_parking_history(uuid) from public, anon, authenticated;
grant execute on function app.ba_parking_update(uuid, text, text, text), public.ba_parking_update(uuid, text, text, text),
  app.ba_parking_remove(uuid), public.ba_parking_remove(uuid),
  app.ba_parking_publish_series(uuid, timestamptz[], timestamptz[]), public.ba_parking_publish_series(uuid, timestamptz[], timestamptz[]),
  app.ba_parking_history(uuid), public.ba_parking_history(uuid) to authenticated;
