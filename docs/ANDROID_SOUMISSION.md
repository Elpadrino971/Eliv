# VybzzZ — Soumission Google Play (1.2.0+19)

Runbook Android, branche `release/app-all`. Deux scripts font le gros du travail :
`scripts/android-signing.sh` (clé d'importation) puis `scripts/android-release.sh` (build + vérif).
Textes du store : `docs/store/fiches-store-12-langues.md`. Détail Google Sign-In : `docs/GOOGLE_SIGNIN.md`.

## 1. Clé de signature

Play App Signing est actif : **Google détient la clé de signature de l'app**, toi tu signes l'AAB avec
une **clé d'importation** (upload key). Perdre cette clé n'est pas grave, Google peut l'enregistrer à nouveau.
`android/key.properties` (ignoré par git) est obligatoire : sans lui, `build.gradle.kts` signe en **debug**
sans rien dire et Play refuse l'import.

```bash
bash scripts/android-signing.sh
```

Le script liste tous les keystores du Mac avec leur SHA-256, marque `INUTILISABLE` celui du 25/09
(chaîne de certificat vide), te demande l'empreinte affichée dans Play Console
(*Configuration → Intégrité de l'application → Signature d'application Play → Certificat de la clé d'importation*)
et écrit `key.properties`. Trois cas :

| Cas | Ce qui se passe | Suite |
|---|---|---|
| **Keystore trouvé** (SHA-256 identique à Play Console) | `key.properties` écrit | passe au §2 tout de suite |
| **Aucun ne correspond → reset demandé** | nouvelle clé `~/Desktop/vybzzz-upload-AAAAMMJJ.jks` + `~/Desktop/upload_certificate.pem`, `key.properties` écrit | Play Console → *Intégrité de l'application* → « Demander la réinitialisation de la clé d'importation » → téléverser le `.pem` |
| **Attente Google** | e-mail de confirmation sous 1 à 2 jours ; la clé est valide **à la date indiquée** | avant cette date, ne rien envoyer : Play refuserait l'AAB |

Sauvegarde le `.jks` **et** son mot de passe à deux endroits (gestionnaire de mots de passe + disque/cloud).
Un mot de passe oublié = keystore inutilisable, comme celui du 25/09.

## 2. Build et vérification

```bash
bash scripts/android-release.sh              # flutter clean + pub get + build appbundle --release
bash scripts/android-release.sh --verify-only # revérifie un AAB déjà construit
```

Le script compare le SHA-256 du signataire de `build/app/outputs/bundle/release/app-release.aab` à celui du
keystore de `key.properties`, **échoue** si c'est la clé de debug ou une autre clé, affiche taille et chemin,
puis ouvre le dossier dans le Finder. `pubspec.yaml` : `1.2.0+19` (code 19 > 8 en production, pas de conflit).

## 3. Play Console — checklist

Production :
- *Production → Créer une version* → téléverser `app-release.aab` → *Notes de version* : bloc
  « Nouveautés 1.2.0 » de `docs/store/fiches-store-12-langues.md` (fr-FR au minimum, 12 langues idéalement)
  → *Enregistrer* → *Examiner la version* → *Démarrer le déploiement en production*.
- Refus « signé avec une mauvaise clé » : la clé d'importation n'est pas (encore) celle de Google → §1, cas 2/3.

Fiche et contenu (menu *Présence sur le Store* / *Règles et programmes → Contenu de l'app*) :
- Fiche principale : descriptions courte/complète depuis `fiches-store-12-langues.md` (*Gérer les traductions*).
- *Sécurité des données* : formulaire à jour (compte, e-mail, contenus créés, achats, identifiants d'appareil,
  données chiffrées en transit, suppression possible depuis l'app).
- *Suppression de compte* : URL publique de la page de suppression + suppression dans l'app (Réglages).
- *Contenu de l'app* : classification du contenu, *Public cible* (18+ ou 13+ selon la réponse retenue, pas d'enfants),
  *Annonces* = **Non**, application d'actualités = Non, fonctionnalités financières = Non, santé = Non.
- Achats intégrés : *Monétiser → Produits → Produits intégrés* doit contenir `ticket_2`, `ticket_4`, `ticket_6`,
  `ticket_9`, `ticket_14` (actifs, prix renseignés dans les pays ciblés). Un produit absent = achat impossible dans l'app.
- Google Sign-In : le SHA-1 de la **clé de signature d'application** (celle de Google, même page *Intégrité de
  l'application*) doit être dans Firebase → Paramètres du projet → app Android `com.app.vybzz` → *Ajouter une empreinte*.
  Retélécharger `android/app/google-services.json` après ajout et vérifier :
  `python3 scripts/verifier-google-services.py android/app/google-services.json <SHA-1>`.
  Sans ce SHA-1, la connexion Google marche en local mais pas sur la version du Play Store.

## 4. Après validation Google

- Vérifier la version en ligne : *Production → tableau de bord*, puis installer depuis le Play Store et tester
  connexion Google, un achat `ticket_2`, un live.
- *Qualité → Android vitals → Plantages et ANR* : surveiller les 48 premières heures ; Crashlytics côté Firebase.
- Si tu as changé de clé d'importation (cas 2/3) : rien à faire côté Firebase, le SHA-1 de signature d'application
  (celui de Google) ne change pas. Mettre à jour Firebase uniquement si Google indique une nouvelle clé de signature.
- Ranger : `.jks` + mot de passe sauvegardés à deux endroits, `upload_certificate.pem` peut être supprimé.
