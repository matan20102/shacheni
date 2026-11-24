begin;
\ir kit.sql
insert into auth.users(id,email,raw_user_meta_data)
select ('c2000000-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid,'committee-'||i||'@example.test',
  jsonb_build_object('full_name','Committee tester '||i) from generate_series(1,5)i;
create table t.v(k text primary key,v text); grant all on t.v to public;
create function t.get(k text) returns text language sql as $$select v from t.v where t.v.k=$1$$;
create function t.put(k text,v text) returns void language sql as $$insert into t.v values($1,$2) on conflict(k) do update set v=excluded.v$$;
grant execute on function t.get(text),t.put(text,text) to public;
create function t.charge(title text) returns jsonb language sql as $$
  select c from jsonb_array_elements(ba_committee(t.get('b')::uuid)->'charges') c where c->>'title'=title$$;
grant execute on function t.charge(text) to public;

select t.as_anon();
select t.throws('anon cannot read the committee page',$$select ba_committee(gen_random_uuid())$$,'42501');
select t.throws('anon cannot report payments',$$select ba_committee_report(gen_random_uuid(),'bit')$$,'42501');

-- 1 creates the building (admin, so committee); 2 and 3 are residents of other apartments; 4 is an outsider.
select t.as_user('c2000000-0000-4000-8000-000000000001');
select accept_legal_documents(array['terms_of_service','privacy_policy']::legal_doc_type[],'he');
select t.put('b',ba_create_home_v2('Committee test',null,'1')::text);
select t.put('code',ba_state()->'homes'->0->>'code');
select t.as_user('c2000000-0000-4000-8000-000000000002');
select accept_legal_documents(array['terms_of_service','privacy_policy']::legal_doc_type[],'he');
select t.put('m2',ba_apply_home(t.get('code'),'2')::text);
select t.throws('pending resident cannot see the page',$$select ba_committee(t.get('b')::uuid)$$,'ACCESS_DENIED');
select t.as_user('c2000000-0000-4000-8000-000000000003');
select accept_legal_documents(array['terms_of_service','privacy_policy']::legal_doc_type[],'he');
select t.put('m3',ba_apply_home(t.get('code'),'3')::text);
select t.as_user('c2000000-0000-4000-8000-000000000001');
select ba_approve(t.get('m2')::uuid,'building'); select ba_approve(t.get('m3')::uuid,'building');

select t.ok('every building starts with its admins as the committee',
  (ba_committee(t.get('b')::uuid)->>'is_committee')::boolean
  and ba_committee(t.get('b')::uuid)->'committee'='["Committee tester 1"]'::jsonb);
select t.ok('the committee sees who it can add',jsonb_array_length(ba_committee(t.get('b')::uuid)->'members')=3);
select t.ok('no fee until the committee sets one',jsonb_array_length(ba_committee(t.get('b')::uuid)->'charges')=0);
select t.throws('direct table reads denied',$$select * from committee_charge$$,'42501');
select t.throws('direct table writes denied',$$insert into committee_payment default values$$,'42501');
select t.throws('private helper denied',$$select app.ba_committee_actor(t.get('b')::uuid,true)$$,'42501');
select t.throws('payment links must be https',$$select ba_committee_settings(t.get('b')::uuid,150,10,'http://bit.example','')$$,'INVALID_ARGUMENT');
select t.throws('due day stays inside every month',$$select ba_committee_settings(t.get('b')::uuid,150,31)$$,'INVALID_ARGUMENT');
select t.lives('committee sets the monthly fee and links',
  $$select ba_committee_settings(t.get('b')::uuid,150,10,'https://www.bitpay.co.il/app/me/abc','https://link.payboxapp.com/xyz','לדירה 1')$$);
select t.ok('the monthly fee opens itself',(t.charge('דמי ועד')->>'amount')::int=150
  and t.charge('דמי ועד')->>'kind'='monthly'
  and (t.charge('דמי ועד')->>'due_on')::date=greatest(date_trunc('month',now() at time zone 'Asia/Jerusalem')::date+9,
    (now() at time zone 'Asia/Jerusalem')::date+7));
select t.ok('looking again does not open a second month',
  (select count(*) from jsonb_array_elements(ba_committee(t.get('b')::uuid)->'charges') c where c->>'kind'='monthly')=1);
select ba_committee_settings(t.get('b')::uuid,180,5,'https://www.bitpay.co.il/app/me/abc','https://link.payboxapp.com/xyz','לדירה 1');
select t.ok('an unpaid month follows the new amount',(t.charge('דמי ועד')->>'amount')::int=180);
select t.throws('a charge needs a title',$$select ba_committee_charge(t.get('b')::uuid,' ','',200,current_date+5)$$,'INVALID_ARGUMENT');
select t.throws('a charge needs an amount',$$select ba_committee_charge(t.get('b')::uuid,'Door','',0,current_date+5)$$,'INVALID_ARGUMENT');
select t.throws('a charge cannot be due in the past',$$select ba_committee_charge(t.get('b')::uuid,'Door','',200,current_date-5)$$,'INVALID_ARGUMENT');
select t.put('door',ba_committee_charge(t.get('b')::uuid,'Door repair','The entrance door lock',200,current_date+14)::text);
select t.ok('committee sees every apartment',jsonb_array_length(t.charge('Door repair')->'apartments')=3
  and (t.charge('Door repair')->>'households')::int=3 and (t.charge('Door repair')->>'paid')::int=0);

select t.as_user('c2000000-0000-4000-8000-000000000002');
select t.ok('residents see the page but are not the committee',not (ba_committee(t.get('b')::uuid)->>'is_committee')::boolean);
select t.ok('residents see the payment links',ba_committee(t.get('b')::uuid)->'settings'->>'bit_link'='https://www.bitpay.co.il/app/me/abc');
select t.ok('residents do not see other apartments',jsonb_array_length(t.charge('Door repair')->'apartments')=0
  and jsonb_array_length(ba_committee(t.get('b')::uuid)->'members')=0);
select t.throws('residents cannot add charges',$$select ba_committee_charge(t.get('b')::uuid,'Mine','',1,current_date+1)$$,'ACCESS_DENIED');
select t.throws('residents cannot change settings',$$select ba_committee_settings(t.get('b')::uuid,1,1)$$,'ACCESS_DENIED');
select t.throws('residents cannot mark payments',
  $$select ba_committee_mark(t.get('door')::uuid,(select apartment_id from community_member where id=t.get('m2')::uuid),true)$$,'ACCESS_DENIED');
select t.throws('payment method is checked',$$select ba_committee_report(t.get('door')::uuid,'gold')$$,'INVALID_ARGUMENT');
select ba_committee_report(t.get('door')::uuid,'bit');
select t.ok('a report waits for the committee',t.charge('Door repair')->>'my_status'='reported'
  and (t.charge('Door repair')->>'paid')::int=0);

select t.as_user('c2000000-0000-4000-8000-000000000003');
select t.ok('the neighbour does not see the report',t.charge('Door repair')->>'my_status'='');

select t.as_user('c2000000-0000-4000-8000-000000000001');
select t.ok('the committee sees the report and its method',
  (select a->>'status'||'/'||(a->>'method') from jsonb_array_elements(t.charge('Door repair')->'apartments') a where a->>'apartment'='2')='reported/bit');
select ba_committee_mark(t.get('door')::uuid,(select apartment_id from community_member where id=t.get('m2')::uuid),true);
select ba_committee_mark(t.get('door')::uuid,(select apartment_id from community_member where id=t.get('m3')::uuid),true,'cash');
select t.ok('confirmed and cash payments count',(t.charge('Door repair')->>'paid')::int=2
  and (select a->>'method' from jsonb_array_elements(t.charge('Door repair')->'apartments') a where a->>'apartment'='3')='cash');
select t.throws('only apartments of the building can be marked',$$select ba_committee_mark(t.get('door')::uuid,gen_random_uuid(),true)$$,'INVALID_ARGUMENT');

select t.as_user('c2000000-0000-4000-8000-000000000002');
select ba_committee_report(t.get('door')::uuid,'paybox');
select t.ok('a confirmed payment is not reopened by another report',t.charge('Door repair')->>'my_status'='confirmed');
select t.ok('residents see the building total',(t.charge('Door repair')->>'paid')::int=2);

select t.as_user('c2000000-0000-4000-8000-000000000001');
select ba_committee_mark(t.get('door')::uuid,(select apartment_id from community_member where id=t.get('m3')::uuid),false);
select t.ok('the committee can undo a mark',(t.charge('Door repair')->>'paid')::int=1);

-- Committee membership.
select t.throws('the admin stays on the committee',$$select ba_committee_set_member((select id from community_member
  where user_id='c2000000-0000-4000-8000-000000000001'),false)$$,'COMMITTEE_ADMIN');
select ba_committee_set_member(t.get('m3')::uuid,true);
select t.as_user('c2000000-0000-4000-8000-000000000003');
select t.ok('an added member runs the committee',(ba_committee(t.get('b')::uuid)->>'is_committee')::boolean
  and jsonb_array_length(t.charge('Door repair')->'apartments')=3);
select t.lives('an added member can add charges',$$select ba_committee_charge(t.get('b')::uuid,'Garden','',50,current_date+3)$$);
select t.as_user('c2000000-0000-4000-8000-000000000002');
select t.throws('residents cannot add committee members',$$select ba_committee_set_member(t.get('m2')::uuid,true)$$,'ACCESS_DENIED');
select t.as_user('c2000000-0000-4000-8000-000000000001');
select ba_committee_set_member(t.get('m3')::uuid,false);
select t.as_user('c2000000-0000-4000-8000-000000000003');
select t.ok('a removed member is a resident again',not (ba_committee(t.get('b')::uuid)->>'is_committee')::boolean);
select t.throws('a removed member cannot add charges',$$select ba_committee_charge(t.get('b')::uuid,'More','',1,current_date+1)$$,'ACCESS_DENIED');

select t.as_user('c2000000-0000-4000-8000-000000000001');
select ba_committee_cancel(t.get('door')::uuid);
select t.ok('a cancelled charge leaves the page',t.charge('Door repair') is null);
select t.throws('a cancelled charge takes no reports',$$select ba_committee_mark(t.get('door')::uuid,
  (select apartment_id from community_member where id=t.get('m2')::uuid),true)$$,'COMMITTEE_CHARGE_CLOSED');

select t.as_user('c2000000-0000-4000-8000-000000000004');
select accept_legal_documents(array['terms_of_service','privacy_policy']::legal_doc_type[],'he');
select t.throws('outsiders cannot see the page',$$select ba_committee(t.get('b')::uuid)$$,'ACCESS_DENIED');
select t.throws('outsiders cannot cancel',$$select ba_committee_cancel(t.get('door')::uuid)$$,'ACCESS_DENIED');
\ir report.sql
rollback;
