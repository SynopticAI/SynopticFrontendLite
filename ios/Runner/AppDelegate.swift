// ios/Runner/AppDelegate.swift
import Flutter
import UIKit
import FirebaseCore
import FirebaseMessaging
import UserNotifications // Ensure UserNotifications is imported

@main
@objc class AppDelegate: FlutterAppDelegate { // Removed explicit conformance to UNUserNotificationCenterDelegate here

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Configure Firebase
    // Make sure this runs first and only once
    if FirebaseApp.app() == nil {
      FirebaseApp.configure()
    }
    
    // Set up Firebase Messaging delegate
    Messaging.messaging().delegate = self
    
    // Register for remote notifications and set UNUserNotificationCenter delegate
    if #available(iOS 10.0, *) {
      // Set 'self' as the delegate for UNUserNotificationCenter
      UNUserNotificationCenter.current().delegate = self // 'self' (AppDelegate) will handle notification callbacks
      
      let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
      UNUserNotificationCenter.current().requestAuthorization(
        options: authOptions,
        completionHandler: { _, _ in }
      )
    } else {
      // Fallback for iOS versions older than 10
      let settings: UIUserNotificationSettings =
        UIUserNotificationSettings(types: [.alert, .badge, .sound], categories: nil)
      application.registerUserNotificationSettings(settings)
    }
    
    application.registerForRemoteNotifications()
    
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  // MARK: - Remote Notification Registration Callbacks
  
  override func application(_ application: UIApplication,
                           didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    Messaging.messaging().apnsToken = deviceToken
    // Forward the call to super if FlutterAppDelegate or other plugins need to handle it.
    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
  }
  
  override func application(_ application: UIApplication,
                           didFailToRegisterForRemoteNotificationsWithError error: Error) {
    print("Failed to register for remote notifications: \(error.localizedDescription)")
    // Forward the call to super if FlutterAppDelegate or other plugins need to handle it.
    super.application(application, didFailToRegisterForRemoteNotificationsWithError: error)
  }
  
  // MARK: - UNUserNotificationCenterDelegate Methods
  // These methods are now part of the AppDelegate class and marked with 'override'.

  // Handle incoming notification when the app is in the foreground.
  // This method needs to be marked with @available(iOS 10.0, *) if not already covered by class availability.
  @available(iOS 10.0, *)
  override func userNotificationCenter(_ center: UNUserNotificationCenter,
                              willPresent notification: UNNotification,
                              withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
    let userInfo = notification.request.content.userInfo
    print("Will present notification: \(userInfo)")
    
    // Show the notification with banner, sound, and badge.
    // Conditionally use .banner for iOS 14+
    if #available(iOS 14.0, *) {
      completionHandler([.banner, .list, .sound, .badge]) // .list can be useful too
    } else {
      completionHandler([.alert, .sound, .badge]) // Fallback for iOS < 14
    }
  }
  
  // Handle user interaction with the notification (e.g., tapping on it).
  // This method needs to be marked with @available(iOS 10.0, *) if not already covered by class availability.
  @available(iOS 10.0, *)
  override func userNotificationCenter(_ center: UNUserNotificationCenter,
                              didReceive response: UNNotificationResponse,
                              withCompletionHandler completionHandler: @escaping () -> Void) {
    let userInfo = response.notification.request.content.userInfo
    print("Did receive notification response: \(userInfo)")
    
    // You can process the notification content here.
    // For example, if you're using Firebase to pass custom data:
    // Messaging.messaging().appDidReceiveMessage(userInfo) // If you want Firebase to handle it.
    
    completionHandler()
  }
}

// MARK: - MessagingDelegate
// This extension handles FCM token refreshes. It's correctly placed.
extension AppDelegate: MessagingDelegate {
  func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
    print("Firebase registration token: \(String(describing: fcmToken))")
    
    let dataDict: [String: String] = ["token": fcmToken ?? ""]
    NotificationCenter.default.post(
      name: Notification.Name("FCMToken"), // Ensure your Flutter code listens for this.
      object: nil,
      userInfo: dataDict
    )
    // TODO: If you send FCM tokens to your backend server, do it here.
  }
}