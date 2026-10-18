-- Minimal stand-in for the pieces of a Supabase database that our migrations depend on, so the
-- migrations and tests can run against a plain PostgreSQL 17 (no Docker / Supabase CLI needed).
-- NOT a migration — never apply this to a real Supabase project.

-- Roles are cluster-wide, so create them only once.
do $$
begin
  if not exists (select 1 from pg_roles where rolname = 'anon') then
    create role anon nologin noinherit;
    create role authenticated nologin noinherit;
    create role service_role nologin noinherit bypassrls;
  end if;
end
$$;

create schema extensions;
create schema auth;
create schema storage;
grant usage on schema public, extensions, auth, storage to anon, authenticated, service_role;

-- Supabase's default privileges on public (the RLS migration revokes them for anon/authenticated).
alter default privileges in schema public grant all on tables to anon, authenticated, service_role;
alter default privileges in schema public grant all on functions to anon, authenticated, service_role;

create table auth.users (
  id uuid primary key default gen_random_uuid(),
  phone text unique,
  email text,
  email_confirmed_at timestamptz,
  raw_user_meta_data jsonb not null default '{}',
  created_at timestamptz not null default now()
);

-- Same definition as Supabase: the JWT `sub` set per request by PostgREST.
create function auth.uid() returns uuid language sql stable as $$
  select coalesce(
    nullif(current_setting('request.jwt.claim.sub', true), ''),
    (nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'sub')
  )::uuid
$$;
grant execute on function auth.uid() to anon, authenticated, service_role;

create table storage.buckets (
  id text primary key,
  name text not null unique,
  public boolean default false,
  file_size_limit bigint,
  allowed_mime_types text[]
);

create table storage.objects (
  id uuid primary key default gen_random_uuid(),
  bucket_id text references storage.buckets (id),
  name text,
  owner_id text,
  metadata jsonb,
  created_at timestamptz default now(),
  unique (bucket_id, name)
);
alter table storage.objects enable row level security;
grant select, insert, update, delete on storage.objects to authenticated, service_role;
grant select on storage.buckets to authenticated, service_role;

do $$
begin
  execute format('alter database %I set search_path = "$user", public, extensions', current_database());
end
$$;
