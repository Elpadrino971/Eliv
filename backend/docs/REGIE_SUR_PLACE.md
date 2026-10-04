# Fiche régie sur place — concert en direct sur VybzzZ

À imprimer ou à envoyer à la personne qui tient l'ordinateur dans la salle.
Elle n'a besoin d'aucun compte VybzzZ : seulement d'OBS et des deux
informations que l'organisateur lui donne de vive voix ou par message privé
(jamais par e-mail de groupe ni dans un chat public) :

- **Serveur** : `rtmps://global-live.mux.com:443/app`
- **Clé de stream** : _________________________________ (donnée par l'organisateur)

Si la clé fuit, l'organisateur peut en générer une nouvelle en un clic
(admin → concert → « 🔑 Nouvelle clé ») : prévenir aussitôt.

## Matériel

- MacBook Pro **branché sur secteur**, mise en veille désactivée
  (Réglages Système → Batterie / Écran : jamais sur secteur).
- iPhone sur trépied, en paysage, **branché en USB au Mac** (il se recharge).
- Interface audio Scarlett en USB au Mac ; console → sortie Matrix/AUX/Rec →
  entrées 1-2 de la Scarlett (INST et 48V désactivés, voyant vert, jamais rouge).
- **Câble Ethernet** si la salle en a un : plus fiable que le Wi-Fi.
- Débit **montant** mesuré sur place (speedtest.net, ligne « upload ») :
  5 Mbps minimum pour du 720p, 10 Mbps pour du 1080p.

## OBS (une fois pour toutes, 15 minutes)

1. Installer OBS (obsproject.com). Assistant : « Optimiser pour la diffusion », 1920×1080, 30 fps.
2. Réglages → Vidéo : base 1920×1080, sortie 1920×1080 (ou 1280×720 si le débit est juste), 30 fps.
3. Réglages → Sortie (mode Simple) : débit vidéo **4500 kbps** (2500 en 720p),
   encodeur **Apple VT H264 Hardware**, audio 160.
4. Réglages → Audio : micro et audio bureau par défaut → **Désactivé**.
5. Réglages → Diffusion : service **Personnalisé**, serveur et clé ci-dessus.
6. Sources (bouton +) :
   - **Périphérique de capture vidéo** « iPhone » → appareil : *Camo Camera*,
     ou *iPhone de …* (Caméra de continuité), ou *Blackmagic Design* (ATEM).
     Clic droit → Transformer → Ajuster à l'écran. Couper son audio dans le mixeur.
   - **Capture d'entrée audio** « Console » → appareil : *Scarlett*.
     Le vumètre doit bouger quand la console joue, rester dans le jaune.
7. Sauvegarder la scène (Profil → Exporter) pour la retrouver le jour J.

## Le soir du concert

| Quand | Quoi |
|---|---|
| H − 60 min | Tout brancher, allumer, OBS ouvert, image et son visibles dans OBS. |
| H − 45 min | **Démarrer la diffusion** dans OBS. Carré vert en bas, 0 image perdue. L'organisateur confirme « flux reçu » depuis l'admin et voit l'image sur un téléphone. Son et image synchronisés ? Test au claquement de mains. |
| H − 30 min | Laisser tourner (le public voit l'écran d'attente ou la scène vide, c'est normal). Ne plus toucher au Mac. |
| H | Le concert commence, rien à faire côté OBS. |
| Pendant | Surveiller le carré en bas d'OBS : vert = tout va bien. Orange/rouge = baisser à 720p dans Réglages → Vidéo (sans arrêter la diffusion). |
| Fin | Attendre le dernier salut, puis **Arrêter la diffusion**. Prévenir l'organisateur, qui termine le concert dans l'admin. |

## Si ça casse

- **OBS affiche « Déconnecté »** : il se reconnecte seul. Si rien après 30 s,
  Arrêter puis Démarrer la diffusion. Le public ne voit qu'une coupure.
- **Image noire** : l'app caméra de l'iPhone s'est fermée, ou l'iPhone s'est
  verrouillé (Camo) / déverrouillé (Caméra de continuité). Rouvrir, puis dans
  OBS clic droit sur la source → Désactiver / Activer.
- **Pas de son** : mixeur OBS, la barre « Console » doit bouger. Sinon :
  câble console → Scarlett, gain, et Réglages Système → Son → Entrée.
- **Internet coupé** : partage de connexion d'un téléphone 4G/5G en secours
  (Wi-Fi de l'iPhone de régie, pas celui qui filme), et passer en 720p.
- **Le Mac est mort** : plan B avec l'application VybzzZ sur un téléphone,
  compte artiste, « Lancer mon concert » : moins beau, mais le concert continue.

## Contact

Organisateur (à distance) : ____________________ (téléphone joignable toute la soirée)
