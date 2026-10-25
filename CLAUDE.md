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
| 12 | Calories were **higher than Google Health**, which already overestimates. | Root cause fixed: Keytel was costing easy walks at ~7 kcal/min. |
| 13 | **Fix the bottom bar** (clipped, inset applied twice). | Replaced Material NavigationBar with custom `BecelNavBar`; verify on device. |
| 14 | **Create CLAUDE.md**, revisit all prompts, keep a todo list of anything missed. | This file — update it every iteration. |
| 16 | "The previous calories display was better: show **total**, then the **breakdown below with predictions**." | Done: total so far → "on track for ~X by midnight" → bar + rows (movement, daily living & digestion, resting, predicted rest of day) → Fitbit line. Keep this layout. |
| 17 | "I literally haven't done anything, how could I burn 1,900?" + "the cal display UI is bad". | Explained: owner's RMR ≈ 1,950/day (81 kcal/h), so ~1,400 of a 5 pm total is just being alive. Card redesigned: total → "~X by midnight" → bar + tiles **At rest (grey) / Everyday / Movement** → sentence saying most of the total is not activity. Sleep now costs 95 % of RMR. Keep the total-first layout (#16) but never colour resting like activity. |
| 18 | Get **≥ 9.5 from all evaluator subagents** (PhD science evaluator + UX/product evaluator added iter 7). | Ongoing. |
| 19 | **Too much explanation text** on screens → move meanings/calculations to a page inside Settings. | Done: "How Becel works" (`/guide`, Settings › Learn) + ⓘ `GuideButton` on each screen opening its section. Keep screens numbers-first. |
| 20 | App took ~10 s to show data → **show old data on open, refresh after**. | Done: last raw Health Connect read cached in app-private file (`readCache`/`writeCache`), shown instantly with "Syncing". |
| 21 | Strain must not overestimate; recovery too low for some. | Day-strain floor 10 → 20 % HRR + cadence intensity floor (owner quiet day 6.6 → 2.7). Recovery display: typical 58 %, green ≥ 67 % (z ≥ +0.5), red ≤ 33 % (z ≤ −0.75). |
| 22 | Calories still feel high (2.2k at 8 pm, 5.5k steps); "is the everyday 455 already inside the 81 kcal/h?"; "does a 1 h walk add 81 + walking?" | Answered: Mifflin RMR is lying-still/fasted, so sitting/standing/digestion are extra (Levine 2000); walking minutes get net walking cost *instead of* the allowance; IOM DLW EER for owner ≈ 2,876 sedentary vs Becel ~2,708. PhD evaluator asked to audit (iter 7). |
| 23 | Load / Vitals cards hidden under the nav bar. | Done: `navClearanceOf(context)` = bar + gap + real system inset + 24 (3-button nav); status-bar backdrop on Today. |
| 24 | Keep **calories directly under the 3 rings** (owner liked it); once food is logged show net eaten-vs-burned below it ("make the UI good, don't fixate on a slider"). | Done: order = rings → Calories → Energy balance (only with food; centred deficit/surplus meter + eaten/burned/protein) → Steps/Active → Plan → Your day → Load/Vitals. Do not move calories below the plan again. |
| 15 | "1,668 kcal and strain 4.4 seem high for my day — research it; what does the PhD evaluator say?" | Answered with DLW/Mifflin/WHOOP evidence: total burn is mostly resting metabolism (81 kcal/h for the owner); free-living PAL ≥ 1.4, so the total was if anything low; 4.4 is "light" on WHOOP's scale (member average 11). Evaluator agreed calories were too low and ambient HR padded load. Home now leads with **active** kcal; total/resting shown beneath. |

### Decisions to keep (with evidence)
- **Calories**: target a light ambulatory day near PAL 1.35–1.45 (DLW floor for free-living adults); do NOT tune to undercut Fitbit's total — Fitbit's known error is exercise kcal. Keytel only ≥ 50 % HRR; FLEX–50 % uses max(step cost, ½ Keytel).
- **Strain**: day strain counts from 20 % HRR (owner: 10 % over-counted sitting) with a cadence intensity floor (≥ 100 spm → 40 % HRR, ≥ 130 → 60 %); training load / ACWR / monotony use effort ≥ 30 % HRR only.
- **Recovery %**: Φ mapping centred on the user's typical morning (= 50 %). Green ≥ 67 % (z ≥ +0.5) means push; red ≤ 25 % (z ≤ −0.75) means recover. A single band drives the ring, words, plan and history. Method copy is generated from the constants (`recoveryMethod`, `energyMethod`), so never hand-write numbers into it.
- **Strain target** = everyday strain + a session: the bands shift by the user's median non-training TRIMP (`ambientTrimp`).
- **Calories card layout** (owner): total first, then the breakdown and the prediction.

## Evaluator score history (target ≥ 9.0)

| Iteration | Commit(s) | Score | Main gaps called out |
|---|---|---|---|
| 0 baseline | `eff2c8b` | 4.2 | Keytel at rest inflates kcal; contradictory recovery weights; population coaching; no complaint fixes |
| 2 | `a71ed31`, `e7a9cfc` | 6.6 | Load used partial day; sleep graded against own debt; rest-day kcal low; strain saturates; cadence lock |
| 3 | `8083007`…`91cc01c` | 7.1 | Green fires on average mornings; ambient load breaks monotony/ACWR; PAL 1.27 too low; TEF drops with partial food log; cadence filter deletes real starts; active min ignores cadence; sleep-need units mismatch; coverage rule fragile; narrow-screen truncation; no HRV trend card / day timeline |
| 4 | `d8343a3`, `4618de6` | 7.4 | Two recovery band systems (ring % vs plan); history vs today need mismatch; cadence-lock exit = normal HR recovery; target ignores ambient strain; strength top-up units; stale method copy; aboveFlexRun too loose; hero "active" includes modelled kcal; learned need double-counts split nights; nav labels clipped; VO₂max category on wide ranges |
| 5 | `8eeba5a` | 7.6 | "Everyday strain" counted training → yellow day got push target; sleep z fixed at 85 % (steady 7 h sleeper ≈ 43 %); compositeScale ignored HRV/RHR correlation; UTC wake dates; 5-min step buckets; strength RPE constant 6; plan ignores HRV trend; no day timeline; narrow truncation; PAL / onset toggle not surfaced |
| 6 | `888e39e` | not rated (evaluator hit rate limit) | — |
| 7 | `2e87dfb` | PhD **7.9** · UX **7.6** | PhD: cadence floor inflated runs; cached data claimed "just now"; strength RPE constant; 5-min steps; guide wording; no day timeline; missing-sleep kcal inflation. Calorie audit: **no constant changes** (2,708/day vs IOM DLW sedentary 2,876). PhD says realistic ceiling ≈ 9.0 for a screenless read-only band. UX: plan buried, prose left, ALL-CAPS titles, ambiguous nav icons, no timeline, zones 0m contradiction |
| 8 | `3b82e66` + layout fix | _awaiting re-rate_ | — |

## Open todos (missed or planned, not done)

- [ ] Record the evaluator's iteration-5 score above and act on its gaps.
- [ ] Verify iteration 5 on the phone (it was locked at install): calories card, nav pill labels, recovery at the 50 % centre, strain target band.
- [ ] Today below-the-fold feels empty vs Bevel: add a day timeline (HR/strain over the day with workout bands) and per-signal sparklines on recovery drivers.
- [ ] Training: seed the EWMA from days before the iteration start (minor double count with short history).
- [ ] 1-minute step buckets (`STEP_BUCKET_MILLIS` in MainActivity.kt) — needs `StepBucket` to carry its duration; every Dart consumer assumes 5 min (cadence = steps/5, phantom thresholds, energy spreading).
- [ ] Strength RPE is a constant 6 for synced lifts; estimate it from session HR density (evaluator iter 5 #5).
- [ ] Today at 360 px / 1.3× text: some captions still truncate (hero captions, vitals labels).
- [ ] Training: show artifact / cadence-lock minutes per workout.
- [ ] Synced strength sessions add no muscular load beyond HR (no RPE available read-only); consider HR-density-scaled top-up.
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
  - `energy.dart` per-minute calories (one source per minute; Keytel only ≥ 50 % HRR; steps with phantom filter; METs for strength; allowance 0.30; TEF 10 % of intake or 8 %).
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
