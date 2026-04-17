package com.dev.flutter_twilio.handler

import android.util.Log
import com.dev.flutter_twilio.FlutterTwilioError
import com.dev.flutter_twilio.TVEventEmitter
import com.dev.flutter_twilio.TVPluginState
import com.google.firebase.messaging.FirebaseMessaging
import com.twilio.voice.RegistrationException
import com.twilio.voice.RegistrationListener
import com.twilio.voice.UnregistrationListener
import com.twilio.voice.Voice

class TVRegistrationMethodHandler(
    private val state: TVPluginState,
    private val emitter: TVEventEmitter,
) {
    companion object {
        private const val TAG = "TVRegistrationMethodHandler"
    }

    /** Stores the Twilio access token for later [register] / [com.dev.flutter_twilio.handler.TVCallMethodHandler.place] calls. */
    fun setAccessToken(token: String) {
        if (token.isEmpty()) {
            throw FlutterTwilioError.of("invalid_argument", "Access token must not be empty")
        }
        Log.d(TAG, "setAccessToken: token length=${token.length}")
        state.accessToken = token
    }

    /**
     * Registers the active access token + the current FCM device token with Twilio.
     *
     * The FCM token is fetched asynchronously; this method returns as soon as the
     * fetch is kicked off. Success / failure arrive on the Pigeon event stream
     * (`CallEventType.registered` / `CallEventType.error`) via [emitter].
     */
    fun register() {
        val accessToken = state.accessToken
            ?: throw FlutterTwilioError.of("not_initialized", "Access token not set")
        fetchFcmToken { token ->
            state.fcmToken = token
            registerForCallInvites(accessToken, token)
        }
    }

    /**
     * Unregisters the current access token / FCM device token with Twilio.
     *
     * Like [register], the FCM token lookup is asynchronous; failures are
     * reported via the event stream.
     */
    fun unregister() {
        val accessToken = state.accessToken
            ?: throw FlutterTwilioError.of("not_initialized", "Access token not set")
        val cached = state.fcmToken
        if (cached != null) {
            unregisterForCallInvites(accessToken, cached)
            return
        }
        fetchFcmToken { token ->
            state.fcmToken = token
            unregisterForCallInvites(accessToken, token)
        }
    }

    private fun fetchFcmToken(onToken: (String) -> Unit) {
        FirebaseMessaging.getInstance().token
            .addOnSuccessListener { token ->
                if (token.isNullOrEmpty()) {
                    emitter.emitError(
                        code = "registration_error",
                        message = "FCM returned an empty device token",
                    )
                } else {
                    onToken(token)
                }
            }
            .addOnFailureListener { t ->
                Log.e(TAG, "FCM token fetch failed", t)
                emitter.emitError(
                    code = "registration_error",
                    message = t.message ?: "Failed to fetch FCM device token",
                    details = mapOf("cause" to t::class.java.name),
                )
            }
    }

    private fun registerForCallInvites(accessToken: String, fcmToken: String) {
        Voice.register(
            accessToken,
            Voice.RegistrationChannel.FCM,
            fcmToken,
            object : RegistrationListener {
                override fun onRegistered(accessToken: String, fcmToken: String) {
                    Log.d(TAG, "registered FCM token")
                    emitter.logEvent("Registered")
                }

                override fun onError(
                    e: RegistrationException,
                    accessToken: String,
                    fcmToken: String,
                ) {
                    Log.e(TAG, "register error: ${e.errorCode} ${e.message}")
                    emitter.emitError(
                        code = "registration_error",
                        message = e.message ?: "Registration failed",
                        details = mapOf(
                            "twilioCode" to e.errorCode,
                            "twilioDomain" to "com.twilio.voice",
                        ),
                    )
                }
            },
        )
    }

    private fun unregisterForCallInvites(accessToken: String, fcmToken: String) {
        Voice.unregister(
            accessToken,
            Voice.RegistrationChannel.FCM,
            fcmToken,
            object : UnregistrationListener {
                override fun onUnregistered(accessToken: String?, fcmToken: String?) {
                    Log.d(TAG, "unregistered FCM token")
                    emitter.logEvent("Unregistered")
                }

                override fun onError(
                    e: RegistrationException,
                    accessToken: String,
                    fcmToken: String,
                ) {
                    Log.e(TAG, "unregister error: ${e.errorCode} ${e.message}")
                    emitter.emitError(
                        code = "registration_error",
                        message = e.message ?: "Unregistration failed",
                        details = mapOf(
                            "twilioCode" to e.errorCode,
                            "twilioDomain" to "com.twilio.voice",
                        ),
                    )
                }
            },
        )
    }
}
