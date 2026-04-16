package com.twilio.twilio_voice.service

import android.content.Context
import android.media.AudioDeviceInfo
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.os.Build
import android.util.Log

class TVAudioManager(context: Context) {
    private val TAG = "TVAudioManager"
    private val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
    private var focusRequest: AudioFocusRequest? = null

    var isSpeakerOn: Boolean = false
        private set
    var isBluetoothOn: Boolean = false
        private set

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
            audioManager.requestAudioFocus(null, AudioManager.STREAM_VOICE_CALL, AudioManager.AUDIOFOCUS_GAIN)
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

    fun setSpeaker(on: Boolean) {
        Log.d(TAG, "setSpeaker: $on")
        audioManager.isSpeakerphoneOn = on
        isSpeakerOn = on
        if (on) {
            if (isBluetoothOn) setBluetooth(false)
        }
    }

    fun setBluetooth(on: Boolean) {
        Log.d(TAG, "setBluetooth: $on")
        if (on) {
            audioManager.startBluetoothSco()
            audioManager.isBluetoothScoOn = true
            isBluetoothOn = true
            if (isSpeakerOn) setSpeaker(false)
        } else {
            audioManager.stopBluetoothSco()
            audioManager.isBluetoothScoOn = false
            isBluetoothOn = false
        }
    }

    fun hasBluetoothDevice(): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val devices = audioManager.getDevices(AudioManager.GET_DEVICES_ALL)
            return devices.any {
                it.type == AudioDeviceInfo.TYPE_BLUETOOTH_SCO || it.type == AudioDeviceInfo.TYPE_BLUETOOTH_A2DP
            }
        }
        return false
    }

    fun reset() {
        if (isBluetoothOn) setBluetooth(false)
        if (isSpeakerOn) setSpeaker(false)
    }
}
