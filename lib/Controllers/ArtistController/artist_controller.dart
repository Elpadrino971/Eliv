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
              subtitle: 'Event created successfully',
              ontap: () {
                Get.close(3);
              },
            );
          } else {
            parseError(value, doBack: true);
          }
        });
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
