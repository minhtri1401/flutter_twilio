package com.dev.flutter_twilio.tone

/** Subset of TVTonePlayer used by TVRingbackController, for testing. */
interface TVTonePlayerLike {
    fun play(
        flutterAssetKey: String?,
        bundledAssetPath: String,
        looping: Boolean,
        forSignalling: Boolean,
    )
    fun stop()
}

enum class CallPhase {
    OUTGOING_CONNECTING,
    INCOMING_RINGING,
    CONNECTED,
    DISCONNECTED,
    ERROR,
}

class TVRingbackController(
    private val player: TVTonePlayerLike,
    private val enabled: Boolean,
    private val customAssetKey: String?,
) {
    private var ringing = false

    fun onCallEvent(phase: CallPhase) {
        when (phase) {
            CallPhase.OUTGOING_CONNECTING -> {
                if (!enabled || ringing) return
                ringing = true
                player.play(
                    flutterAssetKey = customAssetKey,
                    bundledAssetPath = "flutter_twilio/ringback_na.ogg",
                    looping = true,
                    forSignalling = false,
                )
            }
            CallPhase.INCOMING_RINGING -> { /* never play caller-side ringback for incoming */ }
            CallPhase.CONNECTED,
            CallPhase.DISCONNECTED,
            CallPhase.ERROR -> {
                if (ringing) {
                    ringing = false
                    player.stop()
                }
            }
        }
    }
}
