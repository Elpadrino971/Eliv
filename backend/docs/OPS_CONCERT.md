# Exploitation — soir de concert (backend VybzzZ)

Mémo court pour le VPS (Docker, conteneur `vybzzz`, base SQLite dans le volume).

## 1. Sauvegardes

Le script `scripts/backup-db.js` fait une copie cohérente de la base (API `.backup()`
de SQLite, sûre même pendant l'écriture) et garde les 14 dernières (`VYBZZZ_BACKUP_KEEP`).

Cron sur l'HÔTE (toutes les heures, sauvegardes dans `/data/backups` monté dans le conteneur) :

```
0 * * * * docker exec -e VYBZZZ_BACKUP_DIR=/data/backups vybzzz node scripts/backup-db.js >> /var/log/vybzzz-backup.log 2>&1
```

Sauvegarde manuelle **juste avant le live** (et une autre juste après) :

```
docker exec -e VYBZZZ_BACKUP_DIR=/data/backups vybzzz node scripts/backup-db.js
ls -lh /data/backups | tail -3
```

Vérifie que `/data/backups` est bien un volume persistant (pas le disque du conteneur).

## 2. Variables d'environnement à vérifier avant le déploiement

Le serveur **refuse de démarrer** en `NODE_ENV=production` si l'une de ces valeurs manque :

| Variable | Rôle |
|---|---|
| `JWT_SECRET` | ≥ 32 caractères aléatoires (`openssl rand -hex 32`) |
| `RESEND_API_KEY` | envoi des codes OTP (sans lui, plus de code « 1234 » : démarrage refusé) |
| `MUX_WEBHOOK_SECRET`, `STRIPE_WEBHOOK_SECRET` | signature des webhooks |
| `ADMIN_INITIAL_PASSWORD` | uniquement si la base est **vide** au démarrage (≥ 12 caractères) ; crée `admin@vybzzz.com` (ou `ADMIN_INITIAL_EMAIL`) |

À vérifier aussi (pas bloquant au démarrage, mais bloquant pour la fonctionnalité) :

- `EMAIL_FROM` : expéditeur sur un domaine vérifié Resend (ex. `VybzzZ <no-reply@vybzzz.online>`).
  Tant qu'il reste sur `resend.dev`, les codes n'arrivent qu'au propriétaire du compte Resend.
- `REVENUECAT_API_KEY`, `REVENUECAT_WEBHOOK_AUTH` : billets achetés dans l'app.
- `STRIPE_SECRET_KEY` (+ `STRIPE_*`) : billetterie du site, abonnements web.
- `GOOGLE_CLIENT_IDS`, `APPLE_BUNDLE_ID` : connexion sociale (sans eux, l'audience du jeton n'est pas contrôlée).
- `ZEGO_APP_ID`, `ZEGO_SERVER_SECRET` (32 caractères) : jetons du live Zego (app + écrans Stage/Régie).
- `SIGHTENGINE_API_USER`, `SIGHTENGINE_API_SECRET`, `SIGHTENGINE_CALLBACK_TOKEN` : modération
  (en prod, un callback sans `SIGHTENGINE_CALLBACK_TOKEN` configuré est refusé).
- `PUBLIC_BASE_URL` (`https://api.vybzzz.online`) : URLs des fichiers uploadés et des liens de validation.

## 3. Comptes de démo

L'ancien seed créait `demo@vybzzz.com`, `fan1..14@vybzzz.com`, `artist1..5@vybzzz.com`
(mot de passe `password`) et `admin@vybzzz.com/admin123`. Le seed de production ne crée plus
que l'admin. Sur une base existante, purge (après sauvegarde) :

```
docker exec vybzzz node scripts/purge-demo-accounts.js           # dry-run : liste ce qui partirait
docker exec vybzzz node scripts/purge-demo-accounts.js --apply   # exécute
```

Le script ne touche qu'à cette liste fermée d'e-mails (jamais un admin), et supprime avec eux
leurs billets/suivis/avis et les concerts fictifs dont ils sont l'artiste.

Change ensuite le mot de passe de l'admin depuis la console (`/admin`, profil) s'il est encore `admin123`.

## 4. Le soir du live — check-list

1. Sauvegarde manuelle (§1).
2. `docker logs -f vybzzz` ouvert : les erreurs process sont préfixées `[process]`, les uploads refusés `[uploads]`.
3. Le concert est `status = live`, `ticket_price` correct, `has_live_chat = 1`.
4. Un compte fan test **avec billet** voit `has_ticket: true` sur `GET /api/event/:id` et peut écrire dans
   `POST /api/live/:id/messages` ; un compte **sans billet** reçoit 403.
5. Limiteur : 10 tentatives / 15 min par (IP + e-mail) sur login/inscription/OTP, 300 / 15 min par IP.
   Un lot de fans derrière la même IP mobile n'est plus bloqué collectivement.
6. Après le live : nouvelle sauvegarde, vérifier `/api/artist/revenue-transactions` de l'artiste
   (billets app + site confondus).


## Tests d'achat avant lancement (sandbox Apple / Play)

En production, les achats sandbox (TestFlight, comptes testeurs, builds de
développement) sont refusés : aucun argent n'est encaissé. Pour tester le
parcours d'achat sur un vrai téléphone avant le lancement, ajouter dans
`.vybzzz.env` :

    RC_ALLOW_SANDBOX=1

puis redémarrer le conteneur. **Retirer la ligne (et redémarrer) avant tout
concert payant réel** : sinon un testeur obtient un vrai billet et l'artiste
une part sur une vente fictive.


## Regarder le live sur le site (live.html)

Un fan qui paie sur le site (Stripe), ou réserve un concert gratuit, regarde
tout de suite sur `https://vybzzz.online/live.html?e=<id du concert>`, sans
application. Il reçoit aussi son lien par e-mail. Un billet acheté dans l'app
s'ouvre aussi sur le site (« J'ai déjà ma place » → « Compte VybzzZ »).

**Protection du flux (obligatoire avant d'ouvrir la lecture web) :**

1. Dans Mux : *Settings → Signing Keys → Generate new key* (environnement de
   production). Mux affiche un **Key ID** et une **clé privée encodée en
   base64** (une seule fois : la copier tout de suite).
2. Dans `.vybzzz.env` :

       MUX_SIGNING_KEY_ID=<Key ID>
       MUX_SIGNING_KEY_PRIVATE=<clé privée base64, sur une seule ligne>

3. Redémarrer le conteneur.

Sans ces deux variables, la lecture web est **refusée** (message « regarde
dans l'application ») : le site ne reçoit jamais l'identifiant public du flux.
`WATCH_ALLOW_PUBLIC=1` lève ce refus : réservé aux tests, jamais en production.

Ce que fait la protection :
- le navigateur ne reçoit qu'une URL **signée qui expire** (4 h pour un
  direct, 3 h pour un replay), jamais écrite dans la page ;
- l'URL ne se lit **que depuis vybzzz.online** (restriction Mux sur le
  domaine, créée automatiquement à la première lecture) : copiée dans VLC,
  un autre site ou envoyée à quelqu'un, elle ne marche pas ;
- une place s'ouvre sur **2 écrans à la fois** au plus (`WATCH_MAX_DEVICES`) ;
- chaque image porte un **filigrane** (e-mail masqué + n° de place) qui se
  déplace : une capture qui circule dit de quelle place elle vient
  (`SELECT email FROM web_watch_tokens WHERE id = <n° de place>`) ;
- une place remboursée coupe l'accès dans les 20 s.

Limite : aucune technique web n'empêche de filmer l'écran avec un autre
appareil. Seule une protection DRM (Widevine / FairPlay) rend les captures
noires sur une partie des appareils ; elle se négocie avec Mux.

**Mode téléphone** : le site lit le relais Zego → Mux, créé seulement si le
replay est activé sur le concert (réglage par défaut). Replay désactivé =
pas de lecture sur le site pour ce concert.


## Lancer un live depuis le navigateur (studio web)

L'artiste ouvre le studio sur le site (webcam + micro), sans application. Le
navigateur envoie son flux par WebSocket au backend ; le backend le passe à
**ffmpeg**, qui le pousse en RTMP vers un Live Stream **Mux**. Le concert est
créé en `live_mode='pro'` : les fans de l'app (lecteur HLS « pro ») et du site
(`/api/watch/stream`) lisent le même HLS Mux. Rien à changer côté app.

    navigateur --WebSocket--> backend (Node) --stdin--> ffmpeg --RTMPS--> Mux --HLS--> fans

### Activer

1. Dans `.vybzzz.env` : `STUDIO_WEB=1` (sans cette variable, toutes les routes
   `/api/studio/*` répondent 404 « Indisponible. », sauf `GET /api/studio/status`).
   Mux doit être configuré (`MUX_TOKEN_ID`, `MUX_TOKEN_SECRET`, `MUX_WEBHOOK_SECRET`)
   et les clés de lecture signée du site aussi (section précédente).
2. Reconstruire l'image : `backend/Dockerfile` installe `ffmpeg`
   (Debian bookworm, `--no-install-recommends`). Impact : environ **+170 à
   250 Mo** sur l'image (mesure non faite : pas de démon Docker dans
   l'environnement de développement ; à relever avec `docker images` avant/après).
3. Ajouter le WebSocket côté **nginx de l'hôte API** (`api.vybzzz.online`), dans
   le `server { … }` existant, **avant** le `location /` général :

       location /api/studio/ingest {
           proxy_pass http://127.0.0.1:8002;
           proxy_http_version 1.1;
           proxy_set_header Upgrade $http_upgrade;
           proxy_set_header Connection "upgrade";
           proxy_set_header Host $host;
           proxy_set_header X-Real-IP $remote_addr;
           proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
           proxy_set_header X-Forwarded-Proto $scheme;
           proxy_read_timeout 3600s;
           proxy_send_timeout 3600s;
           proxy_buffering off;
           client_max_body_size 0;
       }

   Puis `nginx -t && systemctl reload nginx`. Sans ce bloc, le navigateur reste
   sur « connexion… » (le `Upgrade` n'est pas transmis). `proxy_read_timeout
   3600s` : le backend envoie un ping toutes les 15 s, la connexion tient donc
   tant que le live dure ; si un live dépasse 1 h, le navigateur se reconnecte
   tout seul (nouveau jeton) et Mux garde le flux ouvert 60 s.
4. Redémarrer le conteneur, puis vérifier :
   `curl https://api.vybzzz.online/api/studio/status` → `{"data":{"enabled":true,"ffmpeg":true}}`.
   `ffmpeg:false` = image non reconstruite.

Variables facultatives : `STUDIO_RTMP_BASE` (défaut `rtmps://global-live.mux.com:443/app` ;
ne changer que pour des tests), `STUDIO_WS_URL` (défaut dérivé de
`PUBLIC_BASE_URL`, sinon `wss://api.vybzzz.online/api/studio/ingest`),
`STUDIO_FFMPEG` (chemin du binaire), `SITE_URL` (liens `watch_url` / `web_url`).

### Comment ça se comporte

- `POST /api/studio/live` (artiste, 5 lancements / 15 min) crée le concert
  (prix de la grille, replay au choix, chat, fenêtre de 6 h), le flux Mux
  (latence `low`, fenêtre de reconnexion 60 s) et renvoie un jeton d'ingest de
  30 min. **La clé Mux ne quitte jamais le serveur** (ni réponse, ni journal).
- Un artiste = une session à la fois (409 + la session en cours sinon). Une session
  préparée mais jamais lancée est annulée après 60 min (flux Mux supprimé).
- Coupure réseau du navigateur : ffmpeg est arrêté, le concert reste « live »
  90 s. Si le navigateur revient (`POST /api/studio/live/:id/token`, puis
  nouveau WebSocket), un **nouveau ffmpeg** reprend sur la même clé Mux ; sinon le
  concert passe `completed` et Mux est notifié (`PUT /live-streams/:id/complete`).
- Plafond dur : 6 h de direct. Un serveur trop lent (retard > 6 Mo dans le tube
  ffmpeg) coupe la connexion au lieu de dériver.
- Redémarrage du conteneur en plein live : le navigateur a 90 s pour se reconnecter.

### CPU et débit

- **Vidéo H.264 reçue (`mime` contient `h264` ou `avc1`)** : `-c:v copy`, quasi
  aucun CPU (mesuré : ≈ 3 à 4 % d'un cœur pour 640×360). Seul l'audio est
  ré-encodé en AAC 128 k.
- **Autre codec (VP8/VP9, Firefox)** : transcodage `libx264 veryfast`, 2,5 Mb/s,
  image clé toutes les 2 s, réduit à 720 p max. Mesuré sur une mire synthétique
  (facile à encoder) : ≈ 14 % d'un cœur en 640×360, ≈ 25 % en 1280×720/30 i/s.
  Une vraie webcam (mouvement, bruit) coûte 2 à 3 fois plus : **prévoir ≈ 0,5 à
  0,75 cœur par live transcodé** et surveiller `docker stats` au premier concert.
- Bande passante montante du serveur : ≈ 2,5 à 3 Mb/s par live (RTMPS vers Mux) ;
  entrante : ce que le navigateur envoie (1 à 4 Mb/s).
- Latence mesurée en local : premier morceau envoyé par le navigateur → première
  image reçue côté Mux ≈ 2 à 2,5 s (message `live` après ≈ 1,2 à 1,6 s). S'y ajoute
  la latence HLS de Mux en mode `low` (≈ 5 à 10 s) avant que les fans voient l'image.

### Navigateurs

| Navigateur | MediaRecorder | Chemin serveur |
|---|---|---|
| Chrome / Edge (ordinateur), Chrome Android | `video/webm;codecs=h264,opus` si disponible, sinon vp8/vp9 | copie si H.264, sinon transcodage |
| Safari iOS ≥ 14.3 / macOS | `video/mp4` (H.264 + AAC) | copie |
| Firefox | `video/webm;codecs=vp8,opus` | transcodage |

La page du studio doit passer à `mime` le type **réellement** utilisé par le
`MediaRecorder` (`recorder.mimeType`), URL-encodé. Si l'écran est verrouillé
ou l'onglet passé en arrière-plan, certains navigateurs mobiles suspendent la
caméra : prévenir l'artiste de garder l'écran allumé.

### Check-list de test (avant un vrai concert)

1. `GET /api/studio/status` → `enabled:true, ffmpeg:true`.
2. Compte artiste : ouvrir le studio, créer un live **gratuit** « test », autoriser caméra/micro.
3. Le studio affiche « en direct » en moins de ~3 s ; l'admin (Concerts → Live Mux)
   montre le flux « ● reçu » et l'event passe `live`.
4. Sur un téléphone, dans l'app, le concert apparaît « en direct » et la vidéo se lit ;
   idem sur `live.html?e=<id>`.
5. Couper le Wi-Fi de l'artiste 20 s, le rétablir : le studio se reconnecte, l'event
   reste `live`, les fans ne voient qu'un blocage de quelques secondes.
6. Couper 2 minutes (pas de retour) : l'event passe `completed`.
7. Cliquer sur « Terminer » : `completed`, replay disponible quelques minutes après (webhook Mux).
8. `docker stats` pendant le live : un seul processus `ffmpeg`, CPU conforme (copie vs transcodage).
9. `docker logs` : lignes `[studio] …`, jamais de clé Mux ni de jeton.

Test automatique sans Mux réel (faux Mux + récepteur RTMP local, ffmpeg requis) :
`cd backend && node scripts/test-studio.js`.
