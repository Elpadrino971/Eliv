import Flutter
import UIKit
import AVKit
import FirebaseCore
import UserNotifications
import FirebaseMessaging

@main
@objc class AppDelegate: FlutterAppDelegate, MessagingDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Set up push notifications
    UNUserNotificationCenter.current().delegate = self
    application.registerForRemoteNotifications()

    // Set up Firebase Messaging delegate
    Messaging.messaging().delegate = self

    GeneratedPluginRegistrant.register(with: self)

    // CAST / AirPlay : enregistre le bouton AirPlay natif exposé à Flutter
    // (UiKitView 'vybzzz/airplay_button' -> voir lib/widgets/cast_button.dart).
    if let registrar = self.registrar(forPlugin: "AirPlayRoutePicker") {
      registrar.register(AirPlayRoutePickerFactory(), withId: "vybzzz/airplay_button")
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }

   // MARK: - Firebase Messaging delegate
  func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
    print("Firebase registration token: \(String(describing: fcmToken))")
  }
}

// MARK: - Cast / AirPlay (PlatformView natif)

/// Fabrique le bouton AirPlay natif pour Flutter.
class AirPlayRoutePickerFactory: NSObject, FlutterPlatformViewFactory {
  func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) -> FlutterPlatformView {
    return AirPlayRoutePicker(frame: frame)
  }
}

/// Enveloppe `AVRoutePickerView` : au tap, iOS ouvre le sélecteur AirPlay et
/// diffuse le flux vidéo HLS (Mux) en cours sur l'Apple TV / TV compatible.
class AirPlayRoutePicker: NSObject, FlutterPlatformView {
  private let picker: AVRoutePickerView

  init(frame: CGRect) {
    picker = AVRoutePickerView(frame: frame)
    picker.backgroundColor = .clear
    picker.activeTintColor = UIColor(red: 0.847, green: 0.706, blue: 0.353, alpha: 1.0) // or VYBZZZ
    picker.tintColor = .white
    if #available(iOS 13.0, *) {
      picker.prioritizesVideoDevices = true // privilégie les destinations vidéo (Apple TV)
    }
    super.init()
  }

  func view() -> UIView {
    return picker
  }
}
