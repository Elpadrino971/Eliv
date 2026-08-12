# Modération de contenu (Sightengine)

Modération automatique branchée sur les **3 surfaces** + persistance des
signalements utilisateurs (exigence **App Store 1.2** pour le contenu généré
par les utilisateurs : *filtrer* + *signaler* + *bloquer*).

## Ce qui est couvert

| Surface | Où | Comportement |
|---|---|---|
| **Texte** | chat live (`/event-comment`), titre+description de concert (`/events`), bio/nom (`/update-profile`) | Bloqué **avant** insertion si grave ; « borderline » → journalisé pour revue |
| **Image** | cover de concert, photos de profil (fan + artiste) | Asynchrone ; sur blocage la photo/cover est retirée (event → `blocked`) |
| **Vidéo** | replays de concert (webhook Mux `asset.ready`), clips feed, teasers | Asynchrone via callback ; sur blocage le replay est masqué / le clip désactivé |
| **Live** | flux HLS Mux du concert en direct (cams artiste **+ fans co-host**) | Surveillance continue ; alerte sur callback (coupure auto en option) |
| **Signalements** | bouton « Signaler » (`/report-event`) | **Persistés** dans `content_reports` (avant : ne persistait rien) |

Tables ajoutées : `moderation_flags` (détections auto, file de revue) et
`content_reports` (signalements utilisateurs).

## Configuration (.env sur le VPS)

**Obligatoire :**
```
SIGHTENGINE_API_USER=xxxxx
SIGHTENGINE_API_SECRET=xxxxx
# URL PUBLIQUE de CE backend (utilisée pour le callback vidéo/live ET les URLs
# d'upload). DOIT être joignable depuis l'extérieur.
PUBLIC_BASE_URL=https://vybzzz.fryandeatfood.com
# Jeton secret qui authentifie le callback Sightengine (invente une chaîne).
SIGHTENGINE_CALLBACK_TOKEN=une_chaine_aleatoire_longue
```

**Optionnel (calibrage — valeurs par défaut sûres) :**
```
SIGHTENGINE_BLOCK_THRESHOLD=0.6     # >= ce score -> bloqué
SIGHTENGINE_REVIEW_THRESHOLD=0.35   # entre review et block -> revue humaine
SIGHTENGINE_MINOR_THRESHOLD=0.3     # mineur+sexuel = tolérance zéro (seuil bas)
SIGHTENGINE_LIVE_AUTOSTOP=0         # 1 = couper un live automatiquement sur blocage
SIGHTENGINE_TEXT_MODE=ml            # ml (IA) ou rules (règles)
SIGHTENGINE_IMAGE_MODELS=nudity-2.1,weapon,recreational_drug,gore-2.0,violence,self-harm,offensive-2.0
```

> **Tant que `SIGHTENGINE_API_USER/SECRET` sont absents, la modération est
> entièrement inactive (no-op) : rien n'est bloqué, l'app fonctionne comme
> avant.** On l'active en remplissant les clés.

## Calibrage recommandé

- **Strict sur l'illégal grave** : mineurs + sexuel (CSAM) = blocage auto seuil
  bas, zéro tolérance ; violence/armes/drogues/self-harm = blocage.
- **Souple sur le borderline** : insultes, alcool, langage → plutôt `review`
  (journalisé) que blocage, pour ne pas casser l'expérience artistique.
- **`LIVE_AUTOSTOP=0` au départ** : un faux positif ne doit pas tuer un concert.
  Passe à `1` une fois les seuils validés en conditions réelles.

## Déploiement

```bash
cd /opt/vybzzz/backend
git pull origin version-couplee
# ajoute les clés SIGHTENGINE_* dans .env (voir ci-dessus)
docker stop vybzzz && docker rm vybzzz
docker build -t vybzzz-backend .
docker run -d --name vybzzz --restart unless-stopped \
  -p 127.0.0.1:8002:8002 \
  --env-file .env \
  -v /opt/vybzzz-data:/data \
  -v /opt/vybzzz-storage:/app/storage \
  vybzzz-backend
docker logs -f vybzzz   # vérifie l'absence d'avertissement "SIGHTENGINE_CALLBACK_TOKEN absent"
```

## À finir plus tard (non bloquant)

- Écrans admin pour consulter/traiter `moderation_flags` et `content_reports`
  (les données sont déjà capturées ; il manque l'UI de revue).
- Blocage utilisateur (`block user`) côté app si pas encore présent.
- Modèle « mineur » dédié Sightengine (selon le plan souscrit) pour renforcer la
  détection CSAM au-delà de la combinaison nudité+âge.
