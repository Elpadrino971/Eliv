# VybzzZ — Commandes de déploiement (backend + app)

Deux surfaces, deux branches :

| Surface | Branche | Où |
|---|---|---|
| Backend API + admin + site (regie/stage) | `feat/vibe-crm` | VPS Hostinger, Docker `vybzzz`, nginx |
| App mobile iOS / Android | `release/app-all` | Ton Mac (Xcode / Android Studio) |

Le fichier `/opt/vybzzz/.vybzzz.env` contient les secrets. Ne jamais l'afficher, ne jamais le coller.

---

## 1) Backend + site (VPS)

Rebuild Docker obligatoire : les derniers commits touchent `backend/src`
(badges, mains levées, micro, Q&A, compte à rebours, token Zego, SSE).

```bash
# 1. Code à jour
cd /opt/vybzzz
git fetch origin feat/vibe-crm
git checkout feat/vibe-crm
git pull origin feat/vibe-crm
git log --oneline -1          # attendu : 114b72a (ou plus récent)

# 2. Sauvegarde de la base AVANT migration (les ALTER sont automatiques au boot)
mkdir -p /opt/vybzzz-backups
cp /opt/vybzzz-data/vybzzz.sqlite /opt/vybzzz-backups/vybzzz-$(date +%F-%H%M).sqlite
ls -lh /opt/vybzzz-backups | tail -3

# 3. Image
docker build -t vybzzz-backend backend/

# 4. Bascule (coupure ~5 s)
docker stop vybzzz && docker rm vybzzz
docker run -d --name vybzzz --restart unless-stopped \
  -p 127.0.0.1:8002:8002 \
  -v /opt/vybzzz-data:/data \
  -v /opt/vybzzz-storage:/app/storage \
  --env-file /opt/vybzzz/.vybzzz.env \
  vybzzz-backend

# 5. Contrôle
docker ps --filter name=vybzzz
docker logs --tail 40 vybzzz          # aucun "Error", tables créées, "listening"
curl -s https://api.vybzzz.online/api   # {"status":"success","message":"VYBZZZ API up"}
curl -s -o /dev/null -w "%{http_code}\n" https://vybzzz.online/regie.html   # 200
curl -s -o /dev/null -w "%{http_code}\n" https://vybzzz.online/stage.html   # 200

# 6. Test du temps réel (remplace ID et CLE ; Ctrl+C pour sortir)
curl -N "https://api.vybzzz.online/api/live/ID/stream?key=CLE"   # doit afficher "event: hello"
```

Ménage optionnel après validation :
```bash
docker image prune -f
ls -1t /opt/vybzzz-backups | tail -n +6 | xargs -r -I{} rm /opt/vybzzz-backups/{}
```

Retour arrière si problème :
```bash
cd /opt/vybzzz && git checkout 94ed296^   # commit précédent connu bon
docker build -t vybzzz-backend backend/ && docker stop vybzzz && docker rm vybzzz
# relancer la commande docker run du point 4
cp /opt/vybzzz-backups/<dernier>.sqlite /opt/vybzzz-data/vybzzz.sqlite   # seulement si la base est cassée
```

---

## 2) App mobile (Mac)

Version en cours : `1.1.1+14` sur `release/app-all` (ouverture directe sur Live + Feed).
Ne JAMAIS builder l'app depuis `feat/vibe-crm` (fichiers app obsolètes).

```bash
# 1. Code à jour
cd ~/Vybzzz-V12026            # ton clone local
git fetch origin release/app-all
git checkout release/app-all
git pull origin release/app-all
git log --oneline -1          # attendu : fa9be67 (ou plus récent)
grep '^version:' pubspec.yaml # version: 1.1.1+14

# 2. Environnement propre
flutter --version
flutter clean
flutter pub get
flutter analyze               # 0 error (warnings tolérés)
grep -n "mainIP = " lib/Global/api.dart   # https://api.vybzzz.online, pas d'IP locale
```

### Android (AAB pour Play Console)

Pré-requis : `android/key.properties` présent sur ton Mac (non versionné) avec
`storeFile`, `storePassword`, `keyAlias`, `keyPassword`. Sans lui, le build sort signé en debug
et le Play Store le refuse.

```bash
test -f android/key.properties && echo "keystore OK" || echo "STOP : key.properties manquant"
flutter build appbundle --release
ls -lh build/app/outputs/bundle/release/app-release.aab

# Vérification signature (release, pas debug)
keytool -printcert -jarfile build/app/outputs/bundle/release/app-release.aab | head -5
```
Upload : Play Console → VybzzZ → Production (ou Test interne) → Créer une release → glisser l'AAB
→ notes de version → Examiner → Déployer.

### iOS (IPA pour App Store Connect)

```bash
cd ios && pod install --repo-update && cd ..
flutter build ipa --release
ls -lh build/ios/ipa/*.ipa
```
Si `flutter build ipa` réclame un profil / un export :
```bash
flutter build ipa --release --export-method app-store
```
Upload : ouvre **Transporter** (Mac App Store) → glisser le `.ipa` → Livrer.
Ou depuis Xcode : `open ios/Runner.xcworkspace` → Product → Archive → Distribute App → App Store Connect.

Puis App Store Connect → VybzzZ → version 1.1.1 → sélectionner le build 14 → Soumettre pour examen.

### Test rapide sur appareil avant soumission

```bash
flutter devices
flutter run --release -d <id_du_device>
```
À vérifier à la main : ouverture directe sur Live + Feed, connexion (mail + Google), un live en cours,
un achat de points (sandbox RevenueCat), un cadeau envoyé, un billet.

---

## 3) Ordre conseillé aujourd'hui

1. Backend (section 1) — l'app 1.1.1+14 ne dépend pas des nouvelles routes, mais autant avoir la prod à jour avant les tests.
2. Android AAB → Test interne d'abord, puis Production.
3. iOS IPA → TestFlight, puis soumission.
4. Test régie réel : `https://vybzzz.online/stage.html?event=ID&key=CLE` sur l'écran de scène,
   `https://vybzzz.online/regie.html?event=ID&key=CLE` sur le téléphone / la tablette.

---

## 4) Site : nginx après l'audit (une fois)

Le site n'a plus de pages de démo et possède une vraie page 404, des pages légales,
un favicon et une image de partage. Pour que la 404 et les redirections soient réelles,
nginx doit cesser de renvoyer `index.html` pour toute adresse. Le bloc à appliquer est
dans `site/nginx.vybzzz.conf` (commenté ligne par ligne).

```bash
sudo nano /etc/nginx/sites-available/vybzzz     # coller les directives de site/nginx.vybzzz.conf
sudo nginx -t && sudo systemctl reload nginx
curl -s -o /dev/null -w "%{http_code}\n" https://vybzzz.online/page-inexistante   # attendu : 404
curl -s -o /dev/null -w "%{http_code} %{redirect_url}\n" https://www.vybzzz.online/ # attendu : 301 -> https://vybzzz.online/
curl -s -o /dev/null -w "%{http_code}\n" https://vybzzz.online/confidentialite.html # attendu : 200
```

Sans ce changement, le site reste fonctionnel : les anciennes pages redirigent d'elles-mêmes
vers l'accueil, mais une adresse inexistante affichera encore l'accueil au lieu de la 404.
