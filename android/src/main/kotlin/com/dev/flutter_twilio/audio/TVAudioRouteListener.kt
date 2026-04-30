package com.dev.flutter_twilio.audio

import android.content.Context
import android.media.AudioDeviceCallback
import android.media.AudioDeviceInfo
import android.media.AudioManager
import android.os.Handler
import android.os.Looper
import com.dev.flutter_twilio.generated.AudioRoute

/**
 * Watches the system for audio device additions/removals and notifies callers
 * with the new derived [AudioRoute]. Caller is responsible for emitting the
 * Pigeon event.
 */
class TVAudioRouteListener(context: Context) {

    private val audioManager =
        context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
    private val handler = Handler(Looper.getMainLooper())
    private var callback: AudioDeviceCallback? = null

    fun start(onChanged: (AudioRoute) -> Unit) {
        if (callback != null) return
        val cb = object : AudioDeviceCallback() {
            override fun onAudioDevicesAdded(addedDevices: Array<out AudioDeviceInfo>) {
                onChanged(TVAudioRouteMapper.currentRoute(audioManager))
            }
            override fun onAudioDevicesRemoved(removedDevices: Array<out AudioDeviceInfo>) {
                onChanged(TVAudioRouteMapper.currentRoute(audioManager))
            }
        }
        audioManager.registerAudioDeviceCallback(cb, handler)
        callback = cb
    }

    fun stop() {
        callback?.let { audioManager.unregisterAudioDeviceCallback(it) }
        callback = null
    }
}
