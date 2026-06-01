# Fonctionnalités de l'application Nestvia

**Version :** 1.0
**Plateformes :** Android, iOS, Linux (Flutter)
**Backend :** API REST sécurisée par JWT (`https://api.leofranz.fr/nestvia`)

---

## 1. Présentation générale

Nestvia est une application mobile de location saisonnière qui permet aux
locataires de rechercher, consulter et réserver des biens immobiliers, de
gérer leurs favoris, leurs réservations et leurs notifications, le tout
depuis une interface unifiée disponible en français.

---

## 2. Authentification et sécurité

- Écran d'accueil non connecté (`LandingScreen`) avec accès à la connexion
  et redirection vers le site web pour l'inscription et le mot de passe
  oublié.
- Connexion par email et mot de passe (`POST /auth/login`) avec validation
  côté client (regex email, champ obligatoire).
- Stockage sécurisé du token JWT via `FlutterSecureStorage` (Keystore
  Android / Keychain iOS) et injection automatique du token dans les
  en-têtes Dio (`Authorization: Bearer …`).
- Vérification automatique du token au démarrage (`SplashScreen`) :
  redirection vers la navigation principale si valide, sinon vers l'écran
  d'accueil public.
- Gestion explicite des erreurs réseau (timeout, 401/403, perte de
  connexion) avec messages utilisateur.

---

## 3. Page d'accueil connectée

- En-tête personnalisé : avatar avec initiales, message de bienvenue et
  badge du nombre de notifications non lues.
- Barre de recherche redirigeant vers la recherche avancée.
- Filtres par catégorie de bien chargés dynamiquement (`GET /types-bien`).
- Carrousel « En vedette » : photos, nom, commune, type, prix/nuit, note.
- Section « Près de vous » basée sur la géolocalisation GPS de
  l'utilisateur (`Geolocator`).
- Bouton favori (cœur) disponible sur chaque bien affiché.

---

## 4. Carte interactive

- Carte basée sur `flutter_map` avec tuiles OpenStreetMap.
- Marqueurs personnalisés affichant le prix de chaque bien.
- Recentrage automatique sur la position GPS de l'utilisateur (si
  autorisée).
- Filtres rapides (Tous / < 100 € / Luxe) appliqués côté client.
- Popup détaillée au tap sur un marqueur (photo, infos, prestations, prix)
  avec accès direct à la réservation et au favori.
- Bottom sheet listant les biens visibles dans la zone affichée.

---

## 5. Recherche avancée

- Filtres disponibles : commune (autocomplétion), type de bien
  (autocomplétion), nombre de couchages, animaux acceptés, fourchette de
  prix (`RangeSlider` 0–2 000 € par paliers de 50 €), date d'arrivée et de
  départ.
- Conservation des filtres entre les écrans grâce au singleton
  `SearchFilterService`.
- Vérification de la disponibilité des biens en parallèle pour les dates
  saisies (`GET /biens/:id/disponibilite`).
- Enrichissement des résultats avec photos et tarifs avant affichage sur
  la carte.
- Bouton « Réinitialiser » remettant tous les filtres à zéro.

---

## 6. Fiche détaillée d'un bien

- Photo principale, nom, commune et code postal, type, superficie, nombre
  de couchages, description, prestations, note moyenne et prix par nuit.
- Données issues de `GET /biens/:id`, `GET /biens/:id/photos` et
  `GET /biens/:id/tarifs`.

---

## 7. Réservation

Processus en 3 étapes :

1. **Voyageurs et dates** : sélection du nombre de voyageurs (limité au
   nombre de couchages), choix des dates et vérification de la
   disponibilité.
2. **Récapitulatif** : photo, nom, localisation, calcul automatique
   (nombre de semaines × tarif) et frais de service.
3. **Paiement** : formulaire avec nom du titulaire, numéro de carte (16
   chiffres formatés), date d'expiration (MM/AA) et CVV.

La réservation est créée via `POST /reservations`, suivie d'un écran de
confirmation avec le numéro de réservation et le montant total.

---

## 8. Favoris

- Chargement des favoris (`GET /favoris`) au démarrage et à chaque visite
  de l'onglet.
- Ajout (`POST /favoris`) et suppression (`DELETE /favoris/:id_bien`)
  immédiats côté client puis synchronisés avec l'API.
- Liste des favoris enrichie de photos et de tarifs, avec gestion d'un
  état vide et d'un pull-to-refresh.

---

## 9. Mes réservations

- Écran dédié listant les réservations de l'utilisateur avec filtres (à
  venir, en cours, terminées, annulées).
- Affichage des détails (bien, dates, montant, statut) et actions
  associées.

---

## 10. Notifications et avis

- Liste des notifications triée par date avec badge des non-lues.
- Marquage comme lue au tap (`PATCH /notifications/:id/read`).
- Notifications locales via `flutter_local_notifications` et tâches en
  arrière-plan via `workmanager`.
- Dépôt d'un avis (`ReviewDialog`) déclenché par les notifications de
  type `review_request`.

---

## 11. Profil utilisateur

- Consultation et modification des informations personnelles
  (`PersonalInfoScreen`).
- Changement de mot de passe (`ChangePasswordScreen`).
- Accès aux réservations, aux favoris, au thème de l'application et à la
  déconnexion.

---

## 12. Fonctionnalités transverses

- Interface entièrement localisée en français (`fr_FR`).
- Thème Material 3 avec couleur principale `#1A3C5E`.
- Architecture en services Singleton (`ApiService`, `AuthService`,
  `FavoriteService`, `NotificationService`, `ProfileService`,
  `SearchFilterService`, `PropertyService`, `ReservationService`,
  `LocationService`, `ThemeService`).
- Mise en cache des images réseau (`cached_network_image`).
- Ouverture de liens externes (inscription, mot de passe oublié) via
  `url_launcher`.
