import 'dart:async';
import 'dart:convert';

import 'package:artist/Auth/login_screen.dart';
import 'package:artist/Auth/otp_screen.dart';
import 'package:artist/BottomBar/screens/my_bottom_bar.dart';
import 'package:artist/Auth/login_failed_sheet.dart';
import 'package:artist/Controllers/subscription_controller.dart';
import 'package:artist/Global/api.dart';
import 'package:artist/Models/banks_model.dart';
import 'package:artist/Models/follow_model.dart';
import 'package:artist/Models/genre_model.dart';
import 'package:artist/Models/packages_model.dart';
import 'package:artist/Models/transactions_model.dart';
import 'package:artist/Models/user_model.dart';
import 'package:artist/Auth/complete_profile.dart';
import 'package:artist/Auth/create_passwrod.dart';
import 'package:artist/Global/global.dart';
import 'package:artist/artist_bottom_bar/artist_bottom_bar.dart';
import 'package:artist/services/api_services.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:get/get.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthController extends GetxController {
  final response = ApiResponse();
  Rx<GenreModel> genres = GenreModel().obs;
  Rx<PackagesModel> packages = PackagesModel().obs;
  Rx<TransactionsModel> transactions = TransactionsModel().obs;
  Rx<TransactionsModel> ticketsDataHistory = TransactionsModel().obs;
  Rx<FollowModel> followingArtists = FollowModel().obs;
  Rx<BanksModel> banks = BanksModel().obs;
  RxMap settings = {}.obs;

  Future loginUser({required String email, required String password}) async {
    myLoadingDialog();
    response.typeSetter = 'post';
    response.urlSetter = APIs.loginAPI;
    response.bodySetter = {'email': email, 'password': password};
    final String value;
    try {
      value = await response.hitAPI();
    } catch (_) {
      // Pas de réseau / serveur injoignable : on ferme le loader et on
      // l'explique doucement, au lieu de laisser le loader tourner.
      Get.back();
      await showLoginFailedSheet(code: 'network', email: email);
      return;
    }
    if (value.split(' ').first != 'error') {
      userModel.value = userModelFromJson(value);
      update();
      if (userModel.value.user?.status == 'pending') {
        Get.offAll(() => OtpScreen(email: email));
      } else {
        box.write('user', userModel.value.toJson());
        final id = userModel.value.user?.id;
        if (id != null) unawaited(SubscriptionController.syncIdentity(id));
        // Après connexion : direct sur le Live + Feed (index 2), comme à l'ouverture.
        Get.offAll(() => MyBottomBar(index: 2));
      }
      Get.back();
    } else {
      // Échec de connexion : feuille d'aide (créer un compte / mot de passe
      // oublié) au lieu du dialogue "Warning" bloquant.
      Get.back();
      await showLoginFailedSheet(code: _errorCode(value), email: email);
    }
  }

  /// Extrait le champ `code` d'une réponse d'erreur `error {json}`.
  static String? _errorCode(String value) {
    try {
      final data = jsonDecode(value.split('error ').last);
      if (data is Map && data['code'] != null) return data['code'].toString();
    } catch (_) {}
    return null;
  }

  Future socialLogin({
    required String email,
    required String name,
    String? phone,
    String? idToken, // Google id_token
    String? identityToken, // Apple identity_token
    String provider = 'google',
  }) async {
    myLoadingDialog();
    response.typeSetter = 'post';
    response.urlSetter = APIs.socialLoginAPI;
    response.bodySetter = {
      "registration_type": provider,
      "provider": provider,
      "email": email,
      "full_name": name,
      "phone_number": ?phone,
      "id_token": ?idToken,
      "identity_token": ?identityToken,
    };
    await response.hitAPI().then((value) {
      if (value.split(' ').first != 'error') {
        userModel.value = userModelFromJson(value);
        box.write('user', userModel.value.toJson());
        final id = userModel.value.user?.id;
        if (id != null) unawaited(SubscriptionController.syncIdentity(id));
        update();
        Get.back();
        // Après connexion : direct sur le Live + Feed (index 2), comme à l'ouverture.
        Get.offAll(() => MyBottomBar(index: 2));
      } else {
        parseError(value, doBack: true);
      }
    });
  }

  Future signupUser({
    required String email,
    required String password,
    required String name,
  }) async {
    myLoadingDialog();
    response.typeSetter = 'post';
    response.urlSetter = APIs.signupAPI;
    response.bodySetter = {
      'email': email,
      'password': password,
      'full_name': name,
      'registration_type': 'email',
    };
    await response.hitAPI().then((value) {
      if (value.split(' ').first != 'error') {
        userModel.value = userModelFromJson(value);
        update();
        Get.back();
        Get.off(() => OtpScreen(email: email));
      } else {
        parseError(value, doBack: true);
      }
    });
  }

  Future verifyOtp({
    required String email,
    required String otp,
    bool fromForget = false,
  }) async {
    myLoadingDialog();
    response.typeSetter = 'post';
    response.urlSetter = APIs.verifyOtpAPI;
    response.bodySetter = {'email': email, 'otp_code': otp};
    await response.hitAPI().then((value) {
      if (value.split(' ').first != 'error') {
        userModel.value = userModelFromJson(value);
        update();
        Get.back();
        mySuccessDialog(
          subtitle: 'Otp Verified Successfully',
          ontap: () async {
            if (fromForget) {
              Get.to(() => CreatePasswrod(fromForget: true, email: email));
            } else {
              box.write('user', userModel.value.toJson());
              final id = userModel.value.user?.id;
              if (id != null) {
                unawaited(SubscriptionController.syncIdentity(id));
              }
              Get.to(() => CompleteProfile());
            }
          },
        );
      } else {
        parseError(value, doBack: true);
      }
    });
  }

  Future forgetPassword({required String email, bool froResent = false}) async {
    myLoadingDialog();
    response.typeSetter = 'post';
    response.urlSetter = APIs.forgetPasswordAPI;
    response.bodySetter = {'email': email};
    await response.hitAPI().then((value) {
      if (value.split(' ').first != 'error') {
        userModel.value = userModelFromJson(value);
        update();
        Get.back();
        froResent
            ? null
            : Get.off(() => OtpScreen(fromForget: true, email: email));
      } else {
        parseError(value, doBack: true);
      }
    });
  }

  Future resetPassword({
    required String password,
    required String email,
  }) async {
    myLoadingDialog();
    response.typeSetter = 'post';
    response.urlSetter = APIs.resetPasswordAPI;
    response.bodySetter = {
      'new_password': password,
      "confirm_password": password,
      'email': email,
    };
    await response.hitAPI().then((value) {
      if (value.split(' ').first != 'error') {
        userModel.value = userModelFromJson(value);
        update();
        mySuccessDialog(
          subtitle: 'Password Reset Successfully',
          ontap: () {
            Get.offAll(() => LoginScreen());
          },
        );
      } else {
        parseError(value, doBack: true);
      }
    });
  }

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

  Future<void> updateProfile({
    String? name,
    String? about,
    String? artistBio,
    String? birthDate,
    String? gender,
    String? phoneNumber,
    String? primaryGenre,
    List? genres,
    List? platform,
    List? urls,
    String? location,
    String? lat,
    String? lng,
    String? experience,
    String? artistName,
    String? artistProfile,
    String? profilePicture,
    String? artistNumber,
    String? accountHolderName,
    String? bankName,
    String? accountNumber,
    String? swiftNumber,
    String? routingNumber,
    // Liens en bio (contact + réseaux).
    String? contactEmail,
    String? linkWebsite,
    String? linkInstagram,
    String? linkTiktok,
    String? linkYoutube,
    String? linkSpotify,
    bool fromEdit = false,
    bool formArtist = false,
  }) async {
    myLoadingDialog();
    response.typeSetter = 'post';
    response.urlSetter = APIs.updateProfileAPI;
    response.bodySetter = {
      'id': '${userModel.value.user?.id ?? ''}',
      'full_name': ?name,
      'bio': ?about,
      'dob': ?birthDate,
      'gender': ?gender,
      'phone_number': ?phoneNumber,
      'address': ?location,
      'latitude': ?lat,
      'longitude': ?lng,
      'artist_name': ?artistName,
      "artist_number": ?artistNumber,
      "account_holder_name": ?accountHolderName,
      "bank_name": ?bankName,
      "account_number": ?accountNumber,
      "swift_number": ?swiftNumber,
      "routing_number": ?routingNumber,
      "artist_bio": ?artistBio,
      'contact_email': ?contactEmail,
      'link_website': ?linkWebsite,
      'link_instagram': ?linkInstagram,
      'link_tiktok': ?linkTiktok,
      'link_youtube': ?linkYoutube,
      'link_spotify': ?linkSpotify,
      'experience': ?experience,
      if (primaryGenre != null) "primary_genre": jsonEncode([primaryGenre]),
      if (genres != null) 'genre_ids': jsonEncode(genres),
      if (platform != null) 'platform[]': jsonEncode(platform),
      if (urls != null) 'url[]': jsonEncode(urls),
    };
    await response
        .hitMultipartAPI(
          profilePicture ?? '',
          key: 'profile_image',
          pic2: artistProfile ?? '',
          key2: 'artist_profile',
        )
        .then((value) {
          if (value.split(' ').first != 'error') {
            final user = userModelFromJson(value);
            userModel.value = userModel.value.copyWith(user: user.user);
            update();
            box.write('user', userModel.value.toJson());
            mySuccessDialog(
              subtitle: 'Profile Updated Successfully',
              ontap: () {
                (fromEdit)
                    ? Get.close(2)
                    : (formArtist)
                    ? mySuccessDialog(
                        subtitle: 'Profile Updated Successfully',
                        ontap: () {
                          Get.offAll(() => ArtistBottomBar());
                        },
                      )
                    : Get.offAll(() => MyBottomBar());
              },
            );
          } else {
            parseError(value, doBack: true);
          }
        });
  }

  Future<void> getUserModel() async {
    response.typeSetter = 'post';
    response.urlSetter = APIs.getUserAPI;
    response.bodySetter = {'id': '${userModel.value.user?.id ?? ''}'};
    await response.hitAPI().then((value) {
      if (value.split(' ').first != 'error') {
        final data = userModelFromJson(value);
        userModel.value = userModel.value.copyWith(user: data.user);
        box.write('user', userModel.value.toJson());
        update();
      } else {
        parseError(value);
      }
    });
  }

  Future<void> getPackages() async {
    response.typeSetter = 'get';
    response.urlSetter = APIs.getPackagesAPI;
    await response.hitAPI().then((value) {
      if (value.split(' ').first != 'error') {
        packages.value = packagesModelFromJson(value);
        update();
      } else {
        parseError(value);
      }
    });
  }

  Future<void> purchasePackage({required String packageId}) async {
    myLoadingDialog();
    response.typeSetter = 'post';
    response.urlSetter = APIs.purchasePackageAPI;
    response.bodySetter = {
      'package_id': packageId,
      "user_id": "${userModel.value.user?.id ?? 1}",
    };
    await response.hitAPI().then((value) {
      if (value.split(' ').first != 'error') {
        final data = userModelFromJson(value);
        userModel.value = userModel.value.copyWith(user: data.user);
        box.write('user', userModel.value.toJson());
        update();
        mySuccessDialog(
          subtitle: 'Package Purchased Successfully',
          ontap: () {
            Get.close(2);
          },
        );
      } else {
        parseError(value, doBack: true);
      }
    });
  }

  Future<void> getTransaction({String? key}) async {
    response.typeSetter = 'post';
    response.urlSetter = APIs.getTransactionAPI;
    response.bodySetter = {
      "role": key ?? "points",
      "user_id": "${userModel.value.user?.id ?? 1}",
    };
    await response.hitAPI().then((value) {
      if (value.split(' ').first != 'error') {
        if (key == null) {
          transactions.value = transactionsModelFromJson(value);
        } else {
          ticketsDataHistory.value = transactionsModelFromJson(value);
        }
        update();
      } else {
        parseError(value);
      }
    });
  }

  Future<void> getFollowingArtists() async {
    response.typeSetter = 'post';
    response.urlSetter = APIs.getFollowingArtistsAPI;
    response.bodySetter = {"user_id": "${userModel.value.user?.id ?? 1}"};
    await response.hitAPI().then((value) {
      if (value.split(' ').first != 'error') {
        followingArtists.value = followModelFromJson(value, 'following');
        update();
      } else {
        parseError(value);
      }
    });
  }

  Future<void> addBank({
    required String accountHolderName,
    required String bankName,
    required String accountNumber,
    required String swiftNumber,
    required String routingNumber,
  }) async {
    myLoadingDialog();
    response.typeSetter = 'post';
    response.urlSetter = APIs.addBankAPI;
    response.bodySetter = {
      "user_id": "${userModel.value.user?.id ?? 1}",
      "bank_name": bankName,
      "account_number": accountNumber,
      "account_name": accountHolderName,
      "swift_code": swiftNumber,
      "routing_number": routingNumber,
    };
    await response.hitAPI().then((value) {
      if (value.split(' ').first != 'error') {
        banks.value = banksModelFromJson(value);
        update();
        mySuccessDialog(
          subtitle: 'Bank Added Successfully',
          ontap: () {
            Get.close(3);
          },
        );
      } else {
        parseError(value, doBack: true);
      }
    });
  }

  Future<void> getBank() async {
    response.typeSetter = 'post';
    response.urlSetter = APIs.getBankAPI;
    response.bodySetter = {"user_id": "${userModel.value.user?.id ?? 1}"};
    await response.hitAPI().then((value) {
      if (value.split(' ').first != 'error') {
        banks.value = banksModelFromJson(value);
        update();
      } else {
        parseError(value);
      }
    });
  }

  Future<void> deleteBank({required String bankId}) async {
    myLoadingDialog();
    response.typeSetter = 'post';
    response.urlSetter = APIs.deleteBankAPI;
    response.bodySetter = {"bank_id": bankId};
    await response.hitAPI().then((value) {
      if (value.split(' ').first != 'error') {
        banks.value = banksModelFromJson(value);
        update();
        mySuccessDialog(
          subtitle: 'Bank account deleted successfully',
          ontap: () {
            Get.close(2); // close success dialog
          },
        );
      } else {
        parseError(value, doBack: true);
      }
    });
  }

  Future<void> withdraw({
    required String bankId,
    required String amount,
  }) async {
    myLoadingDialog();
    response.typeSetter = 'post';
    response.urlSetter = APIs.withdrawAPI;
    response.bodySetter = {
      "user_id": "${userModel.value.user?.id ?? 1}",
      "bank_id": bankId,
      "amount": amount,
    };
    await response.hitAPI().then((value) {
      if (value.split(' ').first != 'error') {
        mySuccessDialog(
          subtitle: 'Withdraw Request Sent Successfully',
          ontap: () {
            Get.close(2);
          },
        );
      } else {
        parseError(value, doBack: true);
      }
    });
  }

  Future<void> getSettings() async {
    response.typeSetter = 'get';
    response.urlSetter = APIs.getSettingsAPI;
    await response.hitAPI().then((value) {
      if (value.split(' ').first != 'error') {
        settings.value = jsonDecode(value)["data"] ?? {};
        update();
      } else {
        parseError(value);
      }
    });
  }

  // Déconnexion complète (déplacée depuis l'écran Profil vers ⚙ Réglages).
  Future<void> logout() async {
    myLoadingDialog();
    try {
      final id = userModel.value.user?.id;
      await FirebaseMessaging.instance.unsubscribeFromTopic('00$id');
      await FirebaseMessaging.instance.unsubscribeFromTopic('users');
      await FirebaseMessaging.instance.unsubscribeFromTopic('artist');
      if (userModel.value.user?.registrationType == 'social') {
        await GoogleSignIn.instance.signOut();
      }
      await SubscriptionController.clearIdentity();
      await box.remove('user');
    } catch (_) {}
    await Future.delayed(const Duration(seconds: 1));
    Get.offAll(() => LoginScreen());
  }

  Future<void> deleteAccount() async {
    myLoadingDialog();
    response.typeSetter = 'post';
    response.urlSetter = APIs.deleteAccountAPI;
    response.bodySetter = {"id": "${userModel.value.user?.id ?? 1}"};
    await response.hitAPI().then((value) {
      if (value.split(' ').first != 'error') {
        mySuccessDialog(
          subtitle: 'Account Deleted Successfully',
          ontap: () {
            Get.offAll(() => LoginScreen());
          },
        );
      } else {
        parseError(value, doBack: true);
      }
    });
  }
}
