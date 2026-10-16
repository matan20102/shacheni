-- Prints the results of a *_test.sql file and fails it if any check failed.
select t.as_admin();
\pset footer off
select n, case when ok then 'ok' else 'FAIL' end as result, name, detail from t.results order by n;
select count(*) filter (where ok) as passed, count(*) filter (where not ok) as failed from t.results;
do $$
begin
  if exists (select 1 from t.results where not ok) then
    raise exception 'tests failed: %', (select string_agg(name || coalesce(': ' || detail, ''), '; ') from t.results where not ok);
  end if;
end
$$;

