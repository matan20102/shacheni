-- Helper functions (schema `app`) and integrity triggers.
-- Spec: docs/PRD-data-security-architecture.md §9.5 (triggers), §9.6 (helpers), §12.5 (storage checks).
-- Errors are raised with a stable code as the message (mapped to localized text in the app).
-- All functions: `set search_path = ''` and fully qualified names.

-- =============================================================================================
-- Role & membership helpers (used by RLS policies → granted to authenticated)
-- =============================================================================================

create function app.is_platform_admin()
returns boolean language sql stable security definer set search_path = ''
as $$
  select exists (select 1 from public.platform_admin where user_id = (select auth.uid()))
$$;

-- Approved membership in b AND the building is active.
create function app.is_resident(b uuid)
returns boolean language sql stable security definer set search_path = ''
as $$
  select exists (
    select 1
    from public.building_membership m
    join public.building bl on bl.id = m.building_id
    where m.building_id = b
      and m.user_id = (select auth.uid())
      and m.status = 'approved'
      and bl.status = 'active')
$$;

-- The bare role (an unrevoked building_admin row), without the agreement gate.
-- Used by triggers, where the reviewer is a column value rather than the caller.
create function app.holds_building_admin_role(b uuid, u uuid)
returns boolean language sql stable security definer set search_path = ''
as $$
  select exists (
    select 1 from public.building_admin
    where building_id = b and user_id = u and revoked_at is null)
$$;

-- The version label in force for a document type. he/en share version labels; if they ever differ
-- (one locale published before the other), the most recently published one wins, so any new
-- publication triggers re-acceptance.
create function app.current_legal_version(t public.legal_doc_type)
returns text language sql stable security definer set search_path = ''
as $$
  select d.version from public.legal_document d
  where d.type = t and d.is_current
  order by d.effective_at desc, d.created_at desc
  limit 1
$$;

-- Has the caller accepted the current version of a legal document type (optionally for a building)?
create function app.has_accepted_current(t public.legal_doc_type, b uuid default null)
returns boolean language sql stable security definer set search_path = ''
as $$
  select exists (
    select 1 from public.legal_acceptance a
    where a.user_id = (select auth.uid())
      and a.document_type = t
      and a.building_id is not distinct from b
      and a.document_version = app.current_legal_version(t))
$$;

-- Admin powers = the role AND the current building agreement accepted for that building.
create function app.is_building_admin(b uuid)
returns boolean language sql stable security definer set search_path = ''
as $$
  select app.holds_building_admin_role(b, (select auth.uid()))
     and app.has_accepted_current('building_agreement', b)
$$;

create function app.my_building_ids()
returns setof uuid language sql stable security definer set search_path = ''
as $$
  select m.building_id
  from public.building_membership m
  join public.building bl on bl.id = m.building_id
  where m.user_id = (select auth.uid()) and m.status = 'approved' and bl.status = 'active'
$$;

-- Caller shares an active building with u (both approved residents), or is u.
create function app.shares_building_with(u uuid)
returns boolean language sql stable security definer set search_path = ''
as $$
  select u = (select auth.uid()) or exists (
    select 1
    from public.building_membership mine
    join public.building_membership theirs on theirs.building_id = mine.building_id
    join public.building bl on bl.id = mine.building_id
    where mine.user_id = (select auth.uid()) and mine.status = 'approved'
      and theirs.user_id = u and theirs.status = 'approved'
      and bl.status = 'active')
$$;

-- --- Entity-relationship helpers. Security definer so policies on one table can consult
-- --- another without recursive RLS evaluation.

create function app.is_membership_owner(m uuid)
returns boolean language sql stable security definer set search_path = ''
as $$
  select exists (select 1 from public.building_membership where id = m and user_id = (select auth.uid()))
$$;

create function app.is_delivery_requester(r uuid)
returns boolean language sql stable security definer set search_path = ''
as $$
  select exists (select 1 from public.delivery_request where id = r and requester_id = (select auth.uid()))
$$;

create function app.is_accepted_helper(r uuid)
returns boolean language sql stable security definer set search_path = ''
as $$
  select exists (
    select 1
    from public.delivery_request dr
    join public.delivery_offer o on o.id = dr.accepted_offer_id
    where dr.id = r and o.helper_id = (select auth.uid()))
$$;

create function app.is_transaction_party(t uuid)
returns boolean language sql stable security definer set search_path = ''
as $$
  select exists (
    select 1 from public.transactions
    where id = t and (select auth.uid()) in (payer_id, payee_id))
$$;

create function app.is_payment_party(p uuid)
returns boolean language sql stable security definer set search_path = ''
as $$
  select exists (
    select 1 from public.payment
    where id = p and ((select auth.uid()) in (payer_id, payee_id) or app.is_transaction_party(transaction_id)))
$$;

create function app.has_open_dispute_for_request(r uuid)
returns boolean language sql stable security definer set search_path = ''
as $$
  select exists (
    select 1
    from public.transactions t
    join public.dispute d on d.transaction_id = t.id
    where t.delivery_request_id = r and d.status <> 'resolved')
$$;

-- BR-E10 (e): requester, uploading helper, or a building admin while a dispute on the request is open.
create function app.can_view_proof(r uuid)
returns boolean language sql stable security definer set search_path = ''
as $$
  select app.is_delivery_requester(r)
      or exists (select 1 from public.delivery_proof where request_id = r and uploaded_by = (select auth.uid()))
      or exists (
        select 1 from public.delivery_request dr
        where dr.id = r and app.is_building_admin(dr.building_id) and app.has_open_dispute_for_request(r))
$$;

-- BR-E10 (a): accepted helper, request `collected`, door delivery authorized, no proof yet.
create function app.can_upload_proof(r uuid)
returns boolean language sql stable security definer set search_path = ''
as $$
  select exists (
    select 1 from public.delivery_request dr
    where dr.id = r
      and dr.status = 'collected'
      and (dr.door_delivery_allowed or dr.door_delivery_approved_at is not null)
      and app.is_accepted_helper(r)
      and not exists (select 1 from public.delivery_proof p where p.request_id = r))
$$;

grant usage on schema app to anon, authenticated, service_role;
grant execute on function
  app.is_platform_admin(),
  app.is_resident(uuid),
  app.has_accepted_current(public.legal_doc_type, uuid),
  app.is_building_admin(uuid),
  app.my_building_ids(),
  app.shares_building_with(uuid),
  app.is_membership_owner(uuid),
  app.is_delivery_requester(uuid),
  app.is_accepted_helper(uuid),
  app.is_transaction_party(uuid),
  app.is_payment_party(uuid),
  app.can_view_proof(uuid),
  app.can_upload_proof(uuid)
to authenticated;

-- =============================================================================================
-- Internal helpers (RPC/trigger use only; not granted)
-- =============================================================================================

create function app.building_setting(b uuid, key text)
returns jsonb language sql stable security definer set search_path = ''
as $$
  select coalesce(
    (select settings -> key from public.building where id = b),
    app.default_building_settings() -> key)
$$;

create function app.audit(
  b uuid, action text, target_type text, target_id uuid, note text default null, self_review boolean default false)
returns void language sql volatile security definer set search_path = ''
as $$
  insert into public.audit_log (building_id, actor_id, self_review, action, target_type, target_id, note)
  values (b, (select auth.uid()), self_review, action, target_type, target_id, note)
$$;

-- =============================================================================================
-- Generic triggers
-- =============================================================================================

create function app.set_updated_at()
returns trigger language plpgsql set search_path = ''
as $$
begin
  new.updated_at := now();
  return new;
end
$$;

-- Append-only: no DELETE; UPDATE only of the columns named in the trigger arguments.
create function app.append_only()
returns trigger language plpgsql set search_path = ''
as $$
declare
  allowed text[] := coalesce(tg_argv::text[], '{}');
begin
  if tg_op = 'DELETE' then
    raise exception 'APPEND_ONLY' using detail = tg_table_name;
  end if;
  if (to_jsonb(new) - allowed) is distinct from (to_jsonb(old) - allowed) then
    raise exception 'APPEND_ONLY' using detail = tg_table_name;
  end if;
  return new;
end
$$;

-- Frozen once status is one of the trigger arguments (BR-J1); never deletable.
create function app.guard_final_status()
returns trigger language plpgsql set search_path = ''
as $$
begin
  if tg_op = 'DELETE' then
    raise exception 'IMMUTABLE' using detail = tg_table_name;
  end if;
  if (to_jsonb(old) ->> 'status') = any (tg_argv::text[]) and to_jsonb(new) is distinct from to_jsonb(old) then
    raise exception 'IMMUTABLE' using detail = tg_table_name || ' is ' || (to_jsonb(old) ->> 'status');
  end if;
  return new;
end
$$;

do $$
declare
  t text;
begin
  foreach t in array array[
    'profile', 'building', 'building_membership', 'parking_assignment', 'parking_listing',
    'parking_reservation', 'delivery_request', 'transactions', 'payment', 'dispute']
  loop
    execute format(
      'create trigger set_updated_at before update on public.%I for each row execute function app.set_updated_at()', t);
  end loop;
end
$$;

create trigger append_only before update or delete on public.membership_event
  for each row execute function app.append_only();
create trigger append_only before update or delete on public.payment_event
  for each row execute function app.append_only();
create trigger append_only before update or delete on public.legal_acceptance
  for each row execute function app.append_only();
create trigger append_only before update or delete on public.audit_log
  for each row execute function app.append_only();
create trigger append_only before update or delete on public.rating
  for each row execute function app.append_only('hidden');
create trigger append_only before update or delete on public.delivery_proof
  for each row execute function app.append_only('purged_at');

create trigger guard_transaction_immutable before update or delete on public.transactions
  for each row execute function app.guard_final_status('completed', 'cancelled');
create trigger guard_payment_immutable before update or delete on public.payment
  for each row execute function app.guard_final_status('settled', 'cancelled');

-- =============================================================================================
-- guard_self_review (BR-A6): membership decisions, assignment decisions, dispute resolution
-- =============================================================================================
create function app.guard_self_review()
returns trigger language plpgsql set search_path = ''
as $$
declare
  reviewer uuid;
  old_reviewer uuid;
  is_self boolean;
begin
  if tg_table_name = 'dispute' then
    reviewer := new.resolved_by;
    if tg_op = 'UPDATE' then old_reviewer := old.resolved_by; end if;
  else
    reviewer := new.reviewed_by;
    if tg_op = 'UPDATE' then old_reviewer := old.reviewed_by; end if;
  end if;

  if reviewer is null or reviewer is not distinct from old_reviewer then
    return new;
  end if;

  if not app.holds_building_admin_role(new.building_id, reviewer) then
    raise exception 'NOT_BUILDING_ADMIN';
  end if;

  -- (separate branches: each table has different columns)
  if tg_table_name = 'building_membership' then
    is_self := reviewer = new.user_id;
  elsif tg_table_name = 'parking_assignment' then
    is_self := exists (
      select 1 from public.building_membership m where m.id = new.membership_id and m.user_id = reviewer);
  else
    is_self := exists (
      select 1 from public.transactions t
      where t.id = new.transaction_id and reviewer in (t.payer_id, t.payee_id));
  end if;

  if is_self then
    if not coalesce((app.building_setting(new.building_id, 'allow_admin_self_review'))::boolean, false) then
      raise exception 'SELF_REVIEW_FORBIDDEN';
    end if;
    if tg_table_name = 'dispute' then
      new.self_review := true;
    else
      new.flags := new.flags || '{"self_review": true}';
    end if;
  end if;
  return new;
end
$$;

create trigger guard_self_review before insert or update on public.building_membership
  for each row execute function app.guard_self_review();
create trigger guard_self_review before insert or update on public.parking_assignment
  for each row execute function app.guard_self_review();
create trigger guard_self_review before insert or update on public.dispute
  for each row execute function app.guard_self_review();

-- =============================================================================================
-- guard_assignment_approval (BR-C2): only for an approved membership, active space, active building
-- =============================================================================================
create function app.guard_assignment_approval()
returns trigger language plpgsql set search_path = ''
as $$
begin
  if new.status = 'active' and (tg_op = 'INSERT' or old.status is distinct from 'active') then
    if not exists (
      select 1
      from public.building_membership m
      join public.parking_space s on s.id = new.parking_space_id
      join public.building b on b.id = new.building_id
      where m.id = new.membership_id and m.status = 'approved' and s.is_active and b.status = 'active')
    then
      raise exception 'ASSIGNMENT_NOT_ALLOWED';
    end if;
  end if;
  return new;
end
$$;

create trigger guard_assignment_approval before insert or update of status on public.parking_assignment
  for each row execute function app.guard_assignment_approval();

-- =============================================================================================
-- guard_listing_assignment (BR-C6): the owner holds the ACTIVE assignment of that space
-- =============================================================================================
create function app.guard_listing_assignment()
returns trigger language plpgsql set search_path = ''
as $$
begin
  if not exists (
    select 1
    from public.parking_assignment a
    join public.building_membership m on m.id = a.membership_id
    where a.id = new.assignment_id
      and a.status = 'active'
      and a.parking_space_id = new.parking_space_id
      and m.user_id = new.owner_id)
  then
    raise exception 'NOT_SPACE_HOLDER';
  end if;
  return new;
end
$$;

create trigger guard_listing_assignment
  before insert or update of owner_id, assignment_id, parking_space_id on public.parking_listing
  for each row execute function app.guard_listing_assignment();

-- =============================================================================================
-- validate_offer (BR-E2): helper ≠ requester, approved resident, request still open
-- =============================================================================================
create function app.validate_offer()
returns trigger language plpgsql set search_path = ''
as $$
declare
  r public.delivery_request;
begin
  select * into r from public.delivery_request where id = new.request_id;
  if r.requester_id = new.helper_id then
    raise exception 'OWN_REQUEST';
  end if;
  if not exists (
    select 1
    from public.building_membership m
    join public.building b on b.id = m.building_id
    where m.building_id = r.building_id and m.user_id = new.helper_id
      and m.status = 'approved' and b.status = 'active')
  then
    raise exception 'NOT_RESIDENT';
  end if;
  if r.status not in ('open', 'offer_received') then
    raise exception 'REQUEST_NOT_OPEN';
  end if;
  return new;
end
$$;

create trigger validate_offer before insert on public.delivery_offer
  for each row execute function app.validate_offer();

-- =============================================================================================
-- Ratings: validate_rating + reputation (BR-I1–I3)
-- =============================================================================================
create function app.validate_rating()
returns trigger language plpgsql set search_path = ''
as $$
declare
  t public.transactions;
begin
  select * into t from public.transactions where id = new.transaction_id;
  if t.status <> 'completed' then
    raise exception 'TRANSACTION_NOT_COMPLETED';
  end if;
  if not ((new.rater_id = t.payer_id and new.ratee_id = t.payee_id)
       or (new.rater_id = t.payee_id and new.ratee_id = t.payer_id)) then
    raise exception 'NOT_A_PARTY';
  end if;
  if exists (select 1 from public.dispute d where d.transaction_id = t.id and d.status <> 'resolved') then
    raise exception 'DISPUTE_OPEN';
  end if;
  if now() > t.completed_at
             + make_interval(days => (app.building_setting(t.building_id, 'rating_window_days'))::int) then
    raise exception 'RATING_WINDOW_CLOSED';
  end if;
  return new;
end
$$;

create trigger validate_rating before insert on public.rating
  for each row execute function app.validate_rating();

-- Aggregates count only *revealed* ratings: both parties rated, or the window closed (BR-I3) —
-- otherwise the ratee could infer an unrevealed score from a changed average.
-- The tick job calls this again for ratings whose window closes.
create function app.recompute_reputation(b uuid, u uuid)
returns void language sql volatile security definer set search_path = ''
as $$
  update public.building_membership m
  set rating_avg = agg.avg_stars, rating_count = agg.n
  from (
    select round(avg(r.stars), 2) as avg_stars, count(*)::int as n
    from public.rating r
    join public.transactions t on t.id = r.transaction_id
    where r.building_id = b and r.ratee_id = u and not r.hidden
      and (exists (select 1 from public.rating o where o.transaction_id = r.transaction_id and o.rater_id = r.ratee_id)
           or now() > t.completed_at
                      + make_interval(days => (app.building_setting(b, 'rating_window_days'))::int))
  ) agg
  where m.building_id = b and m.user_id = u
$$;

create function app.update_reputation()
returns trigger language plpgsql set search_path = ''
as $$
begin
  -- A new rating may reveal the counterparty's earlier rating too, so refresh both sides.
  perform app.recompute_reputation(new.building_id, new.ratee_id);
  perform app.recompute_reputation(new.building_id, new.rater_id);
  return null;
end
$$;

create trigger update_reputation after insert or update of hidden on public.rating
  for each row execute function app.update_reputation();

create function app.update_completed_count()
returns trigger language plpgsql set search_path = ''
as $$
begin
  update public.building_membership m
  set completed_count = (
    select count(*) from public.transactions t
    where t.building_id = new.building_id and t.status = 'completed' and m.user_id in (t.payer_id, t.payee_id))
  where m.building_id = new.building_id and m.user_id in (new.payer_id, new.payee_id);
  return null;
end
$$;

create trigger update_completed_count after update of status on public.transactions
  for each row when (new.status = 'completed' and old.status is distinct from 'completed')
  execute function app.update_completed_count();

-- =============================================================================================
-- guard_delivery_proof (BR-E10): uploader, state, authorization, and the Storage object itself
-- =============================================================================================
create function app.guard_delivery_proof()
returns trigger language plpgsql set search_path = ''
as $$
declare
  r public.delivery_request;
  obj record;
begin
  select * into r from public.delivery_request where id = new.request_id;

  if not exists (select 1 from public.delivery_offer o where o.id = r.accepted_offer_id and o.helper_id = new.uploaded_by) then
    raise exception 'NOT_ACCEPTED_HELPER';
  end if;
  if r.status <> 'collected' then
    raise exception 'INVALID_STATE' using detail = r.status::text;
  end if;
  if not (r.door_delivery_allowed or r.door_delivery_approved_at is not null) then
    raise exception 'DOOR_DELIVERY_NOT_ALLOWED';
  end if;
  if new.storage_path not like r.building_id::text || '/' || r.id::text || '/%.jpg' then
    raise exception 'PROOF_INVALID' using detail = 'path';
  end if;

  select o.owner_id, o.metadata, o.created_at into obj
  from storage.objects o
  where o.bucket_id = 'delivery-proofs' and o.name = new.storage_path;
  if not found then
    raise exception 'PROOF_REQUIRED';
  end if;
  if obj.owner_id is distinct from new.uploaded_by::text
     or obj.metadata ->> 'mimetype' is distinct from 'image/jpeg'
     or coalesce((obj.metadata ->> 'size')::bigint, 0)
        > (app.building_setting(r.building_id, 'proof_max_bytes'))::bigint
     or obj.created_at
        < now() - make_interval(mins => (app.building_setting(r.building_id, 'proof_max_age_minutes'))::int)
  then
    raise exception 'PROOF_INVALID';
  end if;

  -- Server-derived facts win over whatever the client sent.
  new.building_id := r.building_id;
  new.mime_type := 'image/jpeg';
  new.size_bytes := (obj.metadata ->> 'size')::int;
  new.uploaded_at := now();
  return new;
end
$$;

create trigger guard_delivery_proof before insert on public.delivery_proof
  for each row execute function app.guard_delivery_proof();

-- =============================================================================================
-- Profile bootstrap: one profile per auth user (phone copied from auth, normalized to E.164)
-- =============================================================================================
create function app.handle_auth_user()
returns trigger language plpgsql security definer set search_path = ''
as $$
declare
  phone text := case when coalesce(new.phone, '') = '' then null
                     when new.phone like '+%' then new.phone
                     else '+' || new.phone end;
begin
  if tg_op = 'INSERT' then
    insert into public.profile (id, phone_e164) values (new.id, phone);
  elsif new.phone is distinct from old.phone then
    update public.profile set phone_e164 = phone where id = new.id;
  end if;
  return new;
end
$$;

create trigger on_auth_user_changed after insert or update of phone on auth.users
  for each row execute function app.handle_auth_user();
