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
    
    // Setup notifications AFTER Firebase and Flutter
    setupNotifications(application)
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  private func setupNotifications(_ application: UIApplication) {
    // Set messaging delegate
    Messaging.messaging().delegate = self
    
    // Set notification center delegate
    UNUserNotificationCenter.current().delegate = self
    
    // Configure foreground presentation options
    Messaging.messaging().setForegroundNotificationPresentationOptions(
      [.alert, .badge, .sound]
    )
    
    // Request notification permissions
    UNUserNotificationCenter.current().requestAuthorization(
      options: [.alert, .badge, .sound]
    ) { granted, error in
      print("Notification permission granted: \(granted)")
      if let error = error {
        print("Notification permission error: \(error)")
      }
      
      DispatchQueue.main.async {
        application.registerForRemoteNotifications()
      }
    }
  }
  
  // MARK: - Remote Notification Registration
  
  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    print("✅ APNS Token received: \(deviceToken.map { String(format: "%02.2hhx", $0) }.joined())")
    
    // CRITICAL FIX: Set APNS token type based on build configuration
    #if DEBUG
    print("🔧 Setting APNS token type: SANDBOX (Development)")
    Messaging.messaging().setAPNSToken(deviceToken, type: .sandbox)
    #else
    print("🔧 Setting APNS token type: PRODUCTION (Release/TestFlight)")
    Messaging.messaging().setAPNSToken(deviceToken, type: .prod)
    #endif
    
    // Also set the token without type for fallback
    Messaging.messaging().apnsToken = deviceToken
    
    // Call super to ensure Flutter plugins get the token
    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
  }
  
  override func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    print("❌ Failed to register for remote notifications: \(error.localizedDescription)")
    super.application(application, didFailToRegisterForRemoteNotificationsWithError: error)
  }
  
  // MARK: - UNUserNotificationCenterDelegate
  
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    let userInfo = notification.request.content.userInfo
    print("📨 Foreground notification: \(userInfo)")
    
    // Show notification in foreground
    if #available(iOS 14.0, *) {
      completionHandler([.banner, .list, .sound, .badge])
    } else {
      completionHandler([.alert, .sound, .badge])
    }
  }
  
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    let userInfo = response.notification.request.content.userInfo
    print("👆 Notification tapped: \(userInfo)")
    completionHandler()
  }
}

// MARK: - MessagingDelegate
extension AppDelegate: MessagingDelegate {
  func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
    print("✅ FCM Token received: \(fcmToken?.prefix(20) ?? "nil")...")
    
    let dataDict: [String: String] = ["token": fcmToken ?? ""]
    NotificationCenter.default.post(
      name: Notification.Name("FCMToken"),
      object: nil,
      userInfo: dataDict
    )
  }
}