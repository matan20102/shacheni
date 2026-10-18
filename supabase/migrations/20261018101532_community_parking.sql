-- Current community parking; legacy assignments and listings remain intact.
create table public.community_parking_space (
  space_id uuid primary key,
  building_id uuid not null,
  apartment_id uuid not null,
  label_key text not null,
  created_by uuid not null references public.profile(id),
  created_at timestamptz not null default now(),
  foreign key(space_id,building_id) references public.parking_space(id,building_id),
  foreign key(apartment_id,building_id) references public.apartment(id,building_id),
  unique(space_id,building_id), unique(building_id,label_key)
);
create index community_parking_space_apartment_idx on public.community_parking_space(apartment_id);
create index community_parking_space_creator_idx on public.community_parking_space(created_by);
create table public.community_parking_offer (
  id uuid primary key default gen_random_uuid(), building_id uuid not null, space_id uuid not null,
  starts_at timestamptz not null, ends_at timestamptz not null,
  status text not null default 'available' check(status in ('available','booked','cancelled')),
  created_by uuid not null references public.profile(id), created_at timestamptz not null default now(), cancelled_at timestamptz,
  foreign key(space_id,building_id) references public.community_parking_space(space_id,building_id),
  unique(id,building_id),
  check(ends_at>starts_at and ends_at-starts_at<=interval '90 days'),
  check((status='cancelled')=(cancelled_at is not null)),
  constraint community_parking_no_overlap exclude using gist (
    space_id with =, tstzrange(starts_at,ends_at,'[)') with &&
  ) where(status in ('available','booked'))
);
create index community_parking_offer_feed_idx on public.community_parking_offer(building_id,ends_at,starts_at);
create index community_parking_offer_space_idx on public.community_parking_offer(space_id);
create index community_parking_offer_creator_idx on public.community_parking_offer(created_by);
create table public.community_parking_booking (
  id uuid primary key default gen_random_uuid(), building_id uuid not null, offer_id uuid not null,
  requester_id uuid not null references public.profile(id),
  status text not null default 'confirmed' check(status in ('confirmed','cancelled')),
  created_at timestamptz not null default now(), cancelled_at timestamptz, cancelled_by uuid references public.profile(id),
  foreign key(offer_id,building_id) references public.community_parking_offer(id,building_id),
  check((status='cancelled')=(cancelled_at is not null and cancelled_by is not null))
);
create unique index community_parking_one_booking_idx on public.community_parking_booking(offer_id) where status='confirmed';
create index community_parking_booking_offer_idx on public.community_parking_booking(offer_id,created_at desc);
create index community_parking_booking_user_idx on public.community_parking_booking(requester_id,created_at desc);
create index community_parking_booking_cancelled_by_idx on public.community_parking_booking(cancelled_by);
-- RPC-only data. No direct table access; projections omit other residents' booking details.
alter table public.community_parking_space enable row level security;
alter table public.community_parking_offer enable row level security;
alter table public.community_parking_booking enable row level security;
revoke all on public.community_parking_space,public.community_parking_offer,public.community_parking_booking from public,anon,authenticated;

-- Same lock ordering as leave/archive: building first, then offer. Recheck authorization after lock.
create function app.ba_parking_actor(b uuid) returns uuid
language plpgsql volatile security definer set search_path='' as $$
declare u uuid:=app.require_user(); a uuid;
begin
  perform app.require_terms();
  perform 1 from public.building where id=b and status='active' for update;
  if not found or not app.ba_resident(b) then raise exception 'ACCESS_DENIED'; end if;
  select apartment_id into strict a from public.community_member where building_id=b and user_id=u and status='approved';
  return a;
end $$;
revoke all on function app.ba_parking_actor(uuid) from public,anon,authenticated;
create function app.ba_parking_add(p_building uuid,p_label text,p_level text,p_notes text) returns uuid
language plpgsql volatile security definer set search_path='' as $$
declare a uuid:=app.ba_parking_actor(p_building); s uuid; v_label text:=btrim(p_label);
begin
  if coalesce(char_length(v_label),0) not between 1 and 20 or char_length(coalesce(p_level,''))>20
    or char_length(coalesce(p_notes,''))>200 then raise exception 'INVALID_ARGUMENT'; end if;
  if exists(select 1 from public.parking_space p where p.building_id=p_building and lower(btrim(p.label))=lower(v_label))
    then raise exception 'PARKING_LABEL_TAKEN'; end if;
  insert into public.parking_space(building_id,label,level,notes) values(p_building,v_label,nullif(btrim(p_level),''),nullif(btrim(p_notes),'')) returning id into s;
  insert into public.community_parking_space(space_id,building_id,apartment_id,label_key,created_by)
    values(s,p_building,a,lower(v_label),auth.uid());
  perform app.audit(p_building,'community.parking_added','parking_space',s);
  return s;
exception when unique_violation then raise exception 'PARKING_LABEL_TAKEN';
end $$;
create function app.ba_parking_publish(p_space uuid,p_start timestamptz,p_end timestamptz) returns uuid
language plpgsql volatile security definer set search_path='' as $$
declare s public.community_parking_space; a uuid; o uuid;
begin
  select * into s from public.community_parking_space where space_id=p_space;
  a:=app.ba_parking_actor(s.building_id);
  if s.apartment_id<>a then raise exception 'ACCESS_DENIED'; end if;
  if p_start is null or p_end is null or p_start<now()-interval '5 minutes' or p_start>now()+interval '90 days'
    or p_end<=p_start or p_end<=now() or p_end-p_start>interval '90 days' then raise exception 'INVALID_TIME_RANGE'; end if;
  insert into public.community_parking_offer(building_id,space_id,starts_at,ends_at,created_by)
    values(s.building_id,p_space,p_start,p_end,auth.uid()) returning id into o;
  perform app.audit(s.building_id,'community.parking_published','community_parking_offer',o);
  return o;
exception when exclusion_violation then raise exception 'PARKING_OVERLAP';
end $$;
create function app.ba_parking_book(p_offer uuid) returns uuid
language plpgsql volatile security definer set search_path='' as $$
declare b uuid; a uuid; owner_apartment uuid; o public.community_parking_offer; booking uuid;
begin
  select building_id into b from public.community_parking_offer where id=p_offer;
  a:=app.ba_parking_actor(b);
  select * into strict o from public.community_parking_offer where id=p_offer for update;
  select apartment_id into owner_apartment from public.community_parking_space where space_id=o.space_id;
  if owner_apartment=a then raise exception 'OWN_PARKING'; end if;
  if o.ends_at<=now() then raise exception 'PARKING_EXPIRED'; end if;
  if not exists(select 1 from public.community_member where apartment_id=owner_apartment and status='approved')
    then raise exception 'PARKING_UNAVAILABLE'; end if;
  -- A network retry by the winner returns the original booking.
  select id into booking from public.community_parking_booking where offer_id=p_offer and status='confirmed' and requester_id=auth.uid();
  if booking is not null then return booking; end if;
  if o.status<>'available' then raise exception 'PARKING_UNAVAILABLE'; end if;
  insert into public.community_parking_booking(building_id,offer_id,requester_id) values(b,p_offer,auth.uid()) returning id into booking;
  update public.community_parking_offer set status='booked' where id=p_offer;
  perform app.audit(b,'community.parking_booked','community_parking_offer',p_offer);
  return booking;
end $$;
create function app.ba_parking_cancel(p_offer uuid) returns void
language plpgsql volatile security definer set search_path='' as $$
declare b uuid; a uuid; o public.community_parking_offer; owns boolean; booking public.community_parking_booking;
begin
  select building_id into b from public.community_parking_offer where id=p_offer;
  a:=app.ba_parking_actor(b);
  select * into strict o from public.community_parking_offer where id=p_offer for update;
  select apartment_id=a into owns from public.community_parking_space where space_id=o.space_id;
  select * into booking from public.community_parking_booking where offer_id=p_offer and status='confirmed' for update;
  if not owns and (booking.id is null or booking.requester_id<>auth.uid()) then raise exception 'ACCESS_DENIED'; end if;
  if o.ends_at<=now() then raise exception 'PARKING_EXPIRED'; end if;
  if o.status='cancelled' then return; end if;
  update public.community_parking_booking set status='cancelled',cancelled_at=now(),cancelled_by=auth.uid() where id=booking.id;
  update public.community_parking_offer set status=case when owns then 'cancelled' else 'available' end,
    cancelled_at=case when owns then now() else null end where id=p_offer;
  perform app.audit(b,case when owns then 'community.parking_offer_cancelled' else 'community.parking_booking_cancelled' end,'community_parking_offer',p_offer);
end $$;
create function app.ba_parking(p_building uuid) returns jsonb
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
      left join lateral (select * from public.community_parking_booking bk where bk.offer_id=o.id
        and (bk.status='confirmed' or bk.requester_id=u) order by (bk.status='confirmed') desc,bk.created_at desc,bk.id limit 1) r on true
      left join public.profile profile on profile.id=r.requester_id
      where o.building_id=p_building and o.ends_at>now()
        and (s.apartment_id=a or r.requester_id=u or (o.status='available' and exists(select 1 from public.community_member m where m.apartment_id=s.apartment_id and m.status='approved')))
      order by (s.apartment_id=a or r.requester_id=u) desc nulls last,o.starts_at,o.id limit 200
    ) row),'[]'));
end $$;
create function public.ba_parking(p_building uuid) returns jsonb language sql stable security invoker set search_path='' as $$select app.ba_parking(p_building)$$;
create function public.ba_parking_add(p_building uuid,p_label text,p_level text default '',p_notes text default '') returns uuid language sql volatile security invoker set search_path='' as $$select app.ba_parking_add(p_building,p_label,p_level,p_notes)$$;
create function public.ba_parking_publish(p_space uuid,p_start timestamptz,p_end timestamptz) returns uuid language sql volatile security invoker set search_path='' as $$select app.ba_parking_publish(p_space,p_start,p_end)$$;
create function public.ba_parking_book(p_offer uuid) returns uuid language sql volatile security invoker set search_path='' as $$select app.ba_parking_book(p_offer)$$;
create function public.ba_parking_cancel(p_offer uuid) returns void language sql volatile security invoker set search_path='' as $$select app.ba_parking_cancel(p_offer)$$;
revoke all on function app.ba_parking(uuid),public.ba_parking(uuid),app.ba_parking_add(uuid,text,text,text),public.ba_parking_add(uuid,text,text,text),app.ba_parking_publish(uuid,timestamptz,timestamptz),public.ba_parking_publish(uuid,timestamptz,timestamptz),app.ba_parking_book(uuid),public.ba_parking_book(uuid),app.ba_parking_cancel(uuid),public.ba_parking_cancel(uuid) from public,anon,authenticated;
grant execute on function app.ba_parking(uuid),public.ba_parking(uuid),app.ba_parking_add(uuid,text,text,text),public.ba_parking_add(uuid,text,text,text),app.ba_parking_publish(uuid,timestamptz,timestamptz),public.ba_parking_publish(uuid,timestamptz,timestamptz),app.ba_parking_book(uuid),public.ba_parking_book(uuid),app.ba_parking_cancel(uuid),public.ba_parking_cancel(uuid) to authenticated;
