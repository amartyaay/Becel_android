/* Copyright 2017-2020 Fitbit, Inc. Licensed under the Apache License, Version 2.0. */
package com.becel.becel

import com.fitbit.goldengate.bindings.coap.CoapEndpoint
import com.fitbit.goldengate.bindings.coap.data.IncomingResponse
import com.fitbit.goldengate.bindings.coap.data.Method
import com.fitbit.goldengate.bindings.coap.data.OutgoingRequestBuilder
import com.fitbit.goldengate.bindings.coap.data.ok
import io.reactivex.Single
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean

/** One short haptic toggle; reports success only after the saved intensity is verified. */
internal object AirHapticPatternExecutor {
    private const val PULSE_MILLIS = 800L
    private const val RESTORE_RETRIES = 2

    fun execute(endpoint: CoapEndpoint): Single<AirHapticExecutionResult> =
        readIntensity(endpoint).flatMap { initialIntensity ->
            require(initialIntensity in AirDirectSettingsProtocol.HAPTICS_LOW..AirDirectSettingsProtocol.HAPTICS_HIGH) {
                "Unsupported starting haptics intensity ${AirDirectSettingsProtocol.name(initialIntensity)}"
            }
            val alternateIntensity = if (initialIntensity == AirDirectSettingsProtocol.HAPTICS_HIGH) {
                AirDirectSettingsProtocol.HAPTICS_LOW
            } else {
                AirDirectSettingsProtocol.HAPTICS_HIGH
            }
            val changeAttempted = AtomicBoolean(false)

            writeIntensity(endpoint, alternateIntensity)
                .doOnSubscribe { changeAttempted.set(true) }
                .flatMap { response ->
                    require(response.responseCode.ok()) { "Haptic pulse request returned ${response.responseCode}" }
                    Single.timer(PULSE_MILLIS, TimeUnit.MILLISECONDS)
                        .flatMap { restoreAndVerify(endpoint, initialIntensity) }
                }
                .onErrorResumeNext { operationError ->
                    if (!changeAttempted.get()) {
                        Single.error<Int>(operationError)
                    } else {
                        restoreAndVerify(endpoint, initialIntensity)
                            .onErrorResumeNext { restoreError ->
                                    Single.error<Int>(
                                    IllegalStateException(
                                        "The haptic test failed and Fitbit Air restoration could not be verified. Keep the band nearby and reconnect before trying again. ${restoreError.message.orEmpty()}",
                                        operationError,
                                    ),
                                )
                            }
                            .flatMap { Single.error<Int>(operationError) }
                    }
                }
                .map { finalIntensity ->
                    AirHapticExecutionResult(initialIntensity, finalIntensity)
                }
        }

    private fun restoreAndVerify(endpoint: CoapEndpoint, initialIntensity: Int): Single<Int> =
        restoreIntensity(endpoint, initialIntensity).flatMap {
            readIntensity(endpoint).flatMap { finalIntensity ->
                if (finalIntensity == initialIntensity) {
                    Single.just(finalIntensity)
                } else {
                    Single.error(
                        IllegalStateException(
                            "Haptics restore verification failed: initial=$initialIntensity final=$finalIntensity",
                        ),
                    )
                }
            }
        }

    private fun restoreIntensity(endpoint: CoapEndpoint, intensity: Int): Single<IncomingResponse> =
        writeIntensity(endpoint, intensity)
            .flatMap { response ->
                if (response.responseCode.ok()) Single.just(response)
                else Single.error(IllegalStateException("Restore write returned ${response.responseCode}"))
            }
            .retry(RESTORE_RETRIES.toLong())

    private fun readIntensity(endpoint: CoapEndpoint): Single<Int> {
        val request = OutgoingRequestBuilder("/settings", Method.PUT)
            .expectSuccess(false)
            .maxResendCount(0)
            .body(AirDirectSettingsProtocol.encodeRequest())
            .build()
        return endpoint.responseFor(request).flatMap { response ->
            require(response.responseCode.ok()) { "Haptics settings read returned ${response.responseCode}" }
            response.body.asData().map { body ->
                AirDirectSettingsProtocol.parseIntensity(body)
                    ?: throw IllegalStateException("Fitbit Air did not return a haptics intensity")
            }
        }
    }

    private fun writeIntensity(endpoint: CoapEndpoint, intensity: Int): Single<IncomingResponse> {
        val request = OutgoingRequestBuilder("/settings", Method.POST)
            .expectSuccess(false)
            .maxResendCount(0)
            .body(AirDirectSettingsProtocol.encodeResponse(intensity))
            .build()
        return endpoint.responseFor(request)
    }
}

internal data class AirHapticExecutionResult(
    val initialIntensity: Int,
    val finalIntensity: Int,
)
