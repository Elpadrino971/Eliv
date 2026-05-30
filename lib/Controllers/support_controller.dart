import 'dart:convert';

import 'package:artist/Global/api.dart';
import 'package:artist/Global/global.dart';
import 'package:artist/Models/support_model.dart';
import 'package:artist/services/api_services.dart';
import 'package:get/get.dart';

class SupportController extends GetxController {
  final response = ApiResponse();
  Rx<SupportModel> supportList = SupportModel().obs;
  RxMap? supportSubjects;

  Future<void> getSupportList() async {
    response.urlSetter = APIs.supportListAPI;
    response.typeSetter = 'post';
    response.bodySetter = {"user_id": '${userModel.value.user?.id ?? '35'}'};
    await response.hitAPI().then((value) {
      if (value.split(' ').first != 'error') {
        supportList.value = supportModelFromJson(value);
        update();
      } else {
        parseError(value, showDialog: false);
      }
    });
  }

  Future<Support> getSupportDetails(String id) async {
    Support support = Support();
    response.urlSetter = APIs.supportDetailsAPI;
    response.typeSetter = 'post';
    response.bodySetter = {"ticket_id": id};
    await response.hitAPI().then((value) {
      if (value.split(' ').first != 'error') {
        final data = jsonDecode(value)['data'];
        support = Support.fromJson(data);
        update();
      } else {
        parseError(value, showDialog: false);
      }
    });
    return support;
  }

  Future<void> createSupport(String subject, String message) async {
    response.urlSetter = APIs.supportCreateAPI;
    response.typeSetter = 'post';
    response.bodySetter = {
      "user_id": '${userModel.value.user?.id ?? '35'}',
      "subject": subject,
      "priority": "high",
      "description": message,
    };
    await response.hitAPI().then((value) {
      if (value.split(' ').first != 'error') {
        supportList.value = supportModelFromJson(value);
        update();
      } else {
        parseError(value, showDialog: false);
      }
    });
  }

  Future<Support> resolveSupport({
    required String id,
    required String rating,
    required String review,
  }) async {
    Support support = Support();
    response.urlSetter = APIs.supportResolveAPI;
    response.typeSetter = 'post';
    response.bodySetter = {"ticket_id": id, "rating": rating, "review": review};
    await response.hitAPI().then((value) {
      if (value.split(' ').first != 'error') {
        final data = jsonDecode(value)['data'];
        support = Support.fromJson(data);
        update();
      } else {
        parseError(value, showDialog: false);
      }
    });
    return support;
  }

  Future<void> getSupportSubjects() async {
    response.urlSetter = APIs.supportSubjectsAPI;
    response.typeSetter = 'post';
    response.bodySetter = {"role": "support"};
    await response.hitAPI().then((value) {
      if (value.split(' ').first != 'error') {
        Map data = jsonDecode(value) as Map;
        supportSubjects = data.obs;
        update();
      } else {
        parseError(value, showDialog: false);
      }
    });
  }

  Future<Support> storeSupportMeta(
    String ticketId,
    String role,
    String value,
  ) async {
    Support support = Support();
    response.urlSetter = APIs.supportStoreMetaAPI;
    response.typeSetter = 'post';
    response.bodySetter = {
      "user_id": '${userModel.value.user?.id ?? '35'}',
      "ticket_id": ticketId,
      "role": role,
      "value": value,
    };
    await response.hitAPI().then((value) {
      if (value.split(' ').first != 'error') {
        final data = jsonDecode(value)['data'];
        support = Support.fromJson(data);
        update();
      } else {
        parseError(value, showDialog: false);
      }
    });
    return support;
  }
}
