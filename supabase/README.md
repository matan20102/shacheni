# Shacheni — database (Supabase / PostgreSQL)

Implements the schema in [`docs/PRD-data-security-architecture.md`](../docs/PRD-data-security-architecture.md) §9 and §12.
Schema changes happen **only** through the migration files here, never by editing in the dashboard.

| File | Contents |
|---|---|
| `migrations/…100000_core_schema.sql` | enums, 26 tables, composite FKs (BR-J4), double-booking exclusion constraints (BR-D1/D2), unique rules, indexes |
| `migrations/…100100_helpers_and_triggers.sql` | `app.*` role helpers (`is_resident`, `is_building_admin`, …), triggers: self-review (BR-A6), assignment/listing guards, offer/rating validation, reputation, immutability, append-only, door-delivery proof (BR-E10), profile bootstrap |
| `migrations/…100200_rls.sql` | default-deny RLS, read-only grants (no client DML except own device tokens) |
| `migrations/…100300_storage.sql` | private buckets `avatars`, `delivery-proofs` + policies |
| `migrations/…100400_legal.sql` | legal TODO placeholders (5 types × he/en), `publish_legal_document`, `get_current_legal_documents` |
| `tests/schema_test.sql` | 83 checks: constraints, triggers, RLS per role (applicant / resident / other building / admin / anon), storage policies |

**Not built yet:** the write RPCs (`create_building`, `submit_membership_application`, …), the views (`public_profile_v`, admin views), `pg_cron` ticks, Edge Functions. They come flow by flow, starting with sign-in and joining a building.

## Run the tests locally (no Docker)

Needs any local PostgreSQL 17 server. `tests/local/supabase_stub.sql` fakes the Supabase pieces the migrations use (`auth.users`, `auth.uid()`, `storage.*`, roles):

```bash
PGBIN="/path/to/pgsql/bin" PGPORT=5432 supabase/tests/local/run_tests.sh
```

The script rebuilds a throwaway `shacheni_test` database from the migrations, then runs the tests (all inside a rolled-back transaction).

## Conventions

- Errors that the app must handle are raised with a stable code as the message (`SELF_REVIEW_FORBIDDEN`, `NOT_SPACE_HOLDER`, `PROOF_REQUIRED`, …). Constraint errors use SQLSTATE: `23P01` = slot taken, `23505` = duplicate.
- Every function: `security definer` only when needed, `set search_path = ''`, schema-qualified names.
- The app ships only the **publishable** key. The service-role key and DB password never go in the app or in git.
