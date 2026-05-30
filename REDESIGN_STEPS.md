# VYBZZZ — Feuille de route refonte design (bleu nuit + or)

Objectif : refaire la **mise en page** de tous les écrans dans la direction premium
(l'accueil est déjà fait ; les couleurs/polices sont déjà appliquées partout).

Légende : ☐ à faire · ☑ fait · 🎯 = écran du moodboard

---

## Étape 0 — Kit de composants premium (fondations) ☑
Refondre les briques réutilisées partout, pour que chaque écran suivant soit rapide et cohérent.
- `widgets/my_appbar.dart` (appbar bleu nuit, retour or, titre Montserrat)
- `widgets/my_button.dart` (bouton or dégradé + variante outline)
- `widgets/my_textfield.dart` (champ bleu nuit, bordure or, label ivoire)
- `widgets/my_container.dart` / `my_card.dart` (carte premium)
- `widgets/my_dialog.dart` / `my_alerts.dart` / `loading_dialog.dart`
- `widgets/my_tab_bar.dart` (onglets or)
- `widgets/my_default_text.dart`, `my_header.dart`, `my_dropdown.dart`, `my_pin_input_field.dart`
- `widgets/shimmer_loaders.dart` (shimmers bleu nuit)
- ✅ déjà : `section_header.dart`

## Étape 1 — Splash & Onboarding (4) ☑
- 🎯 `spalash_screen.dart`
- `OnBoarding/onboarding_1.dart`, `onboarding_2.dart`, `onboarding_3.dart`

## Étape 2 — Authentification (8) ☑
- `Auth/intro_screen.dart`, `choice_screen.dart`, `login_screen.dart`,
  `create_acount.dart`, `create_passwrod.dart`, `forgot_password.dart`,
  `otp_screen.dart`, `complete_profile.dart`

## Étape 3 — Détail événement & Checkout (zone Home) (11) ◐ harmonisé
- 🎯 `homeScreen/future_screen.dart` (Event Detail)
- 🎯 `homeScreen/check_out_screen.dart` (Ticket & Checkout)
- `homeScreen/entry_screen.dart`, `weating_screen.dart`, `explore.dart`,
  `featured_artists.dart`, `live_performance_screen.dart`,
  `performances_screen.dart`, `notification_screen.dart`,
  `report_screen.dart`, `live_broadcast_screen.dart`

## Étape 4 — Discover & Live listing (3) ◐ harmonisé
- `Disscover/disscover_screen.dart`, `LiveScreen/vybz_live_screen.dart`,
  `LiveScreen/artist_detail.dart`

## Étape 5 — Billets / Tickets (5) ◐ harmonisé
- `my_tIckets/my_tickets_screen.dart`, `my_tIckets/live_tickets_video_screen.dart`,
  `profile/my_tickets.dart`, `profile/history.dart`, `profile/topup_history.dart`

## Étape 6 — Profil & réglages (13) ◐ harmonisé
- `profile/profile.dart`, `basic_info.dart`, `personal_screen.dart`,
  `security_screen.dart`, `settings.dart`, `language_screen.dart`,
  `faq_screen.dart`, `contant_page.dart`, `become_artist.dart`,
  `artist_onboarding_screen.dart`, `artist_basic_info.dart`,
  `following_artists.dart`, `alerts_screen.dart`

## Étape 7 — Portefeuille, points, paiement, abonnements (7) ◐ harmonisé
- `profile/user_wallet.dart`, `points_store.dart`, `payment_screen.dart`,
  `all_subscription_screen.dart`, `manage_subscription_screen.dart`,
  `artist_bank_details.dart` + cartes `points_card.dart`, `subscription_card.dart`,
  `transactions_card.dart`

## Étape 8 — Support (3) ◐ harmonisé
- `profile/Support/support_screen.dart`, `support_chat_screen.dart`,
  `all_support_chats.dart`

## Étape 9 — Espace Artiste : Studio (8) ◐ harmonisé
- `Studio/studio_screen.dart`, `artist_events_screen.dart`,
  `artist_create_event.dart`, `add_acount.dart`, `artist_withdraw.dart`,
  `revenue_screen.dart`, `transaction_history.dart`, `artist_chat_tab.dart`
- `artist_bottom_bar.dart` (barre artiste — déjà partiellement faite)

## Étape 10 — Espace Artiste : Events & Stats (6) ◐ harmonisé
- `Events/artist_live_screen.dart`, `artist_live_event_chat.dart`,
  `artist_tips_tab.dart`, `stats_screen.dart`, `analytics_screen.dart`,
  `Status/artist_histroy_screen.dart`

## Étape 11 — Live streaming Zego (7) 🎯 ◐ harmonisé
- 🎯 `ZegoCloud/pre_stream_screen.dart`, `start_stream.dart`, `join_stream.dart`,
  `zego_gifts.dart` (Gifting), `widgets/live_stream_top_bar.dart`,
  `live_stream_side_actions.dart`, `live_stream_chat_preview.dart`

## Étape 12 — Divers & QA final ◐ fait
- `travis_scott/about_screen.dart`, `events_screen.dart` (vérifier si utilisés)
- Passe finale : traquer tous les textes noirs résiduels sur fond bleu nuit,
  cohérence des icônes, espacements, et relecture écran par écran.

---

### Méthode par étape
1. Je refais les écrans de l'étape.
2. Commit + push.
3. Tu lances l'app, captures, on ajuste si besoin.
4. On passe à l'étape suivante.
