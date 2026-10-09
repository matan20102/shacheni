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
| `migrations/…090000_sign_in.sql` | Google sign-in: profile name from Google, consent gate (`my_pending_legal_documents`, `accept_legal_documents`), `update_my_profile` (phone → +972, unique) |
| `migrations/…120000_membership_withdrawn.sql` | adds the `withdrawn` status (own file: a new enum value can't be used in the transaction that adds it) |
| `migrations/…120100_join_flow.sql` | `get_my_access` (what the app routes on), building setup (`create_building`, `set_building_units`, `accept_building_agreement_and_activate`), join (`resolve_join_code` rate-limited, `submit_membership_application`, `withdraw_application`, `respond_to_info_request`), admin (`admin_list_applications`, `admin_decide_membership`, `admin_get_building`, `platform_list_buildings`) |
| `migrations/…150000_join_search.sql` | find a building by name / address (F37): `search_buildings` (30/hour), `get_join_info`; join-code attempts and searches counted separately |
| `migrations/…160000_membership_left.sql`, `…160100_leave_building.sql` | `leave_building` (moving out): blocked during active bookings/deliveries/payments; ends parking assignments, cancels open listings/requests/offers; then the user can join another building |
| `tests/schema_test.sql` | 83 checks: constraints, triggers, RLS per role (applicant / resident / other building / admin / anon), storage policies |
| `tests/sign_in_test.sql` | 26 checks for the sign-in migration |
| `tests/join_search_test.sql` | 16 checks for building search |
| `tests/leave_building_test.sql` | 20 checks: blocked while busy, clean-up, move to another building, rejoin |
| `tests/join_flow_test.sql` | 61 checks: setup → join code (incl. rate limit) → application → info request → approval with parking → withdraw / reject / re-apply → self-approval (BR-A6) |
| `tests/kit.sql`, `tests/report.sql` | shared assertion helpers (included by every `*_test.sql`) |

**Not built yet:** the parking / package / payment RPCs, the views (`public_profile_v`, admin views), `pg_cron` ticks, Edge Functions. They come flow by flow; next is parking.

## Run the tests locally (no Docker)

Needs any local PostgreSQL 17 server. `tests/local/supabase_stub.sql` fakes the Supabase pieces the migrations use (`auth.users`, `auth.uid()`, `storage.*`, roles):

```bash
PGBIN="/path/to/pgsql/bin" PGPORT=5432 supabase/tests/local/run_tests.sh
```

The script rebuilds a throwaway `shacheni_test` database from the migrations, then runs every `tests/*_test.sql` (each inside a rolled-back transaction).

## Conventions

- Errors that the app must handle are raised with a stable code as the message (`SELF_REVIEW_FORBIDDEN`, `NOT_SPACE_HOLDER`, `PROOF_REQUIRED`, …). Constraint errors use SQLSTATE: `23P01` = slot taken, `23505` = duplicate.
- Every function: `security definer` only when needed, `set search_path = ''`, schema-qualified names.
- The app ships only the **publishable** key. The service-role key and DB password never go in the app or in git.

## Deploy to the dev project

Linked once with `supabase link --project-ref ncsxflfhnezkzxavkdhp`. After adding a migration:

```powershell
$env:Path = "C:\src\supabase;" + $env:Path
supabase db push --dry-run   # lists the migrations that are not applied yet
supabase db push
```

## One-time: make yourself the platform admin

After your first Google sign-in, in the dashboard's SQL Editor (replace the email):

```sql
insert into public.platform_admin (user_id)
select id from auth.users where email = 'you@gmail.com';
```
