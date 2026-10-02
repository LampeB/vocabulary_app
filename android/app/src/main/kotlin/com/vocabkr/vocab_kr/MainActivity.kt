package com.vocabkr.vocab_kr

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val recognizer = PcmSpeechRecognizer(applicationContext)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "vocab_kr/pcm_speech")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isSupported" ->
                        result.success(PcmSpeechRecognizer.isSupported(applicationContext))
                    "recognize" -> {
                        val pcm = call.argument<ByteArray>("pcm")
                        val locale = call.argument<String>("locale")
                        if (pcm == null || locale == null) {
                            result.error("bad_args", "pcm and locale are required", null)
                            return@setMethodCallHandler
                        }
                        val sampleRate = call.argument<Int>("sampleRate") ?: 16000
                        val timeoutMs = (call.argument<Int>("timeoutMs") ?: 6000).toLong()
                        recognizer.recognize(pcm, locale, sampleRate, timeoutMs) { outcome ->
                            if (outcome.errorCode != null) {
                                result.error(
                                    "error_${outcome.errorCode}",
                                    "speech recognizer error ${outcome.errorCode}",
                                    outcome.elapsedMs,
                                )
                            } else {
                                result.success(
                                    mapOf(
                                        "texts" to outcome.texts,
                                        "confidences" to outcome.confidences.map { it.toDouble() },
                                        "elapsedMs" to outcome.elapsedMs,
                                    ),
                                )
                            }
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
