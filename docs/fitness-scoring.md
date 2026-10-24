# Fitness measures and scoring method

Becel shows three measures with separate inputs and time windows:

1. **Recovery index**: a 0-100 product estimate using sleep-duration progress, RMSSD HRV, and resting heart rate against personal history.
2. **Sleep duration**: recorded asleep time and progress toward a seven-hour adult reference. It is not a sleep-quality score.
3. **Weekly activity**: heart-rate-estimated moderate-equivalent minutes over the current day and previous six local calendar dates, compared with 150 minutes.

The measures are not combined into one health grade. Missing required inputs produce an unavailable state rather than zero. These are transparent wellness estimates, not clinical measures or validated predictions of recovery or performance.

## Sleep duration

```text
sleep_progress = min(minutes_asleep / 420, 1) * 100
```

The seven-hour reference reflects the consensus recommendation that healthy adults aged 18-60 regularly sleep at least seven hours; it is not an individualized prescription ([AASM/Sleep Research Society consensus](https://jcsm.aasm.org/doi/10.5664/jcsm.4758)). More than seven hours is not penalized. Becel sums Health Connect light, deep, and REM stage intervals when available. Awake, out-of-bed, and unknown intervals are not counted as asleep. Stages are shown as source data and are not graded because consumer wrist devices can disagree with polysomnography, especially on stage classification ([sleep tracker meta-analysis](https://pubmed.ncbi.nlm.nih.gov/39484805/)).

## Recovery index

The selected session is the **longest synced session with at least 180 asleep minutes that ended in the previous 24 hours**. It may be a long nap; Becel does not infer whether a session is a nap or overnight sleep. Sessions shorter than three hours do not produce a Recovery estimate. HRV readings count only when their timestamps fall inside a recorded light, deep, or REM interval for that session. Resting HR is a daily instantaneous Health Connect value, so Becel aligns its valid reading by the local date when the selected sleep session ended; it does not claim that RHR was measured during sleep. Android documents the record as instantaneous ([Health Connect data types](https://developer.android.com/health-and-fitness/health-connect/data-types)); its write guidance recommends a morning daily value ([Health Connect write guidance](https://developer.android.com/health-and-fitness/health-connect/write-data)).

For current HRV, Becel uses the median valid reading inside the selected session's asleep stages. For current RHR, it uses the median valid daily reading on the selected session's local end date. It selects the longest qualifying session on each of the previous 14 **local calendar dates**, excluding the selected session's date. A signal needs valid values on at least 10 distinct dates. Each historical HRV value is the median of readings inside that session's recorded asleep intervals. Each historical RHR value is the median of valid daily readings on that session's local end date. Each personal baseline is the median across its historical date values. HRV and resting HR can have different sample counts and baselines.

```text
HRV z = clamp((ln(current RMSSD) - median(ln(nightly RMSSD))) /
              max(0.10, 1.4826 * MAD(ln(nightly RMSSD))), -2, 2)
RHR z = clamp((current RHR - median(nightly RHR)) /
              max(2 bpm, 1.4826 * MAD(nightly RHR)), -2, 2)

HRV component = clamp(round(50 + 25 * HRV z), 0, 100)
RHR component = clamp(round(50 - 25 * RHR z), 0, 100)
Sleep component = min(minutes_asleep / 420, 1) * 100
Recovery index = round(0.40 * Sleep + 0.35 * HRV + 0.25 * RHR)
```

The `1.4826` factor expresses median absolute deviation (MAD) on a standard-deviation-like scale for normally distributed noise. The 0.10 log-unit HRV floor and 2 bpm resting-HR floor keep repeated, rounded wearable values from creating a zero denominator. HRV is compared in log space because it is a positive, right-skewed measure. A score can span 0-100; the component values and their weights are displayed so the total can be checked.

When current sleep-stage HRV has fewer than two valid readings, the current daily RHR is missing, or either baseline has fewer than all 14 possible dates, Becel marks the result **Limited data**. One daily RHR record is sufficient current coverage because Health Connect defines RHR as a daily instantaneous value. The estimate remains available with one current HRV reading and with 10-13 baseline dates, but the badge and component detail make the thinner coverage visible. Historical baseline still requires at least 10 valid dates per signal. The date association for daily RHR is an explicit product rule and has not been checked against real Fitbit Air Health Connect records. These thresholds, weights, noise floors, and score mapping are Becel product choices; they have not been validated against clinical or athletic outcomes. HRV is most useful for longitudinal, individual interpretation ([applied sport review](https://pubmed.ncbi.nlm.nih.gov/42647345/)).

WHOOP and Bevel are design references for presenting recovery alongside sleep and physiological signals and for using personal baselines. Becel does not reproduce their proprietary formulas ([WHOOP Basics](https://support.whoop.com/s/article/WHOOP-Basics), [Bevel Recovery](https://help.bevel.health/en/articles/11258177), [Bevel baseline requirements](https://help.bevel.health/en/articles/11257601)).

## Weekly activity estimate

The adult aerobic guideline is at least 150 minutes of moderate activity, 75 minutes of vigorous activity, or an equivalent combination per week ([CDC](https://www.cdc.gov/physical-activity-basics/guidelines/adults.html)). Becel reports moderate-equivalent minutes over the current local date and previous six local dates:

```text
moderate_equivalent_minutes = moderate_minutes + 2 * vigorous_minutes
progress = min(moderate_equivalent_minutes / 150, 1) * 100
```

For adjacent Fitbit Air heart-rate samples no more than 120 seconds apart, Becel classifies the interval using midpoint heart rate and heart-rate reserve (HRR). Multiple valid values with the same timestamp are coalesced to their median BPM before intervals are built:

```text
estimated_max_HR = 208 - 0.7 * age
HRR = (midpoint_HR - resting_HR) / (estimated_max_HR - resting_HR)
```

The bands are below 30% HRR, 30-39%, 40-59% (moderate), 60-89% (vigorous), and 90% or higher. Vigorous and near-maximal time both count as vigorous for the equivalent-minute total. These are commonly used heart-rate-reserve bands ([INTERLIVE review](https://pmc.ncbi.nlm.nih.gov/articles/PMC11946962/)). The maximum-heart-rate equation is a population estimate, not a measured maximum; Tanaka et al. report a population regression and a validation study found approximately 10 bpm standard error in its participants ([Tanaka et al.](https://pubmed.ncbi.nlm.nih.gov/11153730/), [HERITAGE comparison](https://pmc.ncbi.nlm.nih.gov/articles/PMC3935487/)).

This estimate requires age 18-100 and a valid resting-HR record from the previous 36 hours. The latest such resting-HR value is applied to all seven dates. Becel shows its value and timestamp alongside the estimate because it can be stale for much of the week. Heart-rate samples outside 30-240 bpm are ignored. Weekly sample processing and zone calculation happen on Android; Flutter receives the resulting zone totals, ranges, progress, input values, and number of local dates with usable intervals, not the raw weekly heart-rate series.

Coverage means **at least one usable interval on that date**, not full-day wear time. Missing wear time and gaps over two minutes are not counted and can lower the total. A raised pulse does not confirm exercise. Heart-rate estimates can miss resistance training and activity with atypical heart responses, including effects from medication, illness, or heat. The estimate does not account for strength-training days, perceived exertion, training phase, or workout intent. Becel calls this **Weekly activity**, not strain or training readiness.

## References

- [AASM/Sleep Research Society adult sleep consensus](https://jcsm.aasm.org/doi/10.5664/jcsm.4758)
- [Wearable sleep trackers compared with polysomnography: meta-analysis](https://pubmed.ncbi.nlm.nih.gov/39484805/)
- [CDC adult physical activity guidelines](https://www.cdc.gov/physical-activity-basics/guidelines/adults.html)
- [INTERLIVE review of consumer wearable heart-rate algorithms](https://pmc.ncbi.nlm.nih.gov/articles/PMC11946962/)
- [Tanaka, Monahan, and Seals (2001)](https://pubmed.ncbi.nlm.nih.gov/11153730/)
- [HERITAGE validation comparison](https://pmc.ncbi.nlm.nih.gov/articles/PMC3935487/)
- [Applied sport monitoring review of RMSSD](https://pubmed.ncbi.nlm.nih.gov/42647345/)
- [Android Health Connect write guidance](https://developer.android.com/health-and-fitness/health-connect/write-data) and [data type reference](https://developer.android.com/health-and-fitness/health-connect/data-types)
- [WHOOP Basics](https://support.whoop.com/s/article/WHOOP-Basics)
- [Bevel Recovery](https://help.bevel.health/en/articles/11258177) and [baseline requirements](https://help.bevel.health/en/articles/11257601)
