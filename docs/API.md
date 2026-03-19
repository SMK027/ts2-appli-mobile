# Nestvia API

API REST pour la gestion de locations — accès utilisateur (locataire).

**URL de production** : `https://api.leofranz.fr/nestvia`

## Architecture

```
src/
├── index.js              # Point d'entrée Express
├── config/
│   └── database.js       # Pool de connexion MariaDB
├── middleware/
│   └── auth.js           # Middleware JWT
└── routes/
    ├── auth.js           # POST /login
    ├── tentatives.js     # POST /tentatives (public)
    ├── biens.js          # GET /biens (recherche), /biens/:id, blocages, photos, tarifs, avis
    ├── communes.js       # GET /communes, /communes/:id
    ├── compte.js         # GET|PUT /compte
    ├── favoris.js        # GET /favoris
    ├── notifications.js  # GET /notifications, PATCH /notifications/:id/read
    ├── photos.js         # GET /photos, /photos/:id
    ├── reservations.js   # GET|POST /reservations
    ├── tarifs.js         # GET /tarifs?id_bien=...
    └── types-bien.js     # GET /types-bien (recherche), /types-bien/:id
```

## Middleware

### Qu'est-ce qu'un middleware ?

Un **middleware** est une fonction intermédiaire qui s'exécute **entre la réception d'une requête HTTP et l'envoi de la réponse**. Dans Express, chaque requête traverse une chaîne de middlewares avant d'atteindre le code métier de la route (le *handler*).

Un middleware reçoit trois paramètres :
- **`req`** : l'objet requête (contient les headers, le body, les paramètres de l'URL, etc.)
- **`res`** : l'objet réponse (permet d'envoyer une réponse HTTP au client)
- **`next`** : une fonction qui passe la main au middleware ou au handler suivant dans la chaîne

```
Requête HTTP
     │
     ▼
┌─────────────┐     ┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   helmet()  │────>│   cors()    │────>│   json()    │────>│ authenticate│──── next() ───> Handler de route
│  (sécurité) │     │  (origines) │     │  (parsing)  │     │   (JWT)     │         OU
└─────────────┘     └─────────────┘     └─────────────┘     └─────────────┘    res.status(401)
                                                                                (rejet immédiat)
```

**Principe clé** : si un middleware appelle `next()`, la requête continue vers l'étape suivante. S'il envoie directement une réponse (ex. `res.status(401).json(...)`), la chaîne s'arrête là — la requête est rejetée avant même d'atteindre la route.

### Les middlewares globaux de cette API

Ces middlewares s'appliquent à **toutes les requêtes** entrantes. Ils sont déclarés dans `index.js` via `app.use(...)` :

| Middleware | Rôle |
|------------|------|
| `helmet()` | Ajoute automatiquement des headers HTTP de sécurité (protection contre le clickjacking, le sniffing MIME, le XSS, etc.) |
| `cors()` | Autorise les requêtes cross-origin (permet au front-end hébergé sur un autre domaine d'appeler l'API) |
| `express.json()` | Parse le body JSON des requêtes entrantes et le rend accessible via `req.body` |

### Le middleware d'authentification (`auth.js`)

Ce middleware est spécifique à cette API. Son rôle est de **vérifier le token JWT** envoyé par le client avant d'autoriser l'accès aux routes protégées.

#### Code source

```js
// src/middleware/auth.js
const jwt = require('jsonwebtoken');
const JWT_SECRET = process.env.JWT_SECRET;

function authenticate(req, res, next) {
  // 1. Récupérer le header Authorization
  const header = req.headers.authorization;

  // 2. Vérifier que le header existe et commence par "Bearer "
  if (!header || !header.startsWith('Bearer ')) {
    return res.status(401).json({ error: 'Token manquant' });
  }

  // 3. Extraire le token (tout ce qui suit "Bearer ")
  const token = header.slice(7);

  try {
    // 4. Vérifier et décoder le token avec la clé secrète
    const payload = jwt.verify(token, JWT_SECRET);

    // 5. Injecter les données utilisateur dans la requête
    req.user = payload;

    // 6. Passer au handler suivant (la route)
    next();
  } catch {
    // 7. Token invalide ou expiré → rejet
    return res.status(401).json({ error: 'Token invalide ou expiré' });
  }
}

module.exports = authenticate;
```

#### Fonctionnement étape par étape

```
Client envoie : GET /nestvia/biens
                Authorization: Bearer eyJhbGciOi...

     │
     ▼
┌──────────────────────────────────────────────────┐
│            Middleware authenticate()              │
│                                                  │
│  1. Lit req.headers.authorization                │
│     → "Bearer eyJhbGciOi..."                     │
│                                                  │
│  2. Vérifie le format "Bearer <token>"           │
│     → Si absent ou mal formé : 401 Token manquant│
│                                                  │
│  3. Extrait le token : header.slice(7)           │
│     → "eyJhbGciOi..."                            │
│                                                  │
│  4. jwt.verify(token, JWT_SECRET)                │
│     → Décode le token ET vérifie la signature    │
│     → Vérifie aussi que le token n'est pas expiré│
│     → Si échec : 401 Token invalide ou expiré    │
│                                                  │
│  5. req.user = payload                           │
│     → Stocke { id, email, iat, exp } dans req    │
│     → Accessible ensuite par toutes les routes   │
│                                                  │
│  6. next() → passe au handler de la route        │
└──────────────────────────────────────────────────┘
     │
     ▼
Handler de route : accède à req.user.id pour
savoir quel utilisateur fait la requête
```

#### Comment le middleware est appliqué aux routes

Le middleware `authenticate` n'est **pas appliqué globalement** à toutes les routes. Il est appliqué **par routeur**, ce qui permet d'avoir des routes publiques (login, tentatives) et des routes protégées :

```js
// index.js

// Routes PUBLIQUES — pas de middleware auth
app.use(`${PREFIX}/auth`, authRoutes);
app.use(`${PREFIX}/tentatives`, tentativesRoutes);

// Routes PROTÉGÉES — auth appliquée dans chaque routeur
app.use(`${PREFIX}/biens`, biensRoutes);
app.use(`${PREFIX}/compte`, compteRoutes);
// ...
```

Dans chaque fichier de route protégée, le middleware est activé via `router.use(authenticate)` :

```js
// src/routes/biens.js (et tous les autres fichiers de routes protégées)
const authenticate = require('../middleware/auth');
const router = express.Router();

router.use(authenticate);  // Toutes les routes de ce routeur passent par authenticate

router.get('/', async (req, res) => {
  // req.user est disponible ici grâce au middleware
  // ...
});
```

Cela signifie que **chaque requête** vers `/nestvia/biens`, `/nestvia/compte`, `/nestvia/favoris`, etc. passe d'abord par `authenticate`. Si le token est valide, `req.user` contient les informations de l'utilisateur connecté (son `id`, son `email`) et la route peut les utiliser pour filtrer les données (ex. ne retourner que les réservations de cet utilisateur).

#### Résumé des réponses possibles

| Situation | Résultat |
|-----------|----------|
| Pas de header `Authorization` | **401** — `{ error: "Token manquant" }` |
| Header présent mais ne commence pas par `Bearer ` | **401** — `{ error: "Token manquant" }` |
| Token présent mais signature invalide (falsifié) | **401** — `{ error: "Token invalide ou expiré" }` |
| Token présent mais expiré (> 24h) | **401** — `{ error: "Token invalide ou expiré" }` |
| Token valide | **Accès autorisé** — `req.user` contient le payload du JWT, la requête continue vers la route |

## Endpoints

Tous les endpoints sont préfixés par `/nestvia`. Tous requièrent un JWT sauf mention contraire.

### Authentification

| Méthode | Route | Auth | Description |
|---------|-------|------|-------------|
| POST | `/nestvia/auth/login` | Non | Connexion (email + password) → JWT |
| POST | `/nestvia/tentatives` | Non | Log de tentative de connexion |

### Biens

| Méthode | Route | Description |
|---------|-------|-------------|
| GET | `/nestvia/biens` | Liste des biens (avec filtres de recherche, voir ci-dessous) |
| GET | `/nestvia/biens/:id` | Détail d'un bien + prestations |
| GET | `/nestvia/biens/:id/blocages` | Blocages du bien |
| GET | `/nestvia/biens/:id/photos` | Photos du bien (URLs complètes) |
| GET | `/nestvia/biens/:id/tarifs` | Tarifs du bien (optionnel: `?date_debut=&date_fin=`) |
| GET | `/nestvia/biens/:id/disponibilite` | Vérifier la disponibilité (`?date_debut=&date_fin=`) |
| GET | `/nestvia/biens/:id/avis` | Avis validés du bien |
| POST | `/nestvia/biens/:id/avis` | Créer un avis (body: `id_reservation`, `rating` 1-5, `comment`) |

#### Filtres de recherche des biens

`GET /nestvia/biens` accepte les query params suivants, combinables :

| Paramètre | Description | Exemple |
|-----------|-------------|---------|
| `nb_personnes` | Nombre minimum de couchages | `?nb_personnes=4` |
| `tarif_min` | Tarif semaine minimum (€) | `?tarif_min=100` |
| `tarif_max` | Tarif semaine maximum (€) | `?tarif_max=300` |
| `type_bien` | ID du type de bien | `?type_bien=2` |
| `animaux` | Animaux autorisés (`oui` / `non`) | `?animaux=oui` |
| `commune` | ID de la commune | `?commune=30438` |
| `prestations` | IDs des prestations requises (toutes doivent être présentes) | `?prestations=1,3,5` |

Exemple combiné : `GET /nestvia/biens?nb_personnes=4&animaux=oui&tarif_max=300`

#### Vérification de disponibilité

`GET /nestvia/biens/:id/disponibilite?date_debut=2026-07-05&date_fin=2026-07-19`

Retourne :
```json
{
  "disponible": true,
  "reservations_conflit": [],
  "blocages_conflit": []
}
```

Si le bien est indisponible, `disponible` vaut `false` et les tableaux contiennent les réservations/blocages en conflit.

### Communes

| Méthode | Route | Description |
|---------|-------|-------------|
| GET | `/nestvia/communes` | Liste (filtres: `?search=&departement=&limit=`) |
| GET | `/nestvia/communes/:id` | Détail d'une commune |

Recherche par nom ou code postal : `GET /nestvia/communes?search=mont`

### Compte

| Méthode | Route | Description |
|---------|-------|-------------|
| GET | `/nestvia/compte` | Infos du compte connecté |
| PUT | `/nestvia/compte` | Mise à jour du compte (champs autorisés uniquement) |

Champs modifiables : `nom_locataire`, `prenom_locataire`, `dna_locataire`, `email_locataire`, `rue_locataire`, `tel_locataire`, `comp_locataire`, `id_commune`, `raison_sociale`, `siret`, `password`.

### Favoris

| Méthode | Route | Description |
|---------|-------|-------------|
| GET | `/nestvia/favoris` | Favoris du compte connecté |
| POST | `/nestvia/favoris` | Ajouter un bien aux favoris (body: `id_bien`) |
| DELETE | `/nestvia/favoris/:id_bien` | Supprimer un bien des favoris |

### Notifications

| Méthode | Route | Description |
|---------|-------|-------------|
| GET | `/nestvia/notifications` | Notifications du compte connecté |
| PATCH | `/nestvia/notifications/:id/read` | Marquer comme lue |

### Photos

| Méthode | Route | Description |
|---------|-------|-------------|
| GET | `/nestvia/photos` | Toutes les photos (URLs complètes) |
| GET | `/nestvia/photos/:id` | Détail d'une photo |

Les liens photos sont retournés en URL complète (préfixés par `APP_URL`).

### Réservations

| Méthode | Route | Description |
|---------|-------|-------------|
| GET | `/nestvia/reservations` | Réservations du compte connecté |
| GET | `/nestvia/reservations/:id` | Détail d'une réservation |
| POST | `/nestvia/reservations` | Créer une réservation (body: `date_debut`, `date_fin`, `id_bien`, `id_tarif`) |

Le montant total est calculé automatiquement (nombre de semaines × tarif).

### Tarifs

| Méthode | Route | Description |
|---------|-------|-------------|
| GET | `/nestvia/tarifs?id_bien=X` | Tarifs d'un bien (optionnel: `&date_debut=&date_fin=`) |

### Types de bien

| Méthode | Route | Description |
|---------|-------|-------------|
| GET | `/nestvia/types-bien` | Liste des types de bien (optionnel: `?search=`) |
| GET | `/nestvia/types-bien/:id` | Détail d'un type de bien |

Recherche par description : `GET /nestvia/types-bien?search=maison`

## Variables d'environnement

| Variable | Description | Exemple |
|----------|-------------|---------|
| `DB_HOST` | Hôte MariaDB | `mariadb-central` |
| `DB_PORT` | Port MariaDB | `3306` |
| `DB_USER` | Utilisateur BDD | `nestvia` |
| `DB_PASSWORD` | Mot de passe BDD | — |
| `DB_NAME` | Nom de la base | `nestvia` |
| `JWT_SECRET` | Clé secrète JWT | — |
| `JWT_EXPIRES_IN` | Durée de validité du token | `24h` |
| `PORT` | Port d'écoute de l'API | `4000` |
| `APP_URL` | URL de l'application (préfixe photos) | `https://nestvia.leofranz.fr` |

## Déploiement

### 1. Configuration

```bash
cp .env.example .env
# Éditer .env avec les vraies valeurs
```

### 2. Lancement

```bash
docker compose up -d --build
```

Le conteneur se connecte automatiquement aux réseaux `proxy` (Traefik) et `db_internal` (MariaDB centralisée).

### 3. Vérification

```bash
curl https://api.leofranz.fr/nestvia/health
```

## Sécurité

- **Authentification JWT** sur tous les endpoints sauf login et tentatives
- **Rate limiting** : 20 requêtes / 15 min sur le login, 50 / 15 min sur les tentatives
- **Helmet** : headers de sécurité HTTP
- **Requêtes paramétrées** : protection contre les injections SQL
- **Whitelist des champs** : seuls les champs autorisés sont modifiables sur le compte
- **Trust proxy** : configuré pour fonctionner derrière Traefik

## Authentification — JWT & Bearer

### Qu'est-ce qu'un JWT ?

Un **JWT** (JSON Web Token) est un jeton d'authentification sous forme de chaîne de caractères. Il permet au serveur de vérifier l'identité d'un utilisateur **sans avoir à interroger la base de données à chaque requête**.

Un JWT est composé de **trois parties** séparées par des points (`.`) :

```
eyJhbGciOiJIUzI1NiJ9.eyJpZCI6NDIsImVtYWlsIjoiYUBiLmNvbSJ9.SflKxwRJSMeKKF2QT4fwpM
|_______ HEADER _______||____________ PAYLOAD _______________||______ SIGNATURE _____|
```

| Partie | Contenu | Rôle |
|--------|---------|------|
| **Header** | Algorithme de signature + type de token | Indique *comment* le token est signé (ex. `HS256`) |
| **Payload** | Données utiles (id utilisateur, email, date d'expiration…) | Contient les informations sur l'utilisateur (appelées *claims*) |
| **Signature** | Hash du header + payload + clé secrète du serveur | Garantit que le token n'a **pas été modifié**. Seul le serveur peut la produire car il est le seul à connaître la clé secrète (`JWT_SECRET`) |

> **Analogie simple** : un JWT, c'est comme un badge visiteur tamponné. Le payload, c'est le nom écrit dessus ; la signature, c'est le tampon impossible à falsifier. Quiconque lit le badge sait qui vous êtes, mais personne ne peut en fabriquer un faux sans le tampon officiel.

Concrètement, le **payload** est encodé en Base64 (lisible par n'importe qui), mais la **signature** empêche toute modification : si un seul caractère du payload est changé, la signature ne correspond plus et le serveur rejette le token.

### Qu'est-ce que Bearer ?

**Bearer** (« porteur » en anglais) est le **schéma d'authentification HTTP** utilisé pour transmettre un JWT au serveur. C'est une convention standardisée ([RFC 6750](https://datatracker.ietf.org/doc/html/rfc6750)) : on envoie le token dans le header HTTP `Authorization` avec le préfixe `Bearer` :

```
Authorization: Bearer eyJhbGciOiJIUzI1NiJ9.eyJpZCI6NDJ9.SflKxw...
```

Le principe est simple : **quiconque possède (« porte ») ce token est considéré comme authentifié**. C'est pour cela qu'il ne faut jamais le partager ou l'exposer côté client de manière non sécurisée.

### Flux d'authentification dans cette API

```
┌──────────┐                         ┌──────────┐
│  Client  │                         │ Serveur  │
└────┬─────┘                         └────┬─────┘
     │                                    │
     │  1. POST /nestvia/auth/login       │
     │    { email, password }             │
     │ ──────────────────────────────────>│
     │                                    │  Vérifie email + password en BDD
     │                                    │  Génère un JWT signé avec JWT_SECRET
     │  2. Réponse : { token: "eyJ..." } │
     │ <──────────────────────────────────│
     │                                    │
     │  3. GET /nestvia/biens             │
     │    Authorization: Bearer eyJ...    │
     │ ──────────────────────────────────>│
     │                                    │  Vérifie la signature du JWT
     │                                    │  Extrait l'id utilisateur du payload
     │  4. Réponse : données protégées   │
     │ <──────────────────────────────────│
```

1. Le client envoie ses identifiants (email + mot de passe) au endpoint de login.
2. Le serveur vérifie les identifiants, puis renvoie un **JWT signé** valide pendant la durée définie par `JWT_EXPIRES_IN` (ici `24h`).
3. Pour chaque requête protégée, le client inclut le token dans le header `Authorization: Bearer <token>`.
4. Le middleware `auth.js` décode le token, vérifie sa signature et sa validité, puis injecte les infos utilisateur dans la requête. Si le token est absent, expiré ou invalide, la requête est rejetée avec un code **401**.

### Exemple concret

**1. Obtenir un token :**

```bash
curl -X POST https://api.leofranz.fr/nestvia/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email": "user@example.com", "password": "secret"}'
```

Réponse : `{ "token": "eyJ..." }`

**2. Utiliser le token dans les requêtes suivantes :**

```bash
curl https://api.leofranz.fr/nestvia/biens \
  -H "Authorization: Bearer eyJ..."
```

> **Résumé** : JWT = le format du jeton (header.payload.signature) ; Bearer = la méthode pour l'envoyer au serveur (via le header HTTP `Authorization`).
