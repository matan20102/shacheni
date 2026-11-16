-- Managers can decline a join request and remove a resident. Removal follows the
-- same household succession as leaving, so an apartment never loses its approver.

-- Ends one approved membership. The caller holds the building lock.
create function app.ba_detach_member(p_member uuid, p_status text, p_action text) returns void
language plpgsql volatile security definer set search_path = '' as $$
declare m public.community_member; successor uuid;
begin
  select * into strict m from public.community_member where id = p_member for update;
  perform 1 from public.apartment where id = m.apartment_id for update;
  update public.community_member set status = p_status, is_building_admin = false,
    is_committee = false, is_apartment_admin = false, updated_at = now() where id = m.id;
  if m.is_apartment_admin then
    select id into successor from public.community_member
      where apartment_id = m.apartment_id and status = 'approved' order by created_at, id limit 1;
    if successor is not null then
      update public.community_member set is_apartment_admin = true, updated_at = now() where id = successor;
      perform app.audit(m.building_id, 'community.apartment_admin_succession', 'community_member', successor);
    else
      update public.community_member set requires_apartment_approval = false,
        building_approved = false, apartment_approved = false,
        building_approved_by = null, apartment_approved_by = null, updated_at = now()
        where apartment_id = m.apartment_id and status = 'pending';
    end if;
  end if;
  -- The former resident can no longer cancel; reopen the neighbours' parking windows.
  with freed as (
    update public.community_parking_booking bk set status = 'cancelled', cancelled_at = now(),
      cancelled_by = coalesce((select auth.uid()), m.user_id)
      from public.community_parking_offer o
      where o.id = bk.offer_id and o.ends_at > now() and bk.requester_id = m.user_id
        and bk.building_id = m.building_id and bk.status = 'confirmed'
      returning bk.offer_id)
  update public.community_parking_offer o set status = 'available'
    from freed where o.id = freed.offer_id and o.status = 'booked';
  perform app.audit(m.building_id, p_action, 'community_member', m.id);
end $$;

create function app.ba_reject(p_member uuid) returns void
language plpgsql volatile security definer set search_path = '' as $$
declare b uuid; m public.community_member;
begin
  perform app.require_user(); perform app.require_terms();
  select building_id into b from public.community_member where id = p_member;
  if b is null then raise exception 'ACCESS_DENIED'; end if;
  -- Same lock order as submit and approve: building, then member.
  perform 1 from public.building where id = b and status = 'active' for update;
  if not found then raise exception 'ACCESS_DENIED'; end if;
  select * into m from public.community_member where id = p_member for update;
  if not (app.ba_admin(b) or app.ba_apartment_admin(m.apartment_id)) then raise exception 'ACCESS_DENIED'; end if;
  if m.status <> 'pending' then raise exception 'INVALID_STATE'; end if;
  update public.community_member set status = 'rejected', building_approved = false, apartment_approved = false,
    building_approved_by = null, apartment_approved_by = null, requested_household_name = null,
    updated_at = now() where id = p_member;
  perform app.notify(m.user_id, b, 'community.application_rejected', '{}', '/home', p_member);
  perform app.audit(b, 'community.reject', 'community_member', p_member);
end $$;

create function app.ba_remove_member(p_member uuid) returns void
language plpgsql volatile security definer set search_path = '' as $$
declare u uuid := app.require_user(); b uuid; m public.community_member;
begin
  perform app.require_terms();
  select building_id into b from public.community_member where id = p_member;
  if b is null then raise exception 'ACCESS_DENIED'; end if;
  perform 1 from public.building where id = b and status = 'active' for update;
  if not found or not app.ba_admin(b) then raise exception 'ACCESS_DENIED'; end if;
  select * into m from public.community_member where id = p_member for update;
  if m.status <> 'approved' then raise exception 'INVALID_STATE'; end if;
  -- Leaving has its own flow, and a manager's role is revoked before removal.
  if m.user_id = u then raise exception 'INVALID_ARGUMENT'; end if;
  if m.is_building_admin then raise exception 'MEMBER_IS_ADMIN'; end if;
  perform app.ba_detach_member(p_member, 'rejected', 'community.member_removed');
  perform app.notify(m.user_id, b, 'community.member_removed', '{}', '/home', p_member);
end $$;

create function public.ba_reject(p_member uuid) returns void
language sql volatile security invoker set search_path = '' as $$ select app.ba_reject(p_member) $$;
create function public.ba_remove_member(p_member uuid) returns void
language sql volatile security invoker set search_path = '' as $$ select app.ba_remove_member(p_member) $$;
revoke all on function app.ba_detach_member(uuid, text, text), app.ba_reject(uuid), public.ba_reject(uuid),
  app.ba_remove_member(uuid), public.ba_remove_member(uuid) from public, anon, authenticated;
grant execute on function app.ba_reject(uuid), public.ba_reject(uuid),
  app.ba_remove_member(uuid), public.ba_remove_member(uuid) to authenticated;
