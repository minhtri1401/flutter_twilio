package com.dev.flutter_twilio.audio

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.media.AudioDeviceInfo
import android.media.AudioManager
import android.os.Build
import android.util.Log
import com.dev.flutter_twilio.FlutterTwilioError
import com.dev.flutter_twilio.generated.AudioRoute
import com.dev.flutter_twilio.generated.AudioRouteInfo

class TVAudioRouter(private val context: Context) {

    private val TAG = "TVAudioRouter"
    private val audioManager =
        context.getSystemService(Context.AUDIO_SERVICE) as AudioManager

    fun current(): AudioRoute = TVAudioRouteMapper.currentRoute(audioManager)

    fun list(): List<AudioRouteInfo> = TVAudioRouteMapper.listAvailable(audioManager)

    @Throws(Exception::class)
    fun set(route: AudioRoute) {
        Log.d(TAG, "setAudioRoute: $route")
        when (route) {
            AudioRoute.EARPIECE -> {
                stopSco()
                audioManager.isSpeakerphoneOn = false
            }
            AudioRoute.SPEAKER -> {
                stopSco()
                audioManager.isSpeakerphoneOn = true
            }
            AudioRoute.BLUETOOTH -> {
                if (!hasBluetoothPermission()) {
                    throw FlutterTwilioError.bluetoothUnavailable(
                        "BLUETOOTH_CONNECT permission not granted")
                }
                if (!hasBluetoothDevice()) {
                    throw FlutterTwilioError.bluetoothUnavailable(
                        "No Bluetooth audio device connected")
                }
                audioManager.isSpeakerphoneOn = false
                try {
                    audioManager.startBluetoothSco()
                    audioManager.isBluetoothScoOn = true
                } catch (t: Throwable) {
                    throw FlutterTwilioError.audioRouteFailed(
                        "Failed to start Bluetooth SCO: ${t.message}")
                }
            }
            AudioRoute.WIRED -> {
                if (!hasWiredDevice()) {
                    throw FlutterTwilioError.wiredUnavailable(
                        "No wired audio device connected")
                }
                stopSco()
                audioManager.isSpeakerphoneOn = false
            }
        }
    }

    private fun stopSco() {
        if (audioManager.isBluetoothScoOn) {
            try {
                audioManager.isBluetoothScoOn = false
                audioManager.stopBluetoothSco()
            } catch (t: Throwable) {
                Log.w(TAG, "stopBluetoothSco failed", t)
            }
        }
    }

    private fun hasBluetoothPermission(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return true
        return context.checkSelfPermission(Manifest.permission.BLUETOOTH_CONNECT) ==
                PackageManager.PERMISSION_GRANTED
    }

    private fun hasBluetoothDevice(): Boolean {
        val devices = audioManager.getDevices(AudioManager.GET_DEVICES_OUTPUTS)
        return devices.any {
            it.type == AudioDeviceInfo.TYPE_BLUETOOTH_SCO ||
                    it.type == AudioDeviceInfo.TYPE_BLUETOOTH_A2DP
        }
    }

    private fun hasWiredDevice(): Boolean {
        val devices = audioManager.getDevices(AudioManager.GET_DEVICES_OUTPUTS)
        return devices.any {
            it.type in arrayOf(
                AudioDeviceInfo.TYPE_WIRED_HEADSET,
                AudioDeviceInfo.TYPE_WIRED_HEADPHONES,
                AudioDeviceInfo.TYPE_USB_HEADSET,
                AudioDeviceInfo.TYPE_USB_DEVICE,
                AudioDeviceInfo.TYPE_LINE_ANALOG,
                AudioDeviceInfo.TYPE_LINE_DIGITAL,
                AudioDeviceInfo.TYPE_HDMI,
            )
        }
    }
}
