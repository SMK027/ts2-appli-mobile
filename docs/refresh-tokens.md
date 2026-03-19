# Refresh des tokens - Documentation technique

## 1. Objectif

Ce document décrit l'implémentation du mécanisme de refresh des tokens dans l'application mobile Nestvia.

Le système permet de:

- prolonger automatiquement une session quand le JWT d'accès expire;
- éviter les déconnexions intempestives pendant l'utilisation;
- appliquer une rotation des refresh tokens conforme à l'API;
- forcer la déconnexion si la régénération échoue.

---

## 2. Contrat API utilisé

## Endpoints d'authentification

- `POST /auth/login`
- `POST /auth/refresh`

## Réponse de login / refresh attendue

```json
{
  "token": "<jwt_access_token>",
  "refresh_token": "<opaque_refresh_token>",
  "refresh_expires_at": "2026-04-18T12:00:00.000Z"
}
```

## Requête de refresh

```json
{
  "refresh_token": "<opaque_refresh_token>"
}
```

## Rotation

L'API renvoie un **nouveau** `refresh_token` à chaque refresh réussi.
Le client doit donc écraser l'ancien refresh token local.

---

## 3. Composants côté mobile

- `lib/config/api_config.dart`
- `lib/services/auth_service.dart`
- `lib/services/api_service.dart`
- `lib/services/navigation_service.dart`
- `lib/main.dart`

---

## 4. Modèle de stockage local

Le stockage sécurisé est assuré via `flutter_secure_storage`.

Clés persistées:

- `auth_token` : JWT d'accès (Bearer)
- `refresh_token` : token de refresh
- `refresh_expires_at` : date d'expiration ISO du refresh

---

## 5. Flux d'authentification

## 5.1 Login

1. L'utilisateur envoie email + mot de passe (`AuthService.login`).
2. L'API répond avec `token`, `refresh_token`, `refresh_expires_at`.
3. Le client stocke les 3 valeurs en local.
4. `ApiService.setAuthToken(token)` injecte `Authorization: Bearer <token>`.

## 5.2 Démarrage application

1. `SplashScreen` appelle `AuthService.initToken()`.
2. Le token d'accès local (si présent) est injecté dans Dio.
3. `isLoggedIn()` retourne vrai si:
   - access token présent;
   - ou refresh token présent et non expiré.

---

## 6. Refresh automatique via interceptor Dio

Le refresh est centralisé dans `ApiService`.

## 6.1 Déclenchement

Dans l'interceptor `onError`:

- si code HTTP `401` sur une route protégée, tentative de refresh;
- exclusion explicite des endpoints:
  - `/auth/login`
  - `/auth/refresh`

## 6.2 Exécution refresh

Méthode interne: `_refreshAccessToken()`

1. Lire `refresh_token` depuis le secure storage.
2. Appeler `POST /auth/refresh` avec `{ refresh_token }`.
3. Valider la réponse (`token` + `refresh_token` obligatoires).
4. Sauvegarder les nouvelles valeurs (rotation).
5. Réinjecter le nouveau JWT dans les headers Dio.

## 6.3 Retry de la requête initiale

Après refresh réussi:

- la requête qui a échoué en 401 est rejouée automatiquement avec le nouveau Bearer token.

Protection anti-boucle:

- un marqueur `__refresh_retry__` est posé dans `RequestOptions.extra`;
- une requête déjà rejouée n'essaie pas un second refresh.

## 6.4 Gestion concurrence

Pour éviter les refresh multiples simultanés:

- `Completer<void>? _refreshCompleter` sérialise le refresh;
- si un refresh est déjà en cours, les autres requêtes attendent sa fin;
- une fois terminé, elles reprennent avec le token mis à jour (ou échouent si refresh KO).

---

## 7. Politique d'échec: déconnexion forcée

Si le refresh échoue (token absent, invalide, expiré, erreur serveur, payload invalide):

1. purge des tokens locaux:
   - `auth_token`
   - `refresh_token`
   - `refresh_expires_at`
2. suppression du header Authorization courant;
3. redirection forcée vers `LandingScreen`.

La redirection est gérée par `NavigationService.forceLogoutToLanding()` via une `navigatorKey` globale configurée dans `MaterialApp`.

Une protection anti-double navigation évite les redirections multiples si plusieurs requêtes échouent en même temps.

---

## 8. Gestion de session côté AuthService

## Vérification de session

`isLoggedIn()`:

- vrai si `auth_token` présent;
- sinon vrai si `refresh_token` présent et non expiré (`refresh_expires_at`);
- faux sinon.

## Déconnexion manuelle

`logout()`:

- supprime les 3 clés en secure storage;
- supprime le Bearer header de Dio.

---

## 9. Séquence technique complète

```text
Utilisateur connecté
   -> Requête API protégée
      -> API répond 401 (JWT expiré)
         -> Interceptor onError
            -> POST /auth/refresh avec refresh_token
               -> succès
                  -> stocke nouveau token + nouveau refresh_token
                  -> rejoue la requête initiale
               -> échec
                  -> purge session locale
                  -> redirection forcée LandingScreen
```

---

## 10. Points de vigilance

1. L'application ne décode pas localement le JWT pour estimer son expiration.
   - La stratégie actuelle est réactive sur 401.

2. Le refresh token est opaque et stocké en secure storage.
   - Aucune exposition en mémoire partagée ou logs applicatifs.

3. Les endpoints `/auth/login` et `/auth/refresh` ne doivent jamais être soumis au mécanisme de refresh.
   - Cela évite les boucles infinies.

4. En cas de refresh invalide, la redirection est immédiate.
   - UX volontairement stricte pour préserver l'intégrité de session.

---

## 11. Scénarios de test recommandés

1. Login nominal
- Vérifier le stockage de `auth_token`, `refresh_token`, `refresh_expires_at`.

2. JWT expiré + refresh valide
- Forcer un 401 sur endpoint protégé;
- vérifier:
  - appel `POST /auth/refresh`;
  - rotation des tokens en local;
  - replay automatique de la requête initiale.

3. JWT expiré + refresh invalide/expiré
- Vérifier:
  - purge des clés de stockage;
  - redirection vers `LandingScreen`.

4. Requêtes concurrentes avec JWT expiré
- Déclencher plusieurs appels en parallèle;
- vérifier qu'un seul refresh part;
- vérifier la stabilité UI/navigation.

---

## 12. Évolutions possibles

1. Ajouter un toast/snackbar standardisé: "Session expirée, veuillez vous reconnecter".
2. Ajouter une stratégie proactive (refresh avant expiration JWT) si nécessaire.
3. Ajouter des métriques observabilité (taux de refresh OK/KO, nombre de logout forcés).
