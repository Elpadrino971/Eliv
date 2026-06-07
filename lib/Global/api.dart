class APIs {
  // static const String mainIP = 'https://vybzzz.fryandeatfood.com'; //Live (Hammad)
  // static const String mainIP = 'http://192.168.1.62:8002'; //Local (dev)
  static const String mainIP = 'https://api.vybzzz.online'; //PROD (notre VPS Hostinger)

  ///For Assets
  static const String profileIP = '$mainIP/profiles';
  static const String eventImageIP = '$mainIP/events/covers';
  static const String eventVideoIP = '$mainIP/events/videos';
  static const String giftImageIP = '$mainIP/giftImages';

  static const String baseAPI = '$mainIP/api';

  // ───────────────────────────────────────────────────────────────────────
  // ABONNEMENT WEB (Stripe) — abos ARTISTES, modele hybride (IAP + Web).
  //
  // Page generique vybzzz.com qui gere les 3 paliers fondateurs (1->200) ET le
  // Pro (200+) via current_founder_plan() cote Supabase, puis lance le Stripe
  // Checkout avec le bon price_id. L'app y ajoute ?user_id=... (a mapper en
  // client_reference_id cote web -> webhook). Voir docs/STRIPE_HYBRID_SETUP.md
  // ───────────────────────────────────────────────────────────────────────
  static const String webSubscribeUrl = 'https://vybzzz.com/subscribe';

  // ───────────────────────────────────────────────────────────────────────
  // MUX — REPLAY (VOD). Le PLAYBACK ID est PUBLIC (pas un secret).
  // CAROUSEL / concert vedette du 1er écran Home (16:9).
  // En prod, ce champ viendra du backend par event (signed playback id).
  // ───────────────────────────────────────────────────────────────────────
  static const String muxDemoPlaybackId =
      'Ixf100DM00MIBOSiPjVkEfbToOgso01NuVin19ugUXbjQA'; // YTDown — carousel home

  /// CONCERT PRO (Mux Live) : playback id d'un flux LIVE.
  /// Vide = pas de live pro en cours.
  static const String muxLivePlaybackId =
      'EcO013Q00m3BON019ydIrEUd3YaAES4J9nx02arl7U862P4'; // Prince - Purple Rain

  /// LIVES (concerts en direct façon Mux Live).
  static const List<String> muxLivePlaybackIds = [
    'EcO013Q00m3BON019ydIrEUd3YaAES4J9nx02arl7U862P4', // Prince - Purple Rain (4:3)
    'Qz0200nUKYr5025USFnUB9DrK3YzXY2k8jzjWcvq4SukBc', // Hans Zimmer (16:9)
  ];

  /// Feed "POUR TOI" (reels verticaux).
  static const List<String> muxDemoPlaybackIds = [
    'OBFReMrxEbTxZVlQw202hYRSzVxVqu7BisBWWKBM3S18', // Kelly Rowland - Cater 2 U (9:16)
    'ZIAVh2AYyALPoxxrRW01wIqPDzX5eO1vYx1XSOSbj39o', // rap short (9:16)
  ];

  /// Onglet "CLIPS" (shorts UGC, 3e page du Live).
  static const List<String> muxShortsPlaybackIds = [
    'JI800K01xSrahXo97QPL01MuLITIH7m3AMvYeJk02Mcfsi00', // Linkin Park - In The End (160:89)
    'BC702qp42F2svVH2n4OU4nHDZz7YwMjSvx02r8gQkRA6g', // YTDown (16:9)
  ];

  // ───────────────────────────────────────────────────────────────────────
  // SHORTS UGC (upload vidéo utilisateur via Mux Direct Upload).
  // [A IMPLEMENTER PAR LE DEV] Le backend cree un "direct upload" Mux
  // (POST https://api.mux.com/video/v1/uploads avec le token secret) et
  // renvoie { "upload_url": "https://storage.googleapis.com/..." }.
  // L'app PUT ensuite la video sur cette URL. Voir docs/MUX_SHORTS_UGC.md
  // ───────────────────────────────────────────────────────────────────────
  static const String createShortUploadAPI = '$baseAPI/shorts/create-upload';

  //Auth
  static const String loginAPI = '$baseAPI/login';
  static const String signupAPI = '$baseAPI/sign-up';
  static const String verifyOtpAPI = '$baseAPI/verify';
  static const String forgetPasswordAPI = '$baseAPI/forget';
  static const String resetPasswordAPI = '$baseAPI/reset-password';
  static const String updatePasswordAPI = '$baseAPI/update-password';
  static const String updateProfileAPI = '$baseAPI/update-profile';
  static const String getUserAPI = '$baseAPI/get-user'; // Post
  static const String eventLogsAPI = '$baseAPI/event-logs'; // Post
  static const String getGenresAPI = '$baseAPI/genres';
  static const String socialLoginAPI = '$baseAPI/social-login';
  static const String deleteAccountAPI = '$baseAPI/delete-account';

  //Events
  static const String eventsAPI = '$baseAPI/events';
  static const String getBannerEventsAPI = '$baseAPI/banner-events';
  static const String featuredArtistAPI = '$baseAPI/featured-artists';
  static const String getArtistFollowersAPI = '$baseAPI/followers';
  static const String buyTicketAPI = '$baseAPI/buy-ticket';
  static const String userEventHistoryAPI = '$baseAPI/user-event-history';
  static const String eventCommentAPI = '$baseAPI/event-comment';
  static const String eventHistoryAPI = '$baseAPI/user-event-history';
  static const String getGiftsAPI = '$baseAPI/gifts';
  static const String sendGiftAPI = '$baseAPI/event-gift';
  static const String updateEventStatusAPI = '$baseAPI/events/update';
  static const String reportEventAPI = '$baseAPI/report-event';
  static String getArtistEventsAPI(String id) => '$baseAPI/artist/$id/events';
  static const String getEventStatsByUserIdAPI =
      '$baseAPI/get-event-stats-by-user-id'; // Post

  //Follow
  static const String followArtistAPI = '$baseAPI/follow';
  static const String unfollowArtistAPI = '$baseAPI/unfollow';
  static const String getFollowingArtistsAPI = '$baseAPI/following';

  /// Artist Specific
  static const String getArtistDataAPI = '$baseAPI/get-artist-statistics';

  //Packages
  static const String getPackagesAPI = '$baseAPI/packages/list';
  static const String purchasePackageAPI = '$baseAPI/packages/buy';

  ///Bank
  static const String addBankAPI = '$baseAPI/withdraw/add-bank';
  static const String getBankAPI = '$baseAPI/withdraw/get-user-banks';
  static const String updateBankAPI = '$baseAPI/withdraw/update-bank';
  static const String deleteBankAPI = '$baseAPI/withdraw/delete-bank';
  static const String withdrawAPI = '$baseAPI/withdraw/add';

  /// Support
  static const String supportListAPI = '$baseAPI/support/get-list'; //Post
  static const String supportCreateAPI = '$baseAPI/support/create'; //Post
  static const String supportResolveAPI = '$baseAPI/support/resolve'; //Post
  static const String supportDetailsAPI = '$baseAPI/support/get-details'; //Post
  static const String supportSubjectsAPI =
      '$baseAPI/support/get-subjects'; //Post
  static const String supportStoreMetaAPI =
      '$baseAPI/support/store-meta'; //Post

  //Transactions
  static const String getTransactionAPI = '$baseAPI/get-transactions';

  //Management
  static const String getManagementAPI = '$baseAPI/settings/get-management';

  //Settings
  static const String getSettingsAPI = '$baseAPI/settings/get-settings';

  //Subscription
  static const String getSubscriptionsAPI = '$baseAPI/subscription/get';
  static const String buySubscriptionAPI = '$baseAPI/subscription/buy';

  // Abusive Words
  static const String getAbusiveWordsAPI = '$baseAPI/get-abusive-words';

  // Boîte à idées
  static const String submitIdeaAPI = '$baseAPI/ideas';
}
