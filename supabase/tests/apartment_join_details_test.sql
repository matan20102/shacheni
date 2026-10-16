begin;
\ir kit.sql

insert into auth.users(id, email, raw_user_meta_data)
select ('bc000000-0000-4000-8000-' || lpad(i::text,12,'0'))::uuid,
  'join-detail-' || i || '@example.test', jsonb_build_object('full_name', 'Test ' || i)
from generate_series(1,8) i;
create table t.v(k text primary key, v text);
grant all on t.v to public;
create function t.get(k text) returns text language sql as $$select v from t.v where t.v.k = $1$$;
create function t.put(k text, v text) returns void language sql as $$insert into t.v values($1,$2) on conflict(k) do update set v=excluded.v$$;
grant execute on function t.get(text), t.put(text,text) to public;

select t.as_anon();
select t.throws('anon cannot discover apartment status', $$select ba_apartment_status('CODE','12')$$, '42501');
select t.throws('anon cannot apply with family name', $$select ba_apply_home('CODE','12')$$, '42501');
select t.throws('anon cannot read apartment directory', $$select * from community_apartment$$, '42501');
select t.as_user('bc000000-0000-4000-8000-000000000008');
select t.throws('status requires consent', $$select ba_apartment_status('CODE','12')$$, 'LEGAL_NOT_ACCEPTED');
select t.throws('new creation requires consent', $$select ba_create_home_v2('Address')$$, 'LEGAL_NOT_ACCEPTED');

select t.as_user('bc000000-0000-4000-8000-000000000001');
select accept_legal_documents(array['terms_of_service','privacy_policy']::legal_doc_type[], 'he');
select t.put('b', ba_create_home_v2('הגננת 216, ירושלים', null, '00012', 2, 'משפחת כהן', 'א')::text);
select t.put('code', ba_state()->'homes'->0->>'code');
select t.ok('creator apartment is numeric and canonical', ba_state()->'homes'->0->>'apartment' = '12');
select t.ok('creator entrance is preserved', ba_state()->'homes'->0->>'entrance' = 'א');
select t.throws('new creation rejects letter suffix', $$select ba_create_home_v2('Other',null,'12א')$$, 'INVALID_ARGUMENT');
select t.throws('directory direct writes denied', $$update community_apartment set entrance = 'ב'$$, '42501');

select t.as_user('bc000000-0000-4000-8000-000000000002');
select accept_legal_documents(array['terms_of_service','privacy_policy']::legal_doc_type[], 'he');
select t.ok('existing apartment identified', (ba_apartment_status(t.get('code'),'0012','א')->>'exists')::boolean);
select t.ok('existing apartment manager identified', (ba_apartment_status(t.get('code'),'12','א')->>'has_admin')::boolean);
select t.ok('lookup reveals only two status flags', (select count(*) from jsonb_object_keys(ba_apartment_status(t.get('code'),'12','א'))) = 2);
select t.ok('entrance choice cannot duplicate the same apartment', (ba_apartment_status(t.get('code'),'12','ב')->>'exists')::boolean);
select t.ok('new number is identified as new', not (ba_apartment_status(t.get('code'),'99','א')->>'exists')::boolean);
select t.ok('unapproved lookup cannot read directory', t.count($$select * from community_apartment$$) = 0);
select t.throws('new application rejects letter suffix', $$select ba_apply_home(t.get('code'),'12א')$$, 'INVALID_ARGUMENT');
select t.put('existing', ba_apply_home(t.get('code'),'12',null,'א','Intruder')::text);
select t.ok('existing home ignores submitted replacement name', (select requested_household_name is null from community_member where id = t.get('existing')::uuid));
select t.as_user('bc000000-0000-4000-8000-000000000001');
select ba_approve(t.get('existing')::uuid,'building');
select t.as_user('bc000000-0000-4000-8000-000000000002');
select t.ok('building approval alone cannot open existing home', jsonb_array_length(ba_state()->'homes') = 0);
select t.as_user('bc000000-0000-4000-8000-000000000001');
select ba_approve(t.get('existing')::uuid,'apartment');
select t.as_user('bc000000-0000-4000-8000-000000000002');
select t.ok('existing family name survives both approvals', ba_state()->'homes'->0->>'household_name' = 'משפחת כהן');
select t.ok('joined family member is not manager', not (ba_state()->'homes'->0->>'is_apartment_admin')::boolean);

select t.as_user('bc000000-0000-4000-8000-000000000003');
select accept_legal_documents(array['terms_of_service','privacy_policy']::legal_doc_type[], 'he');
select t.put('new', ba_apply_home(t.get('code'),'99',null,'א','משפחת ישראלי')::text);
select t.ok('new family name is staged before approval', (select requested_household_name = 'משפחת ישראלי' from community_member where id = t.get('new')::uuid));
select t.ok('pending new family has no content access', jsonb_array_length(ba_state()->'homes') = 0 and t.count($$select * from community_household$$) = 0);
select t.as_user('bc000000-0000-4000-8000-000000000001');
select ba_approve(t.get('new')::uuid,'building');
select t.as_user('bc000000-0000-4000-8000-000000000003');
select t.ok('new family name saved after building approval', ba_state()->'homes'->0->>'household_name' = 'משפחת ישראלי');
select t.ok('first approved member becomes manager', (ba_state()->'homes'->0->>'is_apartment_admin')::boolean);

select t.as_user('bc000000-0000-4000-8000-000000000004');
select accept_legal_documents(array['terms_of_service','privacy_policy']::legal_doc_type[], 'he');
select t.put('entrance_b', ba_apply_home(t.get('code'),'24',null,'ב','משפחת לוי')::text);
select t.as_user('bc000000-0000-4000-8000-000000000001');
select t.throws('entrance A manager cannot approve entrance B household', $$select ba_approve(t.get('entrance_b')::uuid,'apartment')$$, 'ACCESS_DENIED');
select ba_approve(t.get('entrance_b')::uuid,'building');
select t.as_user('bc000000-0000-4000-8000-000000000004');
select t.ok('another apartment in B has independent family', ba_state()->'homes'->0->>'household_name' = 'משפחת לוי' and ba_state()->'homes'->0->>'apartment' = '24');
select t.ok('B cannot see A family', t.count($$select * from community_household$$) = 1);
select t.put('post', ba_publish(t.get('b')::uuid,'Entrance B post','notice')::text);
select t.ok('board label includes entrance without internal key', ba_board(t.get('b')::uuid)->0->>'apartment' = '24 · כניסה ב');

select t.as_user('bc000000-0000-4000-8000-000000000005');
select accept_legal_documents(array['terms_of_service','privacy_policy']::legal_doc_type[], 'he');
select t.put('race1', ba_apply_home(t.get('code'),'44',null,'א','First Family')::text);
select t.as_user('bc000000-0000-4000-8000-000000000006');
select accept_legal_documents(array['terms_of_service','privacy_policy']::legal_doc_type[], 'he');
select t.put('race2', ba_apply_home(t.get('code'),'44',null,'א','Second Family')::text);
select t.as_user('bc000000-0000-4000-8000-000000000001');
select ba_approve(t.get('race1')::uuid,'building');
select ba_approve(t.get('race2')::uuid,'building');
select t.as_user('bc000000-0000-4000-8000-000000000006');
select t.ok('second contender waits for new household manager', jsonb_array_length(ba_state()->'homes') = 0 and (ba_state()->'applications'->0->>'apartment_has_admin')::boolean);
select t.as_user('bc000000-0000-4000-8000-000000000005');
select ba_approve(t.get('race2')::uuid,'apartment');
select t.as_user('bc000000-0000-4000-8000-000000000006');
select t.ok('second contender cannot overwrite winning name', ba_state()->'homes'->0->>'household_name' = 'First Family');

select t.as_admin();
update public.building set settings = settings || '{"community_test_fixture":"join-check"}'::jsonb where id = t.get('b')::uuid;
select t.as_user('bc000000-0000-4000-8000-000000000007');
select accept_legal_documents(array['terms_of_service','privacy_policy']::legal_doc_type[], 'he');
select t.ok('CHECK resolves only explicitly marked fixture', ba_resolve('check')->>'id' = t.get('b'));
select t.ok('CHECK does not grant membership', jsonb_array_length(ba_state()->'homes') = 0);

select t.put('wrong_entrance', ba_apply_home(t.get('code'),'12',null,'ב','Wrong Family')::text);
select t.ok('wrong entrance still routes to existing household admin', (ba_state()->'applications'->0->>'apartment_has_admin')::boolean);
select t.as_user('bc000000-0000-4000-8000-000000000001');
select ba_approve(t.get('wrong_entrance')::uuid,'building');
select t.as_user('bc000000-0000-4000-8000-000000000007');
select t.ok('wrong entrance cannot bypass second approval', jsonb_array_length(ba_state()->'homes') = 0);
select t.as_user('bc000000-0000-4000-8000-000000000001');
select ba_approve(t.get('wrong_entrance')::uuid,'apartment');
select t.as_user('bc000000-0000-4000-8000-000000000007');
select t.ok('canonical family and entrance win over mismatching input', ba_state()->'homes'->0->>'household_name' = 'משפחת כהן' and ba_state()->'homes'->0->>'entrance' = 'א');
\ir report.sql
rollback;
