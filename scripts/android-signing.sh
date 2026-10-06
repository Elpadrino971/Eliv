#!/usr/bin/env bash
# VybzzZ — retrouver (ou recréer) la clé d'IMPORTATION Android et écrire android/key.properties.
#
#   bash scripts/android-signing.sh                      # depuis la racine du dépôt, sur le Mac
#   bash scripts/android-signing.sh /chemin/autre.jks    # ajoute un keystore candidat à la liste
#
# Contexte : Google Play App Signing est actif. Google détient la clé de signature
# de l'app ; toi, tu signes l'AAB avec une clé d'IMPORTATION (upload key). Ce
# script cherche tous les keystores de la machine, affiche leur empreinte
# SHA-256, la compare à celle affichée dans Play Console, et écrit
# android/key.properties. Si aucun keystore ne correspond, il en génère un
# neuf et t'explique comment demander à Google la réinitialisation.
#
# Compatible bash 3.2 (celui de macOS). Les mots de passe ne sont jamais affichés
# ni passés sur la ligne de commande (keytool les lit via une variable d'env).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
KEY_PROPS="$REPO_ROOT/android/key.properties"

# ---------------------------------------------------------------- utilitaires
bold()  { printf '\033[1m%s\033[0m\n' "$*"; }
ok()    { printf '\033[32m%s\033[0m\n' "$*"; }
warn()  { printf '\033[33m%s\033[0m\n' "$*"; }
err()   { printf '\033[31m%s\033[0m\n' "$*" >&2; }
hr()    { printf '%s\n' "------------------------------------------------------------"; }

# keytool : PATH, sinon JDK système, sinon celui d'Android Studio.
find_keytool() {
  if command -v keytool >/dev/null 2>&1; then command -v keytool; return; fi
  local jh
  if jh="$(/usr/libexec/java_home 2>/dev/null)" && [ -x "$jh/bin/keytool" ]; then echo "$jh/bin/keytool"; return; fi
  local as="/Applications/Android Studio.app/Contents/jbr/Contents/Home/bin/keytool"
  if [ -x "$as" ]; then echo "$as"; return; fi
  return 1
}
KEYTOOL="$(find_keytool)" || { err "keytool introuvable. Installe un JDK (brew install --cask temurin) ou Android Studio."; exit 1; }

# Normalise une empreinte : sans ':' ni espaces, en minuscules.
norm() { printf '%s' "$1" | tr -d ': \t\r\n' | tr 'A-F' 'a-f'; }
# Extrait la 1re empreinte SHA-256 (32 octets) / SHA-1 (20 octets) d'une sortie keytool.
sha256_of() { grep -oE '([0-9A-Fa-f]{2}:){31}[0-9A-Fa-f]{2}' "$1" | head -n1 || true; }
sha1_of()   { grep -oE '([0-9A-Fa-f]{2}:){19}[0-9A-Fa-f]{2}'  "$1" | head -n1 || true; }
alias_of()  { sed -nE "s/^(Nom d'alias|Alias name)[[:space:]]*:[[:space:]]*//p" "$1" | head -n1 | tr -d '\r' || true; }

# Lit un mot de passe sans écho. $1 = invite, $2 = nom de la variable à remplir.
ask_secret() {
  local __v
  printf '%s' "$1"
  IFS= read -rs __v </dev/tty
  printf '\n'
  eval "$2=\"\$__v\""
}

# Écrit android/key.properties. $1 = keystore (abs), $2 = alias, $3 = storePassword, $4 = keyPassword.
write_key_properties() {
  local store="$1" al="$2" sp="$3" kp="$4"
  # Java Properties : seul le backslash a besoin d'être échappé dans une valeur.
  sp="$(printf '%s' "$sp" | sed 's/\\/\\\\/g')"
  kp="$(printf '%s' "$kp" | sed 's/\\/\\\\/g')"
  local storeEsc; storeEsc="$(printf '%s' "$store" | sed 's/\\/\\\\/g')"
  if [ -f "$KEY_PROPS" ]; then
    cp "$KEY_PROPS" "$KEY_PROPS.bak.$(date +%Y%m%d%H%M%S)"
    warn "Ancien android/key.properties sauvegardé en .bak"
  fi
  umask 077
  {
    echo "storePassword=$sp"
    echo "keyPassword=$kp"
    echo "keyAlias=$al"
    echo "storeFile=$storeEsc"
  } > "$KEY_PROPS"
  chmod 600 "$KEY_PROPS"
  ok "android/key.properties écrit (ignoré par git) :"
  echo "  keyAlias=$al"
  echo "  storeFile=$store"
  echo "  storePassword / keyPassword : ******"
}

backup_reminder() {
  hr
  warn "SAUVEGARDE OBLIGATOIRE — à faire MAINTENANT, avant toute autre chose :"
  echo "  1. Copie le fichier .jks ET son mot de passe dans un gestionnaire de mots de passe"
  echo "     (1Password, Bitwarden, Trousseau iCloud…) — le .jks en pièce jointe."
  echo "  2. Copie le .jks une 2e fois ailleurs (clé USB, Google Drive/iCloud Drive, autre Mac)."
  echo "  Un keystore perdu = nouvelle demande de réinitialisation à Google (1 à 2 jours"
  echo "  d'attente) ; un mot de passe perdu = keystore inutilisable, comme celui du 25/09."
  hr
}

# ---------------------------------------------------------------- 1. candidats
bold "1/3 — Recherche des keystores sur ce Mac"
echo "keytool : $KEYTOOL"

TMPD="$(mktemp -d "${TMPDIR:-/tmp}/vybzzz-signing.XXXXXX")"
trap 'rm -rf "$TMPD"' EXIT
LIST="$TMPD/candidats.txt"
: > "$LIST"

# Les trois chemins connus + argument(s) optionnel(s).
for p in \
  "$HOME/Desktop/nouvelle-cle-vybzzz/upload-keystore.jks" \
  "$HOME/Downloads/Vybzzz/upload-keystore.jks" \
  "$HOME/Desktop/JUin 2026/apple-lock/android/app/upload-keystore.jks" \
  "$@"
do
  [ -f "$p" ] && printf '%s\n' "$p" >> "$LIST"
done

# Tout *.jks / *.keystore dans ~/Desktop, ~/Downloads et ~ (profondeur 3),
# hors ~/Library, .pub-cache, node_modules et debug.keystore.
for base in "$HOME/Desktop" "$HOME/Downloads" "$HOME"; do
  [ -d "$base" ] || continue
  find "$base" -maxdepth 3 \
    \( -path "$HOME/Library" -o -name node_modules -o -name .pub-cache -o -name .git \) -prune -o \
    -type f \( -name '*.jks' -o -name '*.keystore' \) ! -name debug.keystore -print 2>/dev/null \
    >> "$LIST" || true
done

sort -u "$LIST" -o "$LIST"
N=$(wc -l < "$LIST" | tr -d ' ')

CAND_PATH=(); CAND_ALIAS=(); CAND_SHA256=(); CAND_SHA1=(); CAND_STATUS=(); CAND_PASS=()

if [ "$N" -eq 0 ]; then
  warn "Aucun keystore trouvé."
else
  echo "Keystores trouvés : $N"
  i=0
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    hr
    bold "[$((i+1))/$N] $f"
    ls -la "$f" | awk '{print "     " $5 " octets, modifié le " $6 " " $7 " " $8}'
    out="$TMPD/out.$i"
    status="ignoré"; al=""; s256=""; s1=""; pass=""
    while :; do
      ask_secret "     Mot de passe du keystore (Entrée pour ignorer ce fichier) : " pass
      [ -n "$pass" ] || { status="ignoré"; break; }
      KS_PASS="$pass" "$KEYTOOL" -list -v -keystore "$f" -storepass:env KS_PASS > "$out" 2>&1 || true
      grep -iE "alias|SHA|cha.{1,2}ne|chain|error|erreur|incorrect|tampered" "$out" | grep -v JAVA_TOOL_OPTIONS | sed 's/^/     /' || true
      al="$(alias_of "$out")"
      s256="$(sha256_of "$out")"
      s1="$(sha1_of "$out")"
      if grep -qiE "cha.{1,2}ne du certificat[[:space:]]*:[[:space:]]*0[[:space:]]*$|Certificate chain length:[[:space:]]*0[[:space:]]*$" "$out" \
         || { grep -qiE "PrivateKeyEntry" "$out" && [ -z "$s256" ]; }; then
        status="INUTILISABLE (clé privée sans certificat)"
        err "     => INUTILISABLE : chaîne de certificat vide (comme le fichier du 25/09). Ce fichier ne pourra jamais signer un AAB."
        break
      fi
      if [ -z "$s256" ] && grep -qiE "incorrect|tampered|password|mot de passe|exception|error|erreur" "$out"; then
        warn "     Mot de passe refusé (ou fichier illisible)."
        printf '     Réessayer ? [O/n] '; read -r r </dev/tty
        case "$r" in n|N) status="mot de passe inconnu"; pass=""; break ;; *) continue ;; esac
      fi
      if [ -z "$s256" ]; then
        status="aucune clé"
        warn "     => Aucune empreinte trouvée (keystore vide ou sans clé privée)."
      else
        status="utilisable"
        ok "     => alias '${al:-?}'  SHA-256 $s256"
        [ -n "$s1" ] && echo "        SHA-1   $s1"
      fi
      break
    done
    CAND_PATH[$i]="$f"; CAND_ALIAS[$i]="$al"; CAND_SHA256[$i]="$s256"; CAND_SHA1[$i]="$s1"
    CAND_STATUS[$i]="$status"; CAND_PASS[$i]="$pass"
    i=$((i+1))
  done < "$LIST"
fi

# ---------------------------------------------------------------- 2. comparaison
hr
bold "2/3 — Comparaison avec Play Console"
USABLE=0
if [ "$N" -gt 0 ]; then
  echo "Récapitulatif :"
  i=0
  while [ "$i" -lt "${#CAND_PATH[@]}" ]; do
    printf '  %-40s %s\n' "${CAND_STATUS[$i]}" "${CAND_PATH[$i]}"
    [ -n "${CAND_SHA256[$i]}" ] && printf '  %-40s SHA-256 %s\n' "" "${CAND_SHA256[$i]}"
    [ "${CAND_STATUS[$i]}" = "utilisable" ] && USABLE=$((USABLE+1))
    i=$((i+1))
  done
fi

MATCH=-1
if [ "$USABLE" -gt 0 ]; then
  echo
  echo "Ouvre Play Console → VybzzZ → Configuration → Intégrité de l'application →"
  echo "Signature d'application Play → bloc « Certificat de la clé d'importation »."
  echo "Copie l'empreinte SHA-256 (ou SHA-1 si c'est la seule affichée) et colle-la ici."
  printf 'Empreinte Play Console (Entrée si tu ne la trouves pas) : '
  IFS= read -r PLAY_FP </dev/tty
  PLAY_N="$(norm "$PLAY_FP")"
  if [ -n "$PLAY_N" ]; then
    case "${#PLAY_N}" in
      64) kind=SHA-256 ;;
      40) kind=SHA-1 ;;
      *)  kind=""; warn "Empreinte de longueur inattendue (${#PLAY_N} hex) — je compare quand même." ;;
    esac
    i=0
    while [ "$i" -lt "${#CAND_PATH[@]}" ]; do
      if [ "${CAND_STATUS[$i]}" = "utilisable" ]; then
        if [ "$(norm "${CAND_SHA256[$i]}")" = "$PLAY_N" ] || { [ -n "${CAND_SHA1[$i]}" ] && [ "$(norm "${CAND_SHA1[$i]}")" = "$PLAY_N" ]; }; then
          MATCH=$i; break
        fi
      fi
      i=$((i+1))
    done
    if [ "$MATCH" -ge 0 ]; then
      ok "CORRESPONDANCE ${kind:-} : ${CAND_PATH[$MATCH]}"
    else
      warn "Aucun keystore utilisable ne correspond à l'empreinte Play Console."
    fi
  fi
fi

if [ "$MATCH" -ge 0 ]; then
  hr
  bold "3/3 — Écriture de android/key.properties"
  STORE="${CAND_PATH[$MATCH]}"
  ALIAS="${CAND_ALIAS[$MATCH]:-upload}"
  SP="${CAND_PASS[$MATCH]}"
  printf "Alias détecté : %s — Entrée pour le garder, sinon tape l'alias : " "$ALIAS"
  IFS= read -r a </dev/tty; [ -n "$a" ] && ALIAS="$a"
  ask_secret "Mot de passe de la clé (Entrée = identique au keystore, obligatoire pour un PKCS12) : " KP
  [ -n "$KP" ] || KP="$SP"
  write_key_properties "$STORE" "$ALIAS" "$SP" "$KP"
  backup_reminder
  ok "OK: lance scripts/android-release.sh"
  exit 0
fi

# ---------------------------------------------------------------- 3. nouvelle clé
hr
bold "3/3 — Générer une NOUVELLE clé d'importation"
if [ "$USABLE" -eq 0 ]; then
  echo "Aucun keystore utilisable sur ce Mac."
else
  echo "Aucun keystore ne correspond à celui enregistré dans Play Console."
fi
echo "Comme Google détient la clé de signature de l'app, on peut simplement créer une"
echo "nouvelle clé d'importation et demander à Google de l'enregistrer (1 à 2 jours)."
echo "Les utilisateurs actuels ne sont pas impactés : l'app reste signée par Google."
printf 'Générer une nouvelle clé maintenant ? [o/N] '; read -r r </dev/tty
case "$r" in o|O|y|Y) ;; *) echo "Abandon. Relance le script quand tu as le keystore ou la réponse de Google."; exit 1 ;; esac

NEW_JKS="$HOME/Desktop/vybzzz-upload-$(date +%Y%m%d).jks"
PEM="$HOME/Desktop/upload_certificate.pem"
if [ -e "$NEW_JKS" ]; then
  err "$NEW_JKS existe déjà. Déplace-le ou supprime-le, puis relance."; exit 1
fi

while :; do
  ask_secret "Choisis un mot de passe (≥ 6 caractères, note-le tout de suite) : " NP1
  ask_secret "Confirme le mot de passe : " NP2
  [ "$NP1" = "$NP2" ] || { warn "Les deux saisies diffèrent."; continue; }
  [ "${#NP1}" -ge 6 ] || { warn "Trop court (minimum 6)."; continue; }
  break
done

echo "Génération (RSA 2048, validité 10000 jours, alias 'upload')…"
GOUT="$TMPD/gen.txt"
KS_PASS="$NP1" "$KEYTOOL" -genkeypair -v \
  -keystore "$NEW_JKS" -storetype PKCS12 -storepass:env KS_PASS -keypass:env KS_PASS \
  -keyalg RSA -keysize 2048 -validity 10000 -alias upload \
  -dname "CN=VybzzZ, O=VybzzZ, C=FR" > "$GOUT" 2>&1 || true
[ -s "$NEW_JKS" ] || { err "keytool -genkeypair a échoué :"; sed 's/^/  /' "$GOUT"; exit 1; }
ok "Keystore créé : $NEW_JKS"

# Vérification : la chaîne de certificat doit avoir une longueur de 1.
VOUT="$TMPD/new.txt"
KS_PASS="$NP1" "$KEYTOOL" -list -v -keystore "$NEW_JKS" -storepass:env KS_PASS > "$VOUT" 2>&1 || true
NEW_256="$(sha256_of "$VOUT")"
NEW_1="$(sha1_of "$VOUT")"
if grep -qiE "cha.{1,2}ne du certificat[[:space:]]*:[[:space:]]*1[[:space:]]*$|Certificate chain length:[[:space:]]*1[[:space:]]*$" "$VOUT" && [ -n "$NEW_256" ]; then
  ok "Keystore vérifié : chaîne de certificat = 1, alias upload."
  echo "  SHA-256 : $NEW_256"
  [ -n "$NEW_1" ] && echo "  SHA-1   : $NEW_1"
else
  err "Le keystore généré n'est pas valide (chaîne de certificat ≠ 1). Sortie keytool :"
  sed 's/^/  /' "$VOUT"; exit 1
fi

KS_PASS="$NP1" "$KEYTOOL" -exportcert -rfc -keystore "$NEW_JKS" -storepass:env KS_PASS -alias upload -file "$PEM" >/dev/null 2>&1
[ -s "$PEM" ] && ok "Certificat exporté : $PEM" || { err "Export du certificat échoué."; exit 1; }

write_key_properties "$NEW_JKS" "upload" "$NP1" "$NP1"
unset NP1 NP2

backup_reminder
hr
bold "ÉTAPES PLAY CONSOLE — demande de réinitialisation de la clé d'importation"
echo "  1. https://play.google.com/console → app VybzzZ (com.app.vybzz)"
echo "  2. Menu gauche : Configuration → Intégrité de l'application"
echo "  3. Onglet « Signature d'application Play » → lien"
echo "     « Demander la réinitialisation de la clé d'importation »"
echo "  4. Motif : « Clé d'importation perdue » (ou équivalent) → téléverser le fichier"
echo "     $PEM"
echo "  5. Envoyer. Google envoie un e-mail de confirmation au propriétaire du compte"
echo "     (généralement sous 1 à 2 jours). Rien à faire d'autre en attendant."
echo "  6. La nouvelle clé devient valide À LA DATE indiquée dans l'e-mail / la page"
echo "     Intégrité de l'application. Avant cette date, Play refuse encore les AAB signés"
echo "     avec elle : n'envoie pas de version avant."
echo "  7. Une fois la date passée : bash scripts/android-release.sh"
hr
backup_reminder
ok "Terminé. Empreinte SHA-256 de la nouvelle clé d'importation : $NEW_256"
