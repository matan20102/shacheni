-- Join flow tests: building setup → join code → application → admin decision → access summary.
--   psql -v ON_ERROR_STOP=1 -f supabase/tests/join_flow_test.sql

begin;

\ir kit.sql

-- owner = platform admin; alice, bob = neighbors; eve = signed in but never accepted the terms
insert into auth.users (id, email, raw_user_meta_data) values
  ('a2000000-0000-4000-8000-000000000001', 'owner@example.com', '{"full_name": "Owner"}'),
  ('a2000000-0000-4000-8000-000000000002', 'alice@example.com', '{"full_name": "Alice"}'),
  ('a2000000-0000-4000-8000-000000000003', 'bob@example.com', '{"full_name": "Bob"}'),
  ('a2000000-0000-4000-8000-000000000004', 'eve@example.com', '{"full_name": "Eve"}');
insert into platform_admin (user_id) values ('a2000000-0000-4000-8000-000000000001');

create function t.accept_terms(u uuid) returns void language sql as $$
  select t.as_user(u);
  select accept_legal_documents(array['terms_of_service', 'privacy_policy']::legal_doc_type[], 'he');
  select t.as_admin();
$$;
grant execute on function t.accept_terms(uuid) to public;
select t.accept_terms('a2000000-0000-4000-8000-000000000001');
select t.accept_terms('a2000000-0000-4000-8000-000000000002');
select t.accept_terms('a2000000-0000-4000-8000-000000000003');

-- Scratch values shared between steps (ids returned by RPCs)
create table t.v (k text primary key, v text);
grant all on t.v to public;
create function t.get(key text) returns text language sql as $$ select v from t.v where k = key $$;
create function t.put(key text, val text) returns void language sql as $$
  insert into t.v values (key, val) on conflict (k) do update set v = excluded.v $$;
grant execute on function t.get(text), t.put(text, text) to public;

-- =============================================================================================
-- Platform: create, units, activate
-- =============================================================================================
select t.as_user('a2000000-0000-4000-8000-000000000002');
select t.throws('only the platform admin creates buildings',
  $$select create_building('Herzl 12', '12 Herzl St', 'Tel Aviv', 3, 2)$$, 'NOT_PLATFORM_ADMIN');

select t.as_user('a2000000-0000-4000-8000-000000000001');
select t.put('b', create_building('Herzl 12', '12 Herzl St', 'Tel Aviv', 3, 2)::text);
select t.ok('building created as draft with the creator as its admin',
  (select status = 'draft' from building where id = t.get('b')::uuid)
  and t.count($$select * from building_admin where building_id = t.get('b')::uuid$$) = 1);
select t.throws('duplicate building (same name + address) refused',
  $$select create_building('herzl 12', '12 HERZL ST', null, 1, 0)$$, 'BUILDING_EXISTS');

select t.throws('cannot activate without apartments',
  $$select accept_building_agreement_and_activate(t.get('b')::uuid)$$, 'COUNT_MISMATCH');
select t.throws('duplicate apartment numbers refused',
  $$select set_building_units(t.get('b')::uuid, array['1', '2', ' 2 '], array['P1'])$$, 'DUPLICATE_LABEL');
select t.lives('set apartments and spaces (count mismatch)',
  $$select set_building_units(t.get('b')::uuid, array['1', '2'], array['P1', 'P2'])$$);
select t.throws('activation needs counts to match the declared numbers',
  $$select accept_building_agreement_and_activate(t.get('b')::uuid)$$, 'COUNT_MISMATCH');
select t.lives('replace the lists while still a draft',
  $$select set_building_units(t.get('b')::uuid, array['1', '2', '3', ''], array['P1', 'P2'])$$);
select t.ok('lists replaced, blanks ignored',
  t.count($$select * from apartment where building_id = t.get('b')::uuid$$) = 3);

select t.as_user('a2000000-0000-4000-8000-000000000002');
select t.throws('a non-admin cannot edit the lists',
  $$select set_building_units(t.get('b')::uuid, array['9'], array[]::text[])$$, 'NOT_BUILDING_ADMIN');
select t.throws('a non-admin cannot activate',
  $$select accept_building_agreement_and_activate(t.get('b')::uuid)$$, 'NOT_BUILDING_ADMIN');

select t.as_user('a2000000-0000-4000-8000-000000000001');
select t.put('code', accept_building_agreement_and_activate(t.get('b')::uuid, 'he'));
select t.ok('activation returns an 8-character join code', t.get('code') ~ '^[A-HJ-NP-Z2-9]{8}$');
select t.ok('building is active and the agreement acceptance is recorded',
  (select status = 'active' from building where id = t.get('b')::uuid)
  and app.is_building_admin(t.get('b')::uuid));
select t.throws('lists are frozen after activation',
  $$select set_building_units(t.get('b')::uuid, array['1'], array[]::text[])$$, 'INVALID_STATE');
select t.ok('admin_get_building shows the join code to the admin',
  (admin_get_building(t.get('b')::uuid) ->> 'join_code') = t.get('code'));
select t.ok('platform list shows the building with counts only',
  (select (x ->> 'apartments')::int = 3 and not (x ? 'join_code')
   from jsonb_array_elements(platform_list_buildings()) x));

-- =============================================================================================
-- Join code
-- =============================================================================================
select t.as_user('a2000000-0000-4000-8000-000000000004');
select t.throws('terms must be accepted before using a join code',
  $$select resolve_join_code(t.get('code'))$$, 'LEGAL_NOT_ACCEPTED');

select t.as_user('a2000000-0000-4000-8000-000000000002');
select t.throws('admin_get_building is admin-only', $$select admin_get_building(t.get('b')::uuid)$$, 'NOT_BUILDING_ADMIN');
select t.throws('platform list is platform-only', 'select platform_list_buildings()', 'NOT_PLATFORM_ADMIN');
select t.ok('wrong code resolves to nothing', resolve_join_code('ZZZZZZZZ') is null);
select t.ok('code resolves case/format-insensitively with the pick-lists',
  (select jsonb_array_length(r -> 'apartments') = 3 and jsonb_array_length(r -> 'spaces') = 2
          and r -> 'building' ->> 'name' = 'Herzl 12'
   from (select resolve_join_code(lower(left(t.get('code'), 4)) || '-' || lower(right(t.get('code'), 4))) as r) s));
select t.ok('applicant still cannot read the building''s apartments directly', t.count('select * from apartment') = 0);

select t.as_user('a2000000-0000-4000-8000-000000000003');
select t.ok('ten wrong codes are each answered with nothing',
  (select bool_and(resolve_join_code('WRONG' || g) is null) from generate_series(1, 10) g));
select t.throws('the 11th attempt within an hour is rate-limited',
  $$select resolve_join_code(t.get('code'))$$, 'RATE_LIMITED');
select t.as_admin();
delete from join_code_attempt where user_id = 'a2000000-0000-4000-8000-000000000003';

-- =============================================================================================
-- Application
-- =============================================================================================
-- security definer: applicants cannot read the lists themselves (that is the point)
create function t.apt(n text) returns uuid language sql security definer as $$
  select id from apartment where building_id = t.get('b')::uuid and number = n $$;
create function t.space(l text) returns uuid language sql security definer as $$
  select id from parking_space where building_id = t.get('b')::uuid and label = l $$;
grant execute on function t.apt(text), t.space(text) to public;

select t.as_user('a2000000-0000-4000-8000-000000000002');
select t.throws('declarations are required',
  $$select submit_membership_application(t.get('b')::uuid, t.apt('1'), array[]::uuid[], 'Alice Levi', '0501111111')$$,
  'DECLARATIONS_REQUIRED');
select t.throws('parking declaration required when asking for a space',
  $$select submit_membership_application(t.get('b')::uuid, t.apt('1'), array[t.space('P1')], 'Alice Levi', '0501111111', null,
      '{"accurate_info":true,"is_resident":true,"apartment_correct":true,"rules_understood":true}')$$,
  'DECLARATIONS_REQUIRED');
select t.throws('phone must be a valid Israeli mobile',
  $$select submit_membership_application(t.get('b')::uuid, t.apt('1'), array[]::uuid[], 'Alice Levi', '1234', null,
      '{"accurate_info":true,"is_resident":true,"apartment_correct":true,"rules_understood":true}')$$, 'PHONE_INVALID');
select t.throws('apartment must belong to the building',
  $$select submit_membership_application(t.get('b')::uuid, gen_random_uuid(), array[]::uuid[], 'Alice Levi', '0501111111', null,
      '{"accurate_info":true,"is_resident":true,"apartment_correct":true,"rules_understood":true}')$$, 'INVALID_ARGUMENT');

select t.put('m_alice', submit_membership_application(t.get('b')::uuid, t.apt('1'), array[t.space('P1')], 'Alice Levi', '050-111-1111',
  'Moved in last month', '{"accurate_info":true,"is_resident":true,"apartment_correct":true,"parking_correct":true,"rules_understood":true}', 'he')::text);
select t.ok('application is pending with the profile updated',
  (select status = 'pending' from building_membership where id = t.get('m_alice')::uuid)
  and (select full_name = 'Alice Levi' and phone_e164 = '+972501111111' from profile
       where id = 'a2000000-0000-4000-8000-000000000002'));
select t.ok('parking request created (not granted)',
  (select status = 'requested' from parking_assignment where membership_id = t.get('m_alice')::uuid));
select t.ok('community rules + resident declaration accepted for this building',
  t.count($$select * from legal_acceptance where building_id = t.get('b')::uuid
            and document_type in ('community_rules', 'resident_declaration')$$) = 2);
select t.throws('cannot apply twice', $$select submit_membership_application(t.get('b')::uuid, t.apt('2'), array[]::uuid[], 'Alice Levi', '0501111111', null,
      '{"accurate_info":true,"is_resident":true,"apartment_correct":true,"rules_understood":true}')$$, 'ALREADY_APPLIED');
select t.ok('access summary: pending membership with building, apartment, requested space',
  (select a -> 'membership' ->> 'status' = 'pending' and a -> 'membership' ->> 'building_name' = 'Herzl 12'
          and a -> 'membership' ->> 'apartment' = '1' and a -> 'membership' -> 'spaces' -> 0 ->> 'label' = 'P1'
          and (a ->> 'legal_pending')::boolean = false and (a ->> 'is_platform_admin')::boolean = false
   from (select get_my_access() as a) s));
select t.throws('applicants cannot list applications',
  $$select admin_list_applications(t.get('b')::uuid)$$, 'NOT_BUILDING_ADMIN');
select t.throws('applicants cannot decide',
  $$select admin_decide_membership(t.get('m_alice')::uuid, 'approve')$$, 'NOT_BUILDING_ADMIN');

select t.as_admin();
select t.ok('the admin got an in-app notification',
  t.count($$select * from notification where user_id = 'a2000000-0000-4000-8000-000000000001'
            and type = 'membership.application_received'$$) = 1);

-- =============================================================================================
-- Admin decision: request info → answer → approve with parking
-- =============================================================================================
select t.as_user('a2000000-0000-4000-8000-000000000001');
select t.ok('admin sees the application with phone and requested space',
  (select x ->> 'phone' = '+972501111111' and x -> 'spaces' -> 0 ->> 'label' = 'P1'
   from jsonb_array_elements(admin_list_applications(t.get('b')::uuid)) x));
select t.throws('rejecting needs a reason', $$select admin_decide_membership(t.get('m_alice')::uuid, 'reject')$$, 'NOTE_REQUIRED');
select t.lives('request more info',
  $$select admin_decide_membership(t.get('m_alice')::uuid, 'request_info', 'Which floor?')$$);

select t.as_user('a2000000-0000-4000-8000-000000000002');
select t.ok('applicant sees the question', (get_my_access() -> 'membership' ->> 'info_request_message') = 'Which floor?');
select t.lives('applicant answers', $$select respond_to_info_request('Third floor')$$);

select t.as_user('a2000000-0000-4000-8000-000000000001');
select t.lives('approve with the parking space',
  $$select admin_decide_membership(t.get('m_alice')::uuid, 'approve', null, array[t.space('P1')])$$);
select t.ok('membership approved, space assigned, not a self-review',
  (select status = 'approved' and not (flags ? 'self_review') from building_membership where id = t.get('m_alice')::uuid)
  and (select status = 'active' from parking_assignment where membership_id = t.get('m_alice')::uuid));
select t.throws('decided applications cannot be decided again',
  $$select admin_decide_membership(t.get('m_alice')::uuid, 'reject', 'x')$$, 'INVALID_STATE');

select t.as_user('a2000000-0000-4000-8000-000000000002');
select t.ok('approved resident now reads the building''s apartments', t.count('select * from apartment') = 3);
select t.ok('access summary says approved with the active space',
  (select a -> 'membership' ->> 'status' = 'approved' and a -> 'membership' -> 'spaces' -> 0 ->> 'status' = 'active'
   from (select get_my_access() as a) s));

-- =============================================================================================
-- Withdraw, reject, re-apply (bob)
-- =============================================================================================
select t.as_user('a2000000-0000-4000-8000-000000000003');
select t.put('m_bob', submit_membership_application(t.get('b')::uuid, t.apt('3'), array[]::uuid[], 'Bob Cohen', '0523333333', null,
  '{"accurate_info":true,"is_resident":true,"apartment_correct":true,"rules_understood":true}')::text);
select t.lives('withdraw a pending application', 'select withdraw_application()');
select t.ok('withdrawn application is not live', (get_my_access() -> 'membership' ->> 'status') = 'withdrawn');
select t.ok('re-apply reuses the same membership row',
  submit_membership_application(t.get('b')::uuid, t.apt('3'), array[]::uuid[], 'Bob Cohen', '0523333333', null,
    '{"accurate_info":true,"is_resident":true,"apartment_correct":true,"rules_understood":true}')::text = t.get('m_bob'));
select t.as_user('a2000000-0000-4000-8000-000000000001');
select t.ok('withdrawn applications are hidden from the admin list; re-applied one shows',
  (select count(*) = 1 from jsonb_array_elements(admin_list_applications(t.get('b')::uuid)) x
   where x ->> 'id' = t.get('m_bob') and x ->> 'status' = 'pending'));
select t.lives('reject with a reason', $$select admin_decide_membership(t.get('m_bob')::uuid, 'reject', 'Not on the residents list')$$);
select t.as_user('a2000000-0000-4000-8000-000000000003');
select t.ok('applicant sees the rejection reason',
  (select a -> 'membership' ->> 'status' = 'rejected' and a -> 'membership' ->> 'status_reason' = 'Not on the residents list'
   from (select get_my_access() as a) s));
select t.ok('applicant has no building data', t.count('select * from apartment') = 0);

-- =============================================================================================
-- The owner applies to their own building (BR-A6)
-- =============================================================================================
select t.as_user('a2000000-0000-4000-8000-000000000001');
select t.put('m_owner', submit_membership_application(t.get('b')::uuid, t.apt('2'), array[t.space('P1')], 'Owner Name', '0549999999', null,
  '{"accurate_info":true,"is_resident":true,"apartment_correct":true,"parking_correct":true,"rules_understood":true}')::text);
select t.ok('request for a space held by someone else is flagged',
  (select (flags ->> 'currently_assigned_to_other')::boolean from parking_assignment
   where membership_id = t.get('m_owner')::uuid));
select t.throws('approving a space that is already held fails',
  $$select admin_decide_membership(t.get('m_owner')::uuid, 'approve', null, array[t.space('P1')])$$, 'SPACE_HELD');

select t.as_admin();
update building set settings = settings || '{"allow_admin_self_review": false}' where id = t.get('b')::uuid;
select t.as_user('a2000000-0000-4000-8000-000000000001');
select t.throws('self-approval refused while the switch is off',
  $$select admin_decide_membership(t.get('m_owner')::uuid, 'approve')$$, 'SELF_REVIEW_FORBIDDEN');
select t.as_admin();
update building set settings = settings || '{"allow_admin_self_review": true}' where id = t.get('b')::uuid;

select t.as_user('a2000000-0000-4000-8000-000000000001');
select t.lives('self-approval without the held space', $$select admin_decide_membership(t.get('m_owner')::uuid, 'approve')$$);
select t.ok('self-approval flagged on the row and in the audit log',
  (select (flags ->> 'self_review')::boolean from building_membership where id = t.get('m_owner')::uuid)
  and t.count($$select * from audit_log where action = 'approve_membership' and self_review$$) = 1);
select t.ok('the unapproved space request was rejected',
  (select status = 'rejected' from parking_assignment where membership_id = t.get('m_owner')::uuid));
select t.ok('owner access summary: platform admin, admin of one building, approved resident',
  (select (a ->> 'is_platform_admin')::boolean and jsonb_array_length(a -> 'admin_buildings') = 1
          and a -> 'membership' ->> 'status' = 'approved'
   from (select get_my_access() as a) s));

select t.as_anon();
select t.throws('anon cannot call the join RPCs', $$select resolve_join_code('ABCDEFGH')$$, '42501');

\ir report.sql

rollback;
