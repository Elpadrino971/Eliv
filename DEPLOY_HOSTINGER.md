# VYBZZZ — Déploiement sur le VPS Hostinger

Cible : **VPS Hostinger** — Ubuntu 24.04 LTS — IP `187.77.235.252` — root.
But : `https://api.TONDOMAINE/` (API + dashboard admin) accessible partout, en HTTPS,
persistant, sans nouvel abonnement.

> Méthode : Docker (notre backend est déjà dockerisé) + nginx (reverse proxy) +
> Let's Encrypt (HTTPS gratuit). Copie-colle les blocs **un par un**.

---

## Étape 0 — DNS (dans hPanel Hostinger)

1. hPanel → **Domains → DNS Manager** du domaine choisi (ex. `vybzzz.fr`).
2. Ajoute un enregistrement :
   - **Type** : `A`
   - **Nom** : `api`
   - **Pointe vers / Valeur** : `187.77.235.252`
   - **TTL** : laisse par défaut
3. Enregistre. (Propagation : quelques minutes.)
   → Tu auras `api.vybzzz.fr` qui pointe sur ton VPS.

---

## Étape 1 — Se connecter au VPS

Depuis ton Mac :
```
ssh root@187.77.235.252
```
(mot de passe root = celui de ton hPanel, section "Root password").

---

## Étape 2 — Définir TON domaine (une seule fois)

Remplace `api.vybzzz.fr` par TON sous-domaine, puis colle :
```
export API_DOMAIN=api.vybzzz.fr
```
(Tout le reste utilise cette variable — un seul endroit à changer.)

---

## Étape 3 — Installer Docker, git, nginx, certbot

```
apt update && apt install -y docker.io git nginx certbot python3-certbot-nginx
```
```
systemctl enable --now docker
```

---

## Étape 4 — Récupérer le code (repo privé → token GitHub)

Le repo est privé : il faut un **token de lecture**.
1. Sur GitHub : **Settings → Developer settings → Personal access tokens → Fine-grained tokens → Generate new token**.
2. Repository access : **Only select repositories → Vybzzz-V12026**.
3. Permissions : **Contents → Read-only**. Génère, copie le token (commence par `github_pat_…`).

Puis sur le VPS (remplace `TON_TOKEN`) :
```
git clone https://TON_TOKEN@github.com/Elpadrino971/Vybzzz-V12026.git /opt/vybzzz
```
```
cd /opt/vybzzz && git checkout claude/jolly-maxwell-g4189
```

---

## Étape 5 — Construire et lancer le backend (Docker)

```
cd /opt/vybzzz/backend && docker build -t vybzzz-backend .
```
```
docker run -d --name vybzzz --restart always \
  -p 127.0.0.1:8002:8002 \
  -e JWT_SECRET=$(openssl rand -hex 32) \
  -e VYBZZZ_DB=/data/vybzzz.sqlite \
  -v /opt/vybzzz-data:/data \
  -v /opt/vybzzz-storage:/app/storage \
  vybzzz-backend
```
Vérifie que ça tourne :
```
docker logs vybzzz --tail 20
```
Tu dois voir `VYBZZZ backend en écoute sur http://localhost:8002`.

> Le `-v /opt/vybzzz-data:/data` = **données persistantes** (elles survivent aux
> redémarrages et rebuilds). Le `-p 127.0.0.1:8002` = accessible uniquement via nginx.

---

## Étape 6 — Reverse proxy nginx

```
cat > /etc/nginx/sites-available/vybzzz <<EOF
server {
    listen 80;
    server_name $API_DOMAIN;
    client_max_body_size 50M;
    location / {
        proxy_pass http://127.0.0.1:8002;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF
```
```
ln -sf /etc/nginx/sites-available/vybzzz /etc/nginx/sites-enabled/vybzzz
nginx -t && systemctl reload nginx
```

---

## Étape 7 — HTTPS (Let's Encrypt, gratuit)

```
certbot --nginx -d $API_DOMAIN --non-interactive --agree-tos -m ton-email@exemple.com
```
(Remplace l'email.) Certbot configure le HTTPS + le renouvellement auto.

✅ Teste : ouvre `https://api.vybzzz.fr/api` → tu dois voir `{"status":"success",...}`.
Dashboard admin : `https://api.vybzzz.fr/admin/` (admin@vybzzz.com / admin123).

---

## Étape 8 — Brancher l'app dessus

Dans `lib/Global/api.dart` (sur ton Mac) :
```dart
static const String mainIP = 'https://api.vybzzz.fr'; // VPS Hostinger (prod)
```
Commit + push, puis rebuild l'app. → elle marche partout, même en 4G.

---

## Mettre à jour le backend plus tard

Quand on pousse du nouveau code :
```
cd /opt/vybzzz && git pull
cd backend && docker build -t vybzzz-backend .
docker rm -f vybzzz
docker run -d --name vybzzz --restart always -p 127.0.0.1:8002:8002 \
  -e JWT_SECRET=$(cat /opt/vybzzz-data/.jwt 2>/dev/null || openssl rand -hex 32 | tee /opt/vybzzz-data/.jwt) \
  -e VYBZZZ_DB=/data/vybzzz.sqlite -v /opt/vybzzz-data:/data \
  -v /opt/vybzzz-storage:/app/storage vybzzz-backend
```
(Le JWT est conservé dans `/opt/vybzzz-data/.jwt` pour ne pas déconnecter l'admin.)

---

## Dépannage rapide
- `docker logs vybzzz --tail 50` → voir les erreurs du backend.
- `systemctl status nginx` / `nginx -t` → vérifier nginx.
- Firewall Hostinger : autorise les ports **80** et **443** (hPanel → VPS → Firewall).
- DNS pas encore propagé : attends 5-10 min, re-teste l'étape 7.
