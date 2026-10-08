# Shacheni (שכני) — Decision Log, Risks & Development Roadmap

Part of the [PRD](PRD.md). Version v0.3 (2026-10-02).

---

## A. Decision log

**F = Finalized** (you confirmed it) · **P = Applied default** (I filled a gap; I proceed with it unless you object) · **O = Open** (needs input; gating phase shown).

### A1. Finalized decisions — round 1 (v0.2)

| ID | Decision |
|---|---|
| F1 | Private community platform for apartment buildings; first use cases: parking sharing and package pickup sharing. MVP = those + verification, building administration, transactions, reputation, notifications. No other community features |
| F2 | Backend/DB are **multi-building** from the start (`building_id` everywhere, RLS isolation); the pilot UI focuses on one building |
| F3 | Only an authorized administrator can create a building |
| F4 | Building creation defines name, address, number of apartments, number of parking spaces, the **apartment list** and the **parking-space list** — authoritative; users pick from lists, never type |
| F5 | Registration: full name, phone (OTP), apartment (from list), parking space if applicable (from list), optional photo |
| F6 | Admin reviews a request: approve / reject / **request more information**; unapproved users see no building data |
| F7 | Parking: residents never create spaces — they **request association**; admin verifies and approves; supports apartments with 0/1/many spaces, unassigned spaces, reassignment |
| F8 | Listings only for the user's officially assigned spaces; a listing = one complete availability window |
| F9 | Double-booking prevented **in PostgreSQL** (exclusion constraint) |
| F10 | Package flow: Open → Offer received → Offer accepted → Collected → Delivered → Completed; one accepted offer |
| F11 | **4-digit handoff code**, requester-only, entered by the helper, **5 wrong attempts → 15-minute lock**; carefully designed alternatives when the requester is not present (now specified as the delivery methods in BR-E6) |
| F12 | **Mock payments, no real money, no held funds**; "I paid" → "Payment received"; **payment abstraction layer** |
| F13 | Legal: building admin accepts the building agreement before activation; every user accepts ToS + Privacy; registration declarations; acceptances stored (user, type, version, timestamp); legal text stored separately and versioned |
| F14 | Role-based in-app admin area; admin should not see unnecessary private data |
| F15 | Profile: name, apartment, picture, rating, completed count; apartment not unnecessarily exposed; phone/WhatsApp revealed at the right stage; **no in-app chat** |
| F16 | Ratings 1–5 + optional review; participants only; once per user per transaction |
| F17 | Push notifications for the listed events, actionable where possible |
| F18 | Hebrew default + RTL; English LTR; localization architecture; device-language detection; manual switch in Settings |
| F19 | **You own** all critical production resources; no dependency on a developer's personal account |
| F20 | Flutter/Dart; Supabase (Auth, PostgreSQL, RLS, Edge Functions); Firebase only for push/analytics |
| F21 | Zero-trust security; completed transactions immutable; refunds/disputes are separate records |
| F22 | Measurable, realistic success metrics for one building |
| F24 | Development phases 1–15 in order; **no Flutter code until Phase 7** |

### A2. Finalized decisions — round 2 (this update, v0.3)

| ID | Decision | Where applied |
|---|---|---|
| F25 | **Platform admin = you only.** No additional platform admins; no multi-admin platform system | PRD §2, BR-A1, architecture `platform_admin` (one SQL-seeded row) |
| F26 | **App name: Shacheni** (שכני), official working name in docs and app. **Domain: later; not purchased/configured; must be easy to change** | All docs; "Configuration & domain independence" (architecture); BR-N1 |
| F27 | **Legal agreement = TODO placeholder** until you provide it; versioning, acceptance, timestamp, document version and re-acceptance **are built**; no invented legal text | PRD §5.4, BR-L5; architecture `legal_document`/`legal_acceptance`; S04/S10/A02 |
| F28 | **Apple Developer account: individual/personal, owned by you** | Architecture ownership table |
| F29 | **Google Play account and GitHub owned by you**; developers get access by invitation only | Architecture ownership table |
| F30 | **Backend: managed, Supabase preferred** → evaluated, **re-confirmed**, with dev/prod separation, backups, storage buckets, exit strategy | Architecture "Backend recommendation & Supabase setup" |
| F31 | **Building admin = you only** for the MVP; **you may approve your own membership**; **no two-admin requirement yet**; more admins later | PRD §2 + BR-A6; architecture switch `allow_admin_self_review` |
| F32 | **Building-committee approval is not required**; nothing blocks building creation/activation; platform admin creates and activates directly | BR-A2, state machine 11.1, flow F21 |
| F33 | **Leave package near the apartment door** is an explicit delivery method: requester must authorize; helper must take a **photo**; store delivery confirmation, timestamp, photo, uploader; requester can see it; **not an automatic fallback**; not allowed without authorization | BR-E6, BR-E10; `delivery_proof`; F16; S29/S30/S42/S43 |
| F34 | **Simplified admin model:** Platform Admin → you; Building Admin → you; Resident → any approved resident; same person may hold both admin roles | PRD §2 |
| F35 | **MVP priorities** (1 easy registration … 10 clean Hebrew RTL); keep it simple; no unnecessary administrative complexity | PRD §5.1a; admin screens reduced from 17 to 14 |

### A2b. Finalized decisions — round 3 (2026-10-09, during development)

| ID | Decision | Where applied |
|---|---|---|
| F36 | **Sign-in with Google instead of phone + SMS OTP.** No SMS provider needed. The phone number is still collected (profile / application form), normalized to +972, unique, but **not SMS-verified**; the building admin verifies applicants as before. The Google email is kept only in Supabase Auth (`auth.users`), not in `profile`. Consequences: replaces **P1** (no email) and **O5** (SMS provider); on iOS, App Store rules require **Sign in with Apple** next to Google before submission | Migration `20261009090000_sign_in.sql`; app `lib/data/auth.dart`; architecture §12.2 |

### A3. Applied defaults (P) — tell me if you disagree

| ID | Gap in the brief | Default applied | Alternative / consequence |
|---|---|---|---|
| P1 | "Email if required" | ~~**Not collected** (phone OTP is the identity)~~ **Superseded by F36:** Google is the identity; the email stays in Supabase Auth only | Optional email for notices/recovery |
| P2 | How a user selects *their* building when buildings are hidden | **Building join code** (8 chars) given by you (poster/WhatsApp); typed manually until a domain exists; code only *resolves* the building, admin approval is the gate; rate-limited; rotatable | Personal invites; listing buildings (rejected: leaks buildings) |
| P3 | Parking assignment holder: resident or apartment | **Resident (membership)**; one active holder per space; apartment kept for verification | Apartment-level holder (weaker "assigned to the user") |
| P4 | Ending/reassigning a space with future reservations | You must **explicitly cancel** those reservations (no penalty to the former holder; refund records if paid) | Block until they finish |
| P5 | What is revealed when | Delivery: requester's **apartment** → accepted helper only; **phone/WhatsApp** → counterparty while the transaction is live; parking: **no apartments revealed**, phones only | Reveal more |
| P7 | Payment timing without real funds | Pay any time while live; reminders +24 h/+72 h; **auto-settle** after 72 h payee silence; **unpaid expiry** after 7 days; **no cancellation fees**; refunds are separate records | Longer windows / manual closure |
| P8 | Reservation steps without escrow | requested → accepted → **requester confirms** → active → completed; transaction created at confirmation; instant-book toggle per listing (default: approval) | Skip the confirm step |
| P9 | Language resolution | Saved choice → device language (he→he, en→en) → **Hebrew** | Prompt at first launch |
| P10 | Admin phone visibility | Building admin sees **full name + phone** of applicants/residents of their building (needed to verify); disclosed in the Privacy Policy | Hide phone |
| P11 | Review display | Review text with reviewer's first name + initial, only after both rated or 14 days | Anonymous |
| P12 | Admin UI | Same Flutter app, role-gated; **12 admin + 2 platform screens**; legal versions published by SQL, not a UI | Web console |
| P13 | Dispute window/authority | 7 days after completion; building admin decides; final | Escalation path |
| P14 | Analytics | SQL views (truth) + optional Firebase Analytics without PII | PostHog |
| P15 | Pilot length/rollout | 8 weeks; TestFlight + Play closed testing; poster + word of mouth | Soft launch |
| P17 | Backend hosting | Supabase **Pro** for prod, **EU region**; dev on Local (CLI) + a dev project | Free tier for dev only |
| P18 | One live membership per user in MVP | partial unique index (dropped when multi-building UI ships) | — |
| **P19** | **Scope of your self-review** (your note named "resident account / building membership") | The same audited switch also lets you approve **your own parking assignment** and resolve a **dispute you are party to**; every use is flagged `self_review` in the audit log and shown to the counterparty. Switch it off to restore strict "nobody reviews themselves" | Limit self-review to your membership only (then your own parking and your own disputes need a second admin — which you said not to require) |
| **P20** | Photo-proof details | **Camera-only** capture, one photo per delivery, JPEG ≤ 1600 px / ≤ 3 MB, location metadata stripped, private bucket, **30-day retention** after completion (metadata kept), viewable by requester + uploader (+ you during a dispute) | Longer/shorter retention; allow gallery (weaker evidence) |
| **P21** | Door-delivery permission default | **Off** per request; requester can allow later in-app; helper sees a badge on requests that allow it | Default on |
| **P22** | Auto-confirmation after a door delivery | 24 h with reminders; silence = confirmed (you can resolve disputes) | Require explicit confirmation |
| **P23** | Bundle/application IDs | Propose `com.shacheni.app` (dev: `com.shacheni.app.dev`); no domain required; **claim them early** (Apple Developer portal / Play Console) because IDs are first-come and permanent | Another reverse-domain style |
| **P24** | Hebrew brand form | **שכני** next to "Shacheni" in the store title/listing and in the app | Latin only |

### A4. Open items (O)

| ID | Item | Why it matters | Needed by | Recommendation |
|---|---|---|---|---|
| **O1** | **Pilot building facts:** number of apartments; parking-space count and labels (P01…); who holds each; apartment numbering scheme; rough resident count | Calibrates metric thresholds (PRD §15) and the range-generator presets | Phase 4/5 | A rough list or photo of the numbering is enough |
| **O2** | **Final bundle/application IDs** and a **public privacy-policy URL** for store listings (any URL you control until a domain exists) | IDs are permanent after the first TestFlight/Play upload; stores require a privacy-policy URL for listings (the text stays TODO until you write it) | IDs: claim in Phase 7, freeze before first upload; URL: before Phase 15 submissions | Accept P23; host a one-page static placeholder |
| **O3** | **Your legal texts:** Terms of Service, Privacy Policy, community rules, resident declaration, building agreement (and which language is binding; package liability wording; data location) | Engineering stores/versions/gates them but does not write them. **Real residents should not join until these exist** | Launch gate (Phase 15); not blocking development | Write when ready; publishing a new version triggers re-acceptance automatically |
| **O4** | **Create the accounts you own:** Apple Developer (individual), Google Play (personal), GitHub, Supabase org (Pro for prod), Firebase project, SMS provider | Everything downstream depends on them; Apple/Google verification can take days; **new personal Play accounts must complete a closed test (≈ 12 testers, 14 days — verify) before production release** (the pilot itself can stay in closed testing) | Phase 6–7 | I'll provide a step-by-step checklist when we reach Phase 6 |
| ~~O5~~ | ~~SMS OTP provider/budget~~ — **closed by F36** (Google sign-in). New follow-up: add **Sign in with Apple** before the first iOS submission | App Store guideline: apps offering third-party login must also offer Sign in with Apple | Before Phase 15 (iOS) | Supabase supports the Apple provider; needs the Apple Developer account (O4) |
| **O6** | Confirm **P19** (self-review also covers your own parking assignment and disputes) | Affects trigger behavior and A04/A08/A10 banners | Phase 5 | Keep as specified |
| **O7** | Confirm **P20–P22** (photo retention 30 days, camera-only, door delivery off by default, 24 h auto-confirm) | Privacy/trust trade-offs of the new feature | Phase 4–5 | Keep as specified |
| **O8** | Optional: **trademark/store-name check for "Shacheni"/"שכני"** (Israeli trademark registry, App Store/Play search, social handles) | Name is decided; this only surfaces conflicts early. I cannot verify availability myself | Before Phase 15 | A short lawyer/registry check; non-blocking |

**Closed since v0.2:** second building admin (not required) · committee consent (not required) · name (Shacheni) · Apple account type (individual) · who the admins are (you) · leave-at-place default (now the explicit door-delivery method, default off).

---

## B. Product name

**Shacheni (שכני)** — Hebrew for "my neighbor". Official working name in all documents, code and the app.

| Item | Convention |
|---|---|
| Code identifiers | `shacheni`; Dart package `shacheni_app`; Supabase projects `shacheni-dev` / `shacheni-prod`; repository `shacheni` |
| Display name | From configuration/localization (he: שכני, en: Shacheni); never hard-coded |
| Bundle/application IDs | Proposed `com.shacheni.app` (dev `.dev`), claimed early, frozen before the first store upload (P23). A domain is **not** required for this |
| Domain | Not purchased; `APP_LINK_BASE_URL` is empty configuration. When you buy one: publish the app-link association files, set the base URL, no business-logic change (architecture, "Configuration & domain independence") |
| Branding scope | The name is neighbor-centric, not parking- or package-specific, matching the long-term platform vision |
| Pronunciation note | The "ch" is a guttural Hebrew sound; the English listing may include a pronunciation hint ("sha-KHEN-ee") — a Phase 4 branding detail |

---

## C. Risks

| # | Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|---|
| R1 | **Cold start:** no listings/requests → nobody returns | High | High | Recruit 3–5 parking holders and frequent-pickup neighbors before launch; you seed with consent; weekly metric review |
| R2 | **Single admin = you:** verification speed and availability depend on one person (target < 24 h) | Med | High | Push on every application (N01), fast approve action, reminder at 24 h; extra admins are the first post-MVP feature (§E) |
| R3 | **Self-review / no second approver:** you approve yourself and may resolve your own disputes (bias, no checks) | Med | Med | Audit-flagged, shown to counterparties, switchable off (BR-A6); accepted for the pilot because you asked for it |
| R4 | **Single point of failure for access** (platform admin = one account; lost phone/SIM) | Low–Med | High | Recovery via Supabase dashboard SQL owned by you; runbook; recovery codes and password-manager emergency access |
| R5 | **Mock payments cause friction** (two taps, silent payees) | Med | Med | Auto-settle (72 h), waive, reminders; metric M14; clear copy; real methods behind the abstraction |
| R6 | **Legal text missing at launch** (you will write it later) | Med | High | Launch gate (O3); placeholders are unmistakable; re-acceptance is automatic when real text is published; do not onboard real residents before it exists |
| R7 | **Legal/regulatory exposure** (parking-use rules in the building, package liability, privacy law, photo of doors) | Med | High | Terms/Privacy to be written by you; prohibited items; minimal data; private, short-retention photos; admin disclosure. (Committee approval is not required by your decision — building bylaws remain the owner's responsibility) |
| R8 | **Delivery photos** are sensitive (doors, hallways, people) and can be faked by a modified client | Med | Med | Requester authorization first; camera-only; strip metadata; private bucket; 30-day retention; audited views; 24 h review + disputes; guidance text in the UI |
| R9 | **Fraudulent parking claims** | Med | Med | You verify each assignment; one holder per space; flags when a space is already held |
| R10 | **Handoff disputes** (requester not home, helper claims delivery) | Med | Med | Code or (authorization + photo); no silent completion; escalation method 4; track method mix (M13) |
| R11 | **Pickup points refuse third-party collection** | High | Med | Acknowledgement + pickup-reference field + guidance; disputes record the reason |
| R12 | **SMS OTP deliverability/cost in Israel** | Med | Med | Provider test; second provider; test numbers for reviewers |
| R13 | **RTL/Hebrew quality** (bidi, plurals, layout) | Med | Med | RTL-first design, directional widgets only, bidi isolates, goldens in he/en, native review (you) |
| R14 | **Store requirements for a personal developer identity:** seller name = your personal name on the App Store; **personal Play accounts need a closed-test period before production**; TestFlight external testing needs a one-time beta review; privacy-policy URL for listings | Med | Med | Plan lead time (O4); run the pilot on TestFlight external link + Play closed testing; an app can later be transferred to an organization account |
| R15 | **Loss of control of accounts/keys** | Low | Very high | Ownership plan, MFA, vault with emergency access, runbook, restore drill |
| R16 | **Supabase dependency** (outage, pricing, RLS mistakes) | Low–Med | Med | Evaluated in architecture; standard Postgres + own backups + exit plan; RLS test matrix |
| R17 | **Small-sample metrics** | High | Med | Absolute minimums beside percentages; interviews; decision rule at week 8 |
| R18 | **Scope creep** (admin features, extra delivery methods) | High | Med | Binding exclusions (PRD §5.2) and priorities (§5.1a) |
| R19 | **Name/trademark conflict discovered late** | Low–Med | Med | O8 check; display name is configuration |

---

## D. Development roadmap

Assumptions: you + me as pair-programmer, ~15–20 focused hours/week. Durations are **rough estimates (±30 %)**. Compared with v0.2, the simplified admin model removes work (no admin appointment/invitation, no second-admin flows, 3 fewer admin screens, simpler building lifecycle), while the door-delivery photo proof, storage/retention, backend setup and legal placeholders add some. **Net estimate: ~14–16 weeks to a pilot-ready build** (phases overlap), then the 8-week pilot.

### Phase status

| Phase | Name | Status |
|---|---|---|
| 1 | Product discovery | ✅ done |
| 2 | PRD | ✅ done (v0.3, awaiting your approval) |
| 3 | User flows & screen specifications | ✅ done (24 flows, ~57 screens) |
| 4–15 | below | not started |

### Phases 4–15

| Phase | Name | Est. | Deliverables | Exit criteria |
|---|---|---|---|---|
| **4** | UI/UX design | 2 wk | **Design tokens**; **typography** (bundled Hebrew-capable font, he/en scales, bidi rules); **spacing system** (4/8 pt); **component system** (cards, chips, status chips, stepper, sheets, pickers, 4-digit code input, camera/photo preview, star rating, empty/skeleton/error states); **wireframes** (S06, S11, S12, S15, S18, S26, S27–S29, S42, S31, S37, A04, A08, P02); **high-fidelity** Hebrew RTL screens then English mirror; click-through prototype | You can explain the app to a neighbor in 10 s from the Home mock; native-speaker RTL review; component inventory frozen |
| **5** | Database | 1.5–2 wk | SQL **migrations** (schema in PRD-data §9: composite FKs, enums, **constraints**, **triggers** incl. `guard_self_review` and `guard_delivery_proof`, **RLS**, **RPCs**, views, tick functions, storage buckets + policies, legal TODO seed); **pgTAP tests** (double-booking incl. race, assignment uniqueness, self-review on/off, cross-building isolation, RLS matrix, immutability, rating, payment state machine, handoff lock/regeneration, **door delivery refused without authorization/photo**, Storage policies, legal gate & re-acceptance) | All DB tests green from a clean database; a two-session race cannot double-book; cross-building test shows zero leakage |
| **6** | Technical architecture | 1 wk | Finalize Flutter/Supabase architecture, auth & routing gates, authorization map, Edge Functions (`send-push`, `purge-proofs`), notification architecture, payment abstraction, localization architecture, **configuration/flavors**, CI skeleton; **ownership setup** (O4: accounts under your name, dev + prod projects, backup job design) | Architecture signed off; dev + prod projects exist under your accounts; secrets handled |
| **7** | Create Flutter project | 0.5–1 wk | Skeleton, flavors, theme from tokens, **l10n he/en with RTL**, router + gates, Supabase client, Riverpod structure, FCM wiring, CI builds; claim bundle IDs (O2); "hello building" against the dev project | Runs on iOS + Android devices; CI green; language switch flips RTL/LTR |
| **8** | Authentication & resident verification | 1.5–2 wk | OTP; **legal consent gate (TODO documents)**; join code; application form; status screens; info-request loop; **platform: create building wizard (apartments/spaces) + agreement & activation**; **admin: applications review (incl. self-approval), residents, apartments, spaces**; building settings/poster | New user → application → your approval → Home, on two real phones; **your own application can be approved by you (flagged)**; unapproved user sees no data; publishing a new legal version re-triggers the gate |
| **9** | Parking | 2 wk | Assignments (request/approve/end/reassign), publish, search, request/instant, owner accept, requester confirm, reservation detail, cancel flows, tick job, double-booking UX | Full owner↔requester journey; overlap attempts rejected by DB; assignment edge cases covered |
| **10** | Package pickup | 2.5–3 wk | Requests, offers, accept, secret handling, collected, arrival ping, **code entry + lock + regeneration**, **door-delivery permission, in-app camera, photo upload, proof record, requester photo view, 24 h confirm/auto-confirm, retention purge**, unreachable escalation, expiry/overdue rules | Full requester↔helper journey incl. wrong-code lockout, authorized door delivery with photo, refusal without permission/photo, unreachable escalation |
| **11** | Transactions & mock payments | 1 wk | `transactions` lifecycle, `payment` + events, **provider abstraction + `MockProvider`**, payment panel, reminders/auto-settle/unpaid expiry, refund records, history + receipt | State-machine tests green; completed transaction immutable; refund record on post-settlement cancel |
| **12** | Notifications | 1 wk | Token registration, `send-push`, in-app center, all N-events (he/en templates), deep links, preferences, scheduled reminders | Every N-event fires on real iOS + Android devices and deep-links correctly; template parity check passes |
| **13** | Ratings & disputes | 1 wk | Rate flow (hidden-until-both), reputation triggers, public profile, report-a-problem, admin dispute resolution (incl. photo view), statistics screen | Non-participant can't rate; dispute freezes automation and resolves correctly |
| **14** | Testing | 1.5 wk | Full pgTAP suite, widget/golden tests (he/en), integration journeys, manual two-phone + admin E2E of all 24 flows, accessibility, performance, security review (RLS matrix, admin views, Storage policies), **backup restore drill** | No P0/P1 bugs; all 24 flows pass; security checklist signed |
| **15** | Pilot preparation | 1.5 wk | **Your real legal texts published (O3)**; TestFlight (external link, one-time beta review) and Google Play **closed-testing** setup under your accounts; privacy-policy URL (O2); demo account for reviewers; real building data loaded (O1); poster with join code; your admin runbook; metrics views; dry run with 5–8 residents | Dry run completes; legal texts live; backups verified; privacy-policy URL set |
| — | **Pilot** | 8 wk | Weekly metric review (PRD §15), interviews weeks 3 and 7, weekly bugfix releases | Go / iterate / stop decision at week 8 |

**Critical path (lead times):** Apple and Google account verification and the Play closed-test period (O4) · your legal texts (O3) · bundle IDs (O2). **Parallelizable:** Phase 4 with Phase 5; Phase 14 testing is partly continuous.

**Cut list if time is tight (in order):** statistics screen (use SQL), optional "new listing/request" broadcast pushes, neighbor-review text, English polish, join poster QR. **Never cut:** DB double-booking constraint, assignment verification, handoff code + door-delivery authorization/photo rules, RLS tests, legal acceptance storage and re-acceptance gate, immutability, backups.

---

## E. Post-MVP backlog (explicitly not built now)

1. **Additional platform admins and building admins**, an appointment/invitation mechanism, per-admin permissions, distributed approvals — turn `allow_admin_self_review` off at that point (PRD §2, BR-A6).
2. Multi-building UI (building switcher, discovery, per-user multiple memberships); per-building branding/settings UI.
3. Real payment methods behind the abstraction (Bit, PayBox, cash flows, a real provider with holds) — requires legal/PSP review first.
4. Domain, universal/app links, QR join links.
5. In-app chat; saved searches; partial-window parking and pricing; recurring listings; cancellation fees if ever needed.
6. Committee roles/approvals, if a future building wants them.

---

## F. Gate to start Phase 4

Please review and confirm (or correct):
1. The four documents (start with [PRD.md](PRD.md) "What changed in v0.3", §2 admin model, BR-A6, BR-E6/E10, and screens S11, S29, S42).
2. Applied defaults **P1–P24**, especially **P19** (scope of your self-review), **P20–P22** (photo proof details) and **P23** (bundle ID proposal).
3. Open items **O1** (building facts), **O2** (bundle IDs/privacy-policy URL), **O4** (account creation), **O6/O7**. **O3** (legal texts) is yours to write later and blocks only the launch.

After approval I start **Phase 4** (design tokens, typography, spacing, components, wireframes, high-fidelity screens) and, in parallel, **Phase 5** (SQL migrations, RLS, tests). No Flutter code before Phase 7.
