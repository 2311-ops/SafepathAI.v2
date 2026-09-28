package com.safepath.mobile

import android.content.Context
import androidx.work.BackoffPolicy
import androidx.work.ExistingWorkPolicy
import androidx.work.OneTimeWorkRequest
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.Worker
import androidx.work.WorkerParameters
import java.util.concurrent.TimeUnit

/** Runs the Dart outbox drain without copying Supabase credentials into Android. */
class GeofenceUploadWorker(
    appContext: Context,
    parameters: WorkerParameters
) : Worker(appContext, parameters) {
    override fun doWork(): Result =
        if (GeofenceBackgroundEngine(applicationContext).run()) Result.success() else Result.retry()

    companion object {
        internal const val UNIQUE_WORK_NAME = "safepath-geofence-upload"
        internal const val MIN_BACKOFF_MILLIS = 30_000L

        fun enqueue(context: Context) {
            WorkManager.getInstance(context).enqueueUniqueWork(
                UNIQUE_WORK_NAME,
                ExistingWorkPolicy.KEEP,
                newRequest()
            )
        }

        internal fun newRequest(): OneTimeWorkRequest =
            OneTimeWorkRequestBuilder<GeofenceUploadWorker>()
                .setBackoffCriteria(
                    BackoffPolicy.EXPONENTIAL,
                    MIN_BACKOFF_MILLIS,
                    TimeUnit.MILLISECONDS
                )
                .addTag(UNIQUE_WORK_NAME)
                .build()
    }
}
