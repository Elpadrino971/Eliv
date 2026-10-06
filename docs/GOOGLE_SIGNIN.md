# Connexion Google — pourquoi ça échouait, et quoi faire dans les consoles

## Diagnostic

`android/app/google-services.json` contient, pour le package `com.app.vybzz` :

```json
"oauth_client": []
```

Aucun client OAuth Android n'est enregistré dans le projet Firebase `vybzzz-app`,
donc aucune empreinte SHA-1 de signature. Sur Android, Google Sign-In (Credential
Manager) refuse alors l'app : le sélecteur de compte se ferme ou ne s'ouvre pas,
et l'app affichait "Connexion non aboutie".

Deuxième fragilité : l'app passait ensuite par Firebase Auth (`signInWithCredential`),
qui exige que le fournisseur Google soit activé dans Firebase > Authentication.
Étape inutile : le backend vérifie déjà l'id_token auprès de Google
(`backend/src/services/social_auth.js`). Elle a été retirée du code.

## Côté code (fait)

- `lib/services/google_sign_in.dart` : plus de Firebase Auth ; renvoie email, nom,
  id_token ; annulation silencieuse ; raison courte de l'échec dans `googleLastError`.
- `lib/Auth/login_screen.dart` : le message d'échec affiche la raison entre
  parenthèses, ex. `(clientConfigurationError)` = SHA-1 / client OAuth manquant.

## Côté consoles (à faire une fois)

### 1. Récupérer les 3 empreintes SHA-1

Sur le Mac, dans le dossier du projet :

```bash
# clé d'upload (celle de android/key.properties) — mot de passe demandé
keytool -list -v -keystore android/app/upload-keystore.jks | grep -E "Alias|SHA1"

# clé debug (pour flutter run)
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android | grep SHA1
```

Troisième empreinte : Play Console > Configuration > Intégrité de l'application >
"Certificat de clé de signature d'application" > SHA-1. C'est la clé avec laquelle
Google re-signe l'app publiée : sans elle, la version du Play Store ne peut pas se
connecter, même si la version locale fonctionne.

### 2. Firebase

Console Firebase > projet `vybzzz-app` > Paramètres du projet > Vos applications >
Android `com.app.vybzz` > "Ajouter une empreinte" : coller les 3 SHA-1.

Puis "Télécharger google-services.json" et remplacer `android/app/google-services.json`.
Le fichier doit maintenant contenir un `oauth_client` de `client_type: 1` par empreinte.
Rebuild Android ensuite.

### 3. Backend

`GOOGLE_CLIENT_IDS` dans `/opt/vybzzz/.vybzzz.env` doit contenir les deux clients
(IDs publics, présents dans le dépôt) :

- Web : `284585255358-raknf147buj3vn5ch4ia67u8742fhgt2.apps.googleusercontent.com`
  (audience de l'id_token sur Android)
- iOS : `284585255358-gkcfj2vg7cte3dql3r8i7b1rdkrkghu9.apps.googleusercontent.com`
  (audience de l'id_token sur iPhone)

Contrôle sans afficher le fichier :

```bash
grep -o 'raknf147\|gkcfj2vg' /opt/vybzzz/.vybzzz.env | sort -u
```

Attendu : deux lignes. Si une manque, l'ajouter à la variable puis relancer le conteneur
(`docker restart vybzzz`).

### 4. iOS

Rien à changer : `GoogleService-Info.plist` et le schéma d'URL
`com.googleusercontent.apps.284585255358-gkcfj2vg...` sont cohérents.
