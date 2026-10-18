package com.becel.becel

import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/** Release implementation intentionally contains no direct Fitbit Air control. */
class AirHapticsFeatureImpl : AirHapticsFeature {
    override fun handleMethodCall(
        activity: MainActivity,
        call: MethodCall,
        result: MethodChannel.Result,
        requestBluetoothPermissions: (Array<String>) -> Unit,
    ): Boolean = false

    override fun onBluetoothPermissionsResult(grants: Map<String, Boolean>) = Unit

    override fun onDestroy() = Unit
}
