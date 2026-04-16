package com.twilio.twilio_voice

import android.util.Log
import com.twilio.twilio_voice.constants.FlutterErrorCodes
import io.flutter.plugin.common.EventChannel.EventSink

class TVEventEmitter {

    companion object { private const val TAG = "TVEventEmitter" }
    var sink: EventSink? = null

    fun logEvent(description: String) = logEvent("LOG", "|", description, false)

    fun logEvent(prefix: String, description: String) = logEvent(prefix, "|", description, false)

    fun logEvent(
        prefix: String = "LOG",
        separator: String = "|",
        description: String,
        isError: Boolean = false
    ) {
        val s = sink ?: return
        if (isError) {
            s.error(FlutterErrorCodes.UNAVAILABLE_ERROR, description, null)
        } else {
            val message = if (prefix.isEmpty()) description else "$prefix$separator$description"
            Log.d(TAG, "logEvent: $message")
            s.success(message)
        }
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
        logEvents(arrayOf("PERMISSION", permissionName, state.toString()))
    }
}
