package com.safepath.mobile

import android.app.PendingIntent
import android.os.Build

// Play Services fills in transition extras; the explicit receiver stays non-exported.
internal fun geofencePendingIntentFlags(apiLevel: Int): Int =
    PendingIntent.FLAG_UPDATE_CURRENT or
        if (apiLevel >= Build.VERSION_CODES.S) PendingIntent.FLAG_MUTABLE else 0
