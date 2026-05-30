import 'package:artist/Global/api.dart';
import 'package:artist/Global/global.dart';
import 'package:artist/Models/management_model.dart';
import 'package:artist/services/api_services.dart';
import 'package:get/get.dart';

class SettingController extends GetxController {
  final response = ApiResponse();

  Rx<ManagementModel> management = ManagementModel().obs;

  Future<void> getManagement() async {
    response.urlSetter = APIs.getManagementAPI;
    response.typeSetter = 'post';
    response.bodySetter = {"role": "FAQ"};
    await response.hitAPI().then((value) {
      if (value.split(' ').first != 'error') {
        management.value = managementModelFromJson(value);
        update();
      } else {
        parseError(value, showDialog: false);
      }
    });
  }
}
