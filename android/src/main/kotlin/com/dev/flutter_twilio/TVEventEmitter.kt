package com.dev.flutter_twilio

import android.os.Handler
import android.os.Looper
import android.util.Log
import com.dev.flutter_twilio.generated.ActiveCallDto
import com.dev.flutter_twilio.generated.AudioRoute
import com.dev.flutter_twilio.generated.CallErrorDto
import com.dev.flutter_twilio.generated.CallEventDto
import com.dev.flutter_twilio.generated.CallEventType
import com.dev.flutter_twilio.generated.VoiceFlutterApi

/**
 * Bridges native call-lifecycle events into Flutter via Pigeon's [VoiceFlutterApi].
 *
 * Replaces the legacy string-based EventChannel. Consumers call [logEvent] /
 * [logEvents] with the same descriptions as before; this class parses them into
 * a typed [CallEventDto].
 */
class TVEventEmitter {

    companion object {
        private const val TAG = "TVEventEmitter"
    }

    private var api: VoiceFlutterApi? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    fun attach(api: VoiceFlutterApi) {
        this.api = api
    }

    fun detach() {
        this.api = null
    }

    /**
     * Pigeon's [VoiceFlutterApi.onCallEvent] must be called on the main/UI
     * thread. Twilio SDK callbacks, FCM listeners, and the Firebase messaging
     * token fetch all deliver on background threads, so every outbound event
     * is marshalled here.
     */
    private fun postToMain(block: () -> Unit) {
        if (Looper.myLooper() == Looper.getMainLooper()) block()
        else mainHandler.post(block)
    }

    // region Typed emitters

    fun emit(
        type: CallEventType,
        activeCall: ActiveCallDto? = null,
        error: CallErrorDto? = null,
        audioRoute: AudioRoute? = null,
    ) {
        val dto = CallEventDto(
            type = type,
            activeCall = activeCall,
            error = error,
            audioRoute = audioRoute,
        )
        postToMain {
            val a = api ?: return@postToMain
            try {
                a.onCallEvent(dto) { /* delivery result ignored */ }
            } catch (t: Throwable) {
                Log.w(TAG, "Failed to emit call event ${type.name}: ${t.message}")
            }
        }
    }

    fun emitError(
        code: String,
        message: String,
        details: Map<String?, Any?> = emptyMap(),
    ) {
        emit(
            type = CallEventType.ERROR,
            error = CallErrorDto(code = code, message = message, details = details),
        )
    }

    // endregion

    // region Legacy string API — retained so existing callers don't need a rewrite.
    // Descriptions are parsed and translated to typed events.

    fun logEvent(description: String) = logEvent("LOG", "|", description, false)

    fun logEvent(prefix: String, description: String) = logEvent(prefix, "|", description, false)

    fun logEvent(
        prefix: String = "LOG",
        separator: String = "|",
        description: String,
        isError: Boolean = false
    ) {
        if (isError) {
            // Unrecoverable error coming from the legacy logging path.
            emitError(code = "unknown", message = description)
            return
        }
        dispatchLegacy(prefix, description)
    }

    fun logEvents(descriptions: Array<String>) =
        logEvents("LOG", "|", "|", descriptions, false)

    fun logEvents(prefix: String, descriptions: Array<String>) =
        logEvents(prefix, "|", "|", descriptions, false)

    fun logEvents(
        prefix: String = "LOG",
        separator: String = "|",
        descriptionSeparator: String = "|",
        descriptions: Array<String>,
        isError: Boolean = false
    ) {
        val description = descriptions.joinToString(descriptionSeparator)
        logEvent(prefix, separator, description, isError)
    }

    fun logEventPermission(permissionName: String, state: Boolean) {
        // Permission diagnostics are not modeled in the typed event stream.
        Log.d(TAG, "permission $permissionName granted=$state")
    }

    // endregion

    private fun dispatchLegacy(prefix: String, description: String) {
        // Errors come through as either prefix == "LOG" with a "Call Error: ..." body,
        // or as the description being the bare label.
        val firstToken = description.substringBefore('|').trim()
        val lowerFirst = firstToken.lowercase()

        // Explicit "Call Error: code, message" string from legacy code.
        if (description.startsWith("Call Error:", ignoreCase = true)) {
            val msg = description.removePrefix("Call Error:").trim()
            emitError(code = "twilio_sdk_error", message = msg)
            return
        }

        val type = when (lowerFirst) {
            "incoming" -> CallEventType.INCOMING
            "ringing" -> CallEventType.RINGING
            "connecting" -> CallEventType.CONNECTING
            "connected" -> CallEventType.CONNECTED
            "reconnecting" -> CallEventType.RECONNECTING
            "reconnected" -> CallEventType.RECONNECTED
            "disconnected" -> CallEventType.DISCONNECTED
            "call ended", "callended" -> CallEventType.CALL_ENDED
            "answer" -> CallEventType.ANSWER
            "reject" -> CallEventType.REJECT
            "declined" -> CallEventType.DECLINED
            "missed", "missedcall", "missed call" -> CallEventType.MISSED_CALL
            "returningcall", "returning call" -> CallEventType.RETURNING_CALL
            "hold" -> CallEventType.HOLD
            "unhold" -> CallEventType.UNHOLD
            "mute" -> CallEventType.MUTE
            "unmute" -> CallEventType.UNMUTE
            "speakeron", "speaker on" -> CallEventType.SPEAKER_ON
            "speakeroff", "speaker off" -> CallEventType.SPEAKER_OFF
            "registered" -> CallEventType.REGISTERED
            "unregistered" -> CallEventType.UNREGISTERED
            "registrationfailed", "registration failed" -> CallEventType.REGISTRATION_FAILED
            else -> null
        }

        if (type == null) {
            Log.d(TAG, "dropping unmapped legacy event: '$description'")
            return
        }

        val snapshot = ActiveCallSnapshotter.snapshot()
        emit(type, activeCall = snapshot)
    }
}

/**
 * Provides the current active-call snapshot as an [ActiveCallDto] for event emission.
 * Populated by [FlutterTwilioPlugin] when attached; returns `null` otherwise.
 */
internal object ActiveCallSnapshotter {
    @Volatile
    var provider: (() -> ActiveCallDto?)? = null

    fun snapshot(): ActiveCallDto? = try {
        provider?.invoke()
    } catch (t: Throwable) {
        null
    }
}

