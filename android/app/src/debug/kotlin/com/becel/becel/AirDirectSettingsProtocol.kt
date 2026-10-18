/* Copyright 2017-2020 Fitbit, Inc. Licensed under the Apache License, Version 2.0. */
package com.becel.becel

/** Minimal protobuf codec for the unofficial DirectSettings /settings exchange. */
internal object AirDirectSettingsProtocol {
    const val HAPTICS_OFF = 1
    const val HAPTICS_LOW = 2
    const val HAPTICS_HIGH = 3

    fun encodeRequest(): ByteArray = byteArrayOf(0x0A, 0x01, 0x01)

    fun encodeResponse(intensity: Int): ByteArray {
        require(intensity in HAPTICS_OFF..HAPTICS_HIGH) { "Unsupported haptics intensity $intensity" }
        return byteArrayOf(0x0A, 0x04, 0x0A, 0x02, 0x08, intensity.toByte())
    }

    fun parseIntensity(response: ByteArray): Int? {
        val reader = ProtoReader(response)
        while (!reader.exhausted()) {
            val tag = reader.readVarint().toInt()
            if (tag ushr 3 == 1 && tag and 7 == 2) {
                parseSetting(reader.readBytes())?.let { return it }
            } else {
                reader.skip(tag and 7)
            }
        }
        return null
    }

    fun name(intensity: Int): String = when (intensity) {
        HAPTICS_OFF -> "OFF"
        HAPTICS_LOW -> "LOW"
        HAPTICS_HIGH -> "HIGH"
        else -> "UNKNOWN($intensity)"
    }

    private fun parseSetting(bytes: ByteArray): Int? {
        val reader = ProtoReader(bytes)
        while (!reader.exhausted()) {
            val tag = reader.readVarint().toInt()
            if (tag ushr 3 == 1 && tag and 7 == 2) {
                return parseHaptics(reader.readBytes())
            }
            reader.skip(tag and 7)
        }
        return null
    }

    private fun parseHaptics(bytes: ByteArray): Int? {
        val reader = ProtoReader(bytes)
        while (!reader.exhausted()) {
            val tag = reader.readVarint().toInt()
            if (tag ushr 3 == 1 && tag and 7 == 0) return reader.readVarint().toInt()
            reader.skip(tag and 7)
        }
        return null
    }

    private class ProtoReader(private val bytes: ByteArray) {
        private var position = 0

        fun exhausted(): Boolean = position >= bytes.size

        fun readVarint(): Long {
            var result = 0L
            var shift = 0
            while (shift < 64) {
                require(position < bytes.size) { "Truncated Fitbit Air settings response" }
                val value = bytes[position++].toInt() and 0xff
                result = result or ((value and 0x7f).toLong() shl shift)
                if (value and 0x80 == 0) return result
                shift += 7
            }
            throw IllegalArgumentException("Malformed Fitbit Air settings response")
        }

        fun readBytes(): ByteArray {
            val length = readVarint().toInt()
            require(length >= 0 && position + length <= bytes.size) {
                "Truncated Fitbit Air settings field"
            }
            return bytes.copyOfRange(position, position + length).also { position += length }
        }

        fun skip(wireType: Int) {
            when (wireType) {
                0 -> readVarint()
                1 -> advance(8)
                2 -> advance(readVarint().toInt())
                5 -> advance(4)
                else -> throw IllegalArgumentException("Unsupported protobuf wire type $wireType")
            }
        }

        private fun advance(count: Int) {
            require(count >= 0 && position + count <= bytes.size) { "Truncated Fitbit Air field" }
            position += count
        }
    }
}
