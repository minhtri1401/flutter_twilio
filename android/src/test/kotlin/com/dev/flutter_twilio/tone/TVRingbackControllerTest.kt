package com.dev.flutter_twilio.tone

import org.junit.Assert.assertEquals
import org.junit.Test

class TVRingbackControllerTest {

    private class FakeTone : TVTonePlayerLike {
        var startCount = 0
        var stopCount = 0
        override fun play(
            flutterAssetKey: String?,
            bundledAssetPath: String,
            looping: Boolean,
            forSignalling: Boolean,
        ) { startCount++ }
        override fun stop() { stopCount++ }
    }

    @Test
    fun `outgoing connecting starts then connected stops`() {
        val tone = FakeTone()
        val ctrl = TVRingbackController(tone, enabled = true, customAssetKey = null)
        ctrl.onCallEvent(CallPhase.OUTGOING_CONNECTING)
        ctrl.onCallEvent(CallPhase.CONNECTED)
        assertEquals(1, tone.startCount)
        assertEquals(1, tone.stopCount)
    }

    @Test
    fun `outgoing disconnect mid-ring stops without starting again`() {
        val tone = FakeTone()
        val ctrl = TVRingbackController(tone, enabled = true, customAssetKey = null)
        ctrl.onCallEvent(CallPhase.OUTGOING_CONNECTING)
        ctrl.onCallEvent(CallPhase.DISCONNECTED)
        assertEquals(1, tone.startCount)
        assertEquals(1, tone.stopCount)
    }

    @Test
    fun `incoming connecting never starts`() {
        val tone = FakeTone()
        val ctrl = TVRingbackController(tone, enabled = true, customAssetKey = null)
        ctrl.onCallEvent(CallPhase.INCOMING_RINGING)
        ctrl.onCallEvent(CallPhase.CONNECTED)
        assertEquals(0, tone.startCount)
    }

    @Test
    fun `disabled controller never starts`() {
        val tone = FakeTone()
        val ctrl = TVRingbackController(tone, enabled = false, customAssetKey = null)
        ctrl.onCallEvent(CallPhase.OUTGOING_CONNECTING)
        assertEquals(0, tone.startCount)
    }
}
