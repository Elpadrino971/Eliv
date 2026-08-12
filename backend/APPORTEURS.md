# Apporteurs — Profil type & modèle de commissions

> **But** : un apporteur (imprésario, manager, partenaire) amène des artistes ;
> il touche une commission sur **la part plateforme** générée par SES artistes.
> Chaque apporteur a un **deal différent** → on ne code pas le deal en dur, on
> le **stocke en config** (`deal_type` + `deal_params`). Nouveau contrat = une
> ligne à remplir, **zéro ligne de code**.

---

## 0. Règle-cadre (globale) — TOUT est config, rien n'est figé

Le régime apporteur **ne se ferme pas** à la fin des Founders : ce sont les
**prix / taux qui évoluent** ensuite. Et comme l'avenir est ouvert (d'autres
contrats, d'autres modèles « voire plus »), la règle d'or est :

> **Aucune valeur métier n'est codée en dur.** Taux artiste, taux apporteur,
> durées, prix, paliers, primes : tout vit en base (config) et est **modifiable
> à tout moment sans redéploiement**. Un changement de prix « après Founders »,
> un nouvel apporteur, un nouveau type de deal = **de la donnée, pas du code**.

Concrètement : la part artiste dérive de **l'offre en cours de l'artiste** (qui,
elle, peut changer quand les prix changent) ; le taux apporteur dérive de la
**config de son deal**. Le moteur ne fait qu'appliquer ce qui est en base.

---

## 1. PROFIL TYPE (à remplir pour CHAQUE apporteur)

Copie ce bloc, remplis-le, envoie-le moi → je crée l'apporteur en base.

```
── APPORTEUR ─────────────────────────────────────────
Nom / structure        : ____________________  (ex: Ruddy — RD Management)
Email                  : ____________________
Statut                 : actif | suspendu

── DEAL ──────────────────────────────────────────────
Type de deal           : simple | paliers | fixe_primes
Base de commission     : PART PLATEFORME NETTE  (fixe, ne change pas)
Taux                   : ____ %          (si "simple" ou "fixe_primes")
Paliers (si "paliers") : ex 5% / 10% / 15%
  → déclencheur palier : (à préciser : nb d'artistes ? volume € ? mois ?)
Durée commission       : ____ mois       (Ruddy 12 / Amandine 24)
Renouvelable ?         : oui | non       (si oui: sur validation d'implication)

── PRIMES FIXES (optionnel) ──────────────────────────
Prime 1 : ______ €  déclenchée par : ____________ (ex 150€ au 1er live)
Prime 2 : ______ €  déclenchée par : ____________ (ex 300€ après 3 mensualités encaissées)

── EXCLUSIVITÉ (optionnel) ───────────────────────────
Durée exclusivité      : ____ mois par contact soumis

── RÉGIME DES ARTISTES RATTACHÉS ─────────────────────
(par défaut: Normal. Un artiste PARRAIN est exclu du calcul de commission.)
```

### Exemples déjà connus

**Ruddy Séverin** — apporteur #1 (le nom est une fiche, pas la jauge : la jauge est un `deal_type` générique réutilisable par n'importe quel apporteur)
```
Type de deal    : paliers (JAUGE)
Taux            : jauge 5% → 15% selon le NOMBRE d'artistes actifs amenés
                  (plancher 5%, plafond 15%). Actuellement : 15% (assez d'artistes).
Durée           : 12 mois (renouvelable)
Primes          : aucune
Exclusivité     : —
```

**Amandine Grangé** — apporteur (contrat AXEN DIGITAL, signé)
```
Type de deal    : fixe_primes
Taux            : 5% de la Part Nette AXEN (= part plateforme nette)
Durée           : 24 mois À COMPTER DU 1er LIVE de l'artiste (commission_from=first_live)
Primes          : 150€ "Pionnier"  → au 1er live effectivement diffusé
                  300€ "Fondateur" → à l'encaissement de la 3e mensualité
                  (NON-CUMUL art 6.3 : une seule prime par artiste, la plus haute)
Exclusivité     : 6 mois par contact attribué (renouvelable)
Indemnité       : 300€ forfait de prospection (60 j, sans condition de résultat)
```
deal_params correspondant :
`{ "rate":5, "commission_from":"first_live", "commission_months":24,
   "primes":{ "pionnier":{"amount":150}, "fondateur":{"amount":300} },
   "exclusivity_months":6, "prospection_indemnity":300 }`

> Câblé : la prime Pionnier + le départ des 24 mois se déclenchent
> automatiquement au **premier live** (idempotent). La prime Fondateur se
> déclenche via le bouton « 💶 Fondateur » sur la page agence (à passer en
> auto sur le webhook d'abonnement quand les mensualités transiteront par lui).

---

## 2. La formule unique (money) — on divise sur le NET

Ordre **imposé**, jamais autrement :

```
1. BRUT            = ce que le fan paie                    (ex 49,99€)
2. − Store (15%)   = commission Apple/Google (prélevée à la source)
3. = NET reçu      = BRUT × 0,85                           (ex 42,49€)
4. − Part artiste  = NET × taux_partage_artiste            (50% promo / 60% après)
5. = PART PLATEFORME (ta marge, l'ASSIETTE de l'apporteur)
6. − Commission apporteur = PART PLATEFORME × taux_apporteur
7. = CE QUE TU GARDES
```

Exemple (billet 49,99€, artiste 60%, apporteur 15%) :
`42,49 net → artiste 25,49 → plateforme 17,00 → apporteur 2,55 → toi 14,45`

**Jamais** sur le brut. **Jamais** sur la part artiste. Toujours sur ta part plateforme.

---

## 3. Modèle de données (tables à créer / colonnes à ajouter)

| Table | Rôle | Champs clés |
|---|---|---|
| **apporteurs** | 1 ligne = 1 apporteur | `id, name, email, structure, deal_type, deal_params (JSON), status` |
| **users** (+colonnes) | rattachement + phase artiste | `apporteur_id (nullable, 1 seul), artist_regime (normal/pionnier/fondateur/parrain), date_inscription, sub_free_until, commission_end (modifiable), taux_partage_artiste` |
| **apporteur_commissions** | 1 ligne = 1 commission due | `apporteur_id, artist_id, source_type, source_id, platform_share (assiette), rate, amount, encaissed (bool), invoice_status (due/exigible/payée), created_at` |
| **apporteur_bonuses** | primes fixes (Amandine) | `apporteur_id, artist_id, type, amount, status, triggered_at` |
| **apporteur_reports** | signalement artiste→apporteur | `artist_id, apporteur_id, reason, created_at` → **suspend** la commission |
| **tickets / platform_earnings** (+col) | gating encaissement | `store_fee, net, encaissed (bool), encaissed_at` |

### Comment chaque point de ta spec est couvert
1. **Attribution nominative** → `users.apporteur_id` (nullable, 1 seul). Vide = personne ne commissionne.
2. **Deux compteurs dès l'inscription** → `sub_free_until` (3 mois) + `commission_end` (12/24 mois, **modifiable** → renouvelable).
3. **Formule unique** → §2, assiette = part plateforme nette.
4. **Part artiste variable** → `taux_partage_artiste`, calculé à la volée : `now < sub_free_until ? 50% : offre(60%)`. Bascule automatique, pas de job.
5. **Déclencheur = encaissement** → `apporteur_commissions.encaissed` passe à vrai à J+60 (encaissement Apple) → la commission devient payable.
6. **Pas de commission sans facture** → `invoice_status` : `due` → `exigible` (facture reçue) → `payée`.
7. **Deal flexible** → `deal_type` + `deal_params` (JSON). Moteur = un interpréteur, pas un modèle unique.
8. **Statut artiste** → `artist_regime`. `parrain` (Kassav') = **exclu** du calcul apporteur.
9. **Signalement suspend** → une ligne `apporteur_reports` coupe la commission sur cet artiste. **Jamais** de suspension manuelle sans trace. Le rattachement se coupe **sans supprimer l'artiste**.
10. **Triggers** → inscription (compteurs + 50%) ; fin 3 mois (bascule 60% si payé) ; encaissement (active la commission) ; 1er live / 3e mensualité (primes) ; fin 12 mois (blocage sauf validation) ; **fin des Founders (§0) = arrêt global**.

---

## 4. Ce que JE code (moteur) vs ce qu'il me faut de TOI

**Je code** (backend, testé, comme la modération) :
- Les tables ci-dessus + le moteur `services/apporteur.js` (interpréteur de deal + formule unique).
- Correction NET (−15% store) sur billets & cadeaux, tracée dans `platform_earnings`.
- Rattachement artiste↔apporteur, exclusion parrain, suspension par signalement, gating encaissement + facture.
- Endpoints admin : créer apporteur, rattacher artiste, voir « dû / exigible / payé » par apporteur.

**Il me faut de toi** (3 réponses) :
1. **Ruddy — déclencheur des paliers 5/10/15%** : ça monte selon quoi ? (nombre d'artistes actifs amenés ? volume € encaissé ? ancienneté ?)
2. **Fin des Founders** : c'est une **date** fixe, ou **le nombre de places Founders vendues** (ex : les 200) qui ferme le régime ?
3. **Après les 3 mois** : la part artiste passe à **60%** pour tout le monde, ou ça dépend de l'abonnement qu'il prend (Founder = 60%, autre = autre) ?
