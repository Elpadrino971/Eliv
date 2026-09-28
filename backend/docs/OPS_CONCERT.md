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
