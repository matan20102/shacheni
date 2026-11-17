-- Rate limit for repeated join requests: after a manager declines a request or
-- removes a resident (status 'rejected'), the same person may ask to join that
-- building again only 24 hours later. Leaving voluntarily ('withdrawn') is not limited.
-- The signature of ba_submit_home and its public wrappers is unchanged; older
-- clients show their generic error for the new TRY_LATER code.

create or replace function app.ba_submit_home(p_code text, p_apartment text, p_floor text, p_entrance text, p_household_name text) returns uuid
language plpgsql volatile security definer set search_path = '' as $$
declare u uuid := app.require_user(); b uuid; a uuid; m uuid; old_status text; needs_admin boolean;
  n text := app.ba_normalize_apartment(p_apartment); e text := btrim(coalesce(p_entrance, '')); requested_name text;
begin
  perform app.require_terms();
  if coalesce(char_length(n), 0) not between 1 and 20 or char_length(e) > 20
    or coalesce(char_length(p_floor), 0) > 20 or char_length(btrim(coalesce(p_household_name, ''))) > 60 then raise exception 'INVALID_ARGUMENT'; end if;
  b := (app.ba_resolve(p_code)->>'id')::uuid;
  if b is null then return null; end if;
  perform 1 from public.building where id = b and status = 'active' for update;
  if not found then raise exception 'ACCESS_DENIED'; end if;
  select id, status into m, old_status from public.community_member where building_id = b and user_id = u for update;
  if old_status in ('pending', 'approved') then raise exception 'ALREADY_APPLIED'; end if;
  -- A declined or removed applicant waits a day before asking again.
  if old_status = 'rejected' and exists(select 1 from public.community_member
      where id = m and updated_at > now() - interval '24 hours') then
    raise exception 'TRY_LATER';
  end if;
  select d.apartment_id into a from public.community_apartment d where d.building_id = b and d.number = n;
  if a is null then
    -- Adopt old apartments that have not entered the directory, without moving an existing entrance.
    select ap.id into a from public.apartment ap where ap.building_id = b and ap.number = n
        and not exists(select 1 from public.community_apartment d where d.apartment_id = ap.id);
    if a is null then
      -- Legacy number remains unique per building; the directory is the visible identity.
      insert into public.apartment(building_id, number)
        values(b, case when exists(select 1 from public.apartment where building_id = b and number = n)
          then '@' || substr(replace(gen_random_uuid()::text, '-', ''), 1, 19) else n end) returning id into a;
    end if;
    insert into public.community_apartment(apartment_id, building_id, number, entrance) values(a, b, n, e);
  end if;
  select coalesce(nullif(d.entrance, ''), e) into e from public.community_apartment d where d.apartment_id = a;
  perform 1 from public.apartment where id = a for update;
  needs_admin := exists(select 1 from public.community_member where apartment_id = a and status = 'approved' and is_apartment_admin);
  requested_name := case when exists(select 1 from public.community_member where apartment_id = a and status = 'approved')
    then null else nullif(btrim(p_household_name), '') end;
  insert into public.community_member(building_id, apartment_id, user_id, floor, entrance, requires_apartment_approval, requested_household_name)
    values(b, a, u, nullif(btrim(p_floor), ''), nullif(e, ''), needs_admin, requested_name)
    on conflict (building_id, user_id) do update set apartment_id = excluded.apartment_id, status = 'pending',
      floor = excluded.floor, entrance = excluded.entrance, requires_apartment_approval = excluded.requires_apartment_approval,
      requested_household_name = excluded.requested_household_name,
      building_approved = false, apartment_approved = false, building_approved_by = null, apartment_approved_by = null, updated_at = now()
    returning id into m;
  perform app.notify(cm.user_id, b, 'community.application_received', jsonb_build_object('apartment', n, 'entrance', nullif(e, '')), '/home', m)
    from public.community_member cm where cm.building_id = b and cm.status = 'approved'
      and (cm.is_building_admin or (cm.apartment_id = a and cm.is_apartment_admin));
  perform app.audit(b, 'community.join', 'community_member', m);
  return m;
end $$;
