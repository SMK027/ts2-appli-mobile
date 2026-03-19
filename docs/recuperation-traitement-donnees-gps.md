# Récupération des données GPS et traitement - Documentation technique

## 1. Objectif

Ce document explique comment l'application Nestvia:

- récupère la position GPS de l'utilisateur;
- gère les permissions et cas d'échec;
- transforme ces coordonnées en données exploitables UI;
- utilise les coordonnées pour interroger l'API et afficher les biens proches.

Le document est basé sur l'implémentation actuelle du projet Flutter.

---

## 2. Vue d'ensemble du pipeline GPS

```text
App (HomeScreen / MapScreen)
        |
        v
LocationService.getCurrentPosition()
  - vérifie service GPS
  - vérifie/demande permission
  - lit position (lat, lng)
        |
        +--> null (indisponible/refusé/erreur)
        |      - fallback UI: message position indisponible
        |      - fallback carte: centre France
        |
        +--> Position valide
               - HomeScreen: reverse geocoding (ville)
               - HomeScreen: GET /biens?lat=...&lng=...
               - MapScreen: marqueur utilisateur + recentrage
```

---

## 3. Composants techniques impliqués

## Services

- `lib/services/location_service.dart`
- `lib/services/property_service.dart`
- `lib/services/api_service.dart`

## UI

- `lib/screens/home_screen.dart`
- `lib/screens/map_screen.dart`

## Modèle de données

- `lib/models/property.dart`

## Dépendances Flutter

- `geolocator` (acquisition position)
- `geocoding` (reverse geocoding)
- `flutter_map` + `latlong2` (affichage cartographique)

---

## 4. Acquisition GPS: service dédié

Fichier: `lib/services/location_service.dart`

Méthode centrale:

- `Future<Position?> getCurrentPosition()`

Logique exécutée:

1. Vérifier si le service de localisation est activé:
   - `Geolocator.isLocationServiceEnabled()`
   - si `false` -> `return null`

2. Vérifier la permission:
   - `Geolocator.checkPermission()`
   - si `denied` -> `Geolocator.requestPermission()`
   - si encore `denied` -> `return null`

3. Gérer le refus permanent:
   - si `deniedForever` -> `return null`

4. Lire la position:
   - `Geolocator.getCurrentPosition(locationSettings: LocationSettings(accuracy: LocationAccuracy.medium))`

5. Gérer les exceptions:
   - `catch (_) { return null; }`
   - couvre notamment les plateformes non supportées (commentaire explicite pour Linux desktop).

Contrat de la méthode:

- retourne un objet `Position` en cas de succès;
- retourne `null` pour tout cas non exploitable (service OFF, permission refusée, erreur runtime, plateforme non supportée).

---

## 5. Traitement dans HomeScreen

Fichier: `lib/screens/home_screen.dart`

Méthode: `_loadNearby()`

## 5.1 Récupération de la position

- appelle `LocationService().getCurrentPosition()`.

Cas `position == null`:

- `_locationLabel = 'Position indisponible'`
- `_loadingNearby = false`
- aucun appel API de proximité.

## 5.2 Normalisation d'un libellé de localisation

Si position valide:

1. Valeur initiale:
   - label par défaut basé sur les coordonnées brutes
   - format: `latitude(4 décimales), longitude(4 décimales)`

2. Tentative de reverse geocoding:
   - `placemarkFromCoordinates(lat, lng)`
   - extraction de la ville depuis `locality`, sinon `subAdministrativeArea`, sinon `administrativeArea`

3. En cas d'échec geocoding:
   - conservation du label coordonnées (fallback).

## 5.3 Requête API des biens proches

- appel `PropertyService().getNearbyProperties(latitude, longitude)`
- alimente `_nearbyProperties` puis fin de chargement.

Effet UI:

- la section "Près de vous" est basée sur la position GPS si disponible;
- sinon l'app reste fonctionnelle avec un état de dégradation non bloquant.

---

## 6. Traitement dans MapScreen

Fichier: `lib/screens/map_screen.dart`

Méthode: `_loadData()`

## 6.1 Position utilisateur et fallback géographique

État initial:

- `_userPosition = LatLng(46.603354, 1.888334)` (centre de la France)
- `_hasUserPosition = false`

Au chargement:

- appel `LocationService().getCurrentPosition()`;
- si succès:
  - `_userPosition = LatLng(position.latitude, position.longitude)`
  - `_hasUserPosition = true`
- sinon:
  - conservation du centre France.

## 6.2 Affichage cartographique dépendant GPS

Si `_hasUserPosition == true`:

- ajout d'un marqueur utilisateur (point bleu) dans `MarkerLayer`;
- activation utile du bouton de recentrage (`_centerOnUser`).

Si `_hasUserPosition == false`:

- pas de marqueur utilisateur;
- bouton de géolocalisation affiché en gris.

## 6.3 Filtrage géographique des biens

Indépendamment de la position utilisateur, les biens affichés sur la carte sont filtrés pour ne garder que ceux qui ont des coordonnées exploitables:

- `p.latitude != null && p.longitude != null`

Ce filtre protège la génération des marqueurs et évite les erreurs runtime liées aux coordonnées absentes.

---

## 7. Traitement API des coordonnées

Fichier: `lib/services/property_service.dart`

Méthode: `getNearbyProperties({required double latitude, required double longitude})`

Comportement:

1. Requête HTTP:

- `GET /biens`
- query params:
  - `lat`: latitude utilisateur
  - `lng`: longitude utilisateur

2. Désérialisation:

- conversion du JSON en `List<Property>`.

3. Enrichissement:

- `enrichProperties(properties)` complète photos et tarifs si absents.

4. Gestion d'erreur:

- retourne `[]` en cas d'échec réseau/API.

---

## 8. Modèle de donnée GPS côté client

Fichier: `lib/models/property.dart`

Attributs impliqués:

- `latitude` (double?)
- `longitude` (double?)
- `distanceKm` (double?)

Règles de parsing:

- conversion robuste via `_toDouble(dynamic value)`;
- prise en charge des formats numériques ou string;
- null-safe si valeur manquante/invalide.

Effet:

- le client peut exploiter des réponses API hétérogènes sans crash.

---

## 9. Gestion des erreurs et stratégie de fallback

La stratégie générale est "graceful degradation":

1. GPS indisponible ou permission refusée:
   - pas d'erreur bloquante utilisateur;
   - Home: message "Position indisponible";
   - Map: centre France + carte opérationnelle.

2. Geocoding indisponible:
   - utilisation des coordonnées en texte.

3. API proximité indisponible:
   - liste proche vide;
   - application toujours utilisable (autres sections disponibles).

4. Plateforme non supportée par geolocator:
   - exception absorbée dans `LocationService`;
   - retour `null`.

---

## 10. Permissions et configuration plateforme

## Android

Fichier: `android/app/src/main/AndroidManifest.xml`

Permissions présentes:

- `android.permission.ACCESS_FINE_LOCATION`
- `android.permission.ACCESS_COARSE_LOCATION`

## iOS

Fichier: `ios/Runner/Info.plist`

Constat actuel:

- aucune clé de description d'usage localisation n'est présente (`NSLocationWhenInUseUsageDescription`, etc.).

Impact:

- la demande de permission localisation peut échouer ou être refusée au runtime sur iOS.

Action recommandée:

- ajouter au minimum `NSLocationWhenInUseUsageDescription` avec un message utilisateur explicite.

## Linux desktop

Constat code:

- le service capture explicitement les exceptions liées aux plateformes non supportées.

Impact:

- retour `null` attendu, sans plantage.

---

## 11. Séquence d'exécution (exemple HomeScreen)

```text
HomeScreen._loadNearby()
   -> LocationService.getCurrentPosition()
      -> check service
      -> check/request permission
      -> getCurrentPosition()
   -> if null: label "Position indisponible" + stop
   -> else:
      -> reverse geocoding (ville)
      -> PropertyService.getNearbyProperties(lat, lng)
         -> GET /biens?lat=...&lng=...
         -> mapping Property + enrichissement
      -> update UI "Près de vous"
```

---

## 12. Points de vigilance techniques

1. La précision est fixée à `LocationAccuracy.medium`:
   - compromis performance/batterie;
   - adapté à un usage de proximité général, pas à la navigation fine.

2. Le système lit une position ponctuelle (one-shot):
   - pas de suivi continu (`getPositionStream`) dans l'implémentation actuelle.

3. Les erreurs GPS sont silencieuses pour l'utilisateur:
   - choix UX volontaire pour ne pas bloquer;
   - peut être complété par des messages guidant l'activation GPS/permissions.

4. Le tri "proximité" dépend de l'API:
   - l'app envoie lat/lng;
   - la logique de calcul distance et tri est côté backend.

---

## 13. Recommandations d'amélioration

1. Ajouter la configuration iOS de permission localisation:
   - `NSLocationWhenInUseUsageDescription` dans `Info.plist`.

2. Ajouter un état UI explicite quand la permission est refusée définitivement:
   - proposer un CTA vers les réglages système.

3. Mettre en cache la dernière position connue:
   - améliore l'expérience au redémarrage et hors-ligne partiel.

4. Ajouter une télémétrie technique (logs non sensibles):
   - taux de permission refusée;
   - taux d'échec geocoding;
   - latence moyenne acquisition GPS.

5. Envisager un mode "actualisation position" sur la carte:
   - position one-shot actuelle conservée tant que l'écran n'est pas rechargé.
