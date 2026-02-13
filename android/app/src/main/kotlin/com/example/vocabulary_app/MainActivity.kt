package com.example.vocabulary_app

import android.content.ComponentName
import android.content.Intent
import android.net.Uri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.vocabulary_app/settings"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method == "openVoiceInputSettings") {
                    result.success(openSpeechLanguageSettings())
                } else {
                    result.notImplemented()
                }
            }
    }

    private fun openSpeechLanguageSettings(): Boolean {
        // Try multiple intents in order — targeting STT (speech recognition),
        // NOT TTS (text-to-speech). These are different language packs on Android.
        val intents = listOf(
            // 1. Google offline speech recognition languages list (direct)
            Intent(Intent.ACTION_MAIN).apply {
                component = ComponentName(
                    "com.google.android.googlequicksearchbox",
                    "com.google.android.apps.gsa.settingsui.VoiceSearchLanguagesActivity"
                )
            },
            // 2. Google Speech Services settings (manages STT engine)
            Intent(android.provider.Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                data = Uri.parse("package:com.google.android.tts")
            },
            // 3. Google app info page (user can navigate: Manage → Languages)
            Intent(android.provider.Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                data = Uri.parse("package:com.google.android.googlequicksearchbox")
            },
            // 4. General language & input settings (last fallback)
            Intent(android.provider.Settings.ACTION_INPUT_METHOD_SETTINGS),
        )

        for (intent in intents) {
            try {
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                startActivity(intent)
                return true
            } catch (_: Exception) {
                // This intent didn't work, try the next one
            }
        }
        return false
    }
}
