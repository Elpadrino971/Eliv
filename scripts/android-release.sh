#!/usr/bin/env bash
# VybzzZ — build du bundle Android release et vérification de la signature.
#
#   bash scripts/android-release.sh                # clean + pub get + build appbundle + vérif
#   bash scripts/android-release.sh --verify-only  # ne rebuild pas, vérifie l'AAB existant
#
# Pré-requis : android/key.properties écrit par scripts/android-signing.sh.
# Le script REFUSE un AAB signé avec la clé de debug (build.gradle.kts y retombe en
# silence quand key.properties manque) ou avec une autre clé que celle de key.properties.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"
KEY_PROPS="android/key.properties"
AAB="build/app/outputs/bundle/release/app-release.aab"
VERIFY_ONLY=0
[ "${1:-}" = "--verify-only" ] && VERIFY_ONLY=1

bold() { printf '\033[1m%s\033[0m\n' "$*"; }
ok()   { printf '\033[32m%s\033[0m\n' "$*"; }
warn() { printf '\033[33m%s\033[0m\n' "$*"; }
err()  { printf '\033[31m%s\033[0m\n' "$*" >&2; }
die()  { err "$@"; exit 1; }
hr()   { printf '%s\n' "------------------------------------------------------------"; }

find_keytool() {
  if command -v keytool >/dev/null 2>&1; then command -v keytool; return; fi
  local jh
  if jh="$(/usr/libexec/java_home 2>/dev/null)" && [ -x "$jh/bin/keytool" ]; then echo "$jh/bin/keytool"; return; fi
  local as="/Applications/Android Studio.app/Contents/jbr/Contents/Home/bin/keytool"
  if [ -x "$as" ]; then echo "$as"; return; fi
  return 1
}
KEYTOOL="$(find_keytool)" || die "keytool introuvable (installe un JDK ou Android Studio)."

norm()      { printf '%s' "$1" | tr -d ': \t\r\n' | tr 'A-F' 'a-f'; }
sha256_of() { grep -oE '([0-9A-Fa-f]{2}:){31}[0-9A-Fa-f]{2}' "$1" | head -n1 || true; }
# Lit une clé de android/key.properties (valeur brute, sans CR, backslashs Java dé-échappés).
prop() { sed -nE "s/^[[:space:]]*$1[[:space:]]*[=:][[:space:]]*//p" "$KEY_PROPS" | head -n1 | tr -d '\r' | sed 's/\\\\/\\/g'; }

TMPD="$(mktemp -d "${TMPDIR:-/tmp}/vybzzz-release.XXXXXX")"
trap 'rm -rf "$TMPD"' EXIT

# ---------------------------------------------------------------- 1. key.properties
bold "1/4 — Vérification de android/key.properties"
[ -f "$KEY_PROPS" ] || die "android/key.properties absent → sans lui le bundle serait signé en DEBUG. Lance d'abord : bash scripts/android-signing.sh"
STORE_FILE="$(prop storeFile)"; STORE_PASS="$(prop storePassword)"; KEY_PASS="$(prop keyPassword)"; KEY_ALIAS="$(prop keyAlias)"
[ -n "$STORE_FILE" ] && [ -n "$STORE_PASS" ] && [ -n "$KEY_ALIAS" ] || die "android/key.properties incomplet (storeFile / storePassword / keyAlias). Relance : bash scripts/android-signing.sh"
[ -n "$KEY_PASS" ] || KEY_PASS="$STORE_PASS"
# build.gradle.kts fait file(storeFile) depuis android/app : un chemin relatif se résout là.
case "$STORE_FILE" in
  /*) STORE_ABS="$STORE_FILE" ;;
  *)  STORE_ABS="$REPO_ROOT/android/app/$STORE_FILE" ;;
esac
[ -f "$STORE_ABS" ] || die "Keystore introuvable : $STORE_ABS → lance : bash scripts/android-signing.sh"
echo "keystore : $STORE_ABS (alias $KEY_ALIAS)"

# Empreinte attendue = certificat de la clé d'importation.
KS_OUT="$TMPD/ks.txt"
KS_PASS="$STORE_PASS" "$KEYTOOL" -list -v -keystore "$STORE_ABS" -storepass:env KS_PASS -alias "$KEY_ALIAS" > "$KS_OUT" 2>&1 || true
EXPECTED="$(sha256_of "$KS_OUT")"
if [ -z "$EXPECTED" ]; then
  err "Impossible de lire le certificat du keystore (mot de passe faux, alias inconnu ou keystore corrompu) :"
  grep -viE "JAVA_TOOL_OPTIONS" "$KS_OUT" | sed 's/^/  /' | head -n 12
  die "Relance : bash scripts/android-signing.sh"
fi
ok "SHA-256 attendu (clé d'importation) : $EXPECTED"

# Empreinte de la clé de debug, pour la détecter à coup sûr.
DEBUG_KS="$HOME/.android/debug.keystore"; DEBUG_SHA=""
if [ -f "$DEBUG_KS" ]; then
  KS_PASS=android "$KEYTOOL" -list -v -keystore "$DEBUG_KS" -storepass:env KS_PASS -alias androiddebugkey > "$TMPD/dbg.txt" 2>&1 || true
  DEBUG_SHA="$(sha256_of "$TMPD/dbg.txt")"
  [ -n "$DEBUG_SHA" ] && echo "SHA-256 de la clé debug (à NE PAS retrouver) : $DEBUG_SHA"
fi
[ -n "$DEBUG_SHA" ] && [ "$(norm "$DEBUG_SHA")" = "$(norm "$EXPECTED")" ] && die "key.properties pointe sur la clé de DEBUG. Relance : bash scripts/android-signing.sh"

# ---------------------------------------------------------------- 2. build
hr
bold "2/4 — Build"
VERSION="$(sed -nE 's/^version:[[:space:]]*//p' pubspec.yaml | head -n1 | tr -d '\r')"
BRANCH="$(git rev-parse --abbrev-ref HEAD 2>/dev/null)" || BRANCH="?"
echo "pubspec version : $VERSION   (versionName+versionCode)   branche : $BRANCH"
[ "$BRANCH" = "release/app-all" ] || warn "Attention : tu n'es pas sur release/app-all."
if [ "$VERIFY_ONLY" -eq 1 ]; then
  echo "--verify-only : pas de build, vérification de l'AAB existant."
else
  command -v flutter >/dev/null 2>&1 || die "flutter introuvable dans le PATH."
  flutter clean
  flutter pub get
  flutter build appbundle --release
fi
[ -f "$AAB" ] || die "AAB introuvable : $AAB"

# ---------------------------------------------------------------- 3. signature de l'AAB
hr
bold "3/4 — Signature de l'AAB"
SIG_OUT="$TMPD/sig.txt"
"$KEYTOOL" -printcert -jarfile "$AAB" > "$SIG_OUT" 2>&1 || true
ACTUAL="$(sha256_of "$SIG_OUT")"
if [ -z "$ACTUAL" ]; then
  # Repli : extraire le bloc de signature META-INF/*.RSA et le lire directement.
  unzip -p "$AAB" 'META-INF/*.RSA' 'META-INF/*.DSA' 'META-INF/*.EC' > "$TMPD/sig.p7" 2>/dev/null || true
  [ -s "$TMPD/sig.p7" ] && "$KEYTOOL" -printcert -file "$TMPD/sig.p7" > "$SIG_OUT" 2>&1 || true
  ACTUAL="$(sha256_of "$SIG_OUT")"
fi
[ -n "$ACTUAL" ] || { grep -viE JAVA_TOOL_OPTIONS "$SIG_OUT" | sed 's/^/  /' | head -n 12; die "AAB non signé ou signature illisible. Play Console le refusera."; }
echo "SHA-256 du signataire de l'AAB : $ACTUAL"

if [ -n "$DEBUG_SHA" ] && [ "$(norm "$ACTUAL")" = "$(norm "$DEBUG_SHA")" ]; then
  hr; err "ÉCHEC : l'AAB est signé avec la clé de DEBUG (~/.android/debug.keystore)."
  err "Gradle n'a pas lu android/key.properties. Vérifie le fichier, puis relance ce script."
  die "N'envoie PAS ce fichier sur Play Console."
fi
if grep -qiE "CN=Android Debug|O=Android|OU=Android" "$SIG_OUT" && ! grep -qi "VybzzZ" "$SIG_OUT"; then
  die "ÉCHEC : certificat de debug détecté dans l'AAB (CN=Android Debug). N'envoie PAS ce fichier."
fi
if [ "$(norm "$ACTUAL")" != "$(norm "$EXPECTED")" ]; then
  hr; err "ÉCHEC : l'AAB est signé avec une AUTRE clé que celle de android/key.properties."
  err "  attendu : $EXPECTED"
  err "  obtenu  : $ACTUAL"
  die "Play Console refusera l'import. Relance : bash scripts/android-signing.sh"
fi
ok "OK : l'AAB est signé avec la clé d'importation de android/key.properties."

# ---------------------------------------------------------------- 4. récap
hr
bold "4/4 — Prêt pour Play Console"
SIZE="$(du -h "$AAB" | cut -f1 | tr -d ' ')"
echo "Fichier  : $REPO_ROOT/$AAB"
echo "Taille   : $SIZE"
echo "Version  : $VERSION"
echo
echo "Étapes Play Console (https://play.google.com/console → VybzzZ) :"
echo "  1. Menu gauche : Production → « Créer une version »"
echo "  2. App bundles → téléverser app-release.aab (glisser-déposer depuis le Finder"
echo "     qui s'ouvre à la fin de ce script)"
echo "  3. Nom de la version : laisser la valeur proposée (code 19 → ${VERSION})"
echo "  4. « Notes de version » : copier le bloc « Nouveautés 1.2.0 » de"
echo "     docs/store/fiches-store-12-langues.md — au minimum fr-FR, idéalement les 12"
echo "     langues (une balise <fr-FR>…</fr-FR> par langue, ou l'éditeur par langue)"
echo "  5. Enregistrer → « Examiner la version »"
echo "  6. Vérifier qu'aucune erreur ne bloque (avertissements = OK) →"
echo "     « Démarrer le déploiement en production »"
echo
echo "Si Play refuse l'AAB pour cause de signature : la clé d'importation n'est pas"
echo "(encore) celle enregistrée côté Google → voir docs/ANDROID_SOUMISSION.md, cas 2 et 3."
if command -v open >/dev/null 2>&1 && [ "$(uname)" = "Darwin" ]; then
  open "$(dirname "$AAB")"
fi
