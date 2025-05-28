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
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self
    }
    
    // Request notification permissions
    if #available(iOS 10.0, *) {
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
    } else {
      // Fallback for iOS 9
      let settings = UIUserNotificationSettings(types: [.alert, .badge, .sound], categories: nil)
      application.registerUserNotificationSettings(settings)
      application.registerForRemoteNotifications()
    }
  }
  
  // MARK: - Remote Notification Registration
  
  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
    print("✅ APNS Token received: \(tokenString)")
    
    // CRITICAL FIX: Set APNS token type based on build configuration
    #if DEBUG
    print("🔧 Setting APNS token type: SANDBOX (Development)")
    Messaging.messaging().setAPNSToken(deviceToken, type: .sandbox)
    #else
    print("🔧 Setting APNS token type: PRODUCTION (Release/TestFlight)")
    Messaging.messaging().setAPNSToken(deviceToken, type: .prod)
    #endif
    
    // Also set the token without type for fallback compatibility
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
  
  // MARK: - UNUserNotificationCenterDelegate (iOS 10+)
  
  @available(iOS 10.0, *)
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
  
  @available(iOS 10.0, *)
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    let userInfo = response.notification.request.content.userInfo
    print("👆 Notification tapped: \(userInfo)")
    
    // Handle notification tap if needed
    // You can add navigation logic here based on userInfo
    
    completionHandler()
  }
  
  // MARK: - Legacy notification handling (iOS 9)
  
  override func application(
    _ application: UIApplication,
    didReceiveRemoteNotification userInfo: [AnyHashable : Any],
    fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
  ) {
    print("📨 Legacy remote notification: \(userInfo)")
    
    // Handle the notification
    // This method is called for iOS 9 and as fallback for iOS 10+
    
    completionHandler(.newData)
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
  
  // Optional: Handle token refresh
  func messaging(_ messaging: Messaging, didRefreshRegistrationToken fcmToken: String) {
    print("🔄 FCM Token refreshed: \(fcmToken.prefix(20))...")
    
    let dataDict: [String: String] = ["token": fcmToken]
    NotificationCenter.default.post(
      name: Notification.Name("FCMToken"),
      object: nil,
      userInfo: dataDict
    )
  }
}