begin;
\ir kit.sql
insert into auth.users(id,email,raw_user_meta_data) values
('c2000000-0000-4000-8000-000000000001','reply-owner@example.test','{"full_name":"Shared name"}'),
('c2000000-0000-4000-8000-000000000002','reply-neighbor@example.test','{"full_name":"Shared name"}'),
('c2000000-0000-4000-8000-000000000003','reply-outsider@example.test','{"full_name":"Outsider"}');
create table t.v(k text primary key,v text); grant all on t.v to public;
create function t.get(k text) returns text language sql as $$select v from t.v where t.v.k=$1$$;
create function t.put(k text,v text) returns void language sql as $$insert into t.v values($1,$2) on conflict(k) do update set v=excluded.v$$;
grant execute on function t.get(text),t.put(text,text) to public;
select t.as_anon();
select t.throws('anonymous board RPC remains blocked',$$select ba_board(gen_random_uuid())$$,'42501');
select t.as_user('c2000000-0000-4000-8000-000000000001');
select accept_legal_documents(array['terms_of_service','privacy_policy']::legal_doc_type[],'he');
select t.put('b',ba_create_home_v2('Reply ownership test',null,'12')::text);
select t.put('code',ba_state()->'homes'->0->>'code');
select t.put('p',ba_publish(t.get('b')::uuid,'Post for reply ownership','notice')::text);
select ba_post_action(t.get('p')::uuid,'reply','Creator reply');
select t.ok('own reply is marked by viewer identity',ba_board(t.get('b')::uuid)->0->'replies' @> '[{"text":"Creator reply","mine":true}]');
select t.ok('reply ownership is a boolean',jsonb_typeof(ba_board(t.get('b')::uuid)->0->'replies'->0->'mine')='boolean');
select t.as_user('c2000000-0000-4000-8000-000000000002');
select accept_legal_documents(array['terms_of_service','privacy_policy']::legal_doc_type[],'he');
select t.put('member',ba_apply_home(t.get('code'),'2')::text);
select t.throws('pending resident cannot read reply identity',$$select ba_board(t.get('b')::uuid)$$,'ACCESS_DENIED');
select t.as_user('c2000000-0000-4000-8000-000000000001'); select ba_approve(t.get('member')::uuid,'building');
select t.as_user('c2000000-0000-4000-8000-000000000002');
select ba_post_action(t.get('p')::uuid,'reply','Neighbor reply');
select t.ok('same display name does not make another reply mine',ba_board(t.get('b')::uuid)->0->'replies' @> '[{"text":"Creator reply","mine":false}]');
select t.ok('neighbor sees their own reply as mine',ba_board(t.get('b')::uuid)->0->'replies' @> '[{"text":"Neighbor reply","mine":true}]');
select t.as_user('c2000000-0000-4000-8000-000000000001');
select t.ok('creator sees opposite ownership for same two replies',ba_board(t.get('b')::uuid)->0->'replies' @> '[{"text":"Creator reply","mine":true},{"text":"Neighbor reply","mine":false}]');
select t.ok('existing reply author and text remain present',ba_board(t.get('b')::uuid)->0->'replies' @> '[{"author":"Shared name","text":"Neighbor reply"}]');
select t.ok('author UUID is not exposed',not (ba_board(t.get('b')::uuid)->0->'replies'->0 ? 'author_id'));
select t.as_admin();
update profile set full_name='אני' where id='c2000000-0000-4000-8000-000000000002';
select t.as_user('c2000000-0000-4000-8000-000000000001');
select t.ok('a user named me is still another author',ba_board(t.get('b')::uuid)->0->'replies' @> '[{"author":"אני","text":"Neighbor reply","mine":false}]');
select t.as_user('c2000000-0000-4000-8000-000000000002');
select t.ok('renaming does not change own reply identity',ba_board(t.get('b')::uuid)->0->'replies' @> '[{"text":"Neighbor reply","mine":true}]');
select ba_leave(t.get('b')::uuid);
select t.throws('former resident cannot read replies',$$select ba_board(t.get('b')::uuid)$$,'ACCESS_DENIED');
select t.as_user('c2000000-0000-4000-8000-000000000003');
select accept_legal_documents(array['terms_of_service','privacy_policy']::legal_doc_type[],'he');
select t.throws('outsider cannot read replies',$$select ba_board(t.get('b')::uuid)$$,'ACCESS_DENIED');
select t.as_user('c2000000-0000-4000-8000-000000000001'); select ba_archive(t.get('b')::uuid);
select t.throws('archived building still blocks replies',$$select ba_board(t.get('b')::uuid)$$,'ACCESS_DENIED');
\ir report.sql
rollback;
