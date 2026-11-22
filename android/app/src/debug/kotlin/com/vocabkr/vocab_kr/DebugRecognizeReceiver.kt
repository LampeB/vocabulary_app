package com.vocabkr.vocab_kr

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import java.io.File

/**
 * DEBUG BUILDS ONLY — benchmarks [PcmSpeechRecognizer] on a WAV file without
 * any UI, so the corpus in tool/stt_corpus can be replayed from adb:
 *
 *   adb shell am broadcast -n com.vocabkr.vocab_kr.debug/com.vocabkr.vocab_kr.DebugRecognizeReceiver \
 *     --es path /sdcard/Android/data/com.vocabkr.vocab_kr.debug/files/corpus/x.wav --es locale fr-FR
 *
 * The result is logged under the "PCMREC" tag.
 */
class DebugRecognizeReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val locale = intent.getStringExtra("locale") ?: "fr-FR"
        val onDevice = intent.getBooleanExtra("ondevice", false)
        val offline = intent.getBooleanExtra("offline", false)
        if (intent.getBooleanExtra("download", false)) {
            PcmSpeechRecognizer(context.applicationContext).triggerModelDownload(locale, onDevice)
            return
        }
        val ttsText = intent.getStringExtra("tts")
        if (ttsText != null) {
            synthesizeThenRecognize(context.applicationContext, ttsText, locale, onDevice, goAsync())
            return
        }
        val path = intent.getStringExtra("path") ?: return
        val bytes = File(path).readBytes()
        // Skip the canonical 44-byte WAV header (16kHz mono PCM16 corpus).
        var pcm = bytes.copyOfRange(44, bytes.size)
        var rate = 16000
        if (intent.getBooleanExtra("swap", false)) {
            for (i in 0 until pcm.size - 1 step 2) {
                val t = pcm[i]; pcm[i] = pcm[i + 1]; pcm[i + 1] = t
            }
        }
        val resample = intent.getIntExtra("resample", 0)
        if (resample > 0) {
            pcm = resampleLinear(pcm, 16000, resample)
            rate = resample
        }
        rate = intent.getIntExtra("rate", rate)
        val leadMs = intent.getIntExtra("lead", 0) // extra, on top of the bridge's own 500ms
        if (leadMs > 0) pcm = ByteArray(rate * 2 * leadMs / 1000) + pcm
        val pace = intent.getBooleanExtra("pace", true)
        val gain = intent.getFloatExtra("gain", 1f)
        val pending = goAsync()
        PcmSpeechRecognizer(context.applicationContext)
            .recognize(pcm, locale, rate, 8000, pace, gain, offline, onDevice, intent.getIntExtra("sleep", 5).toLong()) { o ->
                Log.i(
                    "PCMREC",
                    "file=${File(path).name} locale=$locale pace=$pace gain=$gain offline=$offline ondevice=$onDevice sleep=${intent.getIntExtra("sleep", 5)} rate=$rate swap=${intent.getBooleanExtra("swap", false)} lead=$leadMs ms=${o.elapsedMs} " +
                        "error=${o.errorCode} texts=${o.texts} conf=${o.confidences}",
                )
                pending.finish()
            }
    }

    private fun resampleLinear(pcm: ByteArray, from: Int, to: Int): ByteArray {
        val n = pcm.size / 2
        val src = ShortArray(n) { i -> ((pcm[2 * i].toInt() and 0xff) or (pcm[2 * i + 1].toInt() shl 8)).toShort() }
        val m = (n.toLong() * to / from).toInt()
        val out = ByteArray(m * 2)
        for (j in 0 until m) {
            val pos = j.toDouble() * from / to
            val i0 = pos.toInt().coerceAtMost(n - 1)
            val i1 = (i0 + 1).coerceAtMost(n - 1)
            val f = pos - i0
            val v = (src[i0] * (1 - f) + src[i1] * f).toInt()
            out[2 * j] = (v and 0xff).toByte()
            out[2 * j + 1] = ((v shr 8) and 0xff).toByte()
        }
        return out
    }

    /** Control experiment: clean synthetic speech through the same bridge. */
    private fun synthesizeThenRecognize(
        context: Context,
        text: String,
        locale: String,
        onDevice: Boolean,
        pending: PendingResult,
    ) {
        val out = File(context.cacheDir, "tts_probe.wav")
        var tts: android.speech.tts.TextToSpeech? = null
        tts = android.speech.tts.TextToSpeech(context) { status ->
            val engine = tts!!
            if (status != android.speech.tts.TextToSpeech.SUCCESS) {
                Log.i("PCMREC", "tts init failed $status"); pending.finish(); return@TextToSpeech
            }
            engine.language = java.util.Locale.forLanguageTag(locale)
            engine.setOnUtteranceProgressListener(object : android.speech.tts.UtteranceProgressListener() {
                override fun onStart(id: String?) {}
                @Deprecated("") override fun onError(id: String?) {
                    Log.i("PCMREC", "tts error"); pending.finish()
                }
                override fun onDone(id: String?) {
                    val bytes = out.readBytes()
                    val rate = java.nio.ByteBuffer.wrap(bytes, 24, 4)
                        .order(java.nio.ByteOrder.LITTLE_ENDIAN).int
                    val channels = java.nio.ByteBuffer.wrap(bytes, 22, 2)
                        .order(java.nio.ByteOrder.LITTLE_ENDIAN).short
                    val pcm = bytes.copyOfRange(44, bytes.size)
                    android.os.Handler(android.os.Looper.getMainLooper()).post {
                        PcmSpeechRecognizer(context).recognize(
                            pcm, locale, rate, 8000, true, 1f, false, onDevice, 5,
                        ) { o ->
                            Log.i("PCMREC", "file=tts:\"$text\" locale=$locale rate=$rate ch=$channels " +
                                "ondevice=$onDevice ms=${o.elapsedMs} error=${o.errorCode} texts=${o.texts}")
                            engine.shutdown()
                            pending.finish()
                        }
                    }
                }
            })
            engine.synthesizeToFile(text, null, out, "probe")
        }
    }
}
