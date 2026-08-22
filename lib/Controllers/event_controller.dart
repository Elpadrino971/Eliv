import 'dart:convert';

import 'package:artist/Global/api.dart';
import 'package:artist/Global/global.dart';
import 'package:artist/Models/abusive_words_model.dart';
import 'package:artist/Models/artist_clips_model.dart';
import 'package:artist/Models/event_model.dart';
import 'package:artist/Models/follow_model.dart';
import 'package:artist/Models/gift_model.dart';
import 'package:artist/Models/user_model.dart';
import 'package:artist/services/api_services.dart';
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

  /// Video Player Variables
  Rxn<VideoPlayerController> currentController = Rxn<VideoPlayerController>();
  var isMuted = false.obs;
  var currentVideoIndex = 0.obs;
  var showVideoControls = false.obs;

  void initVideoPlayer(String videoUrl) {
    currentController.value?.dispose();
    currentController.value = null;

    // Accepte une URL complete (HLS Mux : https://stream.mux.com/<id>.m3u8)
    // ou un simple nom de fichier sur le backend.
    final uri = videoUrl.startsWith('http')
        ? Uri.parse(videoUrl)
        : Uri.parse('${APIs.eventVideoIP}/$videoUrl');
    final controller =
        VideoPlayerController.networkUrl(uri)
          ..initialize().then((_) {
            update();
          });
    controller.setLooping(true);
    controller.setVolume(isMuted.value ? 0 : 1);
    currentController.value = controller;
    controller.play();
    update();
  }

  void onPageChanged(int index) {
    currentVideoIndex.value = index;
    final ids = forYouClipUrls;
    String? url;
    if (ids.isNotEmpty) {
      url = ids[index % ids.length];
    } else {
      final reel = allEvents.value.data?[index]?.videoReel;
      url = (reel != null && reel.isNotEmpty) ? reel : null;
    }
    if (url != null) {
      initVideoPlayer(url);
    } else {
      currentController.value?.dispose();
      currentController.value = null;
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

  Future<List<String>> _fetchFeedClipUrls(String feed) async {
    response.typeSetter = 'get';
    response.urlSetter = '${APIs.feedClipsAPI}?feed=$feed';
    final value = await response.hitAPI();
    if (value == null || value.toString().split(' ').first == 'error') {
      return [];
    }
    final decoded = jsonDecode(value) as Map<String, dynamic>;
    final list = (decoded['list'] as List?) ?? [];
    return list
        .map((x) => x['video_url']?.toString())
        .where((u) => u != null && u.isNotEmpty)
        .map((u) => u!)
        .toList();
  }

  Future<void> loadFeedClips() async {
    forYouClipUrls.value = await _fetchFeedClipUrls('for_you');
    clipsFeedUrls.value = await _fetchFeedClipUrls('clips');
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

  void disposeVideoController() {
    currentController.value?.dispose();
    currentController.value = null;
  }

  Future<void> getEventsByStatus({
    EventStatus status = EventStatus.published,
    EventDateStatus? dateStatus,
    List? genres,
  }) async {
    response.typeSetter = 'get';
    response.urlSetter =
        '${APIs.eventsAPI}?status=${status.name}&day=${dateStatus?.name ?? ''}&genre_ids=${genres?.join(',') ?? '[]'}';
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
        update();
      } else {
        parseError(value, doBack: false);
      }
    });
  }

  Future<void> getBannerEvents() async {
    response.typeSetter = 'get';
    response.urlSetter = APIs.getBannerEventsAPI;
    await response.hitAPI().then((value) {
      if (value.split(' ').first != 'error') {
        bannerEvents.value = eventModelFromJson(value);
        update();
      } else {
        parseError(value, doBack: false);
      }
    });
  }

  Future<void> getFeaturedArtists() async {
    response.typeSetter = 'get';
    response.urlSetter = APIs.featuredArtistAPI;
    await response.hitAPI().then((value) {
      if (value.split(' ').first != 'error') {
        List data = jsonDecode(value)['data'];
        featuredArtists.value = data.map((e) => User.fromJson(e)).toList();
        update();
      } else {
        parseError(value, doBack: false);
      }
    });
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

  Future<Event?> buyTicket({required String eventId}) async {
    Event? event;
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
    await response.hitAPI().then((value) {
      if (value.split(' ').first != 'error') {
        event = Event.fromJson(jsonDecode(value)['data']);

        update();
        mySuccessDialog(
          subtitle: 'Ticket booked successfully',
          ontap: () {
            Get.back();
            Get.back();
            Get.back(result: event);
          },
        );
      } else {
        parseError(value, doBack: true);
      }
    });
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
  Future<Event?> registerTicketAndGet(String eventId) async {
    Event? event;
    response.typeSetter = 'post';
    response.urlSetter = APIs.buyTicketAPI;
    final countryCode = Get.deviceLocale?.countryCode ?? '';
    response.bodySetter = {
      "event_id": eventId,
      "user_id": "${userModel.value.user?.id ?? 1}",
      "country_code": countryCode,
    };
    await response.hitAPI().then((value) {
      if (value.split(' ').first != 'error') {
        event = Event.fromJson(jsonDecode(value)['data']);
        update();
      } else {
        parseError(value);
      }
    });
    return event;
  }

  Future<void> getUserJoinedEvents() async {
    response.typeSetter = 'post';
    response.urlSetter = APIs.userEventHistoryAPI;
    response.bodySetter = {"user_id": "${userModel.value.user?.id ?? 1}"};
    await response.hitAPI().then((value) {
      if (value.split(' ').first != 'error') {
        userJoinedEvents.value = eventModelFromJson(value, 'list');
        update();
      } else {
        parseError(value, doBack: false);
      }
    });
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

  Future<List<Activity>?> getEventLogs({required String eventId}) async {
    List<Activity>? data;
    response.typeSetter = 'post';
    response.urlSetter = APIs.eventLogsAPI;
    response.bodySetter = {'event_id': eventId};
    await response.hitAPI().then((value) {
      if (value.split(' ').first != 'error') {
        data = (jsonDecode(value)['activity'] as List)
            .map((x) => Activity.fromJson(x))
            .toList();
        update();
      } else {
        parseError(value);
      }
    });
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
