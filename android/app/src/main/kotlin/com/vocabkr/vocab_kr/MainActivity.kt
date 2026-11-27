package com.vocabkr.vocab_kr

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.TimeZone

class MainActivity : FlutterActivity() {
    private var systemSpeech: SystemSpeechCapture? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val systemChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "vocab_kr/system_speech")
        val system = SystemSpeechCapture(applicationContext) { method, payload ->
            systemChannel.invokeMethod(method, payload)
        }
        systemSpeech = system
        systemChannel.setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "supportsOnDeviceRecognition" -> result.success(system.supportsOnDevice())
                    "listen" -> result.success(system.start(
                        call.argument<Int>("session") ?: error("Missing session ID"),
                        call.argument<String>("locale") ?: error("Missing speech locale"),
                        call.argument<Boolean>("onDevice") ?: false,
                    ))
                    "stop" -> result.success(system.stop(
                        call.argument<Int>("session") ?: error("Missing session ID")
                    ))
                    else -> result.notImplemented()
                }
            } catch (error: Exception) {
                result.error("system_speech", error.message, null)
            }
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "vocab_kr/device_time_zone")
            .setMethodCallHandler { call, result ->
                if (call.method == "get") result.success(TimeZone.getDefault().id)
                else result.notImplemented()
            }
        val recognizer = PcmSpeechRecognizer(applicationContext)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "vocab_kr/pcm_speech")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isSupported" ->
                        result.success(PcmSpeechRecognizer.isSupported(applicationContext))
                    "cancel" -> {
                        recognizer.cancel()
                        result.success(null)
                    }
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
                                        "isFinal" to outcome.isFinal,
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

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        try {
            systemSpeech?.dispose()
        } catch (error: Exception) {
            android.util.Log.w("SystemSpeechCapture", "Engine cleanup failed", error)
        }
        systemSpeech = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
