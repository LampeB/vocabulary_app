package com.vocabkr.vocab_kr

import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer

/** One native microphone-owning recognition session. All calls are on the main looper. */
internal class SystemSpeechCapture(
    private val context: Context,
    private val emit: (String, Map<String, Any>) -> Unit,
) {
    private class Session(val id: Int, val recognizer: SpeechRecognizer) {
        var releasing = false
        var terminal = false
        var destroying = false
    }

    private val main = Handler(Looper.getMainLooper())
    private var active: Session? = null

    fun supportsOnDevice(): Boolean =
        Build.VERSION.SDK_INT >= Build.VERSION_CODES.S &&
            SpeechRecognizer.isOnDeviceRecognitionAvailable(context)

    fun start(id: Int, locale: String, onDevice: Boolean): Boolean {
        if (active != null || !SpeechRecognizer.isRecognitionAvailable(context)) return false
        val recognizer = if (onDevice) {
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S || !supportsOnDevice()) return false
            SpeechRecognizer.createOnDeviceSpeechRecognizer(context)
        } else {
            SpeechRecognizer.createSpeechRecognizer(context)
        }
        val session = Session(id, recognizer)
        active = session
        fun event(method: String, payload: Map<String, Any>) {
            if (active === session && !session.releasing) {
                emit(method, payload + ("session" to id))
            }
        }
        fun transcript(bundle: Bundle?, isFinal: Boolean) {
            val words = bundle?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                ?.filter { it.isNotBlank() }.orEmpty()
            if (words.isEmpty()) return
            val scores = bundle?.getFloatArray(SpeechRecognizer.CONFIDENCE_SCORES)
            val alternatives = words.mapIndexed { index, word ->
                mapOf("words" to word, "confidence" to (scores?.getOrNull(index)?.toDouble() ?: -1.0))
            }
            event("result", mapOf("alternates" to alternatives, "isFinal" to isFinal))
        }
        recognizer.setRecognitionListener(object : RecognitionListener {
            override fun onReadyForSpeech(params: Bundle?) = event("status", mapOf("status" to "listening"))
            override fun onEndOfSpeech() = event("status", mapOf("status" to "notListening"))
            override fun onResults(results: Bundle?) {
                if (!onTerminal(session)) return
                transcript(results, true)
                event("status", mapOf("status" to "done"))
            }
            override fun onPartialResults(results: Bundle?) = transcript(results, false)
            override fun onError(error: Int) {
                if (!onTerminal(session)) return
                val name = when (error) {
                    SpeechRecognizer.ERROR_NO_MATCH, SpeechRecognizer.ERROR_SPEECH_TIMEOUT -> "error_no_match"
                    else -> "error_$error"
                }
                event("error", mapOf("message" to name))
            }
            override fun onRmsChanged(rmsdB: Float) = event("level", mapOf("level" to rmsdB.toDouble()))
            override fun onBeginningOfSpeech() {}
            override fun onBufferReceived(buffer: ByteArray?) {}
            override fun onEvent(eventType: Int, params: Bundle?) {}
        })
        try {
            recognizer.startListening(Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
                putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
                putExtra(RecognizerIntent.EXTRA_LANGUAGE, locale)
                putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
                putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 5)
            })
        } catch (error: Exception) {
            // No native start was dispatched. Keep the handle for teardown.
            session.terminal = true
            throw error
        }
        return true
    }

    /** A results/error callback closes recognition. End-of-speech alone does not. */
    private fun onTerminal(session: Session): Boolean {
        if (active !== session || session.terminal) return false
        session.terminal = true
        if (session.releasing) {
            destroyAndConfirm(session)
            return false
        }
        return true
    }

    fun stop(id: Int): Boolean {
        val session = active?.takeIf { it.id == id } ?: return false
        if (session.releasing) return true
        session.releasing = true
        try {
            if (session.terminal) destroyAndConfirm(session)
            else session.recognizer.stopListening()
        } catch (error: Exception) {
            session.releasing = false
            throw error
        }
        return true
    }

    private fun destroyAndConfirm(session: Session) {
        if (session.destroying) return
        session.destroying = true
        try {
            session.recognizer.destroy()
        } catch (error: Exception) {
            session.releasing = false
            session.destroying = false
            emit("releaseFailed", mapOf("session" to session.id))
            return
        }
        // The terminal callback has already ended recognition. The recognizer
        // may post its remaining teardown on this same main looper.
        main.post {
            if (active === session) {
                active = null
                emit("released", mapOf("session" to session.id))
            }
        }
    }

    fun dispose() {
        active?.recognizer?.destroy()
        active = null
    }
}
