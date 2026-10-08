-- Shacheni core schema: enums, tables, constraints, indexes.
-- Source of truth: docs/PRD-data-security-architecture.md §9 (tables §9.2, constraints §9.3, indexes §9.4).
-- Conventions (§9.0): uuid PKs, timestamptz, money in agorot (*_minor), building_id on every community
-- row, child → parent composite FKs (BR-J4). No client DML: writes go through security-definer RPCs.

create extension if not exists btree_gist with schema extensions;

create schema if not exists app;
comment on schema app is 'Shacheni helper functions (security definer); not exposed through the API.';

-- Every function created in `app` is private unless explicitly granted.
alter default privileges in schema app revoke execute on functions from public;

-- ---------------------------------------------------------------------------------------------
-- Enums
-- ---------------------------------------------------------------------------------------------
create type public.building_status as enum ('draft', 'active', 'suspended');
create type public.membership_status as enum ('pending', 'info_requested', 'approved', 'rejected', 'disabled');
create type public.membership_event_type as enum (
  'submitted', 'info_requested', 'info_provided', 'approved', 'rejected', 'disabled', 'enabled', 'apartment_change');
create type public.assignment_status as enum ('requested', 'active', 'rejected', 'withdrawn', 'ended');
create type public.booking_mode as enum ('request', 'instant');
create type public.listing_status as enum ('available', 'reserved', 'active', 'completed', 'cancelled', 'expired');
create type public.reservation_status as enum (
  'requested', 'accepted', 'confirmed', 'active', 'completed', 'cancelled', 'declined', 'expired');
create type public.delivery_status as enum (
  'open', 'offer_received', 'accepted', 'collected', 'delivered', 'completed', 'cancelled', 'expired', 'disputed');
create type public.handoff_method as enum ('code', 'door_photo', 'admin');
create type public.offer_status as enum ('pending', 'accepted', 'rejected', 'withdrawn', 'expired');
create type public.tx_type as enum ('parking', 'delivery');
create type public.tx_status as enum ('in_progress', 'awaiting_settlement', 'completed', 'cancelled', 'disputed');
create type public.payment_kind as enum ('charge', 'refund');
create type public.payment_status as enum ('pending', 'payer_confirmed', 'settled', 'cancelled');
create type public.settled_via as enum ('payee', 'auto', 'admin');
create type public.payment_cancel_reason as enum ('waived', 'expired_unpaid', 'transaction_cancelled', 'admin');
create type public.payment_event_type as enum (
  'created', 'payer_marked_paid', 'payee_confirmed', 'payee_not_received', 'auto_settled', 'waived',
  'expired_unpaid', 'admin_decision', 'cancelled', 'refund_created');
create type public.dispute_reason as enum (
  'space_unavailable', 'space_occupied', 'wrong_space', 'damage', 'not_delivered', 'damaged_package',
  'wrong_item', 'helper_no_show', 'requester_unreachable', 'payment_not_received', 'payment_dispute', 'other');
create type public.dispute_status as enum ('open', 'under_review', 'resolved');
create type public.dispute_outcome as enum ('payment_settled', 'payment_cancelled', 'no_action', 'warning');
create type public.legal_doc_type as enum (
  'terms_of_service', 'privacy_policy', 'community_rules', 'resident_declaration', 'building_agreement');

-- ---------------------------------------------------------------------------------------------
-- Building settings defaults ([CONFIG], §9.2 `building.settings`)
-- ---------------------------------------------------------------------------------------------
create function app.default_building_settings()
returns jsonb
language sql
immutable
set search_path = ''
as $$
  select jsonb_build_object(
    'max_listing_days', 90,
    'max_price_minor', 200000,
    'max_reward_minor', 10000,
    'declared_value_cap_minor', 100000,
    'request_response_hours', 12,
    'confirm_window_minutes', 120,
    'confirm_cutoff_before_start_minutes', 15,
    'late_cancel_hours_short', 1,
    'late_cancel_hours_long', 24,
    'code_max_attempts', 5,
    'code_lock_minutes', 15,
    'code_regen_max', 3,
    'arrival_ping_cooldown_minutes', 10,
    'door_delivery_autoconfirm_hours', 24,
    'proof_retention_days', 30,
    'proof_max_bytes', 3145728,
    'proof_max_dimension_px', 1600,
    'proof_max_age_minutes', 30,
    'allow_admin_self_review', true,
    'payer_reminder_hours', jsonb_build_array(24, 72),
    'payee_silence_autosettle_hours', 72,
    'unpaid_expiry_days', 7,
    'payment_not_received_dispute_threshold', 3,
    'dispute_window_days', 7,
    'dispute_sla_hours', 48,
    'rating_window_days', 14,
    'max_residents_per_apartment', 6,
    'join_attempts_per_hour', 10,
    'overdue_auto_dispute_hours', 24,
    'payment_methods', jsonb_build_array('mock'),
    'optional_push_daily_cap', 3
  )
$$;

-- ---------------------------------------------------------------------------------------------
-- Users & platform
-- ---------------------------------------------------------------------------------------------
create table public.profile (
  id uuid primary key references auth.users (id),
  full_name text not null default '' check (char_length(full_name) <= 100),
  phone_e164 text unique check (phone_e164 ~ '^\+[1-9][0-9]{6,14}$'),
  avatar_url text,
  locale text not null default 'he' check (locale in ('he', 'en')),
  prefs jsonb not null default '{"notify_new_pickup": true, "notify_new_parking": true}',
  deleted_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
comment on table public.profile is 'Global identity; id = auth.users.id. No email, no role column (roles: platform_admin, building_admin).';

-- MVP: exactly one row (the owner), inserted once by SQL. No API write path.
create table public.platform_admin (
  user_id uuid primary key references public.profile (id),
  granted_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------------------------------
-- Building, apartments, spaces, building admins
-- ---------------------------------------------------------------------------------------------
create table public.building (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(name) between 1 and 100),
  address text not null check (char_length(address) between 1 and 200),
  city text check (char_length(city) <= 100),
  timezone text not null default 'Asia/Jerusalem',
  declared_apartment_count int not null check (declared_apartment_count > 0),
  declared_parking_count int not null check (declared_parking_count >= 0),
  status public.building_status not null default 'draft',
  -- 8 chars, unambiguous alphabet (no 0/O/1/I). Rotatable; rate-limited; never grants access (BR-B6).
  join_code text unique check (join_code ~ '^[A-HJ-NP-Z2-9]{8}$'),
  join_code_rotated_at timestamptz,
  settings jsonb not null default app.default_building_settings(),
  created_by uuid not null references public.profile (id),
  created_at timestamptz not null default now(),
  activated_at timestamptz,
  updated_at timestamptz not null default now(),
  check (status = 'draft' or activated_at is not null)
);
create unique index building_name_address_key on public.building (lower(name), lower(address));

create table public.apartment (
  id uuid primary key default gen_random_uuid(),
  building_id uuid not null references public.building (id),
  number text not null check (char_length(number) between 1 and 20),
  floor int,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  unique (building_id, number),
  unique (id, building_id)
);

-- No owner column: ownership exists only through parking_assignment.
create table public.parking_space (
  id uuid primary key default gen_random_uuid(),
  building_id uuid not null references public.building (id),
  label text not null check (char_length(label) between 1 and 20),
  level text check (char_length(level) <= 20),
  notes text check (char_length(notes) <= 200), -- location hints; never gate codes
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  unique (building_id, label),
  unique (id, building_id)
);

-- MVP: one row per building, created by create_building for its creator.
create table public.building_admin (
  id uuid primary key default gen_random_uuid(),
  building_id uuid not null references public.building (id),
  user_id uuid not null references public.profile (id),
  granted_by uuid not null references public.profile (id),
  granted_at timestamptz not null default now(),
  revoked_at timestamptz,
  revoked_by uuid references public.profile (id),
  check ((revoked_at is null) = (revoked_by is null))
);
create unique index one_active_admin_row_per_user
  on public.building_admin (building_id, user_id) where revoked_at is null;

-- ---------------------------------------------------------------------------------------------
-- Membership (resident request → verified resident); reputation is building-scoped
-- ---------------------------------------------------------------------------------------------
create table public.building_membership (
  id uuid primary key default gen_random_uuid(),
  building_id uuid not null references public.building (id),
  user_id uuid not null references public.profile (id),
  apartment_id uuid not null,
  status public.membership_status not null default 'pending',
  applicant_note text check (char_length(applicant_note) <= 500),
  info_request_message text check (char_length(info_request_message) <= 500),
  info_response text check (char_length(info_response) <= 500),
  status_reason text check (char_length(status_reason) <= 500),
  flags jsonb not null default '{}',
  reviewed_by uuid references public.profile (id),
  reviewed_at timestamptz,
  approved_at timestamptz,
  disabled_at timestamptz,
  rating_avg numeric(3, 2),
  rating_count int not null default 0,
  completed_count int not null default 0,
  late_cancel_count int not null default 0,
  provider_cancel_count int not null default 0,
  requester_cancel_count int not null default 0,
  helper_cancel_count int not null default 0,
  unpaid_count int not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  foreign key (apartment_id, building_id) references public.apartment (id, building_id),
  unique (building_id, user_id),
  unique (id, building_id),
  unique (id, apartment_id)
);
-- MVP: one live membership per user (drop when the multi-building UI ships).
create unique index one_live_membership_per_user
  on public.building_membership (user_id) where status in ('pending', 'info_requested', 'approved');
create index building_membership_building_status_idx on public.building_membership (building_id, status);

create table public.membership_event (
  id uuid primary key default gen_random_uuid(),
  building_id uuid not null,
  membership_id uuid not null,
  actor_id uuid references public.profile (id),
  type public.membership_event_type not null,
  message text check (char_length(message) <= 500),
  created_at timestamptz not null default now(),
  foreign key (membership_id, building_id) references public.building_membership (id, building_id)
);
create index membership_event_membership_idx on public.membership_event (membership_id, created_at);

-- ---------------------------------------------------------------------------------------------
-- Parking ownership: the only link between a resident and a space (request + ownership)
-- ---------------------------------------------------------------------------------------------
create table public.parking_assignment (
  id uuid primary key default gen_random_uuid(),
  building_id uuid not null references public.building (id),
  parking_space_id uuid not null,
  membership_id uuid not null,
  apartment_id uuid not null,
  status public.assignment_status not null default 'requested',
  requested_note text check (char_length(requested_note) <= 200),
  requested_at timestamptz not null default now(),
  reviewed_by uuid references public.profile (id),
  reviewed_at timestamptz,
  review_note text check (char_length(review_note) <= 500),
  started_at timestamptz,
  ended_at timestamptz,
  ended_by uuid references public.profile (id),
  end_reason text check (char_length(end_reason) <= 500),
  flags jsonb not null default '{}',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  foreign key (parking_space_id, building_id) references public.parking_space (id, building_id),
  foreign key (membership_id, building_id) references public.building_membership (id, building_id),
  -- holder's apartment, denormalized; follows an apartment change of the membership
  foreign key (membership_id, apartment_id) references public.building_membership (id, apartment_id)
    on update cascade,
  unique (id, building_id),
  check (status <> 'active' or started_at is not null)
);
-- BR-C3: at most ONE active holder per space.
create unique index one_active_assignment_per_space
  on public.parking_assignment (parking_space_id) where status = 'active';
-- No duplicate open request/active pair.
create unique index one_open_assignment_per_pair
  on public.parking_assignment (membership_id, parking_space_id) where status in ('requested', 'active');
create index parking_assignment_membership_idx on public.parking_assignment (membership_id);
create index parking_assignment_building_status_idx on public.parking_assignment (building_id, status);

-- ---------------------------------------------------------------------------------------------
-- Parking marketplace
-- ---------------------------------------------------------------------------------------------
create table public.parking_listing (
  id uuid primary key default gen_random_uuid(),
  building_id uuid not null references public.building (id),
  parking_space_id uuid not null,
  assignment_id uuid not null,
  owner_id uuid not null references public.profile (id),
  start_at timestamptz not null,
  end_at timestamptz not null,
  price_minor int not null check (price_minor >= 0),
  currency text not null default 'ILS' check (currency ~ '^[A-Z]{3}$'),
  description text check (char_length(description) <= 200),
  booking_mode public.booking_mode not null default 'request',
  status public.listing_status not null default 'available',
  cancelled_at timestamptz,
  cancel_reason text check (char_length(cancel_reason) <= 500),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  foreign key (parking_space_id, building_id) references public.parking_space (id, building_id),
  foreign key (assignment_id, building_id) references public.parking_assignment (id, building_id),
  unique (id, building_id),
  unique (id, parking_space_id),
  check (end_at > start_at),
  check (end_at - start_at <= interval '90 days'),
  -- BR-D2: no two live listings of one space overlap ('[)' allows back-to-back windows).
  constraint no_listing_overlap exclude using gist (
    parking_space_id with =, tstzrange(start_at, end_at, '[)') with &&
  ) where (status in ('available', 'reserved', 'active'))
);
create index parking_listing_search_idx on public.parking_listing (building_id, status, start_at);

create table public.parking_reservation (
  id uuid primary key default gen_random_uuid(),
  building_id uuid not null references public.building (id),
  listing_id uuid not null,
  parking_space_id uuid not null,
  owner_id uuid not null references public.profile (id),
  requester_id uuid not null references public.profile (id),
  start_at timestamptz not null,
  end_at timestamptz not null,
  price_minor int not null check (price_minor >= 0),
  currency text not null default 'ILS' check (currency ~ '^[A-Z]{3}$'),
  status public.reservation_status not null default 'requested',
  vehicle_plate text check (char_length(vehicle_plate) <= 15),
  requester_note text check (char_length(requester_note) <= 200),
  decline_reason text check (char_length(decline_reason) <= 500),
  cancel_reason text check (char_length(cancel_reason) <= 500),
  cancelled_by uuid references public.profile (id),
  expires_at timestamptz,
  requested_at timestamptz not null default now(),
  accepted_at timestamptz,
  confirmed_at timestamptz,
  started_at timestamptz,
  completed_at timestamptz,
  cancelled_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  foreign key (listing_id, building_id) references public.parking_listing (id, building_id),
  -- the denormalized space cannot lie about its listing
  foreign key (listing_id, parking_space_id) references public.parking_listing (id, parking_space_id),
  unique (id, building_id),
  check (owner_id <> requester_id),
  check (end_at > start_at),
  -- BR-D1: no two committed reservations of one space overlap (SQLSTATE 23P01 → SLOT_TAKEN).
  -- Pending 'requested' rows are deliberately outside the constraint (BR-D7).
  constraint no_reservation_overlap exclude using gist (
    parking_space_id with =, tstzrange(start_at, end_at, '[)') with &&
  ) where (status in ('accepted', 'confirmed', 'active', 'completed'))
);
create index parking_reservation_listing_idx on public.parking_reservation (listing_id);
create index parking_reservation_requester_idx on public.parking_reservation (requester_id, status);
create index parking_reservation_owner_idx on public.parking_reservation (owner_id, status);
create index parking_reservation_expiry_idx on public.parking_reservation (status, expires_at);

-- ---------------------------------------------------------------------------------------------
-- Packages
-- ---------------------------------------------------------------------------------------------
create table public.delivery_request (
  id uuid primary key default gen_random_uuid(),
  building_id uuid not null references public.building (id),
  requester_id uuid not null references public.profile (id),
  pickup_location text not null check (char_length(pickup_location) between 1 and 200),
  package_description text not null check (char_length(package_description) between 1 and 200),
  notes text check (char_length(notes) <= 500),
  handoff_place text not null default 'Building lobby' check (char_length(handoff_place) <= 100),
  deadline_at timestamptz not null,
  reward_minor int not null default 0 check (reward_minor >= 0), -- upper bound: settings.max_reward_minor (RPC)
  currency text not null default 'ILS' check (currency ~ '^[A-Z]{3}$'),
  door_delivery_allowed boolean not null default false, -- BR-E6: off by default
  door_delivery_approved_at timestamptz,
  arrived_at timestamptz,
  status public.delivery_status not null default 'open',
  accepted_offer_id uuid,
  handoff_method public.handoff_method,
  delivery_note text check (char_length(delivery_note) <= 200),
  collected_at timestamptz,
  delivered_at timestamptz,
  completed_at timestamptz,
  cancelled_at timestamptz,
  autoconfirm_at timestamptz,
  cancelled_by uuid references public.profile (id),
  cancel_reason text check (char_length(cancel_reason) <= 500),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, building_id),
  check (deadline_at >= created_at + interval '30 minutes' and deadline_at <= created_at + interval '7 days')
);
create index delivery_request_open_idx on public.delivery_request (building_id, status, deadline_at);

-- 1:1, separate so that no client can ever SELECT it (RPC get_delivery_secrets only).
create table public.delivery_secret (
  request_id uuid primary key,
  building_id uuid not null,
  pickup_reference text check (char_length(pickup_reference) <= 100),
  handoff_code text check (handoff_code ~ '^[0-9]{4}$'),
  failed_attempts int not null default 0 check (failed_attempts >= 0),
  lock_cycles int not null default 0 check (lock_cycles >= 0),
  locked_until timestamptz,
  regen_count int not null default 0 check (regen_count >= 0),
  foreign key (request_id, building_id) references public.delivery_request (id, building_id)
);

create table public.delivery_offer (
  id uuid primary key default gen_random_uuid(),
  building_id uuid not null,
  request_id uuid not null,
  helper_id uuid not null references public.profile (id),
  message text check (char_length(message) <= 140),
  planned_pickup_at timestamptz,
  status public.offer_status not null default 'pending',
  created_at timestamptz not null default now(),
  responded_at timestamptz,
  foreign key (request_id, building_id) references public.delivery_request (id, building_id),
  unique (id, building_id),
  unique (id, request_id)
);
create unique index one_live_offer_per_helper
  on public.delivery_offer (request_id, helper_id) where status in ('pending', 'accepted');
-- BR-E3: one accepted offer per request.
create unique index one_accepted_offer_per_request
  on public.delivery_offer (request_id) where status = 'accepted';
create index delivery_offer_request_idx on public.delivery_offer (request_id);
create index delivery_offer_helper_idx on public.delivery_offer (helper_id);

-- The accepted offer must belong to this very request (and therefore this building).
alter table public.delivery_request
  add constraint delivery_request_accepted_offer_fkey
  foreign key (accepted_offer_id, id) references public.delivery_offer (id, request_id);

-- Append-only photo evidence of a door delivery (BR-E10).
create table public.delivery_proof (
  id uuid primary key default gen_random_uuid(),
  building_id uuid not null,
  request_id uuid not null unique, -- exactly one proof per request
  uploaded_by uuid not null references public.profile (id),
  storage_path text not null unique, -- object name in bucket 'delivery-proofs': {building_id}/{request_id}/{uuid}.jpg
  mime_type text not null check (mime_type = 'image/jpeg'),
  size_bytes int not null check (size_bytes > 0),
  sha256 text check (sha256 ~ '^[0-9a-f]{64}$'),
  captured_at_client timestamptz,
  uploaded_at timestamptz not null default now(), -- authoritative proof time
  note text check (char_length(note) <= 200),
  purged_at timestamptz,
  foreign key (request_id, building_id) references public.delivery_request (id, building_id)
);

-- ---------------------------------------------------------------------------------------------
-- Transactions & payments
-- ---------------------------------------------------------------------------------------------
create table public.transactions (
  id uuid primary key default gen_random_uuid(),
  building_id uuid not null references public.building (id),
  type public.tx_type not null,
  parking_reservation_id uuid unique,
  delivery_request_id uuid unique,
  payer_id uuid not null references public.profile (id),
  payee_id uuid not null references public.profile (id),
  amount_minor int not null check (amount_minor >= 0),
  currency text not null default 'ILS' check (currency ~ '^[A-Z]{3}$'),
  platform_fee_minor int not null default 0 check (platform_fee_minor >= 0),
  status public.tx_status not null default 'in_progress',
  service_completed_at timestamptz,
  completed_at timestamptz,
  cancelled_at timestamptz,
  cancel_reason text check (char_length(cancel_reason) <= 500),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  foreign key (parking_reservation_id, building_id) references public.parking_reservation (id, building_id),
  foreign key (delivery_request_id, building_id) references public.delivery_request (id, building_id),
  unique (id, building_id),
  check (payer_id <> payee_id),
  -- exactly one source, matching the type
  check (
    (type = 'parking' and parking_reservation_id is not null and delivery_request_id is null)
    or (type = 'delivery' and delivery_request_id is not null and parking_reservation_id is null)
  )
);
create index transactions_payer_idx on public.transactions (payer_id);
create index transactions_payee_idx on public.transactions (payee_id);
create index transactions_building_status_idx on public.transactions (building_id, status);

create table public.payment (
  id uuid primary key default gen_random_uuid(),
  building_id uuid not null,
  transaction_id uuid not null,
  kind public.payment_kind not null,
  related_payment_id uuid references public.payment (id),
  method text not null default 'mock',
  payer_id uuid not null references public.profile (id),
  payee_id uuid not null references public.profile (id),
  amount_minor int not null check (amount_minor >= 0),
  currency text not null default 'ILS' check (currency ~ '^[A-Z]{3}$'),
  status public.payment_status not null default 'pending', -- no hold/authorize states in the MVP
  settled_via public.settled_via,
  cancel_reason public.payment_cancel_reason,
  payer_confirmed_at timestamptz,
  settled_at timestamptz,
  cancelled_at timestamptz,
  not_received_count int not null default 0 check (not_received_count >= 0),
  provider_ref text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  foreign key (transaction_id, building_id) references public.transactions (id, building_id),
  check (payer_id <> payee_id),
  check ((kind = 'refund') = (related_payment_id is not null)),
  check (status <> 'settled' or (settled_at is not null and settled_via is not null)),
  check (status <> 'cancelled' or (cancelled_at is not null and cancel_reason is not null))
);
create unique index one_charge_per_transaction on public.payment (transaction_id) where kind = 'charge';
create index payment_transaction_idx on public.payment (transaction_id);
create index payment_status_idx on public.payment (status);

create table public.payment_event (
  id uuid primary key default gen_random_uuid(),
  payment_id uuid not null references public.payment (id),
  type public.payment_event_type not null,
  actor_id uuid references public.profile (id), -- null = system (tick)
  data jsonb not null default '{}',
  created_at timestamptz not null default now()
);
create index payment_event_payment_idx on public.payment_event (payment_id, created_at);

create table public.dispute (
  id uuid primary key default gen_random_uuid(),
  building_id uuid not null,
  transaction_id uuid not null,
  opened_by uuid not null references public.profile (id),
  reason public.dispute_reason not null,
  description text not null check (char_length(description) between 1 and 1000),
  counterparty_response text check (char_length(counterparty_response) <= 1000),
  status public.dispute_status not null default 'open',
  outcome public.dispute_outcome,
  service_delivered boolean,
  resolved_by uuid references public.profile (id),
  admin_note text check (char_length(admin_note) <= 1000),
  post_completion boolean not null default false,
  self_review boolean not null default false, -- set by guard_self_review (BR-A6)
  created_at timestamptz not null default now(),
  resolved_at timestamptz,
  updated_at timestamptz not null default now(),
  foreign key (transaction_id, building_id) references public.transactions (id, building_id),
  check (status <> 'resolved'
         or (outcome is not null and resolved_by is not null and admin_note is not null and resolved_at is not null))
);
create unique index one_open_dispute_per_transaction
  on public.dispute (transaction_id) where status <> 'resolved';
create index dispute_building_status_idx on public.dispute (building_id, status);

-- ---------------------------------------------------------------------------------------------
-- Reputation, notifications, legal, audit
-- ---------------------------------------------------------------------------------------------
create table public.rating (
  id uuid primary key default gen_random_uuid(),
  building_id uuid not null,
  transaction_id uuid not null,
  rater_id uuid not null references public.profile (id),
  ratee_id uuid not null references public.profile (id),
  stars smallint not null check (stars between 1 and 5),
  comment text check (char_length(comment) <= 280),
  hidden boolean not null default false, -- admin moderation; the only mutable column
  created_at timestamptz not null default now(),
  foreign key (transaction_id, building_id) references public.transactions (id, building_id),
  unique (transaction_id, rater_id),
  check (rater_id <> ratee_id)
);
create index rating_ratee_idx on public.rating (building_id, ratee_id);

-- Stores type + params (not rendered text) so a record renders in either language.
create table public.notification (
  id uuid primary key default gen_random_uuid(),
  building_id uuid references public.building (id), -- null before membership
  user_id uuid not null references public.profile (id),
  type text not null,
  params jsonb not null default '{}', -- never secrets
  route text,
  entity_id uuid,
  dedupe_key text,
  read_at timestamptz,
  push_sent_at timestamptz,
  created_at timestamptz not null default now(),
  unique (user_id, dedupe_key)
);
create index notification_user_idx on public.notification (user_id, created_at desc);
create index notification_unread_idx on public.notification (user_id) where read_at is null;

create table public.device_token (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profile (id) on delete cascade,
  token text not null unique,
  platform text not null check (platform in ('ios', 'android', 'web')),
  locale text not null default 'he' check (locale in ('he', 'en')),
  last_seen_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);
create index device_token_user_idx on public.device_token (user_id);

create table public.legal_document (
  id uuid primary key default gen_random_uuid(),
  type public.legal_doc_type not null,
  version text not null check (char_length(version) between 1 and 40),
  locale text not null check (locale in ('he', 'en')),
  title text not null,
  body_md text not null,
  content_hash text not null check (content_hash ~ '^[0-9a-f]{64}$'), -- sha-256 of body_md
  effective_at timestamptz not null default now(),
  is_current boolean not null default false,
  created_by uuid references public.profile (id),
  created_at timestamptz not null default now(),
  unique (type, locale, version)
);
create unique index one_current_legal_document
  on public.legal_document (type, locale) where is_current;

create table public.legal_acceptance (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profile (id),
  building_id uuid references public.building (id), -- set for building_agreement, community_rules, resident_declaration
  document_type public.legal_doc_type not null,
  document_version text not null,
  document_id uuid not null references public.legal_document (id),
  locale text not null check (locale in ('he', 'en')),
  accepted_at timestamptz not null default now(),
  details jsonb not null default '{}',
  app_version text
);
create unique index one_acceptance_per_version on public.legal_acceptance (
  user_id, coalesce(building_id, '00000000-0000-0000-0000-000000000000'::uuid), document_type, document_version);
create index legal_acceptance_user_idx on public.legal_acceptance (user_id, document_type);

create table public.audit_log (
  id uuid primary key default gen_random_uuid(),
  building_id uuid references public.building (id),
  actor_id uuid references public.profile (id),
  self_review boolean not null default false,
  action text not null,
  target_type text,
  target_id uuid,
  note text,
  created_at timestamptz not null default now()
);
create index audit_log_building_idx on public.audit_log (building_id, created_at desc);

-- Rate limiting for join-code resolution (BR-B6).
create table public.join_code_attempt (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profile (id),
  succeeded boolean not null,
  created_at timestamptz not null default now()
);
create index join_code_attempt_user_idx on public.join_code_attempt (user_id, created_at desc);
