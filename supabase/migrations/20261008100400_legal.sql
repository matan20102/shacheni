-- Legal documents: TODO placeholders + the read/publish functions (§9.2 legal_document, §9.7, BR-L5).
-- No legal wording is written by engineering. The owner publishes the real texts with
-- publish_legal_document(...) from the Supabase SQL editor; that flips is_current and thereby
-- triggers re-acceptance for everyone on their next app start.

-- Privileged: postgres / service role only (never callable from the app).
create function public.publish_legal_document(
  p_type public.legal_doc_type, p_version text, p_locale text, p_title text, p_body_md text)
returns public.legal_document
language plpgsql volatile security definer set search_path = ''
as $$
declare
  doc public.legal_document;
begin
  update public.legal_document set is_current = false
  where type = p_type and locale = p_locale and is_current;

  -- clock_timestamp(): several publications inside one transaction must still be ordered
  insert into public.legal_document (
    type, version, locale, title, body_md, content_hash, is_current, effective_at, created_by, created_at)
  values (p_type, p_version, p_locale, p_title, p_body_md,
          encode(sha256(convert_to(p_body_md, 'UTF8')), 'hex'), true, clock_timestamp(), (select auth.uid()),
          clock_timestamp())
  returning * into doc;
  return doc;
end
$$;

revoke execute on function public.publish_legal_document(public.legal_doc_type, text, text, text, text)
  from public, anon, authenticated;
grant execute on function public.publish_legal_document(public.legal_doc_type, text, text, text, text)
  to service_role;

-- Public: needed before login (consent gate S04).
create function public.get_current_legal_documents(
  p_types public.legal_doc_type[] default null, p_locale text default 'he')
returns setof public.legal_document
language sql stable security definer set search_path = ''
as $$
  select * from public.legal_document
  where is_current and locale = p_locale and (p_types is null or type = any (p_types))
  order by type
$$;

revoke execute on function public.get_current_legal_documents(public.legal_doc_type[], text) from public;
grant execute on function public.get_current_legal_documents(public.legal_doc_type[], text)
  to anon, authenticated;

-- Placeholders: 5 types × he/en, version '0.0-todo'.
do $$
begin
  perform public.publish_legal_document(t.type::public.legal_doc_type, '0.0-todo', l.locale,
                                        case l.locale when 'he' then t.title_he else t.title_en end,
                                        'TODO — legal text to be provided by the owner.')
  from (values
    ('terms_of_service', 'תנאי שימוש', 'Terms of Service'),
    ('privacy_policy', 'מדיניות פרטיות', 'Privacy Policy'),
    ('community_rules', 'כללי הקהילה', 'Community Rules'),
    ('resident_declaration', 'הצהרת דייר', 'Resident Declaration'),
    ('building_agreement', 'הסכם בניין', 'Building Agreement')
  ) as t (type, title_he, title_en)
  cross join (values ('he'), ('en')) as l (locale);
end
$$;
