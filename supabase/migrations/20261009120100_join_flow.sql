-- Join flow: building setup (platform), join code, application, admin decision, and the
-- access summary the app routes on. Spec: PRD flows F01–F06, F21; BR-A1–A6, BR-B1–B7, BR-C2.
-- All RPCs: security definer, actor = auth.uid(), stable error codes as messages.

-- =============================================================================================
-- Internal helpers
-- =============================================================================================

-- guard_self_review: also re-check when the status changes under the same reviewer
-- (e.g. "request info" then "approve" by the same admin, with the switch turned off in between).
create or replace function app.guard_self_review()
returns trigger language plpgsql set search_path = ''
as $$
declare
  reviewer uuid;
  old_reviewer uuid;
  status_changed boolean := tg_op = 'INSERT' or (to_jsonb(new) ->> 'status') is distinct from (to_jsonb(old) ->> 'status');
  is_self boolean;
begin
  if tg_table_name = 'dispute' then
    reviewer := new.resolved_by;
    if tg_op = 'UPDATE' then old_reviewer := old.resolved_by; end if;
  else
    reviewer := new.reviewed_by;
    if tg_op = 'UPDATE' then old_reviewer := old.reviewed_by; end if;
  end if;

  if reviewer is null or (reviewer is not distinct from old_reviewer and not status_changed) then
    return new;
  end if;

  if not app.holds_building_admin_role(new.building_id, reviewer) then
    raise exception 'NOT_BUILDING_ADMIN';
  end if;

  -- (separate branches: each table has different columns)
  if tg_table_name = 'building_membership' then
    is_self := reviewer = new.user_id;
  elsif tg_table_name = 'parking_assignment' then
    is_self := exists (
      select 1 from public.building_membership m where m.id = new.membership_id and m.user_id = reviewer);
  else
    is_self := exists (
      select 1 from public.transactions t
      where t.id = new.transaction_id and reviewer in (t.payer_id, t.payee_id));
  end if;

  if is_self then
    if not coalesce((app.building_setting(new.building_id, 'allow_admin_self_review'))::boolean, false) then
      raise exception 'SELF_REVIEW_FORBIDDEN';
    end if;
    if tg_table_name = 'dispute' then
      new.self_review := true;
    else
      new.flags := new.flags || '{"self_review": true}';
    end if;
  end if;
  return new;
end
$$;

-- 8 characters from the unambiguous alphabet (no 0/O/1/I). Not a secret: it only resolves a
-- building, is rate-limited, and the admin verifies every applicant (BR-B6).
create function app.new_join_code()
returns text language plpgsql volatile set search_path = ''
as $$
declare
  alphabet constant text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  code text;
begin
  loop
    select string_agg(substr(alphabet, 1 + floor(random() * 32)::int, 1), '') into code
    from generate_series(1, 8);
    exit when not exists (select 1 from public.building where join_code = code);
  end loop;
  return code;
end
$$;

-- Records acceptance of the current version of a document type (in the user's locale if it exists).
create function app.record_acceptance(
  uid uuid, b uuid, t public.legal_doc_type, p_locale text, p_details jsonb default '{}')
returns void language plpgsql volatile security definer set search_path = ''
as $$
declare
  doc public.legal_document;
begin
  select d.* into doc
  from public.legal_document d
  where d.type = t and d.is_current and d.version = app.current_legal_version(t)
  order by (d.locale = p_locale) desc
  limit 1;
  if not found then
    raise exception 'LEGAL_DOCUMENT_MISSING' using detail = t::text;
  end if;
  insert into public.legal_acceptance (user_id, building_id, document_type, document_version, document_id, locale, details, app_version)
  values (uid, b, t, doc.version, doc.id, doc.locale, coalesce(p_details, '{}'), null)
  on conflict do nothing;
end
$$;

create function app.notify(
  u uuid, b uuid, n_type text, params jsonb, route text, entity uuid, dedupe text default null)
returns void language sql volatile security definer set search_path = ''
as $$
  insert into public.notification (building_id, user_id, type, params, route, entity_id, dedupe_key)
  values (b, u, n_type, coalesce(params, '{}'), route, entity, dedupe)
  on conflict (user_id, dedupe_key) do nothing
$$;

create function app.notify_building_admins(b uuid, n_type text, params jsonb, route text, entity uuid)
returns void language sql volatile security definer set search_path = ''
as $$
  select app.notify(ba.user_id, b, n_type, params, route, entity,
                    n_type || ':' || entity || ':' || extract(epoch from clock_timestamp()))
  from public.building_admin ba
  where ba.building_id = b and ba.revoked_at is null
$$;

create function app.require_user()
returns uuid language plpgsql stable set search_path = ''
as $$
begin
  if (select auth.uid()) is null then
    raise exception 'NOT_AUTHENTICATED';
  end if;
  return (select auth.uid());
end
$$;

-- Distinct, trimmed, non-empty labels; raises if the cleaned list has duplicates.
create function app.clean_labels(labels text[], max_len int)
returns text[] language plpgsql immutable set search_path = ''
as $$
declare
  cleaned text[];
begin
  select coalesce(array_agg(x order by ord), '{}') into cleaned
  from (select btrim(v) as x, ord from unnest(coalesce(labels, '{}')) with ordinality as u (v, ord)) s
  where x <> '';
  if (select count(distinct lower(x)) from unnest(cleaned) x) <> cardinality(cleaned) then
    raise exception 'DUPLICATE_LABEL';
  end if;
  if exists (select 1 from unnest(cleaned) x where char_length(x) > max_len) then
    raise exception 'INVALID_ARGUMENT' using detail = 'label too long';
  end if;
  return cleaned;
end
$$;

-- =============================================================================================
-- Access summary: everything the app's router needs after sign-in, in one call
-- =============================================================================================
create function public.get_my_access()
returns jsonb language plpgsql stable security definer set search_path = ''
as $$
declare
  uid uuid := app.require_user();
  m record;
  membership jsonb;
begin
  -- the live membership if any, otherwise the most recent one (so a rejection can be shown)
  select bm.*, b.name as b_name, b.address as b_address, b.city as b_city, b.status as b_status, a.number as apt
  into m
  from public.building_membership bm
  join public.building b on b.id = bm.building_id
  join public.apartment a on a.id = bm.apartment_id
  where bm.user_id = uid
  order by (bm.status in ('pending', 'info_requested', 'approved', 'disabled')) desc, bm.updated_at desc
  limit 1;

  if found then
    membership := jsonb_build_object(
      'id', m.id,
      'status', m.status,
      'building_id', m.building_id,
      'building_name', m.b_name,
      'building_address', m.b_address,
      'building_city', m.b_city,
      'building_status', m.b_status,
      'apartment', m.apt,
      'applicant_note', m.applicant_note,
      'info_request_message', m.info_request_message,
      'status_reason', m.status_reason,
      'submitted_at', m.updated_at,
      'spaces', coalesce((
        select jsonb_agg(jsonb_build_object('label', s.label, 'status', pa.status) order by s.label)
        from public.parking_assignment pa
        join public.parking_space s on s.id = pa.parking_space_id
        where pa.membership_id = m.id and pa.status in ('requested', 'active')), '[]'));
  end if;

  return jsonb_build_object(
    'user_id', uid,
    'legal_pending', not (app.has_accepted_current('terms_of_service') and app.has_accepted_current('privacy_policy')),
    'is_platform_admin', app.is_platform_admin(),
    'profile', (select jsonb_build_object('full_name', p.full_name, 'phone', p.phone_e164)
                from public.profile p where p.id = uid),
    'membership', membership,
    'admin_buildings', coalesce((
      select jsonb_agg(jsonb_build_object('id', b.id, 'name', b.name, 'status', b.status) order by b.created_at)
      from public.building_admin ba
      join public.building b on b.id = ba.building_id
      where ba.user_id = uid and ba.revoked_at is null), '[]'));
end
$$;

-- =============================================================================================
-- Platform: create → define apartments/spaces → accept agreement & activate (F21, BR-A1/A2)
-- =============================================================================================
create function public.create_building(
  p_name text, p_address text, p_city text, p_apartment_count int, p_parking_count int)
returns uuid language plpgsql volatile security definer set search_path = ''
as $$
declare
  uid uuid := app.require_user();
  bid uuid;
begin
  if not app.is_platform_admin() then
    raise exception 'NOT_PLATFORM_ADMIN';
  end if;
  if exists (select 1 from public.building
             where lower(name) = lower(btrim(p_name)) and lower(address) = lower(btrim(p_address))) then
    raise exception 'BUILDING_EXISTS';
  end if;

  insert into public.building (name, address, city, declared_apartment_count, declared_parking_count, created_by)
  values (btrim(p_name), btrim(p_address), nullif(btrim(p_city), ''), p_apartment_count, p_parking_count, uid)
  returning id into bid;

  -- The creator becomes the building's admin (MVP: the only one).
  insert into public.building_admin (building_id, user_id, granted_by) values (bid, uid, uid);
  perform app.audit(bid, 'create_building', 'building', bid);
  return bid;
end
$$;

-- Replaces the apartment and parking-space lists of a DRAFT building (nobody can reference them yet:
-- join codes exist only after activation). Active buildings change through dedicated admin RPCs.
create function public.set_building_units(p_building uuid, p_apartments text[], p_spaces text[])
returns void language plpgsql volatile security definer set search_path = ''
as $$
declare
  uid uuid := app.require_user();
  st public.building_status;
  apts text[] := app.clean_labels(p_apartments, 20);
  spaces text[] := app.clean_labels(p_spaces, 20);
begin
  if not (app.is_platform_admin() or app.holds_building_admin_role(p_building, uid)) then
    raise exception 'NOT_BUILDING_ADMIN';
  end if;
  select status into st from public.building where id = p_building for update;
  if not found then
    raise exception 'NOT_FOUND';
  end if;
  if st <> 'draft' then
    raise exception 'INVALID_STATE' using detail = st::text;
  end if;

  delete from public.apartment where building_id = p_building;
  delete from public.parking_space where building_id = p_building;
  insert into public.apartment (building_id, number) select p_building, x from unnest(apts) x;
  insert into public.parking_space (building_id, label) select p_building, x from unnest(spaces) x;
  perform app.audit(p_building, 'set_building_units', 'building', p_building,
                    cardinality(apts) || ' apartments, ' || cardinality(spaces) || ' spaces');
end
$$;

-- BR-A2: lists defined and matching the declared counts; records the building agreement;
-- issues the join code; draft → active. Returns the join code.
create function public.accept_building_agreement_and_activate(p_building uuid, p_locale text default 'he')
returns text language plpgsql volatile security definer set search_path = ''
as $$
declare
  uid uuid := app.require_user();
  b public.building;
  n_apts int;
  n_spaces int;
  code text;
begin
  if not app.holds_building_admin_role(p_building, uid) then
    raise exception 'NOT_BUILDING_ADMIN';
  end if;
  select * into b from public.building where id = p_building for update;
  if b.status <> 'draft' then
    raise exception 'INVALID_STATE' using detail = b.status::text;
  end if;

  select count(*) into n_apts from public.apartment where building_id = p_building and is_active;
  select count(*) into n_spaces from public.parking_space where building_id = p_building and is_active;
  if n_apts = 0 or n_apts <> b.declared_apartment_count then
    raise exception 'COUNT_MISMATCH' using detail = 'apartments ' || n_apts || '/' || b.declared_apartment_count;
  end if;
  if n_spaces <> b.declared_parking_count then
    raise exception 'COUNT_MISMATCH' using detail = 'spaces ' || n_spaces || '/' || b.declared_parking_count;
  end if;

  perform app.record_acceptance(uid, p_building, 'building_agreement', p_locale);
  code := app.new_join_code();
  update public.building
  set status = 'active', activated_at = now(), join_code = code, join_code_rotated_at = now()
  where id = p_building;
  perform app.audit(p_building, 'activate_building', 'building', p_building);
  return code;
end
$$;

create function public.platform_list_buildings()
returns jsonb language plpgsql stable security definer set search_path = ''
as $$
begin
  if not app.is_platform_admin() then
    raise exception 'NOT_PLATFORM_ADMIN';
  end if;
  -- counts only: the platform role sees no personal data (§12.4)
  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', b.id, 'name', b.name, 'address', b.address, 'city', b.city, 'status', b.status,
      'declared_apartments', b.declared_apartment_count, 'declared_spaces', b.declared_parking_count,
      'apartments', (select count(*) from public.apartment a where a.building_id = b.id and a.is_active),
      'spaces', (select count(*) from public.parking_space s where s.building_id = b.id and s.is_active),
      'residents', (select count(*) from public.building_membership m where m.building_id = b.id and m.status = 'approved'),
      'pending', (select count(*) from public.building_membership m
                  where m.building_id = b.id and m.status in ('pending', 'info_requested'))
    ) order by b.created_at)
    from public.building b), '[]');
end
$$;

-- Building details for its admin (or the platform admin during setup), including the join code.
create function public.admin_get_building(p_building uuid)
returns jsonb language plpgsql stable security definer set search_path = ''
as $$
declare
  uid uuid := app.require_user();
begin
  if not (app.is_platform_admin() or app.holds_building_admin_role(p_building, uid)) then
    raise exception 'NOT_BUILDING_ADMIN';
  end if;
  return (
    select jsonb_build_object(
      'id', b.id, 'name', b.name, 'address', b.address, 'city', b.city, 'status', b.status,
      'join_code', b.join_code,
      'declared_apartments', b.declared_apartment_count, 'declared_spaces', b.declared_parking_count,
      'apartments', coalesce((select jsonb_agg(a.number order by a.created_at, a.number)
                              from public.apartment a where a.building_id = b.id and a.is_active), '[]'),
      'spaces', coalesce((select jsonb_agg(s.label order by s.created_at, s.label)
                          from public.parking_space s where s.building_id = b.id and s.is_active), '[]'),
      'pending', (select count(*) from public.building_membership m
                  where m.building_id = b.id and m.status in ('pending', 'info_requested')),
      'residents', (select count(*) from public.building_membership m
                    where m.building_id = b.id and m.status = 'approved'),
      'allow_admin_self_review', coalesce((b.settings ->> 'allow_admin_self_review')::boolean, false),
      'agreement_accepted', app.is_building_admin(b.id))
    from public.building b where b.id = p_building);
end
$$;

-- =============================================================================================
-- Join: resolve the code (BR-B6), submit / withdraw / answer (BR-B1–B4)
-- =============================================================================================
create function public.resolve_join_code(p_code text)
returns jsonb language plpgsql volatile security definer set search_path = ''
as $$
declare
  uid uuid := app.require_user();
  code text := upper(regexp_replace(coalesce(p_code, ''), '[^A-Za-z0-9]', '', 'g'));
  b public.building;
  ok boolean;
begin
  if not (app.has_accepted_current('terms_of_service') and app.has_accepted_current('privacy_policy')) then
    raise exception 'LEGAL_NOT_ACCEPTED';
  end if;
  if (select count(*) from public.join_code_attempt
      where user_id = uid and not succeeded and created_at > now() - interval '1 hour')
     >= (app.default_building_settings() ->> 'join_attempts_per_hour')::int then
    raise exception 'RATE_LIMITED';
  end if;

  select * into b from public.building where join_code = code and status = 'active';
  ok := found;
  -- Recorded even on failure, so wrong codes count towards the limit (no raise below → no rollback).
  insert into public.join_code_attempt (user_id, succeeded) values (uid, ok);
  if not ok then
    return null;
  end if;

  return jsonb_build_object(
    'building', jsonb_build_object('id', b.id, 'name', b.name, 'address', b.address, 'city', b.city),
    'apartments', coalesce((select jsonb_agg(jsonb_build_object('id', a.id, 'number', a.number) order by a.created_at, a.number)
                            from public.apartment a where a.building_id = b.id and a.is_active), '[]'),
    'spaces', coalesce((select jsonb_agg(jsonb_build_object('id', s.id, 'label', s.label) order by s.created_at, s.label)
                        from public.parking_space s where s.building_id = b.id and s.is_active), '[]'));
end
$$;

create function public.submit_membership_application(
  p_building uuid,
  p_apartment uuid,
  p_space_ids uuid[],
  p_full_name text,
  p_phone text,
  p_note text default null,
  p_declarations jsonb default '{}',
  p_locale text default 'he')
returns uuid language plpgsql volatile security definer set search_path = ''
as $$
declare
  uid uuid := app.require_user();
  spaces uuid[] := array(select distinct x from unnest(coalesce(p_space_ids, '{}')) x);
  required text[] := array['accurate_info', 'is_resident', 'apartment_correct', 'rules_understood'];
  k text;
  existing public.building_membership;
  mid uuid;
  residents int;
begin
  if not (app.has_accepted_current('terms_of_service') and app.has_accepted_current('privacy_policy')) then
    raise exception 'LEGAL_NOT_ACCEPTED';
  end if;
  if not exists (select 1 from public.building where id = p_building and status = 'active') then
    raise exception 'BUILDING_NOT_ACTIVE';
  end if;
  if not exists (select 1 from public.apartment where id = p_apartment and building_id = p_building and is_active) then
    raise exception 'INVALID_ARGUMENT' using detail = 'apartment';
  end if;
  if (select count(*) from public.parking_space where id = any (spaces) and building_id = p_building and is_active)
     <> cardinality(spaces) then
    raise exception 'INVALID_ARGUMENT' using detail = 'spaces';
  end if;
  if cardinality(spaces) > 0 then
    required := array_append(required, 'parking_correct');
  end if;
  foreach k in array required loop
    if coalesce((p_declarations ->> k)::boolean, false) is not true then
      raise exception 'DECLARATIONS_REQUIRED' using detail = k;
    end if;
  end loop;
  if exists (select 1 from public.building_membership
             where user_id = uid and status in ('pending', 'info_requested', 'approved')) then
    raise exception 'ALREADY_APPLIED';
  end if;

  -- name + phone live on the profile (validated there: PHONE_INVALID / PHONE_TAKEN)
  perform public.update_my_profile(p_full_name, p_phone, p_locale);

  select count(*) into residents from public.building_membership
  where apartment_id = p_apartment and status = 'approved';

  select * into existing from public.building_membership
  where building_id = p_building and user_id = uid for update;
  if found then
    if existing.status = 'disabled' then
      raise exception 'MEMBERSHIP_DISABLED';
    end if;
    -- re-application after a rejection / withdrawal reuses the row (unique per building + user)
    update public.building_membership set
      apartment_id = p_apartment, status = 'pending', applicant_note = nullif(btrim(p_note), ''),
      info_request_message = null, info_response = null, status_reason = null,
      reviewed_by = null, reviewed_at = null, approved_at = null,
      flags = jsonb_build_object('apartment_residents', residents)
    where id = existing.id;
    mid := existing.id;
    update public.parking_assignment set status = 'withdrawn'
    where membership_id = mid and status = 'requested';
  else
    insert into public.building_membership (building_id, user_id, apartment_id, applicant_note, flags)
    values (p_building, uid, p_apartment, nullif(btrim(p_note), ''), jsonb_build_object('apartment_residents', residents))
    returning id into mid;
  end if;

  -- BR-C4: requests only; the admin verifies. Flag spaces someone else currently holds.
  insert into public.parking_assignment (building_id, parking_space_id, membership_id, apartment_id, flags)
  select p_building, s, mid, p_apartment,
         jsonb_build_object('currently_assigned_to_other',
           exists (select 1 from public.parking_assignment x where x.parking_space_id = s and x.status = 'active'))
  from unnest(spaces) s;

  perform app.record_acceptance(uid, p_building, 'community_rules', p_locale);
  perform app.record_acceptance(uid, p_building, 'resident_declaration', p_locale, p_declarations);

  insert into public.membership_event (building_id, membership_id, actor_id, type, message)
  values (p_building, mid, uid, 'submitted', nullif(btrim(p_note), ''));
  perform app.notify_building_admins(p_building, 'membership.application_received',
    jsonb_build_object('name', btrim(p_full_name)), '/admin/applications/' || mid, mid);
  return mid;
end
$$;

create function public.withdraw_application()
returns void language plpgsql volatile security definer set search_path = ''
as $$
declare
  uid uuid := app.require_user();
  m public.building_membership;
begin
  select * into m from public.building_membership
  where user_id = uid and status in ('pending', 'info_requested') for update;
  if not found then
    raise exception 'NOT_FOUND';
  end if;
  update public.building_membership set status = 'withdrawn' where id = m.id;
  update public.parking_assignment set status = 'withdrawn' where membership_id = m.id and status = 'requested';
  insert into public.membership_event (building_id, membership_id, actor_id, type)
  values (m.building_id, m.id, uid, 'withdrawn');
end
$$;

create function public.respond_to_info_request(p_text text)
returns void language plpgsql volatile security definer set search_path = ''
as $$
declare
  uid uuid := app.require_user();
  m public.building_membership;
begin
  if char_length(btrim(coalesce(p_text, ''))) not between 1 and 500 then
    raise exception 'INVALID_ARGUMENT' using detail = 'text';
  end if;
  select * into m from public.building_membership where user_id = uid and status = 'info_requested' for update;
  if not found then
    raise exception 'INVALID_STATE';
  end if;
  update public.building_membership set status = 'pending', info_response = btrim(p_text) where id = m.id;
  insert into public.membership_event (building_id, membership_id, actor_id, type, message)
  values (m.building_id, m.id, uid, 'info_provided', btrim(p_text));
  perform app.notify_building_admins(m.building_id, 'membership.info_provided',
    '{}', '/admin/applications/' || m.id, m.id);
end
$$;

-- =============================================================================================
-- Admin: applications (A03/A04), decision with parking (BR-A6, BR-C2)
-- =============================================================================================
create function public.admin_list_applications(p_building uuid)
returns jsonb language plpgsql stable security definer set search_path = ''
as $$
declare
  uid uuid := app.require_user();
begin
  if not app.is_building_admin(p_building) then
    raise exception 'NOT_BUILDING_ADMIN';
  end if;
  return coalesce((
    select jsonb_agg(row_to_json(r)::jsonb order by r.submitted_at desc)
    from (
      select m.id, m.user_id, p.full_name, p.phone_e164 as phone, a.number as apartment, m.status,
             m.updated_at as submitted_at, m.applicant_note, m.info_request_message, m.info_response,
             m.status_reason, m.flags, (m.user_id = uid) as is_self,
             (select count(*) from public.building_membership o
              where o.apartment_id = m.apartment_id and o.status = 'approved' and o.id <> m.id) as apartment_residents,
             coalesce((
               select jsonb_agg(jsonb_build_object(
                 'assignment_id', pa.id, 'space_id', s.id, 'label', s.label, 'status', pa.status,
                 'held_by_other', exists (select 1 from public.parking_assignment x
                                          where x.parking_space_id = s.id and x.status = 'active'
                                            and x.membership_id <> m.id)) order by s.label)
               from public.parking_assignment pa
               join public.parking_space s on s.id = pa.parking_space_id
               where pa.membership_id = m.id and pa.status in ('requested', 'active', 'rejected')), '[]') as spaces
      from public.building_membership m
      join public.profile p on p.id = m.user_id
      join public.apartment a on a.id = m.apartment_id
      where m.building_id = p_building and m.status <> 'withdrawn'
    ) r), '[]');
end
$$;

create function public.admin_decide_membership(
  p_membership uuid, p_decision text, p_note text default null, p_approve_space_ids uuid[] default '{}')
returns void language plpgsql volatile security definer set search_path = ''
as $$
declare
  uid uuid := app.require_user();
  m public.building_membership;
  note text := nullif(btrim(coalesce(p_note, '')), '');
  a record;
  self boolean;
begin
  select * into m from public.building_membership where id = p_membership for update;
  if not found then
    raise exception 'NOT_FOUND';
  end if;
  if not app.is_building_admin(m.building_id) then
    raise exception 'NOT_BUILDING_ADMIN';
  end if;
  if m.status not in ('pending', 'info_requested') then
    raise exception 'INVALID_STATE' using detail = m.status::text;
  end if;
  if p_decision in ('reject', 'request_info') and note is null then
    raise exception 'NOTE_REQUIRED';
  end if;

  if p_decision = 'approve' then
    -- guard_self_review checks the role and sets flags.self_review when the admin approves themself
    update public.building_membership
    set status = 'approved', reviewed_by = uid, reviewed_at = now(), approved_at = now(), status_reason = null
    where id = m.id returning * into m;

    for a in
      select pa.id, pa.parking_space_id, s.label
      from public.parking_assignment pa join public.parking_space s on s.id = pa.parking_space_id
      where pa.membership_id = m.id and pa.status = 'requested'
      order by s.label
    loop
      if a.parking_space_id = any (coalesce(p_approve_space_ids, '{}')) then
        if exists (select 1 from public.parking_assignment x where x.parking_space_id = a.parking_space_id and x.status = 'active') then
          raise exception 'SPACE_HELD' using detail = a.label;
        end if;
        update public.parking_assignment
        set status = 'active', reviewed_by = uid, reviewed_at = now(), started_at = now(), review_note = null
        where id = a.id;
      else
        update public.parking_assignment
        set status = 'rejected', reviewed_by = uid, reviewed_at = now(), review_note = note
        where id = a.id;
      end if;
    end loop;

  elsif p_decision = 'reject' then
    update public.building_membership
    set status = 'rejected', status_reason = note, reviewed_by = uid, reviewed_at = now()
    where id = m.id returning * into m;
    update public.parking_assignment
    set status = 'rejected', reviewed_by = uid, reviewed_at = now(), review_note = note
    where membership_id = m.id and status = 'requested';

  elsif p_decision = 'request_info' then
    update public.building_membership
    set status = 'info_requested', info_request_message = note, info_response = null,
        reviewed_by = uid, reviewed_at = now()
    where id = m.id returning * into m;

  else
    raise exception 'INVALID_ARGUMENT' using detail = 'decision';
  end if;

  self := coalesce((m.flags ->> 'self_review')::boolean, false) and m.user_id = uid;
  insert into public.membership_event (building_id, membership_id, actor_id, type, message)
  values (m.building_id, m.id, uid,
          (case p_decision when 'approve' then 'approved' when 'reject' then 'rejected' else 'info_requested' end)::public.membership_event_type,
          note);
  perform app.audit(m.building_id,
                    case p_decision when 'approve' then 'approve_membership'
                                    when 'reject' then 'reject_membership' else 'request_info' end,
                    'building_membership', m.id, note, self);
  perform app.notify(m.user_id, m.building_id, 'membership.' || p_decision, '{}', '/pending', m.id,
                     'membership.' || p_decision || ':' || m.id || ':' || extract(epoch from clock_timestamp()));
end
$$;

-- =============================================================================================
-- Exposure: authenticated callers only (each RPC checks its own role)
-- =============================================================================================
do $$
declare
  f text;
begin
  foreach f in array array[
    'public.get_my_access()',
    'public.create_building(text, text, text, int, int)',
    'public.set_building_units(uuid, text[], text[])',
    'public.accept_building_agreement_and_activate(uuid, text)',
    'public.platform_list_buildings()',
    'public.admin_get_building(uuid)',
    'public.resolve_join_code(text)',
    'public.submit_membership_application(uuid, uuid, uuid[], text, text, text, jsonb, text)',
    'public.withdraw_application()',
    'public.respond_to_info_request(text)',
    'public.admin_list_applications(uuid)',
    'public.admin_decide_membership(uuid, text, text, uuid[])']
  loop
    execute format('revoke execute on function %s from public, anon', f);
    execute format('grant execute on function %s to authenticated', f);
  end loop;
end
$$;
