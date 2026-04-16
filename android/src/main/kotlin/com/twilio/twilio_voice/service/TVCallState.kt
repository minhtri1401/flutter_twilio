package com.twilio.twilio_voice.service

import com.twilio.twilio_voice.types.CallDirection

data class TVCallState(
    val callSid: String = "",
    val from: String = "",
    val to: String = "",
    val direction: CallDirection = CallDirection.INCOMING,
    val isMuted: Boolean = false,
    val isOnHold: Boolean = false,
    val isSpeakerOn: Boolean = false,
    val isBluetoothOn: Boolean = false
)
