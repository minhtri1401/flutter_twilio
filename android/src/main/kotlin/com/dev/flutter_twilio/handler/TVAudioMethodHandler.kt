package com.dev.flutter_twilio.handler

import android.util.Log
import com.dev.flutter_twilio.TVEventEmitter
import com.dev.flutter_twilio.TVPluginState
import com.dev.flutter_twilio.constants.FlutterErrorCodes
import com.dev.flutter_twilio.service.TVCallManager
import com.dev.flutter_twilio.types.TVMethodChannels
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class TVAudioMethodHandler(
    private val state: TVPluginState,
    private val emitter: TVEventEmitter
) {
    companion object { private const val TAG = "TVAudioMethodHandler" }

    fun handle(method: TVMethodChannels, call: MethodCall, result: MethodChannel.Result): Boolean {
        return when (method) {
            TVMethodChannels.TOGGLE_SPEAKER -> {
                val speakerIsOn = call.argument<Boolean>("speakerIsOn") ?: run {
                    result.error(FlutterErrorCodes.MALFORMED_ARGUMENTS, "No 'speakerIsOn' provided or invalid type", null)
                    return true
                }
                if (!TVCallManager.hasActiveCall()) {
                    Log.d(TAG, "Not on call, cannot toggle speaker")
                    result.success(false)
                    return true
                }
                TVCallManager.audioManager?.setSpeaker(speakerIsOn)
                state.isSpeakerOn = speakerIsOn
                result.success(true)
                true
            }
            TVMethodChannels.IS_ON_SPEAKER -> {
                result.success(state.isSpeakerOn)
                true
            }
            TVMethodChannels.TOGGLE_BLUETOOTH -> {
                val bluetoothOn = call.argument<Boolean>("bluetoothOn") ?: run {
                    result.error(FlutterErrorCodes.MALFORMED_ARGUMENTS, "No 'bluetoothOn' provided or invalid type", null)
                    return true
                }
                if (!TVCallManager.hasActiveCall()) {
                    Log.d(TAG, "Not on call, cannot toggle bluetooth")
                    result.success(false)
                    return true
                }
                TVCallManager.audioManager?.setBluetooth(bluetoothOn)
                state.isBluetoothOn = bluetoothOn
                result.success(true)
                true
            }
            TVMethodChannels.IS_BLUETOOTH_ON -> {
                result.success(state.isBluetoothOn)
                true
            }
            TVMethodChannels.TOGGLE_MUTE -> {
                val muted = call.argument<Boolean>("muted") ?: run {
                    result.error(FlutterErrorCodes.MALFORMED_ARGUMENTS, "No 'muted' provided or invalid type", null)
                    return true
                }
                if (!TVCallManager.hasActiveCall()) {
                    Log.d(TAG, "Not on call, cannot toggle mute")
                    result.success(false)
                    return true
                }
                TVCallManager.toggleMute(muted)
                state.isMuted = muted
                result.success(true)
                true
            }
            TVMethodChannels.IS_MUTED -> {
                result.success(state.isMuted)
                true
            }
            TVMethodChannels.HOLD_CALL -> {
                val shouldHold = call.argument<Boolean>("shouldHold") ?: run {
                    result.error(FlutterErrorCodes.MALFORMED_ARGUMENTS, "No 'shouldHold' provided or invalid type", null)
                    return true
                }
                Log.d(TAG, "Hold call invoked")
                if (!TVCallManager.hasActiveCall()) {
                    Log.d(TAG, "Not on call, cannot toggle hold")
                    result.success(false)
                    return true
                }
                TVCallManager.toggleHold(shouldHold)
                state.isHolding = shouldHold
                result.success(true)
                true
            }
            TVMethodChannels.IS_HOLDING -> {
                result.success(state.isHolding)
                true
            }
            else -> false
        }
    }
}
