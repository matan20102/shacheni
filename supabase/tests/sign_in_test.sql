-- Sign-in tests: Google profile bootstrap, consent gate RPCs, update_my_profile.
--   psql -v ON_ERROR_STOP=1 -f supabase/tests/sign_in_test.sql

begin;

\ir kit.sql

-- Google users: email + metadata, no phone.
insert into auth.users (id, email, raw_user_meta_data) values
  ('a1000000-0000-4000-8000-000000000001', 'noa@example.com', '{"full_name": "Noa Levi", "email": "noa@example.com"}'),
  ('a1000000-0000-4000-8000-000000000002', 'tom@example.com', '{"name": "Tom Cohen"}'),
  ('a1000000-0000-4000-8000-000000000003', 'x@example.com', '{}');

select t.ok('profile name taken from Google full_name',
  (select full_name from profile where id = 'a1000000-0000-4000-8000-000000000001') = 'Noa Levi');
select t.ok('profile name falls back to Google name',
  (select full_name from profile where id = 'a1000000-0000-4000-8000-000000000002') = 'Tom Cohen');
select t.ok('profile without metadata gets an empty name and no phone',
  (select full_name = '' and phone_e164 is null from profile where id = 'a1000000-0000-4000-8000-000000000003'));

-- ---------------------------------------------------------------------------------------------
-- Consent gate
-- ---------------------------------------------------------------------------------------------
select t.as_user('a1000000-0000-4000-8000-000000000001');
select t.ok('new user must accept terms + privacy',
  t.count($$select * from my_pending_legal_documents(p_locale => 'he')$$) = 2);
select t.ok('pending docs come in the requested locale',
  (select bool_and(locale = 'en') from my_pending_legal_documents(p_locale => 'en')));
select t.ok('building-scoped types are never part of the sign-in gate',
  t.count($$select * from my_pending_legal_documents(array['community_rules', 'terms_of_service']::legal_doc_type[], 'he')$$) = 1);
select t.throws('cannot accept a building-scoped document here',
  $$select accept_legal_documents(array['building_agreement']::legal_doc_type[], 'he')$$, 'INVALID_ARGUMENT');
select t.throws('must accept at least one document',
  $$select accept_legal_documents(array[]::legal_doc_type[], 'he')$$, 'INVALID_ARGUMENT');

select t.lives('accept terms + privacy',
  $$select accept_legal_documents(array['terms_of_service', 'privacy_policy']::legal_doc_type[], 'en', '0.1.0')$$);
select t.ok('nothing pending after acceptance', t.count($$select * from my_pending_legal_documents()$$) = 0);
select t.ok('acceptance recorded with version, locale and the exact document shown',
  t.count($$select * from legal_acceptance a join legal_document d on d.id = a.document_id
            where a.user_id = 'a1000000-0000-4000-8000-000000000001' and a.locale = 'en' and d.locale = 'en'
              and a.document_version = '0.0-todo' and a.app_version = '0.1.0'$$) = 2);
select t.lives('accepting again is a no-op',
  $$select accept_legal_documents(array['terms_of_service']::legal_doc_type[], 'he')$$);
select t.ok('still exactly two acceptance rows', t.count('select * from legal_acceptance') = 2);

select t.as_user('a1000000-0000-4000-8000-000000000002');
select t.ok('acceptance is per user', t.count($$select * from my_pending_legal_documents()$$) = 2);

-- New privacy policy version → re-acceptance required for privacy only.
select t.as_admin();
select publish_legal_document('privacy_policy', '1.0', 'he', 'מדיניות פרטיות', 'v1 he');
select publish_legal_document('privacy_policy', '1.0', 'en', 'Privacy Policy', 'v1 en');
select t.as_user('a1000000-0000-4000-8000-000000000001');
select t.ok('new privacy version re-opens the gate for privacy only',
  (select array_agg(type::text) from my_pending_legal_documents()) = '{privacy_policy}');
select t.lives('accept the new version',
  $$select accept_legal_documents(array['privacy_policy']::legal_doc_type[], 'he')$$);
select t.ok('gate closed again', t.count($$select * from my_pending_legal_documents()$$) = 0);

select t.as_anon();
select t.throws('anon cannot use the consent RPCs', $$select * from my_pending_legal_documents()$$, '42501');

-- ---------------------------------------------------------------------------------------------
-- update_my_profile
-- ---------------------------------------------------------------------------------------------
select t.as_user('a1000000-0000-4000-8000-000000000001');
select t.ok('local mobile format normalized to E.164',
  (select phone_e164 from update_my_profile(p_phone => '050-123-4567')) = '+972501234567');
select t.ok('international format accepted',
  (select phone_e164 from update_my_profile(p_phone => '+972 52 765 4321')) = '+972527654321');
select t.throws('landline / garbage rejected', $$select update_my_profile(p_phone => '03-1234567')$$, 'PHONE_INVALID');
select t.throws('name too short rejected', $$select update_my_profile(p_full_name => ' a ')$$, 'INVALID_ARGUMENT');
select t.ok('name and locale updated, phone kept',
  (select full_name = 'Noa Levi-Cohen' and locale = 'en' and phone_e164 = '+972527654321'
   from update_my_profile(p_full_name => ' Noa Levi-Cohen ', p_locale => 'en')));

select t.as_user('a1000000-0000-4000-8000-000000000002');
select t.throws('phone already used by another profile', $$select update_my_profile(p_phone => '0527654321')$$, 'PHONE_TAKEN');
select t.ok('update_my_profile only touches the caller''s row',
  (select phone_e164 is null from update_my_profile(p_full_name => 'Tom C')));
select t.throws('still no direct UPDATE on profile', $$update profile set full_name = 'hack'$$, '42501');

\ir report.sql

rollback;
