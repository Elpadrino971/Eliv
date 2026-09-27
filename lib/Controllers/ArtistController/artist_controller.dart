import 'dart:convert';

import 'package:artist/Global/api.dart';
import 'package:artist/Global/global.dart';
import 'package:artist/Models/artist_data_model.dart';
import 'package:artist/Models/event_model.dart';
import 'package:artist/Models/genre_model.dart';
import 'package:artist/services/api_services.dart';
import 'package:get/get.dart';

class ArtistController extends GetxController {
  final response = ApiResponse();
  Rx<GenreModel> genres = GenreModel().obs;
  Rx<EventsModel> artistEvents = EventsModel().obs;
  Rx<EventsModel> eventStats = EventsModel().obs;
  Rx<ArtistDataModel> artistData = ArtistDataModel().obs;

  Future<void> getGenres() async {
    response.typeSetter = 'get';
    response.urlSetter = APIs.getGenresAPI;
    await response.hitAPI().then((value) {
      if (value.split(' ').first != 'error') {
        genres.value = genreModelFromJson(value);
        update();
      } else {
        parseError(value);
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

  Future<void> createEvent({
    required String name,
    required String description,
    required String startDateTime,
    required String endDateTime,
    required String ticketPrice,
    required String genreId,
    required String hasLiveChat,
    required String coverImg,
    required String visualVideo,
    String replayEnabled = '1',
    String replayDurationDays = '60',
  }) async {
    myLoadingDialog();
    response.typeSetter = 'post';
    response.urlSetter = APIs.eventsAPI;
    response.bodySetter = {
      'user_id': userModel.value.user?.id.toString() ?? '1',
      'name': name,
      'description': description,
      'start_date_time': startDateTime,
      'end_date_time': endDateTime,
      'ticket_price': ticketPrice,
      'genre_id': genreId,
      'is_private': '0',
      'has_live_chat': hasLiveChat,
      'replay_enabled': replayEnabled,
      'replay_duration_days': replayDurationDays,
    };
    await response
        .hitMultipartAPI(
          coverImg,
          key: 'cover_image',
          key2: 'video_reel',
          pic2: visualVideo,
        )
        .then((value) {
          if (value.split(' ').first != 'error') {
            update();
            mySuccessDialog(
              subtitle: 'msg_event_created'.tr,
              ontap: () {
                Get.close(3);
              },
            );
          } else {
            parseError(value, doBack: true);
          }
        })
        .catchError((e) {
          myPrint('createEvent: exception -> $e');
          Get.back();
          myWarningDialog(
            title: 'common_error'.tr,
            subtitle: "Connexion impossible. Réessaie.",
          );
        });
  }

  /// Live instantané : crée un concert gratuit qui commence maintenant (titre
  /// seul, pas d'affiche ni de date à choisir) et renvoie l'event prêt à être
  /// diffusé. null si la création a échoué (message déjà affiché).
  Future<Event?> createQuickLive({required String title}) async {
    myLoadingDialog();
    final now = DateTime.now().toUtc();
    final req = ApiResponse();
    req.typeSetter = 'post';
    req.urlSetter = APIs.eventsAPI;
    req.bodySetter = {
      'name': title,
      'description': '',
      // Une minute de marge : le bouton « Lancer » des listes vérifie que
      // l'heure actuelle est dans le créneau du concert.
      'start_date_time':
          now.subtract(const Duration(minutes: 1)).toIso8601String(),
      'end_date_time': now.add(const Duration(hours: 4)).toIso8601String(),
      'ticket_price': '0',
      'is_private': '0',
      'has_live_chat': '1',
      'replay_enabled': '1',
      'replay_duration_days': '60',
    };
    try {
      final value = await req.hitMultipartAPI('');
      Get.back(); // ferme le loader
      if (value is String && value.split(' ').first != 'error') {
        final data = jsonDecode(value)['data'];
        if (data is Map<String, dynamic>) return Event.fromJson(data);
        myWarningDialog(subtitle: 'quick_live_failed'.tr);
        return null;
      }
      parseError(value, doBack: false);
      return null;
    } catch (e) {
      myPrint('createQuickLive: exception -> $e');
      Get.back();
      myWarningDialog(subtitle: 'quick_live_failed'.tr);
      return null;
    }
  }

  Future<void> getArtistData({required String artistId}) async {
    artistData.value = ArtistDataModel();
    response.typeSetter = 'post';
    response.urlSetter = APIs.getArtistDataAPI;
    response.bodySetter = {'id': artistId};
    await response.hitAPI().then((value) {
      if (value.split(' ').first != 'error') {
        artistData.value = artistDataModelFromJson(value);
        update();
      } else {
        parseError(value, doBack: false);
      }
    });
  }

  Future<void> getEventStatsByUserId() async {
    response.typeSetter = 'post';
    response.urlSetter = APIs.getEventStatsByUserIdAPI;
    response.bodySetter = {'user_id': '${userModel.value.user?.id ?? 1}'};
    await response.hitAPI().then((value) {
      if (value.split(' ').first != 'error') {
        eventStats.value = eventModelFromJson(value, 'list');
        update();
      } else {
        parseError(value, doBack: false);
      }
    });
  }
}
