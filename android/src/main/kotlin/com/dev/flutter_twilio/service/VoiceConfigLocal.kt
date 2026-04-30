package com.dev.flutter_twilio.service

/**
 * Internal mirror of [com.dev.flutter_twilio.generated.VoiceConfig] — kept
 * decoupled from the Pigeon-generated type so the call layer doesn't depend
 * on the Flutter binary messenger module.
 */
data class VoiceConfigLocal(
    val ringbackAssetPath: String?,
    val connectToneAssetPath: String?,
    val disconnectToneAssetPath: String?,
    val playRingback: Boolean,
    val playConnectTone: Boolean,
    val playDisconnectTone: Boolean,
    val bringAppToForegroundOnAnswer: Boolean,
    val bringAppToForegroundOnEnd: Boolean,
) {
    companion object {
        val default: VoiceConfigLocal = VoiceConfigLocal(
            ringbackAssetPath = null,
            connectToneAssetPath = null,
            disconnectToneAssetPath = null,
            playRingback = true,
            playConnectTone = true,
            playDisconnectTone = true,
            bringAppToForegroundOnAnswer = false,
            bringAppToForegroundOnEnd = false,
        )
    }
}
