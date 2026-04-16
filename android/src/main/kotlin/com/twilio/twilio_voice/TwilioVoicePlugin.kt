package com.twilio.twilio_voice

import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.util.Log
import androidx.localbroadcastmanager.content.LocalBroadcastManager
import com.twilio.twilio_voice.handler.TVAudioMethodHandler
import com.twilio.twilio_voice.handler.TVCallMethodHandler
import com.twilio.twilio_voice.handler.TVConfigMethodHandler
import com.twilio.twilio_voice.handler.TVPermissionMethodHandler
import com.twilio.twilio_voice.handler.TVRegistrationMethodHandler
import com.twilio.twilio_voice.receivers.TVBroadcastReceiver
import com.twilio.twilio_voice.service.TVCallManager
import com.twilio.twilio_voice.storage.StorageImpl
import com.twilio.twilio_voice.types.TVMethodChannels
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.FlutterPlugin.FlutterPluginBinding
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.EventChannel.EventSink
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.PluginRegistry.NewIntentListener
import io.flutter.plugin.common.PluginRegistry.RequestPermissionsResultListener

class TwilioVoicePlugin : FlutterPlugin, MethodCallHandler, EventChannel.StreamHandler,
    ActivityAware, NewIntentListener, RequestPermissionsResultListener {

    companion object {
        private const val TAG = "TwilioVoicePlugin"
        private const val kCHANNEL_NAME = "twilio_voice"
    }

    private val state = TVPluginState()
    private val emitter = TVEventEmitter()
    private val callEventsReceiver = TVCallEventsReceiver(state, emitter)

    private lateinit var callHandler: TVCallMethodHandler
    private lateinit var audioHandler: TVAudioMethodHandler
    private lateinit var permissionHandler: TVPermissionMethodHandler
    private lateinit var registrationHandler: TVRegistrationMethodHandler
    private lateinit var configHandler: TVConfigMethodHandler

    private var methodChannel: MethodChannel? = null
    private var eventChannel: EventChannel? = null
    private var broadcastReceiver: TVBroadcastReceiver? = null
    private var isReceiverRegistered = false

    private fun register(messenger: BinaryMessenger, context: Context) {
        state.context = context
        state.storage = StorageImpl(context)
        methodChannel = MethodChannel(messenger, "$kCHANNEL_NAME/messages").also {
            it.setMethodCallHandler(this)
        }
        eventChannel = EventChannel(messenger, "$kCHANNEL_NAME/events").also {
            it.setStreamHandler(this)
        }
        callHandler = TVCallMethodHandler(state, emitter)
        audioHandler = TVAudioMethodHandler(state, emitter)
        permissionHandler = TVPermissionMethodHandler(state, emitter)
        registrationHandler = TVRegistrationMethodHandler(state, emitter)
        configHandler = TVConfigMethodHandler(state, emitter)
        broadcastReceiver = TVBroadcastReceiver(this)
        TVCallManager.init(context)
        TVCallManager.listener = callEventsReceiver
    }

    override fun onAttachedToEngine(binding: FlutterPluginBinding) {
        register(binding.binaryMessenger, binding.applicationContext)
    }

    override fun onDetachedFromEngine(binding: FlutterPluginBinding) {
        Log.d(TAG, "Detached from Flutter engine")
        TVCallManager.listener = null
        state.context = null
        methodChannel?.setMethodCallHandler(null)
        methodChannel = null
        eventChannel?.setStreamHandler(null)
        eventChannel = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.arguments !is Map<*, *>) {
            result.error("MALFORMED_ARGUMENTS", "Arguments must be a Map<String, Object>", null)
            return
        }
        val method = TVMethodChannels.fromValue(call.method) ?: run {
            result.notImplemented()
            return
        }
        val handled = callHandler.handle(method, call, result) ||
            audioHandler.handle(method, call, result) ||
            permissionHandler.handle(method, call, result) ||
            registrationHandler.handle(method, call, result) ||
            configHandler.handle(method, call, result)
        if (!handled) result.notImplemented()
    }

    override fun onListen(arguments: Any?, events: EventSink?) {
        Log.i(TAG, "Setting event sink")
        emitter.sink = events
    }

    override fun onCancel(arguments: Any?) {
        Log.i(TAG, "Removing event sink")
        emitter.sink = null
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        Log.d(TAG, "onAttachedToActivity")
        state.activity = binding.activity
        binding.addOnNewIntentListener(this)
        binding.addRequestPermissionsResultListener(this)
        registerReceiver()
    }

    override fun onDetachedFromActivityForConfigChanges() {
        Log.d(TAG, "onDetachedFromActivityForConfigChanges")
        unregisterReceiver()
        state.activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        Log.d(TAG, "onReattachedToActivityForConfigChanges")
        state.activity = binding.activity
        binding.addRequestPermissionsResultListener(this)
        binding.addOnNewIntentListener(this)
        registerReceiver()
    }

    override fun onDetachedFromActivity() {
        Log.d(TAG, "onDetachedFromActivity")
        unregisterReceiver()
        state.activity = null
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<String>,
        grantResults: IntArray
    ): Boolean = permissionHandler.onPermissionsResult(requestCode, permissions, grantResults)

    override fun onNewIntent(intent: Intent): Boolean = false

    private fun registerReceiver() {
        if (isReceiverRegistered) return
        val ctx = state.context ?: return
        val receiver = broadcastReceiver ?: return
        val filter = IntentFilter().apply { addAction(TVBroadcastReceiver.ACTION_INCOMING_CALL_IGNORED) }
        LocalBroadcastManager.getInstance(ctx).registerReceiver(receiver, filter)
        isReceiverRegistered = true
    }

    private fun unregisterReceiver() {
        if (!isReceiverRegistered) return
        state.context?.let { ctx ->
            broadcastReceiver?.let { r ->
                LocalBroadcastManager.getInstance(ctx).unregisterReceiver(r)
            }
        }
        isReceiverRegistered = false
    }

    fun handleBroadcastIntent(intent: Intent) {
        when (intent.action) {
            TVBroadcastReceiver.ACTION_INCOMING_CALL_IGNORED -> {
                val reason = intent.getStringArrayExtra(TVBroadcastReceiver.EXTRA_INCOMING_CALL_IGNORED_REASON) ?: arrayOf()
                val handle = intent.getStringExtra(TVBroadcastReceiver.EXTRA_CALL_HANDLE) ?: "N/A"
                Log.w(TAG, "Incoming call ignored. Handle: $handle, Reasons: ${reason.joinToString()}")
            }
            else -> Log.d(TAG, "handleBroadcastIntent: unhandled action ${intent.action}")
        }
    }
}
