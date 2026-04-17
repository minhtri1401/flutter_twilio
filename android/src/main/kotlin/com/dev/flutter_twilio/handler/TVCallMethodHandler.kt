package com.dev.flutter_twilio.handler

import android.util.Log
import com.dev.flutter_twilio.TVEventEmitter
import com.dev.flutter_twilio.TVPluginState
import com.dev.flutter_twilio.constants.Constants
import com.dev.flutter_twilio.constants.FlutterErrorCodes
import com.dev.flutter_twilio.service.TVCallManager
import com.dev.flutter_twilio.types.ContextExtension.hasMicrophoneAccess
import com.dev.flutter_twilio.types.TVMethodChannels
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject

class TVCallMethodHandler(
    private val state: TVPluginState,
    private val emitter: TVEventEmitter
) {
    companion object { private const val TAG = "TVCallMethodHandler" }

    fun handle(method: TVMethodChannels, call: MethodCall, result: MethodChannel.Result): Boolean {
        return when (method) {
            TVMethodChannels.SEND_DIGITS -> {
                val digits = call.argument<String>("digits") ?: run {
                    result.error(FlutterErrorCodes.MALFORMED_ARGUMENTS, "No 'digits' provided or invalid type", null)
                    return true
                }
                TVCallManager.sendDigits(digits)
                result.success(TVCallManager.hasActiveCall())
                true
            }
            TVMethodChannels.HANGUP -> {
                Log.d(TAG, "Hanging up")
                TVCallManager.hangUp()
                result.success(true)
                true
            }
            TVMethodChannels.ANSWER -> {
                Log.d(TAG, "Answering call")
                state.context?.let { TVCallManager.acceptCall(it) }
                    ?: Log.e(TAG, "Context is null, cannot answer call")
                result.success(true)
                true
            }
            TVMethodChannels.CALL_SID -> {
                result.success(TVCallManager.getActiveCallSid())
                true
            }
            TVMethodChannels.IS_ON_CALL -> {
                result.success(TVCallManager.hasActiveCall())
                true
            }
            TVMethodChannels.MAKE_CALL -> {
                handlePlaceCall(call, result, connect = false)
                true
            }
            TVMethodChannels.CONNECT -> {
                handlePlaceCall(call, result, connect = true)
                true
            }
            else -> false
        }
    }

    private fun handlePlaceCall(call: MethodCall, result: MethodChannel.Result, connect: Boolean) {
        val args = call.arguments as? Map<*, *> ?: run {
            result.error(FlutterErrorCodes.MALFORMED_ARGUMENTS, "Arguments should be a Map<*, *>", null)
            return
        }

        emitter.logEvent("Making new call via ${if (connect) "connect" else "makeCall"}")

        val params = mutableMapOf<String, String>()
        for ((key, value) in args) {
            if (key != Constants.PARAM_TO && key != Constants.PARAM_FROM) {
                params[key.toString()] = value.toString()
            }
        }

        val from: String
        val to: String
        if (connect) {
            from = call.argument<String>(Constants.PARAM_FROM).also {
                if (it == null) emitter.logEvent("No 'from' provided or invalid type, ignoring.")
            } ?: ""
            to = call.argument<String>(Constants.PARAM_TO).also {
                if (it == null) emitter.logEvent("No 'to' provided or invalid type, ignoring.")
            } ?: ""
            Log.d(TAG, "calling with params: from='$from' to='$to' params=${JSONObject(args)}")
        } else {
            from = call.argument<String>(Constants.PARAM_FROM) ?: run {
                result.error(FlutterErrorCodes.MALFORMED_ARGUMENTS, "No '${Constants.PARAM_FROM}' provided or invalid type", null)
                return
            }
            to = call.argument<String>(Constants.PARAM_TO) ?: run {
                result.error(FlutterErrorCodes.MALFORMED_ARGUMENTS, "No '${Constants.PARAM_TO}' provided or invalid type", null)
                return
            }
            Log.d(TAG, "calling $from -> $to")
        }

        val token = state.accessToken ?: run {
            result.error(FlutterErrorCodes.MALFORMED_ARGUMENTS, "No accessToken set, are you registered?", null)
            return
        }
        val ctx = state.context ?: run {
            Log.e(TAG, "Context is null, cannot place call")
            result.success(false)
            return
        }
        if (!ctx.hasMicrophoneAccess()) {
            Log.e(TAG, "No microphone permission, call requestMicrophonePermission() first")
            result.success(false)
            return
        }

        val callParams = HashMap<String, String>(params)
        if (to.isNotEmpty()) callParams[Constants.PARAM_TO] = to
        if (from.isNotEmpty()) callParams[Constants.PARAM_FROM] = from

        result.success(TVCallManager.makeCall(ctx, token, to, from, callParams))
    }
}
