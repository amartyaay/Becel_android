package com.becel.becel

import android.content.ContentValues
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import androidx.activity.result.ActivityResultLauncher
import androidx.activity.result.contract.ActivityResultContracts
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.PermissionController
import androidx.health.connect.client.permission.HealthPermission
import androidx.health.connect.client.records.ActiveCaloriesBurnedRecord
import androidx.health.connect.client.records.BasalMetabolicRateRecord
import androidx.health.connect.client.records.DistanceRecord
import androidx.health.connect.client.records.ExerciseSessionRecord
import androidx.health.connect.client.records.FloorsClimbedRecord
import androidx.health.connect.client.records.HeartRateRecord
import androidx.health.connect.client.records.HeartRateVariabilityRmssdRecord
import androidx.health.connect.client.records.OxygenSaturationRecord
import androidx.health.connect.client.records.Record
import androidx.health.connect.client.records.RespiratoryRateRecord
import androidx.health.connect.client.records.RestingHeartRateRecord
import androidx.health.connect.client.records.SkinTemperatureRecord
import androidx.health.connect.client.records.SleepSessionRecord
import androidx.health.connect.client.records.StepsRecord
import androidx.health.connect.client.records.TotalCaloriesBurnedRecord
import androidx.health.connect.client.records.Vo2MaxRecord
import androidx.health.connect.client.records.metadata.DataOrigin
import androidx.health.connect.client.records.metadata.Metadata
import androidx.health.connect.client.request.ReadRecordsRequest
import androidx.health.connect.client.time.TimeRangeFilter
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.File
import java.time.Duration
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.util.Locale

class MainActivity : FlutterFragmentActivity() {
    private lateinit var healthPermissionLauncher: ActivityResultLauncher<Set<String>>
    private lateinit var bluetoothPermissionLauncher: ActivityResultLauncher<Array<String>>
    private var pendingPermissionResult: MethodChannel.Result? = null
    private val airHapticsFeature: AirHapticsFeature = AirHapticsFeatureImpl()
    private val healthScope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        healthPermissionLauncher = registerForActivityResult(
            PermissionController.createRequestPermissionResultContract(),
        ) { grantedPermissions ->
            pendingPermissionResult?.success(
                mapOf("granted" to grantedPermissions.toList().sorted()),
            )
            pendingPermissionResult = null
        }
        bluetoothPermissionLauncher = registerForActivityResult(
            ActivityResultContracts.RequestMultiplePermissions(),
        ) { grants -> airHapticsFeature.onBluetoothPermissionsResult(grants) }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL_NAME,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "inspect" -> launchHealth(result) { inspectHealthConnect() }
                "requestPermissions" -> requestPermissions(result)
                "readSummary" -> launchHealth(result) { readSummary() }
                "readHeartDetail" -> launchHealth(result) { readHeartDetail() }
                "readFitnessAge" -> result.success(readFitnessAge())
                "saveFitnessAge" -> saveFitnessAge(call.argument<Int>("age"), result)
                "readSleepDetail" -> launchHealth(result) { readSleepDetail() }
                "readTrends7d" -> launchHealth(result) { readTrends7d() }
                "readActivityDetail" -> launchHealth(result) { readActivityDetail() }
                "readBodyDetail" -> launchHealth(result) { readBodyDetail() }
                "openProviderStore" -> openProviderStore(result)
                else -> result.notImplemented()
            }
        }
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            LOCAL_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "read" -> result.success(readLocalLog())
                "write" -> result.success(
                    writeLocalLog(call.argument<String>("json") ?: "{}"),
                )
                "clear" -> result.success(clearLocalData())
                "shareText" -> shareText(
                    call.argument<String>("text") ?: "",
                    result,
                )
                "exportCsv" -> result.success(
                    exportCsv(call.argument<String>("csv") ?: ""),
                )
                else -> result.notImplemented()
            }
        }
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            AIR_HAPTICS_CHANNEL,
        ).setMethodCallHandler { call, result ->
            if (!airHapticsFeature.handleMethodCall(
                    this,
                    call,
                    result,
                    bluetoothPermissionLauncher::launch,
                )
            ) {
                result.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        airHapticsFeature.onDestroy()
        super.onDestroy()
    }

    private fun requestPermissions(result: MethodChannel.Result) {
        if (pendingPermissionResult != null) {
            result.error("REQUEST_IN_PROGRESS", "A permission request is already open.", null)
            return
        }

        val availability = HealthConnectClient.getSdkStatus(this, PROVIDER_PACKAGE)
        if (availability != HealthConnectClient.SDK_AVAILABLE) {
            result.error(
                "HEALTH_CONNECT_UNAVAILABLE",
                availabilityName(availability),
                null,
            )
            return
        }

        pendingPermissionResult = result
        try {
            healthPermissionLauncher.launch(READ_PERMISSIONS)
        } catch (error: Exception) {
            pendingPermissionResult = null
            result.error("PERMISSION_LAUNCH_FAILED", error.message, null)
        }
    }

    private suspend fun inspectHealthConnect(): Map<String, Any?> {
        val availability = HealthConnectClient.getSdkStatus(this, PROVIDER_PACKAGE)
        val granted = if (availability == HealthConnectClient.SDK_AVAILABLE) {
            HealthConnectClient.getOrCreate(this)
                .permissionController
                .getGrantedPermissions()
                .toList()
                .sorted()
        } else {
            emptyList()
        }

        return mapOf(
            "availability" to availabilityName(availability),
            "granted" to granted,
            "requested" to READ_PERMISSIONS.toList().sorted(),
            "checkedAt" to Instant.now().toString(),
        )
    }

    private suspend fun readSummary(): Map<String, Any?> {
        val availability = HealthConnectClient.getSdkStatus(this, PROVIDER_PACKAGE)
        if (availability != HealthConnectClient.SDK_AVAILABLE) {
            return mapOf(
                "status" to availabilityName(availability),
                "checkedAt" to Instant.now().toString(),
            )
        }

        val client = HealthConnectClient.getOrCreate(this)
        val granted = client.permissionController.getGrantedPermissions()
        val now = Instant.now()
        val zone = ZoneId.systemDefault()
        val todayStart = LocalDate.now(zone).atStartOfDay(zone).toInstant()
        val data = mutableMapOf<String, Any?>(
            "status" to if (granted.isEmpty()) "permissionRequired" else "ready",
            "granted" to granted.toList().sorted(),
            "checkedAt" to now.toString(),
            "fitbitAirMetadataMatched" to false,
            "stepCount" to null,
            "heartRateBpm" to null,
            "heartRateAt" to null,
            "heartRateSource" to null,
            "heartRateDevice" to null,
            "sleepSessionMinutes" to null,
            "sleepStart" to null,
            "sleepEnd" to null,
            "sleepSource" to null,
            "sleepDevice" to null,
            "workoutType" to null,
            "workoutStart" to null,
            "workoutDurationMinutes" to null,
            "workoutSource" to null,
            "workoutDevice" to null,
        )

        var fitbitAirRecordCount = 0

        if (HealthPermission.getReadPermission(StepsRecord::class) in granted) {
            val range = TimeRangeFilter.between(todayStart, now)
            val records = mutableListOf<StepsRecord>()
            var pageToken: String? = null
            do {
                val response = client.readRecords(
                    ReadRecordsRequest<StepsRecord>(
                        timeRangeFilter = range,
                        pageSize = 1000,
                        pageToken = pageToken,
                        dataOriginFilter = AIR_SOURCE_ORIGINS,
                    ),
                )
                records.addAll(response.records.filter { isFitbitAirRecord(it.metadata) })
                pageToken = response.pageToken
            } while (!pageToken.isNullOrEmpty())

            if (records.isNotEmpty()) {
                fitbitAirRecordCount += records.size
                data["stepCount"] = records.sumOf { it.count }
            }
        }

        if (HealthPermission.getReadPermission(HeartRateRecord::class) in granted) {
            val start = now.minus(Duration.ofHours(24))
            val records = mutableListOf<HeartRateRecord>()
            var pageToken: String? = null
            do {
                val response = client.readRecords(
                    ReadRecordsRequest<HeartRateRecord>(
                        timeRangeFilter = TimeRangeFilter.between(start, now),
                        pageSize = 1000,
                        pageToken = pageToken,
                        dataOriginFilter = AIR_SOURCE_ORIGINS,
                    ),
                )
                val airRecords = response.records.filter { isFitbitAirRecord(it.metadata) }
                fitbitAirRecordCount += airRecords.size
                records.addAll(airRecords)
                pageToken = response.pageToken
            } while (!pageToken.isNullOrEmpty())
            val latest = records
                .flatMap { record ->
                    record.samples.map { sample ->
                        Triple(sample.time, sample.beatsPerMinute, record)
                    }
                }
                .maxByOrNull { it.first }
            if (latest != null) {
                data["heartRateBpm"] = latest.second
                data["heartRateAt"] = latest.first.toString()
                data["heartRateSource"] = "Fitbit Air"
            }
        }

        if (HealthPermission.getReadPermission(SleepSessionRecord::class) in granted) {
            val start = now.minus(Duration.ofHours(36))
            val records = mutableListOf<SleepSessionRecord>()
            var pageToken: String? = null
            do {
                val response = client.readRecords(
                    ReadRecordsRequest<SleepSessionRecord>(
                        timeRangeFilter = TimeRangeFilter.between(start, now),
                        pageSize = 100,
                        pageToken = pageToken,
                        dataOriginFilter = AIR_SOURCE_ORIGINS,
                    ),
                )
                val airRecords = response.records.filter { isFitbitAirRecord(it.metadata) }
                fitbitAirRecordCount += airRecords.size
                records.addAll(airRecords)
                pageToken = response.pageToken
            } while (!pageToken.isNullOrEmpty())
            // This is a raw recent-session summary. Recovery selects its
            // qualifying session separately from full staged sleep detail.
            val recent = records.filter { it.endTime >= now.minus(Duration.ofHours(24)) }
            val main = (recent.ifEmpty { records }).maxByOrNull {
                Duration.between(it.startTime, it.endTime)
            }
            if (main != null) {
                data["sleepSessionMinutes"] =
                    Duration.between(main.startTime, main.endTime).toMinutes()
                data["sleepStart"] = main.startTime.toString()
                data["sleepEnd"] = main.endTime.toString()
                data["sleepSource"] = "Fitbit Air"
            }
        }

        if (HealthPermission.getReadPermission(ExerciseSessionRecord::class) in granted) {
            val start = now.minus(Duration.ofDays(7))
            val records = mutableListOf<ExerciseSessionRecord>()
            var pageToken: String? = null
            do {
                val response = client.readRecords(
                    ReadRecordsRequest<ExerciseSessionRecord>(
                        timeRangeFilter = TimeRangeFilter.between(start, now),
                        pageSize = 100,
                        pageToken = pageToken,
                        dataOriginFilter = AIR_SOURCE_ORIGINS,
                    ),
                )
                val airRecords = response.records.filter { isFitbitAirRecord(it.metadata) }
                fitbitAirRecordCount += airRecords.size
                records.addAll(airRecords)
                pageToken = response.pageToken
            } while (!pageToken.isNullOrEmpty())
            val latest = records.maxByOrNull { it.endTime }
            if (latest != null) {
                data["workoutType"] = exerciseName(latest.exerciseType)
                data["workoutStart"] = latest.startTime.toString()
                data["workoutDurationMinutes"] =
                    Duration.between(latest.startTime, latest.endTime).toMinutes()
                data["workoutSource"] = "Fitbit Air"
            }
        }

        data["fitbitAirMetadataMatched"] = fitbitAirRecordCount > 0
        return data
    }

    private suspend inline fun <reified T : Record> readAirRecords(
        client: HealthConnectClient,
        start: Instant,
        end: Instant,
    ): List<T> {
        val records = mutableListOf<T>()
        var pageToken: String? = null
        var pages = 0
        do {
            val response = client.readRecords(
                ReadRecordsRequest<T>(
                    timeRangeFilter = TimeRangeFilter.between(start, end),
                    pageSize = 1000,
                    pageToken = pageToken,
                    dataOriginFilter = AIR_SOURCE_ORIGINS,
                ),
            )
            records.addAll(response.records.filter { isFitbitAirRecord(it.metadata) })
            pageToken = response.pageToken
            pages++
        } while (!pageToken.isNullOrEmpty() && pages < 100)
        return records
    }

    private suspend fun readHeartDetail(): Map<String, Any?> {
        val availability = HealthConnectClient.getSdkStatus(this, PROVIDER_PACKAGE)
        if (availability != HealthConnectClient.SDK_AVAILABLE) {
            return mapOf(
                "status" to availabilityName(availability),
                "checkedAt" to Instant.now().toString(),
            )
        }
        val client = HealthConnectClient.getOrCreate(this)
        val granted = client.permissionController.getGrantedPermissions()
        val now = Instant.now()
        val zone = ZoneId.systemDefault()
        val todayStart = LocalDate.now(zone).atStartOfDay(zone).toInstant()
        val weekStart = LocalDate.now(zone).minusDays(6).atStartOfDay(zone).toInstant()
        val loadStart = LocalDate.now(zone).minusDays(LOAD_WINDOW_DAYS - 1).atStartOfDay(zone).toInstant()
        val allSamples = mutableListOf<Pair<Instant, Long>>()
        val trainingSamples = mutableListOf<Pair<Instant, Long>>()
        var activityRestingHrSamples = emptyList<Pair<Instant, Double>>()
        val data = mutableMapOf<String, Any?>(
            "status" to if (granted.isEmpty()) "permissionRequired" else "ready",
            "granted" to granted.toList().sorted(),
            "checkedAt" to now.toString(),
            "series" to emptyList<List<Long>>(),
            "weeklySeries" to emptyList<List<Long>>(),
            "minuteSeries" to emptyList<List<Long>>(),
            "stepBuckets" to emptyList<List<Long>>(),
            "restingHrSamples" to emptyList<List<Any>>(),
            "hrvSamples" to emptyList<List<Any>>(),
            "activityEstimate" to null,
            "latestBpm" to null,
            "latestAt" to null,
            "minBpm" to null,
            "avgBpm" to null,
            "maxBpm" to null,
            "restingHrBpm" to null,
            "hrvRmssd" to null,
        )

        if (HealthPermission.getReadPermission(HeartRateRecord::class) in granted) {
            var pageToken: String? = null
            var pages = 0
            do {
                val response = client.readRecords(
                    ReadRecordsRequest<HeartRateRecord>(
                        timeRangeFilter = TimeRangeFilter.between(loadStart.minusSeconds(120), now),
                        pageSize = 1000,
                        pageToken = pageToken,
                        dataOriginFilter = AIR_SOURCE_ORIGINS,
                    ),
                )
                response.records
                    .filter { isFitbitAirRecord(it.metadata) }
                    .forEach { record ->
                        record.samples.forEach { sample ->
                            allSamples.add(sample.time to sample.beatsPerMinute)
                            if (sample.time >= weekStart.minusSeconds(120)) {
                                trainingSamples.add(sample.time to sample.beatsPerMinute)
                            }
                        }
                    }
                pageToken = response.pageToken
                pages++
            } while (!pageToken.isNullOrEmpty() && pages < 400)

            // One-minute medians keep interval peaks that 5-minute means
            // flatten, while staying small enough for the method channel.
            val minuteBuckets = sortedMapOf<Long, MutableList<Long>>()
            allSamples.forEach { (time, bpm) ->
                if (bpm in 30L..240L) {
                    minuteBuckets.getOrPut(time.toEpochMilli() / 60_000L) { mutableListOf() }.add(bpm)
                }
            }
            data["minuteSeries"] = minuteBuckets.map { (minute, values) ->
                values.sort()
                listOf(minute * 60_000L, values[values.size / 2])
            }

            val today = trainingSamples.filter { it.first >= todayStart }.sortedBy { it.first }
            if (today.isNotEmpty()) {
                val values = today.map { it.second }
                data["minBpm"] = values.min()
                data["maxBpm"] = values.max()
                data["avgBpm"] = values.average().toLong()
                val latest = today.last()
                data["latestBpm"] = latest.second
                data["latestAt"] = latest.first.toString()

                val buckets = sortedMapOf<Long, LongArray>()
                today.forEach { (time, bpm) ->
                    val bucket = time.toEpochMilli() / HEART_BUCKET_MILLIS
                    val entry = buckets.getOrPut(bucket) { longArrayOf(0L, 0L) }
                    entry[0] += 1
                    entry[1] += bpm
                }
                data["series"] = buckets.map { (bucket, entry) ->
                    listOf(bucket * HEART_BUCKET_MILLIS, entry[1] / entry[0])
                }

            }
            if (trainingSamples.isNotEmpty()) {
                val weeklyBuckets = sortedMapOf<Long, LongArray>()
                trainingSamples.forEach { (time, bpm) ->
                    val bucket = time.toEpochMilli() / HEART_BUCKET_MILLIS
                    val entry = weeklyBuckets.getOrPut(bucket) { longArrayOf(0L, 0L) }
                    entry[0] += 1
                    entry[1] += bpm
                }
                data["weeklySeries"] = weeklyBuckets.map { (bucket, entry) ->
                    listOf(bucket * HEART_BUCKET_MILLIS, entry[1] / entry[0])
                }
            }
        }

        if (HealthPermission.getReadPermission(RestingHeartRateRecord::class) in granted) {
            val records = readAirRecords<RestingHeartRateRecord>(
                client,
                now.minus(Duration.ofDays(30)),
                now,
            )
            if (records.isNotEmpty()) {
                val ordered = records.sortedBy { it.time }
                data["restingHrBpm"] = ordered.last().beatsPerMinute
                activityRestingHrSamples = ordered.map { record ->
                    record.time to record.beatsPerMinute.toDouble()
                }
                data["restingHrSamples"] = activityRestingHrSamples.map { (time, bpm) ->
                    listOf(time.toEpochMilli(), bpm)
                }
            }
        }

        if (HealthPermission.getReadPermission(HeartRateVariabilityRmssdRecord::class) in granted) {
            val records = readAirRecords<HeartRateVariabilityRmssdRecord>(
                client,
                now.minus(Duration.ofDays(30)),
                now,
            )
            if (records.isNotEmpty()) {
                val ordered = records.sortedBy { it.time }
                data["hrvRmssd"] = ordered.last().heartRateVariabilityMillis
                data["hrvSamples"] = ordered.map { record ->
                    listOf(record.time.toEpochMilli(), record.heartRateVariabilityMillis)
                }
            }
        }

        if (HealthPermission.getReadPermission(StepsRecord::class) in granted) {
            // Spread each step record evenly across the 5-minute buckets it
            // overlaps so Flutter can separate walking from incidental steps.
            val buckets = sortedMapOf<Long, Double>()
            readAirRecords<StepsRecord>(client, loadStart, now).forEach { record ->
                val start = record.startTime.toEpochMilli()
                val end = maxOf(record.endTime.toEpochMilli(), start + 1)
                val span = (end - start).toDouble()
                var cursor = start
                while (cursor < end) {
                    val bucket = cursor / STEP_BUCKET_MILLIS
                    val bucketEnd = minOf(end, (bucket + 1) * STEP_BUCKET_MILLIS)
                    buckets[bucket] = (buckets[bucket] ?: 0.0) +
                        record.count * (bucketEnd - cursor) / span
                    cursor = bucketEnd
                }
            }
            data["stepBuckets"] = buckets
                .filterValues { it >= 0.5 }
                .map { (bucket, steps) ->
                    listOf(bucket * STEP_BUCKET_MILLIS, Math.round(steps))
                }
        }

        data["activityEstimate"] = ActivityEstimator.estimate(
            heartRateSamples = trainingSamples,
            restingHrSamples = activityRestingHrSamples,
            age = readFitnessAge(),
            now = now,
            zone = zone,
        )?.toMethodChannelMap()

        return data
    }

    private fun readFitnessAge(): Int? {
        val age = getSharedPreferences(FITNESS_PROFILE_PREFS, MODE_PRIVATE)
            .getInt(FITNESS_AGE_KEY, -1)
        return age.takeIf { it in 18..100 }
    }

    private fun saveFitnessAge(age: Int?, result: MethodChannel.Result) {
        if (age != null && age !in 18..100) {
            result.success(false)
            return
        }
        val preferences = getSharedPreferences(FITNESS_PROFILE_PREFS, MODE_PRIVATE)
        val saved = if (age == null) {
            preferences.edit().remove(FITNESS_AGE_KEY).commit()
        } else {
            preferences.edit().putInt(FITNESS_AGE_KEY, age).commit()
        }
        result.success(saved)
    }

    private fun readLocalLog(): String? =
        getSharedPreferences(LOCAL_LOG_PREFS, MODE_PRIVATE)
            .getString(LOCAL_LOG_KEY, null)

    private fun writeLocalLog(json: String): Boolean =
        getSharedPreferences(LOCAL_LOG_PREFS, MODE_PRIVATE)
            .edit()
            .putString(LOCAL_LOG_KEY, json)
            .commit()

    private fun clearLocalData(): Boolean {
        val logCleared = getSharedPreferences(LOCAL_LOG_PREFS, MODE_PRIVATE)
            .edit()
            .clear()
            .commit()
        val profileCleared = getSharedPreferences(FITNESS_PROFILE_PREFS, MODE_PRIVATE)
            .edit()
            .clear()
            .commit()
        return logCleared && profileCleared
    }

    private fun shareText(text: String, result: MethodChannel.Result) {
        if (text.isBlank()) {
            result.success(false)
            return
        }
        try {
            val intent = Intent(Intent.ACTION_SEND).apply {
                type = "text/plain"
                putExtra(Intent.EXTRA_TEXT, text)
            }
            startActivity(Intent.createChooser(intent, "Share Becel summary"))
            result.success(true)
        } catch (error: Exception) {
            result.success(false)
        }
    }

    private fun exportCsv(csv: String): String? {
        if (csv.isBlank()) return null
        val fileName = "becel-week-${LocalDate.now()}.csv"
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                val values = ContentValues().apply {
                    put(MediaStore.MediaColumns.DISPLAY_NAME, fileName)
                    put(MediaStore.MediaColumns.MIME_TYPE, "text/csv")
                    put(
                        MediaStore.MediaColumns.RELATIVE_PATH,
                        "${Environment.DIRECTORY_DOWNLOADS}/Becel",
                    )
                }
                val uri = contentResolver.insert(
                    MediaStore.Downloads.EXTERNAL_CONTENT_URI,
                    values,
                ) ?: return null
                contentResolver.openOutputStream(uri)?.use {
                    it.write(csv.toByteArray(Charsets.UTF_8))
                }
                uri.toString()
            } else {
                val directory = File(
                    getExternalFilesDir(Environment.DIRECTORY_DOCUMENTS),
                    "Becel",
                )
                if (!directory.exists()) directory.mkdirs()
                val file = File(directory, fileName)
                file.writeText(csv, Charsets.UTF_8)
                Uri.fromFile(file).toString()
            }
        } catch (error: Exception) {
            null
        }
    }

    private suspend fun readSleepDetail(): Map<String, Any?> {
        val availability = HealthConnectClient.getSdkStatus(this, PROVIDER_PACKAGE)
        if (availability != HealthConnectClient.SDK_AVAILABLE) {
            return mapOf(
                "status" to availabilityName(availability),
                "checkedAt" to Instant.now().toString(),
            )
        }
        val client = HealthConnectClient.getOrCreate(this)
        val granted = client.permissionController.getGrantedPermissions()
        val now = Instant.now()
        val sessions = mutableListOf<Map<String, Any?>>()

        if (HealthPermission.getReadPermission(SleepSessionRecord::class) in granted) {
            val records = readAirRecords<SleepSessionRecord>(
                client,
                now.minus(Duration.ofDays(30)),
                now,
            )
            records.sortedByDescending { it.endTime }.forEach { record ->
                var awake = 0L
                var light = 0L
                var deep = 0L
                var rem = 0L
                var unstaged = 0L
                val asleepIntervals = mutableListOf<List<Long>>()
                record.stages.forEach { stage ->
                    val minutes = Duration.between(stage.startTime, stage.endTime)
                        .toMinutes().coerceAtLeast(0)
                    when (stage.stage) {
                        SleepSessionRecord.STAGE_TYPE_AWAKE,
                        SleepSessionRecord.STAGE_TYPE_OUT_OF_BED,
                        -> awake += minutes
                        SleepSessionRecord.STAGE_TYPE_LIGHT -> {
                            light += minutes
                            asleepIntervals.add(
                                listOf(stage.startTime.toEpochMilli(), stage.endTime.toEpochMilli()),
                            )
                        }
                        SleepSessionRecord.STAGE_TYPE_DEEP -> {
                            deep += minutes
                            asleepIntervals.add(
                                listOf(stage.startTime.toEpochMilli(), stage.endTime.toEpochMilli()),
                            )
                        }
                        SleepSessionRecord.STAGE_TYPE_REM -> {
                            rem += minutes
                            asleepIntervals.add(
                                listOf(stage.startTime.toEpochMilli(), stage.endTime.toEpochMilli()),
                            )
                        }
                        // Unstaged "sleeping" time is still sleep.
                        SleepSessionRecord.STAGE_TYPE_SLEEPING -> {
                            unstaged += minutes
                            asleepIntervals.add(
                                listOf(stage.startTime.toEpochMilli(), stage.endTime.toEpochMilli()),
                            )
                        }
                        else -> Unit
                    }
                }
                if (record.stages.isEmpty()) {
                    // A session with no stages at all is one unstaged block.
                    unstaged = Duration.between(record.startTime, record.endTime).toMinutes()
                    asleepIntervals.add(
                        listOf(record.startTime.toEpochMilli(), record.endTime.toEpochMilli()),
                    )
                }
                sessions.add(
                    mapOf(
                        "start" to record.startTime.toString(),
                        "end" to record.endTime.toString(),
                        "minutes" to light + deep + rem + unstaged,
                        "unstagedMinutes" to unstaged,
                        "asleepIntervals" to asleepIntervals,
                        "awakeMinutes" to awake,
                        "lightMinutes" to light,
                        "deepMinutes" to deep,
                        "remMinutes" to rem,
                    ),
                )
            }
        }

        return mapOf(
            "status" to if (granted.isEmpty()) "permissionRequired" else "ready",
            "granted" to granted.toList().sorted(),
            "checkedAt" to now.toString(),
            "sessions" to sessions,
        )
    }

    private suspend fun readTrends7d(): Map<String, Any?> {
        val availability = HealthConnectClient.getSdkStatus(this, PROVIDER_PACKAGE)
        if (availability != HealthConnectClient.SDK_AVAILABLE) {
            return mapOf(
                "status" to availabilityName(availability),
                "checkedAt" to Instant.now().toString(),
            )
        }
        val client = HealthConnectClient.getOrCreate(this)
        val granted = client.permissionController.getGrantedPermissions()
        val now = Instant.now()
        val zone = ZoneId.systemDefault()
        val today = LocalDate.now(zone)
        val dates = (6 downTo 0).map { today.minusDays(it.toLong()) }
        val weekStart = dates.first().atStartOfDay(zone).toInstant()
        val steps = LongArray(7)
        val hrSum = LongArray(7)
        val hrCount = LongArray(7)
        val sleepMinutes = LongArray(7)

        if (HealthPermission.getReadPermission(StepsRecord::class) in granted) {
            readAirRecords<StepsRecord>(client, weekStart, now).forEach { record ->
                val index = dates.indexOf(record.startTime.atZone(zone).toLocalDate())
                if (index >= 0) steps[index] += record.count
            }
        }

        if (HealthPermission.getReadPermission(HeartRateRecord::class) in granted) {
            readAirRecords<HeartRateRecord>(client, weekStart, now).forEach { record ->
                val index = dates.indexOf(record.startTime.atZone(zone).toLocalDate())
                if (index >= 0) {
                    record.samples.forEach { sample ->
                        hrSum[index] += sample.beatsPerMinute
                        hrCount[index] += 1
                    }
                }
            }
        }

        if (HealthPermission.getReadPermission(SleepSessionRecord::class) in granted) {
            readAirRecords<SleepSessionRecord>(client, weekStart, now).forEach { record ->
                val index = dates.indexOf(record.endTime.atZone(zone).toLocalDate())
                if (index >= 0) {
                    val asleepMinutes = record.stages.sumOf { stage ->
                        when (stage.stage) {
                            SleepSessionRecord.STAGE_TYPE_LIGHT,
                            SleepSessionRecord.STAGE_TYPE_DEEP,
                            SleepSessionRecord.STAGE_TYPE_REM,
                            -> Duration.between(stage.startTime, stage.endTime)
                                .toMinutes().coerceAtLeast(0)
                            else -> 0L
                        }
                    }
                    if (asleepMinutes > sleepMinutes[index]) {
                        sleepMinutes[index] = asleepMinutes
                    }
                }
            }
        }

        return mapOf(
            "status" to if (granted.isEmpty()) "permissionRequired" else "ready",
            "granted" to granted.toList().sorted(),
            "checkedAt" to now.toString(),
            "dates" to dates.map { it.toString() },
            "steps" to steps.toList(),
            "hrAvg" to dates.indices.map { index ->
                if (hrCount[index] == 0L) null else hrSum[index] / hrCount[index]
            },
            "sleepMinutes" to dates.indices.map { index ->
                if (sleepMinutes[index] == 0L) null else sleepMinutes[index]
            },
        )
    }

    private suspend fun readActivityDetail(): Map<String, Any?> {
        val availability = HealthConnectClient.getSdkStatus(this, PROVIDER_PACKAGE)
        if (availability != HealthConnectClient.SDK_AVAILABLE) {
            return mapOf(
                "status" to availabilityName(availability),
                "checkedAt" to Instant.now().toString(),
            )
        }
        val client = HealthConnectClient.getOrCreate(this)
        val granted = client.permissionController.getGrantedPermissions()
        val now = Instant.now()
        val zone = ZoneId.systemDefault()
        val todayStart = LocalDate.now(zone).atStartOfDay(zone).toInstant()
        val workouts = mutableListOf<Map<String, Any?>>()
        val data = mutableMapOf<String, Any?>(
            "status" to if (granted.isEmpty()) "permissionRequired" else "ready",
            "granted" to granted.toList().sorted(),
            "checkedAt" to now.toString(),
            "workouts" to workouts,
            "distanceMetersToday" to null,
            "floorsToday" to null,
            "caloriesTotalToday" to null,
            "caloriesActiveToday" to null,
        )

        if (HealthPermission.getReadPermission(ExerciseSessionRecord::class) in granted) {
            readAirRecords<ExerciseSessionRecord>(client, now.minus(Duration.ofDays(7)), now)
                .sortedByDescending { it.endTime }
                .forEach { record ->
                    workouts.add(
                        mapOf(
                            "type" to exerciseName(record.exerciseType),
                            "start" to record.startTime.toString(),
                            "minutes" to Duration.between(record.startTime, record.endTime)
                                .toMinutes(),
                        ),
                    )
                }
        }

        if (HealthPermission.getReadPermission(DistanceRecord::class) in granted) {
            val records = readAirRecords<DistanceRecord>(client, todayStart, now)
            if (records.isNotEmpty()) {
                data["distanceMetersToday"] = records.sumOf { it.distance.inMeters }.toLong()
            }
        }

        if (HealthPermission.getReadPermission(FloorsClimbedRecord::class) in granted) {
            val records = readAirRecords<FloorsClimbedRecord>(client, todayStart, now)
            if (records.isNotEmpty()) {
                data["floorsToday"] = records.sumOf { it.floors }.toLong()
            }
        }

        if (HealthPermission.getReadPermission(TotalCaloriesBurnedRecord::class) in granted) {
            val records = readAirRecords<TotalCaloriesBurnedRecord>(client, todayStart, now)
            if (records.isNotEmpty()) {
                data["caloriesTotalToday"] =
                    records.sumOf { it.energy.inKilocalories }.toLong()
            }
        }

        if (HealthPermission.getReadPermission(ActiveCaloriesBurnedRecord::class) in granted) {
            val records = readAirRecords<ActiveCaloriesBurnedRecord>(client, todayStart, now)
            if (records.isNotEmpty()) {
                data["caloriesActiveToday"] =
                    records.sumOf { it.energy.inKilocalories }.toLong()
            }
        }

        return data
    }

    private suspend fun readBodyDetail(): Map<String, Any?> {
        val availability = HealthConnectClient.getSdkStatus(this, PROVIDER_PACKAGE)
        if (availability != HealthConnectClient.SDK_AVAILABLE) {
            return mapOf(
                "status" to availabilityName(availability),
                "checkedAt" to Instant.now().toString(),
            )
        }
        val client = HealthConnectClient.getOrCreate(this)
        val granted = client.permissionController.getGrantedPermissions()
        val now = Instant.now()
        val data = mutableMapOf<String, Any?>(
            "status" to if (granted.isEmpty()) "permissionRequired" else "ready",
            "granted" to granted.toList().sorted(),
            "checkedAt" to now.toString(),
            "spo2Percent" to null,
            "spo2Baseline" to null,
            "respiratoryRate" to null,
            "respiratoryBaseline" to null,
            "skinTempBaselineC" to null,
            "skinTempDeviationC" to null,
            "vo2Max" to null,
        )

        if (HealthPermission.getReadPermission(OxygenSaturationRecord::class) in granted) {
            val records = readAirRecords<OxygenSaturationRecord>(
                client,
                now.minus(Duration.ofDays(7)),
                now,
            )
            val latest = records.maxByOrNull { it.time }
            if (latest != null) {
                data["spo2Percent"] = latest.percentage.value
                data["spo2Baseline"] = records.map { it.percentage.value }.average()
            }
        }

        if (HealthPermission.getReadPermission(RespiratoryRateRecord::class) in granted) {
            val records = readAirRecords<RespiratoryRateRecord>(
                client,
                now.minus(Duration.ofDays(28)),
                now,
            )
            val ordered = records.sortedBy { it.time }
            val latest = ordered.lastOrNull()
            if (latest != null) {
                data["respiratoryRate"] = latest.rate
                // Baseline excludes the latest night so a rise is visible.
                val prior = ordered.dropLast(1)
                if (prior.size >= 3) {
                    data["respiratoryBaseline"] = prior.map { it.rate }.sorted()[prior.size / 2]
                }
            }
        }

        if (HealthPermission.getReadPermission(SkinTemperatureRecord::class) in granted) {
            val records = readAirRecords<SkinTemperatureRecord>(
                client,
                now.minus(Duration.ofDays(7)),
                now,
            )
            val latest = records.maxByOrNull { it.startTime }
            if (latest != null) {
                data["skinTempBaselineC"] = latest.baseline?.inCelsius
                data["skinTempDeviationC"] = latest.deltas.lastOrNull()?.delta?.inCelsius
            }
        }

        if (HealthPermission.getReadPermission(Vo2MaxRecord::class) in granted) {
            val records = readAirRecords<Vo2MaxRecord>(client, now.minus(Duration.ofDays(30)), now)
            data["vo2Max"] = records.maxByOrNull { it.time }?.vo2MillilitersPerMinuteKilogram
        }

        return data
    }

    private fun isFitbitAirRecord(metadata: Metadata): Boolean {
        val packageName = metadata.dataOrigin.packageName
        val fromFitbitApp = packageName.equals(FITBIT_APP_PACKAGE, ignoreCase = true)
        if (!fromFitbitApp &&
            AIR_SOURCE_PACKAGES.none { it.equals(packageName, ignoreCase = true) }
        ) {
            return false
        }

        val manufacturer = normalizeIdentity(metadata.device?.manufacturer)
        val model = normalizeIdentity(metadata.device?.model)

        if (manufacturer.isEmpty() && model.isEmpty()) {
            // Steps and heart-rate records synced by the Fitbit app often
            // carry no device metadata; the Fitbit app source is the only
            // identity available for them.
            return fromFitbitApp
        }

        if (manufacturer.isNotEmpty() && manufacturer !in AIR_MANUFACTURERS) {
            return false
        }
        return model in AIR_MODELS || model.isEmpty()
    }

    private fun normalizeIdentity(value: String?): String = value
        ?.trim()
        ?.lowercase(Locale.ROOT)
        ?.replace(Regex("[^a-z0-9]"), "")
        .orEmpty()

    private fun launchHealth(
        result: MethodChannel.Result,
        operation: suspend () -> Any?,
    ) {
        healthScope.launch {
            try {
                val value = operation()
                withContext(Dispatchers.Main) { result.success(value) }
            } catch (error: Exception) {
                withContext(Dispatchers.Main) {
                    result.error(
                        "HEALTH_CONNECT_ERROR",
                        error.message ?: "Health Connect could not complete the request.",
                        null,
                    )
                }
            }
        }
    }

    private fun openProviderStore(result: MethodChannel.Result) {
        val intent = android.content.Intent(
            android.content.Intent.ACTION_VIEW,
            android.net.Uri.parse("market://details?id=$PROVIDER_PACKAGE"),
        ).setPackage("com.android.vending")
        try {
            startActivity(intent)
            result.success(true)
        } catch (error: Exception) {
            result.success(false)
        }
    }

    private fun availabilityName(status: Int): String = when (status) {
        HealthConnectClient.SDK_AVAILABLE -> "available"
        HealthConnectClient.SDK_UNAVAILABLE_PROVIDER_UPDATE_REQUIRED -> "needsUpdate"
        else -> "unavailable"
    }

    private fun exerciseName(type: Int): String = when (type) {
        ExerciseSessionRecord.EXERCISE_TYPE_RUNNING -> "Run"
        ExerciseSessionRecord.EXERCISE_TYPE_RUNNING_TREADMILL -> "Treadmill run"
        ExerciseSessionRecord.EXERCISE_TYPE_WALKING -> "Walk"
        ExerciseSessionRecord.EXERCISE_TYPE_STRENGTH_TRAINING -> "Strength training"
        ExerciseSessionRecord.EXERCISE_TYPE_BIKING -> "Cycling"
        ExerciseSessionRecord.EXERCISE_TYPE_BIKING_STATIONARY -> "Indoor cycling"
        ExerciseSessionRecord.EXERCISE_TYPE_SWIMMING_POOL -> "Pool swim"
        ExerciseSessionRecord.EXERCISE_TYPE_SWIMMING_OPEN_WATER -> "Open-water swim"
        ExerciseSessionRecord.EXERCISE_TYPE_YOGA -> "Yoga"
        else -> "Workout"
    }

    companion object {
        private const val CHANNEL_NAME = "com.becel/health_connect"
        private const val LOCAL_CHANNEL = "com.becel/local"
        private const val LOCAL_LOG_PREFS = "becel_local_log"
        private const val LOCAL_LOG_KEY = "log_v1"
        private const val FITNESS_PROFILE_PREFS = "becel_fitness_profile"
        private const val FITNESS_AGE_KEY = "age"
        private const val AIR_HAPTICS_CHANNEL = "com.becel/air_haptics"
        private const val HEART_BUCKET_MILLIS = 5L * 60L * 1000L
        private const val STEP_BUCKET_MILLIS = 5L * 60L * 1000L
        private const val LOAD_WINDOW_DAYS = 28L
        private const val PROVIDER_PACKAGE = "com.google.android.apps.healthdata"
        private const val FITBIT_APP_PACKAGE = "com.fitbit.FitbitMobile"
        private val AIR_SOURCE_PACKAGES = setOf(
            FITBIT_APP_PACKAGE,
            "com.google.android.apps.healthdata",
        )
        private val AIR_SOURCE_ORIGINS = setOf(
            DataOrigin(FITBIT_APP_PACKAGE),
            DataOrigin("com.google.android.apps.healthdata"),
        )
        private val AIR_MODELS = setOf("air", "fitbitair", "googlefitbitair")
        private val AIR_MANUFACTURERS = setOf(
            "fitbit",
            "google",
            "googlefitbit",
            "googlellc",
            "fitbitinc",
        )
        private val READ_PERMISSIONS = setOf(
            HealthPermission.getReadPermission(StepsRecord::class),
            HealthPermission.getReadPermission(HeartRateRecord::class),
            HealthPermission.getReadPermission(SleepSessionRecord::class),
            HealthPermission.getReadPermission(ExerciseSessionRecord::class),
            HealthPermission.getReadPermission(DistanceRecord::class),
            HealthPermission.getReadPermission(FloorsClimbedRecord::class),
            HealthPermission.getReadPermission(TotalCaloriesBurnedRecord::class),
            HealthPermission.getReadPermission(ActiveCaloriesBurnedRecord::class),
            HealthPermission.getReadPermission(BasalMetabolicRateRecord::class),
            HealthPermission.getReadPermission(RestingHeartRateRecord::class),
            HealthPermission.getReadPermission(HeartRateVariabilityRmssdRecord::class),
            HealthPermission.getReadPermission(OxygenSaturationRecord::class),
            HealthPermission.getReadPermission(RespiratoryRateRecord::class),
            HealthPermission.getReadPermission(SkinTemperatureRecord::class),
            HealthPermission.getReadPermission(Vo2MaxRecord::class),
        )
    }
}
