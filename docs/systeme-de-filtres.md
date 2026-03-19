# Système de filtres — Documentation technique

## Vue d'ensemble

L'application Nestvia propose un système de filtrage à trois niveaux :

1. **Recherche avancée** (`SearchScreen`) — filtres combinés côté API
2. **Filtrage sur la carte** (`MapScreen`) — filtres rapides côté client
3. **Filtrage des réservations** (`MyReservationsScreen`) — filtres par statut côté client

---

## 1. Recherche avancée — `SearchScreen`

**Fichier :** `lib/screens/search_screen.dart`

### Filtres disponibles

| Filtre             | Type de contrôle           | Paramètre API     | Valeurs possibles                          |
|--------------------|----------------------------|--------------------|-------------------------------------------|
| Commune            | Autocomplete (recherche)   | `commune`          | ID de la commune (entier)                 |
| Type de bien       | Autocomplete (recherche)   | `type_bien`        | ID du type de bien (entier)               |
| Nombre de couchages| Dropdown                   | `nb_personnes`     | `null`, 1, 2, 3, 4, 5, 6, 8, 10          |
| Animaux acceptés   | Dropdown                   | `animaux`          | `null` (Tous), `oui`, `non`              |
| Tarif minimum      | Champ texte (numérique)    | `tarif_min`        | Nombre décimal (€)                        |
| Tarif maximum      | Champ texte (numérique)    | `tarif_max`        | Nombre décimal (€)                        |
| Date d'arrivée     | DatePicker                 | `date_debut`       | Date ISO 8601 (YYYY-MM-DD)               |
| Date de départ     | DatePicker                 | `date_fin`         | Date ISO 8601 (YYYY-MM-DD)               |

### Flux de recherche

```
+----------------+                              +--------------+
|                        |GET /biens?params|                    |
| SearchScreen |                                | API Server |
|  (filtres)|  <--- [{bien1},{bien2},...] --                |
|                        |                               |                    |
+----------------+                              +------------+
        |
        |  Si dates renseignees :
        v
+----------------+                              +--------------+
|          GET /biens/:id/dispo? -----> |                    |
|  filterAvail     |                                | API Server |
|   (par bien)  <-- {"disponible":t/f} |                    |
|                        |                               |                    |
+----------------+                              +--------------+
        |
        v
+----------------+
|   MapScreen    |  <-- resultats sur la carte
+----------------+
```

### Détail du fonctionnement

#### Communes (autocomplete)

- Requête : `GET /communes?search=<query>` (déclenchée à partir de 2 caractères)
- Réponse : liste d'objets `{ "id_commune": int, "nom_commune": string }`
- Un mapping `nom → id` est construit dynamiquement pour envoyer l'ID à l'API

#### Types de bien (autocomplete)

- Requête : `GET /types-bien` (chargement complet, filtrage côté client)
- Réponse : liste d'objets `{ "id_typebien": int, "des_typebien": string }`
- Filtrage local par `contains()` sur le texte saisi

#### Vérification de disponibilité

- Déclenchée **uniquement** si les deux dates sont renseignées
- Appel parallèle (`Future.wait`) pour chaque bien : `GET /biens/:id/disponibilite?date_debut=...&date_fin=...`
- Les biens non disponibles sont retirés des résultats
- En cas d'erreur réseau sur un bien, celui-ci est **conservé** (comportement fail-safe)

### Contraintes sur les dates

| Contrainte                 | Règle                                                        |
|----------------------------|--------------------------------------------------------------|
| Date d'arrivée min         | Demain (`now + 1 jour`)                                     |
| Date d'arrivée max         | Aujourd'hui + 365 jours                                     |
| Date de départ min         | Date d'arrivée + 1 jour                                     |
| Date de départ max         | Aujourd'hui + 730 jours                                     |
| Réinitialisation auto      | Si la date de départ < arrivée + 1j, elle est remise à null |

### Remise à zéro

La méthode `_resetFilters()` remet tous les filtres à leur valeur par défaut (chaînes vides, `null`, contrôleurs vidés).

---

## 2. Filtres rapides sur la carte — `MapScreen`

**Fichier :** `lib/screens/map_screen.dart`

### Filtres disponibles

| Filtre          | Condition                             | Description                    |
|-----------------|---------------------------------------|--------------------------------|
| `Tous`          | Aucun filtre                          | Affiche tous les biens         |
| `< 100€`       | `prixNuit != null && prixNuit < 100`  | Biens à moins de 100€ / nuit  |
| `Luxe`          | `prixNuit != null && prixNuit >= 200` | Biens à 200€+ / nuit          |

### Fonctionnement

- Filtrage **côté client uniquement** (pas de requête API)
- Appliqué sur la liste `_allProperties` déjà chargée
- Résultat stocké dans `_filteredProperties`
- Méthode : `_applyFilter()` avec un `switch` sur `_selectedFilter`

---

## 3. Filtres des réservations — `MyReservationsScreen`

**Fichier :** `lib/screens/my_reservations_screen.dart`

### Filtres disponibles

| Filtre            | Enum                        | Condition sur le statut  |
|-------------------|-----------------------------|--------------------------|
| Tout              | `ReservationFilter.tout`    | Aucun filtre             |
| À venir           | `ReservationFilter.aVenir`  | `status == 'a_venir'`   |
| En cours          | `ReservationFilter.enCours` | `status == 'en_cours'`  |
| Passées           | `ReservationFilter.passees` | `status == 'terminee'`  |

### Fonctionnement

- Filtrage **côté client** via un getter `_filteredReservations`
- Le statut est calculé dynamiquement par la méthode `_getStatus()`
- Pas de requête API supplémentaire

---

## Couche service — `PropertyService`

**Fichier :** `lib/services/property_service.dart`

### `searchProperties()` — Recherche avec filtres

```dart
Future<List<Property>> searchProperties({
  String? commune,
  String? typeBien,
  int? nbPersonnes,
  String? animaux,
  double? tarifMin,
  double? tarifMax,
})
```

- Construit dynamiquement les `queryParameters` (seuls les paramètres non-null sont envoyés)
- Appel : `GET /biens?commune=...&type_bien=...&...`
- Les résultats sont **enrichis** automatiquement avec photos et tarifs via `enrichProperties()`

### `filterAvailable()` — Filtrage par disponibilité

```dart
Future<List<Property>> filterAvailable({
  required List<Property> properties,
  required DateTime dateDebut,
  required DateTime dateFin,
})
```

- Vérification parallèle pour chaque bien
- Appel : `GET /biens/:id/disponibilite?date_debut=YYYY-MM-DD&date_fin=YYYY-MM-DD`
- Réponse attendue : `{ "disponible": true | false }`

### `enrichProperties()` — Enrichissement des résultats

Après chaque recherche, les biens sont complétés en parallèle avec :
- **Photo** : `GET /biens/:id/photos` → premier `lien_photo` non vide
- **Tarif** : `GET /biens/:id/tarifs` → tarif de la semaine courante ou premier disponible

---

## Résumé des appels API liés aux filtres

| Méthode                   | Endpoint                                | Type | Paramètres                                    |
|---------------------------|-----------------------------------------|------|-----------------------------------------------|
| Recherche de biens        | `GET /biens`                            | GET  | commune, type_bien, nb_personnes, animaux, tarif_min, tarif_max |
| Disponibilité d'un bien   | `GET /biens/:id/disponibilite`          | GET  | date_debut, date_fin                          |
| Recherche de communes     | `GET /communes`                         | GET  | search                                        |
| Liste types de bien       | `GET /types-bien`                       | GET  | —                                             |
| Photos d'un bien          | `GET /biens/:id/photos`                 | GET  | —                                             |
| Tarifs d'un bien          | `GET /biens/:id/tarifs`                 | GET  | —                                             |
