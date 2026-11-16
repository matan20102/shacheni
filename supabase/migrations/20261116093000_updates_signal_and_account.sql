-- In-app updates for the bell, a per-building change signal for Realtime,
-- join-code rotation, and account deletion.

create index notification_entity_unread_idx on public.notification(user_id, type, entity_id) where read_at is null;

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
              join public.parking_space ps on ps.id = o.space_id where o.id = n.entity_id) end,
        'starts_at', case when n.type like 'parking.%' then
          (select o.starts_at from public.community_parking_offer o where o.id = n.entity_id) end) data
      from public.notification n join public.building b on b.id = n.building_id
      where n.user_id = u and n.read_at is null
        and n.type in ('community.application_rejected', 'community.member_removed', 'board.reply',
          'board.report', 'parking.booked', 'parking.booking_cancelled', 'parking.offer_cancelled')
        and (n.type in ('community.application_rejected', 'community.member_removed')
          or (b.status = 'active' and exists(select 1 from public.community_member m
            where m.building_id = n.building_id and m.user_id = u and m.status = 'approved'
              and (n.type <> 'board.report' or m.is_building_admin))))
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

create function app.ba_read_notifications(p_ids uuid[]) returns void
language plpgsql volatile security definer set search_path = '' as $$
declare u uuid := app.require_user();
begin
  if p_ids is null or coalesce(cardinality(p_ids), 0) > 100 then raise exception 'INVALID_ARGUMENT'; end if;
  update public.notification set read_at = now()
    where id = any(p_ids) and user_id = u and read_at is null
      and type in ('community.application_rejected', 'community.member_removed', 'board.reply',
        'board.report', 'parking.booked', 'parking.booking_cancelled', 'parking.offer_cancelled');
end $$;

create function app.ba_rotate_code(p_building uuid) returns text
language plpgsql volatile security definer set search_path = '' as $$
declare code text;
begin
  perform app.require_user(); perform app.require_terms();
  perform 1 from public.building where id = p_building and status = 'active' for update;
  if not found or not app.ba_admin(p_building) then raise exception 'ACCESS_DENIED'; end if;
  code := app.new_join_code();
  update public.building set join_code = code, join_code_rotated_at = now() where id = p_building;
  perform app.audit(p_building, 'community.join_code_rotated', 'building', p_building);
  return code;
end $$;

-- One counter row per building. Residents subscribe to it over Realtime and
-- reload through the usual RPCs, so no board, member or parking row is exposed.
create table public.community_signal (
  building_id uuid primary key references public.building(id),
  version bigint not null default 1,
  updated_at timestamptz not null default now()
);
alter table public.community_signal enable row level security;
revoke all on public.community_signal from public, anon, authenticated;
grant select on public.community_signal to authenticated;
create policy community_signal_read on public.community_signal for select to authenticated
  using (app.ba_resident(building_id));

create function app.ba_touch_signal() returns trigger
language plpgsql volatile security definer set search_path = '' as $$
declare b uuid := case when tg_op = 'DELETE' then old.building_id else new.building_id end;
begin
  insert into public.community_signal(building_id) values(b)
    on conflict (building_id) do update set version = public.community_signal.version + 1, updated_at = now();
  return null;
end $$;
revoke all on function app.ba_touch_signal() from public, anon, authenticated;

create trigger board_post_signal after insert or update or delete on public.board_post
  for each row execute function app.ba_touch_signal();
create trigger board_reply_signal after insert or update or delete on public.board_reply
  for each row execute function app.ba_touch_signal();
create trigger board_reaction_signal after insert or update or delete on public.board_reaction
  for each row execute function app.ba_touch_signal();
create trigger board_report_signal after insert or update or delete on public.board_report
  for each row execute function app.ba_touch_signal();
create trigger community_member_signal after insert or update or delete on public.community_member
  for each row execute function app.ba_touch_signal();
create trigger community_parking_offer_signal after insert or update or delete on public.community_parking_offer
  for each row execute function app.ba_touch_signal();
create trigger community_parking_booking_signal after insert or update or delete on public.community_parking_booking
  for each row execute function app.ba_touch_signal();

do $$ begin
  if exists(select 1 from pg_publication where pubname = 'supabase_realtime') then
    alter publication supabase_realtime add table public.community_signal;
  end if;
end $$;

-- Deleting an account removes the person and what they wrote. The profile row
-- stays as an empty tombstone because audit and consent records point at it,
-- and the sign-in identity is detached so a later sign-in starts a new account.
create function app.ba_delete_account() returns void
language plpgsql volatile security definer set search_path = '' as $$
declare u uuid := app.require_user(); m record; current public.community_member; active boolean;
begin
  for m in select cm.id, cm.building_id from public.community_member cm
      where cm.user_id = u and cm.status in ('pending', 'approved') order by cm.building_id loop
    -- Same lock order as every membership flow: building, then member.
    select status = 'active' into active from public.building where id = m.building_id for update;
    select * into current from public.community_member where id = m.id for update;
    if current.status = 'pending' then
      update public.community_member set status = 'withdrawn', requested_household_name = null, updated_at = now() where id = m.id;
      perform app.audit(m.building_id, 'community.withdraw', 'community_member', m.id);
    elsif current.status = 'approved' then
      if active and current.is_building_admin and not exists(select 1 from public.community_member
          where building_id = m.building_id and status = 'approved' and is_building_admin and id <> m.id) then
        if exists(select 1 from public.community_member
            where building_id = m.building_id and status = 'approved' and id <> m.id) then
          raise exception 'LAST_BUILDING_ADMIN';
        end if;
        -- Nobody else lives here: the building is archived with its only resident.
        update public.community_settings set archived_at = now() where building_id = m.building_id;
        update public.building set status = 'suspended' where id = m.building_id;
        perform app.audit(m.building_id, 'community.archive', 'building', m.building_id);
      end if;
      perform app.ba_detach_member(m.id, 'withdrawn', 'community.leave');
    end if;
  end loop;
  update public.board_report set status = 'removed', resolved_at = now(), resolved_by = u
    where status = 'open' and (post_id in (select id from public.board_post where author_id = u and deleted_at is null)
      or reply_id in (select id from public.board_reply where author_id = u and deleted_at is null));
  update public.board_report set status = 'dismissed', resolved_at = now(), resolved_by = u
    where status = 'open' and reporter_id = u;
  update public.board_post set deleted_at = now(), updated_at = now() where author_id = u and deleted_at is null;
  update public.board_reply set deleted_at = now() where author_id = u and deleted_at is null;
  delete from public.board_reaction where user_id = u;
  delete from public.notification where user_id = u;
  delete from public.device_token where user_id = u;
  delete from public.platform_admin where user_id = u;
  update public.profile set full_name = '', phone_e164 = null, avatar_url = null,
    deleted_at = now(), updated_at = now() where id = u;
  perform app.audit(null, 'account.delete', 'profile', u);
  delete from auth.sessions where user_id = u;
  delete from auth.identities where user_id = u;
  update auth.users set email = null, phone = null, raw_user_meta_data = '{}'::jsonb, deleted_at = now() where id = u;
end $$;

create function public.ba_read_notifications(p_ids uuid[]) returns void
  language sql volatile security invoker set search_path = '' as $$ select app.ba_read_notifications(p_ids) $$;
create function public.ba_rotate_code(p_building uuid) returns text
  language sql volatile security invoker set search_path = '' as $$ select app.ba_rotate_code(p_building) $$;
create function public.ba_delete_account() returns void
  language sql volatile security invoker set search_path = '' as $$ select app.ba_delete_account() $$;
revoke all on function app.ba_read_notifications(uuid[]), public.ba_read_notifications(uuid[]),
  app.ba_rotate_code(uuid), public.ba_rotate_code(uuid),
  app.ba_delete_account(), public.ba_delete_account() from public, anon, authenticated;
grant execute on function app.ba_read_notifications(uuid[]), public.ba_read_notifications(uuid[]),
  app.ba_rotate_code(uuid), public.ba_rotate_code(uuid),
  app.ba_delete_account(), public.ba_delete_account() to authenticated;
