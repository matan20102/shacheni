# Shacheni (שכני) — Flutter app (visual prototype v0.1)

Clickable prototype of the Shacheni app: **Hebrew-first (RTL) + English (LTR)**, built from the product specification in [`../docs`](../docs/PRD.md). It runs on **sample data held in memory** — there is **no backend yet** (Supabase comes with Phase 5/8). Nothing you do is saved.

## Run it

Flutter is installed at `C:\src\flutter` (not on PATH). From this folder:

```powershell
$env:Path = "C:\src\flutter\bin;" + $env:Path
flutter pub get
flutter run -d chrome                       # opens the app in Chrome (phone-sized frame on wide screens)
flutter run -d chrome --dart-define=DEMO_SIGNED_IN=true   # skip onboarding, start on Home
flutter run -d chrome --dart-define=DEMO_LOCALE=en        # force English (default: device language → Hebrew)
```

Quality checks: `flutter analyze` · `flutter test` · `flutter build web`.

## What you can click through

| Area | Screens (spec IDs) |
|---|---|
| Onboarding | Welcome · Phone · OTP (any code works) · Legal consent (TODO placeholder text) · Join building (code `SHACH-26`) · Application form · Pending (demo "approve me") — S01–S10 |
| Home | Needs-your-action cards, quick actions, parking available, pickup requests — S11 |
| Parking | Find · listing · request/instant · publish · my parking · owner requests · reservation detail + confirm · my spaces / request assignment — S12–S21 |
| Packages | Help list · new request (door-delivery permission) · offers · accept · helper job · **handoff code entry with 5-attempt lock** · **door delivery with photo proof** · photo viewer — S22–S30, S42, S43 |
| Money | Mock payment panel (*I paid* → *Payment received*), transaction detail, history — S31, S32, S40 |
| Cross-cutting | Rate · cancel sheet · report a problem · neighbor profile · notifications — S33–S37 |
| Me | Profile · settings (language switch he/en, legal docs, demo tools) — S38–S41 |
| Admin (you) | Dashboard · applications review (self-approval flagged) · parking assignments · disputes · activity · stats · building settings (join code + poster) — A01–A12 |
| Platform (you) | Buildings · create-building wizard — P01–P02 |

Dashed orange **"Demo: …"** buttons simulate the *other* party's action (e.g. "Dana accepts", "the helper arrives"), so every flow can be walked alone. Hide them in Settings → Demo.

## Layout

```
lib/
  main.dart · app/ (router, theme tokens, app shell)
  l10n/            app_he.arb (template) + app_en.arb  → generated AppL10n (gen-l10n)
  core/            formatting (money/date/bidi-safe), shared widgets, status mapping
  data/            models + DemoData (in-memory stand-in for the RPCs) + Riverpod providers
  features/        access · home · parking · packages · money · common · me · admin · platform
test/              widget smoke test (Hebrew RTL) + rule tests (code lock, door delivery, offers…)
assets/fonts/      Heebo (bundled, OFL)
```

## Notes for the next phases

- `data/demo_data.dart` mirrors the server rules (RPC names in comments). In Phase 8 it is replaced by repository implementations on Supabase; screens keep their widgets.
- **Localization:** every visible string is in the ARB files — no literals in widgets. gen-l10n orders multi-placeholder arguments **alphabetically by placeholder name** (e.g. `actPayReceived(amount, name)`). Keep that in mind when adding strings.
- Legal documents: the app shows only the placeholder `TODO — legal text to be provided by the owner` (`features/access/access_screens.dart`); the versioned document store is specified in the architecture doc.
- iOS builds require macOS (Xcode); this Windows machine can build and run **web** and (once the Android SDK is installed) **Android**. iOS/TestFlight builds will go through a macOS CI runner or a Mac.
