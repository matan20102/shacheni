begin;
\ir kit.sql
insert into auth.users(id,email,raw_user_meta_data)
select ('c3000000-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid,'inquiry-'||i||'@example.test',
  jsonb_build_object('full_name','Inquiry tester '||i) from generate_series(1,5)i;
create table t.v(k text primary key,v text); grant all on t.v to public;
create function t.get(k text) returns text language sql as $$select v from t.v where t.v.k=$1$$;
create function t.put(k text,v text) returns void language sql as $$insert into t.v values($1,$2) on conflict(k) do update set v=excluded.v$$;
grant execute on function t.get(text),t.put(text,text) to public;

select t.as_anon();
select t.throws('anon cannot list inquiries',$$select ba_inquiries(gen_random_uuid())$$,'42501');
select t.throws('anon cannot write',$$select ba_inquiry_open(gen_random_uuid(),'a','b')$$,'42501');

-- 1 creates the building (admin, so committee); 2 and 3 are residents; 4 is an outsider.
select t.as_user('c3000000-0000-4000-8000-000000000001');
select accept_legal_documents(array['terms_of_service','privacy_policy']::legal_doc_type[],'he');
select t.put('b',ba_create_home_v2('Inquiry test',null,'1')::text);
select t.put('code',ba_state()->'homes'->0->>'code');
select t.as_user('c3000000-0000-4000-8000-000000000002');
select accept_legal_documents(array['terms_of_service','privacy_policy']::legal_doc_type[],'he');
select t.put('m2',ba_apply_home(t.get('code'),'2')::text);
select t.throws('pending resident cannot write',$$select ba_inquiry_open(t.get('b')::uuid,'Noise','Hello')$$,'ACCESS_DENIED');
select t.as_user('c3000000-0000-4000-8000-000000000003');
select accept_legal_documents(array['terms_of_service','privacy_policy']::legal_doc_type[],'he');
select t.put('m3',ba_apply_home(t.get('code'),'3')::text);
select t.as_user('c3000000-0000-4000-8000-000000000001');
select ba_approve(t.get('m2')::uuid,'building'); select ba_approve(t.get('m3')::uuid,'building');

select t.as_user('c3000000-0000-4000-8000-000000000002');
select t.throws('direct table reads denied',$$select * from committee_inquiry$$,'42501');
select t.throws('direct message reads denied',$$select * from committee_inquiry_message$$,'42501');
select t.throws('private helper denied',$$select app.ba_inquiry_preview(gen_random_uuid())$$,'42501');
select t.throws('an inquiry needs a subject',$$select ba_inquiry_open(t.get('b')::uuid,' ','Hello')$$,'INVALID_ARGUMENT');
select t.throws('an inquiry needs a message',$$select ba_inquiry_open(t.get('b')::uuid,'Noise','  ')$$,'INVALID_ARGUMENT');
select t.put('q',ba_inquiry_open(t.get('b')::uuid,'Noise at night','The neighbours above are loud after midnight.')::text);
select t.ok('the author sees their inquiry',ba_inquiries(t.get('b')::uuid)->'mine'->0->>'subject'='Noise at night'
  and ba_inquiries(t.get('b')::uuid)->'mine'->0->>'status'='open'
  and not (ba_inquiries(t.get('b')::uuid)->'mine'->0->>'unread')::boolean);
select t.ok('residents get no inbox',jsonb_array_length(ba_inquiries(t.get('b')::uuid)->'inbox')=0
  and not (ba_inquiries(t.get('b')::uuid)->>'is_committee')::boolean);

select t.as_user('c3000000-0000-4000-8000-000000000003');
select t.ok('a neighbour sees nothing',jsonb_array_length(ba_inquiries(t.get('b')::uuid)->'mine')=0
  and jsonb_array_length(ba_inquiries(t.get('b')::uuid)->'inbox')=0);
select t.throws('a neighbour cannot open it',$$select ba_inquiry(t.get('q')::uuid)$$,'ACCESS_DENIED');
select t.throws('a neighbour cannot answer it',$$select ba_inquiry_reply(t.get('q')::uuid,'me too')$$,'ACCESS_DENIED');
select t.throws('a neighbour cannot close it',$$select ba_inquiry_status(t.get('q')::uuid,'handled')$$,'ACCESS_DENIED');

select t.as_user('c3000000-0000-4000-8000-000000000001');
select t.ok('the committee sees it in the inbox, unread, with who wrote it',
  (select i->>'author'||'/'||(i->>'apartment')||'/'||(i->>'unread') from jsonb_array_elements(ba_inquiries(t.get('b')::uuid)->'inbox') i
    where i->>'id'=t.get('q'))='Inquiry tester 2/2/true'
  and (ba_inquiries(t.get('b')::uuid)->>'unread')::int=1);
select t.ok('the committee got an update',exists(select 1 from notification where user_id='c3000000-0000-4000-8000-000000000001'
  and type='committee.inquiry' and entity_id=t.get('q')::uuid and read_at is null));
select t.ok('the bell shows the subject to the committee, not the message',
  (select n->>'text' from jsonb_array_elements(ba_state()->'notifications') n where n->>'type'='committee.inquiry')='Noise at night');
select t.ok('opening shows the message',ba_inquiry(t.get('q')::uuid)->'messages'->0->>'body'='The neighbours above are loud after midnight.'
  and ba_inquiry(t.get('q')::uuid)->>'side'='committee');
select t.ok('opening marks it read',(ba_inquiries(t.get('b')::uuid)->>'unread')::int=0
  and not exists(select 1 from notification where user_id='c3000000-0000-4000-8000-000000000001'
    and type='committee.inquiry' and read_at is null));
select ba_inquiry_reply(t.get('q')::uuid,'Thanks, we will talk to them.');
select ba_inquiry_status(t.get('q')::uuid,'handled');
select t.throws('status is checked',$$select ba_inquiry_status(t.get('q')::uuid,'gone')$$,'INVALID_ARGUMENT');

select t.as_user('c3000000-0000-4000-8000-000000000002');
select t.ok('the author sees the answer as unread and handled',(ba_inquiries(t.get('b')::uuid)->'mine'->0->>'unread')::boolean
  and ba_inquiries(t.get('b')::uuid)->'mine'->0->>'status'='handled'
  and ba_inquiries(t.get('b')::uuid)->'mine'->0->>'preview'='Thanks, we will talk to them.');
select t.ok('the bell tells the author the committee answered',
  (select n->>'text' from jsonb_array_elements(ba_state()->'notifications') n where n->>'type'='committee.inquiry_reply')='Noise at night');
select t.ok('the answer is signed by the committee, not the member',
  ba_inquiry(t.get('q')::uuid)->'messages'->1->>'name'='הוועד'
  and (ba_inquiry(t.get('q')::uuid)->'messages'->1->>'from_committee')::boolean);
select t.ok('reading clears it',(ba_inquiries(t.get('b')::uuid)->>'unread')::int=0);
select t.throws('only the committee changes the status',$$select ba_inquiry_status(t.get('q')::uuid,'open')$$,'ACCESS_DENIED');
select ba_inquiry_reply(t.get('q')::uuid,'It happened again yesterday.');
select t.ok('writing again reopens it',ba_inquiries(t.get('b')::uuid)->'mine'->0->>'status'='open');

select t.as_user('c3000000-0000-4000-8000-000000000001');
select t.ok('the reopened inquiry is unread for the committee',(ba_inquiries(t.get('b')::uuid)->>'unread')::int=1
  and jsonb_array_length(ba_inquiry(t.get('q')::uuid)->'messages')=3);

-- A committee member added later sees it too; once removed, no longer.
select ba_committee_set_member(t.get('m3')::uuid,true);
select t.as_user('c3000000-0000-4000-8000-000000000003');
select t.ok('an added committee member sees the inbox',jsonb_array_length(ba_inquiries(t.get('b')::uuid)->'inbox')=1
  and ba_inquiry(t.get('q')::uuid)->'messages'->1->>'name'='Inquiry tester 1');
select t.as_user('c3000000-0000-4000-8000-000000000001');
select ba_committee_set_member(t.get('m3')::uuid,false);
select t.as_user('c3000000-0000-4000-8000-000000000003');
select t.throws('a removed member cannot read it',$$select ba_inquiry(t.get('q')::uuid)$$,'ACCESS_DENIED');

select t.as_user('c3000000-0000-4000-8000-000000000004');
select accept_legal_documents(array['terms_of_service','privacy_policy']::legal_doc_type[],'he');
select t.throws('outsiders cannot list',$$select ba_inquiries(t.get('b')::uuid)$$,'ACCESS_DENIED');
select t.throws('outsiders cannot read',$$select ba_inquiry(t.get('q')::uuid)$$,'ACCESS_DENIED');

select t.as_user('c3000000-0000-4000-8000-000000000002');
select ba_inquiry_open(t.get('b')::uuid,'Two','x'); select ba_inquiry_open(t.get('b')::uuid,'Three','x');
select ba_inquiry_open(t.get('b')::uuid,'Four','x'); select ba_inquiry_open(t.get('b')::uuid,'Five','x');
select t.throws('five inquiries a day at most',$$select ba_inquiry_open(t.get('b')::uuid,'Six','x')$$,'TRY_LATER');
select ba_delete_account();
select t.as_user('c3000000-0000-4000-8000-000000000001');
select t.ok('a deleted inquiry leaves nothing in the bell',
  not exists(select 1 from jsonb_array_elements(ba_state()->'notifications') n where n->>'type' like 'committee.inquiry%'));
select t.ok('a deleted account takes its inquiries with it',jsonb_array_length(ba_inquiries(t.get('b')::uuid)->'inbox')=0);
select t.as_admin();
select t.ok('and their messages',(select count(*) from committee_inquiry_message where building_id=t.get('b')::uuid)=0);
\ir report.sql
rollback;
