# « Partager → VYBZZZ » (partage entrant)

Fait apparaître **VYBZZZ** dans la feuille de partage native du téléphone
(« Envoyer à »), comme WhatsApp / Snapchat. L'artiste partage une **vidéo**
(depuis sa galerie ou une autre app) → l'app s'ouvre sur l'écran de création
de clip, **vidéo déjà chargée**.

## ⚠️ Aucune validation TikTok / Instagram
Ce n'est **pas** une intégration TikTok. C'est le **partage système** (iOS/Android).
TikTok ne valide rien et ne peut pas bloquer l'app dans la feuille de partage.
La seule revue = celle **normale d'Apple / Google** à la soumission du build.

Rappel pratique : depuis TikTok, le partage direct passe souvent un **lien**
(pas le fichier). Le flux fiable = **enregistrer la vidéo (galerie) → Partager → VYBZZZ**.

---

## Android — ✅ déjà fait (rien à faire)
- `android/app/src/main/AndroidManifest.xml` : intent-filters `SEND` / `SEND_MULTIPLE`
  pour `video/*` ajoutés sur `MainActivity`.
- Fonctionne dès le prochain build Android.

## iOS — étape Xcode à faire une seule fois (~5 min)
iOS impose une **« Share Extension »** (une cible séparée). À créer dans Xcode
(impossible à distance). Bundle app = `com.app.vybzz`.

1. **Ouvre** `ios/Runner.xcworkspace` dans Xcode.
2. **File → New → Target… → Share Extension.**
   - Product Name : `ShareExtension`
   - Décoche « Activate scheme » si proposé.
3. **App Group** (partage du fichier entre l'extension et l'app) — à ajouter sur
   **les deux** cibles (`Runner` ET `ShareExtension`) :
   - Onglet **Signing & Capabilities → + Capability → App Groups**.
   - Ajoute le groupe : `group.com.app.vybzz`
4. **Remplace** le fichier `ShareViewController.swift` généré par celui du package
   `receive_sharing_intent` (voir son README / dossier `example/ios/Share Extension/`).
   En haut du fichier, mets l'App Group : `group.com.app.vybzz`.
5. **`ShareExtension/Info.plist`** — règle d'activation (accepte les vidéos) :
   ```xml
   <key>NSExtension</key>
   <dict>
     <key>NSExtensionAttributes</key>
     <dict>
       <key>NSExtensionActivationRule</key>
       <dict>
         <key>NSExtensionActivationSupportsMovieWithMaxCount</key>
         <integer>1</integer>
       </dict>
     </dict>
     <key>NSExtensionPointIdentifier</key>
     <string>com.apple.share-services</string>
     <key>NSExtensionPrincipalClass</key>
     <string>$(PRODUCT_MODULE_NAME).ShareViewController</string>
   </dict>
   ```
6. **`ios/Runner/Info.plist`** — déclare le schéma d'URL utilisé par le package
   pour transmettre le média à l'app :
   ```xml
   <key>CFBundleURLTypes</key>
   <array>
     <dict>
       <key>CFBundleURLSchemes</key>
       <array>
         <string>ShareMedia-com.app.vybzz</string>
       </array>
     </dict>
   </array>
   ```
7. **Deployment target** de `ShareExtension` = identique à `Runner` (iOS 15).
8. Build (`flutter build ipa`) → VYBZZZ apparaît dans « Envoyer à » pour les vidéos.

> Réf. officielle : https://pub.dev/packages/receive_sharing_intent (section iOS).

---

## Côté Flutter (déjà codé)
- `pubspec.yaml` : `receive_sharing_intent`.
- `lib/services/share_receiver.dart` : écoute les partages (cold + warm) et ouvre
  `CreateShortScreen(sharedVideoPath: …)`.
- `lib/BottomBar/screens/my_bottom_bar.dart` : `ShareReceiver.init()` au démarrage
  de l'accueil (utilisateur connecté).
- `CreateShortScreen` : accepte une vidéo pré-chargée.

Avant build : `flutter pub get` (nouvelle dépendance) puis `flutter analyze`.
