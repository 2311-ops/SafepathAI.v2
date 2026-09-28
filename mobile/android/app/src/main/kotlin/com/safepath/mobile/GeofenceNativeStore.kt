package com.safepath.mobile

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject

/**
 * A tiny app-private outbox for routine geofence callbacks. Its synchronous
 * commits deliberately finish before BroadcastReceiver.onReceive returns, so
 * a terminated Flutter engine is never needed to retain an OS transition.
 */
class GeofenceNativeStore(context: Context) {
    private val preferences = context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)

    @Synchronized
    fun persist(candidate: Candidate): Boolean {
        val pending = read().toMutableList()
        if (pending.any { it.eventId == candidate.eventId }) return false
        pending += candidate
        // Bound untrusted OS input. Dropping the oldest routine candidate is
        // safer than unbounded app-private storage growth.
        val bounded = pending.takeLast(MAX_PENDING)
        return preferences.edit().putString(OUTBOX, encode(bounded)).commit()
    }

    @Synchronized
    fun drain(): List<Candidate> = read()

    @Synchronized
    fun acknowledge(eventId: String): Boolean {
        val remaining = read().filterNot { it.eventId == eventId }
        return preferences.edit().putString(OUTBOX, encode(remaining)).commit()
    }

    private fun read(): List<Candidate> {
        val serialized = preferences.getString(OUTBOX, null) ?: return emptyList()
        return runCatching {
            val array = JSONArray(serialized)
            buildList {
                for (index in 0 until array.length()) {
                    Candidate.fromJson(array.getJSONObject(index))?.let(::add)
                }
            }
        }.getOrDefault(emptyList())
    }

    private fun encode(candidates: List<Candidate>): String = JSONArray().apply {
        candidates.forEach { put(it.toJson()) }
    }.toString()

    data class Candidate(
        val eventId: String,
        val requestId: String,
        val transition: String,
        val occurredAtEpochMs: Long,
        val latitude: Double?,
        val longitude: Double?,
        val accuracyMeters: Double?,
        val errorCode: Int?
    ) {
        fun toJson(): JSONObject = JSONObject().apply {
            put("version", VERSION)
            put("eventId", eventId)
            put("requestId", requestId)
            put("transition", transition)
            put("occurredAtEpochMs", occurredAtEpochMs)
            put("latitude", latitude)
            put("longitude", longitude)
            put("accuracyMeters", accuracyMeters)
            put("errorCode", errorCode)
        }

        companion object {
            fun fromJson(json: JSONObject): Candidate? = runCatching {
                if (json.optInt("version") != VERSION) return null
                Candidate(
                    eventId = json.getString("eventId"),
                    requestId = json.getString("requestId"),
                    transition = json.getString("transition"),
                    occurredAtEpochMs = json.getLong("occurredAtEpochMs"),
                    latitude = json.takeIf { !it.isNull("latitude") }?.getDouble("latitude"),
                    longitude = json.takeIf { !it.isNull("longitude") }?.getDouble("longitude"),
                    accuracyMeters = json.takeIf { !it.isNull("accuracyMeters") }?.getDouble("accuracyMeters"),
                    errorCode = json.takeIf { !it.isNull("errorCode") }?.getInt("errorCode")
                )
            }.getOrNull()
        }
    }

    private companion object {
        const val PREFERENCES = "safepath_geofence_outbox"
        const val OUTBOX = "pending_v1"
        const val VERSION = 1
        const val MAX_PENDING = 100
    }
}
