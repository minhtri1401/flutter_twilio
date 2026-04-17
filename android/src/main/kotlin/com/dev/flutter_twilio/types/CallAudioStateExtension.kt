package com.dev.flutter_twilio.types

import android.telecom.CallAudioState

object CallAudioStateExtension {
    fun CallAudioState.copyWith(muted: Boolean): CallAudioState {
        return CallAudioState(muted ?: this.isMuted, route ?: this.route, supportedRouteMask ?: this.supportedRouteMask)
    }

    fun CallAudioState.copyWith(route: Int): CallAudioState {
        return CallAudioState(this.isMuted, route , this.supportedRouteMask)
    }
}