-- Explicit opt-in development fixture. Run as project owner, never from the app.
-- No password, OAuth identity, email delivery or real-user membership is created.
-- Re-running leaves an existing fixture (including pending test requests) intact.
do $$
declare b uuid; owner_id uuid; resident_id uuid; a uuid; i int;
  labels text[] := array['מנהל בניין בדיקה · CHECK', 'מנהל בית בדיקה א׳ · CHECK', 'מנהל בית בדיקה ב׳ · CHECK'];
begin
  perform pg_advisory_xact_lock(hashtext('naybor:fixture:join-check'));
  if exists(select 1 from public.building where settings->>'community_test_fixture' = 'join-check') then
    return;
  end if;
  if exists(select 1 from auth.users where email in (
    'naybor-check-admin@example.invalid', 'naybor-check-home-a@example.invalid', 'naybor-check-home-b@example.invalid')) then
    raise exception 'CHECK_FIXTURE_EMAIL_CONFLICT';
  end if;
  for i in 1..3 loop
    resident_id := gen_random_uuid();
    insert into auth.users(id, email, raw_user_meta_data) values(resident_id,
      case i when 1 then 'naybor-check-admin@example.invalid' when 2 then 'naybor-check-home-a@example.invalid' else 'naybor-check-home-b@example.invalid' end,
      jsonb_build_object('full_name', labels[i], 'test_fixture', 'join-check'));
    if i = 1 then
      owner_id := resident_id;
      insert into public.building(name, address, declared_apartment_count, declared_parking_count,
        status, join_code, join_code_rotated_at, created_by, activated_at, settings)
      values('נייבור · בניין בדיקות CHECK', 'סביבת בדיקה בלבד — ירושלים', 4, 0,
        'active', app.new_join_code(), now(), owner_id, now(),
        app.default_building_settings() || '{"community_test_fixture":"join-check"}'::jsonb) returning id into b;
      insert into public.community_settings(building_id, entrance_count) values(b, 5);
    end if;
    insert into public.apartment(building_id, number) values(b,
      case i when 1 then '4' when 2 then '12' else '24' end) returning id into a;
    insert into public.community_apartment(apartment_id, building_id, number, entrance)
      values(a, b, case i when 1 then '4' when 2 then '12' else '24' end, case when i = 3 then 'ב' else 'א' end);
    insert into public.community_member(building_id, apartment_id, user_id, entrance, status,
      building_approved, building_approved_by, is_building_admin, is_committee, is_apartment_admin)
      values(b, a, resident_id, case when i = 3 then 'ב' else 'א' end, 'approved', true, owner_id, i = 1, i = 1, true);
    insert into public.community_household(apartment_id, building_id, display_name, updated_by)
      values(a, b, case i when 1 then 'בית מנהל הבדיקה' when 2 then 'משפחת כהן · בדיקה' else 'משפחת לוי · בדיקה' end, resident_id);
  end loop;
  insert into public.apartment(building_id, number) values(b,'8') returning id into a;
  insert into public.community_apartment(apartment_id, building_id, number, entrance) values(a,b,'8','א');
end $$;
