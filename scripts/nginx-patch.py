#!/usr/bin/env python3
"""
VybzzZ — applique la configuration nginx du site sans copier-coller manuel.

À lancer sur le VPS :   sudo python3 /opt/vybzzz/scripts/nginx-patch.py

Ce que le script fait, dans le bloc « server_name vybzzz.online » uniquement :
  - remplace  location / { try_files $uri $uri/ /index.html; }  par une vraie 404 ;
  - ajoute les liens nominatifs du Live Challenge (/c/nom-de-scene) ;
  - ajoute le raccourci /app et les redirections des anciennes pages ;
  - ajoute le cache des images (30 j) et du CSS/JS (7 j) ;
  - ajoute les en-têtes de sécurité et la redirection www -> domaine principal ;
  - active HTTP/2.
Il ne touche ni au bloc api.vybzzz.online, ni au bloc location /api/,
ni aux lignes gérées par Certbot. Une sauvegarde horodatée est créée.
"""
import re, shutil, sys, datetime, subprocess

PATH = '/etc/nginx/sites-enabled/vybzzz'

BLOC = '''    if ($host = www.vybzzz.online) { return 301 https://vybzzz.online$request_uri; }

    # Live Challenge : lien personnel d'un artiste (aperçu à son nom sur WhatsApp)
    location ~ ^/c/([A-Za-z0-9-]+)$ {
        proxy_pass http://127.0.0.1:8002/api/challenge/invite/$1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }

    location = /app { return 301 /app.html; }

    location = /dashboard.html    { return 301 /; }
    location = /checkout.html     { return 301 /store.html; }
    location = /index-legacy.html { return 301 /; }
    location = /experience.html   { return 301 /; }

    location ~* \\.(png|jpe?g|webp|svg|ico|gif|mp4|woff2?)$ {
        expires 30d;
        add_header Cache-Control "public, immutable";
    }

    location ~* \\.(css|js)$ {
        expires 7d;
        add_header Cache-Control "public";
    }

    location ~ ^/(regie|stage)\\.html$ {
        add_header X-Robots-Tag "noindex, nofollow" always;
    }

    location / {
        try_files $uri $uri/ =404;
    }
    error_page 404 /404.html;
    location = /404.html { internal; }

    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Content-Type-Options nosniff always;
    add_header X-Frame-Options SAMEORIGIN always;
    add_header Referrer-Policy strict-origin-when-cross-origin always;
'''

def fail(msg):
    print('\n  ARRÊT : ' + msg)
    print('  Rien n\'a été modifié.')
    print('  Restaure d\'abord ta sauvegarde :  sudo cp /root/vybzzz.nginx.bak ' + PATH + '\n')
    sys.exit(1)

src = open(PATH, encoding='utf-8').read()

# Le bloc du site : celui qui sert /opt/vybzzz/site.
m = re.search(r'server\s*\{[^{}]*server_name\s+vybzzz\.online[^;]*;.*?\n\}', src, re.S)
if not m:
    fail('bloc « server_name vybzzz.online » introuvable.')
bloc = m.group(0)

if 'try_files $uri $uri/ =404' in bloc or 'challenge/invite' in bloc:
    fail('la configuration semble déjà modifiée (ou à moitié). Restaure la sauvegarde et relance.')

# La ligne à remplacer, telle qu'installée à l'origine.
pat = re.compile(r'[ \t]*location\s*/\s*\{\s*\n[ \t]*try_files\s+\$uri\s+\$uri/\s+/index\.html;\s*\n[ \t]*\}\s*\n')
if not pat.search(bloc):
    fail('la ligne « try_files $uri $uri/ /index.html; » est introuvable ou a déjà été modifiée.')

neuf = pat.sub(BLOC, bloc, count=1)

# HTTP/2 — l'écriture dépend de la version :
#   nginx < 1.25.1 : « listen 443 ssl http2; »
#   nginx >= 1.25.1 : « http2 on; » sur sa propre ligne (l'autre est refusée)
def nginx_version():
    try:
        r = subprocess.run(['nginx', '-v'], capture_output=True, text=True)
        m2 = re.search(r'nginx/(\d+)\.(\d+)\.(\d+)', r.stdout + r.stderr)
        return tuple(int(x) for x in m2.groups()) if m2 else (0, 0, 0)
    except Exception:
        return (0, 0, 0)

ver = nginx_version()
if 'http2' not in neuf:
    if ver >= (1, 25, 1):
        neuf = re.sub(r'(\n([ \t]*)listen 443 ssl;[^\n]*\n)', r'\1\2http2 on;\n', neuf, count=1)
    else:
        neuf = re.sub(r'(\n[ \t]*listen 443 ssl);([^\n]*\n)', r'\1 http2;\2', neuf, count=1)
print('  nginx %d.%d.%d — HTTP/2 activé en écriture %s' % (ver + ('récente' if ver >= (1, 25, 1) else 'classique',)))

# La sauvegarde NE DOIT PAS rester dans sites-enabled : nginx charge tout ce
# qui s'y trouve (include sites-enabled/*), ce qui déclare les blocs en double.
import os
BACKUP_DIR = '/root/nginx-sauvegardes'
os.makedirs(BACKUP_DIR, exist_ok=True)
backup = os.path.join(BACKUP_DIR, 'vybzzz.bak-' + datetime.datetime.now().strftime('%Y%m%d-%H%M%S'))
shutil.copy2(PATH, backup)
open(PATH, 'w', encoding='utf-8').write(src.replace(bloc, neuf, 1))

print('\n  Configuration écrite. Sauvegarde : ' + backup)
print('  Vérification de la syntaxe…\n')
r = subprocess.run(['nginx', '-t'], capture_output=True, text=True)
print((r.stdout + r.stderr).strip())
if r.returncode == 0:
    print('\n  Syntaxe correcte. Applique maintenant :  sudo systemctl reload nginx\n')
else:
    print('\n  Syntaxe refusée. Restaure :  sudo cp ' + backup + ' ' + PATH + '\n')
