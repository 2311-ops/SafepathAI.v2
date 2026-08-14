package com.safepath.mobile

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * Records a bounded routine-geofence recovery signal after OS lifecycle loss.
 *
 * The normal authenticated Flutter bootstrap already owns canonical replacement
 * of monitored zones. This receiver intentionally only records that a
 * replacement is due and retries the credential-free candidate outbox; it
 * neither holds credentials nor starts location or SOS services.
 */
class GeofenceBootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED -> {
                markCanonicalResync(context.applicationContext)
                GeofenceUploadWorker.enqueue(context.applicationContext)
            }
        }
    }

    companion object {
        private const val PREFERENCES = "safepath_geofence_recovery"
        private const val KEY_RESYNC_REQUESTED_AT = "canonical_resync_requested_at"

        /** Durable, bounded marker; it contains no location or auth material. */
        fun markCanonicalResync(context: Context) {
            context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)
                .edit()
                .putLong(KEY_RESYNC_REQUESTED_AT, System.currentTimeMillis())
                .apply()
        }
    }
}
