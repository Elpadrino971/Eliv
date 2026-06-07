# VYBZZZ — Guide de déploiement

Trois surfaces à déployer : **backend + dashboard admin (web)**, **app web (`site/`)**, **app mobile (iOS/Android)**.
Ordre conseillé : 1) backend en ligne → 2) brancher l'app dessus → 3) stores.

---

## 1) Backend + Dashboard admin → Render (le débloqueur)

> Donne une URL `https://…onrender.com` accessible partout (l'app + le dashboard).
> Pas de MCP Render : tu fais ces clics une fois, avec ton compte.

1. Crée un compte sur **https://render.com** (connecte ton GitHub).
2. **New → Blueprint** → choisis le repo `Vybzzz-V12026`.
   Render lit `backend/render.yaml` automatiquement.
3. Render crée le service **vybzzz-backend** (Docker, plan free) et génère `JWT_SECRET`.
4. Clique **Apply / Deploy**. Attends ~3-5 min (build + boot + seed auto).
5. URL obtenue, ex. `https://vybzzz-backend.onrender.com`.
   - Dashboard admin : `https://vybzzz-backend.onrender.com/admin/` (admin@vybzzz.com / admin123)
   - API : `https://vybzzz-backend.onrender.com/api`

**Domaine perso (optionnel) :** Render → Settings → Custom Domain → `api.tondomaine.fr`,
puis chez ton registrar ajoute le CNAME indiqué. HTTPS auto.

⚠️ **Plan free** : le service s'endort après inactivité (cold start ~30 s au réveil) et la base
SQLite se réinitialise à chaque redéploiement. Pour de la prod : plan **Starter** (~7$/mois) +
décommente le bloc `disk:` dans `render.yaml` (données persistantes, pas de cold start).

**Alternative Railway** : New Project → Deploy from GitHub → root `backend` (détecte le Dockerfile)
→ ajoute `JWT_SECRET` + un Volume sur `/data` + `VYBZZZ_DB=/data/vybzzz.sqlite`.

### Après déploiement : brancher l'app
Dans `lib/Global/api.dart` :
```dart
static const String mainIP = 'https://vybzzz-backend.onrender.com'; // prod
```
→ l'app marche partout (4G incluse), fini le Wi-Fi/IP locale.

---

## 2) App web (`site/`) → Vercel / Netlify / GitHub Pages

Site **statique** (HTML/CSS/JS). Déploiement le plus simple :
- **Vercel** : New Project → import du repo → Root Directory = `site` → Deploy.
- **Netlify** : Add new site → import → base directory = `site`.
- **GitHub Pages** : Settings → Pages → source = `/site`.

Si le site appelle l'API, pointe ses `fetch` vers `https://api.tondomaine.fr`.

---

## 3) App mobile (iOS + Android)

### 3.0 Pré-requis communs
- [ ] `mainIP` pointe sur le backend **HTTPS** de prod (étape 1).
- [ ] Bump version à chaque soumission : `pubspec.yaml` → `version: 1.0.0+1` (incrémenter).

### 3.1 Icône de l'app (remplacer le logo Flutter)
1. Mets ton logo carré **1024×1024** en `assets/app_icon.png`.
2. ```bash
   flutter pub get
   dart run flutter_launcher_icons
   ```
   → génère iOS + Android + web + macOS.
3. `flutter clean` puis rebuild.

### 3.2 iOS — Firebase + signature
- [ ] **`GoogleService-Info.plist` MANQUANT** : Firebase Console → projet VYBZZZ → ajoute une app iOS
      (bundle `com.app.vybzz`) → télécharge `GoogleService-Info.plist` → place-le dans `ios/Runner/`
      (et ajoute-le à la cible Runner dans Xcode). Sans ça, les **push iOS** ne marchent pas.
- [ ] Push APNs : Firebase Console → Cloud Messaging → uploade ta clé **APNs** (Apple Developer → Keys).
- [ ] Signature : Xcode → Runner → Signing & Capabilities → Team `92S4C4PWGZ` (auto).
- [ ] Capabilities : Push Notifications + Background Modes (Remote notifications).

### 3.3 Android — keystore de release (OBLIGATOIRE pour le Play Store)
La signature est en **debug** → le Play Store refuse. Crée un keystore :
```bash
keytool -genkey -v -keystore ~/vybzzz-release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias vybzzz
```
Crée `android/key.properties` (NE PAS committer) :
```
storePassword=TON_MOT_DE_PASSE
keyPassword=TON_MOT_DE_PASSE
keyAlias=vybzzz
storeFile=/Users/js/vybzzz-release.jks
```
(La config `build.gradle` release est préparée — voir 3.3b.) Puis :
```bash
flutter build appbundle --release   # génère le .aab pour le Play Store
```

### 3.4 Sécurité (avant prod — cf. docs/BACKEND_CHANGES.md)
- [ ] 🔴 **Révoquer / regénérer la clé Firebase Admin** qui avait été exposée (Google Cloud → IAM → Service Accounts).
- [ ] Vérifier que **Zego** (`appId`/`appSign`), **RevenueCat**, **Stripe** sont des clés **prod**.
- [ ] Idéalement : tokens Zego/Mux **émis côté serveur** (pas en dur dans l'app).

### 3.5 Soumission Apple (App Store Connect)
- [ ] Compte **Apple Developer** (99$/an) actif.
- [ ] App Store Connect → New App (bundle `com.app.vybzz`).
- [ ] Fiche : nom, sous-titre, description, mots-clés, catégorie (Musique).
- [ ] **URL Politique de confidentialité** (obligatoire) + URL support.
- [ ] Captures d'écran : 6,7" (1290×2796) et 6,5" (1242×2688) minimum.
- [ ] Icône 1024×1024 (sans transparence).
- [ ] Build : Xcode → Product → Archive → Distribute → App Store Connect → TestFlight → soumettre à la review.
- [ ] **App Privacy** : déclarer les données collectées (compte, usage, etc.).

### 3.6 Soumission Google (Play Console)
- [ ] Compte **Google Play Developer** (25$ une fois).
- [ ] Play Console → Create app.
- [ ] Fiche : titre, descriptions, catégorie, captures (téléphone + 7"/10").
- [ ] Icône 512×512, image de bannière 1024×500.
- [ ] **Politique de confidentialité** (URL) + **Data safety** + questionnaire contenu.
- [ ] Upload du **.aab signé** (3.3) → release production → review.

---

## Récap — ce qui BLOQUE encore (au 07/06/2026)
| Surface | Bloquant | Action |
|---|---|---|
| Backend/Dashboard | — | Déployer (étape 1) ✅ prêt |
| App web | — | Déployer statique (étape 2) ✅ prêt |
| Mobile | `mainIP` = localhost | → URL prod (après étape 1) |
| Mobile / Android | signature debug | keystore release (3.3) |
| Mobile / iOS | `GoogleService-Info.plist` manquant | Firebase Console (3.2) |
| Mobile | icône = logo Flutter | `flutter_launcher_icons` (3.1) |
| Mobile | clé Firebase Admin exposée | révoquer (3.4) |
| Stores | comptes + fiches + captures | Apple/Google (3.5/3.6) |
