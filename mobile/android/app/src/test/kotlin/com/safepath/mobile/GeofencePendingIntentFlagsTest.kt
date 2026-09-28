package com.safepath.mobile

import android.app.PendingIntent
import org.junit.Assert.assertEquals
import org.junit.Test

class GeofencePendingIntentFlagsTest {
    @Test
    fun android11AndEarlierAllowTransitionExtras() {
        for (api in listOf(23, 29, 30)) {
            val flags = geofencePendingIntentFlags(api)
            assertEquals(PendingIntent.FLAG_UPDATE_CURRENT, flags)
            assertEquals(0, flags and PendingIntent.FLAG_IMMUTABLE)
        }
    }

    @Test
    fun android12AndLaterExplicitlyRequestMutableCallback() {
        for (api in listOf(31, 35, 36)) {
            val flags = geofencePendingIntentFlags(api)
            assertEquals(PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE, flags)
            assertEquals(0, flags and PendingIntent.FLAG_IMMUTABLE)
        }
    }
}
