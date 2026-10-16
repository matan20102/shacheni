begin;
\ir kit.sql

insert into auth.users(id, email, raw_user_meta_data) values
('ba000000-0000-4000-8000-000000000001', 'creator@example.test', '{"full_name":"Creator"}'),
('ba000000-0000-4000-8000-000000000002', 'first@example.test', '{"full_name":"First"}'),
('ba000000-0000-4000-8000-000000000003', 'second@example.test', '{"full_name":"Second"}'),
('ba000000-0000-4000-8000-000000000004', 'other@example.test', '{"full_name":"Other", "is_building_admin":true}'),
('ba000000-0000-4000-8000-000000000005', 'unsigned@example.test', '{}');

create table t.v(k text primary key, v text);
grant all on t.v to public;
create function t.get(k text) returns text language sql as $$select v from t.v where t.v.k = $1$$;
create function t.put(k text, v text) returns void language sql as $$insert into t.v values($1,$2) on conflict(k) do update set v=excluded.v$$;
grant execute on function t.get(text), t.put(text,text) to public;

select t.as_user('ba000000-0000-4000-8000-000000000005');
select t.throws('household creation needs consent', $$select ba_create_home('Address',null,'1',1,'Family')$$, 'LEGAL_NOT_ACCEPTED');
select t.as_anon();
select t.throws('anon cannot create named home', $$select ba_create_home('Address')$$, '42501');
select t.throws('anon cannot rename a household', $$select ba_set_household(gen_random_uuid(), 'Name')$$, '42501');
select t.throws('anon cannot read household names', $$select * from community_household$$, '42501');

select t.as_user('ba000000-0000-4000-8000-000000000001');
select accept_legal_documents(array['terms_of_service','privacy_policy']::legal_doc_type[], 'he');
select t.put('b', ba_create_home('הגפן 18, רמת גן', '', '12א', 9, ' משפחת כהן ')::text);
select t.put('code', ba_state()->'homes'->0->>'code');
select t.ok('household name and building name are separate', ba_state()->'homes'->0->>'household_name' = 'משפחת כהן' and ba_state()->'homes'->0->>'name' = 'הגפן 18, רמת גן');
select t.ok('nine entrances accepted', (ba_state()->'homes'->0->>'entrances')::int = 9);
select t.throws('new creation caps entrances at nine', $$select ba_create_home('Too many',null,'1',10,'Family')$$, 'INVALID_ARGUMENT');
select t.throws('long household name is rejected', $$select ba_create_home('Too long',null,'1',1,repeat('x',61))$$, 'INVALID_ARGUMENT');
select t.ok('failed validation leaves no orphan building', jsonb_array_length(ba_state()->'homes') = 1);
select t.ok('own household name is readable', t.count($$select * from community_household$$) = 1);
select t.throws('direct household write denied', $$update community_household set display_name = 'Spoofed'$$, '42501');
select ba_set_household(t.get('b')::uuid, 'משפחת לוי');
select t.ok('manager can rename their household', ba_state()->'homes'->0->>'household_name' = 'משפחת לוי');
select ba_set_household(t.get('b')::uuid, '');
select t.ok('optional household name can be cleared', ba_state()->'homes'->0->>'household_name' = '' and t.count($$select * from community_household$$) = 0);
select ba_set_household(t.get('b')::uuid, 'משפחת כהן');
select t.put('b2', ba_create_home('Other building', null, '12א', 1, 'Second Family')::text);
select t.ok('households stay separate across buildings', (select count(*) from community_household) = 2);

select t.as_user('ba000000-0000-4000-8000-000000000002');
select accept_legal_documents(array['terms_of_service','privacy_policy']::legal_doc_type[], 'he');
select t.put('member', ba_join(t.get('code'), '12א')::text);
select t.ok('pending member cannot read family names', t.count($$select * from community_household$$) = 0);
select t.throws('pending member cannot rename family', $$select ba_set_household(t.get('b')::uuid,'Intruder')$$, 'ACCESS_DENIED');
select t.as_user('ba000000-0000-4000-8000-000000000001');
select ba_approve(t.get('member')::uuid, 'building');
select ba_approve(t.get('member')::uuid, 'apartment');
select t.as_user('ba000000-0000-4000-8000-000000000002');
select t.ok('approved family member sees shared name', ba_state()->'homes'->0->>'household_name' = 'משפחת כהן');
select t.ok('family member cannot read other building names', t.count($$select * from community_household$$) = 1);
select t.throws('ordinary family member cannot rename it', $$select ba_set_household(t.get('b')::uuid,'Unauthorized')$$, 'ACCESS_DENIED');

select t.as_user('ba000000-0000-4000-8000-000000000003');
select accept_legal_documents(array['terms_of_service','privacy_policy']::legal_doc_type[], 'he');
select t.put('new_apartment', ba_join(t.get('code'), '99')::text);
select t.as_user('ba000000-0000-4000-8000-000000000001');
select ba_approve(t.get('new_apartment')::uuid, 'building');
select t.as_user('ba000000-0000-4000-8000-000000000003');
select t.ok('different apartment cannot read another family name', t.count($$select * from community_household$$) = 0);
select ba_set_household(t.get('b')::uuid,'משפחת ישראלי');
select t.ok('new apartment manager names only their own home', ba_state()->'homes'->0->>'household_name' = 'משפחת ישראלי');
select t.as_user('ba000000-0000-4000-8000-000000000001');
select t.ok('other apartment rename leaves original family unchanged', ba_state()->'homes'->0->>'household_name' = 'משפחת כהן');
\ir report.sql
rollback;
