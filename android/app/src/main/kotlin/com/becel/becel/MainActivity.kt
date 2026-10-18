package com.becel.becel

import androidx.activity.result.ActivityResultLauncher
import androidx.activity.result.contract.ActivityResultContracts
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.PermissionController
import androidx.health.connect.client.permission.HealthPermission
import androidx.health.connect.client.records.ExerciseSessionRecord
import androidx.health.connect.client.records.HeartRateRecord
import androidx.health.connect.client.records.SleepSessionRecord
import androidx.health.connect.client.records.StepsRecord
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
                "openProviderStore" -> openProviderStore(result)
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
            val latest = records.maxByOrNull { it.endTime }
            if (latest != null) {
                data["sleepSessionMinutes"] =
                    Duration.between(latest.startTime, latest.endTime).toMinutes()
                data["sleepStart"] = latest.startTime.toString()
                data["sleepEnd"] = latest.endTime.toString()
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

    private fun isFitbitAirRecord(metadata: Metadata): Boolean {
        val packageName = metadata.dataOrigin.packageName
        if (AIR_SOURCE_PACKAGES.none { it.equals(packageName, ignoreCase = true) }) {
            return false
        }

        val device = metadata.device ?: return false
        val manufacturer = normalizeIdentity(device.manufacturer)
        val model = normalizeIdentity(device.model)
        return when (manufacturer) {
            "fitbit" -> model in AIR_MODELS
            "google" -> model in GOOGLE_AIR_MODELS
            "googlefitbit" -> model in AIR_MODELS + GOOGLE_AIR_MODELS
            else -> false
        }
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
        private const val AIR_HAPTICS_CHANNEL = "com.becel/air_haptics"
        private const val PROVIDER_PACKAGE = "com.google.android.apps.healthdata"
        private val AIR_SOURCE_PACKAGES = setOf(
            "com.fitbit.FitbitMobile",
            "com.google.android.apps.healthdata",
        )
        private val AIR_SOURCE_ORIGINS = setOf(
            DataOrigin("com.fitbit.FitbitMobile"),
            DataOrigin("com.google.android.apps.healthdata"),
        )
        private val AIR_MODELS = setOf("air", "fitbitair", "googlefitbitair")
        private val GOOGLE_AIR_MODELS = setOf("air", "fitbitair", "googlefitbitair")
        private val READ_PERMISSIONS = setOf(
            HealthPermission.getReadPermission(StepsRecord::class),
            HealthPermission.getReadPermission(HeartRateRecord::class),
            HealthPermission.getReadPermission(SleepSessionRecord::class),
            HealthPermission.getReadPermission(ExerciseSessionRecord::class),
        )
    }
}
