package com.dev.flutter_twilio.service

import android.content.Context
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.os.Build
import android.util.Log
import com.dev.flutter_twilio.audio.TVAudioRouter
import com.dev.flutter_twilio.generated.AudioRoute

/**
 * Audio focus + mode helper. Routing has moved to [TVAudioRouter] —
 * this class now only owns AUDIOFOCUS_GAIN + MODE_IN_COMMUNICATION.
 */
class TVAudioManager(context: Context) {
    private val TAG = "TVAudioManager"
    private val audioManager =
        context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
    private val router = TVAudioRouter(context)
    private var focusRequest: AudioFocusRequest? = null

    fun requestAudioFocus() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            focusRequest = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN)
                .setAudioAttributes(
                    android.media.AudioAttributes.Builder()
                        .setUsage(android.media.AudioAttributes.USAGE_VOICE_COMMUNICATION)
                        .setContentType(android.media.AudioAttributes.CONTENT_TYPE_SPEECH)
                        .build()
                )
                .build()
            audioManager.requestAudioFocus(focusRequest!!)
        } else {
            @Suppress("DEPRECATION")
            audioManager.requestAudioFocus(
                null, AudioManager.STREAM_VOICE_CALL,
                AudioManager.AUDIOFOCUS_GAIN,
            )
        }
        audioManager.mode = AudioManager.MODE_IN_COMMUNICATION
    }

    fun abandonAudioFocus() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            focusRequest?.let { audioManager.abandonAudioFocusRequest(it) }
            focusRequest = null
        } else {
            @Suppress("DEPRECATION")
            audioManager.abandonAudioFocus(null)
        }
        audioManager.mode = AudioManager.MODE_NORMAL
    }

    fun reset() {
        try { router.set(AudioRoute.EARPIECE) } catch (t: Throwable) {
            Log.w(TAG, "reset routing failed", t)
        }
    }
}
