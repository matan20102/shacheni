begin;
\ir kit.sql
insert into auth.users(id,email,raw_user_meta_data)
select ('bd000000-0000-4000-8000-' || lpad(i::text,12,'0'))::uuid,
 'approval-' || i || '@example.test', jsonb_build_object('full_name','Test ' || i)
from generate_series(1,4) i;
create table t.v(k text primary key, v text);
grant all on t.v to public;
create function t.get(k text) returns text language sql as $$select v from t.v where t.v.k = $1$$;
create function t.put(k text, v text) returns void language sql as $$insert into t.v values($1,$2) on conflict(k) do update set v=excluded.v$$;
grant execute on function t.get(text), t.put(text,text) to public;

select t.as_anon();
select t.throws('anon cannot mark approvals read', $$select ba_read_approval_updates('{}'::uuid[])$$, '42501');
select t.as_user('bd000000-0000-4000-8000-000000000004');
select t.throws('acknowledgement requires current consent', $$select ba_read_approval_updates('{}'::uuid[])$$, 'LEGAL_NOT_ACCEPTED');
select t.as_user('bd000000-0000-4000-8000-000000000001');
select accept_legal_documents(array['terms_of_service','privacy_policy']::legal_doc_type[],'he');
select t.put('b',ba_create_home_v2('Approval building',null,'12')::text);
select t.put('code',ba_state()->'homes'->0->>'code');
select t.ok('creating a building does not pretend to be an approval', jsonb_array_length(ba_state()->'approval_updates')=0);

select t.as_user('bd000000-0000-4000-8000-000000000002');
select accept_legal_documents(array['terms_of_service','privacy_policy']::legal_doc_type[],'he');
select t.put('member',ba_apply_home(t.get('code'),'12')::text);
select t.ok('submitting an application is not an unread update', jsonb_array_length(ba_state()->'approval_updates')=0);
select t.as_user('bd000000-0000-4000-8000-000000000001');
select t.ok('manager still receives incoming request', t.count($$select * from notification where type='community.application_received' and read_at is null$$)=1);
select t.put('incoming',(select id::text from notification where type='community.application_received'));
select ba_read_approval_updates(array[t.get('incoming')::uuid]);
select t.ok('acknowledgement does not alter request notifications', t.count($$select * from notification where type='community.application_received' and read_at is null$$)=1);
select ba_approve(t.get('member')::uuid,'building');
select t.as_user('bd000000-0000-4000-8000-000000000002');
select t.ok('one of two required approvals is not acceptance', jsonb_array_length(ba_state()->'approval_updates')=0);
select t.as_user('bd000000-0000-4000-8000-000000000001');
select ba_approve(t.get('member')::uuid,'apartment');
select t.ok('manager does not see another users acceptance', jsonb_array_length(ba_state()->'approval_updates')=0);
select t.as_user('bd000000-0000-4000-8000-000000000002');
select t.ok('full acceptance produces one unread update', jsonb_array_length(ba_state()->'approval_updates')=1);
select t.ok('acceptance update references approved building', ba_state()->'approval_updates'->0->>'building_id'=t.get('b'));
select t.put('update',ba_state()->'approval_updates'->0->>'id');
select t.throws('direct notification updates remain denied', $$update notification set read_at=now()$$,'42501');
select t.throws('null acknowledgement rejected', $$select ba_read_approval_updates(null)$$,'INVALID_ARGUMENT');
select t.throws('oversized acknowledgement rejected', $$select ba_read_approval_updates(array_fill(gen_random_uuid(),array[101]))$$,'INVALID_ARGUMENT');

select t.as_user('bd000000-0000-4000-8000-000000000003');
select accept_legal_documents(array['terms_of_service','privacy_policy']::legal_doc_type[],'he');
select t.ok('unrelated user cannot see approval details', jsonb_array_length(ba_state()->'approval_updates')=0);
select ba_read_approval_updates(array[t.get('update')::uuid]);
select t.as_user('bd000000-0000-4000-8000-000000000002');
select t.ok('another user cannot clear the approval', jsonb_array_length(ba_state()->'approval_updates')=1);
select ba_read_approval_updates(array[t.get('update')::uuid]);
select t.ok('reading clears unread update', jsonb_array_length(ba_state()->'approval_updates')=0);
select ba_read_approval_updates(array[t.get('update')::uuid]);
select t.ok('reading remains cleared on subsequent state loads', jsonb_array_length(ba_state()->'approval_updates')=0);
select t.ok('reading does not remove the notification record', t.count($$select * from notification where type='community.application_approved' and read_at is not null$$)=1);
\ir report.sql
rollback;
