package dev.erikengler.campuskoethen

import android.nfc.NfcAdapter
import android.nfc.tech.IsoDep
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.IOException
import java.util.concurrent.atomic.AtomicBoolean

class MainActivity : FlutterActivity() {
    private val ui = Handler(Looper.getMainLooper())
    private var pendingScan: MethodChannel.Result? = null
    private var timeout: Runnable? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "campus_koethen/mensa_card")
            .setMethodCallHandler { call, reply ->
                when (call.method) {
                    "scan" -> startScan(reply)
                    "cancel" -> {
                        pendingScan?.let { finish(it, null, "cancelled") }
                        reply.success(null)
                    }
                    else -> reply.notImplemented()
                }
            }
    }

    override fun onPause() {
        pendingScan?.let { finish(it, null, "cancelled") }
        super.onPause()
    }

    private fun startScan(reply: MethodChannel.Result) {
        val adapter = NfcAdapter.getDefaultAdapter(this)
        when {
            pendingScan != null -> reply.error("busy", null, null)
            adapter == null -> reply.error("unavailable", null, null)
            !adapter.isEnabled -> reply.error("disabled", null, null)
            else -> {
                pendingScan = reply
                val reading = AtomicBoolean()
                try {
                    adapter.enableReaderMode(
                        this,
                        { tag ->
                            if (reading.compareAndSet(false, true)) {
                                val technology = IsoDep.get(tag)
                                val result = try {
                                    technology?.use { card ->
                                        card.connect()
                                        card.timeout = 1500
                                        readBalance(card)
                                    }
                                } catch (_: IOException) {
                                    null
                                } catch (_: SecurityException) {
                                    null
                                }
                                ui.post { finish(reply, result, "readFailed") }
                            }
                        },
                        NfcAdapter.FLAG_READER_NFC_A or NfcAdapter.FLAG_READER_SKIP_NDEF_CHECK,
                        null,
                    )
                    timeout = Runnable { finish(reply, null, "timeout") }.also {
                        ui.postDelayed(it, 30_000)
                    }
                } catch (_: RuntimeException) {
                    finish(reply, null, "unavailable")
                }
            }
        }
    }

    private fun finish(reply: MethodChannel.Result, value: ByteArray?, error: String) {
        if (pendingScan !== reply) return
        pendingScan = null
        timeout?.let { ui.removeCallbacks(it) }
        timeout = null
        try {
            NfcAdapter.getDefaultAdapter(this)?.disableReaderMode(this)
        } catch (_: RuntimeException) {
            // NFC may have been switched off during the scan.
        }
        if (value == null) reply.error(error, null, null) else reply.success(value)
    }

    private fun readBalance(card: IsoDep): ByteArray? {
        // InterCard's publicly readable DESFire purse. Only select and get value.
        val select = byteArrayOf(0x90.toByte(), 0x5A, 0, 0, 3, 0x5F, 0x84.toByte(), 0x15, 0)
        if (!card.transceive(select).contentEquals(byteArrayOf(0x91.toByte(), 0))) return null
        val read = byteArrayOf(0x90.toByte(), 0x6C, 0, 0, 1, 1, 0)
        val response = card.transceive(read)
        if (response.size != 6 || response[4] != 0x91.toByte() || response[5] != 0.toByte()) {
            return null
        }
        return response.copyOfRange(0, 4)
    }
}
