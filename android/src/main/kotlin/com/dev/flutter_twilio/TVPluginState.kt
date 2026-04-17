package com.dev.flutter_twilio

import android.app.Activity
import android.content.Context
import com.dev.flutter_twilio.storage.Storage
import java.util.concurrent.ConcurrentHashMap

class TVPluginState {
    var context: Context? = null
    var activity: Activity? = null
    var storage: Storage? = null
    var accessToken: String? = null
    var fcmToken: String? = null

    @Volatile var isSpeakerOn: Boolean = false
    @Volatile var isBluetoothOn: Boolean = false
    @Volatile var isMuted: Boolean = false
    @Volatile var isHolding: Boolean = false

    val permissionResultHandler: MutableMap<Int, (Boolean) -> Unit> = ConcurrentHashMap()
}
