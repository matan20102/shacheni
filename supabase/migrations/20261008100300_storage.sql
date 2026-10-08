-- Storage: two PRIVATE buckets with MIME/size limits and path-based policies (§12.5, BR-E10).
--   avatars/{user_id}.jpg|png                              read: owner + residents sharing a building; write: owner
--   delivery-proofs/{building_id}/{request_id}/{uuid}.jpg   insert: app.can_upload_proof; select: app.can_view_proof
-- No update/delete of proofs by any user (the retention job uses the service role).

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  ('avatars', 'avatars', false, 1048576, array['image/jpeg', 'image/png']),
  ('delivery-proofs', 'delivery-proofs', false, 3145728, array['image/jpeg'])
on conflict (id) do update
  set public = excluded.public,
      file_size_limit = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

-- Path parsers: return null for anything that does not match the expected layout exactly.
create function app.avatar_owner(object_name text)
returns uuid language sql immutable set search_path = ''
as $$
  select case
    when object_name ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\.(jpg|png)$'
    then left(object_name, 36)::uuid
  end
$$;

-- The request id of a well-formed proof path whose building segment matches the request's building.
create function app.proof_request(object_name text)
returns uuid language sql stable security definer set search_path = ''
as $$
  select dr.id
  from public.delivery_request dr
  where object_name ~ ('^[0-9a-f-]{36}/[0-9a-f-]{36}/'
                       || '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\.jpg$')
    and dr.id::text = split_part(object_name, '/', 2)
    and dr.building_id::text = split_part(object_name, '/', 1)
$$;

grant execute on function app.avatar_owner(text), app.proof_request(text) to authenticated;

create policy avatars_select on storage.objects for select to authenticated
  using (bucket_id = 'avatars' and app.shares_building_with(app.avatar_owner(name)));

create policy avatars_insert on storage.objects for insert to authenticated
  with check (bucket_id = 'avatars' and app.avatar_owner(name) = (select auth.uid()));

create policy avatars_update on storage.objects for update to authenticated
  using (bucket_id = 'avatars' and app.avatar_owner(name) = (select auth.uid()))
  with check (bucket_id = 'avatars' and app.avatar_owner(name) = (select auth.uid()));

create policy avatars_delete on storage.objects for delete to authenticated
  using (bucket_id = 'avatars' and app.avatar_owner(name) = (select auth.uid()));

create policy proofs_insert on storage.objects for insert to authenticated
  with check (bucket_id = 'delivery-proofs' and app.can_upload_proof(app.proof_request(name)));

create policy proofs_select on storage.objects for select to authenticated
  using (bucket_id = 'delivery-proofs' and app.can_view_proof(app.proof_request(name)));
