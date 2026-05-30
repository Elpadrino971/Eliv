import 'dart:async';
import 'dart:io';
import 'package:artist/Global/colors.dart';
import 'package:artist/services/vybzzz_bf1200fc5027.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:artist/Global/global.dart';
import 'package:http/http.dart' as http;
import 'package:googleapis_auth/auth_io.dart' as auth;

class PushNotificationSystem {
  FirebaseMessaging messaging = FirebaseMessaging.instance;
  //initialising firebase message plugin
  final _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  Future initialingCloudMessaging() async {
    // Terminated

    // When driver app is completely closed
    messaging.getInitialMessage().then((RemoteMessage? remoteMessage) async {
      if (remoteMessage != null) {
        showNotification(remoteMessage);
      } else {
        myPrint(remoteMessage);
      }
    });

    // Foreground

    // When driver app is open
    FirebaseMessaging.onMessage.listen((RemoteMessage? remoteMessage) async {
      try {
        if (remoteMessage == null) {
          return;
        } else {
          showNotification(remoteMessage);
        }
      } catch (e) {
        myPrint(e);
      }
    });

    // Background

    // When driver app is in the background and open by the notification
    FirebaseMessaging.onMessageOpenedApp.listen((
      RemoteMessage? remoteMessage,
    ) async {
      if (remoteMessage == null) return;

      await showNotification(remoteMessage);
    });
  }

  //Access Token

  // Get and Read Access Token OAuth 2.0
  Future<String> getAccessToken() async {
    final serviceAccountJson = FirebaseAuthKeys.firebaseJson;

    List<String> scopes = [
      "https://www.googleapis.com/auth/userinfo.email",
      "https://www.googleapis.com/auth/firebase.database",
      "https://www.googleapis.com/auth/firebase.messaging",
    ];
    http.Client client = await auth.clientViaServiceAccount(
      auth.ServiceAccountCredentials.fromJson(serviceAccountJson),
      scopes,
    );
    credentials = await auth.obtainAccessCredentialsViaServiceAccount(
      auth.ServiceAccountCredentials.fromJson(serviceAccountJson),
      scopes,
      client,
    );
    // Access token and expiration time
    fcmAccessToken = credentials?.accessToken.data ?? '';
    final expiresIn = credentials?.accessToken.expiry;

    // Print access token and its expiration time
    myPrint("Access Token: $fcmAccessToken");
    myPrint("Expires In: $expiresIn");
    expiresIn!.difference(DateTime.now()).inMinutes;
    Timer.periodic(
      Duration(minutes: expiresIn.difference(DateTime.now()).inMinutes),
      (timer) async {
        credentials = await auth.obtainAccessCredentialsViaServiceAccount(
          auth.ServiceAccountCredentials.fromJson(serviceAccountJson),
          scopes,
          client,
        );
        // Access token and expiration time
        fcmAccessToken = credentials?.accessToken.data ?? '';
      },
    );

    return credentials?.accessToken.data ?? '';
  }

  // Helper function
  bool isSimulator() {
    return Platform.isIOS &&
        (Platform.environment['SIMULATOR_DEVICE_NAME'] != null);
  }

  // Get and Read FCM Notification Token..
  Future<String> generateAndGetToken() async {
    try {
      if (!Platform.isIOS || (Platform.isIOS && !isSimulator())) {
        await messaging.getAPNSToken();
      }
      String? registrationToken = await messaging.getToken();
      myPrint('FCM Token is $registrationToken');

      messaging.subscribeToTopic("vybzzz");
      messaging.subscribeToTopic("users");
      messaging.subscribeToTopic("artist");
      messaging.subscribeToTopic("00${userModel.value.user?.id}");

      return registrationToken!;
    } catch (e) {
      messaging.subscribeToTopic("vybzzz");
      messaging.subscribeToTopic("users");
      messaging.subscribeToTopic("artist");
      messaging.subscribeToTopic("00${userModel.value.user?.id}");
      return '';
    }
  }

  // permission method for granting notification permission
  Future<void> requestNotificationPermission() async {
    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      announcement: true,
      badge: true,
      carPlay: true,
      criticalAlert: true,
      provisional: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
    } else if (settings.authorizationStatus ==
        AuthorizationStatus.provisional) {
    } else {}
  }

  // function to show visible notification when app is active
  Future<void> showNotification(RemoteMessage message) async {
    // Define the Android notification details
    AndroidNotificationChannel channel = const AndroidNotificationChannel(
      '1',
      'High Importance Notifications',
      importance: Importance.max,
    );
    AndroidNotificationDetails androidNotificationDetails =
        AndroidNotificationDetails(
          channel.id.toString(),
          channel.name.toString(),
          icon: "@mipmap/ic_launcher",
          color: greyColor,
          channelDescription: 'My Channel Discription',
          importance: Importance.high,
          priority: Priority.high,
          ticker: 'ticker',
        );

    // Define the iOS notification details
    const iosNotificationDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      presentList: true,
    );

    // Combine both Android and iOS notification details
    NotificationDetails notificationDetails = NotificationDetails(
      android: androidNotificationDetails,
      iOS: iosNotificationDetails,
    );

    Future.delayed(Duration.zero, () async {
      await _flutterLocalNotificationsPlugin.show(
        id: 0,
        title: message.notification!.title.toString(),
        body: message.notification!.body.toString(),
        notificationDetails: notificationDetails,
        payload:
            message.data['message']?.toString() ??
            message.data['request']?.toString(),
      );
    });
  }

  Future<void> setup() async {
    const androidInitializationSetting = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosInitializationSetting = DarwinInitializationSettings();
    const initSettings = InitializationSettings(
      android: androidInitializationSetting,
      iOS: iosInitializationSetting,
    );
    await _flutterLocalNotificationsPlugin.initialize(settings: initSettings);
  }

  Future<void> requestIOSPermissions() async {
    await _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);

    await requestNotificationPermission();
  }

  void initLocalNotifications(RemoteMessage message) async {
    var androidInitializationSettings = const AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    var iosInitializationSettings = const DarwinInitializationSettings();

    var initializationSetting = InitializationSettings(
      android: androidInitializationSettings,
      iOS: iosInitializationSettings,
    );

    await _flutterLocalNotificationsPlugin.initialize(
      settings: initializationSetting,
      onDidReceiveNotificationResponse: (payload) {
        final value = payload.payload;
        if (value == null || value.isEmpty) return;
        if (value == 'msg') {
          // Get.to(() => MessagesPage());
        } else if (value == 'req') {
          // Get.to(() => FriendRequest());
        }
      },
    );
  }
}
