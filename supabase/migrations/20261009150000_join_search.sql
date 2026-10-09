-- Find a building by name / address as an alternative to the join code (decision F37, amends BR-B6).
-- Finding a building still grants nothing: the admin verifies every applicant. Safeguards: terms
-- accepted, active buildings only, name/address/city only, ≤ 10 results, ≤ 30 searches/hour/user.

alter table public.join_code_attempt
  add column kind text not null default 'code' check (kind in ('code', 'search'));

-- Building card + pick-lists for the application form (shared by code and search).
create function app.join_info(b public.building)
returns jsonb language sql stable security definer set search_path = ''
as $$
  select jsonb_build_object(
    'building', jsonb_build_object('id', b.id, 'name', b.name, 'address', b.address, 'city', b.city),
    'apartments', coalesce((select jsonb_agg(jsonb_build_object('id', a.id, 'number', a.number) order by a.created_at, a.number)
                            from public.apartment a where a.building_id = b.id and a.is_active), '[]'),
    'spaces', coalesce((select jsonb_agg(jsonb_build_object('id', s.id, 'label', s.label) order by s.created_at, s.label)
                        from public.parking_space s where s.building_id = b.id and s.is_active), '[]'))
$$;

create function app.require_terms()
returns void language plpgsql stable security definer set search_path = ''
as $$
begin
  if not (app.has_accepted_current('terms_of_service') and app.has_accepted_current('privacy_policy')) then
    raise exception 'LEGAL_NOT_ACCEPTED';
  end if;
end
$$;

-- Same behavior as before; now counts only code attempts and uses the shared builder.
create or replace function public.resolve_join_code(p_code text)
returns jsonb language plpgsql volatile security definer set search_path = ''
as $$
declare
  uid uuid := app.require_user();
  code text := upper(regexp_replace(coalesce(p_code, ''), '[^A-Za-z0-9]', '', 'g'));
  b public.building;
  ok boolean;
begin
  perform app.require_terms();
  if (select count(*) from public.join_code_attempt
      where user_id = uid and kind = 'code' and not succeeded and created_at > now() - interval '1 hour')
     >= (app.default_building_settings() ->> 'join_attempts_per_hour')::int then
    raise exception 'RATE_LIMITED';
  end if;

  select * into b from public.building where join_code = code and status = 'active';
  ok := found;
  -- Recorded even on failure, so wrong codes count towards the limit (no raise below → no rollback).
  insert into public.join_code_attempt (user_id, succeeded, kind) values (uid, ok, 'code');
  return case when ok then app.join_info(b) end;
end
$$;

-- Active buildings whose name, address or city contains the text (case-insensitive, ≥ 2 chars).
create function public.search_buildings(p_query text)
returns jsonb language plpgsql volatile security definer set search_path = ''
as $$
declare
  uid uuid := app.require_user();
  q text := lower(btrim(coalesce(p_query, '')));
begin
  perform app.require_terms();
  if char_length(q) < 2 then
    raise exception 'INVALID_ARGUMENT' using detail = 'query too short';
  end if;
  if (select count(*) from public.join_code_attempt
      where user_id = uid and kind = 'search' and created_at > now() - interval '1 hour') >= 30 then
    raise exception 'RATE_LIMITED';
  end if;
  insert into public.join_code_attempt (user_id, succeeded, kind) values (uid, true, 'search');

  return coalesce((
    select jsonb_agg(jsonb_build_object('id', r.id, 'name', r.name, 'address', r.address, 'city', r.city) order by r.name)
    from (
      select b.id, b.name, b.address, b.city
      from public.building b
      where b.status = 'active'
        and position(q in lower(b.name || ' ' || b.address || ' ' || coalesce(b.city, ''))) > 0
      order by b.name
      limit 10
    ) r), '[]');
end
$$;

-- The application form's pick-lists for a building chosen from the search results.
create function public.get_join_info(p_building uuid)
returns jsonb language plpgsql stable security definer set search_path = ''
as $$
declare
  b public.building;
begin
  perform app.require_user();
  perform app.require_terms();
  select * into b from public.building where id = p_building and status = 'active';
  if not found then
    raise exception 'NOT_FOUND';
  end if;
  return app.join_info(b);
end
$$;

revoke execute on function public.search_buildings(text), public.get_join_info(uuid) from public, anon;
grant execute on function public.search_buildings(text), public.get_join_info(uuid) to authenticated;
