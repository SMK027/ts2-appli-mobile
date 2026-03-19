# Documentation technique — Système de notifications push locales

## Vue d'ensemble

Le système de notifications push de Nestvia utilise une architecture **hybride** :
- **Push locale en foreground** : déclenchée quand l'app est ouverte et récupère les notifications
- **Worker périodique en background** : interroge l'API toutes les 15 minutes, même app fermée, pour détecter les nouvelles notifications non lues
- **Déduplication persistée** : évite d'afficher deux fois la même notification
- **Filtrage UI** : masque les notifications marquées comme lues du flux visible

---

## Architecture générale

```
┌────────────────────────────────────────────────────────────────┐
│                    Nestvia Mobile App                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌──────────────────────────┐      ┌──────────────────────┐    │
│  │  NotificationService     │      │  Background Worker   │    │
│  │  (Foreground)            │      │  (WorkManager)       │    │
│  │                          │      │                      │    │
│  │  • getNotifications()    │      │  • Periodic check    │    │
│  │  • Local push trigger    │      │  • 15 min interval   │    │
│  │  • Dedup check           │      │  • Network required  │    │
│  │  • Polling (1 min)       │      │  • Token refresh     │    │
│  └────────┬─────────────────┘      └──────────┬───────────┘    │
│           │                                   │                │
│           └───────────────────┬───────────────┘                │
│                               │                                │
│                          ┌────▼─────────────┐                 │
│                          │ FlutterLocal     │                 │
│                          │ Notifications    │                 │
│                          │ (Android notify) │                 │
│                          └────┬─────────────┘                 │
│                               │                                │
└───────────────────────────────┼────────────────────────────────┘
                                │
                    ┌───────────▼──────────┐
                    │  Android System      │
                    │  Notification Panel  │
                    │  (Push visible)      │
                    └──────────────────────┘
                                │
                   ┌────────────▼──────────────┐
                   │  API Backend /nestvia    │
                   │  GET /notifications      │
                   │  (App + Background)      │
                   └──────────────────────────┘
```

---

## Flux détaillé

### 1. Démarrage de l'application

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService().initializeLocalPush();        // Init plugin
  await BackgroundNotificationService.initialize();          // Init WorkManager
  runApp(const NestviaApp());
}
```

**Étapes** :
1. Initialise le plugin `FlutterLocalNotificationsPlugin` (Android)
2. Demande la permission `POST_NOTIFICATIONS` (Android 13+)
3. Enregistre le worker périodique toutes les 15 minutes
4. Lance l'application

### 2. Polling en foreground (app ouverte)

**Lieu** : `lib/screens/main_nav_screen.dart` → `_loadUnreadCount()`

```dart
// Polling automatique toutes les 1 minute
_notifPollingTimer = Timer.periodic(const Duration(minutes: 1), (_) {
  _loadUnreadCount();
});

Future<void> _loadUnreadCount() async {
  final count = await NotificationService().getUnreadCount();
  // getUnreadCount() → getNotifications() → _notifyUnreadPush()
}
```

**Flux** :
1. Appelle `NotificationService().getNotifications()`
2. Récupère la liste `/notifications` de l'API
3. Pour chaque notification non lue : `_notifyUnreadPush()`

### 3. Envoi de push locale (foreground & background)

**Fonction principale** : `NotificationService._notifyUnreadPush()`

```dart
Future<void> _notifyUnreadPush(
  List<Map<String, dynamic>> notifications,
) async {
  final pushedKeys = await _loadPushedNotificationKeys();
  
  for (final notif in notifications) {
    if (_isRead(notif['is_read'])) continue;
    
    final uniqueKey = _notificationUniqueKey(notif);
    if (pushedKeys.contains(uniqueKey)) continue;  // Anti-duplication
    
    // Envoyer push locale
    await _localNotifications.show(
      _notificationId(notif),
      _notificationTitle(notif['type']),
      _notificationMessage(notif['type'], notif),
      NotificationDetails(...),
    );
    
    pushedKeys.add(uniqueKey);
  }
  
  await _savePushedNotificationKeys(pushedKeys);
}
```

**Clé unique** (anti-duplication) :
```dart
String _notificationUniqueKey(Map<String, dynamic> notif) {
  final id = _toInt(notif['id_notification']);
  if (id != null) return 'id:$id';
  
  // Fallback si pas d'ID direct
  final type = notif['type']?.toString() ?? '';
  final message = notif['message']?.toString() ?? '';
  final created = notif['date_created']?.toString() ?? '';
  return 'fallback:$type|$message|$created';
}
```

Les clés sont persistées dans `FlutterSecureStorage` sous :
- **Clé** : `pushed_notifications`
- **Format** : Liste JSON sérialisée : `["id:123", "id:456", "fallback:review|Laissez un avis|2026-03-19T10:00:00"]`

### 4. Worker périodique (app fermée)

**Service** : `lib/services/background_notification_service.dart`

```dart
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task != BackgroundNotificationService.periodicTaskName) {
      return true;
    }
    
    // 1. Initialiser les notifications locales
    final localNotifications = FlutterLocalNotificationsPlugin();
    await localNotifications.initialize(...);
    
    // 2. Charger et rafraîchir le token d'accès
    final token = await _loadAccessTokenWithRefresh();
    if (token == null) return true;  // Pas d'accès : passer
    
    // 3. Appeler l'API /notifications
    final response = await dio.get(ApiConfig.notificationsEndpoint);
    final notifications = response.data.cast<Map<String, dynamic>>();
    
    // 4. Déclencher les pushs pour les non lues
    // (même logique que foreground)
    for (final notif in notifications) {
      if (_isRead(notif['is_read'])) continue;
      // ... push locale
    }
    
    return true;
  });
}
```

**Renouvellement du token** :
```dart
Future<String?> _loadAccessTokenWithRefresh() async {
  // 1. Charger token stocké
  final token = await _storage.read(key: _tokenKey);
  if (token != null && token.isNotEmpty) return token;
  
  // 2. Sinon, utiliser refresh token pour obtenir un nouveau
  final refreshToken = await _storage.read(key: _refreshTokenKey);
  if (refreshToken == null) return null;
  
  // 3. POST /auth/refresh
  final response = await dio.post(
    ApiConfig.refreshEndpoint,
    data: {'refresh_token': refreshToken},
  );
  
  // 4. Sauvegarder les nouveaux tokens
  final newToken = response.data['token'];
  await _storage.write(key: _tokenKey, value: newToken);
  
  return newToken;
}
```

---

## Affichage et gestion des notifications

### Écran Notifications (`lib/screens/notifications_screen.dart`)

**Visibilité** : seules les notifications **non lues** s'affichent

```dart
List<Map<String, dynamic>> get _visibleNotifications =>
    _notifications.where((n) => !_isRead(n['is_read'])).toList();

// Dans le build()
itemCount: _visibleNotifications.length,
itemBuilder: (_, i) => _buildNotificationCard(_visibleNotifications[i]),
```

**Détection du statut lu** :
```dart
bool _isRead(dynamic value) {
  if (value is bool) return value;
  if (value is int) return value == 1;
  final s = value?.toString().toLowerCase();
  return s == '1' || s == 'true';
}
```

**Actions utilisateur** :

| Action | Effet |
|--------|-------|
| Tap sur notification | `PATCH /notifications/:id/read` → masque la notification |
| Swipe dismissal (gauche) | Supprime de la liste locale |
| "Tout marquer comme lu" | `PATCH` sur chaque non lue → toutes disparaissent |
| Laisser avis (review_request) | Dialog → `POST /avis` → marque comme lue |

---

## Gestion des permissions

### Android

**Manifest** (`android/app/src/main/AndroidManifest.xml`) :
```xml
<!-- Notifications push (Android 13+) -->
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>

<!-- Background work (WorkManager) -->
<uses-permission android:name="android.permission.WAKE_LOCK"/>
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>

<!-- Internet -->
<uses-permission android:name="android.permission.INTERNET"/>
```

**Runtime permission** (`FlutterLocalNotificationsPlugin`) :
```dart
final androidPlugin = _localNotifications
    .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
await androidPlugin?.requestNotificationsPermission();
```

Android 13+ demande la permission au runtime. Avant Android 13, la permission est automatiquement accordée.

### iOS

Actuellement **non implémenté**. Pour iOS, il faudrait :
1. Demander la permission via `requestNotificationPermissions()`
2. Implémenter le callback pour les actions push
3. Adapter `BackgroundNotificationService` pour `BGTaskScheduler` (iOS)

---

## Canaux de notifications

### Android

**Canal principal** : `nestvia_notifications_channel`
- Nom : " Notifications Nestvia"
- Importance : MAX
- Priorité : HIGH
- Son : Standard
- Vibration : Standard

```dart
const AndroidNotificationDetails(
  'nestvia_notifications_channel',
  'Notifications Nestvia',
  channelDescription: 'Notifications importantes de l\'application',
  importance: Importance.max,
  priority: Priority.high,
)
```

Les canaux sont immuables une fois créés : changer les propriétés ci-dessus nécessite de changer l'ID du canal.

---

## Déduplication et persistance

### Stockage des clés poussées

```
FlutterSecureStorage
└── pushed_notifications → JSON array
    ├── "id:123"
    ├── "id:456"
    └── "fallback:review|message|created"
```

**Limitation** : ce mécanisme local peut perdre l'historique si l'app est supprimée. Pour une vraie déduplication côté backend, il faudrait :
- Ajouter un champ `notification.is_sent` dans la table  
- Query backend pour les non envoyées au worker et marquer une fois poussées

---

## Types de notifications supportées

| Type | Titre | Message par défaut |
|------|-------|-------------------|
| `review_request` | "Nestvia - Avis demandé" | "Votre location est terminée, laissez un avis sur votre bien meublé." |
| `reservation` | "Nestvia - Réservation" | "Vous avez reçu une nouvelle notification." |
| `payment` | "Nestvia - Paiement" | "Vous avez reçu une nouvelle notification." |
| (autre) | "Nestvia - Nouvelle notification" | Message personnalisé (champ `message`) |

---

## Limitations actuelles et améliorations futures

### Limitations

| Limitation | Impact |
|-----------|--------|
| **Android uniquement** | Pas de background work sur iOS ; foreground only |
| **15 min minimum** | Android limite la fréquence des tâches périodiques |
| **Pas de FCM** | Juste une locale : pas de push quand app tuée |
| **Perte historique** | La liste des pushs disparaît si app supprimée |
| **Pas de son personnalisé** | Utilise le son système d'Android |

### Améliorations suggérées

1. **Implémenter FCM côté backend** :
   - Endpoint `/devices/register` pour sauvegarder le token FCM du mobile
   - Envoyer des vraies push Firebase depuis le backend
   - Fonctionnerait même app fermée/tuée

2. **Implémenter iOS** :
   - `BGTaskScheduler` pour background refresh
   - `UserNotifications` framework pour les permissions

3. **Ajouter un serveur de déduplication** :
   - Table `notification_sends` (id_user, id_notification, sent_at)
   - Backend ne renvoie que les non envoyées au mobile
   - Plus robuste que la persistance locale

4. **Notifications groupées** :
   - Utiliser les summary notifications Android pour regrouper les multiples pushs sous une seule

5. **Actions personnalisées** :
   - Boutons directs dans la notification (Répondre, Accepter, Refuser)
   - Callbacks pour agir sans ouvrir l'app complètement

---

## Fichiers clés

| Fichier | Rôle |
|---------|------|
| `lib/services/notification_service.dart` | Service principal HTTP + push locale |
| `lib/services/background_notification_service.dart` | Worker background periodique |
| `lib/screens/notifications_screen.dart` | UI notifications (foreground) |
| `lib/screens/main_nav_screen.dart` | Polling 1 min + badge non lu |
| `lib/main.dart` | Initialisation au démarrage |
| `pubspec.yaml` | Dépendances (flutter_local_notifications, workmanager) |
| `android/app/src/main/AndroidManifest.xml` | Permissions Android |

---

## Flux complet : d'une notification créée à la lecture par l'utilisateur

```
1. Admin crée notification sur le web panel
   ↓
2. Backend stocke dans DB (is_read=0)
   ↓
3. App ouverte → polling 1 min → GET /notifications
   ├─ Ou background worker → 15 min → GET /notifications
   ↓
4. NotificationService._notifyUnreadPush()
   ├─ Charge clés poussées
   ├─ Pour chaque notif non lue + jamais poussée
   │  └─ FlutterLocalNotifications.show() → Android push
   ├─ Sauvegarde clé poussée
   ↓
5. Utilisateur voit push sur téléphone
   ├─ Tap → ouvre app → NotificationsScreen
   │  └─ Affiche seulement notifications non lues
   ├─ Tap sur notif → PATCH /notifications/:id/read
   │  └─ Backend marque is_read=1
   ├─ App recharge → notif masquée
   └─ Prochaine requête /notifications ne la renverra pas (optionnel)
```

---

## Configuration WorkManager sous le capot

**Tâche périodique enregistrée** :
```dart
await Workmanager().registerPeriodicTask(
  'nestvia_notifications_periodic_check',
  'nestvia_notifications_periodic_check',
  frequency: const Duration(minutes: 15),
  initialDelay: const Duration(minutes: 15),
  existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
  constraints: Constraints(networkType: NetworkType.connected),
);
```

- **initialDelay** : 15 min avant la première exécution
- **frequency** : toutes les 15 min après
- **networkType: connected** : ne s'exécute que si connecté au net
- **ExistingPeriodicWorkPolicy.keep** : ne crée pas de tâche dupliquée si déjà enregistrée

Android peut ajouter jusqu'à 5 min de délai selon les conditions du système.

