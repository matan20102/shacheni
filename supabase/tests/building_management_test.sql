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
select t.throws('creation requires terms', $$select ba_create('Address')$$, 'LEGAL_NOT_ACCEPTED');
select t.as_anon();
select t.throws('anon cannot execute create', $$select ba_create('Address')$$, '42501');
select t.throws('anon cannot read the board', $$select * from board_post$$, '42501');

select t.as_user('ba000000-0000-4000-8000-000000000001');
select accept_legal_documents(array['terms_of_service','privacy_policy']::legal_doc_type[], 'he');
select t.throws('address is required', $$select ba_create(' ')$$, 'INVALID_ARGUMENT');
select t.put('b', ba_create('הגפן 18', ' ', '12א', 2)::text);
select t.put('code', (ba_state()->'homes'->0->>'code'));
select t.ok('address becomes display name when name absent', (ba_state()->'homes'->0->>'name') = 'הגפן 18');
select t.ok('creator has separate admin committee and apartment roles',
  (ba_state()->'homes'->0->>'is_admin')::bool and (ba_state()->'homes'->0->>'is_committee')::bool
  and (ba_state()->'homes'->0->>'is_apartment_admin')::bool);
select t.ok('no apartment roster needed', t.count($$select * from community_member$$) = 1);
select t.put('b2', ba_create('Other Address', 'Second home', '1')::text);
select t.ok('one user has two buildings', jsonb_array_length(ba_state()->'homes') = 2);
select t.put('post', ba_publish(t.get('b')::uuid, 'Hello neighbors', 'notice')::text);
select t.ok('board uses correct building', jsonb_array_length(ba_board(t.get('b')::uuid)) = 1
  and jsonb_array_length(ba_board(t.get('b2')::uuid)) = 0);
select t.throws('invalid post kind blocked', $$select ba_publish(t.get('b')::uuid, 'Text', null)$$, 'INVALID_ARGUMENT');
select t.throws('empty post blocked', $$select ba_publish(t.get('b')::uuid, ' ', 'notice')$$, 'INVALID_ARGUMENT');

select t.as_user('ba000000-0000-4000-8000-000000000002');
select accept_legal_documents(array['terms_of_service','privacy_policy']::legal_doc_type[], 'he');
select t.ok('wrong code returns no building', ba_resolve('INVALID!') is null);
select t.ok('code reveals only building card', ba_resolve(t.get('code'))->>'id' = t.get('b')
  and not (ba_resolve(t.get('code')) ? 'apartments'));
select t.put('first', ba_join(t.get('code'), '999', null, null)::text);
select t.ok('pending application exposes no home', jsonb_array_length(ba_state()->'homes') = 0);
select t.throws('pending user cannot read board RPC', $$select ba_board(t.get('b')::uuid)$$, 'ACCESS_DENIED');
select t.ok('pending user cannot read board table', t.count($$select * from board_post$$) = 0);
select t.throws('pending user cannot self approve', $$select ba_approve(t.get('first')::uuid, 'building')$$, 'ACCESS_DENIED');
select t.throws('pending user cannot publish', $$select ba_publish(t.get('b')::uuid, 'No', 'notice')$$, 'ACCESS_DENIED');
select t.throws('duplicate application blocked', $$select ba_join(t.get('code'), '999')$$, 'ALREADY_APPLIED');

select t.as_user('ba000000-0000-4000-8000-000000000003');
select accept_legal_documents(array['terms_of_service','privacy_policy']::legal_doc_type[], 'he');
select t.put('second', ba_join(t.get('code'), '999')::text);
select t.as_user('ba000000-0000-4000-8000-000000000001');
select t.ok('building admin sees applications', jsonb_array_length(ba_state()->'applications') = 2);
select ba_approve(t.get('first')::uuid, 'building');
select ba_approve(t.get('second')::uuid, 'building');
select t.ok('first approved resident becomes apartment admin',
  (select status = 'approved' and is_apartment_admin from community_member where id=t.get('first')::uuid));
select t.ok('second request now requires apartment approval',
  (select status = 'pending' and requires_apartment_approval and building_approved from community_member where id=t.get('second')::uuid));
select t.throws('building role cannot approve as apartment admin of another apartment',
  $$select ba_approve(t.get('second')::uuid, 'apartment')$$, 'ACCESS_DENIED');

select t.as_user('ba000000-0000-4000-8000-000000000003');
select t.throws('one approval still gives no board access', $$select ba_board(t.get('b')::uuid)$$, 'ACCESS_DENIED');
select t.as_user('ba000000-0000-4000-8000-000000000002');
select t.ok('apartment admin sees only own apartment requests', jsonb_array_length(ba_state()->'applications') = 1);
select ba_approve(t.get('second')::uuid, 'apartment');
select t.throws('member cannot edit others posts', $$select ba_post_action(t.get('post')::uuid, 'edit', 'Changed')$$, 'ACCESS_DENIED');
select t.throws('member cannot pin posts', $$select ba_post_action(t.get('post')::uuid, 'pin')$$, 'ACCESS_DENIED');
select t.throws('member cannot close others posts', $$select ba_post_action(t.get('post')::uuid, 'close')$$, 'ACCESS_DENIED');
select ba_post_action(t.get('post')::uuid, 'reply', 'A reply');
select ba_post_action(t.get('post')::uuid, 'react', null, '💚');
select t.ok('reaction is scoped to acting user', (ba_board(t.get('b')::uuid)->0->'reactions'->>'💚')::int = 1);
select ba_post_action(t.get('post')::uuid, 'react', null, '💚');
select t.ok('reaction toggle removes own reaction', ba_board(t.get('b')::uuid)->0->'reactions' = '{}');
select t.throws('unsupported emoji blocked', $$select ba_post_action(t.get('post')::uuid, 'react', null, 'X')$$, 'INVALID_ARGUMENT');
select t.throws('direct client DML blocked', $$insert into board_post(building_id,author_id,apartment,kind,body)
  values(t.get('b')::uuid,auth.uid(),'999','notice','No')$$, '42501');

select t.as_user('ba000000-0000-4000-8000-000000000003');
select t.ok('both approvals grant access without roles',
  jsonb_array_length(ba_state()->'homes') = 1 and not (ba_state()->'homes'->0->>'is_apartment_admin')::bool);
select t.ok('shared reply visible', ba_board(t.get('b')::uuid)->0->'replies'->0->>'text' = 'A reply');
select t.throws('resident cannot read other building', $$select ba_board(t.get('b2')::uuid)$$, 'ACCESS_DENIED');

select t.as_user('ba000000-0000-4000-8000-000000000004');
select accept_legal_documents(array['terms_of_service','privacy_policy']::legal_doc_type[], 'he');
select t.ok('outside user sees no table posts', t.count($$select * from board_post$$) = 0);
select t.ok('outside user sees no table replies', t.count($$select * from board_reply$$) = 0);
select t.ok('outside user sees no members', t.count($$select * from community_member$$) = 0);
select t.throws('user metadata cannot grant admin powers', $$select ba_approve(t.get('second')::uuid, 'building')$$, 'ACCESS_DENIED');
select t.throws('outside user cannot mutate post', $$select ba_post_action(t.get('post')::uuid, 'react', null, '💚')$$, 'ACCESS_DENIED');
select t.put('fourth', ba_join(t.get('code'), '999')::text);
select t.as_user('ba000000-0000-4000-8000-000000000002');
select ba_approve(t.get('fourth')::uuid, 'apartment');
select t.as_user('ba000000-0000-4000-8000-000000000004');
select t.ok('apartment approval alone grants no home', jsonb_array_length(ba_state()->'homes') = 0);
select t.as_user('ba000000-0000-4000-8000-000000000001');
select ba_approve(t.get('fourth')::uuid, 'building');
select ba_post_action(t.get('post')::uuid, 'close');
select t.as_user('ba000000-0000-4000-8000-000000000004');
select t.ok('reverse approval order grants home', jsonb_array_length(ba_state()->'homes') = 1);
select t.throws('closed post rejects replies', $$select ba_post_action(t.get('post')::uuid, 'reply', 'No')$$, 'POST_CLOSED');
select t.as_user('ba000000-0000-4000-8000-000000000001');
select ba_post_action(t.get('post')::uuid, 'close');
select ba_post_action(t.get('post')::uuid, 'pin');
select ba_post_action(t.get('post')::uuid, 'edit', 'Updated');
select t.ok('author edit and admin pin work', ba_board(t.get('b')::uuid)->0->>'text' = 'Updated'
  and (ba_board(t.get('b')::uuid)->0->>'pinned')::bool);
select ba_post_action(t.get('post')::uuid, 'delete');
select t.ok('deleted posts vanish from feed', ba_board(t.get('b')::uuid) = '[]');
select t.as_user('ba000000-0000-4000-8000-000000000002');
select t.ok('deleted posts replies are hidden', t.count($$select * from board_reply$$) = 0);

select t.as_admin();
select t.ok('public endpoints use invoker security', not exists(select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname='public' and p.proname like 'ba\_%' escape '\' and p.prosecdef));
select t.ok('all new tables enable RLS', (select bool_and(relrowsecurity) from pg_class where oid in
  ('community_settings'::regclass,'community_member'::regclass,'board_post'::regclass,'board_reply'::regclass,'board_reaction'::regclass)));

\ir report.sql
rollback;
