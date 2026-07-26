package com.yourapp.bhasha

import android.app.Application
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.dart.DartExecutor

/**
 * Owns a process-scoped FlutterEngine.
 *
 * Why this exists: the overlay bubble is used while the parent is inside
 * WhatsApp, which is exactly when Android is free to destroy MainActivity.
 * When the Dart side lived on the activity's engine, every bubble action
 * failed with "Bhasha is not ready" as soon as that happened.
 *
 * The engine is created once per process and cached. MainActivity attaches to
 * the same engine instead of building its own, so the UI and the overlay share
 * one Dart isolate - one StorageService, one Sarvam client, one set of
 * preferences. Nothing re-initialises when the activity comes and goes.
 */
class BhashaApplication : Application() {

    override fun onCreate() {
        super.onCreate()

        // Constructing FlutterEngine(Context) registers the Flutter plugins
        // (shared_preferences, flutter_secure_storage) automatically, so Dart
        // can reach storage without an activity present.
        val engine = FlutterEngine(this)

        // The default entrypoint is deliberate: MainActivity renders from this
        // same engine, so it must run main(). With no activity attached the
        // widget tree simply builds without drawing.
        engine.dartExecutor.executeDartEntrypoint(
            DartExecutor.DartEntrypoint.createDefault()
        )

        FlutterEngineCache.getInstance().put(ENGINE_ID, engine)
        BhashaChannel.attachTo(engine, this)
    }

    companion object {
        const val ENGINE_ID = "bhasha_shared_engine"

        /** The cached engine, or null if the process is mid-teardown. */
        fun engine(): FlutterEngine? =
            FlutterEngineCache.getInstance().get(ENGINE_ID)
    }
}
