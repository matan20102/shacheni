begin;
\ir kit.sql
\ir ../fixtures/check_building.sql
\ir ../fixtures/check_building.sql
select t.ok('fixture is idempotent', (select count(*) from public.building where settings->>'community_test_fixture' = 'join-check') = 1);
select t.ok('fixture creates exactly three synthetic identities', (select count(*) from auth.users where raw_user_meta_data->>'test_fixture' = 'join-check') = 3);
select t.ok('fixture has unique apartment numbering across entrances', (select count(*) from public.community_apartment d join public.building b on b.id = d.building_id where b.settings->>'community_test_fixture' = 'join-check' and d.number in ('12','24')) = 2);
select t.ok('fixture has an unclaimed apartment', exists(select 1 from public.community_apartment d join public.building b on b.id = d.building_id where b.settings->>'community_test_fixture' = 'join-check' and d.number = '8' and not exists(select 1 from public.community_member m where m.apartment_id = d.apartment_id)));
select t.ok('no legal acceptance is manufactured for fixtures', (select count(*) from public.legal_acceptance) = 0);
\ir report.sql
rollback;
