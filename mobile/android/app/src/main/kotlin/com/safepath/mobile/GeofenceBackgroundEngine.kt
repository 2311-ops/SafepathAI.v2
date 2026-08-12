package com.safepath.mobile

import android.content.Context
import android.os.Handler
import android.os.Looper
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicReference

/**
 * Owns the short-lived headless engine used by one WorkManager execution.
 *
 * The engine receives no native credentials. Dart restores the encrypted
 * Supabase session itself and tells this runner only whether WorkManager should retry.
 */
class GeofenceBackgroundEngine(private val context: Context) {
    fun run(): Boolean {
        val completed = CountDownLatch(1)
        val retry = AtomicBoolean(true)
        val engine = AtomicReference<FlutterEngine?>()
        val mainHandler = Handler(Looper.getMainLooper())

        mainHandler.post {
            val createdEngine = FlutterEngine(context)
            engine.set(createdEngine)
            MethodChannel(createdEngine.dartExecutor.binaryMessenger, CHANNEL)
                .setMethodCallHandler { call, result ->
                    if (call.method != "complete") {
                        result.notImplemented()
                        return@setMethodCallHandler
                    }
                    retry.set(call.argument<Boolean>("retry") ?: true)
                    result.success(null)
                    completed.countDown()
                }

            runCatching {
                val bundlePath = FlutterInjector.instance().flutterLoader().findAppBundlePath()
                createdEngine.dartExecutor.executeDartEntrypoint(
                    DartExecutor.DartEntrypoint(bundlePath, DART_ENTRYPOINT)
                )
            }.onFailure {
                completed.countDown()
            }
        }

        val finished = completed.await(TIMEOUT_SECONDS, TimeUnit.SECONDS)
        mainHandler.post { engine.getAndSet(null)?.destroy() }
        return finished && !retry.get()
    }

    private companion object {
        const val CHANNEL = "safepath/geofence-background"
        const val DART_ENTRYPOINT = "geofenceBackgroundMain"
        const val TIMEOUT_SECONDS = 90L
    }
}
