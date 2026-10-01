# Rendre VybzzZ robuste — plan

Décidé avec le propriétaire le 1er octobre 2026, après la semaine du concert DJ Wilson.

## Avant le prochain gros événement
1. **Alertes** : surveillance de disponibilité du site et de l'API (UptimeRobot ou
   équivalent) avec notification téléphone ; rapport de plantages dans l'app
   (Firebase Crashlytics ou Sentry — l'audit Play a confirmé qu'il n'y en a pas).
2. **Version minimale obligatoire** : contrôle au démarrage de l'app (« mets à jour »
   + lien du store) pour ne plus laisser des fans sur de vieilles versions.
3. **Environnement de test** : copie du serveur avec faux Stripe / faux Mux, où chaque
   correctif passe avant la production.
4. **Sauvegardes testées** : restaurer une sauvegarde au moins une fois (sur la copie).

## Dans le mois
5. Tests automatiques à chaque modification (GitHub Actions) : analyse Flutter, tests
   du serveur, compilation Android sous Linux.
6. Mise en ligne reproductible (une commande, retour arrière possible).
7. Accès partagés : Apple, Google, Stripe, Mux, Zego, RevenueCat, VPS au nom de la
   société, double authentification, coffre commun (clés de signature incluses).
8. Test de charge : 500 fans simultanés (chat, vidéo, paiement).

## À 3 mois
9. Sortir du serveur unique (second serveur / hébergement géré, base plus robuste que SQLite).
10. Juridique : droits musicaux des sets (SACEM et équivalents), CGU artistes,
    modération, RGPD — avocat spécialisé.
11. Argent : TVA, factures automatiques, versements réels aux artistes, fraude.
12. Web et app : unifier à terme (chaque nouveauté est aujourd'hui faite deux fois).
