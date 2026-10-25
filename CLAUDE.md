# Becel — working notes for Claude

Becel is a Flutter (Android-first) companion for the **Google Fitbit Air**. It
reads Fitbit Air and Google Health data from **Health Connect** and computes
its own WHOOP/Bevel-class metrics on the phone. Branch in progress:
`fitness-engine-rebuild` (do not commit to `master`).

## Owner requirements (log of every request — keep this current)

| # | Request (owner's words, condensed) | Status |
|---|---|---|
| 1 | Make Becel a competitor of **Bevel and WHOOP**; custom algorithms for metrics a coach / gym-goer cares about. | Done (engine below); keep raising quality. |
| 2 | **Great UI and UX.** | Iterating (see todos). |
| 3 | Find common **Fitbit Air complaints** and fix them (calorie overestimation etc.). | Done: calories, phantom steps, early sleep onset, HR overshoot/cadence lock, slow readiness. |
| 4 | Run an **expert evaluator subagent** (PhD exercise science / anatomy / biology, serious athlete) that rates **every iteration**; target **≥ 9/10**. | Ongoing — re-run after each iteration (see scores). |
| 5 | Run on the owner's **phone** and check real data via screenshots. | Done; repeat after changes (Galaxy S24, `RZCY10WA89M`). |
| 6 | **Keep committing** to git. | Ongoing — commit each iteration on the feature branch. |
| 7 | **Read-only app**: never log/write; everything comes from Google Health / Health Connect. | Done: no strength log, no check-ins, no onset edits. |
| 8 | Home shows **steps, calories burned (custom algo)**; food intake optional. | Done: burned + steps + active minutes on Home; food only on Calories screen when shared. |
| 9 | Take **age / weight / height from Google Health**. | Weight, height, body fat read from Health Connect. **Age and sex are not in Health Connect** → entered once in Settings (explain to user). |
| 10 | Calories burned **as of the latest sync**, only shown **once all inputs exist**. | Done ("as of" tag, missing-input state). |
| 11 | **Complete UI overhaul like Bevel**, modern/fancy/attractive; owner **hated the dark colour scheme**. | Done v1 (light theme, gradient rings, Nunito numerals). Polish ongoing. |
| 12 | Calories were **higher than Google Health**, which already overestimates. | Fixed in progress: Keytel no longer applied to easy walking; allowance 0.20; TEF fallback 6 %. Verify on device. |
| 13 | **Fix the bottom bar** (clipped, inset applied twice). | Fix written (inset applied once, removePadding); verify on device. |
| 14 | **Create CLAUDE.md**, revisit all prompts, keep a todo list of anything missed. | This file — update it every iteration. |

## Evaluator score history (target ≥ 9.0)

| Iteration | Commit(s) | Score | Main gaps called out |
|---|---|---|---|
| 0 baseline | `eff2c8b` | 4.2 | Keytel at rest inflates kcal; contradictory recovery weights; population coaching; no complaint fixes |
| 2 | `a71ed31`, `e7a9cfc` | 6.6 | Load used partial day; sleep graded against own debt; rest-day kcal low; strain saturates; cadence lock |
| 3+ | `8083007` → current | _not yet re-rated_ | — |

## Open todos (missed or planned, not done)

- [ ] Re-run the evaluator on the current build; record the score above.
- [ ] Verify on the phone: bottom bar fix; calories now below Fitbit; strain with the 10 % HRR floor.
- [ ] Training load shows "Calibrating" on the owner's real data — check whether the 16 h/day coverage rule is too strict for real Fitbit Air wear (count covered days on device).
- [ ] HRV 7-day trend (`hrvTrend` in `estimates.dart`) has no UI card yet (Recovery screen).
- [ ] Sleep-onset correction toggle (`BodyProfile.correctSleepOnset`) has no Settings switch yet.
- [ ] Today at 360 px / 1.3× text: some captions still truncate (hero captions, vitals labels).
- [ ] Vitals: suppress the VO₂max category when the range spans 2+ categories.
- [ ] Training: show artifact / cadence-lock minutes per workout.
- [ ] Synced strength sessions add no muscular load beyond HR (no RPE available read-only); consider HR-density-scaled top-up.
- [ ] Calories screen: show PAL (TDEE ÷ RMR) and flag implausible days.
- [ ] Update `README.md` and `docs/fitness-scoring.md` — they still describe the old algorithms.
- [ ] `GOAL.md` predates the owner's pivot (Bevel-style scores, read-only); reconcile or mark sections superseded.
- [ ] GOAL.md items never started this session: phone step-challenge alarm, GPS, data-quality review flow.

## Commands

```powershell
flutter test                                   # unit + widget tests (must stay green)
flutter analyze                                # must report no errors/warnings
flutter test test_shots --update-goldens       # review screenshots -> test_shots/goldens/*.png
$env:JAVA_HOME = "C:\Users\amart\.jdks\jbr-17.0.12"
flutter build apk --profile                    # use profile, NOT debug (debug builds a native BLE lib that fails)
& "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe" -s RZCY10WA89M install -r build\app\outputs\flutter-apk\app-profile.apk
```

Phone screenshots: `adb shell screencap -p /sdcard/x.png` then `adb pull` (PowerShell `>` corrupts binary).

## Architecture

- `android/.../MainActivity.kt` — Health Connect reads. Fitbit-Air-only filter for sensor data (`readAirRecords`); any source for weight/height/body fat/nutrition (`readAnyRecords`). Every record type fails soft. 56 days of 1-min HR medians + 5-min step buckets.
- `lib/domain/` — pure Dart, unit tested:
  - `performance.dart` composes everything into one `Performance` snapshot (single source for all screens).
  - `heart_signal.dart` Hampel + cadence-lock cleaning, personal max HR, Karvonen zones.
  - `strain.dart` Banister TRIMP from 10 % HRR, k = 130 → 0–21; EWMA ACWR through yesterday.
  - `energy.dart` per-minute calories (one source per minute; Keytel only ≥ 50 % HRR; steps with phantom filter; METs for strength; allowance 0.20; TEF).
  - `estimates.dart` recovery % (28-day robust baseline, Φ mapping, `RecoveryModel` weights) + HRV trend.
  - `sleep_coach.dart` need (learned baseline + strain + debt), onset correction, consistency.
  - `coaching.dart` daily plan, body alert, weekly review/CSV.
- `lib/data/health_store.dart` — loads raw data, composes `HealthSnapshot`; auto-retries once.
- `lib/data/local_store.dart` — stores **only** the profile (age, sex, optional overrides). Nothing else.

## Conventions

- **Read-only**: never add features that log or write health data.
- Light theme tokens in `lib/app/theme.dart`. Metric hues are CVD-validated on white with the dataviz skill's `validate_palette.js`; re-validate if you change them. Status colours (green/yellow/red) only for good/caution/bad and always with a word.
- Fonts: Inter (text) + Nunito (numerals), bundled; Roboto fallback for symbols. Avoid ≤ ≈ → ₂ ⅓ in UI strings.
- After UI changes, run the strict-font overflow sweep (widget tests use Ahem, wider than real fonts).
- PowerShell gotchas: edit Unicode files with the Edit tool or .NET UTF-8 I/O, never `Get-Content | Set-Content`; single-element nested arrays flatten (`@(@(a,b))`); commit messages via `-F file` or multiple `-m`.
- End commit messages with `Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>`.
