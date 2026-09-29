import 'dart:convert';

import 'package:artist/Global/api.dart';
import 'package:artist/Global/global.dart';
import 'package:artist/Global/mux.dart';
import 'package:artist/Models/abusive_words_model.dart';
import 'package:artist/Models/artist_clips_model.dart';
import 'package:artist/Models/event_model.dart';
import 'package:artist/Models/feed_clip_model.dart';
import 'package:artist/Models/follow_model.dart';
import 'package:artist/Models/gift_model.dart';
import 'package:artist/Models/user_model.dart';
import 'package:artist/services/api_services.dart';
import 'package:flutter/scheduler.dart';
import 'package:get/get.dart';
import 'package:video_player/video_player.dart';
import 'package:zego_uikit_prebuilt_live_streaming/zego_uikit_prebuilt_live_streaming.dart';

class EventController extends GetxController {
  final response = ApiResponse();
  // Réponse dédiée à la grille clips : la fiche artiste charge events/followers
  // via [response] tandis que la grille charge en parallèle. Un ApiResponse
  // séparé évite que les deux appels écrasent l'URL/le type l'un de l'autre.
  final _clipsResponse = ApiResponse();

  Rx<EventsModel> featuredArtist = EventsModel().obs;
  Rx<EventsModel> nextEvents = EventsModel().obs;
  Rx<EventsModel> upcomingEvents = EventsModel().obs;
  Rx<EventsModel> liveNowEvents = EventsModel().obs;
  Rx<EventsModel> filteredEvents = EventsModel().obs;
  Rx<EventsModel> allEvents = EventsModel().obs;
  Rx<EventsModel> bannerEvents = EventsModel().obs;
  Rx<EventsModel> userJoinedEvents = EventsModel().obs;
  Rx<EventsModel> artistEvents = EventsModel().obs;
  Rx<ArtistClipsModel> artistClips = ArtistClipsModel().obs;
  RxBool artistClipsLoading = false.obs;
  Rx<EventsModel> eventHistory = EventsModel().obs;
  RxList<User> featuredArtists = <User>[].obs;
  Rx<FollowModel> artistFollowers = FollowModel().obs;
  Rx<UserModel> artistProfile = UserModel().obs;
  Rx<GiftModel> gifts = GiftModel().obs;
  Rx<AbusiveWordsModel> abusiveWords = AbusiveWordsModel().obs;

  RxBool isLoading = false.obs;

  /// ── Drapeaux de chargement par liste ──
  /// Règle d'affichage (accueil, live, billets) : un squelette (shimmer)
  /// n'est montré QUE si la donnée est encore `null` ET que la requête est
  /// en cours. Une liste vide après chargement (ou un échec réseau) donne un
  /// état vide / une section masquée — jamais un shimmer infini.
  bool isLoadingBanner = false;
  bool isLoadingFeaturedArtists = false;
  bool isLoadingLiveNow = false;
  bool isLoadingNextEvents = false;
  bool isLoadingUpcoming = false;
  bool isLoadingJoinedEvents = false;
  bool isLoadingFeedClips = false;

  /// Vrai dès qu'une réponse (même vide ou en erreur) a été reçue pour les
  /// artistes vedettes : [featuredArtists] est une liste non nullable, on ne
  /// peut donc pas distinguer « jamais chargé » de « vide » sans ce drapeau.
  bool featuredArtistsLoaded = false;

  /// Idem pour les clips des feeds (listes non nullables).
  bool feedClipsLoaded = false;

  /// Video Player Variables
  Rxn<VideoPlayerController> currentController = Rxn<VideoPlayerController>();
  var isMuted = false.obs;
  var currentVideoIndex = 0.obs;
  var showVideoControls = false.obs;

  // ── Lecteurs du feed « Pour toi » : au plus DEUX vivants ──
  //  - [currentController] : clip affiché (lu) ;
  //  - [_nextController]   : clip index + 1, initialisé SANS être lu
  //    (préchargement), promu lecteur courant au swipe -> démarrage
  //    instantané. Le clip précédent est libéré au changement de page ; les
  //    deux sont libérés quand le feed quitte l'écran ou passe en
  //    arrière-plan (voir _ForYouFeedState dans vybz_live_screen.dart).
  VideoPlayerController? _nextController;
  String? _nextUrl;

  /// Accepte une URL complète (HLS Mux : https://stream.mux.com/<id>.m3u8,
  /// plafonnée à 720p pour un démarrage plus rapide sur mobile) ou un simple
  /// nom de fichier sur le backend.
  Uri _videoUri(String videoUrl) => videoUrl.startsWith('http')
      ? Uri.parse(Mux.mobileHls(videoUrl))
      : Uri.parse('${APIs.eventVideoIP}/$videoUrl');

  /// Lecteur courant du feed. [startAt] : position de reprise (retour
  /// d'arrière-plan). Réutilise le lecteur préchargé si c'est le même clip.
  void initVideoPlayer(String videoUrl, {Duration? startAt}) {
    currentController.value?.dispose();
    currentController.value = null;

    // Clip déjà préchargé : promu lecteur courant, lecture immédiate.
    final preloaded = _nextController;
    if (preloaded != null && _nextUrl == videoUrl && !preloaded.value.hasError) {
      _nextController = null;
      _nextUrl = null;
      currentController.value = preloaded;
      preloaded.setLooping(true);
      preloaded.setVolume(isMuted.value ? 0 : 1);
      if (startAt != null && startAt > Duration.zero) preloaded.seekTo(startAt);
      // play() avant la fin de initialize() est mémorisé par video_player et
      // appliqué dès que le lecteur est prêt.
      preloaded.play();
      _safeUpdate();
      return;
    }
    _nextController?.dispose();
    _nextController = null;
    _nextUrl = null;

    final controller = VideoPlayerController.networkUrl(_videoUri(videoUrl));
    controller.setLooping(true);
    controller.setVolume(isMuted.value ? 0 : 1);
    currentController.value = controller;
    // setLooping / play sont ré-appliqués juste après initialize() ; si le
    // lecteur a été remplacé entre-temps (swipe rapide), on ne relance rien.
    controller.initialize().then((_) {
      if (currentController.value != controller) return;
      if (startAt != null && startAt > Duration.zero) {
        controller.seekTo(startAt);
      }
      controller.setLooping(true);
      controller.play();
      _safeUpdate();
    }).catchError((Object e) {
      myPrint('reel init: $e');
    });
    controller.play();
    _safeUpdate();
  }

  /// `update()` sans jamais tomber pendant une phase de build (crash
  /// « setState() or markNeedsBuild() called during build » quand le feed
  /// initialise son premier clip depuis initState).
  void _safeUpdate() {
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.persistentCallbacks ||
        phase == SchedulerPhase.midFrameMicrotasks) {
      SchedulerBinding.instance.addPostFrameCallback((_) => update());
    } else {
      update();
    }
  }

  /// Précharge le clip suivant du feed (initialisé, jamais lu tant qu'il
  /// n'est pas promu par [initVideoPlayer]). null -> libère le préchargé.
  void preloadNextVideo(String? videoUrl) {
    if (videoUrl != null && videoUrl == _nextUrl) return;
    _nextController?.dispose();
    _nextController = null;
    _nextUrl = null;
    if (videoUrl == null) return;
    final controller = VideoPlayerController.networkUrl(_videoUri(videoUrl));
    controller.setLooping(true);
    controller.setVolume(isMuted.value ? 0 : 1);
    _nextController = controller;
    _nextUrl = videoUrl;
    controller.initialize().then((_) {
      // Promu lecteur courant avant la fin de l'init : la vue se rafraîchit.
      if (currentController.value == controller) update();
    }).catchError((Object e) {
      myPrint('reel preload: $e');
    });
  }

  /// URL du reel à l'index [index] du feed « Pour toi » (clips admin en
  /// priorité, sinon vidéo du concert), ou null hors bornes / sans vidéo.
  String? reelUrlAt(int index) {
    final ids = forYouClipUrls;
    if (ids.isNotEmpty) {
      return (index >= 0 && index < ids.length) ? ids[index] : null;
    }
    final events = allEvents.value.data ?? const <Event>[];
    if (index < 0 || index >= events.length) return null;
    final reel = events[index].videoReel;
    return (reel != null && reel.isNotEmpty) ? reel : null;
  }

  void onPageChanged(int index) {
    currentVideoIndex.value = index;
    final url = reelUrlAt(index);
    if (url != null) {
      initVideoPlayer(url);
      preloadNextVideo(reelUrlAt(index + 1));
    } else {
      disposeVideoController();
    }
    update();
  }

  /// URL du 1er reel (init du feed). Priorite aux clips geres depuis
  /// l'admin (rubrique "Clips (Feeds)") ; sinon video de l'event backend.
  String? reelUrlFor(Event? event) {
    if (forYouClipUrls.isNotEmpty) {
      return forYouClipUrls.first;
    }
    final reel = event?.videoReel;
    return (reel != null && reel.isNotEmpty) ? reel : null;
  }

  /// Clips geres depuis l'admin (rubrique "Clips (Feeds)") pour les onglets
  /// "Pour toi" et "Clips" de l'ecran Live — plus besoin d'editer une liste
  /// en dur dans le code, tout se gere depuis le backend.
  RxList<String> forYouClipUrls = <String>[].obs;
  RxList<String> clipsFeedUrls = <String>[].obs;

  /// Mêmes clips que [forYouClipUrls] / [clipsFeedUrls], avec leurs
  /// métadonnées (id, titre, id de lecture Mux → miniature). Sert à la grille
  /// « Clips » de l'accueil ; les listes d'URLs restent la source des feeds
  /// vidéo (même ordre, mêmes index).
  RxList<FeedClip> forYouClips = <FeedClip>[].obs;
  RxList<FeedClip> clipsFeedClips = <FeedClip>[].obs;

  Future<List<FeedClip>> _fetchFeedClips(String feed) async {
    response.typeSetter = 'get';
    response.urlSetter = '${APIs.feedClipsAPI}?feed=$feed';
    try {
      final value = await response.hitAPI();
      if (value == null || '$value'.split(' ').first == 'error') return [];
      final decoded = jsonDecode('$value');
      if (decoded is! Map) return [];
      final list = (decoded['list'] as List?) ?? [];
      return list
          .map(FeedClip.fromJson)
          .whereType<FeedClip>()
          .toList();
    } catch (e) {
      myPrint('feed-clips ($feed): $e');
      return [];
    }
  }

  Future<void> loadFeedClips() async {
    // Pas d'update() ici : appelé depuis initState, un rebuild synchrone
    // déclencherait « setState() called during build ». Le drapeau est lu
    // au prochain build ; l'update() du finally suit un await (sans risque).
    isLoadingFeedClips = true;
    try {
      final forYou = await _fetchFeedClips('for_you');
      forYouClips.value = forYou;
      forYouClipUrls.value = forYou.map((c) => c.videoUrl).toList();
      final clips = await _fetchFeedClips('clips');
      clipsFeedClips.value = clips;
      clipsFeedUrls.value = clips.map((c) => c.videoUrl).toList();
    } finally {
      isLoadingFeedClips = false;
      feedClipsLoaded = true;
      update();
    }
  }

  void toggleVideoControls() {
    showVideoControls.value = !showVideoControls.value;
    if (showVideoControls.value) {
      Future.delayed(Duration(seconds: 3), () {
        showVideoControls.value = false;
        update();
      });
    }
    update();
  }

  void playPauseVideo() {
    if (currentController.value != null) {
      var controller = currentController.value!;
      controller.value.isPlaying ? controller.pause() : controller.play();
      update();
    }
  }

  void seekVideo(int seconds) {
    if (currentController.value != null) {
      var controller = currentController.value!;
      final newPos = controller.value.position + Duration(seconds: seconds);
      controller.seekTo(newPos < Duration.zero ? Duration.zero : newPos);
      update();
    }
  }

  void toggleMute() {
    isMuted.value = !isMuted.value;
    currentController.value?.setVolume(isMuted.value ? 0 : 1);
    update();
  }

  /// Libère le lecteur courant ET le clip préchargé (sortie du feed,
  /// passage en arrière-plan).
  void disposeVideoController() {
    currentController.value?.dispose();
    currentController.value = null;
    _nextController?.dispose();
    _nextController = null;
    _nextUrl = null;
  }

  /// Positionne le drapeau de chargement de la liste visée par
  /// [getEventsByStatus] (même aiguillage que l'affectation du résultat).
  void _setEventsLoading({
    required EventStatus status,
    required EventDateStatus? dateStatus,
    required bool loading,
  }) {
    if (dateStatus == EventDateStatus.future) {
      isLoadingUpcoming = loading;
    } else if (status == EventStatus.live) {
      isLoadingLiveNow = loading;
    } else if (dateStatus == EventDateStatus.today) {
      isLoadingNextEvents = loading;
    }
  }

  Future<void> getEventsByStatus({
    EventStatus status = EventStatus.published,
    EventDateStatus? dateStatus,
    List? genres,
  }) async {
    // Pas d'update() ici (voir getBannerEvents) : le drapeau est lu au
    // prochain build, l'update() du finally suit un await.
    _setEventsLoading(status: status, dateStatus: dateStatus, loading: true);
    response.typeSetter = 'get';
    response.urlSetter =
        '${APIs.eventsAPI}?status=${status.name}&day=${dateStatus?.name ?? ''}&genre_ids=${genres?.join(',') ?? '[]'}';
    try {
      await response.hitAPI().then((value) {
        if (value.split(' ').first != 'error') {
          /// Upcoming and All Events
          if (dateStatus == EventDateStatus.future &&
              status == EventStatus.published) {
            allEvents.value = eventModelFromJson(value);
            upcomingEvents.value = eventModelFromJson(value);

            /// Upcoming Events
          } else if (dateStatus == EventDateStatus.future) {
            upcomingEvents.value = eventModelFromJson(value);

            /// Live Events
          } else if (status == EventStatus.live) {
            liveNowEvents.value = eventModelFromJson(value);

            /// Today's Events
          } else if (dateStatus == EventDateStatus.today) {
            nextEvents.value = eventModelFromJson(value);

            /// Filtered Events
          } else if (genres != null) {
            filteredEvents.value = eventModelFromJson(value);
          }
        } else {
          parseError(value, doBack: false);
        }
      });
    } finally {
      _setEventsLoading(status: status, dateStatus: dateStatus, loading: false);
      update();
    }
  }

  Future<void> getBannerEvents() async {
    // Pas d'update() ici : appelé depuis initState, un rebuild synchrone
    // déclencherait « setState() called during build ». Le drapeau est lu
    // au prochain build ; l'update() du finally suit un await (sans risque).
    isLoadingBanner = true;
    response.typeSetter = 'get';
    response.urlSetter = APIs.getBannerEventsAPI;
    try {
      await response.hitAPI().then((value) {
        if (value.split(' ').first != 'error') {
          bannerEvents.value = eventModelFromJson(value);
        } else {
          parseError(value, doBack: false);
        }
      });
    } finally {
      isLoadingBanner = false;
      update();
    }
  }

  Future<void> getFeaturedArtists() async {
    // Pas d'update() ici : appelé depuis initState, un rebuild synchrone
    // déclencherait « setState() called during build ». Le drapeau est lu
    // au prochain build ; l'update() du finally suit un await (sans risque).
    isLoadingFeaturedArtists = true;
    response.typeSetter = 'get';
    response.urlSetter = APIs.featuredArtistAPI;
    try {
      await response.hitAPI().then((value) {
        if (value.split(' ').first != 'error') {
          final List data = (jsonDecode(value)['data'] as List?) ?? [];
          featuredArtists.value = data.map((e) => User.fromJson(e)).toList();
        } else {
          parseError(value, doBack: false);
        }
      });
    } catch (e) {
      myPrint('getFeaturedArtists: $e');
    } finally {
      isLoadingFeaturedArtists = false;
      featuredArtistsLoaded = true;
      update();
    }
  }

  Future<void> getArtistEvents({required String artistId}) async {
    artistEvents.value = EventsModel();
    response.typeSetter = 'get';
    response.urlSetter = APIs.getArtistEventsAPI(artistId);
    await response.hitAPI().then((value) {
      if (value.split(' ').first != 'error') {
        artistEvents.value = eventModelFromJson(value);
        update();
      } else {
        parseError(value, doBack: false);
      }
    });
  }

  Future<void> getArtistClips({required String artistId}) async {
    artistClipsLoading.value = true;
    artistClips.value = ArtistClipsModel();
    _clipsResponse.typeSetter = 'get';
    _clipsResponse.urlSetter = APIs.getArtistClipsAPI(artistId);
    await _clipsResponse.hitAPI().then((value) {
      if (value.split(' ').first != 'error') {
        artistClips.value = artistClipsModelFromJson(value);
        update();
      } else {
        parseError(value, doBack: false);
      }
    });
    artistClipsLoading.value = false;
  }

  // ── "Ma liste" (artistes enregistrés, façon Netflix) ──
  final _listResponse = ApiResponse();
  RxBool artistSaved = false.obs;
  RxBool myListLoading = false.obs;
  RxList<User> myListArtists = <User>[].obs;

  Future<void> checkArtistSaved({required String artistId}) async {
    _listResponse.typeSetter = 'get';
    _listResponse.urlSetter = APIs.artistSavedAPI(artistId);
    final value = await _listResponse.hitAPI();
    if (value.split(' ').first != 'error') {
      try {
        artistSaved.value = jsonDecode(value)['saved'] == true;
      } catch (_) {}
    }
  }

  Future<void> toggleSaveArtist({required String artistId}) async {
    final wasSaved = artistSaved.value;
    artistSaved.value = !wasSaved; // maj optimiste
    _listResponse.typeSetter = 'post';
    _listResponse.urlSetter =
        wasSaved ? APIs.unsaveArtistAPI(artistId) : APIs.saveArtistAPI(artistId);
    _listResponse.bodySetter = {};
    final value = await _listResponse.hitAPI();
    if (value.split(' ').first == 'error') {
      artistSaved.value = wasSaved; // rollback si échec
      parseError(value, doBack: false);
    }
  }

  Future<void> getMyList() async {
    myListLoading.value = true;
    _listResponse.typeSetter = 'get';
    _listResponse.urlSetter = APIs.myListAPI;
    final value = await _listResponse.hitAPI();
    if (value.split(' ').first != 'error') {
      try {
        final data = (jsonDecode(value)['data'] as List?) ?? [];
        myListArtists.value =
            data.map((e) => User.fromJson(e as Map<String, dynamic>)).toList();
      } catch (e) {
        parseError(value, doBack: false);
      }
    }
    myListLoading.value = false;
  }

  Future<void> getArtistFollowers({required String artistId}) async {
    response.typeSetter = 'get';
    response.urlSetter = '${APIs.getArtistFollowersAPI}/$artistId';
    await response.hitAPI().then((value) {
      if (value.split(' ').first != 'error') {
        try {
          artistFollowers.value = followModelFromJson(value);
        } catch (e) {
          myPrint('getArtistFollowers parse: $e');
        }
        update();
      } else {
        parseError(value, doBack: false);
      }
    });
  }

  Future<void> followArtist({required String artistId}) async {
    response.typeSetter = 'post';
    response.urlSetter = APIs.followArtistAPI;
    response.bodySetter = {
      "user_id": "${userModel.value.user?.id ?? 1}",
      "artist_id": artistId,
    };
    await response.hitAPI().then((value) {
      if (value.split(' ').first != 'error') {
        update();
      } else {
        parseError(value);
      }
    });
  }

  Future<void> unfollowArtist({required String artistId}) async {
    response.typeSetter = 'post';
    response.urlSetter = APIs.unfollowArtistAPI;
    response.bodySetter = {
      "user_id": "${userModel.value.user?.id ?? 1}",
      "artist_id": artistId,
    };
    await response.hitAPI().then((value) {
      if (value.split(' ').first != 'error') {
        update();
      } else {
        parseError(value, doBack: false);
      }
    });
  }

  /// Clé GetStorage : id du concert dont l'achat store (Apple / Google) a été
  /// lancé mais dont le billet n'a pas (encore) été attaché par /buy-ticket.
  /// Écrite AVANT `Purchases.purchase`, effacée quand /buy-ticket réussit.
  /// Permet le bouton « J'ai déjà payé · récupérer mon billet ».
  static const String pendingTicketKey = 'pending_ticket_event';

  /// Dernière réponse d'erreur brute de /buy-ticket (format `error {...}`),
  /// à passer à [parseError] par l'appelant s'il veut l'afficher.
  String? lastBuyTicketError;

  /// Id du concert en attente de billet (voir [pendingTicketKey]), ou null.
  static int? pendingTicketEventId() {
    final raw = box.read(pendingTicketKey);
    if (raw is int) return raw;
    return int.tryParse('${raw ?? ''}');
  }

  /// Faux pour les refus DÉFINITIFS du serveur (géo-blocage 451, concert
  /// introuvable 404, action non autorisée 403) : inutile de réessayer. Tout
  /// le reste (coupure réseau / timeout, 503 « vérification indisponible »,
  /// 402 « aucun achat valide » = reçu pas encore visible chez RevenueCat,
  /// 409 course concurrente) mérite un nouvel essai.
  bool _isRetryableTicketError(String value) {
    final msg = value.toLowerCase();
    if (msg.contains('région') || msg.contains('region')) return false;
    if (msg.contains('not found') || msg.contains('introuvable')) return false;
    if (msg.contains('non autoris')) return false;
    return true;
  }

  /// Un appel /buy-ticket, SANS effet UI. Renvoie le concert mis à jour ou
  /// null (l'erreur brute est dans [lastBuyTicketError]). Ne lance jamais.
  Future<Event?> _postBuyTicket(String eventId) async {
    lastBuyTicketError = null;
    response.typeSetter = 'post';
    response.urlSetter = APIs.buyTicketAPI;
    // Pays de l'APPAREIL (pas la langue) : sert au géo-blocage des concerts
    // (un organisateur peut restreindre la diffusion en ligne dans le pays de
    // son événement physique). Vide si indéterminé -> non bloqué.
    final countryCode = Get.deviceLocale?.countryCode ?? '';
    response.bodySetter = {
      "event_id": eventId,
      "user_id": "${userModel.value.user?.id ?? 1}",
      "country_code": countryCode,
    };
    try {
      final value = await response.hitAPI();
      if (value.split(' ').first != 'error') {
        final data = jsonDecode(value)['data'];
        if (data is Map<String, dynamic>) {
          final event = Event.fromJson(data);
          if ('${box.read(pendingTicketKey) ?? ''}' == eventId) {
            await box.remove(pendingTicketKey);
          }
          update();
          return event;
        }
        lastBuyTicketError =
            'error ${jsonEncode({'message': 'common_error'.tr})}';
        return null;
      }
      lastBuyTicketError = value;
      return null;
    } catch (e) {
      myPrint('buyTicket: exception -> $e');
      lastBuyTicketError =
          'error ${jsonEncode({'message': 'common_error'.tr})}';
      return null;
    }
  }

  /// Enregistre l'accès au concert. Avec [retry], jusqu'à 3 nouveaux essais
  /// espacés de 2 s, 5 s puis 10 s quand l'échec est temporaire (réseau,
  /// 503, 402 « aucun achat valide » le temps que RevenueCat voie le reçu).
  /// À utiliser APRÈS un achat store validé : le paiement est encaissé, il
  /// faut absolument attacher le billet. Aucun effet UI.
  Future<Event?> buyTicketWithRetry(String eventId, {bool retry = true}) async {
    Event? event = await _postBuyTicket(eventId);
    if (!retry) return event;
    const delays = [2, 5, 10];
    for (final seconds in delays) {
      if (event != null) break;
      final err = lastBuyTicketError;
      if (err != null && !_isRetryableTicketError(err)) break;
      await Future.delayed(Duration(seconds: seconds));
      event = await _postBuyTicket(eventId);
    }
    return event;
  }

  /// Version « avec dialogues » : succès -> dialogue puis 3 Get.back (dialogue,
  /// loader, écran de paiement) ; échec -> ferme le loader et affiche l'erreur.
  /// Suppose qu'un loader ([myLoadingDialog]) est ouvert. Ne lance jamais.
  Future<Event?> buyTicket({required String eventId, bool retry = false}) async {
    Event? event;
    try {
      event = await buyTicketWithRetry(eventId, retry: retry);
    } catch (e) {
      myPrint('buyTicket: exception -> $e');
      event = null;
    }
    if (event != null) {
      final result = event;
      mySuccessDialog(
        subtitle: 'msg_ticket_booked'.tr,
        ontap: () {
          Get.back();
          Get.back();
          Get.back(result: result);
        },
      );
    } else {
      parseError(
        lastBuyTicketError ??
            'error ${jsonEncode({'message': 'common_error'.tr})}',
        doBack: true,
      );
    }
    return event;
  }

  /// Récupère un concert unique par son id (pour le join direct depuis
  /// l'anneau LIVE du feed). Renvoie null si introuvable.
  Future<Event?> getEventById(String id) async {
    Event? event;
    response.typeSetter = 'get';
    response.urlSetter = APIs.eventByIdAPI(id);
    await response.hitAPI().then((value) {
      if (value.split(' ').first != 'error') {
        final data = jsonDecode(value)['data'];
        if (data != null) event = Event.fromJson(data);
      }
    });
    return event;
  }

  /// Enregistre l'accès au concert (billet) SANS effet de bord UI (ni dialog
  /// ni pop d'écrans, contrairement à [buyTicket]). Utilisé par le bandeau
  /// "Rejoindre le live" pour enchaîner directement sur la salle de live.
  /// [retry] : nouveaux essais (2 s / 5 s / 10 s) après un achat store payé.
  /// En cas d'échec, l'erreur brute est dans [lastBuyTicketError].
  Future<Event?> registerTicketAndGet(String eventId, {bool retry = false}) =>
      buyTicketWithRetry(eventId, retry: retry);

  Future<void> getUserJoinedEvents() async {
    // Pas d'update() ici : appelé depuis initState, un rebuild synchrone
    // déclencherait « setState() called during build ». Le drapeau est lu
    // au prochain build ; l'update() du finally suit un await (sans risque).
    isLoadingJoinedEvents = true;
    response.typeSetter = 'post';
    response.urlSetter = APIs.userEventHistoryAPI;
    response.bodySetter = {"user_id": "${userModel.value.user?.id ?? 1}"};
    try {
      await response.hitAPI().then((value) {
        if (value.split(' ').first != 'error') {
          userJoinedEvents.value = eventModelFromJson(value, 'list');
        } else {
          parseError(value, doBack: false);
        }
      });
    } finally {
      isLoadingJoinedEvents = false;
      update();
    }
  }

  /// Like / unlike un concert. Renvoie le nouveau nombre de likes.
  Future<int?> likeEvent({required String eventId, required bool liked}) async {
    int? count;
    response.typeSetter = 'post';
    response.urlSetter = APIs.likeEventAPI(eventId);
    response.bodySetter = {'liked': '$liked', 'user_id': '${userModel.value.user?.id ?? 1}'};
    await response.hitAPI().then((value) {
      if (value.split(' ').first != 'error') {
        count = jsonDecode(value)['likes_count'];
        update();
      } else {
        parseError(value, doBack: false);
      }
    });
    return count;
  }

  Future<List<Activity>?> getEventComments({
    required String eventId,
    required String comment,
  }) async {
    List<Activity>? data;
    response.typeSetter = 'post';
    response.urlSetter = APIs.eventCommentAPI;
    response.bodySetter = {
      "event_id": eventId,
      "user_id": '${userModel.value.user?.id ?? 1}',
      "comment": comment,
    };
    await response.hitAPI().then((value) {
      if (value.split(' ').first != 'error') {
        data = (jsonDecode(value)['activity'] as List)
            .map((x) => Activity.fromJson(x))
            .toList();
        update();
        return data;
      } else {
        parseError(value, doBack: false);
        return data;
      }
    });
    return data;
  }

  Future<void> getUserModel({required String id}) async {
    response.typeSetter = 'post';
    response.urlSetter = APIs.getUserAPI;
    response.bodySetter = {'id': id};
    await response.hitAPI().then((value) {
      if (value.split(' ').first != 'error') {
        artistProfile.value = userModelFromJson(value);
        update();
      } else {
        parseError(value);
      }
    });
  }

  /// Fil d'activité du live (commentaires, cadeaux, billets). Appelé en
  /// BOUCLE (toutes les 15 s) par les écrans de live : une erreur ne doit
  /// JAMAIS ouvrir de dialogue modal (avant, chaque coupure réseau affichait
  /// une alerte par-dessus le live). Renvoie null en cas d'échec : l'appelant
  /// garde alors le fil précédent.
  Future<List<Activity>?> getEventLogs({required String eventId}) async {
    List<Activity>? data;
    response.typeSetter = 'post';
    response.urlSetter = APIs.eventLogsAPI;
    response.bodySetter = {'event_id': eventId};
    try {
      final value = await response.hitAPI();
      if (value.split(' ').first != 'error') {
        data = ((jsonDecode(value)['activity'] as List?) ?? [])
            .map((x) => Activity.fromJson(x))
            .toList();
        update();
      } else {
        myPrint('getEventLogs: $value');
      }
    } catch (e) {
      myPrint('getEventLogs: exception -> $e');
    }
    return data;
  }

  Future<void> getEventHistory() async {
    response.typeSetter = 'post';
    response.urlSetter = APIs.eventHistoryAPI;
    response.bodySetter = {'user_id': '${userModel.value.user?.id ?? 1}'};
    await response.hitAPI().then((value) {
      if (value.split(' ').first != 'error') {
        eventHistory.value = eventModelFromJson(value, 'list');
        update();
      } else {
        parseError(value);
      }
    });
  }

  Future<void> getGifts() async {
    response.typeSetter = 'get';
    response.urlSetter = APIs.getGiftsAPI;
    await response.hitAPI().then((value) {
      if (value.split(' ').first != 'error') {
        gifts.value = giftModelFromJson(value);
        update();
      } else {
        parseError(value);
      }
    });
  }

  Future<List<Activity>?> sendGift({
    required String eventId,
    required String giftId,
  }) async {
    List<Activity>? data;
    response.typeSetter = 'post';
    response.urlSetter = APIs.sendGiftAPI;
    response.bodySetter = {
      "event_id": eventId,
      "user_id": '${userModel.value.user?.id ?? 1}',
      "gift_id": giftId,
    };
    await response.hitAPI().then((value) {
      if (value.split(' ').first != 'error') {
        data = (jsonDecode(value)['activity'] as List)
            .map((x) => Activity.fromJson(x))
            .toList();

        // Broadcast to Zego
        try {
          final gift = gifts.value.data?.firstWhere(
            (element) => element.id.toString() == giftId,
          );
          if (gift != null) {
            ZegoUIKit().sendInRoomCommand(
              'gift:${gift.name}:${gift.image}',
              [],
            );
          }
        } catch (e) {
          myPrint('Error broadcasting gift: $e');
        }

        update();
      } else {
        parseError(value);
      }
    });
    return data;
  }

  Future<void> updateEventStatus({
    required String eventId,
    required String status,
  }) async {
    response.typeSetter = 'post';
    response.urlSetter = '${APIs.updateEventStatusAPI}/$eventId';
    response.bodySetter = {"status": status};
    await response.hitAPI().then((value) {
      if (value.split(' ').first != 'error') {
        update();
      } else {
        parseError(value, showDialog: false);
      }
    });
  }

  Future<void> reportEvent({
    required String eventId,
    required String reason,
    required String description,
  }) async {
    response.typeSetter = 'post';
    response.urlSetter = APIs.reportEventAPI;
    response.bodySetter = {
      "event_id": eventId,
      "user_id": '${userModel.value.user?.id ?? 1}',
      "reason": reason,
      "description": description,
    };
    await response.hitAPI().then((value) {
      if (value.split(' ').first != 'error') {
        update();
      } else {
        parseError(value, showDialog: false);
      }
    });
  }

  Future<void> getAbusiveWords() async {
    response.typeSetter = 'get';
    response.urlSetter = APIs.getAbusiveWordsAPI;
    await response.hitAPI().then((value) {
      if (value.split(' ').first != 'error') {
        abusiveWords.value = abusiveWordsModelFromJson(value);
        update();
      } else {
        parseError(value, doBack: false);
      }
    });
  }

  bool hasAbusiveWords(String text) {
    if (abusiveWords.value.data == null || abusiveWords.value.data!.isEmpty) {
      return false;
    }
    final lowerText = text.toLowerCase();
    // Découpe le texte en MOTS (lettres/chiffres, accents inclus) pour une
    // correspondance de mot entier -> "con" ne bloque plus "concert".
    final tokens = lowerText
        .split(RegExp(r'[^a-z0-9àâäéèêëïîôöùûüÿçœæ]+'))
        .where((t) => t.isNotEmpty)
        .toSet();
    for (var w in abusiveWords.value.data!) {
      final bad = w.word?.trim().toLowerCase();
      if (bad == null || bad.isEmpty) continue;
      if (bad.contains(' ')) {
        // Expression (ex. "ta gueule", "kill yourself") -> sous-chaîne.
        if (lowerText.contains(bad)) return true;
      } else {
        // Mot seul -> correspondance de mot entier.
        if (tokens.contains(bad)) return true;
      }
    }
    return false;
  }
}

enum EventStatus { archived, published, cancelled, completed, postponed, live }

enum EventDateStatus { today, future }
