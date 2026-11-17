begin;
\ir kit.sql
insert into auth.users(id,email,raw_user_meta_data)
select ('d1000000-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid,'upgrade-'||i||'@example.test',('{"full_name":"Tester '||i||'"}')::jsonb from generate_series(1,7)i;
insert into auth.identities(user_id) select id from auth.users where email like 'upgrade-%';
insert into auth.sessions(user_id) select id from auth.users where email like 'upgrade-%';
create table t.v(k text primary key,v text); grant all on t.v to public;
create function t.get(k text) returns text language sql as $$select v from t.v where t.v.k=$1$$;
create function t.put(k text,v text) returns void language sql as $$insert into t.v values($1,$2) on conflict(k) do update set v=excluded.v$$;
create function t.u(i int) returns uuid language sql as $$select ('d1000000-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid$$;
create function t.login(i int) returns void language plpgsql as $$begin
  perform t.as_user(t.u(i));
  perform accept_legal_documents(array['terms_of_service','privacy_policy']::legal_doc_type[],'he');
end$$;
grant execute on function t.get(text),t.put(text,text),t.u(int),t.login(int) to public;

-- Anonymous callers reach none of the new endpoints.
select t.as_anon();
select t.throws('anon cannot reject',$$select ba_reject(gen_random_uuid())$$,'42501');
select t.throws('anon cannot remove',$$select ba_remove_member(gen_random_uuid())$$,'42501');
select t.throws('anon cannot page the board',$$select ba_board_page(gen_random_uuid())$$,'42501');
select t.throws('anon cannot report',$$select ba_report(gen_random_uuid())$$,'42501');
select t.throws('anon cannot read reports',$$select ba_reports(gen_random_uuid())$$,'42501');
select t.throws('anon cannot edit replies',$$select ba_reply_action(gen_random_uuid(),'delete')$$,'42501');
select t.throws('anon cannot read parking history',$$select ba_parking_history(gen_random_uuid())$$,'42501');
select t.throws('anon cannot rotate codes',$$select ba_rotate_code(gen_random_uuid())$$,'42501');
select t.throws('anon cannot delete accounts',$$select ba_delete_account()$$,'42501');
select t.throws('anon cannot read the signal',$$select * from community_signal$$,'42501');

-- Building with manager 1 (apt 1), resident 2 (apt 2), housemate 3 (apt 2).
select t.login(1);
select t.put('b',ba_create_home_v2('Upgrade test',null,'1')::text);
select t.put('code',ba_state()->'homes'->0->>'code');
select t.login(2); select t.put('m2',ba_apply_home(t.get('code'),'2')::text);
select t.login(3); select t.put('m3',ba_apply_home(t.get('code'),'2')::text);
select t.login(4); select t.put('m4',ba_apply_home(t.get('code'),'4')::text);

-- Rejecting a request.
select t.throws('applicant cannot reject',$$select ba_reject(t.get('m2')::uuid)$$,'ACCESS_DENIED');
select t.login(2);
select t.throws('another applicant cannot reject',$$select ba_reject(t.get('m4')::uuid)$$,'ACCESS_DENIED');
select t.login(1);
select ba_approve(t.get('m2')::uuid,'building');
select t.throws('approved member cannot be rejected',$$select ba_reject(t.get('m2')::uuid)$$,'INVALID_STATE');
select t.lives('manager rejects a request',$$select ba_reject(t.get('m4')::uuid)$$);
select t.throws('second rejection is refused',$$select ba_reject(t.get('m4')::uuid)$$,'INVALID_STATE');
select t.ok('rejected request leaves the inbox',not exists(select 1 from jsonb_array_elements(ba_state()->'applications') a where a->>'id'=t.get('m4')));
select t.login(4);
select t.ok('applicant no longer sees a pending request',jsonb_array_length(ba_state()->'applications')=0);
select t.ok('applicant is told about the decision',ba_state()->'notifications'->0->>'type'='community.application_rejected');
select t.ok('update names the building',ba_state()->'notifications'->0->>'building_name'='Upgrade test');
select t.throws('rejected applicant has no board access',$$select ba_board_page(t.get('b')::uuid)$$,'ACCESS_DENIED');
select t.put('n4',ba_state()->'notifications'->0->>'id');
select t.login(1);
select t.lives('another user cannot mark it read',$$select ba_read_notifications(array[t.get('n4')::uuid])$$);
select t.login(4);
select t.ok('update survives a foreign read',jsonb_array_length(ba_state()->'notifications')=1);
select ba_read_notifications(array[t.get('n4')::uuid]);
select t.ok('read update disappears',jsonb_array_length(ba_state()->'notifications')=0);
select t.throws('rejected applicant waits a day',$$select ba_apply_home(t.get('code'),'4')$$,'TRY_LATER');
select t.as_admin();
update community_member set updated_at=now()-interval '25 hours' where id=t.get('m4')::uuid;
select t.login(4);
select t.lives('rejected applicant may apply again after a day',$$select t.put('m4',ba_apply_home(t.get('code'),'4')::text)$$);
-- The apartment manager may decline a housemate.
select t.login(2);
select t.lives('apartment manager rejects a housemate request',$$select ba_reject(t.get('m3')::uuid)$$);
select t.as_admin();
update community_member set updated_at=now()-interval '25 hours' where id=t.get('m3')::uuid;
select t.login(3); select t.put('m3',ba_apply_home(t.get('code'),'2')::text);
select t.login(1); select ba_approve(t.get('m3')::uuid,'building'); select ba_approve(t.get('m4')::uuid,'building');
select t.login(2); select ba_approve(t.get('m3')::uuid,'apartment');

-- Board: replies, paging, search.
select t.login(1);
select t.put('p1',ba_publish(t.get('b')::uuid,'First notice about the roof','notice')::text);
select ba_post_action(t.get('p1')::uuid,'pin');
select t.put('p2',ba_publish(t.get('b')::uuid,'Second post 100% done_now','request')::text);
select t.login(2);
select ba_post_action(t.get('p1')::uuid,'reply','Thanks for the update');
select ba_post_action(t.get('p1')::uuid,'reply','One more thing');
select t.put('r1',(select r->>'id' from jsonb_array_elements(ba_board_page(t.get('b')::uuid)->'posts') p, jsonb_array_elements(p->'replies') r where r->>'text'='Thanks for the update'));
select t.ok('replies carry ids',t.get('r1') is not null);
select t.put('p3',ba_publish(t.get('b')::uuid,'Third post from apartment two','notice')::text);
select t.as_admin();
update board_post set created_at=now()-interval '3 hours' where id=t.get('p1')::uuid;
update board_post set created_at=now()-interval '2 hours' where id=t.get('p2')::uuid;
update board_post set created_at=now()-interval '1 hour' where id=t.get('p3')::uuid;
select t.login(2);
select t.ok('first page returns newest first',ba_board_page(t.get('b')::uuid,null,null,2)->'posts'->0->>'id'=t.get('p3'));
select t.ok('first page also carries pinned posts',jsonb_array_length(ba_board_page(t.get('b')::uuid,null,null,2)->'posts')=3);
select t.ok('first page reports more',(ba_board_page(t.get('b')::uuid,null,null,2)->>'has_more')::boolean);
select t.ok('next page returns the older post once',ba_board_page(t.get('b')::uuid,now()-interval '2 hours',null,2)->'posts'->0->>'id'=t.get('p1')
  and jsonb_array_length(ba_board_page(t.get('b')::uuid,now()-interval '2 hours',null,2)->'posts')=1);
select t.ok('last page reports no more',not (ba_board_page(t.get('b')::uuid,now()-interval '2 hours',null,2)->>'has_more')::boolean);
select t.ok('search matches post text',jsonb_array_length(ba_board_page(t.get('b')::uuid,null,'roof')->'posts')=1);
select t.ok('search matches reply text',ba_board_page(t.get('b')::uuid,null,'more thing')->'posts'->0->>'id'=t.get('p1'));
select t.ok('search treats wildcards literally',jsonb_array_length(ba_board_page(t.get('b')::uuid,null,'100%')->'posts')=1
  and jsonb_array_length(ba_board_page(t.get('b')::uuid,null,'%')->'posts')=1
  and jsonb_array_length(ba_board_page(t.get('b')::uuid,null,'done_now')->'posts')=1
  and jsonb_array_length(ba_board_page(t.get('b')::uuid,null,'doneXnow')->'posts')=0);
select t.throws('page size is bounded',$$select ba_board_page(t.get('b')::uuid,null,null,51)$$,'INVALID_ARGUMENT');
select t.throws('long search rejected',$$select ba_board_page(t.get('b')::uuid,null,repeat('x',61))$$,'INVALID_ARGUMENT');
select t.ok('legacy board endpoint still answers',jsonb_array_length(ba_board(t.get('b')::uuid))=3);

-- Reply edit and delete.
select t.lives('author edits a reply',$$select ba_reply_action(t.get('r1')::uuid,'edit',' Thanks a lot ')$$);
select t.ok('edited reply is trimmed and marked',exists(select 1 from jsonb_array_elements(ba_board(t.get('b')::uuid)) p,
  jsonb_array_elements(p->'replies') r where r->>'id'=t.get('r1') and r->>'text'='Thanks a lot' and (r->>'edited')::boolean));
select t.throws('empty reply rejected',$$select ba_reply_action(t.get('r1')::uuid,'edit','  ')$$,'INVALID_ARGUMENT');
select t.throws('unknown reply action rejected',$$select ba_reply_action(t.get('r1')::uuid,'pin')$$,'INVALID_ARGUMENT');
select t.login(3);
select t.throws('another resident cannot edit',$$select ba_reply_action(t.get('r1')::uuid,'edit','x')$$,'ACCESS_DENIED');
select t.throws('another resident cannot delete',$$select ba_reply_action(t.get('r1')::uuid,'delete')$$,'ACCESS_DENIED');
select t.login(1);
select t.throws('manager cannot edit someone else''s reply',$$select ba_reply_action(t.get('r1')::uuid,'edit','x')$$,'ACCESS_DENIED');
select t.ok('post author has one reply update',(select count(*) from jsonb_array_elements(ba_state()->'notifications') n where n->>'type'='board.reply')=1);
select t.ok('reply update quotes the post',(select n->>'text' from jsonb_array_elements(ba_state()->'notifications') n where n->>'type'='board.reply')='First notice about the roof');
select t.lives('manager deletes a reply',$$select ba_reply_action(t.get('r1')::uuid,'delete')$$);
select t.throws('deleted reply cannot be edited',$$select ba_reply_action(t.get('r1')::uuid,'delete')$$,'ACCESS_DENIED');
select t.ok('deleted reply leaves the board',not exists(select 1 from jsonb_array_elements(ba_board(t.get('b')::uuid)) p,
  jsonb_array_elements(p->'replies') r where r->>'id'=t.get('r1')));

-- Reports.
select t.throws('author cannot report own post',$$select ba_report(t.get('p1')::uuid)$$,'INVALID_ARGUMENT');
select t.login(3);
select t.throws('resident cannot read reports',$$select ba_reports(t.get('b')::uuid)$$,'ACCESS_DENIED');
select t.throws('long reason rejected',$$select ba_report(t.get('p2')::uuid,null,repeat('x',301))$$,'INVALID_ARGUMENT');
select t.put('rep',ba_report(t.get('p2')::uuid,null,' Not relevant ')::text);
select t.ok('repeated report returns the same row',ba_report(t.get('p2')::uuid,null,'again')::text=t.get('rep'));
select t.ok('reported post is hidden from the reporter',not exists(select 1 from jsonb_array_elements(ba_board_page(t.get('b')::uuid)->'posts') p where p->>'id'=t.get('p2')));
select t.throws('direct report reads denied',$$select * from board_report$$,'42501');
select t.login(2);
select t.ok('other residents still see the post',exists(select 1 from jsonb_array_elements(ba_board_page(t.get('b')::uuid)->'posts') p where p->>'id'=t.get('p2')));
select ba_report(t.get('p2')::uuid);
select t.throws('resident cannot resolve',$$select ba_report_resolve(t.get('p2')::uuid,null,true)$$,'ACCESS_DENIED');
select t.login(1);
select t.ok('manager sees one target with two reports',jsonb_array_length(ba_reports(t.get('b')::uuid))=1 and (ba_reports(t.get('b')::uuid)->0->>'count')::int=2);
select t.ok('reasons are listed without blanks',ba_reports(t.get('b')::uuid)->0->'reasons'='["Not relevant"]'::jsonb);
select t.ok('manager home counts open reports',(ba_state()->'homes'->0->>'open_reports')::int=2);
select t.ok('manager is told once per target',(select count(*) from jsonb_array_elements(ba_state()->'notifications') n where n->>'type'='board.report')=1);
select t.lives('manager dismisses the reports',$$select ba_report_resolve(t.get('p2')::uuid,null,false)$$);
select t.throws('nothing left to resolve',$$select ba_report_resolve(t.get('p2')::uuid,null,false)$$,'INVALID_STATE');
select t.ok('dismissed post stays on the board',exists(select 1 from jsonb_array_elements(ba_board(t.get('b')::uuid)) p where p->>'id'=t.get('p2')));
select t.login(3);
select t.ok('dismissed post stays hidden for the reporter',not exists(select 1 from jsonb_array_elements(ba_board(t.get('b')::uuid)) p where p->>'id'=t.get('p2')));
-- Reporting a reply and removing it.
select t.login(2);
select t.put('r2',(select r->>'id' from jsonb_array_elements(ba_board(t.get('b')::uuid)) p, jsonb_array_elements(p->'replies') r limit 1));
select t.throws('author cannot report own reply',$$select ba_report(t.get('p1')::uuid,t.get('r2')::uuid)$$,'INVALID_ARGUMENT');
select t.login(3);
select t.throws('reply must belong to the post',$$select ba_report(t.get('p3')::uuid,t.get('r2')::uuid)$$,'ACCESS_DENIED');
select ba_report(t.get('p1')::uuid,t.get('r2')::uuid,'rude');
select t.ok('reported reply is hidden from the reporter',not exists(select 1 from jsonb_array_elements(ba_board(t.get('b')::uuid)) p, jsonb_array_elements(p->'replies') r where r->>'id'=t.get('r2')));
select t.login(1);
select t.ok('reply report names the reply text',ba_reports(t.get('b')::uuid)->0->>'text'='One more thing' and ba_reports(t.get('b')::uuid)->0->>'reply_id'=t.get('r2'));
select t.lives('manager removes the reply',$$select ba_report_resolve(t.get('p1')::uuid,t.get('r2')::uuid,true)$$);
select t.ok('removed reply is gone for everyone',not exists(select 1 from jsonb_array_elements(ba_board(t.get('b')::uuid)) p, jsonb_array_elements(p->'replies') r where r->>'id'=t.get('r2')));
select t.ok('no open reports remain',jsonb_array_length(ba_reports(t.get('b')::uuid))=0);

-- Realtime signal.
select t.login(2);
select t.put('sig',(select version::text from community_signal where building_id=t.get('b')::uuid));
select t.ok('resident reads the building signal',t.get('sig') is not null);
select ba_post_action(t.get('p3')::uuid,'react',null,'💚');
select t.ok('a reaction advances the signal',(select version from community_signal where building_id=t.get('b')::uuid)>t.get('sig')::bigint);
select t.throws('signal cannot be written by clients',$$update community_signal set version=0$$,'42501');
select t.login(5);
select t.ok('outsider reads no signal rows',(select count(*) from community_signal)=0);

-- Join code rotation.
select t.login(2);
select t.throws('resident cannot rotate the code',$$select ba_rotate_code(t.get('b')::uuid)$$,'ACCESS_DENIED');
select t.login(1);
select t.put('code2',ba_rotate_code(t.get('b')::uuid));
select t.ok('rotation issues a different code',t.get('code2')<>t.get('code') and ba_state()->'homes'->0->>'code'=t.get('code2'));
select t.login(5);
select t.ok('old code stops resolving',ba_resolve(t.get('code')) is null);
select t.ok('new code resolves',ba_resolve(t.get('code2'))->>'id'=t.get('b'));

-- Parking: edit, series, updates, remove, history.
select t.login(2);
select t.put('space',ba_parking_add(t.get('b')::uuid,'P7','-1','By the door')::text);
select t.throws('tilde is reserved in labels',$$select ba_parking_add(t.get('b')::uuid,'P~8')$$,'INVALID_ARGUMENT');
select t.login(1);
select t.throws('another household cannot edit',$$select ba_parking_update(t.get('space')::uuid,'X1')$$,'ACCESS_DENIED');
select t.throws('another household cannot remove',$$select ba_parking_remove(t.get('space')::uuid)$$,'ACCESS_DENIED');
select t.put('space1',ba_parking_add(t.get('b')::uuid,'M1')::text);
select t.login(3);
select t.throws('label of another space is taken',$$select ba_parking_update(t.get('space')::uuid,'m1')$$,'PARKING_LABEL_TAKEN');
select t.lives('housemate edits the space',$$select ba_parking_update(t.get('space')::uuid,' P9 ','','')$$);
select t.ok('edit is visible to the household',ba_parking(t.get('b')::uuid)->'spaces'->0->>'label'='P9' and ba_parking(t.get('b')::uuid)->'spaces'->0->>'notes'='');
select t.throws('series needs matching arrays',$$select ba_parking_publish_series(t.get('space')::uuid,array[now()+interval '1 hour'],array[]::timestamptz[])$$,'INVALID_ARGUMENT');
select t.throws('series is bounded',$$select ba_parking_publish_series(t.get('space')::uuid,(select array_agg(now()+make_interval(days=>i)) from generate_series(1,32)i),(select array_agg(now()+make_interval(days=>i,hours=>1)) from generate_series(1,32)i))$$,'INVALID_ARGUMENT');
select t.throws('overlap inside a series fails it whole',$$select ba_parking_publish_series(t.get('space')::uuid,array[now()+interval '1 day',now()+interval '1 day 30 minutes'],array[now()+interval '1 day 1 hour',now()+interval '1 day 2 hours'])$$,'PARKING_OVERLAP');
select t.ok('failed series published nothing',jsonb_array_length(ba_parking(t.get('b')::uuid)->'offers')=0);
select t.ok('series reports its size',ba_parking_publish_series(t.get('space')::uuid,
  array[now()+interval '1 day',now()+interval '2 days',now()+interval '3 days'],
  array[now()+interval '1 day 2 hours',now()+interval '2 days 2 hours',now()+interval '3 days 2 hours'])=3);
select t.ok('series publishes every window',jsonb_array_length(ba_parking(t.get('b')::uuid)->'offers')=3);
select t.put('o1',ba_parking(t.get('b')::uuid)->'offers'->0->>'id');
select t.put('o2',ba_parking(t.get('b')::uuid)->'offers'->1->>'id');
select t.login(1);
select ba_parking_book(t.get('o1')::uuid);
select t.login(2);
select t.ok('owner household hears about the booking',(select n->>'text' from jsonb_array_elements(ba_state()->'notifications') n where n->>'type'='parking.booked')='P9');
select t.login(3);
select t.ok('housemate hears about it too',exists(select 1 from jsonb_array_elements(ba_state()->'notifications') n where n->>'type'='parking.booked' and n->>'entity_id'=t.get('o1')));
select t.throws('space with a booking cannot be removed',$$select ba_parking_remove(t.get('space')::uuid)$$,'PARKING_HAS_BOOKING');
select t.login(1);
select ba_parking_cancel(t.get('o1')::uuid);
select t.login(2);
select t.ok('owner hears about the cancelled booking',exists(select 1 from jsonb_array_elements(ba_state()->'notifications') n where n->>'type'='parking.booking_cancelled'));
select t.login(1);
select ba_parking_book(t.get('o2')::uuid);
select t.login(2);
select ba_parking_cancel(t.get('o2')::uuid);
select t.login(1);
select t.ok('booker hears when the owner cancels',(select n->>'text' from jsonb_array_elements(ba_state()->'notifications') n where n->>'type'='parking.offer_cancelled')='P9');
select t.ok('cancelled window shows in the booker''s history',ba_parking_history(t.get('b')::uuid)->0->>'id'=t.get('o2') and ba_parking_history(t.get('b')::uuid)->0->>'booking_status'='cancelled');
select t.login(4);
select t.ok('uninvolved resident has no history',jsonb_array_length(ba_parking_history(t.get('b')::uuid))=0);
select t.login(2);
select t.lives('household removes the space',$$select ba_parking_remove(t.get('space')::uuid)$$);
select t.ok('removed space leaves the list',jsonb_array_length(ba_parking(t.get('b')::uuid)->'spaces')=0);
select t.throws('removed space cannot publish',$$select ba_parking_publish(t.get('space')::uuid,now()+interval '9 days',now()+interval '10 days')$$,'ACCESS_DENIED');
select t.throws('removed space cannot be edited',$$select ba_parking_update(t.get('space')::uuid,'P9')$$,'ACCESS_DENIED');
select t.ok('history keeps the original label',(select count(*) from jsonb_array_elements(ba_parking_history(t.get('b')::uuid)) h where h->>'label'='P9')=3);
select t.login(4);
select t.ok('open windows of a removed space are withdrawn',jsonb_array_length(ba_parking(t.get('b')::uuid)->'offers')=0);
select t.lives('the label is free again',$$select ba_parking_add(t.get('b')::uuid,'P9')$$);

-- Removing a resident.
select t.login(1);
select ba_parking_publish(t.get('space1')::uuid,now()+interval '5 days',now()+interval '5 days 1 hour');
select t.put('o3',(select o->>'id' from jsonb_array_elements(ba_parking(t.get('b')::uuid)->'offers') o where (o->>'own_space')::boolean limit 1));
select t.login(2); select ba_parking_book(t.get('o3')::uuid);
select t.throws('resident cannot remove',$$select ba_remove_member(t.get('m3')::uuid)$$,'ACCESS_DENIED');
select t.login(1);
select t.put('m1',(select r->>'id' from jsonb_array_elements(ba_residents(t.get('b')::uuid)) r where (r->>'mine')::boolean));
select t.throws('manager cannot remove self',$$select ba_remove_member(t.get('m1')::uuid)$$,'INVALID_ARGUMENT');
select ba_set_admin(t.get('m4')::uuid,true);
select t.throws('a manager is not removed directly',$$select ba_remove_member(t.get('m4')::uuid)$$,'MEMBER_IS_ADMIN');
select ba_set_admin(t.get('m4')::uuid,false);
select t.lives('manager removes the apartment manager',$$select ba_remove_member(t.get('m2')::uuid)$$);
select t.throws('removal is not repeated',$$select ba_remove_member(t.get('m2')::uuid)$$,'INVALID_STATE');
select t.ok('housemate inherits the apartment',exists(select 1 from jsonb_array_elements(ba_residents(t.get('b')::uuid)) r where r->>'id'=t.get('m3') and (r->>'is_apartment_admin')::boolean));
select t.ok('their booking is released',(select o->>'status' from jsonb_array_elements(ba_parking(t.get('b')::uuid)->'offers') o where o->>'id'=t.get('o3'))='available');
select t.login(2);
select t.ok('removed resident loses the building',jsonb_array_length(ba_state()->'homes')=0);
select t.ok('removed resident is told',ba_state()->'notifications'->0->>'type'='community.member_removed');
select t.ok('older building updates no longer show',jsonb_array_length(ba_state()->'notifications')=1);
select t.throws('removed resident has no board access',$$select ba_board(t.get('b')::uuid)$$,'ACCESS_DENIED');
select t.throws('removed resident waits a day to ask again',$$select ba_apply_home(t.get('code2'),'2')$$,'TRY_LATER');

-- Account deletion.
select t.login(1);
select t.throws('last manager with neighbours cannot delete',$$select ba_delete_account()$$,'LAST_BUILDING_ADMIN');
select t.ok('refused deletion changed nothing',(select full_name from profile where id=t.u(1))='Tester 1' and jsonb_array_length(ba_state()->'homes')=1);
select t.login(3);
select ba_post_action(t.get('p3')::uuid,'reply','Reply before leaving');
select ba_post_action(t.get('p3')::uuid,'react',null,'🙌');
select t.put('p4',ba_publish(t.get('b')::uuid,'Post before leaving','notice')::text);
select t.login(6); select t.put('m6',ba_apply_home(t.get('code2'),'2')::text);
select t.login(3);
select t.lives('resident deletes the account',$$select ba_delete_account()$$);
select t.as_admin();
select t.ok('profile is emptied',(select full_name='' and phone_e164 is null and deleted_at is not null from profile where id=t.u(3)));
select t.ok('sign-in identity is detached',not exists(select 1 from auth.identities where user_id=t.u(3)) and not exists(select 1 from auth.sessions where user_id=t.u(3))
  and (select email is null and raw_user_meta_data='{}'::jsonb and deleted_at is not null from auth.users where id=t.u(3)));
select t.ok('membership ended',(select status from community_member where id=t.get('m3')::uuid)='withdrawn');
select t.ok('posts and replies are removed',(select deleted_at is not null from board_post where id=t.get('p4')::uuid)
  and not exists(select 1 from board_reply where author_id=t.u(3) and deleted_at is null) and not exists(select 1 from board_reaction where user_id=t.u(3)));
select t.ok('other accounts are untouched',exists(select 1 from auth.identities where user_id=t.u(1)) and (select full_name from profile where id=t.u(1))='Tester 1');
select t.ok('pending housemate returns to the manager',(select not requires_apartment_approval from community_member where id=t.get('m6')::uuid));
select t.login(1);
select t.ok('board no longer shows the deleted author',not exists(select 1 from jsonb_array_elements(ba_board(t.get('b')::uuid)) p where p->>'id'=t.get('p4')));
select t.ok('directory no longer lists them',not exists(select 1 from jsonb_array_elements(ba_residents(t.get('b')::uuid)) r where r->>'id'=t.get('m3')));
-- A sole resident takes the building along; a pending applicant is simply withdrawn.
select t.login(7);
select t.put('b7',ba_create_home_v2('Solo building',null,'1')::text);
select t.put('m7',ba_apply_home(t.get('code2'),'9')::text);
select t.lives('sole resident deletes the account',$$select ba_delete_account()$$);
select t.as_admin();
select t.ok('their building is archived',(select status from building where id=t.get('b7')::uuid)='suspended');
select t.ok('their pending request is withdrawn',(select status from community_member where id=t.get('m7')::uuid)='withdrawn');
\ir report.sql
rollback;
