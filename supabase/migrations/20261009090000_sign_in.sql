-- Sign-in with Google (decision change: replaces phone OTP, see docs/PRD-decisions-roadmap.md A5).
-- The phone number is no longer an auth identity: residents type it into their profile/application
-- and the building admin verifies them. Email lives only in auth.users (no email column in profile).
--
-- Adds: profile bootstrap from Google metadata, the consent-gate RPCs, update_my_profile.

-- ---------------------------------------------------------------------------------------------
-- Profile bootstrap: take the display name from the OAuth metadata (Google: full_name / name).
-- A phone is copied only if the auth identity has one (phone sign-in, if ever re-enabled).
-- ---------------------------------------------------------------------------------------------
create or replace function app.handle_auth_user()
returns trigger language plpgsql security definer set search_path = ''
as $$
declare
  phone text := case when coalesce(new.phone, '') = '' then null
                     when new.phone like '+%' then new.phone
                     else '+' || new.phone end;
  display_name text := left(btrim(coalesce(
    new.raw_user_meta_data ->> 'full_name', new.raw_user_meta_data ->> 'name', '')), 100);
begin
  if tg_op = 'INSERT' then
    insert into public.profile (id, phone_e164, full_name) values (new.id, phone, display_name);
  elsif new.phone is distinct from old.phone and phone is not null then
    update public.profile set phone_e164 = phone where id = new.id;
  end if;
  return new;
end
$$;

-- ---------------------------------------------------------------------------------------------
-- Consent gate (S04, BR-L1): which current documents has the caller not accepted yet?
-- Only platform-wide types (no building): terms_of_service, privacy_policy. Building-scoped
-- types (rules, declaration, agreement) are accepted inside the join / activation flows.
-- ---------------------------------------------------------------------------------------------
create function public.my_pending_legal_documents(
  p_types public.legal_doc_type[] default array['terms_of_service', 'privacy_policy']::public.legal_doc_type[],
  p_locale text default 'he')
returns setof public.legal_document
language sql stable security definer set search_path = ''
as $$
  select d.*
  from public.legal_document d
  where d.is_current
    and d.locale = p_locale
    and d.type = any (p_types)
    and d.type in ('terms_of_service', 'privacy_policy')
    and not app.has_accepted_current(d.type)
  order by d.type
$$;

-- Records acceptance of the CURRENT version of each type, in the locale the user read it.
-- Idempotent: accepting an already-accepted version is a no-op.
create function public.accept_legal_documents(
  p_types public.legal_doc_type[], p_locale text default 'he', p_app_version text default null)
returns void
language plpgsql volatile security definer set search_path = ''
as $$
declare
  uid uuid := (select auth.uid());
  t public.legal_doc_type;
  doc public.legal_document;
begin
  if uid is null then
    raise exception 'NOT_AUTHENTICATED';
  end if;
  if p_locale not in ('he', 'en') then
    raise exception 'INVALID_ARGUMENT' using detail = 'locale';
  end if;
  if coalesce(cardinality(p_types), 0) = 0 then
    raise exception 'INVALID_ARGUMENT' using detail = 'types';
  end if;

  foreach t in array p_types loop
    if t not in ('terms_of_service', 'privacy_policy') then
      raise exception 'INVALID_ARGUMENT' using detail = 'building-scoped document: ' || t;
    end if;

    -- The document shown: the current row in the user's locale with the version in force.
    select d.* into doc
    from public.legal_document d
    where d.type = t and d.is_current and d.version = app.current_legal_version(t)
    order by (d.locale = p_locale) desc
    limit 1;
    if not found then
      raise exception 'LEGAL_DOCUMENT_MISSING' using detail = t::text;
    end if;

    insert into public.legal_acceptance (user_id, document_type, document_version, document_id, locale, app_version)
    values (uid, t, doc.version, doc.id, doc.locale, left(p_app_version, 40))
    on conflict do nothing;
  end loop;
end
$$;

-- ---------------------------------------------------------------------------------------------
-- update_my_profile: the only write path to one's own profile.
-- Phone: Israeli mobile, normalized to E.164 (+9725XXXXXXXX). Not verified by SMS — the building
-- admin verifies applicants (BR-B).
-- ---------------------------------------------------------------------------------------------
create function app.normalize_il_mobile(raw text)
returns text language sql immutable set search_path = ''
as $$
  select case
    when digits ~ '^9725[0-9]{8}$' then '+' || digits
    when digits ~ '^05[0-9]{8}$' then '+972' || substr(digits, 2)
    when digits ~ '^5[0-9]{8}$' then '+972' || digits
  end
  from (select regexp_replace(coalesce(raw, ''), '[^0-9]', '', 'g') as digits) s
$$;

create function public.update_my_profile(
  p_full_name text default null, p_phone text default null, p_locale text default null)
returns public.profile
language plpgsql volatile security definer set search_path = ''
as $$
declare
  uid uuid := (select auth.uid());
  phone text;
  result public.profile;
begin
  if uid is null then
    raise exception 'NOT_AUTHENTICATED';
  end if;
  if p_full_name is not null and char_length(btrim(p_full_name)) not between 2 and 100 then
    raise exception 'INVALID_ARGUMENT' using detail = 'full_name';
  end if;
  if p_phone is not null then
    phone := app.normalize_il_mobile(p_phone);
    if phone is null then
      raise exception 'PHONE_INVALID';
    end if;
    if exists (select 1 from public.profile where phone_e164 = phone and id <> uid) then
      raise exception 'PHONE_TAKEN';
    end if;
  end if;
  if p_locale is not null and p_locale not in ('he', 'en') then
    raise exception 'INVALID_ARGUMENT' using detail = 'locale';
  end if;

  update public.profile set
    full_name = coalesce(btrim(p_full_name), full_name),
    phone_e164 = coalesce(phone, phone_e164),
    locale = coalesce(p_locale, locale)
  where id = uid
  returning * into result;
  return result;
end
$$;

-- RPC exposure: authenticated users only.
revoke execute on function public.my_pending_legal_documents(public.legal_doc_type[], text) from public, anon;
revoke execute on function public.accept_legal_documents(public.legal_doc_type[], text, text) from public, anon;
revoke execute on function public.update_my_profile(text, text, text) from public, anon;
grant execute on function public.my_pending_legal_documents(public.legal_doc_type[], text) to authenticated;
grant execute on function public.accept_legal_documents(public.legal_doc_type[], text, text) to authenticated;
grant execute on function public.update_my_profile(text, text, text) to authenticated;
