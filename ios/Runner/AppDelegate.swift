import Flutter
import UIKit
import AVKit
import FirebaseCore
import UserNotifications
import FirebaseMessaging

@main
@objc class AppDelegate: FlutterAppDelegate, MessagingDelegate {
  /// Orientations autorisées à l'instant T. L'app est portrait par défaut ;
  /// le lecteur de clip la passe en paysage le temps de la lecture.
  var orientationLock: UIInterfaceOrientationMask = .portrait

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

    // Rotation forcée (clips paysage) — canal 'vybzzz/orientation'.
    // Sur iOS 16+, SystemChrome.setPreferredOrientations ne pivote plus l'UI ;
    // on force la géométrie nativement ici (voir lib/Global/orientation_helper.dart).
    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(
        name: "vybzzz/orientation",
        binaryMessenger: controller.binaryMessenger)
      channel.setMethodCallHandler { [weak self] call, result in
        guard let self = self else { result(nil); return }
        switch call.method {
        case "landscape":
          self.applyOrientation(.landscapeRight, mask: .landscape)
        case "portrait":
          self.applyOrientation(.portrait, mask: .portrait)
        default:
          result(FlutterMethodNotImplemented)
          return
        }
        result(nil)
      }
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  /// Verrouille l'orientation supportée puis demande la bascule réelle.
  private func applyOrientation(_ orientation: UIInterfaceOrientation, mask: UIInterfaceOrientationMask) {
    orientationLock = mask
    if #available(iOS 16.0, *) {
      window?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
      let scene = UIApplication.shared.connectedScenes.first { $0 is UIWindowScene } as? UIWindowScene
      let prefs = UIWindowScene.GeometryPreferences.iOS(interfaceOrientations: mask)
      scene?.requestGeometryUpdate(prefs) { _ in }
    } else {
      UIDevice.current.setValue(orientation.rawValue, forKey: "orientation")
      UIViewController.attemptRotationToDeviceOrientation()
    }
  }

  /// iOS consulte cette méthode pour connaître les orientations autorisées.
  override func application(
    _ application: UIApplication,
    supportedInterfaceOrientationsFor window: UIWindow?
  ) -> UIInterfaceOrientationMask {
    return orientationLock
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
