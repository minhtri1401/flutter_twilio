package com.dev.flutter_twilio.audio

import android.media.AudioDeviceInfo
import android.media.AudioManager
import com.dev.flutter_twilio.generated.AudioRoute
import com.dev.flutter_twilio.generated.AudioRouteInfo

object TVAudioRouteMapper {

    fun fromDeviceType(type: Int): AudioRoute = when (type) {
        AudioDeviceInfo.TYPE_BUILTIN_EARPIECE -> AudioRoute.EARPIECE
        AudioDeviceInfo.TYPE_BUILTIN_SPEAKER -> AudioRoute.SPEAKER
        AudioDeviceInfo.TYPE_BLUETOOTH_SCO,
        AudioDeviceInfo.TYPE_BLUETOOTH_A2DP -> AudioRoute.BLUETOOTH
        AudioDeviceInfo.TYPE_WIRED_HEADSET,
        AudioDeviceInfo.TYPE_WIRED_HEADPHONES,
        AudioDeviceInfo.TYPE_USB_HEADSET,
        AudioDeviceInfo.TYPE_USB_DEVICE,
        AudioDeviceInfo.TYPE_LINE_ANALOG,
        AudioDeviceInfo.TYPE_LINE_DIGITAL,
        AudioDeviceInfo.TYPE_HDMI -> AudioRoute.WIRED
        else -> AudioRoute.EARPIECE
    }

    /// Reads the current routing from AudioManager. Prefers BT (when SCO is on)
    /// > wired headset > built-in speaker > built-in earpiece.
    fun currentRoute(audioManager: AudioManager): AudioRoute {
        if (audioManager.isBluetoothScoOn) return AudioRoute.BLUETOOTH
        val devices = audioManager.getDevices(AudioManager.GET_DEVICES_OUTPUTS)
        for (d in devices) {
            if (d.type in arrayOf(
                AudioDeviceInfo.TYPE_WIRED_HEADSET,
                AudioDeviceInfo.TYPE_WIRED_HEADPHONES,
                AudioDeviceInfo.TYPE_USB_HEADSET,
                AudioDeviceInfo.TYPE_USB_DEVICE,
                AudioDeviceInfo.TYPE_LINE_ANALOG,
                AudioDeviceInfo.TYPE_LINE_DIGITAL,
                AudioDeviceInfo.TYPE_HDMI,
            )) return AudioRoute.WIRED
        }
        if (audioManager.isSpeakerphoneOn) return AudioRoute.SPEAKER
        return AudioRoute.EARPIECE
    }

    /// Builds the full availability list for `listAudioRoutes()`.
    fun listAvailable(audioManager: AudioManager): List<AudioRouteInfo> {
        val current = currentRoute(audioManager)
        val devices = audioManager.getDevices(AudioManager.GET_DEVICES_OUTPUTS)

        var btName: String? = null
        var wiredName: String? = null
        var hasBt = false
        var hasWired = false

        for (d in devices) {
            when (d.type) {
                AudioDeviceInfo.TYPE_BLUETOOTH_SCO,
                AudioDeviceInfo.TYPE_BLUETOOTH_A2DP -> {
                    hasBt = true
                    if (btName == null) btName = d.productName?.toString()
                }
                AudioDeviceInfo.TYPE_WIRED_HEADSET,
                AudioDeviceInfo.TYPE_WIRED_HEADPHONES,
                AudioDeviceInfo.TYPE_USB_HEADSET,
                AudioDeviceInfo.TYPE_USB_DEVICE,
                AudioDeviceInfo.TYPE_LINE_ANALOG,
                AudioDeviceInfo.TYPE_LINE_DIGITAL,
                AudioDeviceInfo.TYPE_HDMI -> {
                    hasWired = true
                    if (wiredName == null) wiredName = d.productName?.toString()
                }
            }
        }

        val out = mutableListOf<AudioRouteInfo>()
        out += AudioRouteInfo(AudioRoute.EARPIECE, current == AudioRoute.EARPIECE, null)
        out += AudioRouteInfo(AudioRoute.SPEAKER, current == AudioRoute.SPEAKER, null)
        if (hasBt) out += AudioRouteInfo(AudioRoute.BLUETOOTH, current == AudioRoute.BLUETOOTH, btName)
        if (hasWired) out += AudioRouteInfo(AudioRoute.WIRED, current == AudioRoute.WIRED, wiredName)
        return out
    }
}
