import 'dart:io';
import 'package:artist/Global/colors.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:artist/Global/global.dart';

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
    // Pas de `criticalAlert` : cette option exige un droit spécial d'Apple
    // (Critical Alerts entitlement) que l'app n'a pas.
    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      announcement: true,
      badge: true,
      carPlay: true,
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
    // Message « données seules » (sans bloc notification) : rien à afficher.
    // Avant, `message.notification!` plantait sur ce type de message.
    final notification = message.notification;
    if (notification == null) return;
    final title = notification.title ?? 'VybzzZ';
    final body = notification.body ?? '';

    // Define the Android notification details
    AndroidNotificationChannel channel = const AndroidNotificationChannel(
      '1',
      'Notifications VybzzZ',
      importance: Importance.max,
    );
    AndroidNotificationDetails androidNotificationDetails =
        AndroidNotificationDetails(
          channel.id.toString(),
          channel.name.toString(),
          icon: "@mipmap/ic_launcher",
          color: greyColor,
          channelDescription: 'Notifications VybzzZ',
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
        title: title,
        body: body,
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
