package com.dev.flutter_twilio

import com.dev.flutter_twilio.generated.FlutterError
import com.twilio.voice.CallException

/**
 * Single source of truth for wire-format errors sent to Dart via Pigeon.
 * Return / throw the produced [FlutterError] from a HostApi method — it lands
 * as a PlatformException on the Dart side with a stable [code].
 */
object FlutterTwilioError {

    fun of(
        code: String,
        message: String,
        details: Map<String, Any?> = emptyMap(),
    ): FlutterError = FlutterError(code, message, details)

    fun fromTwilio(sdk: CallException): FlutterError = of(
        code = "twilio_sdk_error",
        message = sdk.message ?: "Twilio SDK error",
        details = mapOf(
            "twilioCode" to sdk.errorCode,
            "twilioDomain" to "com.twilio.voice",
            "nativeMessage" to sdk.message,
        ),
    )

    fun unknown(cause: Throwable): FlutterError = of(
        code = "unknown",
        message = cause.message ?: cause::class.java.simpleName,
        details = mapOf(
            "nativeMessage" to cause.message,
            "cause" to cause::class.java.name,
        ),
    )
}
