package com.vocabkr.vocab_kr

import android.content.Context
import android.content.Intent
import android.media.AudioFormat
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.ParcelFileDescriptor
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import android.util.Log

/**
 * Runs the phone's speech recognizer on audio WE captured, instead of letting
 * it open the microphone itself (Android 13+ `EXTRA_AUDIO_SOURCE`).
 *
 * This is what lets the phone recognizer join the parallel race: the app owns
 * the one microphone, cuts the learner's answer into an utterance, and every
 * engine — cloud Scribe, on-device Whisper and this one — transcribes the
 * very same recording (user decision 2026-10-02).
 */
class PcmSpeechRecognizer(private val context: Context) {

    data class Outcome(
        val texts: List<String>,
        val confidences: List<Float>,
        /** A SpeechRecognizer ERROR_* code, or null on success / no match. */
        val errorCode: Int?,
        val elapsedMs: Long,
    )

    private val main = Handler(Looper.getMainLooper())

    companion object {
        private const val TAG = "PcmSpeechRecognizer"

        /** Codes that only mean "nothing understood" — not a failure. */
        private val NO_SPEECH = setOf(
            SpeechRecognizer.ERROR_NO_MATCH,
            SpeechRecognizer.ERROR_SPEECH_TIMEOUT,
        )

        /** Our own watchdog code (outside the platform's ERROR_* range). */
        const val ERROR_WATCHDOG = 1000

        fun isSupported(context: Context): Boolean =
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
                SpeechRecognizer.isRecognitionAvailable(context)
    }

    /** Asks the recognizer to download its offline model for [languageTag]. */
    fun triggerModelDownload(languageTag: String, onDevice: Boolean) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return
        val recognizer =
            if (onDevice && SpeechRecognizer.isOnDeviceRecognitionAvailable(context)) {
                SpeechRecognizer.createOnDeviceSpeechRecognizer(context)
            } else {
                SpeechRecognizer.createSpeechRecognizer(context)
            }
        val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
            putExtra(RecognizerIntent.EXTRA_LANGUAGE, languageTag)
        }
        recognizer.triggerModelDownload(intent)
        main.postDelayed({ recognizer.destroy() }, 2000)
        Log.i(TAG, "model download requested for $languageTag onDevice=$onDevice " +
            "onDeviceAvailable=${SpeechRecognizer.isOnDeviceRecognitionAvailable(context)}")
    }

    private fun amplify(pcm: ByteArray, gain: Float): ByteArray {
        val out = ByteArray(pcm.size)
        var i = 0
        while (i + 1 < pcm.size) {
            val s = (pcm[i].toInt() and 0xff) or (pcm[i + 1].toInt() shl 8)
            val v = (s * gain).toInt().coerceIn(-32768, 32767)
            out[i] = (v and 0xff).toByte()
            out[i + 1] = ((v shr 8) and 0xff).toByte()
            i += 2
        }
        return out
    }

    /**
     * Transcribes [pcm] (16-bit mono little-endian at [sampleRate]) in
     * [languageTag] (BCP-47, e.g. "ko-KR"). [onDone] runs on the main thread
     * exactly once. Must be called on the main thread.
     */
    fun recognize(
        pcm: ByteArray,
        languageTag: String,
        sampleRate: Int,
        timeoutMs: Long,
        paceRealtime: Boolean = true,
        gain: Float = 1f,
        preferOffline: Boolean = false,
        onDevice: Boolean = false,
        chunkSleepMs: Long = 5,
        onDone: (Outcome) -> Unit,
    ) {
        val started = System.currentTimeMillis()
        if (!isSupported(context)) {
            onDone(Outcome(emptyList(), emptyList(), SpeechRecognizer.ERROR_CLIENT, 0))
            return
        }
        val recognizer =
            if (onDevice && SpeechRecognizer.isOnDeviceRecognitionAvailable(context)) {
                SpeechRecognizer.createOnDeviceSpeechRecognizer(context)
            } else {
                SpeechRecognizer.createSpeechRecognizer(context)
            }
        val pipe = ParcelFileDescriptor.createPipe()
        val readEnd = pipe[0]
        val writeEnd = pipe[1]
        var finished = false
        // Google's service delivers the transcript of fed audio through
        // onPartialResults and then an EMPTY onResults bundle (verified on
        // the SM-S908B, 2026-10-02) — keep the latest partial as the answer.
        var lastPartial: List<String> = emptyList()
        lateinit var watchdog: Runnable

        fun finish(outcome: Outcome) {
            if (finished) return
            finished = true
            main.removeCallbacks(watchdog)
            try { recognizer.destroy() } catch (e: Exception) { Log.w(TAG, "destroy", e) }
            try { readEnd.close() } catch (_: Exception) {}
            onDone(outcome)
        }

        fun elapsed() = System.currentTimeMillis() - started

        watchdog = Runnable {
            Log.w(TAG, "watchdog after ${elapsed()}ms")
            finish(Outcome(emptyList(), emptyList(), ERROR_WATCHDOG, elapsed()))
        }

        recognizer.setRecognitionListener(object : RecognitionListener {
            override fun onResults(results: Bundle?) {
                val texts = (
                    results
                        ?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                        ?.filter { it.isNotBlank() }
                        ?: emptyList()
                    ).ifEmpty { lastPartial }
                val scores = results
                    ?.getFloatArray(SpeechRecognizer.CONFIDENCE_SCORES)
                    ?.toList()
                    ?: emptyList()
                finish(Outcome(texts, scores, null, elapsed()))
            }

            override fun onError(error: Int) {
                if (lastPartial.isNotEmpty()) {
                    finish(Outcome(lastPartial, emptyList(), null, elapsed()))
                    return
                }
                val code = if (error in NO_SPEECH) null else error
                finish(Outcome(emptyList(), emptyList(), code, elapsed()))
            }

            override fun onReadyForSpeech(params: Bundle?) {}
            override fun onBeginningOfSpeech() {}
            override fun onRmsChanged(rmsdB: Float) {}
            override fun onBufferReceived(buffer: ByteArray?) {}
            override fun onEndOfSpeech() {}
            override fun onPartialResults(partialResults: Bundle?) {
                val texts = partialResults
                    ?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                    ?.filter { it.isNotBlank() }
                if (!texts.isNullOrEmpty()) lastPartial = texts
            }
            override fun onSegmentResults(segmentResults: Bundle) {
                Log.d(TAG, "onSegmentResults ${segmentResults.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)}")
            }
            override fun onEndOfSegmentedSession() {
                Log.d(TAG, "onEndOfSegmentedSession")
            }
            override fun onEvent(eventType: Int, params: Bundle?) {
                Log.d(TAG, "onEvent $eventType ${params?.keySet()}")
            }
        })

        val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(
                RecognizerIntent.EXTRA_LANGUAGE_MODEL,
                RecognizerIntent.LANGUAGE_MODEL_FREE_FORM,
            )
            putExtra(RecognizerIntent.EXTRA_LANGUAGE, languageTag)
            putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 5)
            putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, false)
            putExtra(RecognizerIntent.EXTRA_AUDIO_SOURCE, readEnd)
            putExtra(RecognizerIntent.EXTRA_AUDIO_SOURCE_CHANNEL_COUNT, 1)
            putExtra(
                RecognizerIntent.EXTRA_AUDIO_SOURCE_ENCODING,
                AudioFormat.ENCODING_PCM_16BIT,
            )
            putExtra(RecognizerIntent.EXTRA_AUDIO_SOURCE_SAMPLING_RATE, sampleRate)
            if (preferOffline) putExtra(RecognizerIntent.EXTRA_PREFER_OFFLINE, true)
        }

        main.postDelayed(watchdog, timeoutMs)
        try {
            recognizer.startListening(intent)
        } catch (e: Exception) {
            Log.w(TAG, "startListening failed", e)
            try { writeEnd.close() } catch (_: Exception) {}
            finish(Outcome(emptyList(), emptyList(), SpeechRecognizer.ERROR_CLIENT, elapsed()))
            return
        }

        // Feed the utterance, then a short silence so the recognizer's own
        // endpointer closes the turn, then EOF.
        // 500ms of leading silence: Google's endpointer missed short words
        // that start right at the first sample (corpus 2026-10-02: 3 of 11
        // empty results recovered, none lost).
        val lead = ByteArray(sampleRate * 2 * 500 / 1000)
        val audio = lead + (if (gain == 1f) pcm else amplify(pcm, gain))
        Thread {
            try {
                ParcelFileDescriptor.AutoCloseOutputStream(writeEnd).use { out ->
                    val all = audio + ByteArray(sampleRate * 2 * 700 / 1000)
                    if (!paceRealtime) {
                        out.write(all)
                    } else {
                        // 20ms chunks at (up to 4x) real time: the streaming
                        // recognizer expects a live-like audio stream.
                        val chunk = sampleRate * 2 / 50
                        var offset = 0
                        while (offset < all.size) {
                            val end = minOf(offset + chunk, all.size)
                            out.write(all, offset, end - offset)
                            offset = end
                            Thread.sleep(chunkSleepMs)
                        }
                    }
                }
            } catch (e: Exception) {
                // The recognizer may close its end early once it has a result.
                Log.d(TAG, "pipe write ended: ${e.message}")
            }
        }.start()
    }
}
