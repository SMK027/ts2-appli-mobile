# Connexion à la base de données — Documentation technique

## Architecture générale

L'application Nestvia ne se connecte pas directement à une base de données. Elle communique avec une **API REST** hébergée sur `https://api.leofranz.fr/nestvia`, qui sert d'intermédiaire avec la base de données côté serveur.

```
+--------------+       HTTPS/JSON        +--------------+       SQL        +------------+
| App Flutter  | <---------------------> |  API REST    | <--------------> |    BDD     |
| (Dio client) |                         |  (Serveur)   |                  |   (MySQL)  |               +--------------+                         +--------------+                  +------------+
```

---

## Configuration de l'API

**Fichier :** `lib/config/api_config.dart`

| Paramètre            | Valeur                                       | Description                                  |
|-----------------------|----------------------------------------------|----------------------------------------------|
| `baseUrl`             | `https://api.leofranz.fr/nestvia`            | URL de base de l'API (surchargeable via env) |
| `connectTimeout`      | 10 secondes                                  | Délai max pour établir la connexion          |
| `receiveTimeout`      | 30 secondes                                  | Délai max pour recevoir la réponse           |

### Surcharge de l'URL de base

L'URL de l'API peut être remplacée à la compilation via une variable d'environnement Dart :

```bash
flutter run --dart-define=API_BASE_URL=https://staging-api.leofranz.fr/nestvia
```

---

## Endpoints disponibles

| Constante                        | Chemin             | Usage                              |
|----------------------------------|--------------------|------------------------------------|
| `loginEndpoint`                  | `/auth/login`      | Authentification (POST)            |
| `biensEndpoint`                  | `/biens`           | Liste / recherche de biens (GET)   |
| `featuredPropertiesEndpoint`     | `/biens`           | Biens en vedette (GET)             |
| `nearbyPropertiesEndpoint`       | `/biens`           | Biens proches (GET + lat/lng)      |
| `favorisEndpoint`                | `/favoris`         | Gestion des favoris                |
| `reservationsEndpoint`           | `/reservations`    | Gestion des réservations           |
| `tarifsEndpoint`                 | `/tarifs`          | Tarifs                             |
| `compteEndpoint`                 | `/compte`          | Informations du compte utilisateur |
| `notificationsEndpoint`          | `/notifications`   | Notifications                      |
| `avisEndpoint`                   | `/avis`            | Avis utilisateurs                  |
| `communesEndpoint`               | `/communes`        | Liste/recherche de communes        |
| `typesBienEndpoint`              | `/types-bien`      | Types de biens                     |

### URLs externes (hors API)

| Constante           | URL                                                       | Usage                     |
|----------------------|-----------------------------------------------------------|---------------------------|
| `registerUrl`        | `https://nestvia.leofranz.fr/connexion_inscription.php`   | Inscription (webview)     |
| `forgotPasswordUrl`  | `https://nestvia.leofranz.fr/connexion_inscription.php` | Mot de passe oublié     |

---

## Client HTTP — `ApiService`

**Fichier :** `lib/services/api_service.dart`

### Pattern Singleton

`ApiService` utilise un **singleton** pour garantir une instance unique du client Dio dans toute l'application :

```dart
static final ApiService _instance = ApiService._internal();
factory ApiService() => _instance;
```

### Configuration Dio

Le client HTTP est configuré avec :
- L'URL de base depuis `ApiConfig.baseUrl`
- Les timeouts depuis `ApiConfig`
- Les headers par défaut : `Content-Type: application/json` et `Accept: application/json`
- Un intercepteur pour la gestion des requêtes et erreurs

### Authentification JWT

Le token JWT est injecté dans les headers via :

```dart
void setAuthToken(String token) {
  _dio.options.headers['Authorization'] = 'Bearer $token';
}
```

Et retiré lors de la déconnexion :

```dart
void clearAuthToken() {
  _dio.options.headers.remove('Authorization');
}
```

---

## Authentification — `AuthService`

**Fichier :** `lib/services/auth_service.dart`

### Flux de connexion

1. L'utilisateur saisit email + mot de passe
2. `POST /auth/login` avec les identifiants en JSON
3. L'API retourne un **token JWT** en cas de succès
4. Le token est stocké de manière sécurisée via `flutter_secure_storage`
5. Le token est injecté dans les headers Dio pour les requêtes futures

### Stockage sécurisé

Le token est persisté avec `FlutterSecureStorage` sous la clé `auth_token` :
- **Android** : Android Keystore
- **iOS** : iOS Keychain

### Initialisation au démarrage

Au lancement de l'app, `initToken()` vérifie si un token existe déjà et le réinjecte automatiquement dans le client HTTP.

---

## Gestion des erreurs réseau

`ApiService.handleError()` traduit les erreurs Dio en messages utilisateur lisibles :

| Type d'erreur                    | Message affiché                                              |
|----------------------------------|--------------------------------------------------------------|
| Timeout (connexion/envoi/réception) | « La connexion a expiré. Vérifiez votre réseau. »         |
| Erreur de connexion              | « Impossible de contacter le serveur. Vérifiez votre connexion internet. » |
| HTTP 401                         | « Identifiants incorrects ou session expirée. »             |
| HTTP 404                         | « Ressource introuvable. » (ou message API)                 |
| HTTP 409                         | « Conflit : la ressource existe déjà. » (ou message API)    |
| HTTP 429                         | « Trop de requêtes. Veuillez réessayer plus tard. »          |
| HTTP 5xx                         | « Le serveur est temporairement indisponible. » (ou message API) |

---

## Schéma du flux d'authentification

```
+-----------+    POST /auth/login    +----------+
|  Login    |  --------------------> |   API    |
|  Screen   |                        |  Server  |
|           |  <-------------------  |          |
+-----------+    { "token": "..." }  +----------+
      |
      v
+----------------------+
| FlutterSecureStorage |  <- stockage persistant du JWT
+----------------------+
      |
      v
+----------------------+
| Dio Headers          |  <- Authorization: Bearer <token>
| (ApiService)         |
+----------------------+
```
