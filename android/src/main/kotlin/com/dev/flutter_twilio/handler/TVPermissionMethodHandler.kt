package com.dev.flutter_twilio.handler

import android.Manifest
import android.content.DialogInterface
import android.content.pm.PackageManager
import android.os.Build
import android.util.Log
import androidx.appcompat.app.AlertDialog
import androidx.core.app.ActivityCompat
import com.dev.flutter_twilio.FlutterTwilioError
import com.dev.flutter_twilio.R
import com.dev.flutter_twilio.TVEventEmitter
import com.dev.flutter_twilio.TVPluginState
import com.dev.flutter_twilio.types.ContextExtension.checkPermission
import com.dev.flutter_twilio.types.ContextExtension.hasMicrophoneAccess

class TVPermissionMethodHandler(
    private val state: TVPluginState,
    private val emitter: TVEventEmitter,
) {
    companion object {
        private const val TAG = "TVPermissionMethodHandler"
        const val REQUEST_CODE_MICROPHONE = 1
        const val REQUEST_CODE_MICROPHONE_FOREGROUND = 6
    }

    fun hasMicPermission(): Boolean {
        val ctx = state.context ?: return false
        return ctx.hasMicrophoneAccess()
    }

    /**
     * Requests `RECORD_AUDIO` permission. The Pigeon callback is completed by
     * [callback] once the Android framework delivers the result via
     * [onPermissionsResult].
     */
    fun requestMicPermission(callback: (Boolean) -> Unit) {
        val ctx = state.context ?: run {
            callback(false)
            return
        }
        if (ctx.hasMicrophoneAccess()) {
            callback(true)
            return
        }
        val activity = state.activity ?: run {
            callback(false)
            return
        }
        requestPermission(
            name = "Microphone",
            description = "Microphone permission is required to make or receive phone calls.",
            manifestPermission = Manifest.permission.RECORD_AUDIO,
            requestCode = REQUEST_CODE_MICROPHONE,
            onResult = callback,
        )
        // Best-effort: return value is delivered asynchronously via onPermissionsResult.
        // No action needed here.
        @Suppress("UNUSED_VARIABLE")
        val _unused = activity
    }

    fun onPermissionsResult(
        requestCode: Int,
        permissions: Array<String>,
        grantResults: IntArray,
    ): Boolean {
        if (permissions.isEmpty()) return true
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
            REQUEST_CODE_MICROPHONE_FOREGROUND -> emitter.logEventPermission("Microphone", granted)
        }
        return true
    }

    private fun requestMicrophoneForeground() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            Log.d(TAG, "requestMicrophoneForeground: requesting foreground mic permission")
            requestPermission(
                name = "Microphone Foreground",
                description = "Microphone Foreground permission is required on Android 14+.",
                manifestPermission = Manifest.permission.FOREGROUND_SERVICE_MICROPHONE,
                requestCode = REQUEST_CODE_MICROPHONE_FOREGROUND,
            ) {
                Log.d(TAG, "Microphone foreground permission result: $it")
            }
        }
    }

    private fun requestPermission(
        name: String,
        description: String,
        manifestPermission: String,
        requestCode: Int,
        onResult: (Boolean) -> Unit,
    ) {
        val activity = state.activity ?: run {
            onResult(false)
            return
        }
        if (activity.checkPermission(manifestPermission)) {
            onResult(true)
            return
        }

        state.permissionResultHandler[requestCode] = onResult
        if (ActivityCompat.shouldShowRequestPermissionRationale(activity, manifestPermission)) {
            val clickListener = DialogInterface.OnClickListener { _, _ ->
                ActivityCompat.requestPermissions(activity, arrayOf(manifestPermission), requestCode)
            }
            AlertDialog.Builder(activity)
                .setTitle("$name Permissions")
                .setMessage(description)
                .setPositiveButton(R.string.proceed, clickListener)
                .setNegativeButton(R.string.cancel) { _, _ ->
                    state.permissionResultHandler.remove(requestCode)
                    onResult(false)
                }
                .show()
        } else {
            ActivityCompat.requestPermissions(activity, arrayOf(manifestPermission), requestCode)
        }
    }

    @Suppress("unused")
    private fun throwNotInitialized(): Nothing =
        throw FlutterTwilioError.of("not_initialized", "Plugin not attached to Flutter engine")
}
