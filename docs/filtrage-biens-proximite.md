# Documentation technique — Filtrage des biens à proximité

## Objectif

Afficher dans la section **« Près de vous »** de l'écran d'accueil uniquement les biens situés dans un rayon de **35 km** autour de la position GPS du téléphone.

---

## Architecture du flux

```
┌──────────────┐     getCurrentPosition()     ┌──────────────────┐
│  Téléphone   │ ──────────────────────────►   │ LocationService  │
│  (GPS)       │ ◄──────────────────────────   │                  │
└──────────────┘     Position(lat, lng)        └──────────────────┘
       │
       │  lat, lng
       ▼
┌──────────────────┐   GET /biens?lat=...&lng=...   ┌─────────────┐
│ PropertyService  │ ─────────────────────────────►  │  API REST   │
│ getNearbyProps() │ ◄─────────────────────────────  │  /nestvia   │
└──────────────────┘   List<Property> (JSON)         └─────────────┘
       │
       │  properties (distanceKm peut être null)
       ▼
┌─────────────────────────────────────────────────┐
│  Calcul distance côté client (Geolocator)       │
│  Geolocator.distanceBetween(userLat, userLng,   │
│                              bienLat, bienLng)  │
│  → distanceKm = meters / 1000                   │
└─────────────────────────────────────────────────┘
       │
       │  properties avec distanceKm renseigné
       ▼
┌─────────────────────────────────────────────────┐
│  Filtre _filteredNearby                         │
│  ► distanceKm != null                           │
│  ► distanceKm <= 35.0                           │
│  ► + filtre catégorie si sélectionnée           │
└─────────────────────────────────────────────────┘
       │
       ▼
   Affichage NearbyPropertyItem (avec distance)
```

---

## Fichiers impliqués

| Fichier | Rôle |
|---------|------|
| `lib/services/location_service.dart` | Récupération de la position GPS via Geolocator |
| `lib/services/property_service.dart` | Appel API `/biens` avec paramètres `lat`/`lng` |
| `lib/models/property.dart` | Modèle `Property` avec champs `latitude`, `longitude`, `distanceKm` |
| `lib/screens/home_screen.dart` | Orchestration : chargement, calcul distance, filtrage, affichage |
| `lib/widgets/nearby_property_item.dart` | Widget d'affichage d'un bien avec sa distance |

---

## Détail des composants

### 1. Récupération GPS — `LocationService`

**Fichier :** `lib/services/location_service.dart`

```dart
Future<Position?> getCurrentPosition() async {
  // 1. Vérifie si le service de localisation est activé
  // 2. Vérifie/demande la permission (denied, deniedForever)
  // 3. Retourne Position avec latitude/longitude
  //    ou null si permission refusée / service désactivé
  return await Geolocator.getCurrentPosition(
    locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium),
  );
}
```

**Dépendance :** `geolocator: ^13.0.4`

**Précision :** `LocationAccuracy.medium` — bon compromis entre précision et consommation batterie.

### 2. Appel API — `PropertyService.getNearbyProperties()`

**Fichier :** `lib/services/property_service.dart`

```dart
Future<List<Property>> getNearbyProperties({
  required double latitude,
  required double longitude,
}) async {
  final response = await ApiService().client.get(
    ApiConfig.nearbyPropertiesEndpoint,  // → '/biens'
    queryParameters: { 'lat': latitude, 'lng': longitude },
  );
  final List data = response.data as List;
  final properties = data
      .map((json) => Property.fromJson(json as Map<String, dynamic>))
      .toList();
  return enrichProperties(properties);  // Ajoute photos + tarifs manquants
}
```

**Endpoint :** `GET /nestvia/biens?lat={latitude}&lng={longitude}`

**Réponse JSON attendue par champ :**

| Champ JSON | Champ Dart | Type | Description |
|------------|-----------|------|-------------|
| `id_bien` | `id` | `int` | Identifiant du bien |
| `nom_bien` | `name` | `String` | Nom du bien |
| `latitude` | `latitude` | `double?` | Latitude GPS du bien |
| `longitude` | `longitude` | `double?` | Longitude GPS du bien |
| `distance_km` | `distanceKm` | `double?` | Distance (si calculée par l'API) |
| `nom_commune` | `commune` | `String` | Nom de la commune |
| `tarif` | `prixNuit` | `double?` | Tarif par nuit |

### 3. Calcul de distance côté client

**Fichier :** `lib/screens/home_screen.dart` — méthode `_loadNearby()`

Lorsque l'API ne fournit pas le champ `distance_km`, la distance est calculée côté client :

```dart
final withDistance = properties.map((p) {
  if (p.distanceKm != null) return p;              // API a fourni la distance
  if (p.latitude == null || p.longitude == null) return p;  // Pas de coordonnées
  final meters = Geolocator.distanceBetween(
    position.latitude, position.longitude,
    p.latitude!, p.longitude!,
  );
  return p.copyWith(distanceKm: meters / 1000.0);  // Conversion m → km
}).toList();
```

**Méthode de calcul :** `Geolocator.distanceBetween()` utilise la **formule de Haversine** pour calculer la distance orthodromique (à vol d'oiseau) entre deux points GPS sur la sphère terrestre.

**Priorité :** Si l'API renvoie `distance_km`, cette valeur est conservée. Le calcul client n'intervient qu'en fallback.

### 4. Filtrage — `_filteredNearby`

**Fichier :** `lib/screens/home_screen.dart`

```dart
List<Property> get _filteredNearby {
  final nearby = _nearbyProperties
      .where((p) => p.distanceKm != null && p.distanceKm! <= 35.0);
  if (_selectedCategory == 'Tous') return nearby.toList();
  return nearby
      .where((p) => p.typeBien.toLowerCase() == _selectedCategory.toLowerCase())
      .toList();
}
```

**Règles de filtrage (appliquées séquentiellement) :**

1. **Distance non nulle** : exclut les biens sans coordonnées GPS (ni côté API, ni côté Property)
2. **Distance ≤ 35 km** : rayon maximum de proximité
3. **Catégorie** : filtre optionnel par type de bien (Studio, Appartement, Maison, Villa…)

### 5. Affichage — `NearbyPropertyItem`

**Fichier :** `lib/widgets/nearby_property_item.dart`

La distance est affichée dans chaque carte de bien :

```dart
if (p.distanceKm != null)
  Text(
    '${p.distanceKm!.toStringAsFixed(1)} km',
    style: const TextStyle(color: Colors.grey, fontSize: 11),
  ),
```

### 6. Géocodage inverse

Le nom de la ville est résolu via le package `geocoding` pour l'affichage du label de localisation :

```dart
final placemarks = await placemarkFromCoordinates(lat, lng);
// → "Brive-la-Gaillarde" au lieu de "45.1667, 1.5333"
```

**Dépendance :** `geocoding: ^3.0.0`

---

## Cas limites gérés

| Cas | Comportement |
|-----|-------------|
| GPS désactivé / permission refusée | `_locationLabel = 'Position indisponible'`, section vide |
| Bien sans coordonnées (`latitude`/`longitude` null) | Exclu du filtrage (pas de distance calculable) |
| API fournit `distance_km` | Valeur API utilisée directement (pas de recalcul) |
| API ne fournit pas `distance_km` | Calcul Haversine côté client via Geolocator |
| Aucun bien dans le rayon de 35 km | Message « Aucun bien trouvé près de chez vous. » |
| Géocodage inverse échoue | Coordonnées GPS affichées en fallback |

---

## Constantes et configuration

| Paramètre | Valeur | Emplacement |
|-----------|--------|-------------|
| Rayon maximum | **35.0 km** | `home_screen.dart` → `_filteredNearby` |
| Précision GPS | `LocationAccuracy.medium` | `location_service.dart` |
| Endpoint API | `/biens` | `api_config.dart` → `nearbyPropertiesEndpoint` |

---

## Dépendances

```yaml
geolocator: ^13.0.4        # Position GPS + calcul de distance (Haversine)
geocoding: ^3.0.0           # Géocodage inverse (coordonnées → nom de ville)
```

---

## Diagramme de séquence

```
Utilisateur        HomeScreen       LocationService    PropertyService       API
    │                  │                  │                  │                 │
    │  ouvre l'appli   │                  │                  │                 │
    │─────────────────►│                  │                  │                 │
    │                  │ getCurrentPos()  │                  │                 │
    │                  │─────────────────►│                  │                 │
    │                  │   Position(lat,lng)                 │                 │
    │                  │◄─────────────────│                  │                 │
    │                  │                  │                  │                 │
    │                  │ getNearbyProperties(lat, lng)       │                 │
    │                  │────────────────────────────────────►│                 │
    │                  │                  │                  │ GET /biens      │
    │                  │                  │                  │────────────────►│
    │                  │                  │                  │  List<Property> │
    │                  │                  │                  │◄────────────────│
    │                  │        List<Property>               │                 │
    │                  │◄────────────────────────────────────│                 │
    │                  │                  │                  │                 │
    │                  │ calcul distanceKm (Haversine)       │                 │
    │                  │ filtre ≤ 35 km   │                  │                 │
    │                  │                  │                  │                 │
    │  biens proches   │                  │                  │                 │
    │◄─────────────────│                  │                  │                 │
```
