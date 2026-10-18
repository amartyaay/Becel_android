package com.becel.becel

import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/** Build-variant hook that keeps the unofficial Air bridge out of release builds. */
interface AirHapticsFeature {
    fun handleMethodCall(
        activity: MainActivity,
        call: MethodCall,
        result: MethodChannel.Result,
        requestBluetoothPermissions: (Array<String>) -> Unit,
    ): Boolean

    fun onBluetoothPermissionsResult(grants: Map<String, Boolean>)

    fun onDestroy()
}
