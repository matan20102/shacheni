# Shacheni (שכני) — User Flows, Information Architecture & Screen Specification

Part of the [PRD](PRD.md) (v0.3). Rule IDs `BR-xx` → PRD §10 · state machines → PRD §11 · notification IDs `Nxx` → PRD §13 · RPC/table names → [architecture doc](PRD-data-security-architecture.md). **The UI is specified Hebrew-first (RTL); English (LTR) mirrors the same layouts.**

**Admin model reminder (v0.3):** in the pilot **you are the platform admin and the only building admin**; the admin screens below are the same app, role-gated. There is no admin-appointment feature, no second approver, and no committee step. You may approve your own membership (and, by default, your own parking assignment) — flagged and audited (BR-A6).

Legend: 🔔 notification · **Err** error state · **Sec** security check.

---

## 7. User flows

Every flow lists: **Screens · Actions · Permissions · Database changes · Notifications · Error states · Security checks.**

### F01 — Admin creates a building
- **Screens:** P01 Buildings → P02 Create building wizard, step ① *Details* (then ② apartments, ③ parking spaces — F02/F03 — and ④ review).
- **Actions:** enter building name, full address, city, **number of apartments**, **number of parking spaces**; **Create**. The wizard saves the building as `draft` after step ① and is resumable.
- **Permissions:** platform admin only (you).
- **DB changes:** `create_building` → `building (status = draft, declared counts, settings = defaults incl. allow_admin_self_review = true)`; **the creator's `building_admin` row is created automatically** (no appointment step); `audit_log (create_building)`.
- **Notifications:** none.
- **Err:** duplicate name + address; counts ≤ 0 (apartments) / < 0 (spaces); `NOT_ADMIN`.
- **Sec:** only `create_building` can insert buildings (no DML privilege); platform-admin check from the `platform_admin` table (BR-A1); audit-logged; no committee or second-party approval exists in this flow (BR-A2).

### F02 — Admin defines apartments
- **Screens:** P02 step ② / A06 Apartments.
- **Actions:** choose input mode — **range generator** (floors × units, e.g. floors 1–12, units 01–04 → 101…1204), **paste list** (one per line), or **CSV**; preview table with duplicates highlighted; **Save**. Later: rename, set floor, deactivate/reactivate; count vs declared shown ("52 of 52 ✓").
- **Permissions:** you, as platform admin (setup) or building admin.
- **DB changes:** `bulk_upsert_apartments` → `apartment` rows (`unique (building_id, number)`); `set_apartment_active`; `audit_log`.
- **Notifications:** none.
- **Err:** duplicate labels; empty/too-long label; deactivating an apartment with approved residents requires confirmation (blocks new joins only); deleting is impossible (BR-A4).
- **Sec:** building scope checked from the building id; composite FKs; no resident can write apartments (BR-A3).

### F03 — Admin defines parking spaces
- **Screens:** P02 step ③ / A07 Parking spaces.
- **Actions:** same input modes (e.g., `P01–P40`), optional level and notes per space; preview; **Save**. Later: add/rename/deactivate; filter *Unassigned*; open a space to see holder and history.
- **Permissions:** you (platform/building admin).
- **DB changes:** `bulk_upsert_parking_spaces` → `parking_space` rows (no owner column); `set_space_active`; `audit_log`. A space can exist unassigned (no `parking_assignment` row).
- **Notifications:** none.
- **Err:** duplicate labels; deactivating a space with live listings/reservations is blocked with the affected items listed.
- **Sec:** residents have no INSERT on `parking_space` (BR-C1); notes field warns "do not enter gate codes".

### F04 — Resident registers (account + app-level legal consent)
- **Screens:** S01 Welcome → S02 Phone → S03 OTP → S04 Legal consent (+ S10 viewer).
- **Actions:** device language detected (Hebrew → Hebrew; English → English; otherwise Hebrew); enter phone → OTP → verify; read and accept **Terms of Service** and **Privacy Policy** (documents open in S10; until you provide the real text they show the placeholder `TODO — legal text to be provided by the owner`).
- **Permissions:** anyone (anonymous may read legal text via `get_current_legal_documents`).
- **DB changes:** `auth.users`; `profile` (locale = detected); `accept_legal_documents` → two `legal_acceptance` rows (user, type, **version**, `accepted_at`, locale, app version).
- **Notifications:** none.
- **Err:** invalid phone; SMS failure; wrong/expired OTP; rate limit (30 s resend, 5/hour); documents failed to load (blocking retry); `LEGAL_NOT_ACCEPTED` on any later call if a new version was published.
- **Sec:** OTP rate limits; only **current** versions are accepted; append-only; when you publish a new version (placeholder → final text, or later revisions) the **re-acceptance gate** (S04) reappears for everyone (BR-L1, BR-L2, BR-L5).

### F05 — Resident requests access to a building
- **Screens:** S05 Join building → S06 Application form → S07 Application status.
- **Actions:** enter the **building code** (manual entry; a link/QR later) → app shows building name + address → fill: **full name**, **apartment** (picklist), optional **parking space(s)** (multi-select picklist), optional photo, optional note; confirm the **declarations** (information accurate · I am a resident of this building · apartment correct · parking correct *(if selected)* · I understand the community rules) and accept **community rules** (S10); **Submit request**.
- **Permissions:** authenticated user with current ToS/Privacy accepted; building `active`.
- **DB changes:** `resolve_join_code` (+ `join_code_attempt`); `submit_membership_application` → `building_membership (pending)`, `membership_event (submitted)`, one `parking_assignment (requested)` per selected space (flag if currently assigned to someone else), `legal_acceptance` for `community_rules` + `resident_declaration` (`details` = confirmed items, `building_id`), `profile.full_name/avatar_url`.
- **Notifications:** 🔔 N01 to the building admin.
- **Err:** `JOIN_CODE_INVALID`, `JOIN_RATE_LIMITED`, `BUILDING_NOT_ACTIVE`; `ALREADY_APPLIED`; missing apartment/declaration (inline); empty lists ("Building isn't set up").
- **Sec:** the code only resolves a building (BR-B6); apartment/space are FKs to admin lists — free text impossible (BR-A3); one live membership per user (BR-B1); declarations versioned (BR-L3); applicant sees no building data (BR-B3).

### F06 — Admin approves a resident (also reject / request information)
- **Screens:** A03 Applications → A04 Application review (+ A01 Dashboard counter).
- **Actions:** open request; see **name, phone, apartment, requested parking (with "currently assigned to another resident" flag), other residents in the same apartment, declarations, history**. **Approve** (optionally approve requested parking in the same step, per space), **Reject** (reason), or **Request more information** (message). Fast path: approve from the notification.
- **Permissions:** building admin (you). **You may approve your own application** while `allow_admin_self_review` is true; A04 shows a "This is your own application" banner and the action is flagged.
- **DB changes:** `admin_decide_membership` → status ∈ approved/rejected/info_requested, `reviewed_by/at`, `membership_event`, `audit_log` (`self_review` flag where applicable); optional parking decisions via `admin_decide_assignment`. Applicant replies via `respond_to_info_request` → `pending`.
- **Notifications:** 🔔 N03 approved · N04 rejected · N05 more info · N02 reply received · N08/N09 parking decisions.
- **Err:** `SELF_REVIEW_FORBIDDEN` (only when the switch is off); `STATE_CHANGED`; `NOT_ADMIN`; parking already held → end that assignment first (F24).
- **Sec:** admin sees only application data (admin views); self-review allowed only for the building admin under the switch; audit-logged.

### F07 — Resident requests a parking assignment
- **Screens:** S20 My parking spaces → S21 Request parking assignment. (At registration the same request is created from S06.)
- **Actions:** choose a space from the building's list; optional note; **Send request**; **Withdraw** while requested.
- **Permissions:** approved resident.
- **DB changes:** `request_parking_assignment` → `parking_assignment (requested, flags)`; residents never create a `parking_space` (BR-C1).
- **Notifications:** 🔔 N07 to the building admin.
- **Err:** inactive space; duplicate open request; `NOT_APPROVED`.
- **Sec:** visible only to the requester and the admin; the resident is never told who holds the space (BR-C4).

### F08 — Admin approves a parking assignment
- **Screens:** A08 Parking assignments (Requests tab) → request detail.
- **Actions:** see resident, apartment, space, flags (*currently assigned to <name/apt> — end that assignment first*), history; **Approve** / **Reject** (reason). You verify out-of-band that the space belongs to the resident.
- **Permissions:** building admin; your own request is allowed under the self-review switch (flagged).
- **DB changes:** `admin_decide_assignment` → `active` (`started_at`) or `rejected`; one-holder index; `audit_log`.
- **Notifications:** 🔔 N08 approved · N09 rejected.
- **Err:** `ASSIGNMENT_CONFLICT` (already has an active holder); requester's membership not approved; inactive space.
- **Sec:** `guard_assignment_approval`, `guard_self_review`; one active holder per space (BR-C3).

### F09 — Resident publishes parking
- **Screens:** S16 My parking → S15 Publish parking → S17 Listing detail (owner).
- **Actions:** pick **one of my spaces with an active assignment**; start date/time, end date/time, price (₪), optional description, toggle *I approve each request* (default on); **Publish**.
- **Permissions:** approved resident with an active assignment for that space.
- **DB changes:** `create_parking_listing` → `parking_listing (available, assignment_id)`.
- **Notifications:** 🔔 N28 (optional) to other residents.
- **Err:** `SPACE_NOT_ASSIGNED` (empty state links to S21); `INVALID_WINDOW`; `PRICE_OUT_OF_RANGE`; overlap with my live listing (`no_listing_overlap`).
- **Sec:** assignment checked in RPC **and** trigger `guard_listing_assignment` (BR-C6); cannot publish someone else's space.

### F10 — Resident books parking
- **Screens:** S12 Find → S13 Listing → S14 Review & request → S18 Reservation → S19 Confirm reservation (sheet).
- **Actions:** choose date/time → listings fully covering it → open → **Request** (or **Reserve now** if instant) with optional plate/note. Approval mode: owner **Accept**/**Decline** → requester gets N21 → **Confirm reservation** (S19: window, price, "payment is arranged directly between neighbors; Shacheni doesn't hold money", consequences) → **Confirmed**; transaction created.
- **Permissions:** approved resident; not the owner.
- **DB changes:** `request_parking` → `requested` (or `confirmed` for instant); `respond_to_reservation` → `accepted` (slot locked by the exclusion constraint; listing `reserved`; other overlapping requests `declined`); `confirm_reservation` → `confirmed`, `transactions (in_progress)`, `payment (pending)` if price > 0.
- **Notifications:** 🔔 N20 owner · N21 requester · N22 declined/expired · N23 confirmed (provider) · N25 starts soon.
- **Err:** `SLOT_TAKEN` (alternatives shown); `LISTING_NOT_AVAILABLE`; `OWN_LISTING`; confirm window elapsed; `STATE_CHANGED`.
- **Sec:** **the database rejects overlapping reservations** (`no_reservation_overlap`, BR-D1) even from a modified client; requester ≠ owner; price snapshot server-side.

### F11 — Resident completes the mock payment (parking and packages)
- **Screens:** S31 Payment panel (inside S18, S26, S27, S32).
- **Actions:** **Payer:** panel states amount and recipient and that payment is arranged directly (cash/Bit/PayBox — outside the app); tap **I paid**. **Payee:** "<name> says they paid ₪10" → **Payment received** / **Not received**; or **No payment needed**. Either may **Report a problem**. Timing: parking — any time after confirmation; delivery — at handoff.
- **Permissions:** payer (requester) / payee (provider); live transaction only.
- **DB changes:** `payment_mark_paid` → `payer_confirmed`; `payment_confirm_received` → `settled`; `payment_report_not_received` → `pending` (+ counter; 3 → auto-dispute); `payment_waive` → `cancelled (waived)`; every step → `payment_event`; `app.recompute_transaction`.
- **Notifications:** 🔔 N60 · N61 · N62 · N63 reminders · N64 auto-settled/expired.
- **Err:** `PAYMENT_STATE_INVALID` (refresh); not a party; transaction not live.
- **Sec:** actor-role validated inside `app.apply_payment_event`; settled payments immutable; behind the provider abstraction (BR-F9); **no money is processed or held** (BR-F2).

### F12 — Resident creates a package request
- **Screens:** S22 Help list / S25 My packages → S23 New pickup request → S26 Request detail (requester).
- **Actions:** pickup location, package description, **deadline**, reward (chips 5/10/15/20/custom/Free), notes, optional **pickup reference** (private), handoff place (default "Building lobby"), toggle **"Leave the package near my apartment door"** (default **off**, explanation: "the helper must send you a photo as proof"), acknowledgements (no prohibited items; pickup point allows third-party collection) → **Post request**.
- **Permissions:** approved resident.
- **DB changes:** `create_delivery_request` → `delivery_request (open, door_delivery_allowed)` + `delivery_secret (pickup_reference)`.
- **Notifications:** 🔔 N40 (optional) to other residents.
- **Err:** `DEADLINE_TOO_SOON`; reward over cap; missing acknowledgements; `RATE_LIMITED`.
- **Sec:** the public list exposes only location/description/deadline/reward/handoff place/limited requester profile; `pickup_reference` is in `delivery_secret` (BR-E4, BR-K4); the door-delivery permission is stored server-side and is the only thing that ever enables that method (BR-E6).

### F13 — Another resident offers pickup
- **Screens:** S22 Help → S24 Request detail (helper/public) → offer sheet → S25 My packages (My offers).
- **Actions:** browse by deadline; open; **Offer to pick up** with optional planned time and message; **Withdraw** while pending.
- **Permissions:** approved resident, not the requester.
- **DB changes:** `make_delivery_offer` → `delivery_offer (pending)`; request `open → offer_received`; `withdraw_offer`.
- **Notifications:** 🔔 N41 requester.
- **Err:** `OFFER_EXISTS`; request no longer open; `RATE_LIMITED`.
- **Sec:** helper ≠ requester (`validate_offer`); only public fields shown (BR-E4).

### F14 — Requester accepts a pickup offer
- **Screens:** S26 Request detail (requester): offers → **Accept** → dialog → updated S26 (code panel + helper contact + payment panel).
- **Actions:** compare offers; **Accept** one; **Decline** others (optional); open **Handoff code** panel; (optional) **Allow door delivery** here too.
- **Permissions:** the requester.
- **DB changes:** `respond_to_offer(accept)` → offer `accepted` (others `rejected`), request `accepted`, `delivery_secret.handoff_code` generated, `transactions (in_progress)`, `payment (pending)` if reward > 0; contact reveal enabled.
- **Notifications:** 🔔 N42 helper · N43 other helpers.
- **Err:** `STATE_CHANGED`; another offer already accepted (unique index).
- **Sec:** code never leaves the requester's session (BR-E5); one accepted offer (BR-E3); helper receives pickup reference + requester apartment only now (BR-E4).

### F15 — Package is collected
- **Screens:** S27 Helper job.
- **Actions:** at the pickup point use the **pickup reference**; tap **I picked up the package**.
- **Permissions:** the accepted helper.
- **DB changes:** `mark_collected` → `collected`, `collected_at`.
- **Notifications:** 🔔 N44 requester · N50 deadline reminder to helper.
- **Err:** `STATE_CHANGED`; deadline + 24 h passed.
- **Sec:** only the accepted helper; cancellation blocked from now on (BR-E9).

### F16 — Package is delivered (methods, including door delivery with photo proof)
- **Screens:** S27 Helper job · S28 Enter handoff code · S29 "Can't hand over in person?" sheet · S42 Door delivery photo · S30 Allow door delivery (requester) · S26 (requester: photo, confirm/report) · S43 Delivery photo viewer.
- **Methods (BR-E6):**
  1. **Code in person** — helper arrives, optionally taps **I've arrived** (10-min cooldown) → requester notified (N45) → requester tells the code → helper enters it (**F17**).
  2. **Code by phone** — the requester reads the 4 digits to the helper by call/WhatsApp (phone revealed to both while the transaction is live) so that someone else can receive the package. Same verification as 1.
  3. **Leave near the apartment door + photo proof** — an **explicit method, not an automatic fallback**, available **only if the requester authorized it**: `door_delivery_allowed` set when creating the request (F12), or the requester taps **Allow leaving it near my door** in S30 (reached from N45 or the request). The helper then opens **S42**: takes the photo **in the app** (camera only), previews/retakes, optional note, taps **Submit delivery**. The photo is uploaded to the private bucket and `submit_door_delivery` records the **delivery confirmation, timestamp, photo and uploader** and sets the request to `delivered`. The requester is notified (N47) and can open the photo (S43), then **Confirm received** or **Report a problem**; reminders +1 h/+6 h/+20 h; silence for 24 h auto-confirms.
  4. **No method possible** — the requester is unreachable and has not allowed door delivery: the helper keeps the package, taps **Report a problem → Requester unreachable**; the request stays `collected`; 24 h after the deadline it **auto-opens a dispute** and you are alerted (N51).
- **Permissions:** accepted helper (arrival, code, photo delivery); requester (allow door delivery, confirm, view photo, report).
- **DB changes:** `notify_arrival` → `arrived_at`; `allow_door_delivery` → `door_delivery_approved_at`; Storage insert (policy-checked) → object `delivery-proofs/{building}/{request}/{uuid}.jpg`; `submit_door_delivery(request, path, captured_at, note)` → `delivery_proof (request, uploaded_by, path, hash, uploaded_at)`, request `delivered` (`handoff_method = door_photo`, `delivered_at`, `autoconfirm_at = +24 h`); `confirm_delivery` → `completed`; tick auto-confirm; `tick_retention` purges the image after 30 days.
- **Notifications:** 🔔 N45 arrival · N46 door delivery allowed · N47 package left near your door (photo available) · N48 completed · N51 overdue.
- **Err:** `DOOR_DELIVERY_NOT_ALLOWED` (requester has not authorized — S29 offers "Ask requester to allow"); `PROOF_REQUIRED` / `PROOF_INVALID` (photo missing, too large/old, not JPEG); upload failure (retry; nothing is recorded until both upload and RPC succeed); `ARRIVAL_COOLDOWN`; `CODE_LOCKED` (S28 offers methods 2–4); `STATE_CHANGED`.
- **Sec:** authorization checked **server-side in the RPC and in the Storage insert policy**; photo must exist and be uploaded by the helper within 30 minutes of submission; one proof per request; the proof row is append-only; only requester/uploader (and you, during a dispute) can open the photo, via short-lived signed URLs, each view audited (BR-E10, BR-K6); fallback usage is measured (M13).

### F17 — Handoff code is verified
- **Screens:** S28 Enter handoff code (helper) · S26 code panel (requester; **Generate a new code**).
- **Actions:** helper enters 4 digits → **Confirm delivery**. Requester may **regenerate** the code (≤ 3) if it leaked.
- **Permissions:** accepted helper (verify); requester (view, regenerate).
- **DB changes:** `confirm_handoff(request, code)` in one transaction: checks `locked_until`; compares with `delivery_secret.handoff_code`; **wrong** → `failed_attempts + 1`, at **5** → `locked_until = now + 15 min`, `lock_cycles + 1` (3 cycles → flagged to admin), attempts reset after the lock; **correct** → `collected → delivered → completed` (`handoff_method = code`), `service_completed_at`, `app.recompute_transaction`. `regenerate_handoff_code` → new code, counters reset, `regen_count + 1`.
- **Notifications:** 🔔 N48 completed to both.
- **Err:** `CODE_INVALID` (attempts left); `CODE_LOCKED` (countdown + methods 2–4); `REGEN_LIMIT`; network errors do not consume attempts.
- **Sec:** the code is in no list/push/log; comparison server-side, constant-time; lock persists across devices; only the requester can read it (BR-E5).

### F18 — Transaction is completed
- **Screens:** S18/S26/S32 (status chips), S31 payment panel.
- **Actions:** automatic. **Service completion** (parking: `end_at`; delivery: code verified or door delivery confirmed) → `app.recompute_transaction`: amount 0 or payment already settled/waived → **`completed`**; otherwise **`awaiting_settlement`** until payment is **settled / waived / expired-unpaid** (F11, BR-F5/F6).
- **Permissions:** system; parties see status.
- **DB changes:** `transactions.status`, `service_completed_at`, `completed_at`; `completed_count` +1 for both parties (trigger); rating window opens.
- **Notifications:** 🔔 N27/N48 service done · N66 transaction completed · N70 rating requested · N63/N64.
- **Err:** stuck states visible to you ("awaiting settlement > 7 days"); `disputed` freezes completion.
- **Sec:** completed transactions are **immutable** (BR-J1); later refunds/disputes create new records (BR-F7, BR-H4).

### F19 — Users rate each other
- **Screens:** S33 Rate neighbor (from N70, S32, S18/S26) · S36 Neighbor profile.
- **Actions:** 1–5 stars (required), optional comment ≤ 280; **Submit**. Hidden until both rated or 14 days; then N71.
- **Permissions:** the two parties of a `completed` transaction; once each.
- **DB changes:** `submit_rating` → `rating`; trigger `update_reputation` updates `rating_avg/count` on `building_membership`.
- **Notifications:** 🔔 N70 (+ reminder at +3 days) · N71.
- **Err:** `ALREADY_RATED`; `RATING_WINDOW_CLOSED`; transaction `disputed`; not a party → denied.
- **Sec:** participation enforced by `validate_rating`; unique per rater/transaction; immutable (BR-I1–I2).

### F20 — Admin manages residents and building resources
- **Screens:** A01 Dashboard · A05 Residents · A06 Apartments · A07 Parking spaces · A08 Assignments · A09 Activity (listings, package requests, transactions) · A10 Disputes · A11 Statistics · A12 Building settings.
- **Actions:** search/filter residents, view limited details, **Disable/Enable** (reason); edit apartments/spaces (F02/F03); end/reassign assignments (F24); browse listings, package requests and transactions (read-only, statuses only); remove an abusive listing/request (reason); view statistics; rotate join code and print the poster.
- **Permissions:** building admin (you; current agreement accepted).
- **DB changes:** `admin_set_membership_status`; setup RPCs; moderation sets `cancelled` with reason via RPC; `audit_log` for each.
- **Notifications:** 🔔 N06 disabled resident · N24/N49 to affected counterparties.
- **Err:** `NOT_ADMIN`; disabling cascades (BR-B7) — the confirmation lists everything that will be cancelled.
- **Sec:** least-privilege admin views (§12.4): no handoff codes/references, no delivery photos outside a dispute, no other buildings, no payment details beyond status.

### F21 — Building activation & building agreement
- **Screens:** P01 Buildings (setup checklist) → A02 Building agreement & activation → A12 Building settings.
- **Actions:** when apartments ✓, spaces ✓ and counts match ✓, open A02 (as building admin): read the **building agreement** (S10 — placeholder text until you provide the real one), tick acceptance, **Accept & activate**. The join code is issued; the building is `active` immediately. Platform admin may later **Suspend/Reactivate** it (P01).
- **Permissions:** you (platform admin = building admin). **No committee approval and no second-party approval is required or modeled.**
- **DB changes:** `accept_building_agreement_and_activate` → `legal_acceptance (building_agreement, version, building_id)`, `building.status = active`, `join_code`, `activated_at`; `audit_log`. When you publish a new agreement version, A02 reappears and building-admin tools stay locked until accepted (BR-A8).
- **Notifications:** 🔔 N10 building activated/suspended.
- **Err:** guards fail (counts mismatch, no apartments) → the checklist shows what is missing.
- **Sec:** BR-A2; acceptance append-only; only the building admin can accept for the building. Launch checklist: replace placeholder legal text before real residents join.

### F22 — Cancellation
- **Screens:** S34 Cancel sheet (from S16/S17/S18, S25/S26/S27).
- **Actions:** **Cancel** → the sheet **lists consequences** (matrix §10-G: counterpart notified; payment cancelled or **refund record** if already settled; reliability counter) → reason (required for confirmed items) → **Confirm cancel**.
- **Permissions:** the parties, in the states the matrix allows.
- **DB changes:** `cancel_reservation` / `cancel_parking_listing` / `cancel_delivery_request` / `helper_withdraw` → states per §11; transaction `cancelled`; unsettled payment `cancelled`; settled → **new `payment (kind = refund)`**; counters; listing → available/cancelled.
- **Notifications:** 🔔 N24 / N49 / N65.
- **Err:** `CANNOT_CANCEL` (started/collected → suggests Report a problem); `STATE_CHANGED`.
- **Sec:** actor must be a party; consequences computed server-side; no fees (BR-F8).

### F23 — Dispute
- **Screens:** S35 Report a problem → S32 ("Under review") → A10 Disputes (you).
- **Actions:** party picks a reason, writes a description → **Submit**; counterparty may reply once; you open the review and see both sides, the timeline, that transaction's rating comments and — for door deliveries — the **delivery photo**; then **Resolve**: *service delivered?* yes/no, outcome (`payment_settled` / `payment_cancelled` / `no_action` / `warning`), mandatory note.
- **Permissions:** parties (open/reply); building admin (resolve). If you are a party, you may still resolve while the self-review switch is on — the other party sees "resolved by the building admin (also a party)".
- **DB changes:** `open_dispute` → `dispute (open)`; live transaction → `disputed`; after completion → record only (`post_completion`) and any remedy is a separate `payment` row; `admin_resolve_dispute` → resolved; transaction → `completed` or `cancelled`; `audit_log` (`self_review` flag where applicable).
- **Notifications:** 🔔 N72 counterparty + you · N73 both.
- **Err:** `DISPUTE_WINDOW_CLOSED` (> 7 days); duplicate open dispute; missing note.
- **Sec:** only parties open; admin sees only the disputed transaction (BR-H6); outcome final in the MVP.

### F24 — Admin ends or reassigns a parking assignment
- **Screens:** A08 Parking assignments → assignment detail.
- **Actions:** **End assignment** or **Reassign to…**; the screen shows impact: unreserved listings (auto-cancelled) and future reservations (require **Cancel those reservations** confirmation — no penalty to the former holder).
- **Permissions:** building admin.
- **DB changes:** `admin_end_parking_assignment` / `admin_reassign_parking_space` → old assignment `ended`, new `active` (reassign); listings `cancelled`; reservations `cancelled` (+ refund records if settled); `audit_log`.
- **Notifications:** 🔔 N09 former/new holder · N24 affected requesters.
- **Err:** `ASSIGNMENT_HAS_RESERVATIONS` (cancellation not confirmed); target resident not approved.
- **Sec:** BR-C5; one-holder index; self-review rules (BR-A6) for the new holder.

---

## Information architecture (Phase 3)

### Navigation model
Bottom navigation (4 tabs) + top bar (building name + 🔔). Admin sections live inside **Me** and appear only for admin roles. **No building switcher in the MVP UI.**

```
App
├─ Access (unauthenticated / applicant)
│   Welcome → Phone → OTP → Legal consent → Join building → Application form
│   Status: Pending · More info requested · Rejected/Disabled     (+ Legal document viewer)
└─ Main (approved resident)         [top bar: building name · 🔔 Notifications]
    ├─ 🏠 Home — quick actions · Needs your action · Happening soon · Parking available · Pickup requests
    ├─ 🚗 Parking — Find → Listing → Review/request → Reservation → Confirm
    │              — Mine (I'm sharing | I'm renting) → Listing (owner) / Reservation
    │              — Publish parking · My parking spaces → Request assignment
    ├─ 📦 Packages — Help (open requests) → Request → Offer
    │               — Mine (My requests | My offers) → Request detail → Code · Door delivery · Photo
    │               — Helper job → Code entry · Door delivery photo · New pickup request
    └─ 👤 Me — Profile · Edit profile · History → Transaction → Rate/Report · Settings (language, notifications,
               legal documents, delete account, log out)
             └─ Admin (you as building admin): Dashboard · Applications · Residents · Apartments · Parking spaces ·
                Assignments · Activity · Disputes · Statistics · Building settings
             └─ Platform (you as platform admin): Buildings → Create building wizard
```

### Permission requirements by area

| Area | Applicant | Resident | Building admin | Platform admin |
|---|---|---|---|---|
| Access screens (S01–S10) | ✓ | ✓ | ✓ | ✓ |
| Home, Parking, Packages, Me (S11–S43) | ✗ | ✓ | ✓ (as resident) | ✗ |
| Admin screens A01–A12 | ✗ | ✗ | ✓ own building | ✗ |
| Platform screens P01–P02 | ✗ | ✗ | ✗ | ✓ |
(Pilot: you hold both admin roles. Screens are also protected by server-side RLS/RPC checks; hiding a screen is never the control.)

### Deep links
Path-based and host-independent (a domain is not configured yet): `/join/:code` · `/parking/listing/:id` · `/parking/reservation/:id` · `/packages/request/:id` · `/packages/request/:id/handoff` · `/packages/request/:id/photo` · `/transactions/:id` · `/transactions/:id/rate` · `/notifications` · `/admin/applications/:id` · `/admin/assignments/:id` · `/admin/disputes/:id`. Until a domain exists, notification taps use the custom scheme/FCM data payloads and the join code is entered manually.

### UX principles (inputs to Phase 4)
1. Home answers: *"What can I do in my building right now?"*
2. One primary action per screen; destructive actions secondary and always show consequences.
3. Plain Hebrew first ("אני שילמתי / התשלום התקבל"); payment copy always says it is arranged between neighbors.
4. Trust cues on every person (photo, first name + initial, ⭐, "תושב/ת מאומת/ת").
5. **RTL-first**: layouts designed in Hebrew; English mirrors. Numbers, plates and phone numbers stay LTR inside RTL text.
6. Fast: skeletons; optimistic UI only for harmless actions; server truth for state.
7. Friendly, light, rounded visual tone; no property-management look. Easy registration and fast approval are the top priorities (PRD §5.1a).

---

## 8. Screen specification

### Global patterns (apply to every screen unless overridden)
- **Loading:** skeleton placeholders; write buttons show an inline spinner and are disabled (no double submit); full-screen splash only at app start.
- **Error:** load failure → inline card "Couldn't load" + **Try again**; action failure → snackbar with a *specific* localized message mapped from the server error code; validation → inline under the field.
- **Offline:** persistent top banner; cached in-memory data stays visible; writes disabled with explanation.
- **Conflict:** `STATE_CHANGED`/`SLOT_TAKEN` → dialog "This was just updated" + **Refresh**.
- **Permission denied (server):** `NOT_APPROVED`/`NOT_ADMIN` → the routing gate redirects to the correct status screen (never a raw error).
- **RTL:** start/end layouts; mirrored arrows; steppers run right-to-left in Hebrew; numeric inputs (phone, code, price, plates) LTR-aligned; amounts `₪10`.
- **Pull-to-refresh** on lists; Realtime where noted. **Language:** every string from ARB; no hard-coded text.

Each screen: **Role · Purpose · Data · UI components (buttons in bold) · Actions & navigation · Empty / Loading / Error · Permission.**

---

### A. Access (all authenticated applicants)

**S01 Welcome** — *Role:* anyone. *Purpose:* explain in 5 seconds and start. *UI:* logo/name "שכני · Shacheni" (from config), illustration (neighbors, car, package), headline, 3 short bullets, language toggle (עברית/English), **התחלה (Get started)**, Terms/Privacy links. *Actions:* → S02. *States:* splash while the session restores; no error state. *Permission:* public.

**S02 Phone** — *Purpose:* identify by mobile. *UI:* fixed +972 prefix, phone field (LTR), **שלח קוד**. *Errors:* invalid format; SMS failure; `RATE_LIMITED`.

**S03 OTP** — *UI:* masked number + **Change**, 6 digit boxes (LTR order) with SMS autofill, countdown **שלח שוב** (30 s), **אימות**. *Actions:* verify → routing gate: legal not current → S04; no membership → S05; pending/info/rejected/disabled → S07/S08/S09; approved → S11. *Errors:* wrong/expired code; network.

**S04 Legal consent** — *Role:* any signed-in user (also when a new version is published). *Purpose:* capture ToS + Privacy acceptance. *Data:* current `legal_document` versions in the user's language (**placeholder `TODO — legal text to be provided by the owner` until real text is published**). *UI:* two rows (Terms of Service, Privacy Policy) each **Read** (→ S10) with a checkbox enabled after viewing, version shown, **Continue**. *Actions:* `accept_legal_documents` → next gate. *States:* skeleton; Error: blocking retry. *Permission:* authenticated.

**S05 Join building** — *Role:* authenticated, legal accepted. *Purpose:* find the building by code. *Data:* building name + address (after resolve). *UI:* code field (8 chars, LTR, auto-uppercase), **Continue**; confirmation card "בניין <name>, <address> — is this your building?" with **Yes, continue**. (A QR/link prefill is added when a domain is configured; manual entry always works.) *Errors:* `JOIN_CODE_INVALID`, `JOIN_RATE_LIMITED`, `BUILDING_NOT_ACTIVE`.

**S06 Application form** — *Role:* applicant. *Purpose:* request to join (apartment + optional parking). *Data:* apartment list, parking-space labels (no ownership info). *UI:* full name; **apartment** searchable picker (only listed apartments); **parking space(s)** optional multi-select; optional photo; optional note; declaration checkboxes (information accurate · I'm a resident · apartment correct · parking correct *(if selected)* · community rules understood [S10]); **Submit request**. *Actions:* → S07. *Errors:* missing fields inline; `ALREADY_APPLIED`; upload failure (skip photo). *Empty:* "Building isn't set up yet." *Permission:* applicant.

**S07 Application status (pending)** — *Purpose:* reduce anxiety. *UI:* "We're verifying that you live in <building>", summary (name, apartment, requested parking), **Edit details**, **Withdraw request**, **Log out**. Realtime: status change routes automatically. *Permission:* applicant (no building data).

**S08 More information requested** — *UI:* admin's message, reply field, **Send reply** → S07.

**S09 Rejected / Disabled** — *UI:* message (rejected: "לא הצלחנו לאמת…"; disabled: "החשבון מושהה"), reason (if given), **Edit & resubmit** (rejected only), **Log out**.

**S10 Legal document viewer** — *Role:* anyone. *Purpose:* read ToS, Privacy, community rules, resident declaration, building agreement. *Data:* `legal_document` (title, version, effective date, markdown body — placeholder until provided). *UI:* scrollable text, version/date header, **Accept** (only where invoked as a gate; enabled after scrolling to the end). *States:* skeleton; retry; if the user's language is missing it shows the other language with a notice.

### B. Home

**S11 Home** — *Role:* resident. *Purpose:* "What can I do in my building right now?" *Data:* my actionable items, my upcoming items, open listings, open pickup requests (limited profiles). *UI (top→bottom):* top bar (building name, 🔔 with unread dot); **quick actions 2×2** — מצא חניה · שתף את החניה שלי · בקש איסוף חבילה · עזור לשכן; **Needs your action** (accept/decline a request, confirm a reservation, show/enter the handoff code, allow door delivery, view delivery photo and confirm, mark "I paid"/"Payment received", rate); **Happening soon**; **Parking available now/soon**; **Neighbors who need a pickup**. *Priority:* action items → happening soon → opportunities by urgency. *Actions:* tap card → detail; inline Accept/Decline; quick actions → S12 / S15 (or S21 if no assignment) / S23 / S22. *Empty:* empty sections hidden; if nothing at all: illustration + two CTAs; users without an assignment see "Have a parking space? Request an assignment" → S21. *Loading/Error:* per-section skeleton/retry. *Permission:* resident.

### C. Parking

**S12 Find parking** — *Role:* resident. *Data:* listings (public fields) covering the window. *UI:* segments **Find | Mine**; date/time range (presets Tonight/Tomorrow/This week; default now+1 h→+4 h); "Show all upcoming"; cards (label, window + "covers your time", price ₪, provider avatar/first name+initial/⭐, "Instant"/"Approval needed"); **Share my parking**. *Empty:* "No spaces available for these times" + **Show all upcoming**.

**S13 Listing detail (requester)** — *UI:* label, level, window, price, description, provider card (→ S36), notice "Payment is arranged directly between neighbors", **Request** / **Reserve now** (disabled with reason if own listing/overlap). *Errors:* `LISTING_NOT_AVAILABLE`.

**S14 Review & request** — *UI:* summary, optional vehicle plate (LTR), note, consequences note, **Send request** / **Reserve now** → S18. *Errors:* `SLOT_TAKEN` → conflict dialog + alternatives; `OWN_LISTING`.

**S15 Publish parking** — *Role:* resident with an active assignment. *Data:* my spaces (active assignments only). *UI:* space picker (hidden if one), start date/time, end date/time, price (₪; "Free" chip), description (≤ 200), toggle *I approve each request*, summary line, **Publish** → S17. *Errors:* `INVALID_WINDOW`, `PRICE_OUT_OF_RANGE`, overlap shows the conflicting listing. *Empty:* no active assignment → "To share parking, request a parking assignment" + **Request a parking assignment** (→ S21).

**S16 My parking** — *UI:* segments **I'm sharing | I'm renting**; sharing: *Needs response / Upcoming / Past*; renting: *Needs your confirmation / Upcoming-Active / Past*; **Publish new** / **Find parking**; link **My parking spaces** → S20. *Empty:* tailored CTAs.

**S17 Listing detail (owner)** — *UI:* header + status chip, booking-mode toggle (while `available`), **Requests** with **Accept** / **Decline**, reservation card, **Cancel availability** (only while `available`). *Empty:* "No requests yet." *Errors:* `STATE_CHANGED`.

**S18 Reservation detail (both roles)** — *Data:* reservation, counterparty limited profile (+ phone buttons while live), transaction + payment status. *UI:* stepper (Requested → Accepted → Confirmed → Active → Completed), window, price, counterparty card (**Call / WhatsApp** only while live; **no apartment shown**), plate/note, **S31 Payment panel**, timeline. Actions by state: owner at `requested` → **Accept/Decline**; requester at `accepted` → **Confirm reservation** (S19) with countdown; cancellable → **Cancel** (S34); completed → **Rate** (S33) / **Report a problem** (S35).

**S19 Confirm reservation (sheet)** — *UI:* window, price, "Payment is arranged directly between you and <name>; Shacheni doesn't process or hold money", consequences, **Confirm** / **Not now**. *Errors:* confirm window elapsed.

**S20 My parking spaces** — *Data:* my `parking_assignment` rows. *UI:* cards (space label, status chip, decision note); **Request a parking assignment**; **Withdraw** for requested. *Empty:* "No parking spaces linked to you" + CTA.

**S21 Request parking assignment** — *Data:* the building's space labels (no ownership info). *UI:* space picker, optional note, "The admin will verify before it's linked", **Send request**. *Errors:* inactive space; duplicate.

### D. Packages

**S22 Help (open requests)** — *Data:* open/offer_received requests (public fields). *UI:* segments **Help | Mine**; chips (Today, Highest reward); cards: location, short description, deadline countdown (red < 1 h), reward ₪, requester avatar + first name/initial + ⭐, small icon if **door delivery is allowed**; **Request a pickup**. *Empty:* "No one needs a pickup right now" + CTA. *Realtime:* new requests appear.

**S23 New pickup request** — *UI:* pickup location (suggestions from history), package description, deadline, reward chips, notes, **pickup reference** ("shared only with the neighbor you choose"), handoff place (default "Building lobby"), toggle **"Leave the package near my apartment door (the helper must send me a photo)"** — default off, acknowledgement checkboxes, **Post request** → S26. *Errors:* `DEADLINE_TOO_SOON`, reward cap, acknowledgements.

**S24 Request detail (helper/public)** — *Data:* public fields + requester limited profile (**no apartment/reference**). *UI:* location, description, notes, handoff place, deadline, reward, door-delivery-allowed badge, requester card, **Offer to pick up** / **Withdraw offer**; offer sheet (planned time, message ≤ 140, **Send offer**). If my offer was accepted this becomes S27. *Errors:* request no longer open.

**S25 My packages** — *UI:* segments **My requests | My offers**; groups *Needs action / Active / Past*; status chips; **Request a pickup** / **Help a neighbor**.

**S26 Request detail (requester)** — *Data:* request, offers, helper phone (live), **handoff code (only me)**, door-delivery state, delivery photo (if any), transaction/payment. *UI:* stepper (Open → Offer received → Accepted → Collected → Delivered → Completed); **Offers** with **Accept** / **Decline**; after acceptance: helper card (**Call/WhatsApp**), **Handoff code panel** (4 large digits; "Tell this code to your neighbor only when you have the package"; **Generate a new code**), toggle/button **Allow leaving it near my door**, arrival banner (→ S30), **Delivery photo** card when delivered by door (thumbnail → S43; time; who took it) with **Confirm received** / **Report a problem**; **Cancel** (until collected); **S31 Payment panel**; completed → **Rate**. *Errors:* `STATE_CHANGED`.

**S27 Helper job** — *Role:* accepted helper. *Data:* pickup location, deadline, **pickup reference**, requester first name + **apartment** (revealed only now), handoff place, requester phone (live), door-delivery state. *UI:* stepper (Accepted → Collected → Delivered); pickup block (copy button); deliver-to block; **S31 Payment panel** (payee view); primary action by state — `accepted`: **I picked up the package**; `collected`: **I've arrived** and **Enter handoff code** (→ S28); secondary: **Can't hand over in person?** (→ S29), **Withdraw** (before collected), **Report a problem**.

**S28 Enter handoff code** — *UI:* "Ask <name> for the 4-digit code", 4 boxes (LTR order even in Hebrew), keypad, **Confirm delivery**, attempts-left hint, link **Can't hand over in person?**. *Actions:* success → "נמסר! Delivered" → payment panel/Rate. *Errors:* `CODE_INVALID` (shake, attempts left); `CODE_LOCKED` (countdown 15:00 + methods explained); network error doesn't consume attempts.

**S29 "Can't hand over in person?" (sheet)** — *Role:* helper. *Purpose:* show the available delivery methods honestly. *UI:* **Get the code by phone** (Call/WhatsApp); **Leave it near the apartment door** — enabled only if the requester has allowed it (→ S42), otherwise disabled with **Ask the requester to allow it** (sends N45 with the action); **I can't reach the requester** (→ S35 *Requester unreachable*). *Errors:* `DOOR_DELIVERY_NOT_ALLOWED`, `ARRIVAL_COOLDOWN`.

**S30 Allow door delivery (requester sheet)** — *Role:* requester. *Purpose:* explicit consent in-flight. *UI:* "Your neighbor is here with your package", **Show my code**, **Allow leaving it near my apartment door** (explains: you'll receive a photo as proof and can report a problem), **I'll come down**. *Actions:* allow → N46 to helper. *Errors:* `STATE_CHANGED`.

**S42 Door delivery photo** — *Role:* accepted helper; reachable only when door delivery is allowed. *Purpose:* take the proof photo and submit. *UI:* guidance ("Photograph the package near the door. Avoid people and other residents' doors."), **in-app camera** (no gallery), preview with **Retake**, optional note, **Submit delivery**. *Actions:* resize/re-encode → upload → `submit_door_delivery` → success screen "Delivered — the requester was notified" → S27 (payment panel). *Errors:* `DOOR_DELIVERY_NOT_ALLOWED`, `PROOF_REQUIRED`/`PROOF_INVALID`, camera permission denied (explain + settings link), upload failure/timeout (retry; nothing recorded until success), `STATE_CHANGED`. *Loading:* progress indicator, button disabled.

**S43 Delivery photo viewer** — *Role:* requester, uploading helper; building admin only while a dispute on that request is open. *Data:* photo via short-lived signed URL, delivery timestamp (server), uploader name, helper note. *UI:* full-screen photo (zoom), caption, **Confirm received** / **Report a problem** (requester). *States:* skeleton; error retry; "Photo no longer available" if purged after the retention period (metadata still shown).

### E. Money & transactions

**S31 Payment panel (component embedded in S18/S26/S27/S32)** — *Role:* payer or payee. *Data:* amount, payer/payee, payment status/events. *UI (by role/state):* notice "Payment is arranged directly between neighbors (cash, Bit, PayBox…). The app does not process or hold money."; **Payer, pending** → **אני שילמתי (I paid)**; **Payer, confirmed** → "Waiting for <name> to confirm"; **Payee, pending** → "Waiting for <name> to pay", **No payment needed**; **Payee, payer_confirmed** → **התשלום התקבל (Payment received)** / **לא התקבל (Not received)**; settled → ✔ + timestamp; cancelled/waived/expired chip. *Errors:* `PAYMENT_STATE_INVALID` (refresh).

**S32 Transaction detail** — *Data:* type, title, date/time, counterparty (limited), amount, role (You pay / You receive), status, payment timeline, links to the reservation/request, refund records, delivery-photo link where applicable. *UI:* summary, timeline, **S31**, **Rate** / **Report a problem** (while allowed). Read-only otherwise.

### F. Cross-cutting

**S33 Rate neighbor (modal)** — *Role:* party of a completed transaction. *UI:* counterparty avatar/name, 5 stars (required), comment (≤ 280), **Submit**, **Not now**. *Errors:* `ALREADY_RATED`, `RATING_WINDOW_CLOSED`, blocked by dispute.

**S34 Cancel sheet** — *UI:* title, **consequence list** (server-computed), reason picker, **Confirm cancel**, **Keep it**. *Errors:* `CANNOT_CANCEL`, `STATE_CHANGED`.

**S35 Report a problem** — *Role:* party. *UI:* reason picker by type (incl. *Requester unreachable*, *Payment not received*, *Package not delivered*), description (required ≥ 10 chars), explanation ("A building admin will review within 48 hours; automatic actions are paused"), **Submit report**. *Errors:* `DISPUTE_WINDOW_CLOSED`, duplicate.

**S36 Neighbor profile (public)** — *Data:* `public_profile_v`. *UI:* avatar, first name + initial, "✔ תושב/ת מאומת/ת של <building>", ⭐ average (or "New neighbor" < 3 ratings), rating count, completed transactions, member since, visible reviews. **No apartment, no phone.**

**S37 Notifications** — *Data:* own `notification` rows rendered from type+params. *UI:* list (unread dot), icon by type, title/body, time; swipe to mark read; **Mark all read**; tap → deep link; permission card if push disabled. *Empty:* "You're all caught up." *Realtime:* live.

### G. Me

**S38 Me / Profile** — *UI:* avatar, name, "Apartment 1204 · <building>" (visible to me only), ⭐ + completed count, **Edit profile**, rows: My parking spaces, History, Settings, Help, **Admin** (building admin), **Platform** (platform admin), **Log out**.

**S39 Edit profile** — *UI:* name, photo, apartment (changing it submits a **new application**, BR-B5), **Save**.

**S40 History** — *Data:* my `transactions`. *UI:* filters (All · Parking · Pickups · I paid · I received), grouped by month; row: type icon, title ("חניה P03"), date/time range, counterparty, amount (signed ₪), status chip (Completed · Awaiting payment · Cancelled · Disputed); summary header. *Empty:* "Your parking and pickup activity will appear here."

**S41 Settings** — *UI:* **Language** (עברית / English; saved to profile + device), notification toggles, **Legal documents** (→ S10), app version, **Delete account** (blocked while a transaction is live), **Log out**.

### H. Building admin *(you; current agreement accepted; building-scoped)*

**A01 Admin dashboard** — *UI:* tiles — Pending applications (→ A03), Parking requests (→ A08), Open disputes (red if overdue → A10), Active activity (→ A09), week stats (→ A11). Tiles load independently.

**A02 Building agreement & activation** — *Data:* current `building_agreement` (placeholder until provided), setup checklist. *UI:* agreement text (S10), checklist (apartments, spaces, counts), acceptance checkbox, **Accept & activate**. Also shown when the agreement version changes (admin tools locked until accepted). *Errors:* failing guards listed.

**A03 Applications** — *Data:* `admin_application_v`. *UI:* tabs Pending / Info requested / Decided; cards: name, phone, apartment, requested parking, flags (second resident in apartment, space already assigned, **your own**), age (red > 48 h); **Review**. *Empty:* "No one is waiting."

**A04 Application review** — *Data:* name, phone (tap-to-call), apartment, requested spaces (flags), declarations, note, history, other residents in the apartment. *UI:* per-space checkboxes, **Approve**, **Reject** (reason), **Request more info** (message); banner "This is your own application" when applicable (allowed by the switch, flagged). *Errors:* `SELF_REVIEW_FORBIDDEN` (switch off), `STATE_CHANGED`.

**A05 Residents** — *Data:* `admin_resident_v`. *UI:* search (name/phone/apartment), status filter; detail (profile, apartment, spaces, rating aggregate, reliability counters, history), **Disable/Enable** with reason + consequence list.

**A06 Apartments** — *UI:* list with count vs declared ("52/52"), add via range/paste/CSV (preview), edit label/floor, **Deactivate/Reactivate**. *Errors:* duplicates.

**A07 Parking spaces** — *UI:* list with level/notes, holder (admin-only), filter Unassigned; add via range/paste/CSV, edit, **Deactivate**; space detail → assignment history.

**A08 Parking assignments** — *UI:* tabs Requests / Active / History; request detail with flags; **Approve / Reject**; active detail: **End assignment** / **Reassign to…** with impact list. Your own requests are flagged and allowed (switch).

**A09 Activity (listings · package requests · transactions)** — *Data:* `admin_listing_v`, `admin_delivery_v`, `admin_transaction_v` (**no codes, references, photos, contact data**). *UI:* three tabs; filters by status; flagged items on top (overdue collected, awaiting settlement > 7 d, repeated "not received"); row → read-only detail; **Remove** (reason) for abusive listings/requests.

**A10 Disputes** — *UI:* list (open first, overdue red); detail: statements, timeline, payment status, that transaction's rating comments, **delivery photo** (S43 viewer) for door deliveries; **Resolve**: *service delivered?*, outcome, mandatory note → **Confirm**. A "you are a party" notice appears when applicable (allowed by the switch, flagged).

**A11 Statistics** — *UI:* range selector; §14 metrics: apartments, registered/approved residents and %, WAU, listings, reservations, delivery requests, completed parking and delivery transactions, completion/cancellation rate, repeat users, average rating, settlement health, delivery-method mix. (CSV export post-MVP.)

**A12 Building settings** — *UI:* name/address (read-only here; edited in P01), **join code** with **Rotate code** and a printable **poster** (code + install instructions; QR of the install/join link once `APP_LINK_BASE_URL` is configured), accepted agreement version, read-only admin info. No admin-management controls in the MVP.

### I. Platform admin *(you; no resident PII on these screens)*

**P01 Buildings** — *Data:* buildings + `platform_stats_v`. *UI:* list (name, status chip, apartments, residents count); tap a building for the **detail sheet**: status, setup checklist (apartments ✓ spaces ✓ counts ✓ agreement), activation info, aggregate stats, **Suspend / Reactivate** (reason), link to continue the wizard or open A02; **Create building**. *Empty:* "Create your first building."

**P02 Create building (wizard)** — *Steps:* ① Details (name, full address, city, number of apartments, number of parking spaces) → ② Apartments (range/paste/CSV, preview, count check) → ③ Parking spaces (same) → ④ Review → then **Accept agreement & activate** (A02). Saved as `draft` after step ①; each step is resumable. You become the building admin automatically; no admin-appointment step. *Errors:* duplicates, count mismatch (blocks activation only).

### Screen inventory

| Group | Screens |
|---|---|
| Access | S01 Welcome · S02 Phone · S03 OTP · S04 Legal consent · S05 Join building · S06 Application form · S07 Pending · S08 More info · S09 Rejected/Disabled · S10 Legal viewer |
| Home | S11 |
| Parking | S12 Find · S13 Listing (requester) · S14 Review & request · S15 Publish · S16 My parking · S17 Listing (owner) · S18 Reservation · S19 Confirm sheet · S20 My spaces · S21 Request assignment |
| Packages | S22 Help · S23 New request · S24 Request (helper) · S25 My packages · S26 Request (requester) · S27 Helper job · S28 Code entry · S29 Methods sheet · S30 Allow door delivery · **S42 Door delivery photo · S43 Delivery photo viewer** |
| Money | S31 Payment panel · S32 Transaction detail |
| Cross-cutting | S33 Rate · S34 Cancel · S35 Report problem · S36 Neighbor profile · S37 Notifications |
| Me | S38 Me · S39 Edit profile · S40 History · S41 Settings |
| Building admin | A01 Dashboard · A02 Agreement & activation · A03 Applications · A04 Application review · A05 Residents · A06 Apartments · A07 Parking spaces · A08 Assignments · A09 Activity · A10 Disputes · A11 Statistics · A12 Building settings |
| Platform admin | P01 Buildings · P02 Create building |

≈ 57 screens/sheets (admin screens reduced from 17 to 14). Phase 4 produces wireframes for the key screens (S06, S11, S12, S15, S18, S26, S27–S29, S42, S31, S37, A04, A08, P02), then high-fidelity Hebrew-RTL designs and English mirrors.
