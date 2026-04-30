package com.dev.flutter_twilio

import com.dev.flutter_twilio.generated.FlutterError
import com.twilio.voice.CallException
import com.twilio.voice.RegistrationException

/**
 * Single source of truth for wire-format errors sent to Dart via Pigeon.
 * Return / throw the produced [FlutterError] from a HostApi method — it lands
 * as a PlatformException on the Dart side with a stable [code].
 */
object FlutterTwilioError {

    /**
     * Twilio access-token error codes. Per Twilio Voice SDK docs these cover
     * invalid, expired, or otherwise unusable JWT credentials — we surface them
     * as [`invalid_token`] instead of the generic [`twilio_sdk_error`].
     */
    val TOKEN_ERROR_CODES: Set<Int> = setOf(20101, 20104, 20157)

    /**
     * Twilio signaling error range (53xxx). Covers transport / connection
     * failures we surface as [`connection_error`].
     */
    fun isSignalingError(code: Int): Boolean = code in 53000..53999

    fun of(
        code: String,
        message: String,
        details: Map<String, Any?> = emptyMap(),
    ): FlutterError = FlutterError(code, message, details)

    fun fromTwilio(sdk: CallException): FlutterError {
        val twilioCode = sdk.errorCode
        val (code, message) = when {
            twilioCode in TOKEN_ERROR_CODES -> "invalid_token" to (sdk.message ?: "Access token invalid")
            isSignalingError(twilioCode) -> "connection_error" to (sdk.message ?: "Signaling error")
            else -> "twilio_sdk_error" to (sdk.message ?: "Twilio SDK error")
        }
        return of(
            code = code,
            message = message,
            details = mapOf(
                "twilioCode" to twilioCode,
                "twilioDomain" to "com.twilio.voice",
                "nativeMessage" to sdk.message,
            ),
        )
    }

    fun fromRegistration(sdk: RegistrationException): FlutterError {
        val twilioCode = sdk.errorCode
        val code = if (twilioCode in TOKEN_ERROR_CODES) "invalid_token" else "registration_error"
        return of(
            code = code,
            message = sdk.message ?: "Registration failure",
            details = mapOf(
                "twilioCode" to twilioCode,
                "twilioDomain" to "com.twilio.voice",
                "nativeMessage" to sdk.message,
            ),
        )
    }

    fun bluetoothUnavailable(message: String): FlutterError =
        of("bluetooth_unavailable", message)

    fun wiredUnavailable(message: String): FlutterError =
        of("wired_unavailable", message)

    fun audioRouteFailed(message: String): FlutterError =
        of("audio_route_failed", message)

    fun toneAssetNotFound(path: String): FlutterError =
        of(
            code = "tone_asset_not_found",
            message = "Tone asset not found: $path",
            details = mapOf("assetPath" to path),
        )

    fun notificationPermissionDenied(): FlutterError =
        of(
            code = "notification_permission_denied",
            message = "POST_NOTIFICATIONS permission is required",
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
