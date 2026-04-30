package com.dev.flutter_twilio.notification

import android.app.NotificationManager
import android.os.Build
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [Build.VERSION_CODES.O])
class TVNotificationChannelsTest {

    @Test
    fun `register installs both channels with correct importance`() {
        val ctx = RuntimeEnvironment.getApplication()
        TVNotificationChannels.register(ctx)
        val mgr = ctx.getSystemService(NotificationManager::class.java)
        val incoming = mgr.getNotificationChannel(TVNotificationChannels.INCOMING_CALL_ID)
        val missed = mgr.getNotificationChannel(TVNotificationChannels.MISSED_CALL_ID)
        assertNotNull(incoming)
        assertNotNull(missed)
        assertEquals(NotificationManager.IMPORTANCE_HIGH, incoming.importance)
        assertEquals(NotificationManager.IMPORTANCE_DEFAULT, missed.importance)
    }

    @Test
    fun `register is idempotent`() {
        val ctx = RuntimeEnvironment.getApplication()
        TVNotificationChannels.register(ctx)
        TVNotificationChannels.register(ctx)
        val mgr = ctx.getSystemService(NotificationManager::class.java)
        assertNotNull(mgr.getNotificationChannel(TVNotificationChannels.INCOMING_CALL_ID))
    }
}
