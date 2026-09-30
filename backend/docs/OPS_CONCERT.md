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
