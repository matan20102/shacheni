# Shacheni (שכני) — Database Schema, Security Model & Technical Architecture

Part of the [PRD](PRD.md) (v0.3). Defines the multi-building data model, the zero-trust security model, the **backend recommendation and Supabase setup**, and the Flutter architecture. Rule IDs (`BR-xx`) refer to PRD §10; flow IDs (`F01…`) to the [flows document](PRD-flows-screens.md).

**v0.3 summary of changes here:** one platform admin and one building admin (you), `allow_admin_self_review` switch, no admin-appointment tables/RPCs, building lifecycle `draft → active ⇄ suspended`, new `delivery_proof` table + private Storage bucket + retention, legal placeholders, backend evaluation and environment/backup design, configuration & domain independence, individual Apple account ownership.

---

## Architecture at a glance

```
┌─────────────────────────────┐          ┌───────────────────────────────────────────────┐
│ Flutter app (iOS / Android) │  HTTPS   │ Supabase project (owned by you; dev + prod)   │
│  Riverpod · go_router       ├─────────►│  Auth (phone OTP, JWT)                        │
│  feature-first modules      │          │  Postgres  ── tables · RLS · RPC functions    │
│  Repositories (interfaces)  │◄─────────┤             · triggers · exclusion constraints │
│  l10n: he (RTL) / en (LTR)  │ realtime │             · pg_cron "tick"                   │
│  firebase_messaging (FCM)   │          │  Storage: avatars · delivery-proofs (private) │
└──────────────▲──────────────┘          │  Edge Functions: send-push · purge-proofs     │
               │ push                    │  (+ future payment adapters)                  │
               │                         └───────────────────┬───────────────────────────┘
        ┌──────┴───────┐                                     │ pg_net
        │ FCM / APNs   │◄────────────────────────────────────┘
        └──────────────┘
```

**Principles**
1. **The database is the rules engine.** Clients never write state, money, ratings or roles. Every change is an RPC that derives the actor from `auth.uid()`, re-checks guards, and writes in one transaction.
2. **Constraints beat code.** Exclusion constraints, partial unique indexes, composite foreign keys and triggers make dangerous states unrepresentable, even for a hacked client.
3. **Multi-building by construction.** Every community row carries `building_id`; child tables reference parents with composite FKs `(id, building_id)`; RLS scopes everything by building. The UI shows one building during the pilot.
4. **Roles come from tables, not JWT claims**, so revocation (disable, admin removal) takes effect on the very next request.
5. **Roles stay separate even when one person holds them.** In the pilot you are the platform admin *and* the only building admin; the code, views and RLS still treat them as two roles with different data access, so adding admins later is a data change, not a redesign. Self-review is an explicit audited switch (BR-A6), not a hole in the model.

---

## 9. Database schema (PostgreSQL / Supabase)

### 9.0 Conventions
- PK `uuid default gen_random_uuid()` (`profile.id` = `auth.users.id`). All timestamps `timestamptz`.
- `building_id uuid not null` on every community table; every parent referenced via composite FK `(parent_id, building_id)` (BR-J4). Parents therefore declare `unique (id, building_id)`.
- Money: `*_minor integer` (agorot), `currency text default 'ILS'`.
- Enums are Postgres enums. `transactions` is plural because `transaction` is reserved.
- Mutable tables have `created_at`, `updated_at` (trigger). Append-only tables have only `created_at`.
- Helper functions live in schema `app`; tables in `public`. Clients get **no direct DML** on any stateful table.

### 9.1 Entity overview

```
platform_admin ──(user)── profile 1──* building_membership *──1 building 1──* apartment
                              │            │ 1                    │ 1──* parking_space
                              │            │                      │ 1──* building_admin (user)
                              │            *                      │
                              │       membership_event
                              │
 building_membership 1──* parking_assignment *──1 parking_space
 parking_space 1──* parking_listing (assignment_id) 1──* parking_reservation
 profile 1──* delivery_request 1──1 delivery_secret ;  delivery_request 1──* delivery_offer
 delivery_request 1──0..1 delivery_proof (photo evidence of a door delivery)
 parking_reservation 1──1 transactions 1──1 delivery_request      (exactly one source per transaction)
 transactions 1──* payment 1──* payment_event
 transactions 1──* rating ; transactions 1──* dispute
 profile 1──* notification · device_token · legal_acceptance ; legal_document 1──* legal_acceptance
 audit_log (admin actions, contact reveals) · join_code_attempt (rate limiting)
```

### 9.2 Tables

#### Platform & building

**`platform_admin`** — authoritative list of platform administrators. **MVP: exactly one row (you)**, inserted once by SQL; there is no RPC, screen or invitation to add more (post-MVP backlog). Written only by SQL/migration.
| Field | Type | Notes |
|---|---|---|
| user_id | uuid PK → profile | |
| granted_at | timestamptz | |

**`building`**
| Field | Type | Notes |
|---|---|---|
| id | uuid PK | unique (id) for composite FKs |
| name | text not null | |
| address | text not null | full address; `unique (lower(name), lower(address))` |
| city | text | |
| timezone | text default 'Asia/Jerusalem' | |
| declared_apartment_count | int not null check (>0) | entered at creation; must equal active apartment count to activate (BR-A2) |
| declared_parking_count | int not null check (≥0) | must equal active space count to activate |
| status | enum `draft`/`active`/`suspended` | §11.1 (no committee/second-party step) |
| join_code | text unique null | 8 chars from an unambiguous alphabet; issued at activation; rotatable; stored hashed-comparable (plain is acceptable: low-sensitivity, rate-limited) |
| join_code_rotated_at | timestamptz | |
| settings | jsonb | **[CONFIG] defaults** (below) |
| created_by | uuid → profile | platform admin (you) |
| created_at / activated_at / updated_at | timestamptz | |
`settings` defaults: `max_listing_days 90 · max_price_minor 200000 · max_reward_minor 10000 · declared_value_cap_minor 100000 · request_response_hours 12 · confirm_window_minutes 120 · confirm_cutoff_before_start_minutes 15 · late_cancel_hours_short 1 · late_cancel_hours_long 24 · code_max_attempts 5 · code_lock_minutes 15 · code_regen_max 3 · arrival_ping_cooldown_minutes 10 · door_delivery_autoconfirm_hours 24 · proof_retention_days 30 · proof_max_bytes 3145728 · proof_max_dimension_px 1600 · proof_max_age_minutes 30 · allow_admin_self_review true · payer_reminder_hours [24,72] · payee_silence_autosettle_hours 72 · unpaid_expiry_days 7 · payment_not_received_dispute_threshold 3 · dispute_window_days 7 · dispute_sla_hours 48 · rating_window_days 14 · max_residents_per_apartment 6 · join_attempts_per_hour 10 · overdue_auto_dispute_hours 24 · payment_methods ['mock'] · optional_push_daily_cap 3`. Editable only by the platform admin (you). `allow_admin_self_review` defaults to `true` for the pilot (BR-A6) and is the single switch to flip when more admins exist.

**`apartment`**
| Field | Type | Notes |
|---|---|---|
| id | uuid PK | |
| building_id | uuid FK → building | |
| number | text not null | label shown to users ("1204", "12A") |
| floor | int null | |
| is_active | bool default true | deactivate instead of delete (BR-A4) |
| created_at | timestamptz | |
Constraints: `unique (building_id, number)`, `unique (id, building_id)`.

**`parking_space`**
| Field | Type | Notes |
|---|---|---|
| id | uuid PK | |
| building_id | uuid FK | |
| label | text not null | "P03" |
| level | text null | "-2" |
| notes | text null | location hints; **never store gate codes** |
| is_active | bool default true | |
Constraints: `unique (building_id, label)`, `unique (id, building_id)`. Note: a space has **no owner column** — ownership is expressed only through `parking_assignment`.

**`building_admin`** — building-scoped administrator role. **MVP: exactly one row per building, created automatically by `create_building` for its creator (you).** The table and every helper function already support many admins per building, but no appointment/invitation feature exists yet.
| Field | Type | Notes |
|---|---|---|
| id | uuid PK | |
| building_id / user_id | FK | |
| granted_by | uuid → profile | the platform admin (self, for the creator row) |
| granted_at | timestamptz | |
| revoked_at / revoked_by | null | |
Unique: `(building_id, user_id) where revoked_at is null`. Admin powers also require the user to have accepted the current building agreement (`app.is_building_admin`).

#### Users & membership

**`profile`** — global identity (auth identity lives in `auth.users`).
| Field | Type | Notes |
|---|---|---|
| id | uuid PK = auth.users.id | |
| full_name | text not null | |
| phone_e164 | text unique | copied from auth; read only by self and (via views) admins of buildings the user applied to |
| avatar_url | text null | Storage path `avatars/{user_id}.jpg` |
| locale | text default 'he' check in ('he','en') | |
| prefs | jsonb | `{notify_new_pickup:true, notify_new_parking:true}` |
| deleted_at | timestamptz null | anonymization |
| created_at / updated_at | | |
No email column (decision P1). No role column: roles are in `platform_admin` / `building_admin`.

**`building_membership`** — *the resident request and, once approved, the verified resident.* Reputation lives here (building-scoped).
| Field | Type | Notes |
|---|---|---|
| id | uuid PK | |
| building_id | uuid FK | |
| user_id | uuid FK → profile | |
| apartment_id | uuid not null | FK `(apartment_id, building_id)` → apartment |
| status | enum `pending`/`info_requested`/`approved`/`rejected`/`disabled` | §11.2 |
| applicant_note | text null | |
| info_request_message / info_response | text null | latest exchange (history in `membership_event`) |
| status_reason | text null | rejection/disable reason |
| flags | jsonb | admin hints, e.g. `{apartment_residents: 2}` computed at submit |
| reviewed_by | uuid null → profile | trigger: `reviewed_by ≠ user_id` **unless** `settings.allow_admin_self_review` and reviewer holds the building-admin role; self-reviews set `flags.self_review = true` (BR-A6) |
| reviewed_at / approved_at / disabled_at | timestamptz null | |
| rating_avg | numeric(3,2) null | trigger-maintained |
| rating_count / completed_count | int default 0 | trigger-maintained |
| late_cancel_count / provider_cancel_count / requester_cancel_count / helper_cancel_count / unpaid_count | int default 0 | reliability counters (admin-visible only) |
| created_at / updated_at | | |
Constraints: `unique (building_id, user_id)`; `unique (id, building_id)`; `unique (id, apartment_id)`; **MVP:** `unique (user_id) where status in ('pending','info_requested','approved')` (one live membership per user; drop when multi-building UI ships).

**`membership_event`** (append-only) — `id`, `building_id`, `membership_id`, `actor_id`, `type` (`submitted`/`info_requested`/`info_provided`/`approved`/`rejected`/`disabled`/`enabled`/`apartment_change`), `message`, `created_at`. Gives admins a verification history.

#### Parking ownership

**`parking_assignment`** — *the only link between a resident and a parking space*; models both the **request** and the **ownership**.
| Field | Type | Notes |
|---|---|---|
| id | uuid PK | `unique (id, building_id)` |
| building_id | uuid FK | |
| parking_space_id | uuid | FK `(parking_space_id, building_id)` |
| membership_id | uuid | FK `(membership_id, building_id)` |
| apartment_id | uuid | FK `(membership_id, apartment_id)` → the holder's apartment (denormalized, can't drift) |
| status | enum `requested`/`active`/`rejected`/`withdrawn`/`ended` | §11.3 |
| requested_note | text null | |
| requested_at | timestamptz | |
| reviewed_by / reviewed_at / review_note | | reviewer ≠ requesting user unless BR-A6 self-review is allowed (then flagged `self_review`) |
| started_at / ended_at / ended_by / end_reason | | |
| flags | jsonb | e.g. `{currently_assigned_to_other:true}` shown to admin only |
Indexes/constraints:
```sql
-- at most ONE active holder per space; spaces may be unassigned (no row) (BR-C3)
create unique index one_active_assignment_per_space
  on parking_assignment (parking_space_id) where status = 'active';
-- no duplicate open request/active pair
create unique index one_open_assignment_per_pair
  on parking_assignment (membership_id, parking_space_id) where status in ('requested','active');
```
Cases: apartment with no parking → no rows; one or many spaces → rows; unassigned space → no active row; reassignment → old row `ended`, new row `active` (full history kept).

#### Parking

**`parking_listing`**
| Field | Type | Notes |
|---|---|---|
| id | uuid PK | `unique (id, building_id)`, `unique (id, parking_space_id)` |
| building_id | FK | |
| parking_space_id | uuid | FK `(parking_space_id, building_id)` |
| assignment_id | uuid | FK `(assignment_id, building_id)`; trigger verifies it is the owner's **active** assignment of that space (BR-C6) |
| owner_id | uuid → profile | |
| start_at / end_at | timestamptz | `check (end_at > start_at)`, duration ≤ 90 days |
| price_minor | int | `check (price_minor >= 0)` |
| currency | text | 'ILS' |
| description | text null | ≤ 200 |
| booking_mode | enum `request`/`instant` | default `request` |
| status | enum `available`/`reserved`/`active`/`completed`/`cancelled`/`expired` | §11.4 |
| cancelled_at / cancel_reason / created_at / updated_at | | |

**`parking_reservation`**
| Field | Type | Notes |
|---|---|---|
| id | uuid PK | `unique (id, building_id)` |
| building_id | FK | |
| listing_id | uuid | FK `(listing_id, building_id)` **and** `(listing_id, parking_space_id)` → listing (so the denormalized space cannot lie) |
| parking_space_id | uuid | for the exclusion constraint |
| owner_id / requester_id | uuid → profile | `check (owner_id <> requester_id)` |
| start_at / end_at | timestamptz | MVP = listing window (BR-D5); own columns allow partial booking later |
| price_minor | int | snapshot |
| status | enum `requested`/`accepted`/`confirmed`/`active`/`completed`/`cancelled`/`declined`/`expired` | §11.5 |
| vehicle_plate / requester_note | text null | |
| decline_reason / cancel_reason | text null | |
| cancelled_by | uuid null | |
| expires_at | timestamptz null | response deadline (`requested`) or confirm deadline (`accepted`) |
| requested_at, accepted_at, confirmed_at, started_at, completed_at, cancelled_at | timestamptz null | |

#### Packages

**`delivery_request`**
| Field | Type | Notes |
|---|---|---|
| id | uuid PK | `unique (id, building_id)` |
| building_id | FK | |
| requester_id | uuid → profile | |
| pickup_location | text | free text |
| package_description | text | |
| notes | text null | |
| handoff_place | text default 'Building lobby' | localized default text is client-side; stored value is user text |
| deadline_at | timestamptz | ≥ created + 30 min; ≤ 7 days |
| reward_minor / currency | int / text | `check (reward_minor between 0 and 10000)` [CONFIG] |
| door_delivery_allowed | bool default false | requester authorizes "leave near my apartment door" at creation (BR-E6); **off by default** |
| door_delivery_approved_at | timestamptz null | requester authorized it later, in-app (e.g., when the helper arrives) |
| arrived_at | timestamptz null | last arrival ping (cooldown) |
| status | enum `open`/`offer_received`/`accepted`/`collected`/`delivered`/`completed`/`cancelled`/`expired`/`disputed` | §11.6 |
| accepted_offer_id | uuid null | FK `(accepted_offer_id, building_id)` |
| handoff_method | enum null `code`/`door_photo`/`admin` | how it was handed over; `door_photo` only if a `delivery_proof` exists |
| delivery_note | text null | optional helper note for a door delivery |
| collected_at / delivered_at / completed_at / cancelled_at | timestamptz null | `delivered_at` = **delivery confirmation** timestamp |
| autoconfirm_at | timestamptz null | `delivered_at + 24 h` for door deliveries |
| cancelled_by / cancel_reason / created_at / updated_at | | |

**`delivery_secret`** (1:1; **separate so RLS and column exposure can be strict**)
| Field | Type | Notes |
|---|---|---|
| request_id | uuid PK | FK `(request_id, building_id)` |
| building_id | uuid | |
| pickup_reference | text null | order number / pickup code — visible only to requester and **accepted** helper (via RPC) |
| handoff_code | text null | 4 digits, generated at acceptance; visible **only** to requester; verified server-side only |
| failed_attempts | int default 0 | |
| lock_cycles | int default 0 | 3 → admin flag |
| locked_until | timestamptz null | |
| regen_count | int default 0 | ≤ 3 |

**`delivery_proof`** (append-only; photo evidence of a **door delivery**, BR-E10)
| Field | Type | Notes |
|---|---|---|
| id | uuid PK | |
| building_id | uuid | |
| request_id | uuid | FK `(request_id, building_id)`; **`unique (request_id)`** — exactly one proof per request |
| uploaded_by | uuid → profile | **the user who uploaded the proof** — must be the accepted helper (trigger) |
| storage_path | text | `delivery-proofs/{building_id}/{request_id}/{uuid}.jpg` in the private bucket |
| mime_type / size_bytes / sha256 | text / int / text | JPEG only, ≤ 3 MB (config); hash for integrity |
| captured_at_client | timestamptz null | device clock (informational) |
| uploaded_at | timestamptz default now() | **server timestamp = the authoritative time of the proof** |
| note | text null | optional helper note |
| purged_at | timestamptz null | set by the retention job when the image file is deleted; the row stays |
Created only by `submit_door_delivery` in the same transaction that sets the request to `delivered` (`handoff_method = door_photo`, `delivered_at = now()`). Trigger `guard_delivery_proof` verifies: uploader is the accepted helper; request status `collected`; `door_delivery_allowed` or `door_delivery_approved_at` is set; the Storage object exists, is `image/jpeg`, within size limit and was uploaded within `proof_max_age_minutes`.

**`delivery_offer`**
| Field | Type | Notes |
|---|---|---|
| id | uuid PK | `unique (id, building_id)` |
| building_id | FK | |
| request_id | uuid | FK `(request_id, building_id)` |
| helper_id | uuid → profile | trigger: helper ≠ requester, approved resident |
| message | text null | ≤ 140 |
| planned_pickup_at | timestamptz null | |
| status | enum `pending`/`accepted`/`rejected`/`withdrawn`/`expired` | §11.7 |
| created_at / responded_at | | |
Constraints: `unique (request_id, helper_id) where status in ('pending','accepted')`; **`unique (request_id) where status='accepted'`** (BR-E3).

#### Transactions & payments

**`transactions`** — the deal and its settlement; history, ratings, disputes and payments hang off it.
| Field | Type | Notes |
|---|---|---|
| id | uuid PK | `unique (id, building_id)` |
| building_id | FK | |
| type | enum `parking`/`delivery` | |
| parking_reservation_id / delivery_request_id | uuid null, **unique** | FK `(…, building_id)`; `check` exactly one set, matching `type` |
| payer_id / payee_id | uuid → profile | requester / provider (BR-F3); `check (payer_id <> payee_id)` |
| amount_minor / currency | int / text | immutable from creation |
| platform_fee_minor | int default 0 | reserved |
| status | enum `in_progress`/`awaiting_settlement`/`completed`/`cancelled`/`disputed` | §11.9 |
| service_completed_at | timestamptz null | |
| completed_at / cancelled_at | timestamptz null | |
| cancel_reason | text null | |
| created_at / updated_at | | |
Immutable once `completed`/`cancelled` (trigger, BR-J1).

**`payment`** — mock payment record (one per charge; refunds are separate rows).
| Field | Type | Notes |
|---|---|---|
| id | uuid PK | |
| building_id | FK | |
| transaction_id | uuid | FK `(transaction_id, building_id)` |
| kind | enum `charge`/`refund` | |
| related_payment_id | uuid null | refund → the settled charge |
| method | text default 'mock' | method id from the provider registry (BR-F9) |
| payer_id / payee_id | uuid → profile | for refunds the roles are reversed |
| amount_minor / currency | | |
| status | enum `pending`/`payer_confirmed`/`settled`/`cancelled` | §11.8 — **no hold/authorize states in MVP** |
| settled_via | enum null `payee`/`auto`/`admin` | |
| cancel_reason | enum null `waived`/`expired_unpaid`/`transaction_cancelled`/`admin` | |
| payer_confirmed_at / settled_at / cancelled_at | timestamptz null | |
| not_received_count | int default 0 | |
| provider_ref | text null | for future providers |
| created_at / updated_at | | |
Immutable once `settled` or `cancelled`. One `charge` per transaction (`unique (transaction_id) where kind='charge'`).

**`payment_event`** (append-only) — `id`, `payment_id`, `type` (`created`/`payer_marked_paid`/`payee_confirmed`/`payee_not_received`/`auto_settled`/`waived`/`expired_unpaid`/`admin_decision`/`cancelled`/`refund_created`), `actor_id`, `data jsonb`, `created_at`.

**`dispute`**
| Field | Type | Notes |
|---|---|---|
| id | uuid PK | |
| building_id / transaction_id | FK | |
| opened_by | uuid → profile | a party |
| reason | enum `space_unavailable`/`space_occupied`/`wrong_space`/`damage`/`not_delivered`/`damaged_package`/`wrong_item`/`helper_no_show`/`requester_unreachable`/`payment_not_received`/`payment_dispute`/`other` | |
| description | text | required |
| counterparty_response | text null | one reply |
| status | enum `open`/`under_review`/`resolved` | |
| outcome | enum null `payment_settled`/`payment_cancelled`/`no_action`/`warning` | BR-H3 |
| service_delivered | bool null | admin's decision → transaction `completed` vs `cancelled` |
| resolved_by | uuid null | not a party (BR-A6); admin of the building |
| admin_note | text null | required on resolve |
| post_completion | bool | opened after `completed` |
| created_at / resolved_at | | |

#### Reputation, notifications, legal, audit

**`rating`** (append-only)
| Field | Type | Notes |
|---|---|---|
| id | uuid PK | |
| building_id / transaction_id | FK | |
| rater_id / ratee_id | uuid → profile | trigger: exactly the transaction's two parties, rater ≠ ratee |
| stars | smallint | check 1..5 |
| comment | text null | ≤ 280 |
| hidden | bool default false | admin moderation (only mutable column, via RPC) |
| created_at | | |
`unique (transaction_id, rater_id)`. Visible per BR-I3 via view `visible_rating`.

**`notification`**
| Field | Type | Notes |
|---|---|---|
| id | uuid PK | |
| building_id (null for pre-membership) / user_id | FK | |
| type | text | catalog code, e.g. `parking.request_received` (N20) |
| params | jsonb | template parameters (names, times, amounts) — **no secrets** |
| route / entity_id | text / uuid | deep link target |
| dedupe_key | text | `unique (user_id, dedupe_key)` |
| read_at / push_sent_at / created_at | | |
Stores **type + params**, not rendered text, so the same record renders in either language.

**`device_token`** — `id`, `user_id`, `token` unique, `platform`, `locale`, `last_seen_at`.

**`legal_document`** — versioned legal text, stored separately from code.
| Field | Type | Notes |
|---|---|---|
| id | uuid PK | |
| type | enum `terms_of_service`/`privacy_policy`/`community_rules`/`resident_declaration`/`building_agreement` | |
| version | text | e.g. `2026-11-01` or `1.0`; **the same version label exists for `he` and `en`** |
| locale | text | `he`/`en` |
| title / body_md | text | markdown |
| content_hash | text | sha-256 for evidence |
| effective_at | timestamptz | |
| is_current | bool | `unique (type, locale) where is_current` |
| created_by / created_at | | platform admin (you) |
**Placeholders (BR-L5):** the seed migration inserts, for each of the 5 types and both locales, one current row with `version = '0.0-todo'`, a title naming the document, and `body_md = 'TODO — legal text to be provided by the owner.'`. **No legal wording is written by engineering.** The real text is published later by the owner through a privileged SQL function `publish_legal_document(type, version, locale, title, body_md)` (callable only by `postgres`/service role, from the Supabase SQL editor or a migration) — it inserts the new version, flips `is_current`, and thereby triggers re-acceptance everywhere. Which language is binding is part of the owner's legal text (open O3).

**`legal_acceptance`** (append-only)
| Field | Type | Notes |
|---|---|---|
| id | uuid PK | |
| user_id | uuid → profile | |
| building_id | uuid null | set for `building_agreement`, `community_rules`, `resident_declaration` |
| document_type / document_version | | what was accepted (**agreement type + version**) |
| document_id | uuid → legal_document | the exact text/locale shown |
| locale | text | |
| accepted_at | timestamptz default now() | **date/time of acceptance** |
| details | jsonb | for declarations: the confirmed items, e.g. `{accurate_info:true,is_resident:true,apartment_correct:true,parking_correct:true,rules_understood:true}` |
| app_version | text | |
Unique: `(user_id, coalesce(building_id, '0000…'), document_type, document_version)`. A user "has accepted current" if a row exists for the current version of the type — so a new version (even replacing the TODO placeholder) means nobody has accepted it yet and the **re-acceptance gate** (S04; admin: A02) appears on the next app start. Stores exactly what was required: **user, agreement type, agreement version, acceptance date/time**.

**`audit_log`** (append-only) — `id`, `building_id null`, `actor_id`, `self_review bool default false` (true when BR-A6 allowed a self-review), `action` (`create_building`, `approve_membership`, `reject_membership`, `request_info`, `disable_member`, `approve_assignment`, `end_assignment`, `resolve_dispute`, `remove_listing`, `contact_reveal`, `view_delivery_proof`, `settings_change`, `activate_building` …), `target_type`, `target_id`, `note`, `created_at`.

**`join_code_attempt`** — `id`, `user_id`, `succeeded`, `created_at` (rate limiting BR-B6).

### 9.3 Critical constraints (double-booking and integrity)

```sql
create extension if not exists btree_gist;

-- BR-D2: no two live listings of one space overlap.
alter table parking_listing add constraint no_listing_overlap
  exclude using gist (parking_space_id with =, tstzrange(start_at, end_at, '[)') with &&)
  where (status in ('available','reserved','active'));

-- BR-D1: no two committed reservations of one space overlap.
-- The database rejects it even if a modified client bypasses every UI check.
alter table parking_reservation add constraint no_reservation_overlap
  exclude using gist (parking_space_id with =, tstzrange(start_at, end_at, '[)') with &&)
  where (status in ('accepted','confirmed','active','completed'));
```
`'[)'` allows back-to-back bookings (10:00–14:00 then 14:00–18:00) but rejects 12:00–15:00 against 10:00–14:00. Pending `requested` rows are deliberately outside the constraint (several neighbors may ask; the owner picks one — BR-D7). Two simultaneous accepts: the second fails with SQLSTATE `23P01`, mapped to `SLOT_TAKEN`.

Other key constraints (summary): one active assignment per space (§9.2); one live membership per user (MVP); one accepted offer per request; one transaction per reservation/request; exactly-one-source check on `transactions`; one rating per rater per transaction; one `charge` per transaction; composite FKs everywhere (BR-J4); unique `(building_id, number|label)`.

### 9.4 Indexes
`parking_listing (building_id, status, start_at)` · `parking_reservation (listing_id)`, `(requester_id, status)`, `(owner_id, status)`, `(status, expires_at)` · `delivery_request (building_id, status, deadline_at)` · `delivery_offer (request_id)`, `(helper_id)` · `transactions (payer_id)`, `(payee_id)`, `(building_id, status)` · `payment (transaction_id)`, `(status)` · `building_membership (building_id, status)` · `parking_assignment (membership_id)`, `(building_id, status)` · `notification (user_id, created_at desc)`, `(user_id) where read_at is null` · `legal_acceptance (user_id, document_type)` · `audit_log (building_id, created_at desc)`.

### 9.5 Triggers

| Trigger | Purpose |
|---|---|
| `set_updated_at` | maintain `updated_at` |
| `guard_self_review` | for membership decisions, assignment decisions and dispute resolution: reviewer must hold the building-admin role; if reviewer = subject/party, allow **only** when `settings.allow_admin_self_review = true` and set `self_review` on the row + audit entry; otherwise raise `SELF_REVIEW_FORBIDDEN` (BR-A6) |
| `guard_delivery_proof` | BR-E10 checks (uploader = accepted helper, state `collected`, door delivery authorized, object exists/size/type/age) |
| `guard_assignment_approval` | approval only if membership `approved`, space active, building active |
| `guard_listing_assignment` | listing owner = holder of the active assignment for the space (BR-C6) |
| `guard_transaction_immutable` | BR-J1 |
| `guard_payment_immutable` | `settled`/`cancelled` payments frozen |
| `append_only` | `payment_event`, `legal_acceptance`, `audit_log`, `membership_event`, `rating` (except `hidden`), `delivery_proof` (except system-set `purged_at`) |
| `validate_rating` | parties, completed, not disputed, window open, rater≠ratee |
| `update_reputation` | recompute `rating_avg/count`, `completed_count` |
| `validate_offer` | helper ≠ requester, approved resident, request open |

### 9.6 Functions, views, RLS

#### Helper functions (schema `app`, `security definer`, `stable`, `set search_path = ''`)
```sql
app.is_platform_admin()      -- exists platform_admin row for auth.uid()
app.is_resident(b uuid)      -- approved membership in b AND building.status = 'active'
app.is_building_admin(b uuid)-- active building_admin row AND accepted current building_agreement for b
app.my_building_ids()        -- buildings where the caller is a resident
app.has_accepted_current(type, building uuid default null)
app.notify(user, type, params, route, entity, dedupe)   -- inserts notification honoring prefs/caps/quiet hours
app.apply_payment_event(payment_id, event, actor)       -- the ONLY writer of payment state (BR-F9)
app.recompute_transaction(transaction_id)               -- derives in_progress/awaiting_settlement/completed
app.audit(building, action, target_type, target_id, note)
```

#### RPC functions (the only write path)
All are `security definer`, `set search_path = ''`, `revoke execute … from public; grant execute … to authenticated` (except where noted), take the actor from `auth.uid()` and return the new row(s) or a stable error code.

| Group | RPC | Caller | Checks / effect |
|---|---|---|---|
| Legal | `get_current_legal_documents(types, locale)` | **anon + authenticated** | public text (needed before login) |
| | `accept_legal_documents(items)` | user | records acceptance for *current* versions only |
| Platform | `create_building(name, address, city, apt_count, parking_count)` | platform admin | BR-A1; creates the building in `draft` **and the creator's `building_admin` row**; audit |
| | `update_building(id, …)`, `set_building_status(id, status, reason)`, `update_building_settings(id, patch)` | platform admin | suspend/reactivate; settings incl. `allow_admin_self_review` |
| | *(not in MVP: appoint/revoke admins, add platform admins)* | — | post-MVP backlog |
| Setup | `bulk_upsert_apartments(building, rows)` / `bulk_upsert_parking_spaces(building, rows)` | platform/building admin | uniqueness; preview-then-commit |
| | `set_apartment_active` / `set_space_active` | admin | BR-A4 |
| | `accept_building_agreement_and_activate(building)` | building admin | BR-A2 guards (lists, counts) + records `building_agreement` acceptance + issues join code + `draft → active` in one transaction |
| | `rotate_join_code(building)` | building admin | |
| Join | `resolve_join_code(code)` | user (ToS accepted) | BR-B6 rate limit; returns building name/address + active apartments + active space labels |
| | `submit_membership_application(building, apartment, space_ids[], note, declarations)` | user | BR-B1,B2,B4; creates membership + `requested` assignments; notifies admins |
| | `respond_to_info_request(membership, text)` / `withdraw_application` | applicant | |
| Admin members | `admin_decide_membership(id, decision, note, parking_decisions[])` | building admin | approve/reject/request_info; BR-A6 |
| | `admin_set_membership_status(id, disable\|enable, reason)` | building admin | BR-B7 |
| Assignment | `request_parking_assignment(space, note)` / `withdraw_assignment_request(id)` | resident | flag if currently assigned (BR-C4) |
| | `admin_decide_assignment(id, approve\|reject, note)` | building admin | BR-C2 |
| | `admin_end_parking_assignment(id, cancel_future_reservations)` / `admin_reassign_parking_space(space, to_membership, cancel_future_reservations)` | building admin | BR-C5 |
| Parking | `create_parking_listing(space, start, end, price, desc, mode)` / `cancel_parking_listing(id)` | holder | BR-C6, D2–D4, D8 |
| | `search_parking(start, end, include_all)` | resident | |
| | `request_parking(listing, plate, note)` | resident | request or instant→confirmed (BR-D10) |
| | `respond_to_reservation(id, accept, reason)` | owner | BR-D7 |
| | `confirm_reservation(id)` | requester | creates transaction + payment |
| | `cancel_reservation(id, reason)` | party | §10-G |
| Packages | `create_delivery_request(…)` (+ secret row) / `cancel_delivery_request(id, reason)` | requester | BR-E1, E8 |
| | `list_open_delivery_requests()` | resident | public columns only |
| | `make_delivery_offer(request, message, planned_at)` / `withdraw_offer(id)` | helper | BR-E2 |
| | `respond_to_offer(offer, accept)` | requester | generates code, creates transaction + payment, rejects others |
| | `mark_collected(request)` / `notify_arrival(request)` | helper | cooldown |
| | `confirm_handoff(request, code)` | helper | BR-E5; lock logic; completes service |
| | `allow_door_delivery(request)` | requester | sets `door_delivery_approved_at` (BR-E6); notifies helper |
| | `submit_door_delivery(request, storage_path, captured_at, note)` | accepted helper | BR-E6/E10: requires authorization + uploaded photo; inserts `delivery_proof`, sets `delivered` (`door_photo`, `delivered_at`, `autoconfirm_at`); **fails with `DOOR_DELIVERY_NOT_ALLOWED` / `PROOF_REQUIRED` / `PROOF_INVALID`** |
| | `get_delivery_proof_url(request)` | requester / uploader / building admin during an open dispute | returns a signed URL (≤ 5 min); audited |
| | `confirm_delivery(request)` | requester | confirms a door delivery (or auto-confirm by tick) |
| | `regenerate_handoff_code(request)` | requester | ≤ 3 |
| | `helper_withdraw(request)` | helper | |
| | `get_delivery_secrets(request)` | requester / accepted helper | returns only the caller's allowed fields |
| Payments | `payment_mark_paid(payment)` / `payment_confirm_received(payment)` / `payment_report_not_received(payment)` / `payment_waive(payment)` | payer / payee | thin wrappers over `app.apply_payment_event` |
| Contact | `get_counterparty_contact(transaction)` | party, live transaction | phone (+ apartment only for helper in delivery); audited (BR-K2/K3) |
| Reputation | `submit_rating(transaction, stars, comment)` | party | BR-I1–I3 |
| Disputes | `open_dispute(transaction, reason, desc)` / `respond_dispute(id, text)` | party | BR-H1/H2 |
| | `admin_open_dispute_review(id)` / `admin_resolve_dispute(id, outcome, service_delivered, note)` | building admin | BR-H3; BR-A6 |
| Misc | `register_device_token` / `mark_notifications_read` / `update_my_profile` / `delete_my_account` | user | |

#### Scheduled tick (`pg_cron`, every minute; each function idempotent)
`tick_parking` (expire requests/confirm windows, `confirmed→active`, `active→completed`, expire listings) · `tick_delivery` (expire requests, auto-confirm door deliveries after 24 h, overdue alerts, auto-dispute after 24 h) · `tick_payments` (reminders, 72 h auto-settle, 7-day unpaid expiry) · `tick_notifications` (N25, N26, N47 reminders, N50, N70 reminder, rating-window close) · `tick_disputes` (SLA flags) · `tick_retention` (daily: calls the `purge-proofs` Edge Function for proofs past `proof_retention_days` after request completion/dispute resolution; sets `purged_at`).

#### Views (all `security_barrier`; each filters by role inside the view)
| View | Audience | Exposes | Hides |
|---|---|---|---|
| `public_profile_v` | residents of the same building | membership id, user id, **first name + last initial**, avatar, rating_avg, rating_count, completed_count, member since | phone, apartment, full name, counters |
| `visible_rating_v` | residents | ratings visible per BR-I3 (rater first name + initial) | hidden ratings |
| `admin_application_v` | that building's admins | full name, phone, apartment number, requested spaces (labels), flags, status, history | email (none), everything outside applications |
| `admin_resident_v` | that building's admins | full name, phone, apartment, status, rating aggregates, reliability counters | transactions' secrets |
| `admin_listing_v`, `admin_delivery_v`, `admin_transaction_v` | that building's admins | public fields, statuses, parties' display names, amounts | `delivery_secret`, contact data, notes marked private |
| `admin_dispute_v` | that building's admins | the disputed transaction, statements, timeline, that transaction's rating comments, proof metadata (+ signed URL via RPC while the dispute is open) | unrelated data |
| `platform_stats_v` | platform admin | per-building counts only (apartments, residents, listings, transactions) | any personal data |
| `v_metrics_*` | building admin (own building), platform admin (aggregates) | §14 metrics | — |

#### RLS policies (default deny, RLS enabled on every table)
`authenticated` has **SELECT** on selected tables (subject to RLS) and **EXECUTE** on RPCs; **no INSERT/UPDATE/DELETE** on anything except `device_token` (own rows). `anon` has EXECUTE only on `get_current_legal_documents`.

| Table | SELECT policy | Notes |
|---|---|---|
| platform_admin | self row only | nobody can write via API |
| building | `app.is_platform_admin()` **or** user has any membership/admin row for it (limited columns via view for applicants: name, address, city) | `join_code` visible to admins/platform only |
| apartment, parking_space | residents of the building; building admins; platform admin (setup) | applicants get lists only through `resolve_join_code` |
| building_admin | platform admin; the admin themself | no write path in MVP except `create_building` |
| delivery_proof | requester; uploader; building admin only while a dispute on that request is open | metadata only; the image is in Storage (policies below) |
| profile | self only | others via views |
| building_membership | self row; building admins of that building | residents use `public_profile_v` |
| membership_event | the applicant (own); building admins | |
| parking_assignment | holder (own rows); building admins | other residents never see assignments |
| parking_listing | residents of the building (all statuses except others' `cancelled`) | |
| parking_reservation | requester, owner, building admin (via view) | |
| delivery_request | residents: `open`/`offer_received` (public columns); requester; accepted helper; building admin (view) | |
| delivery_secret | **no direct SELECT for anyone**; RPC `get_delivery_secrets` | |
| delivery_offer | requester of the request; the helper | |
| transactions, payment, payment_event | the two parties; building admin via `admin_transaction_v` | |
| dispute | parties; building admin | |
| rating | via `visible_rating_v` / own rows | |
| notification, device_token | owner | |
| legal_document | `is_current` rows readable by `anon` + `authenticated` (older versions: platform admin) | |
| legal_acceptance | own rows; building admin sees *that building's* acceptances (not other buildings) | |
| audit_log | platform admin (platform-wide); building admin (own building) | |
| join_code_attempt | none (RPC internal) | |

Example (pattern used everywhere):
```sql
alter table parking_listing enable row level security;
create policy listing_select on parking_listing for select to authenticated
  using ( app.is_resident(building_id)
          and (status <> 'cancelled' or owner_id = auth.uid()) );
-- no insert/update/delete policies: writes happen only inside security-definer RPCs
```

### 9.7 Seed / bootstrap
1. Migration creates schema, RLS, functions, storage buckets + policies, and the `legal_document` **TODO placeholders** (`0.0-todo`, text exactly `TODO — legal text to be provided by the owner.`, he + en, all 5 types). No legal wording is authored by engineering.
2. You (owner) sign in once with your phone; a one-time SQL statement inserts your `user_id` into `platform_admin` (the only platform admin).
3. In the app (Platform → Create building) you create the pilot building (you automatically become its building admin), define apartments and spaces, then **Accept agreement & activate** → building `active`. No second admin, committee step or appointment is required.
4. You apply to your own building as a resident (S05/S06) and approve yourself in A04 (allowed by `allow_admin_self_review`, audit-flagged). Same for your own parking space(s) in A08.
5. No building data is hard-coded in migrations; **dev/test data lives in `supabase/seed/` only**.

---

## 12. Security model

### 12.1 Zero-trust principles
1. The Flutter client is untrusted: it can be decompiled, modified, replayed. It only *renders* and *requests*.
2. Every permission is enforced server-side by (a) RLS, (b) RPC guards, (c) constraints/triggers — layered, so one failure doesn't open the system.
3. The actor is always `auth.uid()`; user ids are never accepted as parameters for "who is acting".
4. Parameters are untrusted: IDs are re-validated for building membership and state on every call; UUIDs are not secrets.
5. Roles are looked up from tables on each request (no stale JWT claims).
6. Deny by default; grant the minimum; log what matters.

### 12.2 Authentication
> **Changed by F36 (2026-10-09):** sign-in is **Google OAuth** via Supabase Auth, not phone OTP. The phone number is entered by the user (`update_my_profile`, normalized E.164, unique) and verified by the building admin, not by SMS. The email exists only in `auth.users`. Sign in with Apple must be added before iOS submission. The bullets below describe the original phone-OTP design.

- Supabase Auth, **phone + SMS OTP** (Israeli `+972` numbers in MVP); no passwords. OTP limits: 30 s resend cooldown, ≤ 5 sends/hour/number; provider route to Israel validated in Phase 8.
- Access token 1 h + refresh token in Keychain/Keystore (`flutter_secure_storage`). Sign-out revokes the refresh token; disabling a membership blocks data access immediately via RLS.
- App-store reviewers: a pre-approved demo account with a fixed test OTP in a demo building, disabled in prod after review.
- **No email collected.**

### 12.3 Authorization — roles & the three gates
Gate 1 *consent* (current ToS/Privacy accepted) → Gate 2 *membership* (`app.is_resident`) → Gate 3 *entity rules* (ownership/party/state). Admin functions additionally require `app.is_building_admin(building)` (including current building-agreement acceptance).

| Capability | Applicant | Resident | Building admin | Platform admin |
|---|---|---|---|---|
| Read legal docs; own application | ✓ | ✓ | ✓ | ✓ |
| Resolve a join code | ✓ (ToS accepted) | ✓ | ✓ | ✓ |
| Read building data (listings, requests, public profiles) | ✗ | ✓ own building | ✓ via admin views | ✗ (only aggregate stats) |
| Create building | ✗ | ✗ | ✗ | ✓ |
| Define apartments / spaces | ✗ | ✗ | ✓ own building | ✓ |
| Appoint/revoke admins, add platform admins | ✗ | ✗ | ✗ | ✗ — **not implemented in the MVP** (SQL only) |
| Decide applications / assignments / disable | ✗ | ✗ | ✓ — own request only while `allow_admin_self_review` (flagged) | ✗ (acts through the building-admin role) |
| Publish parking | ✗ | ✓ only with an active assignment | (as resident) | ✗ |
| Resolve disputes | ✗ | ✗ | ✓ — as a party only while `allow_admin_self_review` (flagged) | ✗ |
| View a delivery photo | ✗ | requester / uploading helper only | only while a dispute on that request is open | ✗ |

> In the pilot the **platform admin and the only building admin are the same person (you)**. The columns above remain separate in code and data so that a future split needs no redesign.

### 12.4 Admin data-access matrix (least privilege)
| Data | Platform admin | Building admin |
|---|---|---|
| Building record, apartments, space labels | ✓ | ✓ |
| Applicant/resident full name, **phone**, apartment | ✗ | ✓ own building (needed to verify; disclosed in Privacy Policy, BR-K5) |
| Requested/assigned parking | ✗ | ✓ |
| Ratings (aggregates) | ✗ (aggregate stats only) | ✓ aggregates; comments only inside a dispute |
| Listings, package requests (public fields + status) | ✗ | ✓ |
| Transactions (type, parties' names, amount, status, dates) | ✗ | ✓ |
| Payment details beyond status | ✗ | status only |
| **Handoff codes, pickup references** | ✗ | ✗ |
| **Delivery photo proof** (metadata + image) | ✗ | only during an open dispute on that request (signed URL, audited) |
| Other users' notifications, device tokens | ✗ | ✗ |
| Audit log | ✓ | ✓ own building |
| Any other building | ✓ (setup/stats) | ✗ |
There is no "super-user" read path in the app; production data inspection is done only through the Supabase dashboard by you (owner) and is outside application roles. Because you hold both roles in the pilot, the table shows what *each role's code path* can reach, and the Privacy Policy must disclose that the building admin can see names and phone numbers of residents of their building (text TODO).

### 12.5 Building-level data isolation
- `building_id` on every community row; composite FKs prevent cross-building links (BR-J4); RLS includes `app.is_resident(building_id)` everywhere.
- RPCs derive `building_id` from the **entity being touched** and re-check membership in *that* building.
- Storage (both buckets **private**, signed URLs only):
  - `avatars/{user_id}.jpg` — read: the owner and residents who share a building (checked via function); write: owner; MIME `image/jpeg|png`, ≤ 1 MB.
  - `delivery-proofs/{building_id}/{request_id}/{uuid}.jpg` — **insert**: only if `app.can_upload_proof(request_id)` (caller is the accepted helper, request `collected`, door delivery authorized, no existing proof); **select**: only if `app.can_view_proof(request_id)` (requester, uploader, or building admin with an open dispute on the request); **no update/delete for any user** (the retention job uses the service role); MIME `image/jpeg` only, ≤ 3 MB; path building id must match the request's building.
- Automated test: create buildings A and B with residents, run the whole read/write matrix as users of A against B's ids; expect zero rows/denials.

### 12.6 Specific protections (your examples)
| A user cannot… | Prevented by |
|---|---|
| Access another building | RLS `is_resident(building_id)`; composite FKs; RPC re-check |
| Access unapproved residents | `public_profile_v` filters `status='approved'`; applicants have no building-data read |
| Publish someone else's parking | `create_parking_listing` requires an **active assignment** for that user and space; trigger `guard_listing_assignment`; no INSERT privilege |
| Modify another user's transaction | no DML privilege; RPCs check `payer_id/payee_id = auth.uid()` |
| Approve themselves as a resident (ordinary user) | admin RPCs require the building-admin role; `guard_self_review`; applicants/residents can't call admin RPCs |
| Approve their own parking assignment (ordinary user) | same; the **sole building admin** may self-review only while `allow_admin_self_review = true`, flagged in the audit log (BR-A6) |
| Complete a door delivery without permission | `submit_door_delivery` checks `door_delivery_allowed` / `door_delivery_approved_at` server-side; Storage insert policy checks the same |
| Complete a door delivery without a photo | photo object must exist and `delivery_proof` must be created in the same transaction |
| Read someone's delivery photo | private bucket; select policy limited to requester/uploader/(admin during dispute); short-lived signed URLs; every view audited |
| Rate a transaction they did not take part in | `validate_rating` trigger; `unique (transaction_id, rater_id)` |
| Modify a completed transaction | `guard_transaction_immutable`; later issues create new `payment`/`dispute` rows |
| Claim a space that belongs to someone else | request only; **admin verifies**; one active holder per space; flagged if currently held by another |
| Invent apartment/space numbers | free text impossible: FKs to admin-defined lists |
| Brute-force a join code | rate limit, code rotation, code never grants access |
| Brute-force the handoff code | 5 attempts → 15-min server-side lock, lock cycles flag admins, regeneration limited |
| Read the handoff code as the helper | `delivery_secret` has no SELECT; `get_delivery_secrets` returns code **only** to the requester |
| Remove their own consent evidence | `legal_acceptance` append-only |
| Create a building | only `create_building` (platform admin) |

### 12.7 Privacy
- Public surfaces show only first name + last initial, photo, rating, counts (BR-K1). Phone and apartment never appear in public views.
- Contact reveal is just-in-time, counterparty-only, while the transaction is live (BR-K3), logged in `audit_log`. Apartment reveal only to the accepted helper in a delivery (BR-K2).
- Push payloads carry no personal data beyond generic text + entity id; lock-screen safe.
- Analytics receive no names/phones/apartments; handoff codes/references never leave the database except to the entitled user's screen.
- Account deletion in-app (required by Apple/Google): anonymizes the profile ("Former resident"), retains transaction/audit records needed by counterparties.
- **Delivery photos** are personal data (they may show a door, a hallway, a person): taken in-app only (camera, not gallery), re-encoded to JPEG with location metadata stripped, uploaded to a private bucket, visible only to requester/uploader (and admin during a dispute), never in push payloads, deleted `proof_retention_days` (30) after completion/resolution. The UI instructs the helper to photograph only the package and avoid people and other residents' doors. The Privacy Policy (TODO text) must disclose this. Residual risk: the client is untrusted, so a modified client could upload an unrelated JPEG — the photo is evidence for the requester's review, not an authenticity guarantee.
- Data location: choose an EU Supabase region and confirm with counsel (O3). Privacy law obligations (Israeli Privacy Protection Law) belong to the legal workstream, not to this document.

### 12.8 Payment security (MVP)
- The app **never touches card data or funds**; no payment credentials are stored (BR-F2).
- `payment_event` is an append-only audit trail; settled payments are immutable; refunds are separate rows.
- Payment state changes only through `app.apply_payment_event`, which validates actor ↔ role (payer vs payee) and the state machine (§11.8).
- The UI states clearly that payment is arranged directly between neighbors outside the app.
- Future real providers: secrets in Edge Function secrets only; webhook signature verification; idempotency keys; PCI scope stays with the provider.

### 12.9 API security
- TLS only; the app ships only the Supabase **anon key**. The **service-role key exists only inside Edge Function secrets**.
- All RPCs: `security definer`, `set search_path = ''`, schema-qualified names, no dynamic SQL from user input, argument validation, stable error codes (no stack traces to clients).
- Rate limiting: OTP, join-code attempts, handoff attempts, creation endpoints (≤ 20 requests/offers/hour/user), arrival ping cooldown.
- Optional hardening before pilot: Firebase App Check (App Attest / Play Integrity).
- Separate dev and prod projects; secrets never in git; CI uses repository secrets owned by your org.

### 12.10 Auditability
`audit_log` records every admin action, every contact reveal, every delivery-proof view, and flags self-reviews (`self_review = true`); `membership_event`, `payment_event`, `legal_acceptance`, `rating`, `delivery_proof` are append-only. A nightly consistency view checks: no building without admin when active; no overlapping reservations; every completed transaction has both parties' membership in the same building; `settled` payments belong to terminal-or-in-progress transactions.

### 12.11 Threat summary
| Threat | Controls |
|---|---|
| Outsider joins to spy | OTP + join code + **admin verification** against authoritative lists; no data before approval |
| Fraudulent parking claim | Admin-verified assignments; one holder per space; audit |
| Malicious/curious admin | Least-privilege views; audit log; no secrets visible; self-review explicitly flagged. **Accepted pilot risk:** the sole admin is you, so there is no second approver; mitigated by audit flags and by the switch to disable self-review once more admins exist |
| Cross-building leakage (future) | Composite FKs + RLS + automated cross-building test |
| Helper falsely claims delivery | Correct code **or** (requester authorization + in-app photo); 24 h requester review; disputes; door-delivery share monitored |
| Misuse of delivery photos | Private bucket, strict select policy, signed URLs, audit of views, 30-day retention, in-app camera only |
| Lost platform-admin access (single admin) | Recovery through the Supabase dashboard (SQL) owned by you; documented in the runbook |
| Replay / race / double-booking | DB exclusion constraints; idempotent RPCs |
| Modified client | No DML privileges; RLS; triggers; server-side recomputation |
| Rating abuse | Trigger-enforced participation; one per party; hidden-until-both; admin hide |
| Account takeover | OTP, session revocation on disable, App Check (optional) |
| Lost production access | Ownership & continuity plan (below) |

---

## Backend recommendation & Supabase setup

### Verdict: **Supabase remains the recommended backend for the MVP.**

Evaluated against your criteria (pricing and limits are indicative and must be re-checked on the vendors' current pages before you commit):

| Criterion | Supabase | Firebase (Firestore) | Self-managed (VPS + Postgres + own API/auth) | Managed Postgres (Neon/RDS) + custom API |
|---|---|---|---|---|
| **Low initial cost** | Free tier for dev; **Pro ≈ US$25/month per organization** (+ small per-extra-project compute) covers a pilot | Pay-as-you-go, cheap at pilot scale | Cheapest VM, but **your time** is the cost | DB cheap; API hosting + auth are extra |
| **Easy development** | Auth + DB + Storage + Functions + Realtime + CLI in one; Flutter SDK | Excellent SDK, but data modeling is document-based | You build everything | You build API, auth, authorization |
| **PostgreSQL** | **Full Postgres** (extensions: btree_gist, pg_cron, pg_net) | ✗ no relational constraints | ✓ | ✓ |
| **Authentication (phone OTP)** | ✓ built in (Twilio/Vonage/MessageBird etc.) | ✓ phone auth | You integrate an OTP provider | You integrate |
| **Row-Level Security** | **Native Postgres RLS**, enforced for client SDK calls | Security Rules (different model, weaker for double-booking & joins) | Possible, you wire it | Possible, you wire it |
| **Server-side functions** | SQL/PL-pgSQL RPC + **Edge Functions** (Deno) | Cloud Functions | Anything | Anything |
| **Push notifications** | **No push service** → use FCM via an Edge Function (Firebase used for push only) | ✓ native | You integrate FCM | You integrate FCM |
| **Double-booking guarantee** | **Exclusion constraint in the DB** | Hand-rolled transactions | ✓ (Postgres) | ✓ |
| **Scalability** | Far beyond one building; vertical scaling + read replicas on higher plans | Very high | Manual | Good |
| **Migration / expansion** | Standard Postgres: `pg_dump` to any host; open-source stack (self-hostable); lock-in is mainly Auth/Storage/Edge APIs | Hard to leave (proprietary data model) | Full control | Moderate |
| **Ownership & control** | Org and projects owned by **you**; DB credentials, backups, SQL access are yours | Owned by you (Google project) | Full | Full |
| **Operational burden** | Low (managed) | Low | **High** (patching, backups, uptime, security) | Medium |

**Why not the alternatives for this MVP:** Firestore cannot express the core invariants (overlap prevention, one holder per space, composite building integrity) without custom transaction code, and you excluded it as the primary database. A self-managed server contradicts "managed backend first". Managed Postgres + a custom API means writing and securing an auth/authorization layer that Supabase already provides. Nhost/Hasura-style stacks are similar in spirit but with a smaller ecosystem and no clear advantage here.

**Known risks and how we handle them**
| Risk | Handling |
|---|---|
| No Supabase region in Israel (latency ~50–90 ms from the EU) | Choose an EU region (e.g., Frankfurt); acceptable for this app; privacy/legal location confirmed by counsel (O3) |
| RLS mistakes are silent leaks | Default-deny, no client DML, pgTAP RLS test matrix, cross-building test, admin views instead of raw tables |
| Edge Function/`pg_net` push can fail silently | `push_sent_at` tracking, retry in `tick_notifications`, in-app center as the reliable channel |
| Vendor outage or pricing change | Standard Postgres + migrations in git + own backups → portable; the exit plan below |
| Free-tier limits (auto-pause after inactivity, no scheduled backups) | **Prod runs on the Pro plan** from the pilot; the Free plan is only for throwaway experiments |
| Dashboard schema edits drifting from git | Policy: schema changes **only via migrations**; production dashboard is read-mostly |

### Recommended setup

**Accounts (all owned by you):** one Supabase **organization** under your personal account with MFA; GitHub account/org; Firebase project (push only); SMS provider; Apple individual account; Google Play account. Developers are **invited** with the minimum role; nobody receives the owner role.

**Environments** — strict separation:
| | Local | **dev** | **prod** |
|---|---|---|---|
| Purpose | Daily work, DB tests | Shared integration, TestFlight/internal builds for you | The pilot with real residents |
| Supabase | **Supabase CLI** (Docker) — free, fast pgTAP | Cloud project `shacheni-dev` | Cloud project `shacheni-prod` (**Pro**) |
| Data | seed script | synthetic seed only | real data only; **no seed/test data** |
| Auth/SMS | test OTP | **test OTP numbers** (no real SMS) | real SMS provider |
| Firebase/FCM | — | dev Firebase app | prod Firebase app |
| Flutter flavor / bundle ID | — | `dev` / `…​.dev` suffix | `prod` |
| Secrets | `.env.local` (not committed) | CI secrets (dev) | CI secrets (prod) + your password manager |
| Schema deploy | `supabase db reset` | auto on merge to `main` | **manual approval** step in CI, after dev is green |
Keys: separate anon key, service-role key, DB password and FCM credentials per environment; the service-role key exists only in Edge Function secrets and CI secrets, never in the app.

**Database**: PostgreSQL via Supabase; schema exclusively through versioned migrations in `supabase/migrations/`; RLS on every table; helper functions in schema `app`; extensions `btree_gist`, `pg_cron`, `pg_net`, `pgcrypto`; `public` API exposure limited to the tables/views/RPCs we intend (unused schemas disabled in API settings).

**Auth**: Supabase Auth phone OTP; provider chosen in Phase 8 (O6); test OTP numbers for dev and for the store-review demo account; sessions via secure storage.

**Row-Level Security**: as specified in §9.6 / §12; the anon key can do nothing except fetch current legal documents.

**Edge Functions** (only where SQL cannot): `send-push` (FCM delivery, localized templates) and `purge-proofs` (retention deletion of delivery photos with the service role). Payment adapters are future. Secrets via `supabase secrets set`.

**Storage (images)**: two **private** buckets — `avatars` and `delivery-proofs` — with MIME/size limits and the policies in §12.5; the app resizes and re-encodes images before upload (≤ 1600 px JPEG, EXIF stripped); signed URLs with short expiry for display and caching of avatars by the client.

**Backups**
1. **Provider backups:** Pro-plan automated daily backups (confirm retention on the current plan); consider the point-in-time-recovery add-on if the budget allows once real data accumulates.
2. **Your own off-platform backups:** a scheduled CI job (GitHub Actions, under your account) runs `pg_dump` for `shacheni-prod` daily/weekly, encrypts the dump, and stores it in a storage location you own (e.g., private cloud bucket or drive); a second job exports Storage objects (avatars; delivery proofs are short-lived and may be excluded). Auth users are inside the DB dump (`auth` schema) so phone identities are covered.
3. **Restore drill** before the pilot starts and once per quarter: restore the dump into a scratch project and run the DB test suite against it.
4. **Schema is reproducible from git** (migrations), so a total loss costs data, not structure.

**Migration / exit strategy (kept cheap):** (a) standard Postgres dump/restore to any provider; (b) RLS policies and RPCs are plain SQL; (c) the Flutter data layer is behind repository interfaces, so replacing Auth/Storage/Edge calls is localized; (d) Supabase is open source and can be self-hosted if ever required. Nothing in the design depends on a proprietary data model.

**Cost (indicative, verify before committing):** Supabase Pro ≈ US$25/month (+ dev project compute if it lives in the same org, typically a few dollars to ~US$10/month) · SMS OTP per message (provider-dependent, a few cents each — budget for ~2–3 OTPs per resident per month) · FCM free · Apple Developer Program US$99/year · Google Play one-time US$25 · domain later (~US$10–25/year) · crash reporting free tier. A realistic pilot budget is **tens of dollars per month**, dominated by Supabase Pro.

**Monitoring & limits:** Supabase spend cap left **on**; usage alerts; a weekly look at logs; the admin "health" query (stuck states) described below.

### Configuration & domain independence
No domain is purchased or configured now (BR-N1). Therefore:
- All environment values come from per-flavor configuration (`--dart-define-from-file`): Supabase URL/anon key, **`APP_LINK_BASE_URL`** (empty until a domain exists), support contact, legal-page URLs, store URLs, app display name key. No literal hostname appears in Dart, SQL, Edge Functions or notification templates (templates take a base URL from config/secret).
- **Join flow works without a domain**: the building admin shares the **join code** (S05 manual entry) and the install link (TestFlight/Play testing link). Deep-link routes (`/join/:code`, notification routes) are parsed from *paths*, independent of host, and also registered under a custom scheme (`shacheni://`), so adding a domain later only means: buy the domain, publish `apple-app-site-association` and `assetlinks.json`, set `APP_LINK_BASE_URL`, and update the associated-domains entitlement — **no code change in business logic**.
- Join QR poster (A12) encodes `APP_LINK_BASE_URL/join/<code>` once the base URL is configured; before that it shows the code and install instructions as text/QR of the install link.
- Legal documents are stored in the database and shown in-app; **store listings require a public privacy-policy URL** — until a domain exists this can be any URL you control (e.g., a static page); it carries the placeholder/final legal text and is set in configuration, not code.
- Email/support addresses, sender names and brand strings are configuration/localization values, so the domain and any future name changes are low-risk.

## Technical architecture (Phase 6 inputs)

### Stack
| Concern | Choice | Why |
|---|---|---|
| App | **Flutter / Dart**, iOS + Android | required |
| State | **Riverpod** | simple, testable |
| Navigation | `go_router` + redirect guards by *app state* (see below) + path-based deep links (host-independent) | notifications and join links need deep links |
| Camera / images | camera-only capture (e.g., `image_picker` with camera source or `camera`) + client re-encode (resize, JPEG, strip EXIF) | delivery photo proof (BR-E10) |
| Backend | **Supabase**: Auth, PostgreSQL, RLS, Realtime, Storage, Edge Functions, pg_cron | required; relational constraints solve double-booking |
| Firebase | **only** FCM (push) and, if needed, Analytics. Never a database | required |
| Localization | Flutter `gen-l10n`, ARB `he` + `en`, ICU plurals | BR-M1 |
| Models | plain Dart + `json_serializable` | keep light |
| Testing | `flutter_test`, `mocktail`, `integration_test`; pgTAP for DB | |
| CI/CD | GitHub Actions (or Codemagic) under **your** org | ownership |
| Crash reporting | Sentry or Crashlytics (owner account) | |

### App routing gates (single redirect function)
`no session → Welcome/Phone/OTP` → `legal not current → Consent gate` → `no membership → Join building` → `membership: pending/info_requested/rejected/disabled → status screen` → `approved → Main`. Admin entries appear inside **Me** when `building_admin` or `platform_admin` rows exist (and the agreement gate for admins). In the pilot you see both entries: **Admin** (building) and **Platform** (create building).

### Flutter project structure
```
lib/
├─ main_dev.dart / main_prod.dart        # flavors
├─ app/    router.dart · gates.dart · theme/ (tokens) · l10n/ (app_he.arb, app_en.arb)
├─ core/   supabase/ (client, error mapping) · money.dart · time.dart (building tz) ·
│          bidi.dart · widgets/ (shared components) · config/
└─ features/
    ├─ auth/  legal/  join/                # OTP, consent gate, join code, application
    ├─ home/
    ├─ parking/                            # listings, reservations, search, assignments
    ├─ delivery/                           # requests, offers, handoff
    ├─ payments/                           # payment panel, PaymentMethod presenters
    ├─ transactions/  ratings/  notifications/  profile/
    └─ admin/ (building/)  platform/       # role-gated
       each feature: data/ (repository impl) · domain/ (entities, repo interface) · presentation/
supabase/  migrations/ · functions/ (send-push, purge-proofs) · seed/ (dev only) · tests/ (pgTAP)
```
Rule: **UI never imports Supabase**; repository interfaces live in `domain/`. This is the only abstraction layer added.

### Notification architecture
1. Producers (RPCs, tick) call `app.notify(...)`, which applies preferences, quiet hours, daily cap (optional types) and `dedupe_key`, then inserts a `notification` row (type + params + route).
2. A trigger on `notification` insert calls the **`send-push` Edge Function** through `pg_net` (shared-secret header).
3. `send-push` (service role) loads the user's `device_token`s and `profile.locale`, renders the localized **he/en** template (title/body, no PII beyond generic text), sends via **FCM HTTP v1**, sets `push_sent_at`, deletes invalid tokens.
4. Client: registers token on login (`register_device_token`), shows foreground messages locally, routes taps through `go_router` deep links (`route`/`entity_id`), renders the in-app center from `type + params` using ARB (so a language switch also re-renders history), listens to Realtime on `notification` for live badge.
5. Template parity (he/en, ARB ↔ Edge Function) checked in CI.
Notification actions (e.g., Accept / Decline): iOS/Android action buttons call the same RPCs with the user's session after an app-lock-safe open; MVP default is deep link to the screen with the action prominent.

### Payment abstraction (layers)
```
Business logic (RPCs, tick)          ← depends ONLY on payment.status
        │ app.apply_payment_event(payment, event, actor)   ← the single state machine (§11.8)
        ▼
PaymentProvider adapter (server)      id · capabilities · createPayment(intent) · handleEvent(...)
   MockProvider (MVP, in-DB, no external call)  ── future: Bit · PayBox · Cash · RealProvider
        ▼
PaymentMethod presenter (Flutter)     instructions text key · optional deep link · which buttons to show
```
Capabilities: `holdsFunds` (false), `requiresPayerConfirmation` (true), `requiresPayeeConfirmation` (true), `supportsRefund` (record-only). A future Bit/PayBox/cash method differs only in presenter instructions/deep link; a real provider fires `payer_confirmed`/`settled` events from webhooks and may add `authorized`/`captured` states via an additive migration. The transaction system needs no rewrite (BR-F9). Methods enabled per building in `settings.payment_methods`; each `payment.method` records what was used. No hold of user funds anywhere.

### Localization architecture
- ARB files `app_he.arb` (template/default) and `app_en.arb`; keys are semantic (`reservation_status_confirmed`), ICU plurals/selects (Hebrew `one/two/other`), zero string literals in widgets (lint rule + CI grep).
- Locale resolution at startup: **saved choice (profile.locale + local copy) → device language (`he`→he, `en`→en) → `he`**. Settings offers עברית / English; changing it updates `profile.locale` (used by push templates) immediately.
- Direction from locale; layouts use `EdgeInsetsDirectional`, `AlignmentDirectional`, `start/end` (never left/right); directional icons mirrored; numbers/times in Latin digits, 24-hour clock, week starts Sunday, Gregorian dates.
- Currency formatted by `NumberFormat.currency(locale, symbol: '₪')` — one `Money` type formats everywhere.
- Mixed-direction safety: phone numbers, plates, Latin names and amounts wrapped in bidi isolates; user-entered fields auto-detect direction.
- Hebrew-capable font bundled with the app (e.g., Rubik/Heebo/Assistant, open-source) — no runtime font download.
- Server returns **codes + params** (errors, statuses, notification types), never sentences. Legal docs by locale from `legal_document`.
- Tests: golden/widget tests for key screens in `he` (RTL) and `en`; pseudo-localization check for overflow.

### Error catalog (server → client → localized message + behavior)
`NOT_APPROVED` · `LEGAL_NOT_ACCEPTED` · `BUILDING_NOT_ACTIVE` · `JOIN_CODE_INVALID` · `JOIN_RATE_LIMITED` · `APARTMENT_INVALID` · `ALREADY_APPLIED` · `SELF_REVIEW_FORBIDDEN` · `NOT_ADMIN` · `SPACE_NOT_ASSIGNED` · `ASSIGNMENT_CONFLICT` · `ASSIGNMENT_HAS_RESERVATIONS` · `SLOT_TAKEN` · `LISTING_NOT_AVAILABLE` · `OWN_LISTING` · `INVALID_WINDOW` · `PRICE_OUT_OF_RANGE` · `STATE_CHANGED` · `CANNOT_CANCEL` · `DEADLINE_TOO_SOON` · `OFFER_EXISTS` · `CODE_INVALID` · `CODE_LOCKED` · `DOOR_DELIVERY_NOT_ALLOWED` · `PROOF_REQUIRED` · `PROOF_INVALID` · `ARRIVAL_COOLDOWN` · `REGEN_LIMIT` · `PAYMENT_STATE_INVALID` · `DISPUTE_WINDOW_CLOSED` · `ALREADY_RATED` · `RATING_WINDOW_CLOSED` · `RATE_LIMITED`. Each maps to an ARB key and a UX behavior (inline / snackbar / conflict dialog).

### Environments & delivery
- Local / **dev** / **prod** as defined in "Backend recommendation & Supabase setup". Flutter flavors with different bundle IDs (`.dev` suffix); migrations in git are the single source of truth (`supabase db push`, prod behind manual approval).
- Naming: package `shacheni_app`; dev bundle/application IDs end with `.dev`. The **final bundle/application ID must be chosen before the first TestFlight/Play upload** (it cannot be changed afterwards without creating a new app); it does not require owning a domain. Decision log O2.
- Distribution: **TestFlight** (individual Apple account) and **Google Play closed testing**. Note: new *personal* Google Play accounts are currently required to run a closed test with a minimum number of testers for a minimum period (about 12 testers for 14 days at the time of writing — verify in Play Console) before they can publish to production. The pilot itself can run entirely on closed testing.
- Observability: crash reporting; Supabase logs; an admin "health" query for stuck states (reservations past `expires_at`, payments pending > 7 days, disputes past SLA).

### Testing strategy (feeds Phase 5 and 14)
| Layer | What |
|---|---|
| Database (pgTAP) | double-booking (overlap, back-to-back OK, two-session race); one active assignment per space; **self-review allowed only for the building admin while `allow_admin_self_review` is true (flagged) and blocked when false; never allowed for ordinary residents**; **cross-building isolation**; RLS per table/role; admin view column exposure; immutability of transactions/payments/acceptances/proofs; rating rules; payment state machine; handoff lock/regeneration; **door delivery refused without authorization or without proof; Storage policies for `delivery-proofs` (insert/select/no-delete); proof retention purge**; legal gate (placeholder → new version triggers re-acceptance); join-code rate limit |
| Dart unit | validators, Money, bidi helpers, status mapping, cancellation-consequence calculator |
| Widget / golden | key screens in RTL Hebrew and LTR English, empty/loading/error states |
| Integration | full parking and pickup journeys incl. mock payment, on devices |
| Manual E2E | two phones (iOS + Android) + one admin device: all 24 flows |
| Pilot dry run | 5–8 friendly residents for one week |

### Ownership & continuity (you own every critical resource)
| Resource | Owner of record | Developer access | Notes |
|---|---|---|---|
| Source repository | **your GitHub account/repository** (an organization under your account is optional) | invited collaborators (write), no owner/admin role | branch protection; no code only on a laptop |
| Apple Developer Program / App Store Connect | **your individual Apple ID** (account holder) — decided | invited *Developer/App Manager*; App Store Connect API key owned by you for CI | The App Store shows **your personal name as the seller**. An app can later be transferred to an organization account if you form a company |
| Google Play Console | **your** developer account (personal) | invited users with limited roles | **Play App Signing** enabled so Google holds the app-signing key; you hold the upload key; personal-account closed-testing requirement (see "Environments & delivery") |
| Supabase | org/projects **under your account** (Pro plan for pilot: no auto-pause, backups) | invited members | region EU (P17) |
| Firebase (FCM, optional Analytics) | project owned by you | IAM roles | APNs auth key generated from your Apple account |
| Domain & DNS | **not purchased yet** (decided); when bought: registrar account in your name | none | needed later for universal/app links; see "Configuration & domain independence" |
| SMS/OTP provider | your account | none | |
| Signing keys / certificates | stored in **your** password manager + encrypted backup; CI holds copies in repo secrets of your org | none | never only on a developer's machine |
| Secrets (`.env`, service role, FCM, SMS) | your password manager; Edge Function secrets in Supabase | least-privilege per environment | rotate on any offboarding |
| Crash/analytics accounts | owned by you | invited | |
Practices: MFA everywhere; recovery codes stored offline; shared password manager vault with emergency access for a trusted person; nothing registered with a developer's personal email; a short **runbook** (how to deploy, rotate keys, restore a backup, recover platform-admin access via SQL, publish a new legal version) kept in the repo; weekly automatic backup plus a restore drill before the pilot; migrations let the schema be rebuilt from git alone.

### Multi-building later (what is deliberately *not* built yet)
Already built into backend/DB: buildings, per-building admins (table + helpers), memberships, building-scoped RLS, per-building settings and legal acceptances. **Not built now:** UI for multiple memberships/building switching, building discovery, per-building branding, cross-building analytics UI, **additional platform/building admins and any appointment mechanism**. Enabling later = drop the MVP one-live-membership index, add a building switcher, scope client queries by the selected membership; and for more admins: add an appointment RPC/screen (invitation by phone), flip `allow_admin_self_review` to `false`, and distribute approvals.
