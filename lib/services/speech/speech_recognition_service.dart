import 'package:speech_to_text/speech_to_text.dart' as stt;

/// Service de reconnaissance vocale pour les réponses du quiz
class SpeechRecognitionService {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isInitialized = false;
  bool _isListening = false;

  /// Obtenir l'état d'écoute
  bool get isListening => _isListening;

  /// Vérifier si le service est initialisé
  bool get isInitialized => _isInitialized;

  /// Initialiser le service de reconnaissance vocale
  Future<bool> initialize() async {
    if (_isInitialized) {
      print('✅ STT déjà initialisé');
      return true;
    }

    try {
      _isInitialized = await _speech.initialize(
        onError: (error) {
          print('❌ Erreur STT: ${error.errorMsg}');
        },
        onStatus: (status) {
          print('📊 Statut STT: $status');
          _isListening = status == 'listening';
        },
      );

      if (_isInitialized) {
        print('✅ STT initialisé avec succès');
        
        // Afficher les langues disponibles
        final locales = await _speech.locales();
        print('🌍 ${locales.length} langues disponibles');
        
        // Vérifier que FR et KO sont disponibles
        final hasFrench = locales.any((l) => l.localeId.startsWith('fr'));
        final hasKorean = locales.any((l) => l.localeId.startsWith('ko'));
        
        if (hasFrench) print('✅ Français disponible');
        if (hasKorean) print('✅ Coréen disponible');
        
        if (!hasFrench || !hasKorean) {
          print('⚠️ Certaines langues manquent, vérifiez votre système');
        }
      } else {
        print('❌ Échec initialisation STT');
      }

      return _isInitialized;
    } catch (e) {
      print('❌ Erreur lors de l\'initialisation STT: $e');
      return false;
    }
  }

  /// Démarrer l'écoute avec callback
  /// 
  /// langCode: Code de langue (fr, ko, en)
  /// onResult: Callback appelé avec le texte reconnu
  /// onConfidence: Callback appelé avec le niveau de confiance (0.0-1.0)
  Future<bool> startListening({
    required String langCode,
    required Function(String) onResult,
    Function(double)? onConfidence,
  }) async {
    if (!_isInitialized) {
      print('⚠️ STT non initialisé');
      return false;
    }

    if (_isListening) {
      print('⚠️ STT déjà en écoute');
      return false;
    }

    try {
      // Convertir le code de langue en locale
      final localeId = _getLocaleId(langCode);
      
      print('🎤 Démarrage écoute - Langue: $localeId');

      final success = await _speech.listen(
        onResult: (result) {
          if (result.finalResult) {
            print('✅ Résultat final: "${result.recognizedWords}"');
            print('   Confiance: ${result.confidence}');

            onResult(result.recognizedWords);
            onConfidence?.call(result.confidence);
          } else {
            // Résultat partiel (en cours de reconnaissance)
            print('🔄 Partiel: "${result.recognizedWords}"');
          }
        },
        localeId: localeId,
        listenOptions: stt.SpeechListenOptions(
          cancelOnError: true,
          listenMode: stt.ListenMode.dictation,
        ),
        listenFor: const Duration(seconds: 10), // Max 10s d'écoute
        pauseFor: const Duration(seconds: 3), // Pause après 3s de silence
      );

      if (success) {
        _isListening = true;
        print('✅ Écoute démarrée');
      } else {
        print('❌ Échec démarrage écoute');
      }

      return success;
    } catch (e) {
      print('❌ Erreur lors du démarrage de l\'écoute: $e');
      return false;
    }
  }

  /// Arrêter l'écoute
  Future<void> stopListening() async {
    if (_isListening) {
      await _speech.stop();
      _isListening = false;
      print('🛑 Écoute arrêtée');
    }
  }

  /// Annuler l'écoute
  Future<void> cancelListening() async {
    if (_isListening) {
      await _speech.cancel();
      _isListening = false;
      print('🚫 Écoute annulée');
    }
  }

  /// Convertir le code de langue en locale ID
  String _getLocaleId(String langCode) {
    switch (langCode.toLowerCase()) {
      case 'fr':
        return 'fr-FR'; // Français (France)
      case 'ko':
        return 'ko-KR'; // Coréen (Corée du Sud)
      case 'en':
        return 'en-US'; // Anglais (États-Unis)
      case 'es':
        return 'es-ES'; // Espagnol (Espagne)
      case 'de':
        return 'de-DE'; // Allemand (Allemagne)
      case 'it':
        return 'it-IT'; // Italien (Italie)
      case 'ja':
        return 'ja-JP'; // Japonais (Japon)
      case 'zh':
        return 'zh-CN'; // Chinois (Chine)
      default:
        return 'en-US'; // Fallback vers anglais
    }
  }

  /// Vérifier si une langue est disponible
  Future<bool> isLanguageAvailable(String langCode) async {
    if (!_isInitialized) {
      await initialize();
    }

    final locales = await _speech.locales();
    final localeId = _getLocaleId(langCode);
    
    return locales.any((l) => l.localeId == localeId);
  }

  /// Obtenir toutes les langues disponibles
  Future<List<String>> getAvailableLanguages() async {
    if (!_isInitialized) {
      await initialize();
    }

    final locales = await _speech.locales();
    return locales.map((l) => l.localeId).toList();
  }

  /// Libérer les ressources
  void dispose() {
    _speech.stop();
    _isInitialized = false;
    _isListening = false;
    print('🗑️ STT disposed');
  }
}
