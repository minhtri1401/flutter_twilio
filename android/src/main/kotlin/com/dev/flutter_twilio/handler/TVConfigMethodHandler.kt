package com.dev.flutter_twilio.handler

import android.util.Log
import com.dev.flutter_twilio.TVEventEmitter
import com.dev.flutter_twilio.TVPluginState
import com.dev.flutter_twilio.constants.FlutterErrorCodes
import com.dev.flutter_twilio.types.TVMethodChannels
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class TVConfigMethodHandler(
    private val state: TVPluginState,
    private val emitter: TVEventEmitter
) {
    companion object { private const val TAG = "TVConfigMethodHandler" }

    fun handle(method: TVMethodChannels, call: MethodCall, result: MethodChannel.Result): Boolean {
        return when (method) {
            TVMethodChannels.DEFAULT_CALLER -> {
                val defaultCaller = call.argument<String>("defaultCaller") ?: run {
                    result.error(FlutterErrorCodes.MALFORMED_ARGUMENTS, "No 'defaultCaller' provided or invalid type", null)
                    return true
                }
                val storage = state.storage ?: run {
                    Log.e(TAG, "Storage is null")
                    result.success(false)
                    return true
                }
                emitter.logEvent("defaultCaller is $defaultCaller")
                storage.defaultCaller = defaultCaller
                result.success(true)
                true
            }
            TVMethodChannels.SHOW_NOTIFICATIONS -> {
                val show = call.argument<Boolean>("show") ?: run {
                    result.error(FlutterErrorCodes.MALFORMED_ARGUMENTS, "No 'show' provided or invalid type", null)
                    return true
                }
                val storage = state.storage ?: run {
                    Log.e(TAG, "Storage is null")
                    result.success(false)
                    return true
                }
                storage.showNotifications = show
                result.success(true)
                true
            }
            TVMethodChannels.REJECT_CALL_ON_NO_PERMISSIONS -> {
                val shouldReject = call.argument<Boolean>("shouldReject") ?: run {
                    result.error(FlutterErrorCodes.MALFORMED_ARGUMENTS, "No 'shouldReject' provided or invalid type", null)
                    return true
                }
                val storage = state.storage ?: run {
                    Log.e(TAG, "Storage is null")
                    result.success(false)
                    return true
                }
                Log.d(TAG, "shouldRejectOnNoPermissions: $shouldReject")
                storage.rejectOnNoPermissions = shouldReject
                result.success(true)
                true
            }
            TVMethodChannels.IS_REJECTING_CALL_ON_NO_PERMISSIONS -> {
                val storage = state.storage ?: run {
                    Log.e(TAG, "Storage is null")
                    result.success(false)
                    return true
                }
                result.success(storage.rejectOnNoPermissions)
                true
            }
            TVMethodChannels.HAS_REGISTERED_PHONE_ACCOUNT -> {
                emitter.logEvent("hasRegisteredPhoneAccount")
                Log.w(TAG, "hasRegisteredPhoneAccount: phone accounts not used, returning true")
                result.success(true)
                true
            }
            TVMethodChannels.REGISTER_PHONE_ACCOUNT -> {
                emitter.logEvent("registerPhoneAccount")
                Log.w(TAG, "registerPhoneAccount: phone accounts not used, returning true")
                result.success(true)
                true
            }
            TVMethodChannels.IS_PHONE_ACCOUNT_ENABLED -> {
                emitter.logEvent("isPhoneAccountEnabled")
                Log.w(TAG, "isPhoneAccountEnabled: phone accounts not used, returning true")
                result.success(true)
                true
            }
            TVMethodChannels.OPEN_PHONE_ACCOUNT_SETTINGS -> {
                emitter.logEvent("changePhoneAccount")
                Log.w(TAG, "openPhoneAccountSettings: phone accounts not used, no-op")
                result.success(true)
                true
            }
            TVMethodChannels.UPDATE_CALLKIT_ICON -> {
                result.success(true)
                true
            }
            @Suppress("DEPRECATION")
            TVMethodChannels.BACKGROUND_CALL_UI,
            @Suppress("DEPRECATION")
            TVMethodChannels.REQUIRES_BACKGROUND_PERMISSIONS,
            @Suppress("DEPRECATION")
            TVMethodChannels.REQUEST_BACKGROUND_PERMISSIONS -> {
                result.success(true)
                true
            }
            else -> false
        }
    }
}
