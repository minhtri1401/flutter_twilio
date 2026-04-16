package com.twilio.twilio_voice.service

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import com.twilio.voice.Call
import com.twilio.voice.CallException
import com.twilio.voice.CallInvite
import com.twilio.voice.CancelledCallInvite
import com.twilio.twilio_voice.types.CallDirection
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
        TVCallAudioService.startService(context, invite.from ?: "Unknown")
        _audioManager?.requestAudioFocus()
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
        return true
    }

    fun makeCall(context: Context, accessToken: String, to: String?, from: String?, params: Map<String, String>): Boolean {
        Log.d(TAG, "makeCall: to=$to, from=$from")
        callDirection = CallDirection.OUTGOING
        val paramsWithIdentity = HashMap<String, String>(params).apply {
            if (!to.isNullOrEmpty()) put("To", to)
            if (!from.isNullOrEmpty()) put("From", from)
        }
        val connectOptions = ConnectOptions.Builder(accessToken)
            .params(paramsWithIdentity)
            .build()
        val call = Voice.connect(context, connectOptions, this)
        if (call != null) {
            activeCall = call
            TVCallAudioService.startService(context, to ?: "Unknown")
            _audioManager?.requestAudioFocus()
        } else {
            Log.e(TAG, "makeCall: Voice.connect() returned null")
        }
        return call != null
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
        mainHandler.post { listener?.onCallConnected(call) }
    }

    override fun onConnectFailure(call: Call, error: CallException) {
        Log.e(TAG, "onConnectFailure: ${error.errorCode} ${error.message}")
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
        cleanup()
        mainHandler.post { listener?.onCallDisconnected(call, error) }
    }
    // endregion

    private fun cleanup() {
        activeCall = null
        activeCallInvite = null
        _audioManager?.reset()
        _audioManager?.abandonAudioFocus()
        appContext?.let { TVCallAudioService.stopService(it) }
    }
}
