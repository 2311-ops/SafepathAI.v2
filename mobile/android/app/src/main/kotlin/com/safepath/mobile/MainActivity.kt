package com.safepath.mobile

import android.Manifest
import android.app.PendingIntent
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import com.google.android.gms.common.ConnectionResult
import com.google.android.gms.common.GoogleApiAvailability
import com.google.android.gms.location.Geofence
import com.google.android.gms.location.GeofencingClient
import com.google.android.gms.location.GeofencingRequest
import com.google.android.gms.location.LocationServices
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private lateinit var geofencingClient: GeofencingClient
    private lateinit var nativeStore: GeofenceNativeStore

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        geofencingClient = LocationServices.getGeofencingClient(this)
        nativeStore = GeofenceNativeStore(applicationContext)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler(::onGeofencingMethod)
    }

    private fun onGeofencingMethod(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getCapability" -> result.success(mapOf("status" to capability()))
            "requestBackgroundCapability" -> {
                requestBackgroundCapability()
                // Android returns from the permission sheet asynchronously. The Flutter
                // save flow re-checks capability after the explicit user action.
                result.success(mapOf("status" to capability()))
            }
            "replaceMonitoredZones" -> replaceMonitoredZones(call, result)
            "drainPendingCandidates" -> result.success(
                nativeStore.drain().map { candidate ->
                    mapOf(
                        "eventId" to candidate.eventId,
                        "requestId" to candidate.requestId,
                        "transition" to candidate.transition,
                        "occurredAtEpochMs" to candidate.occurredAtEpochMs,
                        "latitude" to candidate.latitude,
                        "longitude" to candidate.longitude,
                        "accuracyMeters" to candidate.accuracyMeters,
                        "errorCode" to candidate.errorCode
                    )
                }
            )
            "acknowledgeCandidate" -> {
                val eventId = call.argument<String>("eventId")
                if (eventId.isNullOrBlank()) {
                    result.error("invalid_arguments", "eventId is required.", null)
                } else if (nativeStore.acknowledge(eventId)) {
                    result.success(null)
                } else {
                    result.error("outbox_write_failed", "Could not acknowledge candidate.", null)
                }
            }
            else -> result.notImplemented()
        }
    }

    private fun replaceMonitoredZones(call: MethodCall, result: MethodChannel.Result) {
        if (capability() != CAPABILITY_READY) {
            result.error("capability_unavailable", "Background location capability is not ready.", capability())
            return
        }
        val rawZones = call.argument<List<Map<String, Any?>>>("zones") ?: emptyList()
        if (rawZones.size > MAX_ZONES) {
            result.error("zone_limit", "Android supports at most $MAX_ZONES monitored zones.", null)
            return
        }
        val geofences = try {
            rawZones.map(::toGeofence)
        } catch (exception: IllegalArgumentException) {
            result.error("invalid_zone", exception.message, null)
            return
        }
        geofencingClient.removeGeofences(geofencePendingIntent)
            .addOnSuccessListener {
                if (geofences.isEmpty()) {
                    result.success(null)
                    return@addOnSuccessListener
                }
                val request = GeofencingRequest.Builder()
                    // Server-side confirmation owns dwell/hysteresis; do not
                    // create an initial enter event during replacement.
                    .setInitialTrigger(0)
                    .addGeofences(geofences)
                    .build()
                try {
                    geofencingClient.addGeofences(request, geofencePendingIntent)
                        .addOnSuccessListener { result.success(null) }
                        .addOnFailureListener { error ->
                            result.error("registration_failed", error.message, null)
                        }
                } catch (security: SecurityException) {
                    result.error("capability_unavailable", security.message, capability())
                }
            }
            .addOnFailureListener { error ->
                result.error("registration_failed", error.message, null)
            }
    }

    private fun toGeofence(zone: Map<String, Any?>): Geofence {
        val zoneId = zone["zoneId"] as? String ?: throw IllegalArgumentException("zoneId is required.")
        val generation = (zone["generation"] as? Number)?.toInt()
            ?: throw IllegalArgumentException("generation is required.")
        val latitude = (zone["latitude"] as? Number)?.toDouble()
            ?: throw IllegalArgumentException("latitude is required.")
        val longitude = (zone["longitude"] as? Number)?.toDouble()
            ?: throw IllegalArgumentException("longitude is required.")
        val radius = (zone["radiusMeters"] as? Number)?.toFloat()
            ?: throw IllegalArgumentException("radiusMeters is required.")
        require(generation > 0 && latitude in -90.0..90.0 && longitude in -180.0..180.0 && radius > 0f)
        return Geofence.Builder()
            .setRequestId("$zoneId:$generation")
            .setCircularRegion(latitude, longitude, radius)
            .setTransitionTypes(Geofence.GEOFENCE_TRANSITION_ENTER or Geofence.GEOFENCE_TRANSITION_EXIT)
            .setExpirationDuration(Geofence.NEVER_EXPIRE)
            .build()
    }

    private fun requestBackgroundCapability() {
        val permissions = buildList {
            if (!hasPermission(Manifest.permission.ACCESS_FINE_LOCATION)) add(Manifest.permission.ACCESS_FINE_LOCATION)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q && !hasPermission(Manifest.permission.ACCESS_BACKGROUND_LOCATION)) {
                add(Manifest.permission.ACCESS_BACKGROUND_LOCATION)
            }
        }
        if (permissions.isNotEmpty()) {
            ActivityCompat.requestPermissions(this, permissions.toTypedArray(), GEOFENCE_PERMISSION_REQUEST)
        }
    }

    private fun capability(): String = when {
        GoogleApiAvailability.getInstance().isGooglePlayServicesAvailable(this) != ConnectionResult.SUCCESS -> CAPABILITY_UNAVAILABLE
        !hasPermission(Manifest.permission.ACCESS_FINE_LOCATION) -> CAPABILITY_NEEDS_LOCATION
        Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q && !hasPermission(Manifest.permission.ACCESS_BACKGROUND_LOCATION) -> CAPABILITY_NEEDS_BACKGROUND
        else -> CAPABILITY_READY
    }

    private fun hasPermission(permission: String): Boolean =
        ContextCompat.checkSelfPermission(this, permission) == PackageManager.PERMISSION_GRANTED

    private val geofencePendingIntent: PendingIntent by lazy {
        PendingIntent.getBroadcast(
            this,
            2404,
            Intent(this, GeofenceBroadcastReceiver::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    private companion object {
        const val CHANNEL = "safepath/geofencing"
        const val MAX_ZONES = 20
        const val GEOFENCE_PERMISSION_REQUEST = 2404
        const val CAPABILITY_READY = "ready"
        const val CAPABILITY_NEEDS_LOCATION = "needsLocationPermission"
        const val CAPABILITY_NEEDS_BACKGROUND = "needsBackgroundPermission"
        const val CAPABILITY_UNAVAILABLE = "unavailable"
    }
}
