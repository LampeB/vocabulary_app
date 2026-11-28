package com.vocabkr.vocab_kr

import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.Locale

/** Owns the app's Android synthesizer. Commands and terminal events run on the main looper. */
internal class DeviceSpeech(context: Context, messenger: BinaryMessenger) {
    private data class Voice(val locale: String, val rate: Float, val pitch: Float)

    private class Request(val client: Int, val voice: Voice, val text: String?, val reply: MethodChannel.Result)

    private class Engine(val name: String?, val tts: TextToSpeech) {
        var voice: Voice? = null
    }

    private class Opening(val engine: Engine, val request: Request)

    private class Utterance(val id: String, val engine: Engine, val request: Request) {
        var stopReply: MethodChannel.Result? = null
    }

    private val context = context.applicationContext
    private val channel = MethodChannel(messenger, "vocab_kr/device_speech")
    private val main = Handler(Looper.getMainLooper())
    private val engines = mutableMapOf<String?, Engine>()
    private var preparing: Opening? = null
    private var active: Utterance? = null
    private var nextId = 0L
    private val installedEngines by lazy {
        @Suppress("DEPRECATION")
        context.packageManager.queryIntentServices(
            Intent(TextToSpeech.Engine.INTENT_ACTION_TTS_SERVICE), 0
        ).map { it.serviceInfo.packageName }.toSet()
    }

    private val listener = object : UtteranceProgressListener() {
        override fun onStart(utteranceId: String) {}
        override fun onDone(utteranceId: String) = postTerminal(utteranceId, completed = true)

        @Deprecated("Deprecated in Android")
        override fun onError(utteranceId: String) = postTerminal(utteranceId, completed = false)

        override fun onError(utteranceId: String, errorCode: Int) =
            postTerminal(utteranceId, completed = false)

        override fun onStop(utteranceId: String, interrupted: Boolean) =
            postTerminal(utteranceId, completed = false)
    }

    init {
        channel.setMethodCallHandler(::handle)
    }

    private fun handle(call: MethodCall, reply: MethodChannel.Result) {
        when (call.method) {
            "warmUp", "speak" -> {
                val client = call.argument<Int>("client")
                val locale = call.argument<String>("locale")
                val rate = call.argument<Number>("rate")
                val pitch = call.argument<Number>("pitch")
                val text = call.argument<String>("text")
                if (client == null || locale == null || rate == null || pitch == null ||
                    (call.method == "speak" && text == null)
                ) {
                    reply.success(0)
                    return
                }
                val preferred = call.argument<List<String>>("engines").orEmpty()
                prepare(
                    Request(client, Voice(locale, rate.toFloat() * 2f, pitch.toFloat()), text, reply),
                    preferred.firstOrNull(installedEngines::contains),
                )
            }
            "stop" -> {
                val client = call.arguments as? Int
                if (client == null) reply.success(0)
                else stop(client, reply)
            }
            else -> reply.notImplemented()
        }
    }

    private fun prepare(request: Request, name: String?) {
        if (active != null || preparing != null) {
            request.reply.success(0)
            return
        }
        val ready = engines[name]
        if (ready != null) {
            start(ready, request)
            return
        }
        lateinit var opening: Opening
        val initialized = TextToSpeech.OnInitListener { status ->
            main.post { finishOpening(opening, status) }
        }
        val tts = if (name == null) TextToSpeech(context, initialized)
            else TextToSpeech(context, initialized, name)
        opening = Opening(Engine(name, tts), request)
        preparing = opening
    }

    private fun finishOpening(opening: Opening, status: Int) {
        if (preparing !== opening) return
        preparing = null
        val engine = opening.engine
        if (status != TextToSpeech.SUCCESS ||
            engine.tts.setOnUtteranceProgressListener(listener) != TextToSpeech.SUCCESS
        ) {
            engine.tts.shutdown()
            opening.request.reply.success(0)
            return
        }
        engines[engine.name] = engine
        start(engine, opening.request)
    }

    private fun start(engine: Engine, request: Request) {
        val tts = engine.tts
        val voice = request.voice
        if (engine.voice != voice) {
            engine.voice = null
            if (tts.setLanguage(Locale.forLanguageTag(voice.locale)) < TextToSpeech.LANG_AVAILABLE ||
                tts.setSpeechRate(voice.rate) != TextToSpeech.SUCCESS ||
                tts.setPitch(voice.pitch) != TextToSpeech.SUCCESS
            ) {
                request.reply.success(0)
                return
            }
            engine.voice = voice
        }
        val text = request.text
        if (text == null) {
            request.reply.success(1)
            return
        }
        val utterance = Utterance((++nextId).toString(), engine, request)
        val parameters = Bundle().apply { putFloat(TextToSpeech.Engine.KEY_PARAM_VOLUME, 1f) }
        if (tts.speak(text, TextToSpeech.QUEUE_FLUSH, parameters, utterance.id) != TextToSpeech.SUCCESS) {
            request.reply.success(0)
            return
        }
        active = utterance
    }

    private fun stop(client: Int, reply: MethodChannel.Result) {
        val utterance = active
        if (utterance == null) {
            val pending = preparing
            if (pending != null) {
                if (pending.request.client != client) {
                    reply.success(0)
                    return
                }
                preparing = null
                pending.engine.tts.shutdown()
                pending.request.reply.success(0)
            }
            reply.success(1)
            return
        }
        if (utterance.request.client != client || utterance.stopReply != null ||
            utterance.engine.tts.stop() != TextToSpeech.SUCCESS
        ) {
            reply.success(0)
            return
        }
        // A successful command can precede the native terminal callback. Retain
        // the utterance until that callback even if this stop attempt expires.
        utterance.stopReply = reply
        main.postDelayed({
            if (active === utterance && utterance.stopReply === reply) {
                utterance.stopReply = null
                reply.success(0)
            }
        }, 750)
    }

    private fun postTerminal(id: String, completed: Boolean) {
        main.post {
            val utterance = active?.takeIf { it.id == id } ?: return@post
            active = null
            val stopReply = utterance.stopReply
            utterance.request.reply.success(if (completed && stopReply == null) 1 else 0)
            stopReply?.success(1)
        }
    }

    fun dispose() {
        channel.setMethodCallHandler(null)
        main.removeCallbacksAndMessages(null)
        val pending = preparing
        val utterance = active
        preparing = null
        active = null
        pending?.request?.reply?.success(0)
        utterance?.request?.reply?.success(0)
        utterance?.stopReply?.success(0)
        pending?.engine?.tts?.shutdown()
        engines.values.forEach { it.tts.shutdown() }
        engines.clear()
    }
}
