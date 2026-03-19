/// Configuration de l'API Nestvia
/// Issue #1 - [INIT] : Stocker l'URL de l'API dans un fichier de configuration
class ApiConfig {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://api.leofranz.fr/nestvia',
  );

  static const String loginEndpoint = '/auth/login';
  static const String refreshEndpoint = '/auth/refresh';
  static const String featuredPropertiesEndpoint = '/biens';
  static const String nearbyPropertiesEndpoint = '/biens';
  static const String favorisEndpoint = '/favoris';
  static const String reservationsEndpoint = '/reservations';
  static const String biensEndpoint = '/biens';
  static const String tarifsEndpoint = '/tarifs';
  static const String compteEndpoint = '/compte';
  static const String comptePasswordEndpoint = '/compte/password';
  static const String notificationsEndpoint = '/notifications';
  static const String avisEndpoint = '/avis';
  static const String communesEndpoint = '/communes';
  static const String typesBienEndpoint = '/types-bien';

  static const String registerUrl = 'https://nestvia.leofranz.fr/connexion_inscription.php';
  static const String forgotPasswordUrl = 'https://nestvia.leofranz.fr/connexion_inscription.php';

  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 30);
}
