import Flutter
import UIKit
import FirebaseCore
import FirebaseMessaging
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate {

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    
    // Configure Firebase FIRST
    if FirebaseApp.app() == nil {
      FirebaseApp.configure()
    }
    
    // Register Flutter plugins
    GeneratedPluginRegistrant.register(with: self)
    
    // Setup method channel for notifications
    setupMethodChannel()
    
    // Setup notifications
    setupNotifications(application)
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  private func setupMethodChannel() {
    let controller = window?.rootViewController as! FlutterViewController
    let notificationChannel = FlutterMethodChannel(
      name: "flutter.io/notifications",
      binaryMessenger: controller.binaryMessenger
    )
    
    notificationChannel.setMethodCallHandler { [weak self] (call, result) in
      switch call.method {
      case "registerForRemoteNotifications":
        print("🚀 Method channel: registerForRemoteNotifications called")
        DispatchQueue.main.async {
          UIApplication.shared.registerForRemoteNotifications()
          print("✅ Called UIApplication.shared.registerForRemoteNotifications()")
        }
        result("success")
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
  
  private func setupNotifications(_ application: UIApplication) {
    print("🔧 Setting up notifications...")
    
    // Set messaging delegate
    Messaging.messaging().delegate = self
    
    // Set notification center delegate
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self
    }
  }
  
  // MARK: - Remote Notification Registration
  
  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
    print("✅ APNS Token received in AppDelegate: \(tokenString)")
    
    // Set APNS token type for Firebase
    #if DEBUG
    print("🔧 Setting APNS token type: SANDBOX")
    Messaging.messaging().setAPNSToken(deviceToken, type: .sandbox)
    #else
    print("🔧 Setting APNS token type: PRODUCTION")
    Messaging.messaging().setAPNSToken(deviceToken, type: .prod)
    #endif
    
    // Also set the token property
    Messaging.messaging().apnsToken = deviceToken
    
    // Call super
    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
  }
  
  override func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    print("❌ APNS Registration failed: \(error.localizedDescription)")
    
    // Detailed error logging
    let nsError = error as NSError
    print("❌ Error domain: \(nsError.domain)")
    print("❌ Error code: \(nsError.code)")
    print("❌ Error userInfo: \(nsError.userInfo)")
    
    super.application(application, didFailToRegisterForRemoteNotificationsWithError: error)
  }
  
  // MARK: - UNUserNotificationCenterDelegate
  
  @available(iOS 10.0, *)
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    if #available(iOS 14.0, *) {
      completionHandler([.banner, .list, .sound, .badge])
    } else {
      completionHandler([.alert, .sound, .badge])
    }
  }
  
  @available(iOS 10.0, *)
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    completionHandler()
  }
}

// MARK: - MessagingDelegate
extension AppDelegate: MessagingDelegate {
  func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
    print("✅ FCM Token received in AppDelegate: \(fcmToken?.prefix(20) ?? "nil")...")
    
    let dataDict: [String: String] = ["token": fcmToken ?? ""]
    NotificationCenter.default.post(
      name: Notification.Name("FCMToken"),
      object: nil,
      userInfo: dataDict
    )
  }
}