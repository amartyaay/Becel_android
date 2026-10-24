package com.becel.becel

import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertNotNull
import org.junit.Test

class ActivityEstimatorTest {
    private val zone = ZoneId.of("UTC")
    private val now = Instant.parse("2026-10-24T12:00:00Z")

    @Test
    fun classifiesHeartRateReserveBoundaries() {
        val cases = listOf(
            95L to 0,
            96L to 1,
            107L to 1,
            108L to 2,
            131L to 2,
            132L to 3,
            167L to 3,
            168L to 4,
        )

        for ((bpm, expectedZone) in cases) {
            val start = now.minusSeconds(60)
            val estimate = estimate(
                heartRates = listOf(start to bpm, now to bpm),
            )

            assertNotNull("Expected an estimate at $bpm bpm", estimate)
            assertEquals("Zone for $bpm bpm", 1.0, estimate!!.zoneMinutes[expectedZone], 0.0001)
            assertEquals(1.0, estimate.zoneMinutes.sum(), 0.0001)
        }
    }

    @Test
    fun accepts120SecondGapAndRejects121SecondGap() {
        val start = now.minusSeconds(120)
        val atLimit = estimate(heartRates = listOf(start to 120L, now to 120L))

        assertNotNull(atLimit)
        assertEquals(2.0, atLimit!!.moderateMinutes, 0.0001)

        val tooWideStart = now.minusSeconds(121)
        assertNull(estimate(heartRates = listOf(tooWideStart to 120L, now to 120L)))

        val fractionalTooWideStart = now.minusMillis(120_900)
        assertNull(
            estimate(heartRates = listOf(fractionalTooWideStart to 120L, now to 120L)),
        )
    }

    @Test
    fun conflictingRepeatedTimestampsAreCoalescedIndependentOfInputOrder() {
        val start = now.minusSeconds(60)
        val firstOrder = estimate(
            heartRates = listOf(
                start to 120L,
                start to 180L,
                now to 120L,
            ),
        )
        val reversedOrder = estimate(
            heartRates = listOf(
                start to 180L,
                start to 120L,
                now to 120L,
            ),
        )

        assertNotNull(firstOrder)
        assertNotNull(reversedOrder)
        assertEquals(firstOrder!!.zoneMinutes, reversedOrder!!.zoneMinutes)
        assertEquals(1.0, firstOrder.vigorousMinutes, 0.0001)
        assertEquals(1, firstOrder.usableDays)
    }

    @Test
    fun restingHeartRateMustBeRecentValidAndLeaveUsableReserve() {
        val recentHeartRates = listOf(now.minusSeconds(60) to 120L, now to 120L)
        val atAgeLimit = estimate(
            heartRates = recentHeartRates,
            resting = listOf(now.minusSeconds(36 * 60 * 60) to 60.0),
        )
        assertNotNull(atAgeLimit)

        val stale = estimate(
            heartRates = recentHeartRates,
            resting = listOf(now.minusSeconds(36 * 60 * 60 + 1) to 60.0),
        )
        assertNull(stale)

        assertNull(estimate(heartRates = recentHeartRates, age = 17))
        assertNull(
            estimate(
                heartRates = recentHeartRates,
                resting = listOf(now to 109.0), // max HR 138; reserve is below 30.
                age = 100,
            ),
        )
        assertNull(
            estimate(
                heartRates = recentHeartRates,
                resting = listOf(now to 121.0),
            ),
        )
    }

    @Test
    fun countsBothLocalDatesWhenAnIntervalCrossesMidnight() {
        val localNow = Instant.parse("2026-04-11T00:01:00Z")
        val start = Instant.parse("2026-04-10T23:59:00Z")
        val estimate = estimate(
            heartRates = listOf(start to 120L, localNow to 120L),
            now = localNow,
        )

        assertNotNull(estimate)
        assertEquals(2.0, estimate!!.moderateMinutes, 0.0001)
        assertEquals(2, estimate.usableDays)
        assertEquals("2026-04-10", estimate.dailyDates[5])
        assertEquals("2026-04-11", estimate.dailyDates[6])
        assertEquals(1.0, estimate.dailyEquivalentMinutes[5]!!, 0.0001)
        assertEquals(1.0, estimate.dailyEquivalentMinutes[6]!!, 0.0001)
        assertEquals(1.0, estimate.dailyCoverageMinutes[5], 0.0001)
        assertEquals(1.0, estimate.dailyCoverageMinutes[6], 0.0001)
    }

    @Test
    fun usesSevenLocalCalendarDatesAcrossDaylightSavingChange() {
        val eastern = ZoneId.of("America/New_York")
        val localNow = Instant.parse("2026-03-08T22:00:00Z") // 18:00 after DST starts.
        val today = localNow.atZone(eastern).toLocalDate()
        val samples = mutableListOf<Pair<Instant, Long>>()
        for (offset in 6L downTo 0L) {
            val at = today.minusDays(offset)
                .atTime(12, 0)
                .atZone(eastern)
                .toInstant()
            samples.add(at to 120L)
            samples.add(at.plusSeconds(60) to 120L)
        }
        val estimate = ActivityEstimator.estimate(
            heartRateSamples = samples,
            restingHrSamples = listOf(localNow.minusSeconds(60) to 60.0),
            age = 40,
            now = localNow,
            zone = eastern,
        )

        assertNotNull(estimate)
        assertEquals(7, estimate!!.usableDays)
        assertEquals(7.0, estimate.moderateMinutes, 0.0001)
        assertEquals(7, estimate.dailyDates.size)
        assertEquals(List(7) { 1.0 }, estimate.dailyEquivalentMinutes)
        assertEquals(List(7) { 1.0 }, estimate.dailyCoverageMinutes)
        assertEquals(LocalDate.of(2026, 3, 8), localNow.atZone(eastern).toLocalDate())
    }

    private fun estimate(
        heartRates: List<Pair<Instant, Long>>,
        resting: List<Pair<Instant, Double>>? = null,
        age: Int? = 40,
        now: Instant = this.now,
    ) = ActivityEstimator.estimate(
        heartRateSamples = heartRates,
        restingHrSamples = resting ?: listOf(now.minusSeconds(60) to 60.0),
        age = age,
        now = now,
        zone = zone,
    )
}
