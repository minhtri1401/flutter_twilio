package com.dev.flutter_twilio.audio

import android.media.AudioDeviceInfo
import com.dev.flutter_twilio.generated.AudioRoute
import org.junit.Assert.assertEquals
import org.junit.Test

class TVAudioRouteMapperTest {

    @Test
    fun `built-in earpiece maps to earpiece`() {
        assertEquals(AudioRoute.EARPIECE,
            TVAudioRouteMapper.fromDeviceType(AudioDeviceInfo.TYPE_BUILTIN_EARPIECE))
    }

    @Test
    fun `built-in speaker maps to speaker`() {
        assertEquals(AudioRoute.SPEAKER,
            TVAudioRouteMapper.fromDeviceType(AudioDeviceInfo.TYPE_BUILTIN_SPEAKER))
    }

    @Test
    fun `bluetooth SCO and A2DP map to bluetooth`() {
        assertEquals(AudioRoute.BLUETOOTH,
            TVAudioRouteMapper.fromDeviceType(AudioDeviceInfo.TYPE_BLUETOOTH_SCO))
        assertEquals(AudioRoute.BLUETOOTH,
            TVAudioRouteMapper.fromDeviceType(AudioDeviceInfo.TYPE_BLUETOOTH_A2DP))
    }

    @Test
    fun `wired headset, USB headset, USB device, line, HDMI map to wired`() {
        for (t in intArrayOf(
            AudioDeviceInfo.TYPE_WIRED_HEADSET,
            AudioDeviceInfo.TYPE_WIRED_HEADPHONES,
            AudioDeviceInfo.TYPE_USB_HEADSET,
            AudioDeviceInfo.TYPE_USB_DEVICE,
            AudioDeviceInfo.TYPE_LINE_ANALOG,
            AudioDeviceInfo.TYPE_LINE_DIGITAL,
            AudioDeviceInfo.TYPE_HDMI,
        )) {
            assertEquals("type=$t", AudioRoute.WIRED, TVAudioRouteMapper.fromDeviceType(t))
        }
    }

    @Test
    fun `unknown type defaults to earpiece (safe fallback)`() {
        assertEquals(AudioRoute.EARPIECE, TVAudioRouteMapper.fromDeviceType(-1))
    }
}
