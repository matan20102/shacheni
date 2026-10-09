-- Shared assertion kit for the *_test.sql files (included with \ir; needs psql).
-- Everything is created inside the test file's transaction and rolled back.

create schema t;
grant usage on schema t to public;
create table t.results (n serial, name text, ok boolean, detail text);
grant all on t.results to public;
grant usage on sequence t.results_n_seq to public;

create function t.ok(name text, cond boolean, detail text default null) returns void language sql as $$
  insert into t.results (name, ok, detail) values (name, coalesce(cond, false), detail)
$$;

-- Expect the statement to fail with an error whose SQLSTATE or message equals `expected`.
create function t.throws(name text, stmt text, expected text) returns void language plpgsql as $$
begin
  begin
    execute stmt;
  exception when others then
    perform t.ok(name, sqlerrm = expected or sqlstate = expected, sqlstate || ' ' || sqlerrm);
    return;
  end;
  perform t.ok(name, false, 'no error raised');
end
$$;

create function t.lives(name text, stmt text) returns void language plpgsql as $$
begin
  execute stmt;
  perform t.ok(name, true);
exception when others then
  perform t.ok(name, false, sqlstate || ' ' || sqlerrm);
end
$$;

create function t.count(stmt text) returns bigint language plpgsql as $$
declare n bigint;
begin
  execute 'select count(*) from (' || stmt || ') s' into n;
  return n;
end
$$;

-- Act as a user (or anon) for the following statements; t.as_admin() switches back.
create function t.as_user(u uuid) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', u, 'role', 'authenticated')::text, true);
  select set_config('role', 'authenticated', true);
$$;
create function t.as_anon() returns void language sql as $$
  select set_config('request.jwt.claims', '{"role":"anon"}', true);
  select set_config('role', 'anon', true);
$$;
create function t.as_admin() returns void language sql as $$
  select set_config('role', 'postgres', true);
  select set_config('request.jwt.claims', '', true);
$$;
grant execute on all functions in schema t to public;

