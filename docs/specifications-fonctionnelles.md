# Spécifications fonctionnelles — Application mobile Nestvia

**Version :** 1.0
**Date :** 12 mars 2026
**Plateforme :** Flutter (Android / iOS / Linux)
**API Backend :** `https://api.leofranz.fr/nestvia`

---

## Table des matières

1. [Présentation générale](#1-présentation-générale)
2. [Architecture technique](#2-architecture-technique)
3. [Écrans et navigation](#3-écrans-et-navigation)
4. [Fonctionnalités détaillées](#4-fonctionnalités-détaillées)
   - 4.1 [Initialisation et démarrage](#41-initialisation-et-démarrage)
   - 4.2 [Accueil non-connectée](#42-accueil-non-connectée)
   - 4.3 [Authentification](#43-authentification)
   - 4.4 [Page d'accueil connectée](#44-page-daccueil-connectée)
   - 4.5 [Carte interactive](#45-carte-interactive)
   - 4.6 [Recherche avancée](#46-recherche-avancée)
   - 4.7 [Fiche détaillée d'un bien](#47-fiche-détaillée-dun-bien)
   - 4.8 [Réservation](#48-réservation)
   - 4.9 [Favoris](#49-favoris)
   - 4.10 [Notifications et avis](#410-notifications-et-avis)
   - 4.11 [Profil utilisateur](#411-profil-utilisateur)
   - 4.12 [Mes réservations](#412-mes-réservations)
5. [Endpoints API consommés](#5-endpoints-api-consommés)
6. [Traçabilité des issues](#6-traçabilité-des-issues)

---

## 1. Présentation générale

Nestvia est une application mobile de location saisonnière permettant aux locataires de :

- Rechercher et consulter des biens disponibles à la location
- Visualiser les biens sur une carte interactive
- Réserver un bien pour une période donnée
- Gérer leurs favoris, notifications et profil

L'application ne se connecte pas directement à une base de données. Elle communique exclusivement avec une **API REST** sécurisée par **JWT** (JSON Web Tokens).

---

## 2. Architecture technique

| Composant | Technologie | Description |
|-----------|-------------|-------------|
| Application mobile | Flutter / Dart | Interface utilisateur multiplateforme |
| Client HTTP | Dio | Requêtes REST avec gestion JWT |
| Stockage sécurisé | FlutterSecureStorage | Persistance du token JWT |
| Carte | flutter_map + OpenStreetMap | Carte interactive avec marqueurs |
| Géolocalisation | Geolocator | Position GPS de l'utilisateur |
| API Backend | Node.js / Express | API REST avec authentification JWT |
| Base de données | MariaDB | Données métier (biens, réservations, etc.) |

### Pattern Singleton

Tous les services (`ApiService`, `AuthService`, `FavoriteService`, `NotificationService`, `ProfileService`, `SearchFilterService`) utilisent le **pattern Singleton** pour garantir une instance unique dans l'application.

### Localisation

L'application est configurée en **français** (`fr_FR`) avec les localisations Material, Widgets et Cupertino.

---

## 3. Écrans et navigation

### Flux de navigation

```
Démarrage
    |
    v
SplashScreen (vérification token)
    |
    +--> Token valide --> MainNavScreen (BottomNavigationBar)
    |                         |
    |                         +-- Accueil (HomeScreen)
    |                         +-- Carte (MapScreen)
    |                         +-- Favoris (FavoritesScreen)
    |                         +-- Notifications (NotificationsScreen)
    |                         +-- Profil (ProfileScreen)
    |
    +--> Pas de token --> LandingScreen
                              |
                              +-- Se connecter --> AuthScreen --> MainNavScreen
                              +-- S'inscrire --> Navigateur externe (site web)
```

### Écrans secondaires (accessibles depuis la navigation principale)

| Écran | Accès depuis | Description |
|-------|--------------|-------------|
| `SearchScreen` | Accueil (barre de recherche) | Recherche avancée avec filtres |
| `MapScreen` | Résultats de recherche / onglet Carte | Carte avec marqueurs de prix |
| `PropertyPopup` | Marqueur sur la carte | Fiche résumée d'un bien |
| `BookingScreen` | Popup bien / Fiche détaillée | Processus de réservation (3 étapes) |
| `BookingSuccessScreen` | Fin de réservation | Confirmation de réservation |
| `MyReservationsScreen` | Profil | Liste des réservations avec filtres |
| `ReviewDialog` | Notification de type review_request | Formulaire de dépôt d'avis |

---

## 4. Fonctionnalités détaillées

### 4.1 Initialisation et démarrage

**Issues :** #1
**Fichiers :** `main.dart`, `config/api_config.dart`, `services/api_service.dart`

| Spécification | Détail |
|---------------|--------|
| Initialisation Dio | Client HTTP configuré avec URL de base, timeouts (connexion 10s, réception 30s), headers JSON |
| URL de base | `https://api.leofranz.fr/nestvia` (surchargeable via `--dart-define=API_BASE_URL=...`) |
| Localisation | Date formatting initialisé en `fr_FR` |
| Thème | Material 3, couleur principale `#1A3C5E`, police Roboto |

### 4.2 Accueil non-connectée

**Issues :** #2, #3, #4, #25
**Fichiers :** `screens/splash_screen.dart`, `screens/landing_screen.dart`

#### SplashScreen

| Spécification | Détail |
|---------------|--------|
| Vérification automatique | Au démarrage, vérifie si un token JWT est stocké localement |
| Token présent | Réinjecte le token dans Dio et redirige vers `MainNavScreen` |
| Pas de token | Redirige vers `LandingScreen` |
| Affichage | Logo Nestvia, nom de l'app, indicateur de chargement |

#### LandingScreen

| Spécification | Détail |
|---------------|--------|
| Bouton « Se connecter » | Navigation vers `AuthScreen` |
| Bouton « S'inscrire » | Ouverture de `https://nestvia.leofranz.fr/connexion_inscription.php` dans le navigateur externe |
| Affichage | Logo, nom « Nestvia », slogan « Trouvez le logement qui vous correspond » |

### 4.3 Authentification

**Issues :** #5, #6, #7, #26
**Fichiers :** `screens/auth_screen.dart`, `services/auth_service.dart`

#### Formulaire de connexion

| Champ | Validation côté client |
|-------|------------------------|
| Email | Obligatoire, format email vérifié par regex |
| Mot de passe | Obligatoire, visibilité basculable |

#### Processus de connexion

| Étape | Détail |
|-------|--------|
| 1. Soumission | `POST /auth/login` avec `{ email, password }` |
| 2. Réponse OK | L'API retourne `{ "token": "eyJ..." }` |
| 3. Stockage | Token JWT stocké via `FlutterSecureStorage` (Keystore Android / Keychain iOS) |
| 4. Injection | Token injecté dans les headers Dio (`Authorization: Bearer <token>`) |
| 5. Navigation | Redirection vers `MainNavScreen` (pile de navigation vidée) |

#### Erreurs gérées

| Cas | Message affiché |
|-----|-----------------|
| HTTP 401 / 403 | « Email ou mot de passe incorrect. Compte inexistant ou verrouillé. » |
| Timeout | « La connexion a expiré. Vérifiez votre réseau. » |
| Pas de réseau | « Impossible de contacter le serveur. Vérifiez votre connexion internet. » |

#### Liens supplémentaires

| Action | Comportement |
|--------|-------------|
| « Mot de passe oublié ? » | Ouverture de `https://nestvia.leofranz.fr/connexion_inscription.php` dans le navigateur externe |
| « Pas encore de compte ? S'inscrire » | Ouverture de la page d'inscription dans le navigateur externe |

### 4.4 Page d'accueil connectée

**Issues :** #8, #9, #10, #11, #27
**Fichiers :** `screens/home_screen.dart`, `widgets/featured_property_card.dart`, `widgets/nearby_property_item.dart`

#### En-tête

| Élément | Description |
|---------|-------------|
| Avatar utilisateur | Initiales (prénom + nom) dans un cercle coloré |
| Message de bienvenue | « Bonjour, {prénom} » |
| Badge notifications | Nombre de notifications non lues |

#### Barre de recherche

| Spécification | Détail |
|---------------|--------|
| Comportement | Tap → navigation vers `SearchScreen` (recherche avancée) |
| Apparence | Champ non éditable, icône de recherche |

#### Filtres par catégorie de bien

| Spécification | Détail |
|---------------|--------|
| Source | `GET /types-bien` (chargement dynamique) |
| Affichage | Chips horizontaux : « Tous », « Studio », « Appartement », « Maison », « Villa », etc. |
| Comportement | Filtre côté client appliqué aux sections « En vedette » et « Près de vous » |

#### Section « En vedette »

| Spécification | Détail |
|---------------|--------|
| Source | `GET /biens` via `PropertyService.getFeaturedProperties()` |
| Enrichissement | Photo (`GET /biens/:id/photos`) + tarif (`GET /biens/:id/tarifs`) en parallèle |
| Affichage | Carrousel horizontal de cartes avec photo, nom, commune, type, prix/nuit, note |
| Bouton favori | Cœur en overlay sur chaque carte (toggle favori) |
| Tap | Navigation vers la carte centrée sur le bien |

#### Section « Près de vous »

| Spécification | Détail |
|---------------|--------|
| Géolocalisation | Demande permission GPS, récupère la position via `Geolocator` |
| Source | `GET /biens?lat=...&lng=...` via `PropertyService.getNearbyProperties()` |
| Affichage | Liste verticale avec photo, nom, localisation, prix |
| Bouton favori | Cœur sur chaque item |
| Position indisponible | Message « Position indisponible » sans erreur bloquante |

### 4.5 Carte interactive

**Issues :** #12, #13, #14, #28
**Fichiers :** `screens/map_screen.dart`, `widgets/property_popup.dart`

#### Carte

| Spécification | Détail |
|---------------|--------|
| Librairie | flutter_map avec tuiles OpenStreetMap |
| Centre par défaut | Centre de la France (46.6°N, 1.9°E) |
| Centre utilisateur | Si GPS disponible, bouton pour recentrer sur la position |
| Marqueurs | Badge de prix affiché sur chaque bien géolocalisé |

#### Filtres rapides

| Filtre | Condition |
|--------|-----------|
| Tous | Aucun filtre |
| < 100€ | `prixNuit < 100` |
| Luxe | `prixNuit >= 200` |

Filtrage **côté client uniquement**, sans requête API supplémentaire.

#### Popup fiche d'un bien

| Spécification | Détail |
|---------------|--------|
| Déclenchement | Tap sur un marqueur |
| Contenu | Photo, nom, note, localisation, type de bien, superficie, prestations, prix/nuit |
| Données | Enrichies via `GET /biens/:id` (détail + prestations) et `GET /biens/:id/photos` |
| Bouton « Réserver » | Navigation vers `BookingScreen` avec le bien sélectionné |
| Bouton favori | Toggle ajout/suppression favori |

#### Bottom sheet — Liste des biens

| Spécification | Détail |
|---------------|--------|
| Contenu | Liste scrollable des biens visibles dans la zone |
| Bouton recherche avancée | Navigation vers `SearchScreen` |

### 4.6 Recherche avancée

**Issues :** #10
**Fichiers :** `screens/search_screen.dart`, `services/property_service.dart`, `services/search_filter_service.dart`

#### Filtres disponibles

| Filtre | Type de contrôle | Paramètre API | Valeurs |
|--------|------------------|---------------|---------|
| Commune | Autocomplete (min. 2 caractères) | `commune` | ID commune (entier) |
| Type de bien | Autocomplete | `type_bien` | ID type de bien (entier) |
| Nombre de couchages | Dropdown | `nb_personnes` | 1, 2, 3, 4, 5, 6, 8, 10 |
| Animaux acceptés | Dropdown | `animaux` | Tous / Oui / Non |
| Fourchette de prix | RangeSlider double curseur | `tarif_min` / `tarif_max` | 0 € à 2 000 € par paliers de 50 € |
| Date d'arrivée | DatePicker | `date_debut` | Demain à J+365 |
| Date de départ | DatePicker | `date_fin` | Arrivée+1j à J+730 |

#### Sélection de la fourchette de prix

| Spécification | Détail |
|---------------|--------|
| Composant | `RangeSlider` Flutter avec double curseur |
| Plage | 0 € à 2 000 € |
| Pas | 50 € (40 divisions) |
| Apparence | Curseurs et piste active en vert `#10B981`, labels de prix affichés au-dessus |
| Valeur par défaut | Plage complète [0, 2 000] (aucun filtrage appliqué) |
| Logique | Si les curseurs sont aux extrêmes, les paramètres `tarif_min` / `tarif_max` ne sont pas envoyés à l'API |

#### Conservation des filtres entre les pages

| Spécification | Détail |
|---------------|--------|
| Service | `SearchFilterService` (Singleton) |
| Fichier | `services/search_filter_service.dart` |
| Données conservées | Commune (nom + ID), type de bien (nom + ID), nombre de couchages, animaux, fourchette de prix, dates d'arrivée et de départ |
| Persistance | En mémoire (durée de vie de l'application) |
| Sauvegarde | Automatique à chaque modification d'un filtre |
| Restauration | Automatique à l'ouverture de `SearchScreen` (dans `initState`) |
| Réinitialisation | Le bouton « Réinitialiser » remet à zéro l'état local et le singleton |

Ainsi, lorsque l'utilisateur navigue entre la page d'accueil, la carte et l'écran de recherche, les filtres précédemment saisis sont conservés.

#### Autocomplétion des communes

- `GET /communes?search=<query>` déclenché à partir de 2 caractères
- Mapping dynamique `nom_commune → id_commune`

#### Autocomplétion des types de bien

- `GET /types-bien` (chargement intégral, filtrage local)
- Mapping dynamique `des_typebien → id_typebien`

#### Flux de recherche

1. L'utilisateur configure ses filtres
2. `GET /biens?commune=X&type_bien=Y&nb_personnes=Z&...` avec paramètres non-null uniquement
3. Si dates renseignées : vérification parallèle de disponibilité pour chaque bien via `GET /biens/:id/disponibilite?date_debut=...&date_fin=...`
4. Biens non disponibles retirés des résultats (fail-safe : conservés en cas d'erreur réseau)
5. Résultats enrichis (photos + tarifs) et affichés sur la `MapScreen`

#### Remise à zéro

Bouton « Réinitialiser » remet tous les filtres à leur valeur par défaut (état local et singleton `SearchFilterService`).

### 4.7 Fiche détaillée d'un bien

**Issues :** #14
**Fichiers :** `widgets/property_popup.dart`, `services/reservation_service.dart`

| Donnée affichée | Source API |
|-----------------|------------|
| Photo principale | `GET /biens/:id/photos` (première photo) |
| Nom du bien | `GET /biens/:id` → `nom_bien` |
| Commune, code postal | `nom_commune`, `cp_commune` |
| Type de bien | `des_typebien` |
| Superficie | `superficie_bien` |
| Nombre de couchages | `nb_couchage` |
| Description | `description_bien` |
| Prestations | Liste des `libelle_prestation` |
| Note moyenne | `rating_moyen` (étoiles) |
| Prix / nuit | Tarif calculé depuis `GET /biens/:id/tarifs` |

### 4.8 Réservation

**Issues :** #15, #16, #17, #18, #29, #30
**Fichiers :** `screens/booking_screen.dart`, `screens/booking_success_screen.dart`, `services/reservation_service.dart`

#### Étape 1 — Sélection voyageurs et dates

| Spécification | Détail |
|---------------|--------|
| Nombre de voyageurs | Sélecteur +/- (min 1, max = nb_couchage du bien) |
| Date d'arrivée | DatePicker, préremplie si provient de la recherche |
| Date de départ | DatePicker, préremplie si provient de la recherche |
| Vérification disponibilité | `GET /biens/:id/disponibilite?date_debut=...&date_fin=...` |
| Blocages | Vérifie l'absence de blocages sur la période |

#### Étape 2 — Récapitulatif et calcul du montant

| Spécification | Détail |
|---------------|--------|
| Photo du bien | Première photo récupérée via `GET /biens/:id/photos` |
| Nom et localisation | Nom du bien, commune |
| Tarifs | Récupérés via `GET /biens/:id/tarifs` |
| Calcul | Nombre de semaines × tarif par semaine |
| Frais de service | Calculés automatiquement |
| Montant total | Tarif semaines + frais de service |
| Sélection du tarif | Si plusieurs tarifs disponibles, choix de la période |

#### Étape 3 — Formulaire de paiement

| Champ | Validation |
|-------|------------|
| Nom du titulaire | Obligatoire |
| Numéro de carte | 16 chiffres avec formatage automatique |
| Date d'expiration | Format MM/AA |
| CVV | 3 chiffres |

Les données ne sont pas stockées en base de données mais sont nécessaires pour poursuivre la réservation.

#### Création de la réservation

| Spécification | Détail |
|---------------|--------|
| Requête | `POST /reservations` avec `{ date_debut, date_fin, id_bien, id_tarif }` |
| Montant total | Calculé automatiquement côté API (nombre de semaines × tarif) |
| Succès | Navigation vers `BookingSuccessScreen` |
| Erreur | Message d'erreur affiché sous le formulaire |

#### Page de confirmation

| Élément | Description |
|---------|-------------|
| Icône | Check vert dans un cercle |
| Titre | « Réservation confirmée ! » |
| Détails | Nom du bien, montant total, numéro de réservation |
| Bouton | « Retour à l'accueil » → `MainNavScreen` |

### 4.9 Favoris

**Issues :** #11, #19, #31
**Fichiers :** `screens/favorites_screen.dart`, `services/favorite_service.dart`

#### Gestion des favoris

| Action | Endpoint API | Comportement |
|--------|-------------|--------------|
| Charger les favoris | `GET /favoris` | Au démarrage + à chaque visite de l'onglet |
| Ajouter un favori | `POST /favoris` avec `{ id_bien }` | Toggle local immédiat + appel API asynchrone |
| Supprimer un favori | `DELETE /favoris/:id_bien` | Toggle local immédiat + appel API asynchrone |

#### Bouton favori (cœur)

| Emplacement | Comportement |
|-------------|-------------|
| Carte « En vedette » | Cœur en overlay (coin supérieur droit) |
| Item « Près de vous » | Cœur à droite de l'item |
| Popup carte | Cœur dans l'en-tête |
| Page Favoris | Cœur pour retirer le bien |

#### Page Favoris

| Spécification | Détail |
|---------------|--------|
| Source | `GET /favoris` enrichis avec photos et tarifs |
| Affichage | Liste verticale avec photo, nom, commune, type, prix |
| Actions | Tap → `BookingScreen`, swipe/button → retirer des favoris |
| État vide | Message « Aucun favori pour le moment » avec icône |
| Pull-to-refresh | Rechargement de la liste |

### 4.10 Notifications et avis

**Issues :** #20, #21, #32
**Fichiers :** `screens/notifications_screen.dart`, `services/notification_service.dart`, `widgets/review_dialog.dart`

#### Notifications

| Spécification | Détail |
|---------------|--------|
| Source | `GET /notifications` |
| Affichage | Liste ordonnée par date (plus récentes en premier) |
| Badge non-lu | Indicateur visuel sur les notifications non lues |
| Marquer comme lue | `PATCH /notifications/:id/read` (tap sur la notification) |
| Marquer tout comme lu | Bouton « Tout marquer comme lu » (itère sur toutes les non-lues) |
| Données affichées | Type, message, date de création, statut lu/non-lu |

#### Types de notifications

| Type | Description | Action |
|------|-------------|--------|
| `review_request` | Demande d'avis après séjour | Ouvre le formulaire d'avis |
| Autres | Notifications informatives | Marquage comme lu uniquement |

#### Dépôt d'avis

| Spécification | Détail |
|---------------|--------|
| Déclenchement | Tap sur notification de type `review_request` |
| Formulaire | Note en étoiles (1-5) + commentaire optionnel |
| Envoi | `POST /biens/:id/avis` avec `{ id_reservation, rating, comment }` |
| ID du bien | Récupéré depuis le détail de la réservation associée |
| Après envoi | Notification marquée comme lue, dialog fermé |

### 4.11 Profil utilisateur

**Issues :** #22, #24, #33
**Fichiers :** `screens/profile_screen.dart`, `services/profile_service.dart`

#### Affichage du profil

| Donnée | Source |
|--------|--------|
| Initiales | Calculées depuis prénom + nom |
| Nom complet | `prenom_locataire` + `nom_locataire` |
| Email | `email_locataire` |
| Téléphone | `tel_locataire` |
| Ancienneté | Calculée depuis `created_at` |
| Nombre de réservations | Compteur depuis `GET /reservations` |
| Réservations terminées | Calculées côté client (date_fin < aujourd'hui) |

#### Modification du profil

| Champs modifiables (API) | Description |
|--------------------------|-------------|
| `nom_locataire` | Nom |
| `prenom_locataire` | Prénom |
| `email_locataire` | Email |
| `tel_locataire` | Téléphone |
| `rue_locataire` | Adresse |
| `comp_locataire` | Complément d'adresse |
| `id_commune` | Commune |
| `raison_sociale` | Raison sociale |
| `siret` | SIRET |
| `password` | Mot de passe |

Requête : `PUT /compte` avec les champs à modifier.

#### Déconnexion

| Spécification | Détail |
|---------------|--------|
| Action | Suppression du token de `FlutterSecureStorage` + retrait des headers Dio |
| Navigation | Retour à `LandingScreen` (pile de navigation vidée) |
| Favoris | Cache local vidé |

#### Liens du profil

| Lien | Destination |
|------|-------------|
| Mes réservations | `MyReservationsScreen` |
| Mes favoris | `FavoritesScreen` |

### 4.12 Mes réservations

**Issues :** #23, #34
**Fichiers :** `screens/my_reservations_screen.dart`, `services/profile_service.dart`

#### Source de données

| Requête | Endpoint |
|---------|----------|
| Liste | `GET /reservations` |
| Détail | `GET /reservations/:id` |

#### Filtres par statut

| Filtre | Condition (calculée côté client) |
|--------|----------------------------------|
| Tout | Aucun filtre |
| À venir | `date_debut > aujourd'hui` |
| En cours | `date_debut <= aujourd'hui <= date_fin` |
| Passées | `date_fin < aujourd'hui` |

#### Données affichées par réservation

| Donnée | Source |
|--------|--------|
| Nom du bien | `nom_bien` |
| Adresse | `rue_bien`, `com_bien` |
| Dates | `date_debut` → `date_fin` |
| Montant | `montant_total` |
| Tarif / saison | `tarif`, `libelle_saison` |
| Statut | Calculé dynamiquement (à venir / en cours / terminée) |

---

## 5. Endpoints API consommés

### Routes publiques (sans authentification)

| Méthode | Endpoint | Description |
|---------|----------|-------------|
| POST | `/nestvia/auth/login` | Connexion (email + password) → JWT |
| POST | `/nestvia/tentatives` | Log de tentative de connexion |

### Routes protégées (JWT requis)

#### Biens

| Méthode | Endpoint | Description |
|---------|----------|-------------|
| GET | `/nestvia/biens` | Liste des biens (avec filtres) |
| GET | `/nestvia/biens/:id` | Détail d'un bien + prestations |
| GET | `/nestvia/biens/:id/blocages` | Blocages d'un bien |
| GET | `/nestvia/biens/:id/photos` | Photos d'un bien (URLs complètes) |
| GET | `/nestvia/biens/:id/tarifs` | Tarifs d'un bien (optionnel: `?date_debut=&date_fin=`) |
| GET | `/nestvia/biens/:id/disponibilite` | Vérifier la disponibilité (`?date_debut=&date_fin=`) |
| GET | `/nestvia/biens/:id/avis` | Avis validés d'un bien |
| POST | `/nestvia/biens/:id/avis` | Créer un avis (`id_reservation`, `rating` 1-5, `comment`) |

##### Filtres de recherche des biens

| Paramètre | Description | Exemple |
|-----------|-------------|---------|
| `nb_personnes` | Nombre minimum de couchages | `?nb_personnes=4` |
| `tarif_min` | Tarif semaine minimum (€) | `?tarif_min=100` |
| `tarif_max` | Tarif semaine maximum (€) | `?tarif_max=300` |
| `type_bien` | ID du type de bien | `?type_bien=2` |
| `animaux` | Animaux autorisés (`oui` / `non`) | `?animaux=oui` |
| `commune` | ID de la commune | `?commune=30438` |
| `prestations` | IDs des prestations requises | `?prestations=1,3,5` |

#### Communes

| Méthode | Endpoint | Description |
|---------|----------|-------------|
| GET | `/nestvia/communes` | Liste (filtres: `?search=&departement=&limit=`) |
| GET | `/nestvia/communes/:id` | Détail d'une commune |

#### Compte

| Méthode | Endpoint | Description |
|---------|----------|-------------|
| GET | `/nestvia/compte` | Infos du compte connecté |
| PUT | `/nestvia/compte` | Mise à jour du compte (champs autorisés uniquement) |

#### Favoris

| Méthode | Endpoint | Description |
|---------|----------|-------------|
| GET | `/nestvia/favoris` | Favoris du compte connecté |
| POST | `/nestvia/favoris` | Ajouter un bien aux favoris (`id_bien`) |
| DELETE | `/nestvia/favoris/:id_bien` | Supprimer un bien des favoris |

#### Notifications

| Méthode | Endpoint | Description |
|---------|----------|-------------|
| GET | `/nestvia/notifications` | Notifications du compte connecté |
| PATCH | `/nestvia/notifications/:id/read` | Marquer comme lue |

#### Photos

| Méthode | Endpoint | Description |
|---------|----------|-------------|
| GET | `/nestvia/photos` | Toutes les photos (URLs complètes) |
| GET | `/nestvia/photos/:id` | Détail d'une photo |

#### Réservations

| Méthode | Endpoint | Description |
|---------|----------|-------------|
| GET | `/nestvia/reservations` | Réservations du compte connecté |
| GET | `/nestvia/reservations/:id` | Détail d'une réservation |
| POST | `/nestvia/reservations` | Créer une réservation (`date_debut`, `date_fin`, `id_bien`, `id_tarif`) |

#### Tarifs

| Méthode | Endpoint | Description |
|---------|----------|-------------|
| GET | `/nestvia/tarifs?id_bien=X` | Tarifs d'un bien (optionnel: `&date_debut=&date_fin=`) |

#### Types de bien

| Méthode | Endpoint | Description |
|---------|----------|-------------|
| GET | `/nestvia/types-bien` | Liste des types de bien (optionnel: `?search=`) |
| GET | `/nestvia/types-bien/:id` | Détail d'un type de bien |

---

## 6. Traçabilité des issues

### Issues INIT

| # | Titre | Statut | Fichiers concernés |
|---|-------|--------|--------------------|
| 1 | [INIT] Connexion à l'API Nestvia au démarrage | Implémenté | `main.dart`, `api_config.dart`, `api_service.dart`, `splash_screen.dart` |

### Issues CF-ACCUEIL

| # | Titre | Statut | Fichiers concernés |
|---|-------|--------|--------------------|
| 2 | Affichage de la page d'accueil non-connectée | Implémenté | `splash_screen.dart`, `landing_screen.dart` |
| 3 | Bouton « Se connecter » → page de connexion | Implémenté | `landing_screen.dart` |
| 4 | Bouton « S'inscrire » → site web | Implémenté | `landing_screen.dart`, `auth_screen.dart` |

### Issues CF-AUTH

| # | Titre | Statut | Fichiers concernés |
|---|-------|--------|--------------------|
| 5 | Formulaire de connexion — saisie email et mot de passe | Implémenté | `auth_screen.dart` |
| 6 | Lien « Mot de passe oublié » — réinitialisation | Implémenté | `auth_screen.dart` |
| 7 | Authentification via API et gestion du token de session | Implémenté | `auth_service.dart`, `auth_screen.dart` |

### Issues CF-HOME

| # | Titre | Statut | Fichiers concernés |
|---|-------|--------|--------------------|
| 8 | Affichage des biens « En vedette » sur la page d'accueil | Implémenté | `home_screen.dart`, `featured_property_card.dart`, `property_service.dart` |
| 9 | Affichage des biens « Près de vous » avec géolocalisation | Implémenté | `home_screen.dart`, `nearby_property_item.dart`, `location_service.dart` |
| 10 | Barre de recherche et filtres par catégorie de bien | Implémenté | `home_screen.dart`, `search_screen.dart` |
| 11 | Ajout et suppression d'un bien en favori | Implémenté | `favorite_service.dart`, `featured_property_card.dart`, `nearby_property_item.dart` |

### Issues CF-CARTE

| # | Titre | Statut | Fichiers concernés |
|---|-------|--------|--------------------|
| 12 | Carte interactive avec marqueurs de prix | Implémenté | `map_screen.dart` |
| 13 | Filtres par prix et bottom sheet liste des biens | Implémenté | `map_screen.dart` |
| 14 | Popup fiche d'un bien avec bouton Réserver | Implémenté | `property_popup.dart` |

### Issues CF-RESA

| # | Titre | Statut | Fichiers concernés |
|---|-------|--------|--------------------|
| 15 | Étape 1 — Sélection voyageurs et dates | Implémenté | `booking_screen.dart`, `reservation_service.dart` |
| 16 | Étape 2 — Récapitulatif et calcul du montant | Implémenté | `booking_screen.dart` |
| 17 | Étape 3 — Formulaire de paiement et création | Implémenté | `booking_screen.dart`, `reservation_service.dart` |

### Issues CF-CONFIRM

| # | Titre | Statut | Fichiers concernés |
|---|-------|--------|--------------------|
| 18 | Page de confirmation de réservation | Implémenté | `booking_success_screen.dart` |

### Issues CF-FAVORIS

| # | Titre | Statut | Fichiers concernés |
|---|-------|--------|--------------------|
| 19 | Affichage de la liste des biens en favoris | Implémenté | `favorites_screen.dart`, `favorite_service.dart` |

### Issues CF-NOTIFS

| # | Titre | Statut | Fichiers concernés |
|---|-------|--------|--------------------|
| 20 | Affichage et gestion des notifications | Implémenté | `notifications_screen.dart`, `notification_service.dart` |
| 21 | Dépôt d'un avis sur un bien après séjour | Implémenté | `review_dialog.dart`, `notification_service.dart` |

### Issues CF-PROFIL

| # | Titre | Statut | Fichiers concernés |
|---|-------|--------|--------------------|
| 22 | Affichage et modification du profil utilisateur | Implémenté | `profile_screen.dart`, `profile_service.dart` |
| 23 | Page « Mes réservations » avec filtres | Implémenté | `my_reservations_screen.dart`, `profile_service.dart` |
| 24 | Déconnexion de l'utilisateur | Implémenté | `profile_screen.dart`, `auth_service.dart` |

### Issues PAGE (structure des écrans)

| # | Titre | Statut | Fichier concerné |
|---|-------|--------|------------------|
| 25 | Page d'accueil non-connectée (Splash / Landing) | Implémenté | `splash_screen.dart`, `landing_screen.dart` |
| 26 | Page de connexion (AuthPage) | Implémenté | `auth_screen.dart` |
| 27 | Page d'accueil connectée (HomePage) | Implémenté | `home_screen.dart` |
| 28 | Page Carte (MapPage) | Implémenté | `map_screen.dart` |
| 29 | Page de réservation (BookingPage - 3 étapes) | Implémenté | `booking_screen.dart` |
| 30 | Page de confirmation de réservation (BookingSuccess) | Implémenté | `booking_success_screen.dart` |
| 31 | Page Favoris (FavoritesPage) | Implémenté | `favorites_screen.dart` |
| 32 | Page Notifications (NotificationsPage) | Implémenté | `notifications_screen.dart` |
| 33 | Page Profil (ProfilePage) | Implémenté | `profile_screen.dart` |
| 34 | Page Mes Réservations (sous-page Profil) | Implémenté | `my_reservations_screen.dart` |
