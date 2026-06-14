class AppConfig {
  static const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://YOUR_PROJECT.supabase.co',
  );
  static const supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'YOUR_SUPABASE_ANON_KEY',
  );
  static const revenueCatApiKey = String.fromEnvironment(
    'REVENUECAT_API_KEY',
    defaultValue: 'YOUR_REVENUECAT_KEY',
  );

  static const whisperEdgeFunctionUrl = '$supabaseUrl/functions/v1/whisper-proxy';
  static const elevenLabsEdgeFunctionUrl = '$supabaseUrl/functions/v1/elevenlabs-proxy';

  static const enableWhisperSTT = true;
  static const enableElevenLabsTTS = true;
  static const maxFreeVocabLists = 3;
  static const maxFreeWordsPerList = 50;
  static const maxFreeCardsPerDay = 10;
}
