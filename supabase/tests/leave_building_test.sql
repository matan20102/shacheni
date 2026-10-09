-- Leaving a building (moving apartments) and joining another.
--   psql -v ON_ERROR_STOP=1 -f supabase/tests/leave_building_test.sql

begin;

\ir kit.sql

-- owner (admin of A and B) · alice, bob, dave = residents of A · carol = applicant
insert into auth.users (id, email) values
  ('a4000000-0000-4000-8000-000000000001', 'owner@example.com'),
  ('a4000000-0000-4000-8000-000000000002', 'alice@example.com'),
  ('a4000000-0000-4000-8000-000000000003', 'bob@example.com'),
  ('a4000000-0000-4000-8000-000000000004', 'carol@example.com'),
  ('a4000000-0000-4000-8000-000000000005', 'dave@example.com');

insert into building (id, name, address, declared_apartment_count, declared_parking_count, status, activated_at, join_code, created_by)
values
  ('b4000000-0000-4000-8000-00000000000a', 'Tower A', '1 Herzl St', 5, 2, 'active', now(), 'TWRA2345', 'a4000000-0000-4000-8000-000000000001'),
  ('b4000000-0000-4000-8000-00000000000b', 'Tower B', '2 Herzl St', 1, 0, 'active', now(), 'TWRB2345', 'a4000000-0000-4000-8000-000000000001');
insert into building_admin (building_id, user_id, granted_by) values
  ('b4000000-0000-4000-8000-00000000000a', 'a4000000-0000-4000-8000-000000000001', 'a4000000-0000-4000-8000-000000000001'),
  ('b4000000-0000-4000-8000-00000000000b', 'a4000000-0000-4000-8000-000000000001', 'a4000000-0000-4000-8000-000000000001');
insert into apartment (id, building_id, number) values
  ('c4000000-0000-4000-8000-0000000000a1', 'b4000000-0000-4000-8000-00000000000a', '1'),
  ('c4000000-0000-4000-8000-0000000000a2', 'b4000000-0000-4000-8000-00000000000a', '2'),
  ('c4000000-0000-4000-8000-0000000000a3', 'b4000000-0000-4000-8000-00000000000a', '3'),
  ('c4000000-0000-4000-8000-0000000000a4', 'b4000000-0000-4000-8000-00000000000a', '4'),
  ('c4000000-0000-4000-8000-0000000000a5', 'b4000000-0000-4000-8000-00000000000a', '5'),
  ('c4000000-0000-4000-8000-0000000000b1', 'b4000000-0000-4000-8000-00000000000b', '1');
insert into parking_space (id, building_id, label) values
  ('d4000000-0000-4000-8000-0000000000a1', 'b4000000-0000-4000-8000-00000000000a', 'P1'),
  ('d4000000-0000-4000-8000-0000000000a2', 'b4000000-0000-4000-8000-00000000000a', 'P2');
insert into building_membership (id, building_id, user_id, apartment_id, status) values
  ('e4000000-0000-4000-8000-000000000002', 'b4000000-0000-4000-8000-00000000000a', 'a4000000-0000-4000-8000-000000000002', 'c4000000-0000-4000-8000-0000000000a2', 'approved'),
  ('e4000000-0000-4000-8000-000000000003', 'b4000000-0000-4000-8000-00000000000a', 'a4000000-0000-4000-8000-000000000003', 'c4000000-0000-4000-8000-0000000000a3', 'approved'),
  ('e4000000-0000-4000-8000-000000000004', 'b4000000-0000-4000-8000-00000000000a', 'a4000000-0000-4000-8000-000000000004', 'c4000000-0000-4000-8000-0000000000a4', 'pending'),
  ('e4000000-0000-4000-8000-000000000005', 'b4000000-0000-4000-8000-00000000000a', 'a4000000-0000-4000-8000-000000000005', 'c4000000-0000-4000-8000-0000000000a5', 'approved');

-- alice: holds P1, has an open listing with a pending request from bob, an open package request
-- with dave's pending offer, and a pending offer on dave's request.
insert into parking_assignment (id, building_id, parking_space_id, membership_id, apartment_id, status, started_at) values
  ('f4000000-0000-4000-8000-000000000001', 'b4000000-0000-4000-8000-00000000000a', 'd4000000-0000-4000-8000-0000000000a1',
   'e4000000-0000-4000-8000-000000000002', 'c4000000-0000-4000-8000-0000000000a2', 'active', now());
insert into parking_assignment (building_id, parking_space_id, membership_id, apartment_id) values
  ('b4000000-0000-4000-8000-00000000000a', 'd4000000-0000-4000-8000-0000000000a2',
   'e4000000-0000-4000-8000-000000000002', 'c4000000-0000-4000-8000-0000000000a2');
insert into parking_listing (id, building_id, parking_space_id, assignment_id, owner_id, start_at, end_at, price_minor) values
  ('14000000-0000-4000-8000-000000000001', 'b4000000-0000-4000-8000-00000000000a', 'd4000000-0000-4000-8000-0000000000a1',
   'f4000000-0000-4000-8000-000000000001', 'a4000000-0000-4000-8000-000000000002', now() + interval '1 day', now() + interval '2 days', 1000);
insert into parking_reservation (building_id, listing_id, parking_space_id, owner_id, requester_id, start_at, end_at, price_minor) values
  ('b4000000-0000-4000-8000-00000000000a', '14000000-0000-4000-8000-000000000001', 'd4000000-0000-4000-8000-0000000000a1',
   'a4000000-0000-4000-8000-000000000002', 'a4000000-0000-4000-8000-000000000003', now() + interval '1 day', now() + interval '2 days', 1000);
insert into delivery_request (id, building_id, requester_id, pickup_location, package_description, deadline_at) values
  ('64000000-0000-4000-8000-000000000001', 'b4000000-0000-4000-8000-00000000000a', 'a4000000-0000-4000-8000-000000000002', 'Post', 'Box', now() + interval '1 day'),
  ('64000000-0000-4000-8000-000000000002', 'b4000000-0000-4000-8000-00000000000a', 'a4000000-0000-4000-8000-000000000005', 'Post', 'Box', now() + interval '1 day');
insert into delivery_offer (building_id, request_id, helper_id) values
  ('b4000000-0000-4000-8000-00000000000a', '64000000-0000-4000-8000-000000000001', 'a4000000-0000-4000-8000-000000000005'),
  ('b4000000-0000-4000-8000-00000000000a', '64000000-0000-4000-8000-000000000002', 'a4000000-0000-4000-8000-000000000002');

-- bob ↔ dave: a delivery in progress (bob requester, dave accepted helper, unsettled transaction)
insert into delivery_request (id, building_id, requester_id, pickup_location, package_description, deadline_at) values
  ('64000000-0000-4000-8000-000000000003', 'b4000000-0000-4000-8000-00000000000a', 'a4000000-0000-4000-8000-000000000003', 'Post', 'Box', now() + interval '1 day');
insert into delivery_offer (id, building_id, request_id, helper_id, status) values
  ('74000000-0000-4000-8000-000000000003', 'b4000000-0000-4000-8000-00000000000a', '64000000-0000-4000-8000-000000000003', 'a4000000-0000-4000-8000-000000000005', 'accepted');
update delivery_request set status = 'accepted', accepted_offer_id = '74000000-0000-4000-8000-000000000003'
where id = '64000000-0000-4000-8000-000000000003';
insert into transactions (id, building_id, type, delivery_request_id, payer_id, payee_id, amount_minor) values
  ('34000000-0000-4000-8000-000000000003', 'b4000000-0000-4000-8000-00000000000a', 'delivery', '64000000-0000-4000-8000-000000000003',
   'a4000000-0000-4000-8000-000000000003', 'a4000000-0000-4000-8000-000000000005', 500);

-- =============================================================================================
select t.as_user('a4000000-0000-4000-8000-000000000004');
select t.throws('an applicant cannot "leave" (they withdraw instead)', 'select leave_building()', 'NOT_A_RESIDENT');

select t.as_user('a4000000-0000-4000-8000-000000000003');
select t.throws('cannot leave during an active delivery / unsettled transaction', 'select leave_building()', 'ACTIVE_COMMITMENTS');
select t.as_user('a4000000-0000-4000-8000-000000000005');
select t.throws('the helper is blocked too', 'select leave_building()', 'ACTIVE_COMMITMENTS');

select t.as_user('a4000000-0000-4000-8000-000000000002');
select t.lives('alice leaves', 'select leave_building()');
select t.as_admin();
select t.ok('membership is "left"',
  (select status = 'left' from building_membership where id = 'e4000000-0000-4000-8000-000000000002'));
select t.ok('held space released, requested space withdrawn',
  (select array_agg(status::text order by status::text) from parking_assignment
   where membership_id = 'e4000000-0000-4000-8000-000000000002') = '{ended,withdrawn}');
select t.ok('P1 can now be assigned to someone else',
  not exists (select 1 from parking_assignment where parking_space_id = 'd4000000-0000-4000-8000-0000000000a1' and status = 'active'));
select t.ok('her listing and the pending request on it are cancelled',
  (select status = 'cancelled' from parking_listing where id = '14000000-0000-4000-8000-000000000001')
  and (select bool_and(status = 'cancelled') from parking_reservation where listing_id = '14000000-0000-4000-8000-000000000001'));
select t.ok('her open package request is cancelled and the offer on it expired',
  (select status = 'cancelled' from delivery_request where id = '64000000-0000-4000-8000-000000000001')
  and (select status = 'expired' from delivery_offer where request_id = '64000000-0000-4000-8000-000000000001'));
select t.ok('her pending offer on another request is withdrawn',
  (select status = 'withdrawn' from delivery_offer where request_id = '64000000-0000-4000-8000-000000000002'));
select t.ok('history kept: event recorded, admin notified',
  t.count($$select * from membership_event where membership_id = 'e4000000-0000-4000-8000-000000000002' and type = 'left'$$) = 1
  and t.count($$select * from notification where type = 'membership.left'$$) = 1);

select t.as_user('a4000000-0000-4000-8000-000000000002');
select t.ok('after leaving: no building data any more', t.count('select * from parking_listing') + t.count('select * from apartment') = 0);
select t.ok('access summary says "left" (→ join screen)', (get_my_access() -> 'membership' ->> 'status') = 'left');
select t.throws('cannot leave twice', 'select leave_building()', 'NOT_A_RESIDENT');

-- Moving: apply to building B
select accept_legal_documents(array['terms_of_service', 'privacy_policy']::legal_doc_type[], 'he');
select t.lives('apply to the new building',
  $$select submit_membership_application('b4000000-0000-4000-8000-00000000000b', 'c4000000-0000-4000-8000-0000000000b1',
      array[]::uuid[], 'Alice Levi', '0502222222', null,
      '{"accurate_info":true,"is_resident":true,"apartment_correct":true,"rules_understood":true}')$$);
select t.ok('pending in the new building',
  (select a -> 'membership' ->> 'status' = 'pending' and a -> 'membership' ->> 'building_name' = 'Tower B'
   from (select get_my_access() as a) s));

select t.as_user('a4000000-0000-4000-8000-000000000001');
select t.as_admin();
insert into legal_acceptance (user_id, building_id, document_type, document_version, document_id, locale)
select 'a4000000-0000-4000-8000-000000000001', b, type, version, id, locale
from legal_document, unnest(array['b4000000-0000-4000-8000-00000000000a', 'b4000000-0000-4000-8000-00000000000b']::uuid[]) b
where type = 'building_agreement' and locale = 'he' and is_current;
select t.as_user('a4000000-0000-4000-8000-000000000001');
select t.ok('people who left are not listed as applications in the old building',
  not exists (select 1 from jsonb_array_elements(admin_list_applications('b4000000-0000-4000-8000-00000000000a')) x
              where x ->> 'user_id' = 'a4000000-0000-4000-8000-000000000002'));

-- Coming back: once the delivery is settled, dave can leave and later rejoin the same building
select t.as_admin();
update delivery_request set status = 'completed', completed_at = now() where id = '64000000-0000-4000-8000-000000000003';
update transactions set status = 'completed', completed_at = now() where id = '34000000-0000-4000-8000-000000000003';
select t.as_user('a4000000-0000-4000-8000-000000000005');
select t.lives('dave leaves once nothing is in progress', 'select leave_building()');
select accept_legal_documents(array['terms_of_service', 'privacy_policy']::legal_doc_type[], 'he');
select t.ok('rejoining the same building reuses the membership row',
  (submit_membership_application('b4000000-0000-4000-8000-00000000000a', 'c4000000-0000-4000-8000-0000000000a5',
     array[]::uuid[], 'Dave', '0505555555', null,
     '{"accurate_info":true,"is_resident":true,"apartment_correct":true,"rules_understood":true}'))::text
   = 'e4000000-0000-4000-8000-000000000005');
-- separate statement: get_my_access is stable and sees the snapshot from the start of its statement
select t.ok('…and needs approval again', (get_my_access() -> 'membership' ->> 'status') = 'pending');

\ir report.sql

rollback;
