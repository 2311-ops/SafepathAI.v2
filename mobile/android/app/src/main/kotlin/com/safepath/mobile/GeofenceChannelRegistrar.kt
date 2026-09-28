package com.safepath.mobile

import android.content.Context
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

internal object GeofenceChannelRegistrar {
    private const val CHANNEL = "safepath/geofencing"

    fun register(
        binaryMessenger: BinaryMessenger,
        context: Context,
        appHandler: ((MethodCall, MethodChannel.Result) -> Boolean)? = null
    ) {
        val nativeStore = GeofenceNativeStore(context.applicationContext)
        MethodChannel(binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
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
                    else -> {
                        if (appHandler?.invoke(call, result) != true) {
                            result.notImplemented()
                        }
                    }
                }
            }
    }
}
