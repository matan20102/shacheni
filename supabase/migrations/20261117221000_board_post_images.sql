-- Images in board posts (up to 4 per post), kept in a PRIVATE storage bucket.
--   board-images/{building_id}/{user_id}/{uuid}.jpg|png|webp
--   upload: the user in the path, while a resident of the building in the path
--   read:   residents of that building (the app shows them through signed URLs)
--   delete: the uploader
-- ba_publish keeps its signature for installed clients; new clients call ba_publish_v2.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('board-images', 'board-images', false, 2097152, array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do update
  set public = excluded.public,
      file_size_limit = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

alter table public.board_post add column images text[] not null default '{}'
  check (cardinality(images) <= 4);

-- Building and uploader of a well-formed image path; null for anything else.
create function app.board_image_building(object_name text) returns uuid
language sql immutable set search_path = '' as $$
  select case when object_name ~ ('^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/'
      || '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/'
      || '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\.(jpg|png|webp)$')
    then split_part(object_name, '/', 1)::uuid end
$$;
create function app.board_image_uploader(object_name text) returns uuid
language sql immutable set search_path = '' as $$
  select case when app.board_image_building(object_name) is not null
    then split_part(object_name, '/', 2)::uuid end
$$;
grant execute on function app.board_image_building(text), app.board_image_uploader(text) to authenticated;

create policy board_images_insert on storage.objects for insert to authenticated
  with check (bucket_id = 'board-images' and app.board_image_uploader(name) = (select auth.uid())
    and app.ba_resident(app.board_image_building(name)));

create policy board_images_select on storage.objects for select to authenticated
  using (bucket_id = 'board-images' and app.ba_resident(app.board_image_building(name)));

create policy board_images_delete on storage.objects for delete to authenticated
  using (bucket_id = 'board-images' and app.board_image_uploader(name) = (select auth.uid()));

create or replace function app.ba_post_json(p public.board_post, u uuid) returns jsonb
language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'id', p.id, 'building_id', p.building_id, 'author', coalesce(nullif(pr.full_name, ''), 'שכן'),
    'mine', p.author_id = u, 'apartment', p.apartment, 'text', p.body, 'kind', p.kind,
    'created_at', p.created_at, 'pinned', p.pinned, 'closed', p.closed, 'edited', p.edited_at is not null, 'images', to_jsonb(p.images),
    'replies', coalesce((select jsonb_agg(jsonb_build_object('id', r.id,
        'author', coalesce(nullif(rp.full_name, ''), 'שכן'), 'text', r.body, 'mine', r.author_id = u,
        'edited', r.edited_at is not null, 'created_at', r.created_at) order by r.created_at, r.id)
      from public.board_reply r join public.profile rp on rp.id = r.author_id
      where r.post_id = p.id and r.deleted_at is null
        and not exists(select 1 from public.board_report x where x.reply_id = r.id and x.reporter_id = u)), '[]'),
    'reactions', coalesce((select jsonb_object_agg(x.emoji, x.n)
      from (select emoji, count(*) n from public.board_reaction where post_id = p.id group by emoji) x), '{}'),
    'my_reactions', coalesce((select jsonb_agg(emoji) from public.board_reaction where post_id = p.id and user_id = u), '[]'))
  from public.profile pr where pr.id = p.author_id
$$;

-- Publishes a post with images the caller already uploaded to this building.
create function app.ba_publish_v2(p_building uuid, p_body text, p_kind text, p_images text[]) returns uuid
language plpgsql volatile security definer set search_path = '' as $$
declare u uuid := app.require_user(); p uuid; imgs text[] := coalesce(p_images, '{}');
begin
  if cardinality(imgs) > 4 or cardinality(imgs) <> (select count(distinct x) from unnest(imgs) x)
    or exists(select 1 from unnest(imgs) x where app.board_image_building(x) is distinct from p_building
      or app.board_image_uploader(x) is distinct from u
      or not exists(select 1 from storage.objects o where o.bucket_id = 'board-images' and o.name = x))
  then raise exception 'INVALID_ARGUMENT'; end if;
  p := app.ba_publish(p_building, p_body, p_kind);
  if cardinality(imgs) > 0 then update public.board_post set images = imgs where id = p; end if;
  return p;
end $$;

create function public.ba_publish_v2(p_building uuid, p_body text, p_kind text, p_images text[] default '{}') returns uuid
language sql volatile security invoker set search_path = '' as $$ select app.ba_publish_v2(p_building, p_body, p_kind, p_images) $$;

revoke all on function app.ba_publish_v2(uuid, text, text, text[]), public.ba_publish_v2(uuid, text, text, text[])
  from public, anon, authenticated;
grant execute on function app.ba_publish_v2(uuid, text, text, text[]), public.ba_publish_v2(uuid, text, text, text[])
  to authenticated;
