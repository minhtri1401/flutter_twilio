package com.dev.flutter_twilio.service

import com.dev.flutter_twilio.types.CallDirection

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
