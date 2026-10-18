package com.becel.becel

import android.Manifest
import android.annotation.SuppressLint
import android.bluetooth.BluetoothManager
import android.bluetooth.le.ScanCallback
import android.bluetooth.le.ScanFilter
import android.bluetooth.le.ScanResult
import android.bluetooth.le.ScanSettings
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.ParcelUuid
import androidx.core.content.ContextCompat
import com.fitbit.bluetooth.fbgatt.FitbitGatt
import com.fitbit.bluetooth.fbgatt.rx.DEFAULT_UUID_MASK
import com.fitbit.bluetooth.fbgatt.rx.GOLDEN_GATE_SERVICE_UUID_MASK
import com.fitbit.bluetooth.fbgatt.rx.PeripheralConnectionChangeListener
import com.fitbit.goldengate.GoldenGateConnectionManagerModule
import com.fitbit.goldengate.bindings.coap.CoapEndpoint
import com.fitbit.goldengate.bindings.coap.CoapEndpointBuilder
import com.fitbit.goldengate.bindings.node.BluetoothAddressNodeKey
import com.fitbit.goldengate.bindings.stack.DtlsSocketNetifGattlink
import com.fitbit.goldengate.bt.DEFAULT_CLIENT_ADDRESS
import com.fitbit.goldengate.bt.DEFAULT_SERVER_ADDRESS
import com.fitbit.goldengate.bt.PeerRole
import com.fitbit.goldengate.bt.gatt.server.services.gattlink.FitbitGattlinkService
import com.fitbit.goldengate.bt.gatt.server.services.gattlink.GattlinkService
import com.fitbit.goldengate.node.stack.StackPeer
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.reactivex.Single
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.net.Inet4Address
import java.util.concurrent.TimeUnit
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException
import kotlinx.coroutines.suspendCancellableCoroutine

/** Debug-build-only direct BLE experiment, adapted from the Apache-2.0 bridge. */
class AirHapticsFeatureImpl : AirHapticsFeature {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private val mainHandler = Handler(Looper.getMainLooper())
    private var pendingPermissionMethod: String? = null
    private var pendingPermissionResult: MethodChannel.Result? = null
    private var runtimeReady = false

    override fun handleMethodCall(
        activity: MainActivity,
        call: MethodCall,
        result: MethodChannel.Result,
        requestBluetoothPermissions: (Array<String>) -> Unit,
    ): Boolean {
        currentActivity = activity
        return when (call.method) {
            "air.selected" -> {
                result.success(loadSelected(activity))
                true
            }
            "air.select" -> {
                val address = call.argument<String>("address")?.trim()
                val name = call.argument<String>("name")?.trim().orEmpty()
                if (address.isNullOrBlank()) {
                    result.error("INVALID_DEVICE", "Select a device from the Bluetooth scan first.", null)
                } else {
                    saveSelected(activity, address, name)
                    result.success(loadSelected(activity))
                }
                true
            }
            "air.scan", "air.test" -> {
                if ("arm64-v8a" !in Build.SUPPORTED_ABIS) {
                    result.error(
                        "UNSUPPORTED_ARCHITECTURE",
                        "The experimental Fitbit Air bridge currently supports arm64 Android devices only.",
                        null,
                    )
                } else if (hasBluetoothPermissions(activity)) {
                    perform(activity, call.method, result)
                } else if (pendingPermissionResult != null) {
                    result.error("BUSY", "A Fitbit Air Bluetooth action is already waiting for permission.", null)
                } else {
                    pendingPermissionMethod = call.method
                    pendingPermissionResult = result
                    requestBluetoothPermissions(requiredBluetoothPermissions())
                }
                true
            }
            else -> false
        }
    }

    override fun onBluetoothPermissionsResult(grants: Map<String, Boolean>) {
        val method = pendingPermissionMethod ?: return
        val result = pendingPermissionResult ?: return
        pendingPermissionMethod = null
        pendingPermissionResult = null
        if (grants.values.any { !it }) {
            result.error(
                "BLUETOOTH_PERMISSION_DENIED",
                "Bluetooth permission is required to find and connect to Fitbit Air.",
                null,
            )
            return
        }
        val activity = currentActivity ?: run {
            result.error("ACTIVITY_UNAVAILABLE", "Return to Becel and try again.", null)
            return
        }
        perform(activity, method, result)
    }

    private var currentActivity: MainActivity? = null

    private fun perform(activity: MainActivity, method: String, result: MethodChannel.Result) {
        currentActivity = activity
        scope.launch {
            try {
                val value = when (method) {
                    "air.scan" -> scanDevices(activity)
                    "air.test" -> testPulse(activity)
                    else -> error("Unsupported Fitbit Air action")
                }
                withContext(Dispatchers.Main) { result.success(value) }
            } catch (error: Exception) {
                withContext(Dispatchers.Main) {
                    result.error(
                        "AIR_HAPTIC_FAILED",
                        error.message ?: "Fitbit Air could not complete the haptic test.",
                        null,
                    )
                }
            }
        }
    }

    private suspend fun scanDevices(context: Context): List<Map<String, Any>> {
        ensureRuntime(context)
        repeat(SCAN_ATTEMPTS) { attempt ->
            val devices = scan(context, SCAN_WINDOW_MILLIS)
            if (devices.isNotEmpty()) return devices
            if (attempt < SCAN_ATTEMPTS - 1) delay(SCAN_RETRY_DELAY_MILLIS)
        }
        return emptyList()
    }

    private suspend fun testPulse(context: Context): Map<String, Any> {
        ensureRuntime(context)
        val selected = loadSelected(context)
            ?: throw IllegalStateException("Select a Fitbit Air from the scan before testing.")
        val address = awaitSelectedAir(context, selected)
        if (address == null) {
            throw IllegalStateException(
                "Fitbit Air has not advertised a connectable Bluetooth address yet. Becel cannot force Google Health to release its connection. Keep the band nearby and try again after Google Health finishes syncing; you do not need to unpair it.",
            )
        }

        var peer: StackPeer<CoapEndpoint>? = null
        var lastConnectError: Exception? = null
        for (attempt in 0 until CONNECTION_ATTEMPTS) {
            val attemptPeer = createPeer(address)
            try {
                attemptPeer.connection()
                    .firstOrError()
                    .timeout(CONNECT_TIMEOUT_SECONDS, TimeUnit.SECONDS)
                    .blockingGet()
                peer = attemptPeer
                lastConnectError = null
                break
            } catch (error: Exception) {
                lastConnectError = error
                runCatching { attemptPeer.close() }
                if (attempt < CONNECTION_ATTEMPTS - 1) delay(CONNECT_RETRY_DELAY_MILLIS)
            }
        }

        val connectedPeer = peer ?: throw IllegalStateException(
            "Fitbit Air advertised, but Becel could not connect. Google Health may have reconnected first; try the pulse again shortly. ${lastConnectError?.message.orEmpty()}",
        )
        try {
            val execution = AirHapticPatternExecutor.execute(connectedPeer.stackService).blockingGet()
            return mapOf(
                "deviceName" to (selected["name"] as? String ?: "Fitbit Air"),
                "initialIntensity" to execution.initialIntensity,
                "finalIntensity" to execution.finalIntensity,
                "restored" to (execution.initialIntensity == execution.finalIntensity),
            )
        } finally {
            runCatching { connectedPeer.close() }
            delay(PEER_RELEASE_SETTLE_MILLIS)
        }
    }

    /**
     * Google Health and this experimental bridge cannot use the Air's single BLE link together.
     * Wait for an advertisement, then refresh a rotated address only when a single Air-named
     * Golden Gate device is visible.
     */
    private suspend fun awaitSelectedAir(
        context: Context,
        selected: Map<String, Any>,
    ): String? {
        val savedAddress = selected["address"] as String
        val selectedName = (selected["name"] as? String).orEmpty()
        repeat(CONNECT_SCAN_ATTEMPTS) { attempt ->
            val devices = scan(context, CONNECT_SCAN_WINDOW_MILLIS)
            val exact = devices.firstOrNull {
                (it["address"] as? String).equals(savedAddress, ignoreCase = true)
            }
            if (exact != null) return exact["address"] as String

            if (selectedName.contains("air", ignoreCase = true)) {
                val airMatches = devices.filter {
                    (it["name"] as? String).orEmpty().contains("air", ignoreCase = true)
                }
                if (airMatches.size == 1) {
                    val current = airMatches.single()
                    val currentAddress = current["address"] as String
                    saveSelected(context, currentAddress, current["name"] as? String ?: selectedName)
                    return currentAddress
                }
            }
            if (attempt < CONNECT_SCAN_ATTEMPTS - 1) delay(SCAN_RETRY_DELAY_MILLIS)
        }
        return null
    }

    private fun ensureRuntime(context: Context) {
        if (runtimeReady) return
        synchronized(this) {
            if (runtimeReady) return
            GoldenGateConnectionManagerModule.init(
                context.applicationContext,
                loggingEnabled = false,
                isBleCentralRole = true,
            )
            runtimeReady = true
        }
    }

    private fun createPeer(address: String): StackPeer<CoapEndpoint> {
        val stackConfig = DtlsSocketNetifGattlink(
            Inet4Address.getByName(DEFAULT_SERVER_ADDRESS) as Inet4Address,
            0,
            Inet4Address.getByName(DEFAULT_CLIENT_ADDRESS) as Inet4Address,
            0,
        )
        return StackPeer(
            BluetoothAddressNodeKey(address),
            PeerRole.Peripheral,
            stackConfig,
            CoapEndpointBuilder(),
            { connection -> PeripheralConnectionChangeListener().register(connection) },
            { stack -> stack.dtlsEventObservable },
        )
    }

    @SuppressLint("MissingPermission")
    private suspend fun scan(
        context: Context,
        durationMillis: Long,
    ): List<Map<String, Any>> = suspendCancellableCoroutine { continuation ->
        val manager = context.getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager
        val scanner = manager.adapter?.bluetoothLeScanner
        if (scanner == null || manager.adapter?.isEnabled != true) {
            continuation.resumeWithException(IllegalStateException("Turn on Bluetooth and try again."))
            return@suspendCancellableCoroutine
        }

        val found = linkedMapOf<String, Map<String, Any>>()
        lateinit var callback: ScanCallback
        val timeout = Runnable {
            stopScan(scanner, callback)
            if (continuation.isActive) continuation.resume(found.values.toList())
        }
        callback = object : ScanCallback() {
            override fun onScanResult(callbackType: Int, result: ScanResult) {
                if (!continuation.isActive) return
                try {
                    FitbitGatt.getInstance().addBackgroundScannedDeviceConnection(result)
                    found[result.device.address] = mapOf(
                        "address" to result.device.address,
                        "name" to (result.scanRecord?.deviceName
                            ?: result.device.name
                            ?: "Fitbit device"),
                        "rssi" to result.rssi,
                    )
                } catch (_: Exception) {
                    // Ignore malformed advertisements and keep collecting the scan.
                }
            }

            override fun onScanFailed(errorCode: Int) {
                mainHandler.removeCallbacks(timeout)
                if (continuation.isActive) {
                    continuation.resumeWithException(
                        IllegalStateException("Bluetooth scan failed (error $errorCode)."),
                    )
                }
            }
        }

        continuation.invokeOnCancellation {
            mainHandler.removeCallbacks(timeout)
            stopScan(scanner, callback)
        }

        try {
            val filters = listOf(
                ScanFilter.Builder()
                    .setServiceUuid(
                        ParcelUuid(GattlinkService.uuid),
                        ParcelUuid.fromString(GOLDEN_GATE_SERVICE_UUID_MASK),
                    )
                    .build(),
                ScanFilter.Builder()
                    .setServiceUuid(
                        ParcelUuid(FitbitGattlinkService.uuid),
                        ParcelUuid.fromString(DEFAULT_UUID_MASK),
                    )
                    .build(),
            )
            scanner.startScan(
                filters,
                ScanSettings.Builder().setScanMode(ScanSettings.SCAN_MODE_LOW_LATENCY).build(),
                callback,
            )
            mainHandler.postDelayed(timeout, durationMillis)
        } catch (error: Exception) {
            mainHandler.removeCallbacks(timeout)
            stopScan(scanner, callback)
            if (continuation.isActive) continuation.resumeWithException(error)
        }
    }

    @SuppressLint("MissingPermission")
    private fun stopScan(scanner: android.bluetooth.le.BluetoothLeScanner, callback: ScanCallback) {
        runCatching { scanner.stopScan(callback) }
    }

    private fun loadSelected(context: Context): Map<String, Any>? {
        val preferences = context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)
        val address = preferences.getString(KEY_ADDRESS, null)?.takeIf(String::isNotBlank) ?: return null
        return mapOf(
            "address" to address,
            "name" to (preferences.getString(KEY_NAME, null) ?: "Fitbit Air"),
        )
    }

    private fun saveSelected(context: Context, address: String, name: String) {
        context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)
            .edit()
            .putString(KEY_ADDRESS, address)
            .putString(KEY_NAME, name.ifBlank { "Fitbit Air" })
            .apply()
    }

    private fun hasBluetoothPermissions(context: Context): Boolean =
        requiredBluetoothPermissions().all {
            ContextCompat.checkSelfPermission(context, it) == PackageManager.PERMISSION_GRANTED
        }

    private fun requiredBluetoothPermissions(): Array<String> = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
        arrayOf(Manifest.permission.BLUETOOTH_SCAN, Manifest.permission.BLUETOOTH_CONNECT)
    } else {
        arrayOf(Manifest.permission.ACCESS_FINE_LOCATION)
    }

    override fun onDestroy() {
        pendingPermissionResult?.error("ACTIVITY_CLOSED", "Becel was closed before Bluetooth permission was granted.", null)
        pendingPermissionResult = null
        pendingPermissionMethod = null
        currentActivity = null
        scope.cancel()
    }

    private companion object {
        const val PREFERENCES = "becel_fitbit_air_haptics"
        const val KEY_ADDRESS = "device_address"
        const val KEY_NAME = "device_name"
        const val SCAN_WINDOW_MILLIS = 8_000L
        const val CONNECT_SCAN_WINDOW_MILLIS = 7_000L
        const val CONNECT_TIMEOUT_SECONDS = 18L
        const val SCAN_ATTEMPTS = 4
        const val CONNECT_SCAN_ATTEMPTS = 5
        const val CONNECTION_ATTEMPTS = 2
        const val SCAN_RETRY_DELAY_MILLIS = 1_500L
        const val CONNECT_RETRY_DELAY_MILLIS = 1_000L
        const val PEER_RELEASE_SETTLE_MILLIS = 1_000L
    }
}
