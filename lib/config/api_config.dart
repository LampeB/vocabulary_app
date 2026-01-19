class ApiConfig {
  // ==================== ELEVENLABS TTS ====================

  // Clé API ElevenLabs - à configurer dans api_config_local.dart
  static const String elevenLabsApiKey =
      String.fromEnvironment('ELEVENLABS_API_KEY', defaultValue: '');
  static const String elevenLabsApiUrl = 'https://api.elevenlabs.io/v1';

  // Voix par langue
  static const Map<String, String> elevenLabsVoiceIds = {
    'fr': 'pNInz6obpgDQGcFmaJgB', // Adam (French)
    'ko': '21m00Tcm4TlvDq8ikWAM', // Rachel (peut faire du coréen)
    'en': '21m00Tcm4TlvDq8ikWAM', // Rachel (English)
  };

  // ==================== OPENAI WHISPER STT ====================

  // Clé API OpenAI - à configurer dans api_config_local.dart
  static const String openAiApiKey =
      String.fromEnvironment('OPENAI_API_KEY', defaultValue: '');
  static const String whisperApiUrl =
      'https://api.openai.com/v1/audio/transcriptions';
  static const String whisperModel = 'whisper-1';

  // ==================== CLAUDE API (ANTHROPIC) ====================

  // Clé API Claude - à configurer dans api_config_local.dart
  static const String claudeApiKey =
      String.fromEnvironment('ANTHROPIC_API_KEY', defaultValue: '');
  static const String claudeApiUrl = 'https://api.anthropic.com/v1/messages';
  static const String claudeModel = 'claude-sonnet-4-20250514';
  static const String claudeVersion = '2023-06-01';

  // ==================== MODE DE DÉVELOPPEMENT ====================

  // Utiliser les services gratuits au lieu des APIs payantes
  static const bool useFreeTTS = true; // true = Flutter TTS natif
  static const bool useFreeSTT = true; // true = speech_to_text natif
  static const bool useClaudeForParsing = false; // false = parsing manuel

  // ==================== TIMEOUTS ====================

  static const Duration apiTimeout = Duration(seconds: 30);
  static const Duration ttsTimeout = Duration(seconds: 10);
  static const Duration sttTimeout = Duration(seconds: 5);

  // ==================== RETRY ====================

  static const int maxRetries = 3;
  static const Duration retryDelay = Duration(seconds: 2);

  // ==================== HEADERS HELPERS ====================

  static Map<String, String> getElevenLabsHeaders() {
    return {
      'xi-api-key': elevenLabsApiKey,
      'Content-Type': 'application/json',
    };
  }

  static Map<String, String> getOpenAiHeaders() {
    return {
      'Authorization': 'Bearer $openAiApiKey',
      'Content-Type': 'multipart/form-data',
    };
  }

  static Map<String, String> getClaudeHeaders() {
    return {
      'x-api-key': claudeApiKey,
      'anthropic-version': claudeVersion,
      'Content-Type': 'application/json',
    };
  }

  // ==================== VALIDATION ====================

  static bool get isElevenLabsConfigured =>
      elevenLabsApiKey != 'YOUR_ELEVENLABS_API_KEY' &&
      elevenLabsApiKey.isNotEmpty;

  static bool get isOpenAiConfigured =>
      openAiApiKey != 'YOUR_OPENAI_API_KEY' && openAiApiKey.isNotEmpty;

  static bool get isClaudeConfigured =>
      claudeApiKey != 'YOUR_CLAUDE_API_KEY' && claudeApiKey.isNotEmpty;

  static bool get canUsePremiumTTS => !useFreeTTS && isElevenLabsConfigured;
  static bool get canUsePremiumSTT => !useFreeSTT && isOpenAiConfigured;
  static bool get canUseClaudeParsing =>
      useClaudeForParsing && isClaudeConfigured;
}
