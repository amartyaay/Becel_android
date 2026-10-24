package com.becel.becel

import java.time.Duration
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import kotlin.math.roundToInt
import kotlin.math.roundToLong

internal data class ActivityEstimate(
    val age: Int,
    val estimatedMaxHrBpm: Int,
    val restingHrBpm: Double,
    val restingHrAt: Instant,
    val progressPercent: Int,
    val moderateMinutes: Double,
    val vigorousMinutes: Double,
    val usableDays: Int,
    val zoneMinutes: List<Double>,
    val zoneRanges: List<String>,
) {
    val equivalentMinutes: Double
        get() = moderateMinutes + 2 * vigorousMinutes

    fun toMethodChannelMap(): Map<String, Any> = mapOf(
        "age" to age,
        "estimatedMaxHrBpm" to estimatedMaxHrBpm,
        "restingHrBpm" to restingHrBpm,
        "restingHrAt" to restingHrAt.toEpochMilli(),
        "progressPercent" to progressPercent,
        "moderateMinutes" to moderateMinutes,
        "vigorousMinutes" to vigorousMinutes,
        "usableDays" to usableDays,
        "zoneMinutes" to zoneMinutes,
        "zoneRanges" to zoneRanges,
    )
}

/** Calculates seven-local-date, HRR-based moderate-equivalent minutes. */
internal object ActivityEstimator {
    private const val WINDOW_DAYS = 7L
    private const val MAX_SAMPLE_GAP_SECONDS = 120L
    private const val RESTING_HR_MAX_AGE_HOURS = 36L

    fun estimate(
        heartRateSamples: List<Pair<Instant, Long>>,
        restingHrSamples: List<Pair<Instant, Double>>,
        age: Int?,
        now: Instant,
        zone: ZoneId,
    ): ActivityEstimate? {
        if (age == null || age !in 18..100) return null

        val recentCutoff = now.minus(Duration.ofHours(RESTING_HR_MAX_AGE_HOURS))
        val restingRecord = restingHrSamples
            .asSequence()
            .filter { (at, bpm) ->
                at >= recentCutoff && at <= now && bpm in 30.0..120.0
            }
            .maxByOrNull { it.first }
            ?: return null

        val maximum = 208.0 - 0.7 * age
        val resting = restingRecord.second
        val reserve = maximum - resting
        if (reserve < 30.0) return null

        val today = now.atZone(zone).toLocalDate()
        val cutoff = today.minusDays(WINDOW_DAYS - 1)
            .atStartOfDay(zone)
            .toInstant()
        val ordered = heartRateSamples
            .asSequence()
            .filter { (at, bpm) ->
                at >= cutoff.minusSeconds(MAX_SAMPLE_GAP_SECONDS) &&
                    at <= now && bpm in 30L..240L
            }
            .distinct()
            .sortedBy { it.first }
            .toList()
        if (ordered.size < 2) return null

        val zones = DoubleArray(5)
        val usableDays = mutableSetOf<LocalDate>()
        var validIntervals = 0
        for (index in 0 until ordered.lastIndex) {
            val first = ordered[index]
            val second = ordered[index + 1]
            val gap = Duration.between(first.first, second.first).seconds
            if (gap <= 0 || gap > MAX_SAMPLE_GAP_SECONDS) continue

            var cursor = maxOf(first.first, cutoff)
            val intervalEnd = minOf(second.first, now)
            if (!intervalEnd.isAfter(cursor)) continue
            validIntervals++

            val midpoint = (first.second + second.second) / 2.0
            val hrr = (midpoint - resting) / reserve
            val zoneIndex = when {
                hrr < 0.30 -> 0
                hrr < 0.40 -> 1
                hrr < 0.60 -> 2
                hrr < 0.90 -> 3
                else -> 4
            }

            while (cursor < intervalEnd) {
                val localDate = cursor.atZone(zone).toLocalDate()
                val nextLocalDay = localDate.plusDays(1)
                    .atStartOfDay(zone)
                    .toInstant()
                val segmentEnd = minOf(intervalEnd, nextLocalDay)
                val segmentSeconds = Duration.between(cursor, segmentEnd).seconds
                if (segmentSeconds <= 0) break
                zones[zoneIndex] += segmentSeconds / 60.0
                usableDays.add(localDate)
                cursor = segmentEnd
            }
        }
        if (validIntervals == 0) return null

        val moderate = zones[2]
        val vigorous = zones[3] + zones[4]
        val equivalent = moderate + 2 * vigorous
        fun bpmAt(fraction: Double) = "${(resting + reserve * fraction).roundToLong()} bpm"

        return ActivityEstimate(
            age = age,
            estimatedMaxHrBpm = maximum.roundToInt(),
            restingHrBpm = resting,
            restingHrAt = restingRecord.first,
            progressPercent = (equivalent / 150.0 * 100).roundToInt().coerceIn(0, 100),
            moderateMinutes = moderate,
            vigorousMinutes = vigorous,
            usableDays = usableDays.size,
            zoneMinutes = zones.toList(),
            zoneRanges = listOf(
                "<${bpmAt(0.30)}",
                "${bpmAt(0.30)}-${bpmAt(0.40)}",
                "${bpmAt(0.40)}-${bpmAt(0.60)}",
                "${bpmAt(0.60)}-${bpmAt(0.90)}",
                ">${bpmAt(0.90)}",
            ),
        )
    }
}
