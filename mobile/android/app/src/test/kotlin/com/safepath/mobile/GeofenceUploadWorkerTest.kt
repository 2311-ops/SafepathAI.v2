package com.safepath.mobile

import org.junit.Assert.assertTrue
import org.junit.Test

class GeofenceUploadWorkerTest {
    @Test
    fun `background upload uses one bounded unique work request`() {
        val request = GeofenceUploadWorker.newRequest()

        assertTrue(request.tags.contains(GeofenceUploadWorker.UNIQUE_WORK_NAME))
        assertTrue(request.workSpec.backoffDelayDuration >= GeofenceUploadWorker.MIN_BACKOFF_MILLIS)
    }
}
