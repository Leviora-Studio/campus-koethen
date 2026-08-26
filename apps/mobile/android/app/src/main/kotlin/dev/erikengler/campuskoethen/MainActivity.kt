package dev.erikengler.campuskoethen

import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Hosts the Flutter engine and the one platform channel the app owns itself.
 *
 * `FLAG_SECURE` keeps a window out of screenshots and out of the thumbnail the
 * system shows in Recents. It is applied **selectively**, not globally: the
 * screens that ask for it are the ones showing a university password or the
 * copy of a student ID, while a timetable or a canteen menu stays perfectly
 * screenshottable — students share those on purpose.
 */
class MainActivity : FlutterActivity() {
    /** Screens currently asking for protection; the flag drops at zero. */
    private var protectionRequests = 0

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            SCREEN_PROTECTION_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "acquire" -> {
                    protectionRequests++
                    applyFlag()
                    result.success(null)
                }
                "release" -> {
                    // Never below zero: a release without a matching acquire
                    // would otherwise leave the counter negative and the next
                    // acquire unable to reach 1.
                    if (protectionRequests > 0) protectionRequests--
                    applyFlag()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun applyFlag() {
        // Window flags have to be touched on the UI thread.
        runOnUiThread {
            if (protectionRequests > 0) {
                window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
            } else {
                window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
            }
        }
    }

    companion object {
        private const val SCREEN_PROTECTION_CHANNEL =
            "dev.erikengler.campuskoethen/screen_protection"
    }
}
