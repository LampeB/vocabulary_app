package com.vocabkr.vocab_kr

import android.content.Context
import android.os.Looper
import android.speech.tts.TextToSpeech
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

private class Reply(private val label: String, private val timeline: MutableList<Pair<String, Int>>) : MethodChannel.Result {
    private val values = mutableListOf<Int>()
    override fun success(result: Any?) {
        check(values.isEmpty()) { "$label completed more than once" }
        val code = result as Int
        values.add(code)
        timeline.add(label to code)
    }
    override fun notImplemented() = error("$label was not implemented")
    fun expect(vararg expected: Int) = check(values == expected.toList()) {
        "$label expected ${expected.toList()}, got $values"
    }
}

private class Probe : AutoCloseable {
    private val messenger = BinaryMessenger()
    private val device = DeviceSpeech(Context(), messenger)
    private val main = Looper.getMainLooper()
    val replies = mutableListOf<Pair<String, Int>>()

    init {
        TextToSpeech.instances.clear()
        check(messenger.channel.name == "vocab_kr/device_speech")
    }

    fun tick(ms: Long = 0) = main.advanceBy(ms)
    val engine: TextToSpeech get() = TextToSpeech.instances.last()

    fun speak(label: String, client: Int = 1, locale: String = "ko", engine: String? = null) =
        call("speak", label, mapOf(
            "client" to client, "text" to label, "locale" to locale,
            "rate" to 0.5, "pitch" to 1.0, "engines" to listOfNotNull(engine),
        ))

    fun stop(label: String, client: Int = 1) = call("stop", label, client)

    private fun call(method: String, label: String, arguments: Any?): Reply =
        Reply(label, replies).also { messenger.channel.invoke(method, arguments, it) }

    override fun close() = device.dispose()
}

private fun checkCase(name: String, assertion: Probe.() -> Unit) {
    Probe().use(assertion)
    println("PASS $name")
}

fun main() {
    checkCase("stop error returns 0 and retains native ownership") {
        val voice = speak("voice")
        val tts = engine
        tts.finishInit()
        tick()
        val id = tts.played.single().id
        tts.stopCode = TextToSpeech.ERROR
        stop("refused").expect(0)
        check(tts.stopTargets == listOf(id))
        tick(1000)
        voice.expect()
        speak("blocked").expect(0)
        check(tts.played.size == 1)
        tts.done(id)
        tick()
        voice.expect(1)
    }

    checkCase("accepted stop needs terminal completion and stale work cannot touch the next voice") {
        val voice = speak("old")
        val tts = engine
        tts.finishInit()
        tick()
        val oldId = tts.played.single().id
        val timedOut = stop("silent stop")
        stop("duplicate pending").expect(0)
        check(tts.stopTargets == listOf(oldId))
        tick(749)
        timedOut.expect()
        voice.expect()
        tick(1)
        timedOut.expect(0)
        voice.expect()
        speak("still blocked").expect(0)
        check(tts.played.size == 1)

        val retry = stop("retry")
        retry.expect()
        check(tts.stopTargets == listOf(oldId, oldId))
        tick(100)
        tts.stopped(oldId)
        retry.expect()
        tick()
        voice.expect(0)
        retry.expect(1)
        check(replies.takeLast(2) == listOf("old" to 0, "retry" to 1))

        val next = speak("new", client = 2, locale = "en-US")
        val newPlayback = tts.played.last()
        check(newPlayback.id != oldId && newPlayback.locale.toLanguageTag() == "en-US")
        val stopNext = stop("stop new", client = 2)
        tts.stopped(oldId)
        tts.done(oldId)
        tick(650)
        next.expect()
        stopNext.expect()
        retry.expect(1)
        speak("new stays blocked", client = 2).expect(0)
        tts.stopped(newPlayback.id)
        tick()
        next.expect(0)
        stopNext.expect(1)
    }

    checkCase("a different client cannot stop an active or initializing owner") {
        val voice = speak("owner")
        val tts = engine
        stop("wrong client preparing", client = 2).expect(0)
        voice.expect()
        check(tts.stopTargets.isEmpty() && tts.shutdowns == 0)
        tts.finishInit()
        tick()
        val id = tts.played.single().id
        stop("wrong client active", client = 2).expect(0)
        voice.expect()
        check(tts.stopTargets.isEmpty())
        tts.done(id)
        tick()
        voice.expect(1)
    }

    checkCase("stop before initialization cancels without dispatch and ignores stale initialization") {
        val voice = speak("never spoken")
        val opening = engine
        val stop = stop("cancel init")
        voice.expect(0)
        stop.expect(1)
        check(opening.shutdowns == 1 && opening.played.isEmpty() && opening.stopTargets.isEmpty())
        val next = speak("next after init cancellation", client = 2)
        val nextEngine = engine
        check(opening !== nextEngine)
        opening.finishInit()
        tick()
        check(opening.played.isEmpty() && nextEngine.played.isEmpty())
        next.expect()
        nextEngine.finishInit()
        tick()
        val playback = nextEngine.played.single()
        check(playback.text == "next after init cancellation")
        nextEngine.done(playback.id)
        tick()
        next.expect(1)
    }

    checkCase("stop targets the current engine and switching back reuses the ready engine") {
        val koreanReply = speak("Korean", engine = "ko-engine")
        val korean = engine
        check(korean.name == "ko-engine")
        korean.finishInit()
        tick()
        val koreanId = korean.played.single().id
        korean.done(koreanId)
        tick()
        koreanReply.expect(1)

        val englishReply = speak("English", locale = "en-US", engine = "en-engine")
        val english = engine
        check(english.name == "en-engine" && english !== korean && korean.shutdowns == 0)
        english.finishInit()
        tick()
        val englishId = english.played.single().id
        val interrupted = stop("interrupt English")
        check(korean.stopTargets.isEmpty() && english.stopTargets == listOf(englishId))
        korean.stopped(koreanId)
        tick()
        englishReply.expect()
        interrupted.expect()
        english.stopped(englishId)
        tick()
        englishReply.expect(0)
        interrupted.expect(1)

        val returned = speak("returned to Korean", engine = "ko-engine")
        check(TextToSpeech.instances.size == 2 && korean.played.last().text == "returned to Korean")
        korean.done(korean.played.last().id)
        tick()
        returned.expect(1)
    }
}
