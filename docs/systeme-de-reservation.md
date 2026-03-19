# Système de réservation - Documentation technique

## 1. Objectif et périmètre

Cette documentation décrit le fonctionnement **réel** du système de réservation dans l'application Flutter Nestvia, en se basant sur:

- le code actuel de l'application;
- les issues GitHub:
  - #29 - Page de réservation (BookingPage - 3 étapes)
  - #30 - Page de confirmation de réservation (BookingSuccess)
  - #18 - CF confirmation de réservation

Le document couvre:

- les points d'entrée UI vers la réservation;
- les éléments UI de chaque étape;
- les actions déclenchées (navigation, appels API, validations);
- les données échangées avec l'API;
- la conformité entre l'implémentation et les issues.

---

## 2. Composants impliqués

## UI (Flutter)

- `lib/screens/booking_screen.dart`
- `lib/screens/booking_success_screen.dart`
- `lib/screens/my_reservations_screen.dart`
- `lib/widgets/property_popup.dart`
- `lib/widgets/featured_property_card.dart`
- `lib/widgets/nearby_property_item.dart`
- `lib/screens/favorites_screen.dart`

## Services

- `lib/services/reservation_service.dart`
- `lib/services/profile_service.dart`
- `lib/services/api_service.dart`
- `lib/services/notification_service.dart`
- `lib/config/api_config.dart`

---

## 3. Vue d'ensemble du flux

```text
Point d'entrée (Home/Map/Favoris)
        |
        v
BookingScreen (3 étapes)
  Etape 1: voyageurs + dates + check disponibilité
  Etape 2: récapitulatif coût
  Etape 3: formulaire paiement + création réservation
        |
        v
BookingSuccessScreen (confirmation)
        |
        v
Retour accueil (MainNavScreen)
```

En parallèle du flux principal:

- `MyReservationsScreen` consomme `GET /reservations` pour afficher l'historique utilisateur.

---

## 4. Points d'entrée UI vers BookingScreen

## 4.1 Depuis la carte (popup bien)

Élément UI:

- bouton `Réserver` dans la popup d'un bien.

Action:

- fermeture de la popup;
- navigation vers `BookingScreen(property, dateDebut, dateFin, nbPersonnes)`.

Fichier:

- `lib/widgets/property_popup.dart`

## 4.2 Depuis les cards "En vedette"

Élément UI:

- bouton `Voir` sur carte bien.

Action:

- navigation vers `BookingScreen(property, nbPersonnes)`.

Fichier:

- `lib/widgets/featured_property_card.dart`

## 4.3 Depuis les biens "Près de vous"

Élément UI:

- bouton `Réserver` sur item.

Action:

- navigation vers `BookingScreen(property, nbPersonnes)`.

Fichier:

- `lib/widgets/nearby_property_item.dart`

## 4.4 Depuis les favoris

Élément UI:

- tap sur une carte favori.

Action:

- navigation vers `BookingScreen(property, nbPersonnes)`.

Fichier:

- `lib/screens/favorites_screen.dart`

---

## 5. BookingScreen - Détail technique par étape

L'écran suit un state machine simple basé sur `_currentStep`:

- `0`: Étape 1;
- `1`: Étape 2;
- `2`: Étape 3.

Des états transverses pilotent l'UI:

- `_loadingData`: chargement initial des données du bien;
- `_checkingAvailability`: vérification disponibilité;
- `_submitting`: soumission paiement/réservation;
- `_error`: message d'erreur utilisateur.

### 5.1 Initialisation de l'écran

Actions exécutées au `initState()`:

1. Pré-remplissage optionnel:
   - `_startDate = widget.dateDebut`
   - `_endDate = widget.dateFin`
   - `_travelers = widget.nbPersonnes` (si > 0)
2. Chargement des données nécessaires via `_loadBookingData()`:
   - `ReservationService.getPropertyTarifs(idBien)`
   - `ReservationService.getPropertyPhotos(idBien)`

Appels API déclenchés:

- `GET /biens/:id/tarifs`
- `GET /biens/:id/photos`

Effets UI:

- affichage d'un `CircularProgressIndicator` pendant le chargement;
- calcul du total automatique si des dates sont déjà présentes.

---

### 5.2 Étape 1 - Détails séjour (issue #29)

Éléments UI:

- résumé du bien (photo, nom, commune, note);
- compteur voyageurs (`-` / `+`), borné entre 1 et `nbCouchage`;
- bloc dates (arrivée / départ) + bouton `Modifier les dates`;
- indicateur de progression visuel (barres);
- bouton principal `Continuer`.

Actions utilisateur et traitements:

1. **Changer le nombre de voyageurs**
   - action locale `setState`;
   - pas d'appel API.

2. **Choisir les dates**
   - ouverture `showDateRangePicker`;
   - mise à jour `_startDate`, `_endDate`;
   - recalcul `_calculateTotal()`.

3. **Continuer vers étape 2** (`_nextStep`)
   - validation: dates obligatoires;
   - si dates OK: appel `_checkAvailability()`.

Appel API de disponibilité:

- `GET /biens/:id/disponibilite?date_debut=yyyy-MM-dd&date_fin=yyyy-MM-dd`

Comportement:

- si `disponible == true`: passage en étape 2;
- sinon: message d'erreur bloquant et maintien en étape 1;
- en cas erreur réseau/API: message utilisateur via `ApiService.handleError`.

---

### 5.3 Étape 2 - Récapitulatif (issue #29)

Éléments UI:

- ligne `Logement`: `nbSemaines x tarifParSemaine`;
- ligne `Frais de service`: 5%;
- ligne `Total`;
- rappel période, nombre de nuits, nombre de voyageurs;
- badge `Paiement sécurisé`;
- bouton principal `Confirmer`.

Règles de calcul implémentées:

- `nbNuits = dateFin - dateDebut` en jours;
- `nbSemaines = ceil(nbNuits / 7)`;
- `logement = nbSemaines * tarifParSemaine`;
- `fraisService = logement * 0.05`;
- `montantTotal = logement + fraisService`.

Sélection du tarif:

- `BookingScreen` choisit le premier tarif dont `annee_tarif` correspond à l'année de `dateDebut`;
- fallback: premier tarif disponible.

Appel API:

- aucun appel supplémentaire à cette étape.

---

### 5.4 Étape 3 - Paiement + création réservation (issue #29)

Éléments UI:

- formulaire:
  - `TITULAIRE DE LA CARTE`
  - `NUMÉRO DE CARTE` (formatage en groupes de 4)
  - `EXPIRATION` (format `MM/YY`)
  - `CVV` (3 chiffres)
- bouton `Payer X.XX €`.

Validations locales:

- titulaire obligatoire;
- numéro de carte: 16 chiffres min;
- expiration: longueur min 5 (`MM/YY`);
- CVV: longueur min 3;
- présence d'un tarif sélectionné.

Action `Payer` (`_submitPayment`):

1. validation formulaire;
2. appel API de création de réservation;
3. navigation `pushReplacement` vers `BookingSuccessScreen` avec:
   - `reservationId`
   - `propertyName`
   - `montantTotal`.

Appel API:

- `POST /reservations`

Payload envoyé:

```json
{
  "date_debut": "YYYY-MM-DD",
  "date_fin": "YYYY-MM-DD",
  "id_bien": 123,
  "id_tarif": 456
}
```

Notes importantes:

- les données de carte **ne sont pas envoyées** au backend;
- le paiement est simulé côté UI, puis la réservation est créée côté API.

Gestion d'erreurs:

- erreurs Dio converties via `ApiService.handleError`;
- fallback générique: `Erreur lors du paiement. Veuillez réessayer.`

---

## 6. BookingSuccessScreen - Confirmation (issues #30 et #18)

Éléments UI implémentés:

- icône de validation verte (`check_circle`);
- titre: `Réservation confirmée !`;
- nom du bien;
- montant total;
- numéro de réservation (si présent);
- message: confirmation par email;
- bouton `Retour à l'accueil`.

Action bouton:

- navigation vers `MainNavScreen` avec purge de pile (`pushAndRemoveUntil`).

Appels API:

- aucun appel API effectué par cet écran.

---

## 7. Endpoints API réellement utilisés

| Méthode | Endpoint | Déclencheur UI | Code |
|---|---|---|---|
| GET | `/biens/:id/tarifs` | ouverture de `BookingScreen` | `ReservationService.getPropertyTarifs` |
| GET | `/biens/:id/photos` | ouverture de `BookingScreen` | `ReservationService.getPropertyPhotos` |
| GET | `/biens/:id/disponibilite` | clic `Continuer` en étape 1 | `_checkAvailability` |
| POST | `/reservations` | clic `Payer` en étape 3 | `ReservationService.createReservation` |
| GET | `/reservations` | ouverture `MyReservationsScreen` | `ProfileService.getReservations` |

Contexte technique:

- base URL configurée dans `ApiConfig.baseUrl`;
- client HTTP unique via `ApiService` (Dio);
- token JWT injecté dans les headers (si utilisateur connecté);
- gestion centralisée des messages d'erreur réseau/API.

---

## 8. Écran Mes réservations (complément système)

`MyReservationsScreen` apporte la lecture et le suivi des réservations créées.

Fonctionnalités UI:

- filtres: `Tout`, `À venir`, `En cours`, `Passées`;
- cards de réservation avec statut, montant, bien, commune, dates;
- bottom sheet de détails;
- action `Modifier` affichée pour les réservations à venir.

Actions déclenchées:

- `GET /reservations` au chargement et au pull-to-refresh;
- action `Modifier`: actuellement non implémentée (SnackBar informatif).

---

## 9. Conformité aux issues #29, #30, #18

| Exigence | Statut | Détail |
|---|---|---|
| #29 - Booking en 3 étapes | Conforme | Étapes 1/2/3 présentes, progression visuelle, boutons Continuer/Confirmer/Payer |
| #29 - Étape 1 (voyageurs + dates) | Conforme | Compteur voyageurs, DateRangePicker, calcul nuits |
| #29 - Étape 2 (récap coûts) | Conforme | Logement + frais service + total + badge paiement sécurisé |
| #29 - Étape 3 (paiement + création réservation) | Partiellement conforme | Formulaire présent + POST /reservations; paiement non connecté à un PSP |
| #30 - Page BookingSuccess | Conforme | Icône, message confirmation, info email, bouton retour accueil |
| #18 - Affichage numéro réservation | Conforme | Affiche `id_reservations` si présent |
| #18 - Notification non lue générée (`notifications.is_read = 0`) | Dépend backend | Aucun appel explicite côté mobile; attendu réalisé côté API lors du POST /reservations |

---

## 10. Séquence technique (runtime)

```text
Utilisateur -> BookingScreen: Ouvrir
BookingScreen -> API: GET /biens/:id/tarifs
BookingScreen -> API: GET /biens/:id/photos

Utilisateur -> BookingScreen: Choisir dates + Continuer
BookingScreen -> API: GET /biens/:id/disponibilite
API --> BookingScreen: {disponible: true|false}

Utilisateur -> BookingScreen: Confirmer (étape 2)
Utilisateur -> BookingScreen: Payer (étape 3)
BookingScreen -> API: POST /reservations
API --> BookingScreen: {id_reservations, ...}
BookingScreen -> BookingSuccessScreen: Navigation + données de confirmation

Utilisateur -> BookingSuccessScreen: Retour à l'accueil
BookingSuccessScreen -> MainNavScreen: Navigation reset stack
```

---

## 11. Points d'attention techniques

1. **Capacité voyageurs non envoyée au backend**
   - `_travelers` sert à l'UI/récapitulatif mais n'est pas transmis dans `POST /reservations`.

2. **Paiement non intégré à un prestataire**
   - les champs CB sont validés localement seulement;
   - aucune tokenisation/capture de paiement côté API mobile.

3. **Conformité notification #18**
   - la génération de notification de confirmation n'est pas pilotée par un appel mobile dédié;
   - elle doit être implémentée côté backend sur la création de réservation.

4. **Modification réservation non disponible dans l'app**
   - UI visible dans `MyReservationsScreen`, mais comportement encore à venir.

---

## 12. Recommandations d'évolution

1. Ajouter des validations métier supplémentaires côté mobile:
   - date de fin strictement > date de début;
   - cohérence max voyageurs vs règles métier backend.

2. Enrichir `POST /reservations` si nécessaire métier:
   - inclure explicitement nombre de voyageurs;
   - inclure un récapitulatif tarifaire serveur (ou récupérer le total calculé backend).

3. Introduire un vrai flux de paiement:
   - PSP (Stripe/Adyen/etc.), token de paiement, confirmation serveur.

4. Vérifier la création de notification backend après réservation:
   - test d'intégration API: `POST /reservations` puis `GET /notifications`.

5. Implémenter la modification/annulation de réservation:
   - endpoint dédié + UX associée dans `MyReservationsScreen`.
