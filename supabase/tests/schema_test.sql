-- Schema / constraint / trigger / RLS tests. Runs inside one transaction and rolls back.
--   psql -v ON_ERROR_STOP=1 -f supabase/tests/schema_test.sql
-- Prints one line per check and fails (non-zero exit) if any check fails.
-- Plain SQL on purpose (no pgTAP needed), so it runs on any local Postgres.

begin;

\ir kit.sql

-- ---------------------------------------------------------------------------------------------
-- Fixtures: building A (owner = platform + building admin, alice, bob, carol=applicant),
--           building B (dave). Created as postgres (bypasses RLS, like the RPCs will).
-- ---------------------------------------------------------------------------------------------
insert into auth.users (id, phone) values
  ('a0000000-0000-4000-8000-000000000001', '972500000001'),  -- owner
  ('a0000000-0000-4000-8000-000000000002', '972500000002'),  -- alice
  ('a0000000-0000-4000-8000-000000000003', '972500000003'),  -- bob
  ('a0000000-0000-4000-8000-000000000004', '972500000004'),  -- carol (applicant)
  ('a0000000-0000-4000-8000-000000000005', '972500000005');  -- dave (building B)

select t.ok('profile auto-created with E.164 phone',
  (select phone_e164 from profile where id = 'a0000000-0000-4000-8000-000000000002') = '+972500000002');

insert into platform_admin (user_id) values ('a0000000-0000-4000-8000-000000000001');

insert into building (id, name, address, declared_apartment_count, declared_parking_count, status, activated_at, join_code, created_by)
values
  ('b0000000-0000-4000-8000-00000000000a', 'Tower A', '1 Herzl St', 4, 2, 'active', now(), 'ABCD2345', 'a0000000-0000-4000-8000-000000000001'),
  ('b0000000-0000-4000-8000-00000000000b', 'Tower B', '2 Herzl St', 1, 1, 'active', now(), 'WXYZ6789', 'a0000000-0000-4000-8000-000000000001');

insert into apartment (id, building_id, number) values
  ('c0000000-0000-4000-8000-0000000000a1', 'b0000000-0000-4000-8000-00000000000a', '1'),
  ('c0000000-0000-4000-8000-0000000000a2', 'b0000000-0000-4000-8000-00000000000a', '2'),
  ('c0000000-0000-4000-8000-0000000000a3', 'b0000000-0000-4000-8000-00000000000a', '3'),
  ('c0000000-0000-4000-8000-0000000000a4', 'b0000000-0000-4000-8000-00000000000a', '4'),
  ('c0000000-0000-4000-8000-0000000000b1', 'b0000000-0000-4000-8000-00000000000b', '1');

insert into parking_space (id, building_id, label) values
  ('d0000000-0000-4000-8000-0000000000a1', 'b0000000-0000-4000-8000-00000000000a', 'P1'),
  ('d0000000-0000-4000-8000-0000000000a2', 'b0000000-0000-4000-8000-00000000000a', 'P2'),
  ('d0000000-0000-4000-8000-0000000000b1', 'b0000000-0000-4000-8000-00000000000b', 'P1');

insert into building_admin (building_id, user_id, granted_by) values
  ('b0000000-0000-4000-8000-00000000000a', 'a0000000-0000-4000-8000-000000000001', 'a0000000-0000-4000-8000-000000000001');

insert into legal_acceptance (user_id, building_id, document_type, document_version, document_id, locale)
select 'a0000000-0000-4000-8000-000000000001', 'b0000000-0000-4000-8000-00000000000a', type, version, id, locale
from legal_document where type = 'building_agreement' and locale = 'he' and is_current;

insert into building_membership (id, building_id, user_id, apartment_id, status) values
  ('e0000000-0000-4000-8000-000000000001', 'b0000000-0000-4000-8000-00000000000a', 'a0000000-0000-4000-8000-000000000001', 'c0000000-0000-4000-8000-0000000000a1', 'pending'),
  ('e0000000-0000-4000-8000-000000000002', 'b0000000-0000-4000-8000-00000000000a', 'a0000000-0000-4000-8000-000000000002', 'c0000000-0000-4000-8000-0000000000a2', 'pending'),
  ('e0000000-0000-4000-8000-000000000003', 'b0000000-0000-4000-8000-00000000000a', 'a0000000-0000-4000-8000-000000000003', 'c0000000-0000-4000-8000-0000000000a3', 'pending'),
  ('e0000000-0000-4000-8000-000000000004', 'b0000000-0000-4000-8000-00000000000a', 'a0000000-0000-4000-8000-000000000004', 'c0000000-0000-4000-8000-0000000000a4', 'pending'),
  ('e0000000-0000-4000-8000-000000000005', 'b0000000-0000-4000-8000-00000000000b', 'a0000000-0000-4000-8000-000000000005', 'c0000000-0000-4000-8000-0000000000b1', 'approved');

-- =============================================================================================
-- Self-review (BR-A6)
-- =============================================================================================
select t.throws('non-admin cannot review a membership',
  $$update building_membership set status = 'approved', approved_at = now(), reviewed_at = now(),
      reviewed_by = 'a0000000-0000-4000-8000-000000000002'
    where id = 'e0000000-0000-4000-8000-000000000003'$$, 'NOT_BUILDING_ADMIN');

update building_membership set status = 'approved', approved_at = now(), reviewed_at = now(),
  reviewed_by = 'a0000000-0000-4000-8000-000000000001'
where id in ('e0000000-0000-4000-8000-000000000001', 'e0000000-0000-4000-8000-000000000002', 'e0000000-0000-4000-8000-000000000003');

select t.ok('admin self-approval allowed and flagged',
  (select flags ->> 'self_review' from building_membership where id = 'e0000000-0000-4000-8000-000000000001') = 'true');
select t.ok('approving someone else is not flagged',
  (select flags ? 'self_review' from building_membership where id = 'e0000000-0000-4000-8000-000000000002') = false);

update building set settings = settings || '{"allow_admin_self_review": false}' where id = 'b0000000-0000-4000-8000-00000000000a';
select t.throws('self-review refused when the switch is off',
  $$update building_membership set reviewed_by = null where id = 'e0000000-0000-4000-8000-000000000001';
    update building_membership set reviewed_by = 'a0000000-0000-4000-8000-000000000001' where id = 'e0000000-0000-4000-8000-000000000001'$$,
  'SELF_REVIEW_FORBIDDEN');
update building set settings = settings || '{"allow_admin_self_review": true}' where id = 'b0000000-0000-4000-8000-00000000000a';

select t.throws('one live membership per user',
  $$insert into building_membership (building_id, user_id, apartment_id)
    values ('b0000000-0000-4000-8000-00000000000b', 'a0000000-0000-4000-8000-000000000002', 'c0000000-0000-4000-8000-0000000000b1')$$,
  '23505');
select t.throws('composite FK: membership cannot point at another building''s apartment',
  $$insert into building_membership (building_id, user_id, apartment_id, status)
    values ('b0000000-0000-4000-8000-00000000000b', 'a0000000-0000-4000-8000-000000000004', 'c0000000-0000-4000-8000-0000000000a4', 'rejected')$$,
  '23503');

-- =============================================================================================
-- Parking assignments (BR-C2, C3)
-- =============================================================================================
insert into parking_assignment (id, building_id, parking_space_id, membership_id, apartment_id, status, started_at)
values ('f0000000-0000-4000-8000-000000000001', 'b0000000-0000-4000-8000-00000000000a', 'd0000000-0000-4000-8000-0000000000a1',
        'e0000000-0000-4000-8000-000000000002', 'c0000000-0000-4000-8000-0000000000a2', 'active', now());

select t.throws('one active holder per space',
  $$insert into parking_assignment (building_id, parking_space_id, membership_id, apartment_id, status, started_at)
    values ('b0000000-0000-4000-8000-00000000000a', 'd0000000-0000-4000-8000-0000000000a1',
            'e0000000-0000-4000-8000-000000000003', 'c0000000-0000-4000-8000-0000000000a3', 'active', now())$$, '23505');
select t.throws('no active assignment for a pending applicant',
  $$insert into parking_assignment (building_id, parking_space_id, membership_id, apartment_id, status, started_at)
    values ('b0000000-0000-4000-8000-00000000000a', 'd0000000-0000-4000-8000-0000000000a2',
            'e0000000-0000-4000-8000-000000000004', 'c0000000-0000-4000-8000-0000000000a4', 'active', now())$$,
  'ASSIGNMENT_NOT_ALLOWED');
select t.throws('assignment apartment must be the holder''s apartment',
  $$insert into parking_assignment (building_id, parking_space_id, membership_id, apartment_id)
    values ('b0000000-0000-4000-8000-00000000000a', 'd0000000-0000-4000-8000-0000000000a2',
            'e0000000-0000-4000-8000-000000000003', 'c0000000-0000-4000-8000-0000000000a1')$$, '23503');

-- =============================================================================================
-- Listings & reservations: double-booking (BR-C6, D1, D2)
-- =============================================================================================
select t.throws('cannot list a space you do not hold',
  $$insert into parking_listing (building_id, parking_space_id, assignment_id, owner_id, start_at, end_at, price_minor)
    values ('b0000000-0000-4000-8000-00000000000a', 'd0000000-0000-4000-8000-0000000000a1', 'f0000000-0000-4000-8000-000000000001',
            'a0000000-0000-4000-8000-000000000003', '2030-01-01 10:00+02', '2030-01-01 14:00+02', 1000)$$,
  'NOT_SPACE_HOLDER');

insert into parking_listing (id, building_id, parking_space_id, assignment_id, owner_id, start_at, end_at, price_minor)
values ('10000000-0000-4000-8000-000000000001', 'b0000000-0000-4000-8000-00000000000a', 'd0000000-0000-4000-8000-0000000000a1',
        'f0000000-0000-4000-8000-000000000001', 'a0000000-0000-4000-8000-000000000002', '2030-01-01 10:00+02', '2030-01-01 14:00+02', 1500);

select t.throws('overlapping live listing rejected',
  $$insert into parking_listing (building_id, parking_space_id, assignment_id, owner_id, start_at, end_at, price_minor)
    values ('b0000000-0000-4000-8000-00000000000a', 'd0000000-0000-4000-8000-0000000000a1', 'f0000000-0000-4000-8000-000000000001',
            'a0000000-0000-4000-8000-000000000002', '2030-01-01 12:00+02', '2030-01-01 15:00+02', 1000)$$, '23P01');
select t.lives('back-to-back listing allowed',
  $$insert into parking_listing (id, building_id, parking_space_id, assignment_id, owner_id, start_at, end_at, price_minor)
    values ('10000000-0000-4000-8000-000000000002', 'b0000000-0000-4000-8000-00000000000a', 'd0000000-0000-4000-8000-0000000000a1',
            'f0000000-0000-4000-8000-000000000001', 'a0000000-0000-4000-8000-000000000002', '2030-01-01 14:00+02', '2030-01-01 18:00+02', 1000)$$);
select t.throws('listing longer than 90 days rejected',
  $$insert into parking_listing (building_id, parking_space_id, assignment_id, owner_id, start_at, end_at, price_minor)
    values ('b0000000-0000-4000-8000-00000000000a', 'd0000000-0000-4000-8000-0000000000a1', 'f0000000-0000-4000-8000-000000000001',
            'a0000000-0000-4000-8000-000000000002', '2031-01-01', '2031-06-01', 1000)$$, '23514');

-- Two pending requests may overlap; only one can be accepted.
insert into parking_reservation (id, building_id, listing_id, parking_space_id, owner_id, requester_id, start_at, end_at, price_minor)
values
  ('20000000-0000-4000-8000-000000000001', 'b0000000-0000-4000-8000-00000000000a', '10000000-0000-4000-8000-000000000001', 'd0000000-0000-4000-8000-0000000000a1',
   'a0000000-0000-4000-8000-000000000002', 'a0000000-0000-4000-8000-000000000003', '2030-01-01 10:00+02', '2030-01-01 14:00+02', 1500),
  ('20000000-0000-4000-8000-000000000002', 'b0000000-0000-4000-8000-00000000000a', '10000000-0000-4000-8000-000000000001', 'd0000000-0000-4000-8000-0000000000a1',
   'a0000000-0000-4000-8000-000000000002', 'a0000000-0000-4000-8000-000000000001', '2030-01-01 10:00+02', '2030-01-01 14:00+02', 1500);
select t.ok('overlapping pending requests coexist', true);

update parking_reservation set status = 'accepted', accepted_at = now() where id = '20000000-0000-4000-8000-000000000001';
select t.throws('second accept of an overlapping reservation → 23P01 (SLOT_TAKEN)',
  $$update parking_reservation set status = 'accepted' where id = '20000000-0000-4000-8000-000000000002'$$, '23P01');
select t.throws('reservation cannot be for the owner themself',
  $$insert into parking_reservation (building_id, listing_id, parking_space_id, owner_id, requester_id, start_at, end_at, price_minor)
    values ('b0000000-0000-4000-8000-00000000000a', '10000000-0000-4000-8000-000000000002', 'd0000000-0000-4000-8000-0000000000a1',
            'a0000000-0000-4000-8000-000000000002', 'a0000000-0000-4000-8000-000000000002', '2030-01-01 14:00+02', '2030-01-01 18:00+02', 1000)$$,
  '23514');
select t.throws('reservation space must match its listing',
  $$insert into parking_reservation (building_id, listing_id, parking_space_id, owner_id, requester_id, start_at, end_at, price_minor)
    values ('b0000000-0000-4000-8000-00000000000a', '10000000-0000-4000-8000-000000000002', 'd0000000-0000-4000-8000-0000000000a2',
            'a0000000-0000-4000-8000-000000000002', 'a0000000-0000-4000-8000-000000000003', '2030-01-01 14:00+02', '2030-01-01 18:00+02', 1000)$$,
  '23503');

-- =============================================================================================
-- Transactions, payments, ratings (BR-J1, I1–I3)
-- =============================================================================================
insert into transactions (id, building_id, type, parking_reservation_id, payer_id, payee_id, amount_minor)
values ('30000000-0000-4000-8000-000000000001', 'b0000000-0000-4000-8000-00000000000a', 'parking', '20000000-0000-4000-8000-000000000001',
        'a0000000-0000-4000-8000-000000000003', 'a0000000-0000-4000-8000-000000000002', 1500);
insert into payment (id, building_id, transaction_id, kind, payer_id, payee_id, amount_minor)
values ('40000000-0000-4000-8000-000000000001', 'b0000000-0000-4000-8000-00000000000a', '30000000-0000-4000-8000-000000000001', 'charge',
        'a0000000-0000-4000-8000-000000000003', 'a0000000-0000-4000-8000-000000000002', 1500);

select t.throws('transaction must have exactly one source',
  $$insert into transactions (building_id, type, payer_id, payee_id, amount_minor)
    values ('b0000000-0000-4000-8000-00000000000a', 'parking', 'a0000000-0000-4000-8000-000000000003', 'a0000000-0000-4000-8000-000000000002', 1)$$,
  '23514');
select t.throws('one charge per transaction',
  $$insert into payment (building_id, transaction_id, kind, payer_id, payee_id, amount_minor)
    values ('b0000000-0000-4000-8000-00000000000a', '30000000-0000-4000-8000-000000000001', 'charge',
            'a0000000-0000-4000-8000-000000000003', 'a0000000-0000-4000-8000-000000000002', 1500)$$, '23505');
select t.throws('cannot rate before completion',
  $$insert into rating (building_id, transaction_id, rater_id, ratee_id, stars)
    values ('b0000000-0000-4000-8000-00000000000a', '30000000-0000-4000-8000-000000000001',
            'a0000000-0000-4000-8000-000000000003', 'a0000000-0000-4000-8000-000000000002', 5)$$, 'TRANSACTION_NOT_COMPLETED');

update payment set status = 'settled', settled_at = now(), settled_via = 'payee' where id = '40000000-0000-4000-8000-000000000001';
update transactions set status = 'completed', completed_at = now(), service_completed_at = now()
where id = '30000000-0000-4000-8000-000000000001';

select t.throws('completed transaction is immutable',
  $$update transactions set amount_minor = 1 where id = '30000000-0000-4000-8000-000000000001'$$, 'IMMUTABLE');
select t.throws('settled payment is immutable',
  $$update payment set amount_minor = 1 where id = '40000000-0000-4000-8000-000000000001'$$, 'IMMUTABLE');
select t.throws('transactions cannot be deleted',
  $$delete from transactions where id = '30000000-0000-4000-8000-000000000001'$$, 'IMMUTABLE');
select t.ok('completed_count maintained for both parties',
  (select array_agg(completed_count order by user_id) from building_membership
   where id in ('e0000000-0000-4000-8000-000000000002', 'e0000000-0000-4000-8000-000000000003')) = '{1,1}');

select t.throws('non-party cannot rate',
  $$insert into rating (building_id, transaction_id, rater_id, ratee_id, stars)
    values ('b0000000-0000-4000-8000-00000000000a', '30000000-0000-4000-8000-000000000001',
            'a0000000-0000-4000-8000-000000000001', 'a0000000-0000-4000-8000-000000000002', 1)$$, 'NOT_A_PARTY');

insert into rating (id, building_id, transaction_id, rater_id, ratee_id, stars)
values ('50000000-0000-4000-8000-000000000001', 'b0000000-0000-4000-8000-00000000000a', '30000000-0000-4000-8000-000000000001',
        'a0000000-0000-4000-8000-000000000003', 'a0000000-0000-4000-8000-000000000002', 4);
select t.ok('first rating stays hidden from the aggregate (BR-I3)',
  (select rating_count from building_membership where id = 'e0000000-0000-4000-8000-000000000002') = 0);
select t.throws('one rating per rater per transaction',
  $$insert into rating (building_id, transaction_id, rater_id, ratee_id, stars)
    values ('b0000000-0000-4000-8000-00000000000a', '30000000-0000-4000-8000-000000000001',
            'a0000000-0000-4000-8000-000000000003', 'a0000000-0000-4000-8000-000000000002', 5)$$, '23505');

insert into rating (building_id, transaction_id, rater_id, ratee_id, stars)
values ('b0000000-0000-4000-8000-00000000000a', '30000000-0000-4000-8000-000000000001',
        'a0000000-0000-4000-8000-000000000002', 'a0000000-0000-4000-8000-000000000003', 5);
select t.ok('both rated → both revealed in aggregates',
  (select array_agg(rating_count::text || '@' || rating_avg::text order by user_id) from building_membership
   where id in ('e0000000-0000-4000-8000-000000000002', 'e0000000-0000-4000-8000-000000000003')) = '{1@4.00,1@5.00}');

select t.throws('rating stars are append-only',
  $$update rating set stars = 1 where id = '50000000-0000-4000-8000-000000000001'$$, 'APPEND_ONLY');
update rating set hidden = true where id = '50000000-0000-4000-8000-000000000001';
select t.ok('admin hide removes the rating from the aggregate',
  (select rating_count from building_membership where id = 'e0000000-0000-4000-8000-000000000002') = 0);

-- =============================================================================================
-- Packages: offers & door-delivery proof (BR-E2, E3, E6, E10)
-- =============================================================================================
insert into delivery_request (id, building_id, requester_id, pickup_location, package_description, deadline_at, reward_minor)
values ('60000000-0000-4000-8000-000000000001', 'b0000000-0000-4000-8000-00000000000a', 'a0000000-0000-4000-8000-000000000003',
        'Post office', 'Small box', now() + interval '1 day', 1000);
insert into delivery_secret (request_id, building_id, pickup_reference)
values ('60000000-0000-4000-8000-000000000001', 'b0000000-0000-4000-8000-00000000000a', 'REF-123');

select t.throws('requester cannot offer on own request',
  $$insert into delivery_offer (building_id, request_id, helper_id)
    values ('b0000000-0000-4000-8000-00000000000a', '60000000-0000-4000-8000-000000000001', 'a0000000-0000-4000-8000-000000000003')$$,
  'OWN_REQUEST');
select t.throws('applicant cannot offer',
  $$insert into delivery_offer (building_id, request_id, helper_id)
    values ('b0000000-0000-4000-8000-00000000000a', '60000000-0000-4000-8000-000000000001', 'a0000000-0000-4000-8000-000000000004')$$,
  'NOT_RESIDENT');
select t.throws('deadline must be ≥ 30 minutes ahead',
  $$insert into delivery_request (building_id, requester_id, pickup_location, package_description, deadline_at)
    values ('b0000000-0000-4000-8000-00000000000a', 'a0000000-0000-4000-8000-000000000003', 'x', 'y', now() + interval '5 minutes')$$,
  '23514');

insert into delivery_offer (id, building_id, request_id, helper_id, status)
values ('70000000-0000-4000-8000-000000000001', 'b0000000-0000-4000-8000-00000000000a', '60000000-0000-4000-8000-000000000001',
        'a0000000-0000-4000-8000-000000000002', 'accepted');
update delivery_request set status = 'collected', collected_at = now(), accepted_offer_id = '70000000-0000-4000-8000-000000000001'
where id = '60000000-0000-4000-8000-000000000001';

select t.throws('accepted offer must belong to the same request',
  $$insert into delivery_request (id, building_id, requester_id, pickup_location, package_description, deadline_at, accepted_offer_id)
    values ('60000000-0000-4000-8000-000000000002', 'b0000000-0000-4000-8000-00000000000a', 'a0000000-0000-4000-8000-000000000001',
            'x', 'y', now() + interval '1 day', '70000000-0000-4000-8000-000000000001')$$, '23503');

create function t.insert_proof(path text, uploader uuid) returns void language sql as $$
  insert into delivery_proof (building_id, request_id, uploaded_by, storage_path, mime_type, size_bytes)
  values ('b0000000-0000-4000-8000-00000000000a', '60000000-0000-4000-8000-000000000001', uploader, path, 'image/jpeg', 1)
$$;
grant execute on function t.insert_proof(text, uuid) to public;

select t.throws('door delivery without authorization refused',
  $$select t.insert_proof('b0000000-0000-4000-8000-00000000000a/60000000-0000-4000-8000-000000000001/90000000-0000-4000-8000-000000000001.jpg',
                          'a0000000-0000-4000-8000-000000000002')$$, 'DOOR_DELIVERY_NOT_ALLOWED');

update delivery_request set door_delivery_approved_at = now() where id = '60000000-0000-4000-8000-000000000001';

select t.throws('only the accepted helper may submit a proof',
  $$select t.insert_proof('b0000000-0000-4000-8000-00000000000a/60000000-0000-4000-8000-000000000001/90000000-0000-4000-8000-000000000001.jpg',
                          'a0000000-0000-4000-8000-000000000001')$$, 'NOT_ACCEPTED_HELPER');
select t.throws('door delivery without an uploaded photo refused',
  $$select t.insert_proof('b0000000-0000-4000-8000-00000000000a/60000000-0000-4000-8000-000000000001/90000000-0000-4000-8000-000000000001.jpg',
                          'a0000000-0000-4000-8000-000000000002')$$, 'PROOF_REQUIRED');
select t.throws('proof path must be inside the request''s folder',
  $$select t.insert_proof('b0000000-0000-4000-8000-00000000000b/60000000-0000-4000-8000-000000000001/90000000-0000-4000-8000-000000000001.jpg',
                          'a0000000-0000-4000-8000-000000000002')$$, 'PROOF_INVALID');

-- Storage policies: the helper can upload into the request folder; a stranger cannot.
select t.as_user('a0000000-0000-4000-8000-000000000001');
select t.throws('storage: non-helper cannot upload a proof',
  $$insert into storage.objects (bucket_id, name, owner_id, metadata)
    values ('delivery-proofs', 'b0000000-0000-4000-8000-00000000000a/60000000-0000-4000-8000-000000000001/90000000-0000-4000-8000-000000000009.jpg',
            'a0000000-0000-4000-8000-000000000001', '{"mimetype":"image/jpeg","size":1000}')$$, '42501');
select t.as_user('a0000000-0000-4000-8000-000000000002');
select t.lives('storage: accepted helper uploads a proof',
  $$insert into storage.objects (bucket_id, name, owner_id, metadata)
    values ('delivery-proofs', 'b0000000-0000-4000-8000-00000000000a/60000000-0000-4000-8000-000000000001/90000000-0000-4000-8000-000000000001.jpg',
            'a0000000-0000-4000-8000-000000000002', '{"mimetype":"image/jpeg","size":120000}')$$);
select t.as_admin();

select t.lives('valid door-delivery proof accepted',
  $$select t.insert_proof('b0000000-0000-4000-8000-00000000000a/60000000-0000-4000-8000-000000000001/90000000-0000-4000-8000-000000000001.jpg',
                          'a0000000-0000-4000-8000-000000000002')$$);
select t.ok('proof size taken from the stored object, not the client',
  (select size_bytes from delivery_proof where request_id = '60000000-0000-4000-8000-000000000001') = 120000);
select t.throws('proof rows are append-only',
  $$update delivery_proof set note = 'edited' where request_id = '60000000-0000-4000-8000-000000000001'$$, 'APPEND_ONLY');
select t.lives('retention job may set purged_at',
  $$update delivery_proof set purged_at = now() where request_id = '60000000-0000-4000-8000-000000000001'$$);

-- =============================================================================================
-- RLS: what each role can read / write
-- =============================================================================================
-- carol: applicant (pending) in A
select t.as_user('a0000000-0000-4000-8000-000000000004');
select t.ok('applicant sees no listings', t.count('select * from parking_listing') = 0);
select t.ok('applicant sees no apartments', t.count('select * from apartment') = 0);
select t.ok('applicant sees no open package requests', t.count('select * from delivery_request') = 0);
select t.ok('applicant sees only own membership', t.count('select * from building_membership') = 1);
select t.ok('applicant sees own profile only', t.count('select * from profile') = 1);

-- dave: resident of building B
select t.as_user('a0000000-0000-4000-8000-000000000005');
select t.ok('cross-building: no listings of A', t.count('select * from parking_listing') = 0);
select t.ok('cross-building: no apartments of A',
  t.count($$select * from apartment where building_id = 'b0000000-0000-4000-8000-00000000000a'$$) = 0);
select t.ok('cross-building: no transactions/payments of A',
  t.count('select * from transactions') + t.count('select * from payment') = 0);
select t.ok('cross-building: cannot see building A', t.count($$select id from building where name = 'Tower A'$$) = 0);
select t.ok('cross-building: sees own building', t.count($$select id from building where name = 'Tower B'$$) = 1);

-- bob: resident of A (requester of the delivery, payer of the parking transaction)
select t.as_user('a0000000-0000-4000-8000-000000000003');
select t.ok('resident sees listings of own building', t.count('select * from parking_listing') = 2);
select t.ok('resident cannot see someone else''s parking assignment', t.count('select * from parking_assignment') = 0);
select t.ok('resident sees own transaction + payment',
  t.count('select * from transactions') = 1 and t.count('select * from payment') = 1);
select t.ok('requester can see the proof row', t.count('select * from delivery_proof') = 1);
select t.ok('requester can read the proof image object', t.count('select * from storage.objects') = 1);
select t.ok('resident sees other members only via views, not the table', t.count('select * from building_membership') = 1);
select t.throws('nobody can read delivery secrets directly', 'select * from delivery_secret', '42501');
select t.throws('no direct insert of listings', $$insert into parking_listing (building_id, parking_space_id, assignment_id, owner_id, start_at, end_at, price_minor)
    values ('b0000000-0000-4000-8000-00000000000a', 'd0000000-0000-4000-8000-0000000000a1', 'f0000000-0000-4000-8000-000000000001',
            'a0000000-0000-4000-8000-000000000003', '2032-01-01', '2032-01-02', 1)$$, '42501');
select t.throws('no direct update of own membership',
  $$update building_membership set status = 'approved' where user_id = 'a0000000-0000-4000-8000-000000000003'$$, '42501');
select t.throws('join code not readable by residents', 'select join_code from building', '42501');
select t.throws('cannot write the audit log', $$insert into audit_log (action) values ('x')$$, '42501');
select t.lives('can register own device token',
  $$insert into device_token (user_id, token, platform) values ('a0000000-0000-4000-8000-000000000003', 'tok-bob', 'android')$$);
select t.throws('cannot register a device token for someone else',
  $$insert into device_token (user_id, token, platform) values ('a0000000-0000-4000-8000-000000000002', 'tok-x', 'android')$$, '42501');

-- alice: resident (helper/uploader, payee)
select t.as_user('a0000000-0000-4000-8000-000000000002');
select t.ok('holder sees own assignment', t.count('select * from parking_assignment') = 1);
select t.ok('uploader can see the proof row', t.count('select * from delivery_proof') = 1);
select t.ok('accepted helper sees the collected request', t.count('select * from delivery_request') = 1);

-- owner: building admin of A (agreement accepted), but not a party to the delivery
select t.as_user('a0000000-0000-4000-8000-000000000001');
select t.ok('admin sees all memberships of the building', t.count('select * from building_membership') = 4);
select t.ok('admin cannot see a proof without an open dispute', t.count('select * from delivery_proof') = 0);
select t.ok('admin cannot see the proof image without an open dispute', t.count('select * from storage.objects') = 0);
select t.ok('platform admin sees both buildings', t.count('select id from building') = 2);
select t.ok('admin sees the building audit log (none yet)', t.count('select * from audit_log') = 0);

-- open a dispute on the delivery → admin may view the proof
select t.as_admin();
insert into transactions (id, building_id, type, delivery_request_id, payer_id, payee_id, amount_minor)
values ('30000000-0000-4000-8000-000000000002', 'b0000000-0000-4000-8000-00000000000a', 'delivery', '60000000-0000-4000-8000-000000000001',
        'a0000000-0000-4000-8000-000000000003', 'a0000000-0000-4000-8000-000000000002', 1000);
insert into dispute (building_id, transaction_id, opened_by, reason, description)
values ('b0000000-0000-4000-8000-00000000000a', '30000000-0000-4000-8000-000000000002', 'a0000000-0000-4000-8000-000000000003',
        'not_delivered', 'Not at my door');
select t.as_user('a0000000-0000-4000-8000-000000000001');
select t.ok('admin sees the proof during an open dispute',
  t.count('select * from delivery_proof') = 1 and t.count('select * from storage.objects') = 1);

-- admin role without the current building agreement → no admin reads
select t.as_admin();
select publish_legal_document('building_agreement', '1.0', 'he', 'הסכם בניין', 'v1');
select t.as_user('a0000000-0000-4000-8000-000000000001');
select t.ok('new agreement version → admin reads blocked until re-acceptance',
  t.count('select * from building_membership') = 1);

-- anon: only current legal documents
select t.as_anon();
select t.ok('anon reads current legal documents', t.count('select * from legal_document') = 10);
select t.ok('anon RPC returns current docs per locale', t.count($$select * from get_current_legal_documents(null, 'en')$$) = 5);
select t.throws('anon cannot read profiles', 'select * from profile', '42501');
select t.throws('anon cannot publish legal documents',
  $$select publish_legal_document('terms_of_service', 'x', 'he', 't', 'b')$$, '42501');
select t.as_user('a0000000-0000-4000-8000-000000000003');
select t.throws('users cannot publish legal documents',
  $$select publish_legal_document('terms_of_service', 'x', 'he', 't', 'b')$$, '42501');

\ir report.sql

rollback;
