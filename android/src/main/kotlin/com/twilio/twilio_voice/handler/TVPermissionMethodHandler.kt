package com.twilio.twilio_voice.handler

import android.Manifest
import android.content.DialogInterface
import android.content.pm.PackageManager
import android.os.Build
import android.util.Log
import androidx.appcompat.app.AlertDialog
import androidx.core.app.ActivityCompat
import com.twilio.twilio_voice.R
import com.twilio.twilio_voice.TVEventEmitter
import com.twilio.twilio_voice.TVPluginState
import com.twilio.twilio_voice.types.ContextExtension.checkPermission
import com.twilio.twilio_voice.types.ContextExtension.hasCallPhonePermission
import com.twilio.twilio_voice.types.ContextExtension.hasManageOwnCallsPermission
import com.twilio.twilio_voice.types.ContextExtension.hasMicrophoneAccess
import com.twilio.twilio_voice.types.ContextExtension.hasReadPhoneNumbersPermission
import com.twilio.twilio_voice.types.ContextExtension.hasReadPhoneStatePermission
import com.twilio.twilio_voice.types.TVMethodChannels
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class TVPermissionMethodHandler(
    private val state: TVPluginState,
    private val emitter: TVEventEmitter
) {
    companion object {
        private const val TAG = "TVPermissionMethodHandler"
        const val REQUEST_CODE_MICROPHONE = 1
        const val REQUEST_CODE_CALL_PHONE = 3
        const val REQUEST_CODE_READ_PHONE_NUMBERS = 4
        const val REQUEST_CODE_READ_PHONE_STATE = 5
        const val REQUEST_CODE_MICROPHONE_FOREGROUND = 6
        const val REQUEST_CODE_MANAGE_CALLS = 7
    }

    fun handle(method: TVMethodChannels, call: MethodCall, result: MethodChannel.Result): Boolean {
        return when (method) {
            TVMethodChannels.HAS_MIC_PERMISSION -> {
                result.success(state.context?.hasMicrophoneAccess() ?: false)
                true
            }
            TVMethodChannels.REQUEST_MIC_PERMISSION -> {
                emitter.logEvent("requesting mic permission")
                if (state.context?.hasMicrophoneAccess() == true) {
                    result.success(true)
                } else {
                    requestPermission("Microphone", "Microphone permission is required to make or receive phone calls.",
                        Manifest.permission.RECORD_AUDIO, REQUEST_CODE_MICROPHONE) { result.success(it) }
                }
                true
            }
            TVMethodChannels.HAS_READ_PHONE_STATE_PERMISSION -> {
                result.success(state.context?.hasReadPhoneStatePermission() ?: false)
                true
            }
            TVMethodChannels.REQUEST_READ_PHONE_STATE_PERMISSION -> {
                emitter.logEvent("requestingReadPhoneStatePermission")
                if (state.context?.hasReadPhoneStatePermission() == true) {
                    result.success(true)
                } else {
                    requestPermission("Read Phone State", "Read phone state to make or receive phone calls.",
                        Manifest.permission.READ_PHONE_STATE, REQUEST_CODE_READ_PHONE_STATE) { result.success(it) }
                }
                true
            }
            TVMethodChannels.HAS_CALL_PHONE_PERMISSION -> {
                result.success(state.context?.hasCallPhonePermission() ?: false)
                true
            }
            TVMethodChannels.REQUEST_CALL_PHONE_PERMISSION -> {
                emitter.logEvent("requestingCallPhonePermission")
                if (state.context?.hasCallPhonePermission() == true) {
                    result.success(true)
                } else {
                    requestPermission("Access Phone", "Required to place calls with Telecom App",
                        Manifest.permission.CALL_PHONE, REQUEST_CODE_CALL_PHONE) { result.success(it) }
                }
                true
            }
            TVMethodChannels.HAS_READ_PHONE_NUMBERS_PERMISSION -> {
                result.success(state.context?.hasReadPhoneNumbersPermission() ?: false)
                true
            }
            TVMethodChannels.REQUEST_READ_PHONE_NUMBERS_PERMISSION -> {
                emitter.logEvent("requestingReadPhoneNumbersPermission")
                if (state.context?.hasReadPhoneNumbersPermission() == true) {
                    result.success(true)
                } else {
                    requestPermission("Read Phone Numbers", "Grant access to read phone numbers.",
                        Manifest.permission.READ_PHONE_NUMBERS, REQUEST_CODE_READ_PHONE_NUMBERS) { result.success(it) }
                }
                true
            }
            TVMethodChannels.HAS_MANAGE_OWN_CALLS_PERMISSION -> {
                val has = if (Build.VERSION.SDK_INT <= Build.VERSION_CODES.TIRAMISU) {
                    state.context?.hasManageOwnCallsPermission() ?: false
                } else true
                result.success(has)
                true
            }
            TVMethodChannels.REQUEST_MANAGE_OWN_CALLS_PERMISSION -> {
                emitter.logEvent("requestingManageOwnCallsPermission")
                if (Build.VERSION.SDK_INT > Build.VERSION_CODES.TIRAMISU || state.context?.hasManageOwnCallsPermission() == true) {
                    result.success(true)
                } else {
                    requestPermission("Manage Calls", "Manage own calls permission.",
                        Manifest.permission.MANAGE_OWN_CALLS, REQUEST_CODE_MANAGE_CALLS) { result.success(it) }
                }
                true
            }
            @Suppress("DEPRECATION")
            TVMethodChannels.HAS_BLUETOOTH_PERMISSION,
            @Suppress("DEPRECATION")
            TVMethodChannels.REQUEST_BLUETOOTH_PERMISSION -> {
                result.success(false)
                true
            }
            else -> false
        }
    }

    fun onPermissionsResult(requestCode: Int, permissions: Array<String>, grantResults: IntArray): Boolean {
        if (permissions.isNotEmpty()) {
            val granted = grantResults[0] == PackageManager.PERMISSION_GRANTED
            state.permissionResultHandler[requestCode]?.let { handler ->
                handler(granted)
                state.permissionResultHandler.remove(requestCode)
            }
            when (requestCode) {
                REQUEST_CODE_MICROPHONE -> {
                    emitter.logEventPermission("Microphone", granted)
                    if (granted) requestMicrophoneForeground()
                }
                REQUEST_CODE_READ_PHONE_NUMBERS -> emitter.logEventPermission("Read Phone Numbers", granted)
                REQUEST_CODE_READ_PHONE_STATE -> emitter.logEventPermission("Read Phone State", granted)
                REQUEST_CODE_CALL_PHONE -> {
                    emitter.logEventPermission("Call Phone", granted)
                    if (granted) requestManageCallsIfNeeded()
                }
                REQUEST_CODE_MICROPHONE_FOREGROUND -> emitter.logEventPermission("Microphone", granted)
                REQUEST_CODE_MANAGE_CALLS -> emitter.logEventPermission("Manage Calls", granted)
            }
        }
        return true
    }

    private fun requestMicrophoneForeground() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            Log.d(TAG, "requestMicrophoneForeground: automatically requesting foreground microphone permission")
            requestPermission("Microphone Foreground",
                "Microphone Foreground permission is required to make or receive phone calls on Android 14 and higher.",
                Manifest.permission.FOREGROUND_SERVICE_MICROPHONE, REQUEST_CODE_MICROPHONE_FOREGROUND) {
                Log.d(TAG, "Microphone foreground permission result: $it")
            }
        }
    }

    private fun requestManageCallsIfNeeded() {
        if (Build.VERSION.SDK_INT <= Build.VERSION_CODES.TIRAMISU) {
            requestPermission("Manage Calls", "Manage own calls permission.",
                Manifest.permission.MANAGE_OWN_CALLS, REQUEST_CODE_MANAGE_CALLS) {
                Log.d(TAG, "Manage Calls permission result: $it")
            }
        }
    }

    private fun requestPermission(
        name: String,
        description: String,
        manifestPermission: String,
        requestCode: Int,
        onResult: (Boolean) -> Unit
    ) {
        val activity = state.activity ?: run { onResult(false); return }
        if (activity.checkPermission(manifestPermission)) { onResult(true); return }

        emitter.logEvent("requestPermissionFor$name")
        state.permissionResultHandler[requestCode] = onResult
        if (ActivityCompat.shouldShowRequestPermissionRationale(activity, manifestPermission)) {
            val clickListener = DialogInterface.OnClickListener { _, _ ->
                ActivityCompat.requestPermissions(activity, arrayOf(manifestPermission), requestCode)
            }
            AlertDialog.Builder(activity)
                .setTitle("$name Permissions")
                .setMessage(description)
                .setPositiveButton(R.string.proceed, clickListener)
                .setNegativeButton(R.string.cancel, null)
                .setOnDismissListener { emitter.logEvent("Request${name}Access") }
                .show()
        } else {
            ActivityCompat.requestPermissions(activity, arrayOf(manifestPermission), requestCode)
        }
    }
}
