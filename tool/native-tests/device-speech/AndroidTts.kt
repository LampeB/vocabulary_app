package android.speech.tts

import android.content.Context
import android.os.Bundle
import java.util.Locale

abstract class UtteranceProgressListener {
    abstract fun onStart(utteranceId: String)
    abstract fun onDone(utteranceId: String)
    @Deprecated("Deprecated in Android")
    abstract fun onError(utteranceId: String)
    open fun onError(utteranceId: String, errorCode: Int) {}
    open fun onStop(utteranceId: String, interrupted: Boolean) {}
}

class TextToSpeech(context: Context, private val init: OnInitListener, val name: String? = null) {
    fun interface OnInitListener { fun onInit(status: Int) }

    object Engine {
        const val INTENT_ACTION_TTS_SERVICE = "android.intent.action.TTS_SERVICE"
        const val KEY_PARAM_VOLUME = "volume"
    }

    companion object {
        const val SUCCESS = 0
        const val ERROR = -1
        const val LANG_AVAILABLE = 0
        const val QUEUE_FLUSH = 0
        val instances = mutableListOf<TextToSpeech>()
    }

    data class Played(val text: String, val id: String, val locale: Locale)

    val played = mutableListOf<Played>()
    val stopTargets = mutableListOf<String?>()
    var stopCode = SUCCESS
    var shutdowns = 0
    private lateinit var events: UtteranceProgressListener
    private lateinit var locale: Locale

    init { instances.add(this) }

    fun setOnUtteranceProgressListener(progress: UtteranceProgressListener): Int {
        events = progress
        return SUCCESS
    }

    fun setLanguage(language: Locale): Int {
        locale = language
        return LANG_AVAILABLE
    }

    fun setSpeechRate(rate: Float) = SUCCESS
    fun setPitch(pitch: Float) = SUCCESS

    fun speak(text: String, queueMode: Int, params: Bundle, utteranceId: String): Int {
        played.add(Played(text, utteranceId, locale))
        return SUCCESS
    }

    fun stop(): Int {
        stopTargets.add(played.lastOrNull()?.id)
        return stopCode
    }

    fun shutdown() { shutdowns++ }
    fun finishInit() = init.onInit(SUCCESS)
    fun stopped(id: String) = events.onStop(id, true)
    fun done(id: String) = events.onDone(id)
}
