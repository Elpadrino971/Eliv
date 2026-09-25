#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Verifie android/app/google-services.json apres l'ajout des empreintes SHA-1
dans la console Firebase.

Le symptome d'origine : "oauth_client": [] pour le package com.app.vybzz,
c'est-a-dire aucune empreinte enregistree, donc connexion Google impossible
sur Android. Ce script dit si le fichier telecharge corrige bien ca.

Usage :
    python3 scripts/verifier-google-services.py [chemin] [empreinte...]

Les empreintes attendues se donnent avec ou sans deux-points, la casse
n'importe pas. Sans argument, le script verifie seulement le fichier.
"""
import json
import re
import sys

PACKAGE_ATTENDU = 'com.app.vybzz'
PROJET_ATTENDU = 'vybzzz-app'


def norm(h):
    return re.sub(r'[^0-9a-fA-F]', '', h).lower()


def main():
    args = [a for a in sys.argv[1:]]
    chemin = 'android/app/google-services.json'
    if args and not norm(args[0]):
        chemin = args.pop(0)
    elif args and args[0].endswith('.json'):
        chemin = args.pop(0)
    attendues = {norm(a): a for a in args if len(norm(a)) in (40, 64)}

    try:
        data = json.load(open(chemin, encoding='utf-8'))
    except FileNotFoundError:
        print(f'ECHEC  fichier introuvable : {chemin}')
        return 1
    except json.JSONDecodeError as e:
        print(f'ECHEC  JSON invalide : {e}')
        return 1

    projet = data.get('project_info', {}).get('project_id')
    print(f'Projet Firebase : {projet}')
    if projet != PROJET_ATTENDU:
        print(f'  ATTENTION  attendu "{PROJET_ATTENDU}" — mauvais projet ?')

    cible = None
    for client in data.get('client', []):
        pkg = client.get('client_info', {}).get('android_client_info', {}).get('package_name')
        oauth = client.get('oauth_client', [])
        marque = '  <-- celui que l\'application utilise' if pkg == PACKAGE_ATTENDU else ''
        print(f'\nPackage {pkg} : {len(oauth)} client(s) OAuth{marque}')
        if pkg == PACKAGE_ATTENDU:
            cible = client
        for o in oauth:
            t = o.get('client_type')
            genre = {1: 'Android (empreinte)', 3: 'Web (serveur)'}.get(t, f'type {t}')
            h = o.get('android_info', {}).get('certificate_hash')
            print(f'   - {genre}' + (f' — {h}' if h else f" — {o.get('client_id','')}"))

    if cible is None:
        print(f'\nECHEC  aucun client pour {PACKAGE_ATTENDU}.')
        return 1

    empreintes = {
        norm(o.get('android_info', {}).get('certificate_hash', ''))
        for o in cible.get('oauth_client', [])
        if o.get('client_type') == 1
    } - {''}

    print()
    if not empreintes:
        print('ECHEC  aucune empreinte enregistree pour ' + PACKAGE_ATTENDU + '.')
        print('       La connexion Google echouera sur Android, comme avant.')
        print('       Ajoute les SHA-1 dans Firebase, puis re-telecharge le fichier.')
        return 1

    print(f'OK  {len(empreintes)} empreinte(s) enregistree(s) pour {PACKAGE_ATTENDU}.')

    manquantes = [orig for n, orig in attendues.items() if n not in empreintes]
    if attendues:
        for n, orig in attendues.items():
            print(('  presente : ' if n in empreintes else '  ABSENTE  : ') + orig)
    if manquantes:
        print('\nECHEC  des empreintes attendues manquent dans le fichier.')
        return 1

    if not any(o.get('client_type') == 3 for o in cible.get('oauth_client', [])):
        print('\nATTENTION  aucun client OAuth de type Web (serveur) pour ce package.')
        print('           Le backend verifie l\'id_token avec ce client.')
    return 0


if __name__ == '__main__':
    sys.exit(main())
