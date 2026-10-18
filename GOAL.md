# GOAL.md — Becel: Android clone of Bevel, built around Fitbit Air

> Research date: 2026-10-18. All external claims below are sourced from the links in
> [§14 References](#14-references). Items marked **(inferred)** are design decisions, not
> verified facts about Bevel.

---

## 1. Purpose

Build **Becel**, an Android-first (Flutter) health-coaching app that clones the core
experience of **Bevel** (bevel.health, Finerpoint Inc., iOS-only) for users whose primary
wearable is the **Fitbit Air** (Google, screenless tracker, released May 2026).

Bevel is the #1 WHOOP-alternative app for Apple Watch users and has **no Android app**
([Bodly review](https://bodly.app/blog/bevel-app-review)). Android + Fitbit Air is an
unserved combination: Fitbit Air is a $99 screenless WHOOP-style band with accurate HR and
sleep tracking but whose official app (Google Health) gives raw numbers and a Gemini coach,
not the integrated Recovery/Strain/Energy-Bank experience that Bevel provides
([PCMag review](https://uk.pcmag.com/fitness-trackers/165161/fitbit-air),
[WIRED](https://www.wired.com/story/google-fitbit-air/),
[Google blog — Fitbit Air India](https://blog.google/intl/en-in/products/hardware/the-all-new-fitbit-air-comes-to-india/)).

---

## 2. What Bevel is (research summary)

**Bevel: AI Health Coach** — App Store id `6456176249`, developer **Finerpoint, Inc.**,
iOS 18+, iPhone + Apple Watch. 4.8★ / ~49K ratings globally, 150K+ active users, ~800 MB.
Apple-Watch-first, but Biology data can also come from Garmin, Oura and **Google Health**
([App Store release notes](https://apps.apple.com/br/app/bevel-ai-health-coach/id6456176249?l=en-GB)).

Core value proposition: turn wearable data into five daily scores + coaching.

| Pillar | What it is |
|---|---|
| **Recovery** | 1–100% morning readiness from Sleep Score, HRV, RHR, respiratory rate, SpO₂, wrist temperature ([help](https://help.bevel.health/en/articles/11258177), [blog](https://www.bevel.health/blog/what-is-recovery-score)) |
| **Sleep** | 0–100 score from 6 contributors: Time Asleep, Deep, REM, Heart-Rate Dip, Efficiency, Continuity + sleep need/bank/debt, smart alarm ([blog](https://www.bevel.health/blog/what-is-sleep-score)) |
| **Strain** | Daily exertion, active + passive, HR-zone driven, **uncapped**, logarithmic, 100% ≈ a high-intensity workout; **Target Strain** recommendation ([blog](https://www.bevel.health/blog/what-is-strain-score)) |
| **Stress** | Real-time 0–100 physiological stress (lower = calmer) from HR + HRV with activity context; not emotions ([Key Terms](https://help.bevel.health/en/articles/11251073)) |
| **Energy Bank** | Body-battery; combines Recovery, sleep, strain, stress; carries over day to day; recharges during calm/rest/naps; non-linear at extremes ([help](https://help.bevel.health/en/articles/11258369)) |

Supporting systems (Free tier unless noted): Nutrition (score, 6M+ foods, barcode/photo/
describe/recipe, glucose/CGM), Fitness (Cardio Load = ATL/CTL/TSB using TRIMP, Cardio
Status with 7 states, Cardio Focus, Heart-Rate Recovery, HR zones with Max HR / HR
Reserve / LTHR / manual), Strength Builder (700+ exercises, 1RM, volume, muscular load,
muscle freshness, routines), Biology (HRV/RHR 60-day baselines, VO₂max, weight trend,
LBM, body fat, BP, glucose, Biological Age, Health Monitors, Timeline), Journal
(hydration, caffeine, alcohol, sunlight, screen time, mood, creatine, PMS, allergies,
late meals, shared bed, …), Cycle Tracking, Activity Status (Active/Sick/Injured/Break),
Smart Alarm, Home-screen widgets, and Bevel Intelligence (AI coach — **Pro**).
Pro also unlocks **Health Records**, **Biological Age**, **Training Plans**
([pricing page](https://help.bevel.health/en/articles/11583937)).

Pricing: Free (now includes all five scores), Pro $14.99/mo, $10.99/mo annual-commit,
$99.99/yr.

Calibration: Bevel needs **2–6 weeks** to personalize; Stress/Energy Bank need ~30 days;
Recovery requires complete sleep HRV + RHR or it will not render
([Common Questions](https://help.bevel.health/en/articles/11257601),
[fitcoin summary](https://www.fitcoin.co/articles/bevel-scores-explained)).

Bevel's exact formulas/weights are **not public** — Becel implements *behavior-equivalent*
algorithms (documented in §7), never claiming numerical parity.

---

## 3. Target device: Fitbit Air

| Spec | Value |
|---|---|
| Release | May 26, 2026 (US from $99.99; India Oct 2, 2026, ₹13,999) |
| Form | Screenless pebble, 34.9 × 17 × 8.3 mm, 5.2 g (12 g with band), medical-grade band options |
| OS | FitbitOS (syncs **only** with the Google Health app) |
| Battery | ~7 days; 34.5 mAh; 5 min charge ≈ 1 day; full in 90 min; USB-C |
| Durability | 5 ATM, IP68 |
| Sensors | Optical HR, SpO₂, skin temperature, accelerometer, gyroscope, vibration motor; **no** EDA, ECG, altimeter, Wi-Fi, NFC, mic |
| GPS | Connected GPS only (phone) |
| On-device storage | 7 days detailed motion data (minute-by-minute), 30 days daily totals, HR at 2-s intervals |
| Health features | 24/7 HR, HRV, RHR, sleep stages & duration, SpO₂, respiration, skin temp, Afib/pulse-arrhythmia alerts, Daily Readiness, Cardio Load, Target Load, stress tracking |
| Sync | Google Health app (BLE), auto-sync throughout the day and ~every 15 min when app is open/in background |

Sources: [gadgetsandwearables specs](https://gadgetsandwearables.com/technical-specs/fitbit-air/),
[Google Store specs](https://store.google.com/us/product/google_fitbit_air_specs),
[PCMag](https://uk.pcmag.com/fitness-trackers/165161/fitbit-air),
[Google blog India](https://blog.google/intl/en-in/products/hardware/the-all-new-fitbit-air-comes-to-india/).

PCMag verdict: accurate HR & sleep, 7+ day battery, weak auto-workout detection,
Gemini coaching is the differentiator — exactly the data profile Bevel-style scores need.

**Critical device constraints for Becel**

1. **No direct device access.** "Fitbit devices can't communicate directly with third-party
   applications. They sync exclusively with the Google Health app"
   ([Google Health API docs](https://developers.google.com/health/data-types)). All
   Becel data arrives *after* the Google Health app syncs.
2. **No third-party smart alarm on the wrist.** The Air's vibration motor is not
   programmable by third parties; Becel's smart alarm can only be a phone alarm +
   notification. (Bevel's Apple Watch alarm has no equivalent on this hardware.)
3. **No live in-workout screen.** No real-time HR broadcast to third parties; workouts are
   post-hoc. (inferred from #1; verify with Health Connect latency on device.)
4. **No EDA →** stress must be computed from HR/HRV/movement (same signals Bevel uses for
   Apple Watch, so parity is achievable).
5. Skin temperature is delivered as **nightly derivations/variation from baseline**
   (relative), not absolute temperature.
6. Weight/body-fat only come from Fitbit Aria scales or manual logging (Air has no body
   composition; Google Health API lists only Aria devices as weight sources).

---

## 4. Data access architecture

### 4.1 Do NOT build on the Fitbit Web API

The legacy Fitbit Web API **turns off permanently on October 30, 2026** (support ended
Sep 30, 2026) ([developers.google.com/health](https://developers.google.com/health),
[dev.fitbit.com](https://dev.fitbit.com/legal/fitbit-user-data-and-developer-policy/)).

### 4.2 Primary: Google Health API v4 (cloud)

- Successor to Fitbit Web API; REST + gRPC; **Google OAuth 2.0**; new
  `googlehealth.*` scope bundles; users must re-consent; `healthUserId` identity;
  **webhook subscriptions**, rollups/daily-rollups, "reconciled stream" that matches what
  users see in Google Health ([overview](https://developers.google.com/health/about),
  [migration](https://developers.google.com/health/migration),
  [data types](https://developers.google.com/health/data-types)).
- Rate limits + pagination rules; "hot load 7–14 days, cold load history in background";
  max query range 90 days for most rollups (14 days for HR/calories).
- Requires a Google Cloud project, OAuth verification, and **CASA security assessment
  (4–6 weeks)** before production — start this early ([Validic timeline](https://help.validic.com/space/VCS/5535203416/Fitbit+to+Google+Health+API:+Developer+Migration+Timeline)).
- **OAuth client = Web Server type** (setup asks for a redirect URI; register a custom
  URI scheme such as `com.becel:/oauth2redirect` for the Android app). Mobile apps must
  use the **system browser (Chrome Custom Tabs)** — AppAuth-style flow
  (`flutter_appauth`); embedded WebViews are forbidden and break Google OAuth.
- **Pre-consent requirement**: user must first link Google Health in the Google Health
  mobile app. Verify after token exchange with `GET /v4/users/me/identity`; handle
  `400 ACCOUNT_NOT_LINKED`.
- **Refresh tokens** expire after **7 days** while the consent screen stays in
  "Testing" (100 test users max). Publish before production. Refresh on-demand only —
  never batch-/cron-refresh. Separate GCP projects per environment (no sandbox).
- **RISC (Cross-Account Protection) is optional** — enable later only if we want push
  notices for revoked tokens / unlinked accounts; otherwise detect via failed refreshes.
- **Onboarding deep links**: `https://www.fitbit.com/in-app/today` opens the Google
  Health app (Today page); `https://fitbit.google.com/wse/deeplink/store` opens its
  store listing ([universal/app links](https://developers.google.com/health/universal-app-links)).

Fitbit Air–compatible data types we will consume (from the
[data types table](https://developers.google.com/health/data-types)):

`heart-rate` (1 s resolution), `heart-rate-variability`, `daily-heart-rate-variability`,
`daily-resting-heart-rate`, `sleep`, `oxygen-saturation`, `daily-oxygen-saturation`,
`respiratory-rate-sleep-summary`, `daily-respiratory-rate`,
`daily-sleep-temperature-derivations`, `exercise`, `steps`, `distance`,
`active-energy-burned`, `total-calories`, `active-zone-minutes`, `active-minutes`,
`activity-level`, `sedentary-period`, `time-in-heart-rate-zone`,
`calories-in-heart-rate-zone`, `daily-heart-rate-zones`, `vo2-max`, `daily-vo2-max`,
`run-vo2-max`, `swim-lengths-data`, `irregular-rhythm-notification`,
`hydration-log`, `nutrition-log`, `food`, `food-measurement-unit`, `menstrual-period`,
`weight`/`body-fat` (Aria scales), `blood-glucose` (manual/CGM).

### 4.3 Secondary: Health Connect (on-device)

The Google Health app syncs **both ways** with Health Connect on Android
([support article](https://support.google.com/fitbit/answer/14506680)). Becel reads from
Health Connect for offline-first, on-device scoring with no server round-trip (privacy
story to match Bevel's "Built for privacy"). Health Connect gives us record types for
sleep sessions **with stages**, heart rate, HRV (RMSSD), RHR, SpO₂, respiratory rate,
skin temperature, VO₂max, exercise sessions, steps, distance, calories, total energy, etc.
([Health Connect data types](https://developer.android.com/health-and-fitness/health-connect/data-types)).

Publishing requirements: declare every Health Connect data type in the Play Console,
justify health-data access, implement background-read permission flow, respect write
cooldowns (15 min) if Becel ever writes back.

**Verified `health` plugin (v13.3.2, carp.dk) details for our build** — checked against
pub.dev, [docs.carp.dk](https://docs.carp.dk/plugins/health/data-types) and plugin source:

- `minSdkVersion 26` required (bump `android/app/build.gradle.kts`; Flutter default is
  21). Health Connect runs on Android 9+ (API 28) via the Play app, built-in on Android
  14+.
- Android-verified data types we need: **HRV RMSSD** (changelog 13.2.0; Android-only in
  the plugin), **skin temperature** (13.3.1+; availability varies by HC version), body
  temperature, blood oxygen, respiratory rate, resting HR, HR, sleep stages
  (deep/light/REM/awake/asleep), steps, distance, calories, workouts (+ routes).
- **Workout routes**: Android only surfaces routes while our app is in the foreground,
  and reading Google Health's routes requires the user to manually grant "Always
  allow" for *Exercise routes* in the Health Connect app (no request dialog exists yet).
- Manifest setup: per-type `android.permission.health.READ_*` permissions, `<queries>`
  block for `com.google.android.apps.healthdata`, `ViewPermissionUsageActivity`
  activity-alias linking the privacy policy (required for Play review), `MainActivity`
  must extend `FlutterFragmentActivity`, `ACTIVITY_RECOGNITION` for steps/pedometer.
- Background sync: `READ_HEALTH_DATA_IN_BACKGROUND` +
  `requestHealthDataInBackgroundAuthorization()`.
- **History window**: reads are capped at the last **30 days** by default; for backfill
  request history access (`READ_HEALTH_DATA_HISTORY` +
  `requestHealthDataHistoryAuthorization()`).

### 4.4 Recommended hybrid (inferred)

| Use case | Source |
|---|---|
| Real-time dashboard, scoring, offline | **Health Connect** (user enables Google Health → HC sync) |
| History backfill, webhooks, cross-device continuity | **Google Health API** (OAuth) |
| Aria weight/body-fat, glucose from CGM | Google Health API |
| Nutrition database lookups | own backend / third-party food DB |

Data-source-family filter: `users/me/dataSourceFamilies/google-wearables` gives raw
Fitbit-Air-recorded telemetry only ([endpoints doc](https://developers.google.com/health/endpoints)).

---

## 5. Feature parity matrix

| # | Bevel feature | Becel scope | Phase |
|---|---|---|---|
| 1 | Recovery Score + contributors | Full | MVP |
| 2 | Sleep: stages, score, needed/bank/debt, smart alarm (phone), sleep goal | Full (alarm = phone) | MVP |
| 3 | Strain: active/passive, per-workout strain, Target Strain | Full | MVP |
| 4 | Stress: real-time-ish daytime score, maps by activity | Full | MVP |
| 5 | Energy Bank | Full | MVP |
| 6 | Home "Today" hub: score rings, cards, Timeline, Action (+) button | Full | MVP |
| 7 | Trends & history charts, calibration UX | Full | MVP |
| 8 | Workouts from Fitbit Air (auto + manual logging), HR zones (+zone settings) | Full | v1 |
| 9 | Cardio Load (ATL/CTL/TSB via TRIMP), Cardio Status (7 states), Cardio Focus, HRR | Full | v1 |
| 10 | Journal + Insights (correlate habits ↔ sleep/recovery) | Full | v1 |
| 11 | Hydration + caffeine tracking | Full | v1 |
| 12 | Activity Status (Active/Sick/Injured/Break) | Full | v1 |
| 13 | Nutrition: manual/describe/barcode/photo AI, score, macros, net energy | Barcode+manual+describe first, photo AI later | v2 |
| 14 | Strength Builder (exercises, sets/reps/1RM/volume, muscular load, freshness, routines) | Reduced v1: logging + volume/1RM; muscular strain needs phone motion | v2 |
| 15 | Biology: baselines (60-day), weight trend, LBM, fat %, BP, glucose, Health Monitors | Full minus watch-only inputs | v1 |
| 16 | Cycle Tracking (phase-aware insights) | Full (basic) | v2 |
| 17 | Health Records (labs import, manual + PDF) | Pro feature | v2 |
| 18 | Biological Age (+ confidence level, weekly update) | Pro feature | v2 |
| 19 | Bevel Intelligence AI coach (chat, check-ins, proactive) | Pro feature — see §10 | v3 |
| 20 | Widgets (home-screen) | Android app widgets / Glance | v1 |
| 21 | Apple Watch app | **Not applicable**; Wear OS companion = non-goal v1 | — |
| 22 | Smart Alarm on wrist | **Impossible with Fitbit Air** (phone alarm only) | — |

Free vs Pro split (mirror Bevel's current logic): all five scores + tracking free;
AI coach, biological age, health records, training plans = Pro.

---

## 6. Bevel information architecture (observed/inferred)

Observed from marketing screenshots + docs:

- **Today/Home** — date header; Recovery, Strain, Sleep hero values; coaching message;
  Timeline of workouts/sleep/nutrition; Action button “+” (bottom-right, customizable).
- **Score detail pages** — Recovery (contributors, baselines), Sleep (hypnogram, stages,
  needed, bank), Strain (chart vs Target Strain band, HR zones, cardio/muscular/passive),
  Stress (0–100 day map by activity), Energy Bank (battery + history).
- **Fitness** — workouts list, Cardio Load chart + status, Cardio Graphs, Strength graphs,
  Personal Records, Routines, Training Load.
- **Nutrition** — diary, Nutrition Score + food-quality contributors, macro balance,
  net energy, glucose (if available), recipes.
- **Biology** — Health Monitors card (RR, RHR, HRV, SpO₂, Temp, Sleep), VO₂max, weight
  trend, LBM/body-fat/BP/glucose rows, Biological Age, Health Records.
- **Journal** — habit list with correlation insights vs sleep/recovery.
- **Settings** — customization: goals (sleep), calculations (HRV RMSSD/SDNN, resting-HRV
  source, temp source), HR zone method, units, widgets.

Design language to replicate: dark, near-black background, large rounded score cards with
red/green/yellow status accents, bold numeric typography, smooth charts, haptic polish.
(Becel will create its own visual identity — no copied assets.)

---

## 7. Scoring system specifications (Becel algorithms)

All formulas are our own published-in-code approximations, clinically disclaimed
("wellness insights, not a medical device"). Evaluated with Bevel's *behavioral* targets:
2–6 week calibration, morning recovery stamp, uncapped logarithmic strain, cumulative
energy bank.

### 7.1 Signal pipeline (Fitbit Air → metrics)

| Metric | Derivation |
|---|---|
| Resting HRV | Mean RMSSD over sleep (Google Health `heart-rate-variability` samples within sleep window; Health Connect HRV record) |
| HRV baseline | 60-day rolling average of resting HRV |
| RHR | `daily-resting-heart-rate` (Fitbit computes during sleep); fallback: 10th-percentile HR during sleep window |
| Sleep stages | `sleep` sessions (deep/core/REM/awake intervals) |
| HR dip | (mean daytime HR − mean sleeping HR) / mean daytime HR |
| RR | `respiratory-rate-sleep-summary` (nightly average) |
| SpO₂ | `daily-oxygen-saturation` (nightly average, % ) |
| Skin temp deviation | `daily-sleep-temperature-derivations` (nightly °C delta from personal baseline) |
| Daytime HR series | `heart-rate` samples (5-min buckets) |
| Movement context | steps + activity-level during HR buckets (stress gating) |

### 7.2 Recovery Score (0–100, computed once/morning after sleep sync)

Approach (inferred weights — tune during calibration):
`Recovery = 0.45·SleepScore + 0.20·z(HRV vs 60-day baseline) + 0.15·z(RHR, inverted)
+ 0.08·z(RR, inverted) + 0.07·(SpO₂ term) + 0.05·(temp deviation term)`, mapped to 1–100
via logistic on the personal baseline. Requires sleep HRV + RHR; otherwise show
"missing data" state (Bevel behavior). Baseline warm-up: blend personal baseline with
population prior during first 2–6 weeks; show calibration banner.

### 7.3 Sleep Score (0–100) — 6 contributors

`f(timeAsleep, need) + f(deep vs target) + f(REM vs target) + f(HR dip) +
f(efficiency = asleep/inBed) + f(continuity = interruptions)`, deep/REM targets age/sex
adjusted (Bevel-style). Add: Time to Fall Asleep, Time in Bed, HR Dip, sleep efficiency,
continuity metrics on the Sleep page.

- **Sleep Needed** = sleepGoal + strainAdjustment + sleepDebtPayment + efficiencyAdjust.
- **Sleep Bank** = Σ (sleep + naps − goal) over 7 days with recency weighting; negative → debt.
- **Smart alarm**: phone alarm inside wake window; wake when accelerometer/HR suggest
  light sleep near target time (approximation, phone-only).

### 7.4 Strain (uncapped, ~0–100+, log scaling)

- Per-workout strain: time-in-zone weighted (Z1=1 … Z5=5 × duration), Bartsch-style
  log mapping (like Whoop/Bevel: strain = c·ln(1+load)).
- **Passive strain**: 5-min HR buckets outside workouts vs personal daytime baseline,
  weighted by movement (steps) to discount excitement/stress.
- **Daily Strain** = workout strain + passive strain.
- **Target Strain** = f(recent recovery scores, 7-day strain trend) → a low–high band.

### 7.5 Stress (0–100, lower = calmer)

Real-time-ish bucket score from HR + HRV + movement context; sleep stress separately
scored (elevated sleep HR/HRV stress reduces Energy Bank charging). ~30-day adaptation.
Inputs: HR above personal daytime baseline net of expected HR from step rate; HRV
suppression vs baseline; sustained-window smoothing to avoid spikes from housework.

### 7.6 Energy Bank (0–100, cumulative across days)

Battery model: charge rate driven by sleep quality/length + daytime calm periods
(stress < threshold) + naps; drain rate driven by strain + stress + time awake;
non-linear saturation near 0/100; carries balance day-to-day.

### 7.7 Cardio Load & Status

TRIMP-based (Banister): `TRIMP = Σ (duration × HRr × 0.64·e^(1.92·HRr))` (male) /
0.86·e^(1.67·HRr) (female), HRr = reserve fraction.
ATL = 7-day EMA, CTL = 42-day EMA, TSB = CTL − ATL; status mapping:
Calibrating (first 6 weeks/insufficient data), Detraining, Maintaining, Productive,
Peaking, Fatigued, Overtraining (Bevel's exact thresholds unknown — replicate semantics).
Cardio Focus: minutes in low-aerobic / high-aerobic / anaerobic zones defined by %VO₂max.
HRR: peak HR (zone 4+) minus HR at +2 min, shown when workout reaches zone 4.

### 7.8 Biological Age (Pro, weekly on Mondays)

Three input groups (Bevel-documented structure):
1. Physiological & lifestyle factors (4-week averages): sleep duration/consistency, RHR,
   HRV, activity/steps, VO₂max, body composition, resting RR, BP.
2. Habits: training frequency, nutrition score, alcohol, smoking (self-report),
   hydration, stress load.
3. Blood biomarkers (manual entry / PDF import): HbA1c, LDL, HDL, triglycerides,
   hs-CRP, ALT, eGFR, ferritin, vitamin D, TSH, etc.
Age-adjusted z-scores vs population tables → weighted composite → biological age,
with a **Confidence Level** (Low/Med/High) based on data freshness/completeness.

---

## 8. Data mapping: Bevel metric → Fitbit Air data

| Bevel metric | Fitbit Air / Google Health source | Health Connect path |
|---|---|---|
| Overnight HRV (RMSSD) | `heart-rate-variability`, `daily-heart-rate-variability` | HRV RMSSD records |
| RHR | `daily-resting-heart-rate` | Resting heart rate |
| Sleep stages & sessions | `sleep` | Sleep sessions + stages |
| Respiratory rate | `respiratory-rate-sleep-summary`, `daily-respiratory-rate` | Respiratory rate |
| SpO₂ | `daily-oxygen-saturation`, `oxygen-saturation` | Oxygen saturation |
| Wrist temperature deviation | `daily-sleep-temperature-derivations` | Skin temperature (peripheral) |
| Workouts | `exercise` | Exercise sessions |
| HR during workouts | `heart-rate`, `time-in-heart-rate-zone`, `daily-heart-rate-zones` | Heart rate, exercise |
| Cardio intensity | `active-zone-minutes` (Fitbit AZM ≈ strain proxy) | (AZM not in HC; recompute from HR) |
| Steps/distance/calories | `steps`, `distance`, `active-energy-burned`, `total-calories` | Steps, Distance, Active/Total calories |
| VO₂max | `vo2-max`, `daily-vo2-max`, `run-vo2-max` | VO₂max |
| Heart rhythm alerts | `irregular-rhythm-notification` | — |
| Weight / body fat | `weight`, `body-fat` (Aria only) | Weight / Body fat |
| Hydration/nutrition logs | `hydration-log`, `nutrition-log`, `food` | Hydration, Nutrition |
| Blood glucose | `blood-glucose` (manual/CGM) | Blood glucose |
| Stress | **not exposed** — compute from HR/HRV/movement | compute from HC records |
| Daily Readiness / Sleep Score (Google's) | **not exposed via API** — compute Bevel-style ourselves | — |

---

## 9. Product & UX requirements

1. **Onboarding**: welcome → install/sign in to the Google Health app + pair Fitbit Air
   (deep link `https://fitbit.google.com/wse/deeplink/store`) → enable
   Google Health → Health Connect sync (Google Health app settings → Connections) →
   Becel Health Connect permission flow (step-by-step, copy errors verbatim) →
   wearable check (verify Fitbit Air data present) → goals (sleep goal, activity level,
   sex/age for targets) → baseline calibration explanation.
2. **Calibration UX**: banners like Bevel's ("Building your baseline, day X of ~42"),
   grayscale/scored placeholders until enough data; never fabricate scores.
3. **Morning cycle**: sleep → recovery computed → notification "Recovery 72% — ready to
   train"; Today screen updated.
4. **Today**: 5 score cards (Recovery, Sleep, Strain vs Target, Stress, Energy Bank),
   coaching sentence, Timeline, + action button (log water/caffeine/food/workout/journal).
5. **Trends**: 1D/1W/1M/3M/6M/1Y ranges on every metric page; week-in-review screen.
6. **Settings**: sleep goal + auto-calc; HRV method (RMSSD default, SDNN option);
   resting HRV source (sleep vs awake); HR zone method (MaxHR/HR-Reserve/LTHR/manual);
   temp source; units; widgets config; privacy & data export/deletion.
7. **Privacy**: local-first storage; explicit consent screens; data export (JSON/CSV);
   account deletion; no ads; no third-party analytics on health data — same trust pitch
   as Bevel's "Built for privacy".
8. **Accessibility**: dynamic text, color-blind-safe score colors (don't rely on
   red/green only), TalkBack for score cards.

---

## 10. Technical architecture (proposed)

- **App**: Flutter (stable channel; project scaffolded here), Android only.
- **State**: Riverpod (or Bloc) + `go_router`; `Material 3` with custom dark theme.
- **Local DB**: Drift (SQLite) — raw data cache, aggregates, scores, settings.
- **Health data**: 
  - `health` plugin (Health Connect) for on-device ingestion + background reads.
  - `googleapis` REST client with AppAuth (`flutter_appauth`) for Google Health API v4 —
    system-browser flow required (Chrome Custom Tabs); `google_sign_in` is not used
    (add gRPC later only if needed).
- **Sync**: `workmanager` periodic jobs (on HC change / every 15–30 min), foreground
  service for long backfills; webhook receiver (needs minimal backend) for push updates.
- **Charts**: `fl_chart` (or custom painters for hypnogram/energy battery).
- **Notifications**: `flutter_local_notifications` + exact alarms for smart alarm window.
- **Widgets**: `home_widget` + Glance-style native Android widgets for score cards.
- **AI coach (v3)**: server-side LLM call with a sanitized metrics context; user opt-in;
  per-feature usage accounting (mirror Bevel Pro's weekly allowance); no raw health data
  retention by default.
- **Backend (optional but likely)**: minimal service for Google OAuth token exchange,
  webhook receipt, food DB proxy, AI proxy. Health data stays local by default.

**Repository layout (target)**

```
lib/
  app/            # theme, router, di
  core/           # models, utils, health-units
  data/
    health_connect/
    google_health/
    db/           # drift tables + DAOs
  domain/         # scoring engines (recovery, sleep, strain, stress, energy, cardio load)
  features/
    onboarding/ today/ sleep/ recovery/ strain/ stress/ energy/
    fitness/ nutrition/ journal/ biology/ settings/
  widgets/        # shared score cards, rings, charts
```

---

## 11. Phased roadmap & acceptance criteria

**Phase 0 — Foundation (done/next)**
- Flutter Android project (this repo, name `becel`). ✅
- CI (analyze + test), theming, navigation shell, Drift schema v1.

**Phase 1 — MVP scores (the reason to exist)**
- Health Connect ingestion (HR, HRV, RHR, RR, SpO₂, temp, sleep, steps, workouts).
- Recovery, Sleep, Strain, Stress, Energy Bank engines + Today screen + details + trends.
- Calibration states; morning notification; background sync; Play data-declaration.
- *Accept:* after 3 weeks of Fitbit Air data, scores available without gaps; app cold-start
  → Today < 2 s; scores refresh after each Google Health sync.

**Phase 2 — Fitness depth**
- Cardio Load/Status/Focus, HRR, workout list w/ zones, manual workouts, Timeline.
- Journal + insights, hydration/caffeine, Activity Status, widget(s).
- *Accept:* TRIMP load matches sanity checks on sample workouts; journal insights show
  correlations after 30 days.

**Phase 3 — Nutrition & Biology**
- Food logging (search/describe/barcode; photo AI if feasible), Nutrition Score, macros,
  net energy; glucose entry/CGM display; weight trend, LBM, BP, baselines; cycle tracking.
- *Accept:* daily energy balance ±5% vs Google Health totals.

**Phase 4 — Pro features**
- Google Health API cloud sync (OAuth + backfill + webhooks), health records (manual/PDF →
  labs), Biological Age + confidence, training plans, AI coach.
- *Accept:* 1-year backfill in < 5 min; AI answers cite user metrics correctly.

**Phase 5 — Polish/launch**
- Accessibility pass, performance pass, crash-free > 99.5%, privacy policy + data-safety
  forms, Play review incl. Health Connect declarations, beta via Play internal track.

---

## 12. Non-goals (explicit)

- iOS app (Bevel itself is iOS; this is the Android counterpart).
- Wear OS companion app in v1 (no Fitbit Air data path to a watch; revisit later).
- Direct Fitbit Air Bluetooth pairing / on-device workouts / wrist smart alarm
  (technically impossible for third parties; see §3).
- Live in-exercise HR display (post-hoc only).
- Medical claims; diagnosing illness; ECG-like features (Air has no ECG).
- Copying Bevel's trade dress, assets, copy, or brand.
- CGM hardware integration in v1 (glucose data entry/display only until a validated
  source is available via Health Connect).

---

## 13. Risks & legal

| Risk | Mitigation |
|---|---|
| Google Health API access gating (OAuth verification, CASA 4–6 wks, scopes) | Start now; build Phase 1–2 on Health Connect (no gating) |
| Fitbit Web API shutdown Oct 30, 2026 | Never code against legacy API |
| Health Connect sync must be user-enabled in Google Health app | Onboarding wizard + troubleshooting screens (mirror Google's docs) |
| Data gaps (watch off, battery, sync lag) | Explain gracefully; Bevel-style "scores unavailable" states; local re-sync |
| Fitbit HRV is averaged RMSSD (not raw RR) | Treat as our HRV truth; features use relative baselines, not absolute comparisons |
| Name "Becel" is an existing Unilever food brand | Legal check before launch; rename is cheap now (package id can stay) |
| Bevel may ship Android later | Move fast on Fitbit-Air niche; local-first privacy + Journal/Nutrition depth as moat |
| Health-data policies (Play health apps, GDPR/HIPAA-adjacent) | Local-first, consent, export/delete, no ad SDKs |
| Fake-score temptation during calibration | Hard rule: no score without required signals; show calibration UI |

---

## 14. References

**Bevel**
- https://www.bevel.health/ · https://www.bevel.health/app · https://www.bevel.health/watch-2
- App Store: https://apps.apple.com/us/app/bevel-ai-health-coach/id6456176249
- Help — Membership & Pricing: https://help.bevel.health/en/articles/11583937
- Help — Key Bevel Terms: https://help.bevel.health/en/articles/11251073
- Help — Recovery FAQ: https://help.bevel.health/en/articles/11258177
- Help — Stress & Energy FAQ: https://help.bevel.health/en/articles/11258369
- Help — Common Questions (calibration): https://help.bevel.health/en/articles/11257601
- Blog — Recovery: https://www.bevel.health/blog/what-is-recovery-score
- Blog — Sleep: https://www.bevel.health/blog/what-is-sleep-score
- Blog — Strain: https://www.bevel.health/blog/what-is-strain-score
- Blog — Cardio Load: https://www.bevel.health/blog/the-basics-cardio-load
- Blog — Biological Age: https://www.bevel.health/blog/biological-age-the-basics
- Independent review: https://bodly.app/blog/bevel-app-review
- Score explainer: https://www.fitcoin.co/articles/bevel-scores-explained

**Fitbit Air**
- https://www.wired.com/story/google-fitbit-air/
- https://uk.pcmag.com/fitness-trackers/165161/fitbit-air
- https://gadgetsandwearables.com/technical-specs/fitbit-air/
- https://store.google.com/us/product/google_fitbit_air_specs
- https://blog.google/intl/en-in/products/hardware/the-all-new-fitbit-air-comes-to-india/

**APIs & platform**
- Google Health API: https://developers.google.com/health
- Data types: https://developers.google.com/health/data-types
- Endpoints/data source families: https://developers.google.com/health/endpoints
- Migration from Fitbit Web API: https://developers.google.com/health/migration
- Health Connect: https://developer.android.com/health-and-fitness/health-connect
- Health Connect data types: https://developer.android.com/health-and-fitness/health-connect/data-types
- Google Health ⇄ Health Connect support: https://support.google.com/fitbit/answer/14506680
- CASA/migration timeline: https://help.validic.com/space/VCS/5535203416
