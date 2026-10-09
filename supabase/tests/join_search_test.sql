-- Finding a building by name / address (F37).
--   psql -v ON_ERROR_STOP=1 -f supabase/tests/join_search_test.sql

begin;

\ir kit.sql

insert into auth.users (id, email) values
  ('a3000000-0000-4000-8000-000000000001', 'owner@example.com'),
  ('a3000000-0000-4000-8000-000000000002', 'noa@example.com'),
  ('a3000000-0000-4000-8000-000000000003', 'new@example.com');  -- never accepted the terms

insert into building (id, name, address, city, declared_apartment_count, declared_parking_count, status, activated_at, join_code, created_by)
values
  ('b3000000-0000-4000-8000-000000000001', 'Herzl 12', '12 Herzl St', 'Tel Aviv', 2, 1, 'active', now(), 'HERZ2345', 'a3000000-0000-4000-8000-000000000001'),
  ('b3000000-0000-4000-8000-000000000002', 'מגדלי הים', 'הרצל 40', 'חיפה', 1, 0, 'active', now(), 'HAFA2345', 'a3000000-0000-4000-8000-000000000001'),
  ('b3000000-0000-4000-8000-000000000003', 'Herzl Draft', '99 Herzl St', 'Tel Aviv', 1, 0, 'draft', null, null, 'a3000000-0000-4000-8000-000000000001');
insert into apartment (building_id, number) values
  ('b3000000-0000-4000-8000-000000000001', '1'), ('b3000000-0000-4000-8000-000000000001', '2'),
  ('b3000000-0000-4000-8000-000000000002', '7');
insert into parking_space (building_id, label) values ('b3000000-0000-4000-8000-000000000001', 'P1');

select t.as_user('a3000000-0000-4000-8000-000000000002');
select accept_legal_documents(array['terms_of_service', 'privacy_policy']::legal_doc_type[], 'he');

select t.ok('search by street finds the active building only (not the draft)',
  (select jsonb_array_length(r) = 1 and r -> 0 ->> 'name' = 'Herzl 12' from (select search_buildings('herzl st') as r) s));
select t.ok('search by city is case-insensitive', jsonb_array_length(search_buildings('TEL AVIV')) = 1);
select t.ok('Hebrew search works', (search_buildings('הרצל') -> 0 ->> 'name') = 'מגדלי הים');
select t.ok('results carry only id, name, address, city',
  (select array_agg(k order by k) from jsonb_object_keys(search_buildings('herzl') -> 0) k) = '{address,city,id,name}');
select t.ok('no match → empty list', search_buildings('nowhere') = '[]');
select t.throws('at least 2 characters', $$select search_buildings(' h ')$$, 'INVALID_ARGUMENT');

select t.ok('pick-lists for a chosen building',
  (select jsonb_array_length(j -> 'apartments') = 2 and jsonb_array_length(j -> 'spaces') = 1
   from (select get_join_info('b3000000-0000-4000-8000-000000000001') as j) s));
select t.throws('no pick-lists for a draft building',
  $$select get_join_info('b3000000-0000-4000-8000-000000000003')$$, 'NOT_FOUND');
select t.ok('join code still works', (resolve_join_code('herz-2345') -> 'building' ->> 'name') = 'Herzl 12');

select t.as_admin();
select t.ok('searches do not use up the join-code attempts',
  (select count(*) from join_code_attempt where kind = 'code' and not succeeded) = 0);
select t.as_user('a3000000-0000-4000-8000-000000000002');
select t.ok('25 more searches are answered',
  (select bool_and(jsonb_typeof(search_buildings('herzl')) = 'array') from generate_series(1, 25)));
select t.throws('the 31st search within an hour is rate-limited', $$select search_buildings('herzl')$$, 'RATE_LIMITED');
select t.ok('a wrong join code is still allowed after the search limit', resolve_join_code('WRONGWRO') is null);

select t.as_user('a3000000-0000-4000-8000-000000000003');
select t.throws('terms must be accepted before searching', $$select search_buildings('herzl')$$, 'LEGAL_NOT_ACCEPTED');
select t.throws('terms must be accepted before loading pick-lists',
  $$select get_join_info('b3000000-0000-4000-8000-000000000001')$$, 'LEGAL_NOT_ACCEPTED');

select t.as_anon();
select t.throws('anon cannot search', $$select search_buildings('herzl')$$, '42501');

\ir report.sql

rollback;
