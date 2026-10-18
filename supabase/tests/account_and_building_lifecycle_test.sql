begin;
\ir kit.sql
insert into auth.users(id,email,raw_user_meta_data)
select ('be000000-0000-4000-8000-' || lpad(i::text,12,'0'))::uuid,
 'lifecycle-' || i || '@example.test', jsonb_build_object('full_name','Resident ' || i)
from generate_series(1,5) i;
create table t.v(k text primary key, v text);
grant all on t.v to public;
create function t.get(k text) returns text language sql as $$select v from t.v where t.v.k = $1$$;
create function t.put(k text, v text) returns void language sql as $$insert into t.v values($1,$2) on conflict(k) do update set v=excluded.v$$;
grant execute on function t.get(text), t.put(text,text) to public;

select t.as_anon();
select t.throws('anonymous profile edit denied', $$select ba_update_profile('Someone','')$$,'42501');
select t.throws('anonymous leave denied', $$select ba_leave(gen_random_uuid())$$,'42501');
select t.throws('anonymous archive denied', $$select ba_archive(gen_random_uuid())$$,'42501');
select t.as_user('be000000-0000-4000-8000-000000000005');
select t.throws('profile requires consent', $$select ba_update_profile('Someone','')$$,'LEGAL_NOT_ACCEPTED');
select t.throws('leave requires consent', $$select ba_leave(gen_random_uuid())$$,'LEGAL_NOT_ACCEPTED');
select t.throws('archive requires consent', $$select ba_archive(gen_random_uuid())$$,'LEGAL_NOT_ACCEPTED');

select t.as_user('be000000-0000-4000-8000-000000000001');
select accept_legal_documents(array['terms_of_service','privacy_policy']::legal_doc_type[],'he');
select ba_update_profile('  New Name  ','050-1234567');
select t.ok('profile name normalized',ba_state()->'profile'->>'full_name'='New Name');
select t.ok('phone normalized',ba_state()->'profile'->>'phone'='+972501234567');
select t.ok('only own email returned',ba_state()->'profile'->>'email'='lifecycle-1@example.test');
select t.throws('short name rejected', $$select ba_update_profile('x','')$$,'INVALID_ARGUMENT');
select t.throws('null name rejected', $$select ba_update_profile(null,'')$$,'INVALID_ARGUMENT');
select t.throws('bad phone rejected', $$select ba_update_profile('Good Name','123')$$,'PHONE_INVALID');
select t.ok('failed update preserves profile',ba_state()->'profile'->>'full_name'='New Name');
select t.put('b',ba_create_home_v2('Lifecycle test',null,'1')::text);
select t.put('code',ba_state()->'homes'->0->>'code');
select t.throws('last admin cannot leave', $$select ba_leave(t.get('b')::uuid)$$,'LAST_BUILDING_ADMIN');
select t.ok('failed leave retains access',jsonb_array_length(ba_state()->'homes')=1);

select t.as_user('be000000-0000-4000-8000-000000000002');
select accept_legal_documents(array['terms_of_service','privacy_policy']::legal_doc_type[],'he');
select t.throws('phone uniqueness enforced', $$select ba_update_profile('Other Name','0501234567')$$,'PHONE_TAKEN');
select t.ok('cannot read other profile through state',ba_state()->'profile'->>'full_name'='Resident 2');
select t.throws('nonmember archive denied', $$select ba_archive(t.get('b')::uuid)$$,'ACCESS_DENIED');
select t.throws('nonmember leave denied', $$select ba_leave(t.get('b')::uuid)$$,'ACCESS_DENIED');
select t.put('m2',ba_apply_home(t.get('code'),'2')::text);
select t.throws('pending member cannot leave through approved path', $$select ba_leave(t.get('b')::uuid)$$,'ACCESS_DENIED');
select t.as_user('be000000-0000-4000-8000-000000000001');
select ba_approve(t.get('m2')::uuid,'building');
select t.as_user('be000000-0000-4000-8000-000000000003');
select accept_legal_documents(array['terms_of_service','privacy_policy']::legal_doc_type[],'he');
select t.put('m3',ba_apply_home(t.get('code'),'2')::text);
select t.as_user('be000000-0000-4000-8000-000000000001');
select ba_approve(t.get('m3')::uuid,'building');
select t.as_user('be000000-0000-4000-8000-000000000002');
select ba_approve(t.get('m3')::uuid,'apartment');
select ba_leave(t.get('b')::uuid);
select t.ok('leaving removes home immediately',jsonb_array_length(ba_state()->'homes')=0);
select t.ok('leaving removes stale approval update',jsonb_array_length(ba_state()->'approval_updates')=0);
select t.throws('former resident cannot read board', $$select ba_board(t.get('b')::uuid)$$,'ACCESS_DENIED');
select t.throws('repeated leave is rejected', $$select ba_leave(t.get('b')::uuid)$$,'ACCESS_DENIED');
select t.as_user('be000000-0000-4000-8000-000000000003');
select t.ok('next resident becomes apartment admin',(ba_state()->'homes'->0->>'is_apartment_admin')::boolean);
select t.throws('apartment admin cannot archive building', $$select ba_archive(t.get('b')::uuid)$$,'ACCESS_DENIED');

select t.as_user('be000000-0000-4000-8000-000000000004');
select accept_legal_documents(array['terms_of_service','privacy_policy']::legal_doc_type[],'he');
select t.put('m4',ba_apply_home(t.get('code'),'2')::text);
select t.as_user('be000000-0000-4000-8000-000000000001');
select ba_approve(t.get('m4')::uuid,'building');
select t.as_user('be000000-0000-4000-8000-000000000003');
select ba_leave(t.get('b')::uuid);
select t.as_user('be000000-0000-4000-8000-000000000004');
select t.ok('empty household no longer needs missing apartment approver',not (ba_state()->'applications'->0->>'apartment_has_admin')::boolean);
select t.ok('manager must review pending applicant again',not (ba_state()->'applications'->0->>'building_approved')::boolean);
select t.as_user('be000000-0000-4000-8000-000000000001');
select ba_approve(t.get('m4')::uuid,'building');
select ba_update_profile('New Name','');
select t.ok('optional phone can be cleared',ba_state()->'profile'->>'phone'='');

-- A second building administrator is a fixture setup, not a client promotion API.
select t.as_admin();
update public.community_member set is_building_admin=true where id=t.get('m4')::uuid;
select t.as_user('be000000-0000-4000-8000-000000000001');
select ba_leave(t.get('b')::uuid);
select t.ok('admin may leave when replacement exists',jsonb_array_length(ba_state()->'homes')=0);
select t.as_user('be000000-0000-4000-8000-000000000005');
select accept_legal_documents(array['terms_of_service','privacy_policy']::legal_doc_type[],'he');
select t.put('m5',ba_apply_home(t.get('code'),'5')::text);
select t.as_user('be000000-0000-4000-8000-000000000004');
select ba_publish(t.get('b')::uuid,'Preserve this history','notice');
select t.throws('replacement is now last admin', $$select ba_leave(t.get('b')::uuid)$$,'LAST_BUILDING_ADMIN');
select ba_archive(t.get('b')::uuid);
select t.ok('archive removes active home',jsonb_array_length(ba_state()->'homes')=0);
select t.ok('archive removes pending inbox',jsonb_array_length(ba_state()->'applications')=0);
select t.throws('archive blocks board', $$select ba_board(t.get('b')::uuid)$$,'ACCESS_DENIED');
select t.throws('archive blocks posting', $$select ba_publish(t.get('b')::uuid,'Denied','notice')$$,'ACCESS_DENIED');
select t.throws('archive blocks approval', $$select ba_approve(t.get('m5')::uuid,'building')$$,'ACCESS_DENIED');
select t.ok('archived join code does not resolve',ba_resolve(t.get('code')) is null);
select t.ok('archived code cannot submit request',ba_apply_home(t.get('code'),'9') is null);
select t.throws('archived building cannot be archived again', $$select ba_archive(t.get('b')::uuid)$$,'ACCESS_DENIED');
select ba_leave(t.get('b')::uuid);
select t.as_user('be000000-0000-4000-8000-000000000005');
select t.ok('archived pending request hidden from applicant',jsonb_array_length(ba_state()->'applications')=0);
select t.as_admin();
select t.ok('archive timestamp retained',(select archived_at is not null from community_settings where building_id=t.get('b')::uuid));
select t.ok('building retained and suspended',(select status='suspended' from building where id=t.get('b')::uuid));
select t.ok('post history retained',(select count(*)=1 from board_post where building_id=t.get('b')::uuid));
select t.ok('leaving revokes all roles',not exists(select 1 from community_member where building_id=t.get('b')::uuid and status='withdrawn' and (is_building_admin or is_apartment_admin or is_committee)));
select t.ok('archive action audited',(select count(*)=1 from audit_log where building_id=t.get('b')::uuid and action='community.archive'));
select t.ok('profile action audited without personal details',(select count(*)=2 from audit_log where actor_id='be000000-0000-4000-8000-000000000001' and action='community.profile_updated' and note is null));
\ir report.sql
rollback;
