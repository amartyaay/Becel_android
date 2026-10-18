pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            file("local.properties").inputStream().use { properties.load(it) }
            val flutterSdkPath = properties.getProperty("flutter.sdk")
            require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
            flutterSdkPath
        }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.11.1" apply false
    id("org.jetbrains.kotlin.android") version "2.2.20" apply false
}

include(":app")

include(":RxFitbitGatt")
project(":RxFitbitGatt").projectDir = file("fitbit_air_bridge/platform/android/goldengate/RxFitbitGatt")
include(":GoldenGateBindings")
project(":GoldenGateBindings").projectDir = file("fitbit_air_bridge/platform/android/goldengate/GoldenGateBindings")
include(":linkcontroller")
project(":linkcontroller").projectDir = file("fitbit_air_bridge/platform/android/goldengate/linkcontroller")
include(":GoldenGateConnectionManager")
project(":GoldenGateConnectionManager").projectDir = file("fitbit_air_bridge/platform/android/goldengate/GoldenGateConnectionManager")
