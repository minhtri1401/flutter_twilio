package com.twilio.twilio_voice.handler

import android.util.Log
import com.twilio.twilio_voice.TVEventEmitter
import com.twilio.twilio_voice.TVPluginState
import com.twilio.twilio_voice.constants.FlutterErrorCodes
import com.twilio.twilio_voice.types.TVMethodChannels
import com.twilio.voice.RegistrationException
import com.twilio.voice.RegistrationListener
import com.twilio.voice.UnregistrationListener
import com.twilio.voice.Voice
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class TVRegistrationMethodHandler(
    private val state: TVPluginState,
    private val emitter: TVEventEmitter
) {
    companion object { private const val TAG = "TVRegistrationMethodHandler" }

    fun handle(method: TVMethodChannels, call: MethodCall, result: MethodChannel.Result): Boolean {
        return when (method) {
            TVMethodChannels.TOKENS -> {
                val deviceToken = call.argument<String>("deviceToken") ?: run {
                    result.error(FlutterErrorCodes.MALFORMED_ARGUMENTS, "No 'deviceToken' provided or invalid type", null)
                    return true
                }
                val accessToken = call.argument<String>("accessToken") ?: run {
                    result.error(FlutterErrorCodes.MALFORMED_ARGUMENTS, "No 'accessToken' provided or invalid type", null)
                    return true
                }
                Log.d(TAG, "Setting up tokens and registering for call invites")
                state.accessToken = accessToken
                state.fcmToken = deviceToken
                registerForCallInvites(accessToken, deviceToken)
                result.success(true)
                true
            }
            TVMethodChannels.UNREGISTER -> {
                val token = call.argument<String?>("accessToken") ?: state.accessToken ?: run {
                    result.error(FlutterErrorCodes.MALFORMED_ARGUMENTS, "No 'accessToken' provided or invalid type, nor any previously set", null)
                    return true
                }
                unregisterForCallInvites(token)
                result.success(true)
                true
            }
            TVMethodChannels.REGISTER_CLIENT -> {
                val clientId = call.argument<String>("id") ?: run {
                    result.error(FlutterErrorCodes.MALFORMED_ARGUMENTS, "No 'id' provided or invalid type", null)
                    return true
                }
                val clientName = call.argument<String>("name") ?: run {
                    result.error(FlutterErrorCodes.MALFORMED_ARGUMENTS, "No 'name' provided or invalid type", null)
                    return true
                }
                val storage = state.storage ?: run {
                    Log.e(TAG, "Storage is null")
                    result.success(false)
                    return true
                }
                emitter.logEvent("Registering client $clientId:$clientName")
                result.success(storage.addRegisteredClient(clientId, clientName))
                true
            }
            TVMethodChannels.UNREGISTER_CLIENT -> {
                val clientId = call.argument<String>("id") ?: run {
                    result.error(FlutterErrorCodes.MALFORMED_ARGUMENTS, "No 'id' provided or invalid type", null)
                    return true
                }
                val storage = state.storage ?: run {
                    Log.e(TAG, "Storage is null")
                    result.success(false)
                    return true
                }
                emitter.logEvent("Unregistering $clientId")
                result.success(storage.removeRegisteredClient(clientId))
                true
            }
            else -> false
        }
    }

    private fun registerForCallInvites(accessToken: String, fcmToken: String): Boolean {
        if (fcmToken.isEmpty() || accessToken.isEmpty()) {
            Log.e(TAG, "Token is empty, unable to register")
            return false
        }
        Voice.register(accessToken, Voice.RegistrationChannel.FCM, fcmToken, object : RegistrationListener {
            override fun onRegistered(accessToken: String, fcmToken: String) {
                Log.d(TAG, "Successfully registered FCM $fcmToken")
            }
            override fun onError(e: RegistrationException, accessToken: String, fcmToken: String) {
                Log.e(TAG, "Registration error: ${e.errorCode}, ${e.message}")
            }
        })
        return true
    }

    private fun unregisterForCallInvites(accessToken: String) {
        Log.i(TAG, "Un-registering with FCM")
        val fcmToken = state.fcmToken ?: run {
            Log.e(TAG, "FCM token is null, unable to unregister")
            return
        }
        Voice.unregister(accessToken, Voice.RegistrationChannel.FCM, fcmToken, object : UnregistrationListener {
            override fun onUnregistered(accessToken: String?, fcmToken: String?) {
                Log.d(TAG, "Successfully un-registered FCM $fcmToken")
            }
            override fun onError(e: RegistrationException, accessToken: String, fcmToken: String) {
                Log.e(TAG, "Unregistration error: ${e.errorCode}, ${e.message}")
            }
        })
    }
}
