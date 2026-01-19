import '../services/audio/audio_service.dart';
import '../services/audio/local_audio_service.dart';
import '../services/audio/backend_audio_service.dart';

/// Configuration centrale de l'application
/// Gère le mode de déploiement et la création des services
class AppConfig {
  // ========================================
  // MODE DE DÉPLOIEMENT
  // ========================================
  
  /// Mode actuel de l'application
  /// 
  /// Pour développement local : DeploymentMode.local
  /// Pour production cloud : DeploymentMode.cloud
  static const DeploymentMode mode = DeploymentMode.local;
  
  // ========================================
  // CONFIGURATION BACKEND (pour mode cloud)
  // ========================================
  
  /// URL du backend en production
  /// Exemple : 'https://api.vocabularyapp.com'
  static const String backendUrl = 'https://your-backend.com';
  
  /// URL du backend en développement local
  /// Exemple : 'http://localhost:3000' ou 'http://192.168.1.10:3000'
  static const String localBackendUrl = 'http://localhost:3000';
  
  /// Token d'authentification (sera défini après login)
  static String? authToken;
  
  // ========================================
  // FACTORY DE SERVICES
  // ========================================
  
  /// Crée le service audio approprié selon le mode
  static AudioService createAudioService() {
    switch (mode) {
      case DeploymentMode.local:
        return LocalAudioService();
        
      case DeploymentMode.cloud:
        return BackendAudioService();
        
      case DeploymentMode.localBackend:
        // Utile pour tester le backend en local
        return BackendAudioService(baseUrl: localBackendUrl);
    }
  }
  
  // ========================================
  // HELPERS
  // ========================================
  
  /// Headers HTTP pour les requêtes backend
  static Map<String, String> getHeaders() {
    return {
      'Content-Type': 'application/json',
      if (authToken != null) 'Authorization': 'Bearer $authToken',
    };
  }
  
  /// Indique si l'app utilise un backend (cloud ou local)
  static bool get usesBackend => 
      mode == DeploymentMode.cloud || mode == DeploymentMode.localBackend;
  
  /// Indique si l'app fonctionne en mode entièrement local
  static bool get isFullyLocal => mode == DeploymentMode.local;
}

/// Modes de déploiement disponibles
enum DeploymentMode {
  /// Mode local : génération ElevenLabs directe, stockage local
  /// - API key exposée dans l'app
  /// - Pas de backend requis
  /// - Parfait pour développement et usage personnel
  local,
  
  /// Mode cloud : backend hébergé, stockage cloud
  /// - API key sécurisée côté serveur
  /// - Cache partagé entre utilisateurs
  /// - Prêt pour distribution publique
  cloud,
  
  /// Mode backend local : backend sur PC local, pour tests
  /// - Utile pour développer le backend
  /// - Teste l'architecture cloud en local
  localBackend,
}
