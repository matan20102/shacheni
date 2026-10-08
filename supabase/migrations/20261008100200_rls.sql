-- Row-level security: default deny, read-only for clients.
-- Spec: docs/PRD-data-security-architecture.md §9.6 "RLS policies" and §12.
-- `authenticated` gets SELECT (filtered by RLS) and no INSERT/UPDATE/DELETE anywhere except its own
-- device tokens. All writes go through security-definer RPCs. `anon` reads only current legal texts.
-- Cross-table checks use app.* security-definer helpers to avoid recursive policy evaluation.

-- ---------------------------------------------------------------------------------------------
-- Privileges. Supabase grants ALL on new public tables to anon/authenticated by default — undo that.
-- ---------------------------------------------------------------------------------------------
revoke all on all tables in schema public from anon, authenticated;
alter default privileges in schema public revoke all on tables from anon, authenticated;

grant select on
  public.platform_admin, public.apartment, public.parking_space, public.building_admin,
  public.profile, public.building_membership, public.membership_event, public.parking_assignment,
  public.parking_listing, public.parking_reservation, public.delivery_request, public.delivery_offer,
  public.delivery_proof, public.transactions, public.payment, public.payment_event, public.dispute,
  public.rating, public.notification, public.device_token, public.legal_document,
  public.legal_acceptance, public.audit_log
to authenticated;

-- building: every column except join_code (admins read it through an RPC).
grant select (
  id, name, address, city, timezone, declared_apartment_count, declared_parking_count, status,
  join_code_rotated_at, settings, created_by, created_at, activated_at, updated_at
) on public.building to authenticated;

grant insert, update, delete on public.device_token to authenticated;
grant select on public.legal_document to anon;
-- delivery_secret and join_code_attempt: no client privileges at all.

-- ---------------------------------------------------------------------------------------------
-- Enable RLS everywhere
-- ---------------------------------------------------------------------------------------------
do $$
declare
  t text;
begin
  for t in select tablename from pg_tables where schemaname = 'public' loop
    execute format('alter table public.%I enable row level security', t);
  end loop;
end
$$;

-- ---------------------------------------------------------------------------------------------
-- Platform & building
-- ---------------------------------------------------------------------------------------------
create policy platform_admin_select on public.platform_admin for select to authenticated
  using (user_id = (select auth.uid()));

create policy building_select on public.building for select to authenticated
  using (
    app.is_platform_admin()
    or app.holds_building_admin_role(id, (select auth.uid()))
    or exists (
      select 1 from public.building_membership m
      where m.building_id = building.id and m.user_id = (select auth.uid()))
  );

-- Applicants get the pick-lists only through resolve_join_code.
create policy apartment_select on public.apartment for select to authenticated
  using (app.is_resident(building_id) or app.is_building_admin(building_id) or app.is_platform_admin());

create policy parking_space_select on public.parking_space for select to authenticated
  using (app.is_resident(building_id) or app.is_building_admin(building_id) or app.is_platform_admin());

create policy building_admin_select on public.building_admin for select to authenticated
  using (user_id = (select auth.uid()) or app.is_platform_admin());

-- ---------------------------------------------------------------------------------------------
-- Users & membership (other residents are seen only through public_profile_v)
-- ---------------------------------------------------------------------------------------------
create policy profile_select on public.profile for select to authenticated
  using (id = (select auth.uid()));

create policy membership_select on public.building_membership for select to authenticated
  using (user_id = (select auth.uid()) or app.is_building_admin(building_id));

create policy membership_event_select on public.membership_event for select to authenticated
  using (app.is_membership_owner(membership_id) or app.is_building_admin(building_id));

-- Other residents never see assignments.
create policy assignment_select on public.parking_assignment for select to authenticated
  using (app.is_membership_owner(membership_id) or app.is_building_admin(building_id));

-- ---------------------------------------------------------------------------------------------
-- Parking
-- ---------------------------------------------------------------------------------------------
create policy listing_select on public.parking_listing for select to authenticated
  using (app.is_resident(building_id) and (status <> 'cancelled' or owner_id = (select auth.uid())));

create policy reservation_select on public.parking_reservation for select to authenticated
  using ((select auth.uid()) in (requester_id, owner_id));

-- ---------------------------------------------------------------------------------------------
-- Packages
-- ---------------------------------------------------------------------------------------------
create policy delivery_request_select on public.delivery_request for select to authenticated
  using (
    requester_id = (select auth.uid())
    or (app.is_resident(building_id) and status in ('open', 'offer_received'))
    or app.is_accepted_helper(id)
  );

create policy delivery_offer_select on public.delivery_offer for select to authenticated
  using (helper_id = (select auth.uid()) or app.is_delivery_requester(request_id));

create policy delivery_proof_select on public.delivery_proof for select to authenticated
  using (app.can_view_proof(request_id));

-- delivery_secret: RLS on, no policy → no direct SELECT for anyone (RPC get_delivery_secrets only).

-- ---------------------------------------------------------------------------------------------
-- Transactions, payments, disputes, ratings
-- ---------------------------------------------------------------------------------------------
create policy transactions_select on public.transactions for select to authenticated
  using ((select auth.uid()) in (payer_id, payee_id));

create policy payment_select on public.payment for select to authenticated
  using (app.is_payment_party(id));

create policy payment_event_select on public.payment_event for select to authenticated
  using (app.is_payment_party(payment_id));

create policy dispute_select on public.dispute for select to authenticated
  using (app.is_transaction_party(transaction_id) or app.is_building_admin(building_id));

-- Own ratings only; others' ratings via visible_rating_v (hidden-until-both, BR-I3).
create policy rating_select on public.rating for select to authenticated
  using (rater_id = (select auth.uid()));

-- ---------------------------------------------------------------------------------------------
-- Notifications, devices, legal, audit
-- ---------------------------------------------------------------------------------------------
create policy notification_select on public.notification for select to authenticated
  using (user_id = (select auth.uid()));

create policy device_token_all on public.device_token for all to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

create policy legal_document_select_current on public.legal_document for select to anon, authenticated
  using (is_current);
create policy legal_document_select_all on public.legal_document for select to authenticated
  using (app.is_platform_admin());

create policy legal_acceptance_select on public.legal_acceptance for select to authenticated
  using (user_id = (select auth.uid()) or (building_id is not null and app.is_building_admin(building_id)));

create policy audit_log_select on public.audit_log for select to authenticated
  using (app.is_platform_admin() or (building_id is not null and app.is_building_admin(building_id)));

-- join_code_attempt: RLS on, no policy (RPC-internal).
