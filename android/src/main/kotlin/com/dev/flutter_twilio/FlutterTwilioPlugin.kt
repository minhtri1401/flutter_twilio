package com.dev.flutter_twilio

import android.util.Log
import com.dev.flutter_twilio.generated.ActiveCallDto
import com.dev.flutter_twilio.generated.AudioRoute
import com.dev.flutter_twilio.generated.AudioRouteInfo
import com.dev.flutter_twilio.generated.CallDirection
import com.dev.flutter_twilio.generated.FlutterError
import com.dev.flutter_twilio.generated.PlaceCallRequest
import com.dev.flutter_twilio.generated.VoiceConfig
import com.dev.flutter_twilio.generated.VoiceFlutterApi
import com.dev.flutter_twilio.generated.VoiceHostApi
import com.dev.flutter_twilio.audio.TVAudioRouteListener
import com.dev.flutter_twilio.audio.TVAudioRouter
import com.dev.flutter_twilio.generated.CallEventType
import com.dev.flutter_twilio.handler.TVAudioMethodHandler
import com.dev.flutter_twilio.handler.TVCallMethodHandler
import com.dev.flutter_twilio.handler.TVPermissionMethodHandler
import com.dev.flutter_twilio.handler.TVRegistrationMethodHandler
import com.dev.flutter_twilio.service.TVCallManager
import com.dev.flutter_twilio.service.VoiceConfigLocal
import com.dev.flutter_twilio.storage.StorageImpl
import com.dev.flutter_twilio.tone.TVTonePlayer
import com.twilio.voice.CallException
import com.twilio.voice.RegistrationException
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.FlutterPlugin.FlutterPluginBinding
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.PluginRegistry.RequestPermissionsResultListener

/**
 * Entry point for the `flutter_twilio` Android plugin.
 *
 * Implements the Pigeon-generated [VoiceHostApi] and delegates each typed
 * method to a single-purpose handler. All errors are translated via
 * [FlutterTwilioError] so Dart observers receive the stable codes documented
 * in the spec.
 *
 * Asynchronous call-lifecycle events are pushed back to Dart via the
 * [VoiceFlutterApi] installed on [TVEventEmitter] — never via an
 * [io.flutter.plugin.common.EventChannel].
 */
class FlutterTwilioPlugin :
    FlutterPlugin,
    ActivityAware,
    RequestPermissionsResultListener,
    VoiceHostApi {

    companion object {
        private const val TAG = "FlutterTwilioPlugin"
    }

    private val state = TVPluginState()
    private val emitter = TVEventEmitter()
    private val callEventsReceiver = TVCallEventsReceiver(state, emitter)

    private lateinit var callHandler: TVCallMethodHandler
    private lateinit var audioHandler: TVAudioMethodHandler
    private lateinit var permissionHandler: TVPermissionMethodHandler
    private lateinit var registrationHandler: TVRegistrationMethodHandler
    private lateinit var audioRouter: TVAudioRouter
    private var audioRouteListener: TVAudioRouteListener? = null

    private var flutterApi: VoiceFlutterApi? = null

    override fun onAttachedToEngine(binding: FlutterPluginBinding) {
        val context = binding.applicationContext
        state.context = context
        state.storage = StorageImpl(context)

        val messenger = binding.binaryMessenger
        VoiceHostApi.setUp(messenger, this)
        flutterApi = VoiceFlutterApi(messenger).also { emitter.attach(it) }

        audioRouter = TVAudioRouter(context)
        callHandler = TVCallMethodHandler(state, emitter)
        audioHandler = TVAudioMethodHandler(state, emitter, audioRouter)
        permissionHandler = TVPermissionMethodHandler(state, emitter)
        registrationHandler = TVRegistrationMethodHandler(state, emitter)

        TVCallManager.init(context)
        TVCallManager.applyConfig(
            VoiceConfigLocal.default,
            TVTonePlayer(context),
            TVTonePlayer(context),
            TVTonePlayer(context),
        )
        TVCallManager.listener = callEventsReceiver

        ActiveCallSnapshotter.provider = { snapshotActiveCall() }

        audioRouteListener = TVAudioRouteListener(context).apply {
            start { route ->
                emitter.emit(CallEventType.AUDIO_ROUTE_CHANGED, audioRoute = route)
            }
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPluginBinding) {
        Log.d(TAG, "onDetachedFromEngine")
        VoiceHostApi.setUp(binding.binaryMessenger, null)
        audioRouteListener?.stop()
        audioRouteListener = null
        emitter.detach()
        flutterApi = null
        TVCallManager.listener = null
        ActiveCallSnapshotter.provider = null
        state.context = null
    }

    // region ActivityAware

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        state.activity = binding.activity
        binding.addRequestPermissionsResultListener(this)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        state.activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        state.activity = binding.activity
        binding.addRequestPermissionsResultListener(this)
    }

    override fun onDetachedFromActivity() {
        state.activity = null
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<String>,
        grantResults: IntArray,
    ): Boolean = permissionHandler.onPermissionsResult(requestCode, permissions, grantResults)

    // endregion

    // region VoiceHostApi

    override fun setAccessToken(token: String, callback: (Result<Unit>) -> Unit) =
        guard(callback) { registrationHandler.setAccessToken(token) }

    override fun register(callback: (Result<Unit>) -> Unit) =
        guard(callback) { registrationHandler.register() }

    override fun unregister(callback: (Result<Unit>) -> Unit) =
        guard(callback) { registrationHandler.unregister() }

    override fun place(request: PlaceCallRequest, callback: (Result<ActiveCallDto>) -> Unit) =
        guard(callback) {
            val extra: Map<String, String> = request.extraParameters
                ?.filter { (k, v) -> k != null && v != null }
                ?.mapKeys { (k, _) -> k!! }
                ?.mapValues { (_, v) -> v!! }
                ?: emptyMap()
            callHandler.place(to = request.to, from = request.from, extra = extra)
            snapshotActiveCall()
                ?: throw FlutterTwilioError.of(
                    "connection_error",
                    "Outgoing call placed but no active-call snapshot is available",
                )
        }

    override fun answer(callback: (Result<Unit>) -> Unit) =
        guard(callback) { callHandler.answer() }

    override fun reject(callback: (Result<Unit>) -> Unit) =
        guard(callback) { callHandler.reject() }

    override fun hangUp(callback: (Result<Unit>) -> Unit) =
        guard(callback) { callHandler.hangUp() }

    override fun setMuted(muted: Boolean, callback: (Result<Unit>) -> Unit) =
        guard(callback) { callHandler.setMuted(muted) }

    override fun setOnHold(onHold: Boolean, callback: (Result<Unit>) -> Unit) =
        guard(callback) { callHandler.setOnHold(onHold) }

    override fun setSpeaker(onSpeaker: Boolean, callback: (Result<Unit>) -> Unit) =
        guard(callback) { audioHandler.setSpeakerLegacy(onSpeaker) }

    override fun sendDigits(digits: String, callback: (Result<Unit>) -> Unit) =
        guard(callback) { callHandler.sendDigits(digits) }

    override fun getActiveCall(callback: (Result<ActiveCallDto?>) -> Unit) =
        guard(callback) { snapshotActiveCall() }

    override fun hasMicPermission(callback: (Result<Boolean>) -> Unit) =
        guard(callback) { permissionHandler.hasMicPermission() }

    override fun requestMicPermission(callback: (Result<Boolean>) -> Unit) {
        try {
            permissionHandler.requestMicPermission { granted ->
                callback(Result.success(granted))
            }
        } catch (t: Throwable) {
            callback(Result.failure(mapError(t)))
        }
    }

    override fun configure(config: VoiceConfig, callback: (Result<Unit>) -> Unit) =
        guard(callback) { /* TODO(Task 22): apply VoiceConfig */ }

    override fun setAudioRoute(route: AudioRoute, callback: (Result<Unit>) -> Unit) =
        guard(callback) { audioHandler.setAudioRoute(route) }

    override fun getAudioRoute(callback: (Result<AudioRoute>) -> Unit) =
        guard(callback) { audioHandler.getAudioRoute() }

    override fun listAudioRoutes(callback: (Result<List<AudioRouteInfo>>) -> Unit) =
        guard(callback) { audioHandler.listAudioRoutes() }

    override fun bringAppToForeground(callback: (Result<Unit>) -> Unit) =
        guard(callback) {
            throw FlutterTwilioError.of("not_initialized", "bringAppToForeground not yet wired")
        }

    // endregion

    // region Helpers

    private inline fun <T> guard(
        noinline cb: (Result<T>) -> Unit,
        crossinline body: () -> T,
    ) {
        try {
            cb(Result.success(body()))
        } catch (t: Throwable) {
            cb(Result.failure(mapError(t)))
        }
    }

    private fun mapError(t: Throwable): Throwable = when (t) {
        is FlutterError -> t
        is CallException -> FlutterTwilioError.fromTwilio(t)
        is RegistrationException -> FlutterTwilioError.fromRegistration(t)
        else -> FlutterTwilioError.unknown(t)
    }

    /**
     * Build an [ActiveCallDto] from the current [TVCallManager] snapshot,
     * or `null` when no call is active or pending.
     */
    private fun snapshotActiveCall(): ActiveCallDto? {
        if (!TVCallManager.hasActiveCall()) return null
        val sid = TVCallManager.getActiveCallSid() ?: "unknown"
        val direction = when (TVCallManager.callDirection) {
            com.dev.flutter_twilio.types.CallDirection.INCOMING -> CallDirection.INCOMING
            com.dev.flutter_twilio.types.CallDirection.OUTGOING -> CallDirection.OUTGOING
        }
        val custom: Map<String?, String?> = TVCallManager.activeCustomParameters
            .mapKeys { (k, _) -> k as String? }
            .mapValues { (_, v) -> v as String? }
        return ActiveCallDto(
            sid = sid,
            from = TVCallManager.activeCallFrom,
            to = TVCallManager.activeCallTo,
            direction = direction,
            startedAt = TVCallManager.callStartedAtMillis,
            isMuted = state.isMuted,
            isOnHold = state.isHolding,
            isOnSpeaker = state.isSpeakerOn,
            currentRoute = audioRouter.current(),
            connectedAt = TVCallManager.connectedAtMillis,
            customParameters = custom,
        )
    }

    // endregion
}
