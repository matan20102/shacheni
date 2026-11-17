begin;
\ir kit.sql
insert into auth.users(id,email,raw_user_meta_data)
select ('d2000000-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid,'images-'||i||'@example.test',('{"full_name":"Images '||i||'"}')::jsonb from generate_series(1,3)i;
insert into auth.identities(user_id) select id from auth.users where email like 'images-%';
insert into auth.sessions(user_id) select id from auth.users where email like 'images-%';
create table t.img(k text primary key,v text); grant all on t.img to public;
create function t.iget(k text) returns text language sql as $$select v from t.img where t.img.k=$1$$;
create function t.iput(k text,v text) returns void language sql as $$insert into t.img values($1,$2) on conflict(k) do update set v=excluded.v$$;
create function t.iu(i int) returns uuid language sql as $$select ('d2000000-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid$$;
create function t.ilogin(i int) returns void language plpgsql as $$begin
  perform t.as_user(t.iu(i));
  perform accept_legal_documents(array['terms_of_service','privacy_policy']::legal_doc_type[],'he');
end$$;
-- Image path of user i in the building, with a fixed file id n.
create function t.ipath(i int,n int,ext text default 'jpg') returns text language sql as $$
  select t.iget('b')||'/'||t.iu(i)||'/e2000000-0000-4000-8000-'||lpad(n::text,12,'0')||'.'||ext$$;
create function t.upload(name text) returns void language sql as $$
  insert into storage.objects(bucket_id,name,owner_id,metadata) values('board-images',name,auth.uid()::text,'{}')$$;
grant execute on function t.iget(text),t.iput(text,text),t.iu(int),t.ilogin(int),t.ipath(int,int,text),t.upload(text) to public;

-- Manager 1 and resident 2 share a building; user 3 has a building of their own.
select t.ilogin(1);
select t.iput('b',ba_create_home_v2('Images test',null,'1')::text);
select t.iput('code',ba_state()->'homes'->0->>'code');
select t.ilogin(2); select t.iput('m2',ba_apply_home(t.iget('code'),'2')::text);
select t.ilogin(1); select ba_approve(t.iget('m2')::uuid,'building');
select t.ilogin(3); select ba_create_home_v2('Other images building',null,'1');

select t.as_anon();
select t.throws('anon cannot publish with images',$$select ba_publish_v2(gen_random_uuid(),'x','notice','{}')$$,'42501');

-- Uploads.
select t.ilogin(2);
select t.lives('resident uploads an image',$$select t.upload(t.ipath(2,1))$$);
select t.lives('png and webp are accepted',$$select t.upload(t.ipath(2,2,'png')); select t.upload(t.ipath(2,3,'webp'))$$);
select t.throws('cannot upload under another user',$$select t.upload(t.ipath(1,9))$$,'42501');
select t.throws('a malformed path is refused',$$select t.upload(t.iget('b')||'/'||t.iu(2)||'/photo.jpg')$$,'42501');
select t.throws('other file types are refused',$$select t.upload(t.ipath(2,4,'gif'))$$,'42501');
select t.ilogin(3);
select t.throws('an outsider cannot upload to the building',$$select t.upload(t.ipath(3,1))$$,'42501');
select t.ilogin(1);
select t.lives('manager uploads an image',$$select t.upload(t.ipath(1,1))$$);

-- Reading.
select t.ok('a neighbour sees the image',t.count($$select 1 from storage.objects where name=t.ipath(2,1)$$)=1);
select t.ilogin(3);
select t.ok('an outsider does not',t.count($$select 1 from storage.objects where bucket_id='board-images'$$)=0);

-- Publishing.
select t.ilogin(2);
select t.iput('p1',ba_publish_v2(t.iget('b')::uuid,'Lost keys, photo attached','notice',array[t.ipath(2,1),t.ipath(2,2,'png')])::text);
select t.ok('the post carries its images in order',
  (select p->'images' from jsonb_array_elements(ba_board(t.iget('b')::uuid)) p where p->>'id'=t.iget('p1'))
    =jsonb_build_array(t.ipath(2,1),t.ipath(2,2,'png')));
select t.ok('board pages carry images too',
  (select jsonb_array_length(p->'images') from jsonb_array_elements(ba_board_page(t.iget('b')::uuid)->'posts') p where p->>'id'=t.iget('p1'))=2);
select t.throws('an image that was not uploaded is refused',
  $$select ba_publish_v2(t.iget('b')::uuid,'x','notice',array[t.ipath(2,8)])$$,'INVALID_ARGUMENT');
select t.throws('another user''s image is refused',
  $$select ba_publish_v2(t.iget('b')::uuid,'x','notice',array[t.ipath(1,1)])$$,'INVALID_ARGUMENT');
select t.throws('the same image twice is refused',
  $$select ba_publish_v2(t.iget('b')::uuid,'x','notice',array[t.ipath(2,1),t.ipath(2,1)])$$,'INVALID_ARGUMENT');
select t.throws('more than four images are refused',
  $$select ba_publish_v2(t.iget('b')::uuid,'x','notice',array[t.ipath(2,1),t.ipath(2,2,'png'),t.ipath(2,3,'webp'),t.ipath(2,5),t.ipath(2,6)])$$,'INVALID_ARGUMENT');
select t.throws('text is still required',
  $$select ba_publish_v2(t.iget('b')::uuid,' ','notice',array[t.ipath(2,1)])$$,'INVALID_ARGUMENT');
select t.ilogin(3);
select t.throws('an outsider cannot publish',
  $$select ba_publish_v2(t.iget('b')::uuid,'x','notice','{}')$$,'ACCESS_DENIED');

-- Installed clients keep publishing without images.
select t.ilogin(2);
select t.iput('p2',ba_publish(t.iget('b')::uuid,'Plain notice','notice')::text);
select t.ok('older publish has no images',
  (select p->'images' from jsonb_array_elements(ba_board(t.iget('b')::uuid)) p where p->>'id'=t.iget('p2'))='[]'::jsonb);
select t.iput('p3',ba_publish_v2(t.iget('b')::uuid,'No photos','request')::text);
select t.ok('images are optional',
  (select p->'images' from jsonb_array_elements(ba_board(t.iget('b')::uuid)) p where p->>'id'=t.iget('p3'))='[]'::jsonb);

-- Deleting uploads.
select t.ilogin(1);
delete from storage.objects where name=t.ipath(2,3,'webp');
select t.ok('a neighbour cannot delete the upload',t.count($$select 1 from storage.objects where name=t.ipath(2,3,'webp')$$)=1);
select t.ilogin(2);
delete from storage.objects where name=t.ipath(2,3,'webp');
select t.ok('the uploader can',t.count($$select 1 from storage.objects where name=t.ipath(2,3,'webp')$$)=0);

\ir report.sql
rollback;
