package com.safepath.mobile

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import com.google.android.gms.location.Geofence
import com.google.android.gms.location.GeofencingEvent
import java.util.UUID

/** Receives routine Play Services transitions; it does not start any service. */
class GeofenceBroadcastReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val event = GeofencingEvent.fromIntent(intent) ?: return
        if (event.hasError() && event.errorCode == GEOFENCE_NOT_AVAILABLE) {
            // Play Services can temporarily lose geofence availability. Do not
            // persist an un-uploadable pseudo-candidate: request the normal
            // authenticated canonical replacement on the next app bootstrap.
            GeofenceBootReceiver.markCanonicalResync(context.applicationContext)
            return
        }
        val occurredAt = System.currentTimeMillis()
        val location = event.triggeringLocation
        val transition = when (event.geofenceTransition) {
            Geofence.GEOFENCE_TRANSITION_ENTER -> "enter"
            Geofence.GEOFENCE_TRANSITION_EXIT -> "exit"
            else -> "error"
        }
        val requestIds = event.triggeringGeofences?.map { it.requestId }.orEmpty()
        val ids = if (requestIds.isEmpty()) listOf("") else requestIds
        val store = GeofenceNativeStore(context.applicationContext)
        ids.forEach { requestId ->
            if (store.persist(
                GeofenceNativeStore.Candidate(
                    eventId = UUID.randomUUID().toString(),
                    requestId = requestId,
                    transition = transition,
                    occurredAtEpochMs = occurredAt,
                    latitude = location?.latitude,
                    longitude = location?.longitude,
                    accuracyMeters = location?.accuracy?.toDouble(),
                    errorCode = event.errorCode.takeIf { event.hasError() }
                )
            )) {
                GeofenceUploadWorker.enqueue(context.applicationContext)
            }
        }
    }

    private companion object {
        const val GEOFENCE_NOT_AVAILABLE = 1000
    }
}
