#!/usr/bin/env python3
"""
VybzzZ — empreinte de version sur les fichiers CSS et JS du site.

Pourquoi : nginx garde le CSS et le JS 7 jours dans le navigateur. Sans ça,
une correction mise en ligne n'arrive pas chez les visiteurs déjà venus, qui
continuent d'utiliser l'ancienne version pendant une semaine.

Principe : chaque référence devient « data.js?v=a1b2c3d4 », où l'empreinte
est calculée sur le contenu du fichier. Le contenu change -> l'adresse change
-> le navigateur télécharge la nouvelle version immédiatement. Le contenu ne
change pas -> l'adresse est identique -> le cache continue de servir.

À lancer après toute modification d'un .css ou .js du site :
    python3 scripts/stamp-assets.py
"""
import hashlib, pathlib, re, sys

SITE = pathlib.Path(__file__).resolve().parent.parent / 'site'
ASSET = re.compile(r'((?:src|href)=")([A-Za-z0-9_./-]+\.(?:js|css))(?:\?v=[a-f0-9]+)?(")')

def digest(path):
    return hashlib.md5(path.read_bytes()).hexdigest()[:8]

cache, changed, stamped = {}, [], 0
for html in sorted(SITE.glob('*.html')):
    src = html.read_text(encoding='utf-8')

    def repl(m):
        global stamped
        rel = m.group(2)
        target = (SITE / rel).resolve()
        # On ne marque que les fichiers du site, jamais une adresse externe.
        if not str(target).startswith(str(SITE)) or not target.is_file():
            return m.group(0)
        if rel not in cache:
            cache[rel] = digest(target)
        stamped += 1
        return f'{m.group(1)}{rel}?v={cache[rel]}{m.group(3)}'

    out = ASSET.sub(repl, src)
    if out != src:
        html.write_text(out, encoding='utf-8')
        changed.append(html.name)

print(f'  {stamped} références marquées dans {len(changed)} page(s)')
for name, h in sorted(cache.items()):
    print(f'    {name:24} v={h}')
if changed:
    print('\n  Pages modifiées : ' + ', '.join(changed))
else:
    print('\n  Aucune page modifiée (empreintes déjà à jour).')
