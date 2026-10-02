# Shacheni (שכני) — Product Requirements Document

> **Name:** **Shacheni** (Hebrew: שכני, "my neighbor") is the official working name in all documentation, code identifiers (`shacheni`) and the app. The display name still comes from configuration/localization, and **no domain is purchased or configured yet** — every URL/host is configuration (see architecture doc, "Configuration & domain independence").
> **Version:** v0.3 — specification update after the second round of confirmed decisions. **No code written.**
> **Date:** 2026-10-02
> **Phases 1–3 (discovery, PRD, flows & screen specs) are complete. Next: Phase 4 (UI/UX) and Phase 5 (database) after your approval.**

## Document map

| File | Contains |
|---|---|
| **PRD.md** (this file) | Vision · roles · problems · value · MVP definition · cross-cutting requirements · user stories · **business rules** · **state machines** · notifications · analytics · success metrics |
| [PRD-flows-screens.md](PRD-flows-screens.md) | **24 user flows** (each with screens, actions, permissions, DB changes, notifications, errors, security checks) · information architecture · **~57 screen specifications** (Hebrew RTL-first) |
| [PRD-data-security-architecture.md](PRD-data-security-architecture.md) | **Database schema** (PKs, FKs, constraints, indexes, RLS, functions, triggers) · **security model** · **backend recommendation & Supabase setup** · Flutter architecture · payment abstraction · localization · configuration & domain independence · ownership & continuity |
| [PRD-decisions-roadmap.md](PRD-decisions-roadmap.md) | Decision log (finalized / applied defaults / open) · risks · **15-phase roadmap** · post-MVP backlog |

**Conventions**

- *Requester* = resident who needs something. *Provider* = resident who offers something (parking holder, package helper).
- Money: **ILS**, integer agorot (`amount_minor`; 1000 = ₪10.00). **The MVP never processes or holds money** (see §5.4 and BR-F2).
- Timestamps stored in UTC (`timestamptz`), displayed in the building's timezone (`Asia/Jerusalem`).
- **[CONFIG]** = tunable default in `building.settings`, not hard-coded. Defaults are collected in the architecture doc (§9.2 `building`).
- Rule IDs `BR-xx` are referenced by flows, schema and tests. **[DB]** enforced by the database itself; **[RPC]** by server-side functions; **[UI]** UX only.
- "Finalized (F#)", "Proposed default (P#)" and "Open (O#)" refer to the decision log.

## What changed in v0.3 (this version)

| Area | v0.2 | v0.3 |
|---|---|---|
| Name | Binyan (working) | **Shacheni** (שכני); domain deferred, all URLs configurable |
| Admin model | Platform admin + ≥ 2 building admins, no self-approval | **Pilot = one person is Platform admin *and* the only Building admin.** No second admin required; **the admin may approve their own membership** (and, by default, own parking assignment) through an explicit, audited switch `allow_admin_self_review` that can be turned off when more admins exist |
| Multi-admin | Appointment, invitations | **Not implemented.** No admin appointment RPC/UI; the creator of a building becomes its building admin automatically. Schema stays ready for more admins |
| Building lifecycle | draft → pending_agreement → active ⇄ suspended | **draft → active ⇄ suspended**; the owner creates and activates directly (building agreement acceptance recorded at activation) |
| Committee | Consent a pilot gate | **Not required**; nothing blocks creation/activation |
| Legal | Draft placeholders | **TODO placeholders only — no invented legal text.** Versioning, acceptance records (user, type, version, timestamp) and re-acceptance gate are built |
| Package leave-at-door | Consent-gated "leave at place" fallback, note | **Explicit delivery method "leave near apartment door"**: requester must authorize it; helper must take an **in-app photo as proof**; stored with timestamp and uploader; viewable by the requester (and, in a dispute, the admin); retention-limited |
| Backend | Supabase (assumed) | **Evaluated and re-confirmed**, with dev/prod separation, storage buckets, backups, and an exit strategy (architecture doc) |
| Ownership | Generic | Apple **individual** account, Google Play and GitHub accounts owned by you; developers are invited only |
| Admin screens | 14 + 3 platform | **12 + 2** (activity views merged; building detail folded into the buildings list) |

## What changed in v0.2

| Area | v0.1 | v0.2 |
|---|---|---|
| Scope | One building, multi-building later | **Backend and DB are multi-building now**; UI focuses on the pilot building. Only authorized admins create buildings |
| Building setup | Seeded by SQL | **Admin-defined authoritative lists** of apartments and parking spaces; building activation requires a building-agreement acceptance |
| Users | `user_profile` with one building | Global `profile` + **`building_membership`** (resident request → verified resident) |
| Verification | Name/phone/apartment (+ invite code) | Apartment **and parking space picked from authoritative lists**; join by **building code/QR**; admin can **approve / reject / request more info** |
| Parking ownership | Space belongs to an apartment | **`parking_assignment`**: resident *requests*, admin *approves*; one active holder per space; reassignable |
| Reservations | accepted → paid → confirmed | requested → accepted → **requester confirms** → active → completed |
| Payments | Held funds (escrow-style), refunds, fees on late cancel | **No money handled.** Mock lifecycle: payer **"I paid"** → payee **"Payment received"**; refunds are separate records; **no cancellation fees** |
| Transactions | One lifecycle | **Two lifecycles**: service (reservation/request) and transaction (service + settlement) |
| Handoff | Code + simple no-code fallback | Code, **arrival ping, remote code, consent-based leave-at-place** (superseded in v0.3 by photo-proof door delivery), lock/regenerate, escalation |
| Legal | Checkboxes | **Versioned legal documents + stored acceptances**, building agreement, resident declarations |
| Language | Hebrew-first suggested | **Hebrew default + RTL, English LTR**, device-language detection, full localization architecture |
| Admin | One role | **Platform admin** (creates buildings) and **building admin** (runs a building), least-privilege data access |
| Ownership | Not covered | **You own every production resource**; documented continuity plan |
| Privacy | Apartment shown to counterparties | Apartment revealed **only when needed** (delivery: requester's apartment to the accepted helper); phone/WhatsApp only to the counterparty while a transaction is live |

---

## 1. Product vision

### The platform
**Shacheni is a private community platform for residents of apartment buildings.** Each building is a closed, verified community. Residents share resources and help each other with small services. Long term it becomes the digital layer of the building; the first two use cases are:

1. **Parking sharing** — a resident's idle space is used by a neighbor who needs one.
2. **Package pickup sharing** — a neighbor already going to a pickup point collects a package for another.

### The problem
Idle resources and small unmet needs coexist inside one building, but WhatsApp groups offer no structure, no trust, no guarantees against double-booking, no price clarity, and no record. Asking a neighbor for a favor or paying them is socially awkward.

### The solution
A verified, building-only app: **authoritative building data (apartments, parking spaces) → verified residents → verified parking holders → structured transactions with a simple payment record, handoff security and reputation.**

> *"Help your neighbors, save time and money, and make better use of resources that already exist inside your building."*

### What the MVP is for
A **validation experiment in ONE real building**: *will residents repeatedly use an app to share parking and help each other with package pickups?* Everything in scope serves that question. The multi-building backend exists so success does not require a rewrite — not so we can ship multiple buildings now.

---

## 2. Users & roles

| Role | Who | Scope | Key capabilities |
|---|---|---|---|
| **Platform admin** | **You — the only one in the MVP.** A single `platform_admin` row seeded by SQL; there is no feature to add more | Whole platform | Create buildings; define building lists; suspend/reactivate a building; platform statistics |
| **Building admin** | **You — the only one in the MVP.** Created automatically as the creator of the building; must accept the building agreement | One building | Manage building info, apartments & parking spaces; review join requests (approve / reject / request info); review parking-assignment requests, end/reassign spaces; disable residents; view listings, package requests, transactions; resolve disputes; building statistics |
| **Resident** | Approved member of a building | One building (MVP) | Parking: publish (own assigned spaces), search, request/reserve. Packages: request, offer, deliver. Pay/receive (mock), rate, view history |
| **Applicant** | Authenticated user without an approved membership (new, pending, info requested, rejected, disabled) | Own application only | Edit/complete own application, see status, read legal documents. **No building data** |

**MVP admin model (intentionally simple):** *Platform admin → you · Building admin → you · Resident → any approved resident.* The same person holds both admin roles and is typically also a resident. The two roles remain **separate in the code and in the data-access rules** (so a future second admin or a non-resident platform operator needs no redesign), but the pilot does not require a second admin, committee approval, or an admin-appointment feature.

**Self-review (decided):** the sole admin may approve their own resident membership. Because the pilot has exactly one admin, this is implemented as an **explicit, audited switch** — `building.settings.allow_admin_self_review` (default `true` for the pilot) — which applies to the admin's own membership application and, by default, their own parking assignment and any dispute they are party to; every such action is flagged `self_review = true` in the audit log. Turning the switch off restores strict "nobody reviews themselves" with no code change (BR-A6). Ordinary residents can never review anything.

### Personas (transacting)

| Persona | Needs | Success |
|---|---|---|
| **Parking provider** — "Dana, travels often" | Earn from an idle space with no hassle or risk | Listing in < 1 min, no double-booking, no negotiation |
| **Parking requester** — "Yossi, second car/guests" | Space for tonight / this week / this month | Finds one in < 30 s |
| **Package requester** — "Noa, works late" | Get a package without losing an evening | Safe handoff, no private data leaked |
| **Package helper** — "Amir, going to the mall anyway" | Earn a few shekels on a trip already planned | Sees relevant requests at a glance, simple handoff |
| **Building admin** — you, in the pilot | Keep the community real and safe with minimal work | Approves in seconds, resolves a dispute, sees whether it works |

---

## 3. User problems

| # | Problem | Our answer |
|---|---|---|
| UP1 | My parking space sits idle | One-minute listing for my *assigned* space |
| UP2 | I need extra parking sometimes | Search by time across neighbors' spaces |
| UP3 | Double-booking / confusion | Database-enforced no-overlap + explicit statuses |
| UP4 | I don't trust strangers (or people claiming spaces they don't own) | Verified residents, admin-verified parking assignment, ratings |
| UP5 | I can't collect my package in time | Request a neighbor with a reward |
| UP6 | I'm going there anyway | Browse open requests, one-tap offer |
| UP7 | Awkwardness about money | Visible price up front, simple paid/received record |
| UP8 | "Did the package reach me?" | Handoff code, or — only if I allow it — leaving it near my door **with a photo as proof** |
| UP9 | Privacy | Minimal disclosure, only when needed, only to the counterparty |

## 4. Value proposition

Provider: turn idle capacity into income/goodwill with minutes of effort and full control. Requester: nearby, cheap, clear. Everyone: a **trusted** layer — verified, rated, recorded, private. Versus WhatsApp: structure, guarantees, trust, privacy, memory.

---

## 5. MVP definition

### 5.1 Included

| # | Capability | MVP scope |
|---|---|---|
| 1 | Accounts | Phone + SMS OTP; no email collected (decision log P1) |
| 2 | Legal | **Versioned legal-document store with TODO placeholders** (Terms of Service, Privacy Policy, community rules, resident declaration, building agreement); stored acceptances; re-acceptance gate. **No legal text is written by engineering** |
| 3 | Building administration | You (platform admin = building admin) create and activate the building directly; manage the authoritative apartment and parking-space lists |
| 4 | Resident verification | Join by building code/QR → application → admin approve/reject/request info |
| 5 | Parking assignment | Resident requests association with an existing space; admin approves, ends, reassigns |
| 6 | Parking sharing | Publish listing (own assigned space), cancel if unreserved |
| 7 | Parking reservations | Search by time, request or instant-reserve, owner accepts, requester confirms, double-booking protection, statuses |
| 8 | Package pickup | Requests, offers, accept, collected, delivered, completed; handoff code; code by phone; **explicit "leave near apartment door" method with mandatory photo proof** |
| 9 | Transactions & payments | `Transaction` record per deal; **mock payment lifecycle** behind a `PaymentProvider` abstraction; refunds as separate records |
| 10 | Reputation | 1–5 stars + optional review, mutual, post-completion, aggregates |
| 11 | Notifications | Push (FCM) + in-app center, actionable |
| 12 | Profiles & history | Limited public profile, own profile, transaction history |
| 13 | Dispute handling | Report a problem → admin resolution (no funds involved) |
| 14 | Localization | Hebrew default (RTL) + English (LTR) from day one |
| 15 | Home screen | Action-first feed |

### 5.1a MVP priorities (in order)
1. Easy resident registration · 2. Fast manual approval · 3. Trusted resident identity · 4. Parking sharing · 5. Package pickup sharing · 6. Simple mock payments · 7. Secure handoff · 8. Delivery photo proof · 9. Ratings and reputation · 10. Clean Hebrew RTL experience.
When scope or time is tight, anything not serving this list is cut first. The product must stay simple enough to validate the core idea before more administration features are added.

### 5.2 Intentionally excluded (binding)

Multi-building **UI** (building switcher, discovery, per-user multiple memberships) · **additional platform admins, additional building admins, any admin-appointment/invitation mechanism, a second-approver requirement** (post-MVP backlog) · building-committee approval workflows · real money handling of any kind (holding funds, card payments, Bit/PayBox API integrations) · in-app chat · cancellation fees/penalties · partial-window booking, price proration, recurring listings, saved searches · visitor/guest parking, EV charging, gate integrations · photos other than the **delivery proof** (and optional profile picture) · couriers, insurance, ID verification · maps/geolocation · community feed, announcements, marketplace · web app, tablets, offline mode · additional languages · in-app support chat · gamification beyond ratings · email collection · **domain purchase/configuration and universal/app links** (deferred; configuration-ready).

### 5.3 Non-functional targets
Cold start < 2.5 s; lists < 1 s after first load; **zero double-bookings (DB-enforced)**; no unauthorized read of private fields (RLS-tested); iOS 15+/Android 8+ **[CONFIG: confirm at project creation]**; accessible (dynamic type, contrast ≥ 4.5:1, 44 pt targets); **fully RTL-correct**.

### 5.4 Cross-cutting product requirements

**Payments (finalized).** The MVP does **not** process real money and does **not** hold funds. The app keeps a *payment record* and simulates the lifecycle: the payer taps **"I paid"**, the payee taps **"Payment received"**; the transaction is then financially settled for MVP purposes. All payment logic sits behind a `PaymentProvider` abstraction so Bit, PayBox, cash flows, or a real provider can be added later without rewriting the transaction system. The UI must state clearly that payment is arranged directly between neighbors.

**Legal.** Legal text lives in `legal_document` (versioned, localized, effective-dated) — never in code. Acceptances are append-only records (user, document type, version, timestamp). Required: Terms of Service + Privacy Policy (every user, app level), building agreement (building admin, per building, before activation), community rules + resident declarations (each applicant, per application). A new document version triggers a re-acceptance gate. **You will write the legal agreement / Terms of Service later.** Until then every document body is the literal placeholder `TODO — legal text to be provided by the owner` (version `0.0-todo`, Hebrew and English). The application must **not** contain invented legal text. Publishing the real text later is a data operation (a new version row), which automatically triggers re-acceptance by everyone. Launch checklist item: placeholders are replaced before real residents join.

**Localization.** Hebrew is default and RTL; English is LTR. No hard-coded user-facing strings. Language resolves as: user's saved choice → device language (Hebrew→Hebrew, English→English) → Hebrew. Manual switch in Settings. Notifications and legal documents follow the recipient's language.

**Ownership.** Source repository (your GitHub), your **individual** Apple Developer account, your Google Play Developer account, Supabase, Firebase, signing keys and store listings are owned by **you**; developers get invited roles only (see architecture doc, "Ownership & continuity"). The domain will be bought later by you; nothing in the product hard-codes a domain.

**Delivery photo proof.** Leaving a package near the requester's apartment door is an **explicit delivery method, never an automatic fallback**. It requires (1) the requester's permission — given when creating the request or later in-app — and (2) a **photo taken in the app by the helper**, stored with timestamp, uploader and delivery confirmation, viewable by the requester as evidence. Without the requester's permission the server refuses to complete a delivery this way (BR-E6, BR-E10).

---

## 6. User stories

All stories assume an **approved resident** unless stated. AC = acceptance criteria.

### Epic A — Building setup (platform admin / building admin)

**A1 — As the platform admin, I want to create a building with its name, address, number of apartments and parking spaces so a community can be set up.**
- AC: building created in `draft`; only platform admins can create; duplicate (name+address) rejected; declared counts are positive integers.

**A2 — As an admin, I want to define the building's actual apartments and parking spaces so verification and ownership are authoritative.**
- AC: add via range generator (e.g., `101–120`, `P01–P40`), pasted list, or CSV; labels unique per building; apartments may carry floor; spaces may carry level/notes; preview before saving; later edits allowed (rename, deactivate; never delete when referenced).

**A3 — As the platform admin (the owner), I automatically become the building admin of every building I create, so I can run it without any appointment step.**
- AC: `create_building` also creates the creator's `building_admin` row; no UI or RPC to add other admins exists in the MVP (post-MVP backlog); audit-logged.

**A4 — As the building admin, I want to accept the building agreement and activate the building in one step.**
- AC: acceptance stored (user, building, document type, version, timestamp — against the current placeholder or final text); activation only if ≥ 1 apartment, declared counts match, agreement version current; join code generated; building becomes `active` immediately (no committee or second-party approval).

**A5 — As a building admin, I want to share a join code/QR so residents can find the building.**
- AC: code displayed with QR + printable poster; code can be rotated/disabled; code never grants access by itself.

### Epic B — Registration & verification

**B1 — As a new user, I want to sign up with my phone number.**
- AC: Israeli mobile → OTP; resend cooldown 30 s; ≤ 5 sends/hour; session persists.

**B2 — As a new user, I must accept the Terms of Service and Privacy Policy.**
- AC: documents viewable in full; acceptance stored with version; re-acceptance required when versions change.

**B3 — As a new user, I want to find my building by code or QR.**
- AC: valid code shows building name + address; invalid code error; ≤ 10 attempts/hour; no building list is ever shown.

**B4 — As an applicant, I want to apply to my building by selecting my apartment and (optionally) my parking space(s) from the building's lists, with my name and optional photo.**
- AC: apartment is a required pick-list (no free text); parking is an optional multi-pick from the list; required declarations (information accurate, I am a resident, apartment correct, parking correct if applicable, community rules, ToS, Privacy); submit creates a `pending` application and N-events to admins.

**B5 — As an applicant, I want to see the status of my application and respond if the admin needs more information.**
- AC: states pending / more info requested / approved / rejected; free-text response returns it to `pending`.

**B6 — As a building admin, I want to see an applicant's name, phone, apartment, requested parking, and anything unusual (e.g., space already assigned to someone else) so I can verify them.**
- AC: Approve / Reject (reason) / Request info (message); the sole admin **may approve their own application** (flagged and audit-logged, `allow_admin_self_review`, BR-A6).

**B7 — As a building admin, I want to disable a resident.**
- AC: access removed immediately; open listings/requests cancelled; in-progress transactions flagged; counterparties notified; reversible.

**B8 — As a user, I want to delete my account.**
- AC: blocked while transactions are in progress; otherwise anonymizes the profile ("Former resident"), keeps transaction records.

### Epic C — Parking assignment

**C1 — As a resident, I want to request association with a parking space of my building, so I can share it.**
- AC: pick from the building's spaces; the request is never visible to other residents; duplicate open request blocked.

**C2 — As a building admin, I want to verify that the space belongs to that resident/apartment, then approve or reject.**
- AC: the screen shows whether the space is currently assigned to someone else; approval creates an active assignment; rejection with reason; the sole admin may approve their own request (flagged + audit-logged, BR-A6).

**C3 — As a building admin, I want to end or reassign a space.**
- AC: ending/reassigning auto-cancels unreserved listings; if future reservations exist I must explicitly choose to cancel them (no fee) or the action is refused; affected users notified.

**C4 — As a resident, I want to see my spaces and request statuses.**
- AC: list: active / requested / rejected / ended; empty state explains how to request.

### Epic D — Parking provider

**D1 — As a resident, I want to publish one of my assigned spaces as available.**
- AC: only spaces with my *active* assignment; start/end date-time, price (₪, may be 0), optional description, approval toggle (default: I approve); end > start, start in the future, ≤ 90 days, no overlap with my live listings for that space.

**D2 — As a provider, I want to review and accept/decline requests.**
- AC: request shows requester's limited profile; accepting declines overlapping requests; unanswered requests expire.

**D3 — As a provider, I want to cancel unreserved availability.**
- AC: allowed while `available`; pending requests auto-declined and notified.

**D4 — As a provider, I want to cancel a confirmed reservation with clear consequences.**
- AC: sheet states: reservation cancelled, requester notified, refund record created if the requester already paid, reliability counter increases.

**D5 — As a provider, I want to record that I received payment.** (see Epic H)

### Epic E — Parking requester

**E1 — As a resident, I want to search by date/time and see available listings with price and availability.** AC: results fully cover the requested window; sorted by fit then price; empty state offers "show all upcoming".
**E2 — As a requester, I want to request or reserve instantly** (per listing mode). AC: one listing = one whole window.
**E3 — As a requester, I want to confirm the accepted reservation to commit.** AC: confirm window; confirmation creates the transaction.
**E4 — As a requester, I want to be protected from double-booking.** AC: conflicting attempt fails with `SLOT_TAKEN` and alternatives are offered.
**E5 — As a requester, I want to cancel with clear consequences.** AC: cancel sheet; refund record if already paid.
**E6 — As a requester, I want reminders.** AC: push 1 h before start; 30 min before end.

### Epic F — Package requester

**F1 — Create a pickup request** (location, description, deadline, reward, notes, optional pickup reference, handoff place, and an optional permission **"Leave the package near my apartment door"** — default off, explained as "the helper must send me a photo"). AC: deadline ≥ 30 min, ≤ 7 days; reward ≤ cap; prohibited-items acknowledgement.
**F2 — Receive offers and accept exactly one.** AC: other offers auto-rejected; handoff code appears for me only; helper's phone revealed.
**F3 — Know when the package is collected / the helper has arrived.** AC: push events.
**F4 — Verify the handoff with my code, or explicitly allow door delivery.** AC: I can share the code by phone; I can allow "leave near my apartment door" at creation or later in-app (e.g., when the helper arrives); regenerate the code (max 3).
**F4b — See the delivery photo as proof.** AC: when a package is left by the door I get a notification with the photo, the time and who took it; I can **Confirm received** or **Report a problem**; silence for 24 h auto-confirms.
**F5 — Cancel (before collection).** AC: consequences shown.
**F6 — Report a problem.** AC: available from collected state until 7 days after completion.

### Epic G — Package helper

**G1 — Browse open requests.** AC: location, deadline, reward, requester's limited profile; own requests excluded.
**G2 — Offer with optional planned time/message; withdraw while pending.**
**G3 — After acceptance, see what I need (pickup reference, requester's apartment, handoff place, contact).**
**G4 — Mark collected; tell the requester I've arrived; enter the code.** AC: 5 wrong attempts → 15-min lock; wrong attempts never consume on network errors.
**G5 — Deliver by leaving the package near the door, only when allowed, with photo proof.** AC: the option is available only if the requester allowed it; I must take the photo inside the app (no gallery); delivery is confirmed only after the photo is uploaded; without permission the server refuses.
**G6 — Escalate when I cannot deliver.** AC: if the requester is unreachable and has not allowed door delivery, I keep the package, tap **Report a problem**, and the case escalates; nothing is ever marked delivered silently.

### Epic H — Payments (mock)

**H1 — As a payer, I want to see exactly what I owe and tap "I paid".**
**H2 — As a payee, I want to confirm "Payment received", or say "Not received", or waive.**
**H3 — As a user, I want a clear record of what was paid, to whom, and when.**
**H4 — As a developer/owner, I want to swap payment methods later.** AC: all payment logic goes through a provider abstraction; the transaction system only depends on `payment.status`.

### Epic I — Ratings & reputation

**I1 — Rate the other party after a transaction is completed (1–5, optional comment).** AC: one per user per transaction; 14-day window; immutable.
**I2 — See reputation before transacting.** AC: average, rating count, completed transactions, "New neighbor" until 3 ratings.
**I3 — Fairness.** AC: ratings hidden until both submitted or window closes; non-participants cannot rate (DB-enforced).

### Epic J — Notifications, profile & settings

**J1 — Receive actionable push + in-app notifications (§13).**
**J2 — Control optional notifications; change language manually; read legal documents; delete account.**
**J3 — View history with amount, date, counterparty, status.**
**J4 — Maintain a profile that proves I'm a verified resident.**

### Epic K — Administration

**K1** Review applications · **K2** Review parking assignments · **K3** Manage residents (disable/enable) · **K4** Manage apartments & spaces · **K5** View listings, package requests, transactions (no secrets) · **K6** Resolve disputes · **K7** View building statistics.
- AC (all): role-gated server-side, building-scoped, audit-logged, least-privilege data.

---

## 10. Business rules

Legend: **[DB]** database-enforced · **[RPC]** server function · **[UI]** UX only.

### A — Buildings, roles, administration
- **BR-A1 [RPC/DB]** Only a platform admin can create a building. `authenticated` has no INSERT/UPDATE privilege on `building`; creation is only through `create_building()`.
- **BR-A2 [RPC]** Building lifecycle `draft → active ⇄ suspended`. Activation requires: ≥ 1 active building admin (the creator), ≥ 1 active apartment, declared apartment/parking counts equal the list sizes, and the building admin has accepted the **current** building agreement (placeholder or final). **Nothing else gates activation** — no committee or second-party approval. Residents can apply only to `active` buildings; `suspended` buildings are read-blocked for residents.
- **BR-A3 [DB/RPC]** Apartments and parking spaces are defined only by admins. Users select from lists; free-text apartment or space values are impossible by schema (foreign keys).
- **BR-A4 [DB]** Apartments/spaces referenced by memberships, assignments or listings cannot be deleted; they are deactivated (`is_active = false`), which blocks new joins/assignments/listings on them.
- **BR-A5 [DB/RPC]** Least privilege: a platform admin sees no resident PII and no transactions by default; a building admin sees only the minimum personal data needed (see admin data access matrix in architecture doc) and **never** handoff codes, pickup references, or other buildings' data.
- **BR-A6 [DB]** **Self-review is controlled by one switch.** `building.settings.allow_admin_self_review` — **`true` in the pilot** (you are the only admin and may approve your own membership, your own parking assignment, and resolve a dispute you are party to). While it is `true`, every self-review is permitted **only for a user who holds the building-admin role**, and the audit row is flagged `self_review = true`. When it is `false` (once more admins exist), the reviewer of a membership application, parking assignment or dispute must differ from the subject user, enforced by trigger. Ordinary residents can never review anything under either setting. The switch is editable only by the platform admin.
- **BR-A7 [RPC]** Every admin action and every contact-reveal is written to `audit_log` (append-only).
- **BR-A8 [RPC]** A user must have accepted the **current** building agreement to exercise building-admin powers.

### B — Membership & verification
- **BR-B1 [DB/RPC]** Flow: account → accept ToS/Privacy → join code → application. In the MVP a user can have **one non-terminal membership** (pending / info_requested / approved) — a partial unique index that can be dropped when multi-building UI ships.
- **BR-B2 [DB]** The selected apartment must be an active apartment of that building (composite FK `(apartment_id, building_id)`). More than 6 residents per apartment **[CONFIG]** is flagged to the admin.
- **BR-B3 [DB]** Only `approved` memberships of an `active` building can read community data (RLS). Pending/info_requested/rejected/disabled users see only their own application, building name, and legal documents.
- **BR-B4 [RPC]** An application requires current legal documents accepted and all resident declarations confirmed; each is stored with document version and timestamp.
- **BR-B5 [RPC]** Changing apartment after approval creates a new application; the old membership stays approved until the new one is decided (admin sees both).
- **BR-B6 [RPC]** The join code only *resolves* a building. It never grants access. Attempts are rate-limited (10/hour/user **[CONFIG]**); it returns only that building's name/address and its pick-lists.
- **BR-B7 [RPC]** Disabling a membership revokes access immediately, cancels the user's open listings and open/offer_received requests, withdraws pending offers, and flags in-progress transactions for admin review.
- **BR-B8 [RPC]** `request info` pauses the application (`info_requested`); the applicant's reply returns it to `pending`.

### C — Parking assignment
- **BR-C1 [DB]** A resident can never create a parking space (INSERT only by admins). A resident can only create a *request* (`parking_assignment.status = 'requested'`).
- **BR-C2 [RPC/DB]** Only an admin of that building may approve; approval requires the requester's membership to be `approved` and the space `is_active`; reviewer ≠ requester unless BR-A6 allows self-review.
- **BR-C3 [DB]** At most **one `active` assignment per space** (partial unique index). A space may be unassigned; an apartment may have 0..n spaces; a resident may hold 0..n spaces.
- **BR-C4 [RPC]** A request for a space that is currently actively assigned to someone else is allowed (the admin may be reassigning) but is flagged to the admin; the resident is **not** told who holds it.
- **BR-C5 [RPC]** Ending/reassigning an assignment: `available` listings for the space are cancelled and their pending requests declined; if reservations in `accepted/confirmed/active` exist in the future, the admin must pass `cancel_future_reservations = true` (reservations are cancelled, no reliability penalty to the provider, refund records created if paid) — otherwise the action is refused.
- **BR-C6 [RPC/DB]** A listing can be created only by the holder of an **active** assignment for that space; the listing stores `assignment_id`, and a trigger verifies the assignment is active and belongs to the owner.

### D — Parking listings & reservations
- **BR-D1 [DB]** No overlapping reservations in status `accepted/confirmed/active/completed` for one space (exclusion constraint). Back-to-back allowed.
- **BR-D2 [DB]** No overlapping live listings (`available/reserved/active`) for one space.
- **BR-D3 [DB/RPC]** `end_at > start_at`; ≤ 90 days **[CONFIG]**; `start_at` in the future at creation.
- **BR-D4 [DB/RPC]** Price integer agorot, 0 ≤ price ≤ ₪2,000 **[CONFIG]**. Price 0 = free; no payment row is created.
- **BR-D5 [RPC]** MVP: a reservation covers the **whole listing window**. Reservation rows carry their own start/end so partial booking is a later, non-breaking change.
- **BR-D6 [RPC]** A resident cannot reserve their own listing.
- **BR-D7 [RPC]** Accepting a request (or an instant reservation) declines all other overlapping pending requests.
- **BR-D8 [RPC]** The provider can cancel a listing only while it has no `accepted/confirmed/active` reservation; pending requests are auto-declined.
- **BR-D9 [RPC]** Timers **[CONFIG]**: unanswered request expires at `min(requested_at + 12 h, start_at − 1 h)`; an accepted reservation unconfirmed after `min(accepted_at + 2 h, start_at − 15 min)` expires and the listing becomes `available` again.
- **BR-D10 [RPC]** Instant-book listings skip the owner approval; the requester's confirmation happens at reservation time (status goes directly to `confirmed`).

### E — Package pickup
- **BR-E1 [DB/RPC]** Deadline ≥ now + 30 min and ≤ 7 days; reward 0–₪100 **[CONFIG]**.
- **BR-E2 [RPC]** A resident cannot offer on their own request; one live offer per helper per request.
- **BR-E3 [DB]** At most one `accepted` offer per request (partial unique index). Accepting rejects all other pending offers.
- **BR-E4 [RPC/RLS]** Disclosure: open requests are visible to approved residents of the building with public fields only. After acceptance, the **accepted helper** additionally sees the requester's apartment, the pickup reference and handoff place; the requester sees the helper's phone. Nobody else ever sees them.
- **BR-E5 [RPC]** **Handoff code:** random 4-digit code generated when the offer is accepted; visible **only to the requester**; never returned by any list/search/push; verified only server-side by `confirm_handoff`. **5 incorrect attempts → locked 15 minutes** **[CONFIG]**; the lock is server-side; network errors do not consume attempts; after the lock, attempts reset; 3 lock cycles flag the request to admins. The requester can **regenerate** the code (≤ 3 times), which resets attempts.
- **BR-E6 [RPC]** **Delivery methods** (flows F16/F17). (1) **Code in person** — default. (2) **Code by phone** — the requester reads the code to the helper remotely (someone else may receive the package); same verification as (1). (3) **Leave near the apartment door with photo proof** — an **explicit delivery method, not an automatic fallback**: it is available **only if the requester authorized it** (`door_delivery_allowed` set when creating the request, or `door_delivery_approved_at` set later by the requester in-app). Without authorization the server rejects the completion (`DOOR_DELIVERY_NOT_ALLOWED`). It also requires the photo proof of BR-E10. After a door delivery the request is `delivered` and the requester has 24 h to confirm or dispute. (4) **No method possible** (requester unreachable and door delivery not authorized) → the helper keeps the package; "Report a problem" is the only route; an automatic dispute opens 24 h after the deadline. **A delivery can never be completed without either the correct code or (authorization + photo).**
- **BR-E7 [RPC]** A door delivery (method 3) auto-confirms 24 h after delivery **[CONFIG]** unless disputed; reminders at +1 h, +6 h, +20 h.
- **BR-E8 [RPC/UI]** Prohibited items (cash, IDs, medication, illegal items, declared value > ₪1,000 **[CONFIG]**) must be acknowledged; admins may remove requests.
- **BR-E9 [RPC]** A collected package cannot be cancelled; it must be delivered or disputed.
- **BR-E10 [DB/RPC/Storage]** **Delivery photo proof.** (a) Allowed only for the accepted helper, while the request is `collected` and door delivery is authorized (BR-E6). (b) The photo is taken **inside the app** (camera only; no gallery picker), re-encoded as JPEG (≤ 1600 px, ≤ 3 MB, location metadata stripped) and uploaded to a **private** storage bucket. (c) The RPC `submit_door_delivery` verifies the uploaded object exists at the expected path, creates one `delivery_proof` row (**request, uploader, storage path, size, hash, device capture time, server upload timestamp**) and in the same transaction sets the request to `delivered` with `handoff_method = door_photo` and `delivered_at` (the **delivery confirmation**). (d) Exactly one proof per request; proof rows are append-only. (e) Readable only by the requester, the uploading helper, and — only while a dispute on that request is open — the building admin; always through short-lived signed URLs. (f) The image file is purged `proof_retention_days` (30 **[CONFIG]**) after the request completes (or after a dispute is resolved); the metadata row remains as evidence that a proof existed. (g) The photo is *evidence*, not an authenticity guarantee: the controls are requester authorization, the 24 h review, and disputes.

### F — Transactions & mock payments
- **BR-F1 [RPC/DB]** **Two lifecycles.** The *service* lifecycle (reservation / delivery request) and the *transaction* lifecycle (deal + settlement). A transaction is created when the requester commits: parking — at reservation `confirmed`; delivery — at offer `accepted`. `amount_minor`, parties and type are immutable from creation.
- **BR-F2 [RPC]** **The MVP never processes or holds money.** No authorization/hold/escrow statuses exist. The payment record documents what neighbors arrange between themselves.
- **BR-F3 [RPC]** Payer = the requester; payee = the parking holder / helper. Platform fee = 0 (`platform_fee_minor` reserved).
- **BR-F4 [RPC]** Payment settlement: payer taps **I paid** (`payer_confirmed`); payee taps **Payment received** (`settled`). The payee may confirm even if the payer has not tapped. **Not received** returns the payment to `pending` and notifies the payer; 3 such events open a dispute automatically. The payee may **waive** (no payment needed).
- **BR-F5 [RPC]** Timing **[CONFIG]**: payer may pay at any time while the transaction is live. After service completion the payer is reminded at +24 h and +72 h. If `payer_confirmed` and the payee is silent for 72 h → auto-settled (`settled_via = 'auto'`). If still unpaid 7 days after service completion → the transaction completes with the payment `cancelled (expired_unpaid)`, the payer gets an `unpaid` counter, the payee is told how to dispute.
- **BR-F6 [DB]** A transaction becomes `completed` when the service is complete **and** the payment is `settled`, waived, or `expired_unpaid` (or amount is 0). A `completed` or `cancelled` transaction, and a `settled` payment, are **immutable**; later corrections (refunds, disputes) are **separate records** (BR-J1).
- **BR-F7 [RPC]** Cancelling a transaction cancels an unsettled payment. If the payment was already `settled`, a **refund record** (`payment.kind = 'refund'`, reversed roles, full amount) is created and follows the same *I paid / Payment received* lifecycle.
- **BR-F8 [RPC]** **No cancellation fees** in the MVP. Late cancellations affect only reputation counters (admin-visible).
- **BR-F9 [Arch]** All payment behavior goes through the `PaymentProvider` abstraction. Business logic depends only on `payment.status` events; adding Bit/PayBox/cash/real provider must not change transaction code.

### G — Cancellation matrix

| Situation | Who | Result | Reliability counter |
|---|---|---|---|
| Parking request (not accepted) | Requester | Withdrawn | — |
| Parking accepted, not yet confirmed | Requester or provider | Cancelled; listing → available | — |
| Parking confirmed, **before the late threshold** (short window < 24 h: 1 h before start; ≥ 24 h: 24 h before start) | Requester | Cancelled; payment cancelled, or refund record if settled | — |
| Parking confirmed, **inside the late threshold** | Requester | Same as above | late-cancel +1 |
| Parking confirmed | Provider | Cancelled; listing cancelled; refund record if settled; requester notified | owner-cancel +1 (admin flagged if < 2 h before start) |
| Parking active/started | Anyone | **Cannot cancel** → Report a problem | — |
| Parking assignment ended by admin (BR-C5) | Admin | Reservations cancelled; refund records if settled | none to provider |
| Package, before offer accepted | Requester | Cancelled; offers expire | — |
| Package accepted, not collected | Requester | Cancelled; payment cancelled/refund record | requester-cancel +1 |
| Package accepted, not collected | Helper (withdraw) | Request reopens if > 1 h to deadline, else expires | helper-cancel +1 |
| Package collected | Anyone | **Cannot cancel** (BR-E9) | — |
| Deadline passes, not collected | System | Request expires; payment cancelled | — |
| Collected, deadline passed | System | Alert requester + admin; auto-dispute after 24 h | — |

### H — Disputes
- **BR-H1 [RPC]** Either participant may open a dispute while the transaction is `in_progress` / `awaiting_settlement`, or up to **7 days after `completed`** **[CONFIG]**.
- **BR-H2 [RPC]** Opening a dispute on a live transaction moves it to `disputed`, which **freezes automation** (auto-complete, auto-settle, auto-confirm, unpaid expiry) and blocks ratings.
- **BR-H3 [RPC]** Only a building admin resolves; a building admin who is themself a party may resolve only while `allow_admin_self_review = true` (BR-A6; the resolution is flagged `self_review` in the audit log and shown as such to the other party). Outcomes: `payment_settled` (provider's claim upheld — payment marked settled), `payment_cancelled` (requester's claim upheld — payment cancelled; refund record if already settled), `no_action`, `warning`. A written note is mandatory. Decision is final in the MVP.
- **BR-H4 [RPC]** A dispute opened after `completed` never edits the transaction (BR-J1); remedies are separate payment records.
- **BR-H5** Target admin response: 48 h **[CONFIG]**; overdue disputes are highlighted.
- **BR-H6** Disputes show the admin only the disputed transaction's data, statements, timeline, rating comments of that transaction and — for door deliveries — the delivery photo proof (BR-E10) — not unrelated private data.

### I — Ratings
- **BR-I1 [DB]** Only the two parties of a `completed` transaction may rate each other; exactly one rating per party per transaction (`unique (transaction_id, rater_id)`); validated by trigger, not by the client.
- **BR-I2 [DB]** Stars 1–5; comment ≤ 280 characters; immutable (admin can hide an abusive comment).
- **BR-I3 [RPC]** Window = 14 days after completion; ratings stay hidden until both parties rated or the window closes.
- **BR-I4 [DB]** `rating_avg`, `rating_count`, `completed_count` live on `building_membership` and are maintained only by triggers. "New neighbor" is shown until 3 ratings.
- **BR-I5** A transaction in `disputed` status cannot be rated until resolved.

### J — Immutability & integrity
- **BR-J1 [DB]** `completed`/`cancelled` transactions are immutable except `updated_at`; `settled` payments and all `payment_event`, `legal_acceptance`, `audit_log`, `rating`, `delivery_proof` rows are append-only (the only permitted change to a proof row is the system setting `purged_at` when the image file is deleted by retention). Corrections are **new rows**.
- **BR-J2 [DB]** Terminal states of reservations, requests, offers, listings, assignments, memberships (rejected) are final.
- **BR-J3 [DB]** Clients have no INSERT/UPDATE/DELETE privilege on stateful tables; all writes are RPCs that take the actor from `auth.uid()`.
- **BR-J4 [DB]** Multi-building integrity: every child row repeats `building_id` and references its parent with a composite FK `(parent_id, building_id)`, so cross-building links are impossible.

### K — Privacy & disclosure
- **BR-K1** Other residents see only: first name + last initial, photo, rating, rating count, completed count, "Verified resident of <building>".
- **BR-K2** **Apartment number** of another resident is revealed only when necessary: in a delivery, the requester's apartment to the **accepted helper**, from acceptance until the transaction ends. In parking, apartments are never revealed.
- **BR-K3** **Phone / WhatsApp** of the counterparty is revealed (tap-to-call/WhatsApp, via RPC) only while the transaction is live (`in_progress`, `awaiting_settlement`, `disputed`), and each reveal is logged. No in-app chat.
- **BR-K4** Handoff code and pickup reference are never present in list endpoints, push payloads, analytics, or logs.
- **BR-K5** Admin phone visibility is limited to application review and resident management in their own building and is disclosed in the Privacy Policy (text TODO, owner-provided).
- **BR-K6** Delivery photos are visible only to the requester, the uploading helper and (during an open dispute) the building admin; they never appear in notifications' payloads (the notification only says a photo is available), analytics, or public profiles. The UI tells the helper to photograph only the package near the door and to avoid people and other residents' doors.

### L — Legal
- **BR-L1** ToS and Privacy must be accepted (current versions) before any other app function. A new version blocks the app until re-accepted.
- **BR-L2** Acceptance rows store user, document type, version, timestamp (+ locale, app version) and are append-only.
- **BR-L3** Resident declarations (accurate information, I am a resident, apartment correct, parking correct if applicable, community rules understood) are stored with the application, versioned.
- **BR-L4** The building agreement is accepted by the building admin before activation and re-accepted on a new version.
- **BR-L5** **No legal text in code or in engineering-authored files.** Every legal document body is stored in `legal_document`; until the owner supplies the real text it is the placeholder `TODO — legal text to be provided by the owner` (version `0.0-todo`, he + en). Publishing a new version (a database operation by the owner) makes it current and triggers re-acceptance for all affected users and for the building admin. A **launch checklist** item blocks the pilot until placeholders are replaced.

### N — Configuration
- **BR-N1** No domain, host name, store URL or brand string is hard-coded. App name, link base URL, legal URLs, support contact and Supabase endpoints come from per-flavor configuration and localization; changing the domain later requires only configuration and DNS/association files.

### M — Localization
- **BR-M1** Every user-facing string comes from localization resources; DB/server returns codes and parameters, not sentences.
- **BR-M2** Hebrew UI is RTL; English LTR; user content direction is auto-detected per field.

---

## 11. State machines

Every transition is executed by a server function (never a direct table update) which also writes timestamps and notifications. `System` = scheduled tick (every minute).

### 11.1 Building — `draft · active · suspended`

| From | Event | Actor | Guard | To |
|---|---|---|---|---|
| — | create (creator becomes the building admin) | Platform admin | BR-A1 | draft |
| draft | accept agreement & activate | Building admin (you) | ≥ 1 apartment, declared counts match, current building agreement accepted in the same step (BR-A2) | active (join code issued) |
| active | suspend | Platform admin | reason | suspended |
| suspended | reactivate | Platform admin | — | active |

No approval by a committee or any second party is part of this machine.

### 11.2 Membership (resident request) — `pending · info_requested · approved · rejected · disabled`

| From | Event | Actor | Guard | To | Effects |
|---|---|---|---|---|---|
| — | submit application | Applicant | BR-B1,B2,B4 | pending | notify building admins |
| pending | request info | Admin | BR-A6 | info_requested | notify applicant |
| info_requested | respond | Applicant | — | pending | notify admins |
| pending | approve | Admin | BR-A6 (the sole admin may approve their own application while `allow_admin_self_review`) | approved | notify applicant; may approve parking requests in same action |
| pending / info_requested | reject | Admin | reason | rejected | notify applicant |
| rejected | resubmit (edited) | Applicant | — | pending | |
| approved | disable | Admin | reason | disabled | BR-B7 |
| disabled | enable | Admin | — | approved | |

### 11.3 Parking assignment — `requested · active · rejected · withdrawn · ended`

| From | Event | Actor | Guard | To |
|---|---|---|---|---|
| — | request | Resident (approved) | space active; no open request for same pair | requested |
| requested | approve | Admin | BR-C2, no other active assignment on the space (else admin must end it first or use *reassign*) | active |
| requested | reject | Admin | reason | rejected |
| requested | withdraw | Resident | — | withdrawn |
| active | end / reassign | Admin | BR-C5 | ended (reassign also creates a new `active` row) |
| active | membership disabled | System | — | ended |

### 11.4 Parking listing — `available · reserved · active · completed · cancelled · expired`

| From | Event | Actor | Guard | To |
|---|---|---|---|---|
| — | create | Holder | BR-C6, BR-D2,D3 | available |
| available | reservation accepted, or instant reservation confirmed | Owner/Requester | BR-D1 | reserved |
| reserved | reservation cancelled/declined/expired by requester or system, start in future | System | — | available |
| reserved | owner cancels reservation, or assignment ended with cancel | Owner/Admin | — | cancelled |
| reserved | start_at reached (reservation confirmed) | System | — | active |
| reserved | start_at reached (reservation only accepted) | System | — | expired |
| available | cancel | Owner | BR-D8 | cancelled |
| available | start_at reached, no reservation | System | — | expired |
| active | end_at reached | System | tx not disputed | completed |

### 11.5 Parking reservation — `requested · accepted · confirmed · active · completed · cancelled · declined · expired`

Your required statuses map as: *Available* = **listing**; *Requested, Accepted, Confirmed, Active, Completed, Cancelled* = **reservation**; `declined` and `expired` make every dead end explicit.

| From | Event | Actor | Guard | To | Effects |
|---|---|---|---|---|---|
| — | request (approval-mode listing) | Requester | BR-D5,D6 | requested | notify owner |
| — | reserve now (instant listing) | Requester | BR-D1 | **confirmed** | transaction `in_progress` + payment `pending` (if price > 0); listing → reserved |
| requested | accept | Owner | BR-D1,D7 | accepted | listing → reserved; slot locked; `expires_at` = confirm window |
| requested | decline | Owner | — | declined | |
| requested | withdraw | Requester | — | cancelled | |
| requested | no response | System | BR-D9 | expired | |
| accepted | confirm | Requester | window open | **confirmed** | transaction `in_progress` + payment `pending` (if price > 0) |
| accepted | window elapsed | System | — | expired | listing → available |
| accepted | cancel | Requester/Owner | — | cancelled | listing → available (requester) / cancelled (owner) |
| confirmed | cancel | Requester | start not reached | cancelled | matrix §10-G; tx cancelled |
| confirmed | cancel | Owner / Admin (BR-C5) | start not reached | cancelled | tx cancelled |
| confirmed | start_at | System | — | active | notify both |
| active | end_at | System | tx not disputed | completed | tx → `awaiting_settlement` or `completed`; rating request when tx completed |

### 11.6 Delivery request — `open · offer_received · accepted · collected · delivered · completed · cancelled · expired · disputed`

Your flow *Open → Offer received → Offer accepted → Package collected → Package delivered → Completed* is the main path; `accepted` = "offer accepted".

| From | Event | Actor | Guard | To | Effects |
|---|---|---|---|---|---|
| — | create | Requester | BR-E1,E8 | open | notify residents (optional) |
| open | offer made | Helper | BR-E2 | offer_received | notify requester |
| offer_received | last pending offer withdrawn/rejected | System | — | open | |
| open / offer_received | accept offer | Requester | pending offer exists | accepted | offer accepted, others rejected; **code generated**; **transaction `in_progress` + payment `pending`**; reveal helper phone, requester apartment (to helper) |
| accepted | collected | Helper | before deadline + 24 h | collected | notify requester |
| collected | arrival ping | Helper | cooldown 10 min | collected | notify requester |
| collected | correct code | Helper | not locked | delivered → **completed** (atomic) | tx → awaiting_settlement/completed |
| collected | **door delivery with photo** | Helper | `door_delivery_allowed` or `door_delivery_approved_at` set (BR-E6) **and** valid photo proof uploaded by the helper (BR-E10) | delivered | `delivery_proof` row, `handoff_method = door_photo`, 24 h confirm timer, notify requester |
| collected | requester allows door delivery | Requester | — | collected | `door_delivery_approved_at` set; notify helper |
| delivered | confirm / auto-confirm | Requester/System | not disputed | completed | tx update |
| open / offer_received | cancel | Requester | — | cancelled | offers expired |
| accepted | cancel | Requester | not collected | cancelled | matrix; tx cancelled |
| accepted | withdraw | Helper | not collected | open (if > 1 h left) else expired | tx cancelled; counters |
| open / offer_received / accepted | deadline passes | System | — | expired | tx cancelled if existed |
| collected / delivered / completed (≤ 7 d) | dispute opened | Either | BR-H1 | disputed (if live) | freeze |
| disputed | admin resolves | Admin | BR-H3 | completed or cancelled | |
| collected | deadline + 24 h passed | System | — | disputed | auto-dispute (BR-E6 method 4) |

### 11.7 Delivery offer — `pending · accepted · rejected · withdrawn · expired`

| From | Event | Actor | To |
|---|---|---|---|
| — | offer | Helper | pending |
| pending | accept | Requester | accepted |
| pending | reject / another accepted | Requester/System | rejected |
| pending | withdraw | Helper | withdrawn |
| accepted | helper backs out (before collection) | Helper | withdrawn |
| pending | request cancelled/expired | System | expired |

### 11.8 Payment — `pending · payer_confirmed · settled · cancelled`

(`kind = charge | refund`; for refunds the payer/payee roles are reversed.) **No hold/authorization statuses exist in the MVP**; a future provider may add them without changing transaction logic (BR-F9).

| From | Event | Actor | To | Notes |
|---|---|---|---|---|
| — | transaction created, amount > 0 | System | pending | |
| pending | "I paid" | Payer | payer_confirmed | notify payee |
| pending / payer_confirmed | "Payment received" | Payee | settled | `settled_via = 'payee'` |
| payer_confirmed | "Not received" | Payee | pending | counter +1; 3 → auto-dispute |
| payer_confirmed | payee silent 72 h | System | settled | `settled_via = 'auto'` (BR-F5) |
| pending / payer_confirmed | payee waives | Payee | cancelled | `reason = 'waived'` |
| pending / payer_confirmed | transaction cancelled | System | cancelled | |
| pending | 7 days after service completion | System | cancelled | `reason = 'expired_unpaid'` |
| pending / payer_confirmed | admin resolves dispute | Admin | settled or cancelled | |
| settled | transaction later cancelled/dispute remedy | System/Admin | *(unchanged)* — a **new refund payment** is created | immutability |

### 11.9 Transaction — `in_progress · awaiting_settlement · completed · cancelled · disputed`

| From | Event | To | Notes |
|---|---|---|---|
| — | commit (parking confirmed / offer accepted) | in_progress | amount 0 → no payment row |
| in_progress | service completed and (amount = 0 or payment settled/cancelled) | completed | ratings open; counters |
| in_progress | service completed, payment unsettled | awaiting_settlement | reminders |
| awaiting_settlement | payment settled / waived / `expired_unpaid` | completed | |
| in_progress | cancelled (per matrix) | cancelled | payment cancelled or refund record |
| in_progress / awaiting_settlement | dispute opened | disputed | automation frozen |
| disputed | admin resolves: service confirmed delivered (`payment_settled`, `no_action`, `warning`) | completed | a still-unsettled payment is settled/cancelled per the outcome |
| disputed | admin resolves: service not delivered (`payment_cancelled`) | cancelled | refund record if the payment was already settled |
| completed / cancelled | — | **terminal, immutable** | later disputes → separate records |

Resolution detail: the admin decides whether the service was delivered; that single decision selects `completed` or `cancelled`.

### 11.10 Dispute — `open · under_review · resolved`

`open` (created) → `under_review` (admin opens it) → `resolved` (outcome + note, BR-H3). `post_completion = true` when opened after `completed`.

---

## 13. Notifications

Delivery: **push (FCM→APNs/Android) + in-app center** (every push is also stored). Notifications store `type + params` and are **rendered in the recipient's language** (push server-side, center client-side). T = transactional (cannot be disabled); O = optional (toggle, ≤ 3/day). **Action** = quick action on the destination screen.

| ID | Event | Recipient | When | Type | Action / deep link |
|---|---|---|---|---|---|
| **Building & verification** |
| N01 | Resident registration request submitted | Building admins | application submitted | T | Review request |
| N02 | Applicant replied to info request | Building admins | respond | T | Review request |
| N03 | Resident approved | Applicant | approve | T | Open app |
| N04 | Resident rejected | Applicant | reject | T | See reason |
| N05 | More information requested | Applicant | request info | T | Reply |
| N06 | Resident disabled | Resident | disable | T | — |
| N07 | Parking assignment requested | Building admins | request | T | Review |
| N08 | Parking assignment approved | Resident | approve | T | Publish parking |
| N09 | Parking assignment rejected / ended / reassigned | Resident | decision | T | View |
| N10 | Building activated / suspended | Building admins | status change | T | — |
| **Parking** |
| N20 | Parking request received | Provider | request (approval mode) | T | Accept / Decline |
| N21 | Parking request accepted — please confirm | Requester | accept | T | Confirm |
| N22 | Parking request declined / expired | Requester | decline / expiry | T | Find another space |
| N23 | Parking reservation confirmed | Provider | confirm / instant | T | View |
| N24 | Parking reservation cancelled | Other party | cancel | T | View |
| N25 | Reservation starts soon | Both | start − 1 h | T | View |
| N26 | Reservation ends soon | Requester | end − 30 min | T | View |
| N27 | Parking completed | Both | end | T | Payment / View |
| N28 | New parking available | Residents | listing created | O | View listing |
| **Package pickup** |
| N40 | Pickup request created | Residents (not requester) | create | O | Offer to pick up |
| N41 | Pickup offer received | Requester | offer | T | Accept / View |
| N42 | Pickup offer accepted | Helper | accept | T | View job |
| N43 | Pickup offer not selected | Helper | rejected | T | Browse requests |
| N44 | Package marked collected | Requester | collected | T | View (code) |
| N45 | Helper arrived with your package | Requester | arrival ping | T | Show code / Allow leaving it near my door |
| N46 | Door delivery allowed | Helper | requester allows it in-app | T | Deliver (take photo) |
| N47 | Package left near your door — photo available | Requester | door delivery submitted; reminders +1 h, +6 h, +20 h (payload carries no photo) | T | View photo → Confirm / Report |
| N48 | Delivery completed | Both | completed | T | Payment / View |
| N49 | Request cancelled / helper withdrew / expired | Other party | event | T | View / Create again |
| N50 | Deadline in 1 h, not collected | Helper (and requester) | deadline − 1 h | T | View |
| N51 | Overdue: collected but not delivered | Requester + building admins | deadline passed | T | Report a problem |
| **Payments & transactions** |
| N60 | Payment: "I paid" received | Payee | payer taps | T | Payment received / Not received |
| N61 | Payment confirmed received | Payer | payee confirms | T | View |
| N62 | Payment not received | Payer | payee reports | T | Pay / contact |
| N63 | Payment reminder | Payer | +24 h, +72 h after service | T | I paid |
| N64 | Payment auto-settled / expired | Both | system | T | View |
| N65 | Refund record created | Both | cancel after settled | T | View |
| N66 | Transaction completed | Both | completed | T | Rate |
| **Reputation & disputes** |
| N70 | Rating requested | Both | completed; reminder +3 days | T | Rate |
| N71 | Rating received | Rated user | both rated / window closes | T | View profile |
| N72 | Dispute opened | Counterparty + building admins | open | T | View / Respond |
| N73 | Dispute resolved | Both | resolved | T | View outcome |

Rules: quiet hours 22:00–07:00 for O types; max 3 optional pushes/day; duplicates suppressed by `dedupe_key`; payloads contain no personal data beyond generic text and an entity id (lock-screen safe).

---

## 14. Analytics

Principle: **the database is the source of truth** (per-building SQL views). Client analytics (Firebase Analytics, only if needed) is used solely for funnels/UX and receives no names, phone numbers or apartment numbers.

### 14.1 Business metrics (per building)

| Metric | Definition |
|---|---|
| Apartments | active apartments (N) |
| Registered residents | memberships ever submitted (excluding rejected) |
| Approved residents / % approved | approved ÷ submitted; approved apartments ÷ N |
| Application turnaround | median time submit → decision |
| Parking holders | residents with ≥ 1 active assignment; % of spaces assigned |
| Weekly active users (WAU) | residents with ≥ 1 *transactional action* in the week (create listing/request, offer, request/accept/confirm/cancel, enter code, pay/receive, rate) |
| Engaged residents | opened the app ≥ 1×/week (client event) |
| Parking listings | created per week; avg duration/price |
| Listing request rate | listings with ≥ 1 request ÷ listings that reached end/expiry/completion |
| Parking reservations | counts by status |
| Completed parking transactions | transactions of type parking in `completed` |
| Delivery requests | created per week |
| Request → offer rate; time to first offer | requests with ≥ 1 offer ÷ created; median minutes |
| Completed delivery transactions | transactions of type delivery in `completed` |
| Transaction completion rate | completed ÷ (completed + cancelled + expired-after-commit) |
| Cancellation rate | cancelled ÷ committed, by type and actor |
| Average transaction value | avg amount of completed |
| Settlement health | % settled within 72 h; % auto-settled; % expired_unpaid |
| Repeat usage | residents with > 1 completed transaction ÷ residents with ≥ 1 |
| Retention | weekly cohorts: % active at +1, +2, +4 weeks |
| Rating health | average stars; % ≤ 2 |
| Handoff health | % delivered by code; % delivered by door + photo; % door deliveries disputed; code lockouts; disputes |
| Dispute rate | disputes ÷ transactions |

### 14.2 Client events (no PII)
`app_open` · `signup_started` · `otp_verified` · `legal_accepted` · `join_code_resolved` · `application_submitted` · `home_card_tapped{card}` · `parking_search{window_hours}` · `parking_search_empty` · `listing_publish_completed` · `reservation_requested` · `pickup_request_completed` · `offer_completed` · `handoff_code_viewed` · `handoff_code_entered{result}` · `payment_marked_paid` · `rating_submitted` · `notification_opened{type}` · `language_changed` · `error_shown{code}`.

---

## 15. MVP success metrics (single-building pilot)

**We do not assume success.** Thresholds are *proposals to agree before launch*, calibrated once the real building size is known (open O1). In a single building the absolute numbers are small, so **every percentage is paired with a minimum absolute count**; decisions must not hinge on one or two transactions. *N* = apartments. Pilot = 8 weeks; evaluate at weeks 4, 6, 8.

### 15.1 Baseline facts to record (not scored)
Number of apartments (N) · number of parking spaces and % assigned · residents registered / approved · applications pending > 48 h.

### 15.2 Scored metrics

| # | Question | Metric | Go | Iterate | Stop / rethink |
|---|---|---|---|---|---|
| M1 | Do residents join? | Apartments with ≥ 1 approved resident ÷ N, by week 4 | ≥ 30 % (and ≥ 12 residents) | 15–30 % | < 15 % after active promotion |
| M2 | Are applications handled? | % approved of submitted (excl. spam) · median decision time | ≥ 85 % · < 24 h | 60–85 % · 24–72 h | < 60 % or > 72 h |
| M3 | Do joiners act? | % of approved residents with ≥ 1 transactional action within 14 days | ≥ 40 % | 20–40 % | < 20 % |
| M4 | Weekly active users | WAU ÷ approved residents (weeks 5–8 average) | ≥ 25 % | 12–25 % | < 12 % |
| M5 | Is there real transaction volume? | Completed transactions (parking + delivery) in weeks 1–8 | ≥ 20 (≥ 10 of each of one type) | 8–20 | < 8 |
| M6 | Is parking supply real? | Parking listings created; % receiving ≥ 1 request | ≥ 10 listings; ≥ 50 % | 5–10; 25–50 % | < 5 or < 25 % |
| M7 | Does parking close? | Reservations confirmed ÷ listings; completed parking transactions | ≥ 30 %; ≥ 8 | 15–30 %; 3–8 | < 15 %; < 3 |
| M8 | Do pickups get answered? | Delivery requests; % with ≥ 1 offer before deadline | ≥ 10; ≥ 50 % | 5–10; 25–50 % | < 5; < 25 % |
| M9 | Do pickups complete? | Completed delivery transactions ÷ accepted offers | ≥ 85 % (n ≥ 8) | 65–85 % | < 65 % |
| M10 | Overall completion & cancellation | Completion rate; cancellation rate | ≥ 75 %; ≤ 20 % | 55–75 %; 20–35 % | < 55 %; > 35 % |
| M11 | Repeat usage | Residents with > 1 completed transaction (count and ÷ residents with ≥ 1) | ≥ 6 residents and ≥ 40 % | 3–5 / 20–40 % | < 3 / < 20 % |
| M12 | Retention | % of week-1 active residents active again in week 4 | ≥ 30 % | 15–30 % | < 15 % |
| M13 | Trust | Average rating; dispute rate; door-delivery share | ≥ 4.5; < 3 %; < 25 % | 4.0–4.5; 3–8 %; 25–40 % | < 4.0; > 8 %; > 40 % |
| M14 | Settlement works | % of payments settled within 72 h of service | ≥ 80 % | 60–80 % | < 60 % (the "I paid / received" step is too much friction) |
| M15 | Is the pain real? | Week-6 survey: "How would you feel if you could no longer use the app?" — % "very disappointed" among active users (n ≥ 10) | ≥ 40 % | 25–40 % | < 25 % |

**Qualitative:** 5–8 short resident interviews (weeks 3 and 7); admin diary of verification effort (minutes/week); top reasons for not using; every cancellation/dispute reason; "what did you expect that was missing?".

**Decision rule at week 8:** continue to a second building only if **M3, M5, M11 and M15 are Go and M13 is not Stop**. If only one use case works (parking *or* pickup), keep it and cut the other. If M14 is Stop, investigate payment friction before concluding anything about demand.
