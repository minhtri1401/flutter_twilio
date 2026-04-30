package com.dev.flutter_twilio.service

import android.content.Context
import android.content.Intent
import android.os.Handler
import android.os.Looper
import android.util.Log
import com.twilio.voice.Call
import com.twilio.voice.CallException
import com.twilio.voice.CallInvite
import com.twilio.voice.CancelledCallInvite
import com.dev.flutter_twilio.notification.TVIncomingCallNotifier
import com.dev.flutter_twilio.tone.CallPhase
import com.dev.flutter_twilio.tone.TVRingbackController
import com.dev.flutter_twilio.tone.TVTonePlayer
import com.dev.flutter_twilio.types.CallDirection
import com.twilio.voice.ConnectOptions
import com.twilio.voice.Voice

object TVCallManager : Call.Listener {
    private const val TAG = "TVCallManager"
    private val mainHandler = Handler(Looper.getMainLooper())

    private var appContext: Context? = null
    private var _audioManager: TVAudioManager? = null

    val audioManager: TVAudioManager? get() = _audioManager

    var activeCall: Call? = null
        private set
    var activeCallInvite: CallInvite? = null
        private set
    var callDirection: CallDirection = CallDirection.OUTGOING
        private set

    /** Epoch millis when the current call was placed / accepted. `0` when no call is active. */
    @Volatile
    var callStartedAtMillis: Long = 0L
        private set

    /** Epoch millis when the call's media first connected. `null` while ringing/connecting. */
    @Volatile
    var connectedAtMillis: Long? = null
        private set

    /** Caller identifier of the current call (outgoing: from our identity; incoming: remote). */
    @Volatile
    var activeCallFrom: String = ""
        private set

    /** Callee identifier of the current call. */
    @Volatile
    var activeCallTo: String = ""
        private set

    /** Extra parameters attached to the active call (incoming invite params or outgoing extras). */
    @Volatile
    var activeCustomParameters: Map<String, String> = emptyMap()
        private set

    private var ringback: TVRingbackController? = null
    private var connectTonePlayer: TVTonePlayer? = null
    private var disconnectTonePlayer: TVTonePlayer? = null
    private var config: VoiceConfigLocal = VoiceConfigLocal.default

    fun applyConfig(
        cfg: VoiceConfigLocal,
        ringbackPlayer: TVTonePlayer,
        connectPlayer: TVTonePlayer,
        disconnectPlayer: TVTonePlayer,
    ) {
        config = cfg
        ringback = TVRingbackController(
            ringbackPlayer,
            enabled = cfg.playRingback,
            customAssetKey = cfg.ringbackAssetPath,
        )
        connectTonePlayer = connectPlayer
        disconnectTonePlayer = disconnectPlayer
    }

    val activeConfig: VoiceConfigLocal get() = config

    var listener: TVCallManagerListener? = null
        set(value) {
            field = value
            // Replay pending invite when listener connects (FCM may arrive before plugin initializes)
            activeCallInvite?.let { value?.onCallInviteReceived(it) }
        }

    interface TVCallManagerListener {
        fun onCallInviteReceived(callInvite: CallInvite)
        fun onCancelledCallInviteReceived(cancelledCallInvite: CancelledCallInvite)
        fun onCallRinging(call: Call)
        fun onCallConnected(call: Call)
        fun onCallConnectFailure(call: Call, error: CallException)
        fun onCallReconnecting(call: Call, error: CallException)
        fun onCallReconnected(call: Call)
        fun onCallDisconnected(call: Call, error: CallException?)
    }

    fun init(context: Context) {
        appContext = context.applicationContext
        if (_audioManager == null) {
            _audioManager = TVAudioManager(context.applicationContext)
        }
    }

    fun handleCallInvite(callInvite: CallInvite) {
        Log.d(TAG, "handleCallInvite: ${callInvite.callSid}")
        callDirection = CallDirection.INCOMING
        activeCallInvite = callInvite
        activeCallFrom = callInvite.from ?: ""
        activeCallTo = callInvite.to ?: ""
        activeCustomParameters = callInvite.customParameters.toMap()
        listener?.onCallInviteReceived(callInvite)
    }

    fun handleCancelledCallInvite(cancelledCallInvite: CancelledCallInvite) {
        Log.d(TAG, "handleCancelledCallInvite: ${cancelledCallInvite.callSid}")
        if (activeCallInvite?.callSid == cancelledCallInvite.callSid) {
            activeCallInvite = null
        }
        listener?.onCancelledCallInviteReceived(cancelledCallInvite)
    }

    fun acceptCall(context: Context): Boolean {
        val invite = activeCallInvite ?: run {
            Log.e(TAG, "acceptCall: No active call invite")
            return false
        }
        Log.d(TAG, "acceptCall: ${invite.callSid}")
        val call = invite.accept(context, this)
        if (call == null) {
            Log.e(TAG, "acceptCall: invite.accept() returned null")
            return false
        }
        activeCall = call
        activeCallInvite = null
        callStartedAtMillis = System.currentTimeMillis()
        TVCallAudioService.startService(context, invite.from ?: "Unknown")
        _audioManager?.requestAudioFocus()
        TVIncomingCallNotifier.cancel(context)
        return true
    }

    fun rejectCall(context: Context): Boolean {
        val invite = activeCallInvite ?: run {
            Log.e(TAG, "rejectCall: No active call invite")
            return false
        }
        Log.d(TAG, "rejectCall: ${invite.callSid}")
        invite.reject(context)
        activeCallInvite = null
        activeCustomParameters = emptyMap()
        activeCallFrom = ""
        activeCallTo = ""
        TVIncomingCallNotifier.cancel(context)
        return true
    }

    /**
     * Starts an outgoing Twilio call. Throws if the Twilio SDK rejects the
     * request — the Pigeon guard in [com.dev.flutter_twilio.FlutterTwilioPlugin]
     * maps [CallException] / [RuntimeException] into stable error codes for
     * Dart.
     */
    fun makeCall(context: Context, accessToken: String, to: String?, from: String?, params: Map<String, String>) {
        Log.d(TAG, "makeCall: to=$to, from=$from")
        callDirection = CallDirection.OUTGOING
        val paramsWithIdentity = HashMap<String, String>(params).apply {
            if (!to.isNullOrEmpty()) put("To", to)
            if (!from.isNullOrEmpty()) put("From", from)
        }
        val connectOptions = try {
            ConnectOptions.Builder(accessToken)
                .params(paramsWithIdentity)
                .build()
        } catch (t: Throwable) {
            Log.e(TAG, "makeCall: failed to build ConnectOptions: ${t.message}")
            throw t
        }
        val call = try {
            Voice.connect(context, connectOptions, this)
        } catch (t: Throwable) {
            Log.e(TAG, "makeCall: Voice.connect threw: ${t.message}")
            throw t
        }
        if (call == null) {
            Log.e(TAG, "makeCall: Voice.connect() returned null")
            throw com.dev.flutter_twilio.FlutterTwilioError.of(
                "connection_error",
                "Voice.connect returned null — unable to start outgoing call",
            )
        }
        activeCall = call
        callStartedAtMillis = System.currentTimeMillis()
        activeCallFrom = from ?: ""
        activeCallTo = to ?: ""
        activeCustomParameters = params.filterKeys { it != "To" && it != "From" }
        TVCallAudioService.startService(context, to ?: "Unknown")
        _audioManager?.requestAudioFocus()
        ringback?.onCallEvent(CallPhase.OUTGOING_CONNECTING)
    }

    fun hangUp(): Boolean {
        val call = activeCall ?: run {
            Log.w(TAG, "hangUp: No active call")
            return false
        }
        call.disconnect()
        return true
    }

    fun toggleMute(mute: Boolean) {
        activeCall?.mute(mute) ?: Log.w(TAG, "toggleMute: No active call")
    }

    fun toggleHold(hold: Boolean) {
        activeCall?.hold(hold) ?: Log.w(TAG, "toggleHold: No active call")
    }

    fun sendDigits(digits: String) {
        activeCall?.sendDigits(digits) ?: Log.w(TAG, "sendDigits: No active call")
    }

    fun acceptPendingInvite(context: Context): Boolean = acceptCall(context)

    fun rejectPendingInvite(context: Context): Boolean = rejectCall(context)

    fun shouldBringAppToForegroundOnAnswer(): Boolean = config.bringAppToForegroundOnAnswer

    fun shouldBringAppToForegroundOnEnd(): Boolean = config.bringAppToForegroundOnEnd

    fun hasActiveCall(): Boolean = activeCall != null || activeCallInvite != null

    fun getActiveCallSid(): String? = activeCall?.sid ?: activeCallInvite?.callSid

    // region Call.Listener — called on Twilio SDK thread, post to main
    override fun onRinging(call: Call) {
        Log.d(TAG, "onRinging: ${call.sid}")
        mainHandler.post { listener?.onCallRinging(call) }
    }

    override fun onConnected(call: Call) {
        Log.d(TAG, "onConnected: ${call.sid}")
        activeCall = call
        connectedAtMillis = System.currentTimeMillis()
        ringback?.onCallEvent(CallPhase.CONNECTED)
        if (config.playConnectTone) {
            connectTonePlayer?.play(
                flutterAssetKey = config.connectToneAssetPath,
                bundledAssetPath = "flutter_twilio/connect_tone.ogg",
                looping = false,
                forSignalling = true,
            )
        }
        mainHandler.post { listener?.onCallConnected(call) }
    }

    override fun onConnectFailure(call: Call, error: CallException) {
        Log.e(TAG, "onConnectFailure: ${error.errorCode} ${error.message}")
        ringback?.onCallEvent(CallPhase.ERROR)
        cleanup()
        mainHandler.post { listener?.onCallConnectFailure(call, error) }
    }

    override fun onReconnecting(call: Call, callException: CallException) {
        Log.d(TAG, "onReconnecting: ${call.sid}")
        mainHandler.post { listener?.onCallReconnecting(call, callException) }
    }

    override fun onReconnected(call: Call) {
        Log.d(TAG, "onReconnected: ${call.sid}")
        mainHandler.post { listener?.onCallReconnected(call) }
    }

    override fun onDisconnected(call: Call, error: CallException?) {
        Log.d(TAG, "onDisconnected: ${call.sid}, error: ${error?.message}")
        ringback?.onCallEvent(CallPhase.DISCONNECTED)
        if (config.playDisconnectTone) {
            disconnectTonePlayer?.play(
                flutterAssetKey = config.disconnectToneAssetPath,
                bundledAssetPath = "flutter_twilio/disconnect_tone.ogg",
                looping = false,
                forSignalling = true,
            )
        }
        if (config.bringAppToForegroundOnEnd) {
            appContext?.let { ctx ->
                ctx.packageManager.getLaunchIntentForPackage(ctx.packageName)?.let { intent ->
                    intent.addFlags(
                        Intent.FLAG_ACTIVITY_NEW_TASK or
                            Intent.FLAG_ACTIVITY_REORDER_TO_FRONT or
                            Intent.FLAG_ACTIVITY_SINGLE_TOP,
                    )
                    intent.putExtra("com.dev.flutter_twilio.action", "call_ended")
                    ctx.startActivity(intent)
                }
            }
        }
        cleanup()
        mainHandler.post { listener?.onCallDisconnected(call, error) }
    }
    // endregion

    private fun cleanup() {
        activeCall = null
        activeCallInvite = null
        callStartedAtMillis = 0L
        connectedAtMillis = null
        activeCallFrom = ""
        activeCallTo = ""
        activeCustomParameters = emptyMap()
        _audioManager?.reset()
        _audioManager?.abandonAudioFocus()
        appContext?.let { TVCallAudioService.stopService(it) }
    }
}
