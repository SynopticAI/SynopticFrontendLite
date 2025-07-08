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
    
    print("🚀 AppDelegate didFinishLaunching started")
    
    // Configure Firebase FIRST
    if FirebaseApp.app() == nil {
      FirebaseApp.configure()
      print("✅ Firebase configured")
    } else {
      print("✅ Firebase already configured")
    }
    
    // Register Flutter plugins
    GeneratedPluginRegistrant.register(with: self)
    print("✅ Flutter plugins registered")
    
    // Setup method channel for notifications
    setupMethodChannel()
    
    // Setup notifications with detailed logging
    setupNotifications(application)
    
    // Check entitlements and capabilities
    checkAppCapabilities()
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  private func checkAppCapabilities() {
    print("🔍 Checking app capabilities...")
    
    // Check if we're running on simulator
    #if targetEnvironment(simulator)
    print("⚠️ Running on iOS Simulator - APNS won't work")
    #else
    print("✅ Running on real device")
    #endif
    
    // Check build configuration
    #if DEBUG
    print("🔧 Build configuration: DEBUG")
    #else
    print("🔧 Build configuration: RELEASE/PRODUCTION")
    #endif
    
    // Check bundle identifier
    if let bundleId = Bundle.main.bundleIdentifier {
      print("📦 Bundle ID: \(bundleId)")
    }
    
    // Check if entitlements file exists
    if let entitlements = Bundle.main.entitlements {
      print("📋 App entitlements found:")
      for (key, value) in entitlements {
        print("   \(key): \(value)")
      }
      
      // Specifically check for aps-environment
      if let apsEnv = entitlements["aps-environment"] as? String {
        print("✅ APS Environment: \(apsEnv)")
      } else {
        print("❌ APS Environment not found in entitlements!")
      }
    } else {
      print("❌ No entitlements found!")
    }
    
    // Check code signing
    if let path = Bundle.main.path(forResource: "embedded", ofType: "mobileprovision") {
      print("✅ Provisioning profile embedded at: \(path)")
    } else {
      print("⚠️ No embedded provisioning profile found")
    }
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
          print("📱 About to call UIApplication.shared.registerForRemoteNotifications()")
          UIApplication.shared.registerForRemoteNotifications()
          print("✅ Called UIApplication.shared.registerForRemoteNotifications()")
        }
        result("success")
      case "checkRegistrationStatus":
        DispatchQueue.main.async {
          let isRegistered = UIApplication.shared.isRegisteredForRemoteNotifications
          print("📊 isRegisteredForRemoteNotifications: \(isRegistered)")
          result(isRegistered)
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
  
  private func setupNotifications(_ application: UIApplication) {
    print("🔧 Setting up notifications...")
    
    // Set messaging delegate
    Messaging.messaging().delegate = self
    print("✅ Firebase Messaging delegate set")
    
    // Set notification center delegate
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self
      print("✅ UNUserNotificationCenter delegate set")
    }
    
    // Check if already registered
    let isRegistered = application.isRegisteredForRemoteNotifications
    print("📊 Initial registration status: \(isRegistered)")
    
    // Try to register immediately (this should trigger callbacks)
    print("🔄 Attempting initial remote notification registration...")
    application.registerForRemoteNotifications()
    print("✅ Initial registration call completed")
  }
  
  // MARK: - Remote Notification Registration
  
  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
    print("🎉 SUCCESS: APNS Token received in AppDelegate!")
    print("🔑 Token: \(tokenString)")
    print("📏 Token length: \(deviceToken.count) bytes")
    
    // Verify we're in the right environment
    #if DEBUG
    print("🔧 Setting APNS token type: SANDBOX")
    Messaging.messaging().setAPNSToken(deviceToken, type: .sandbox)
    #else
    print("🔧 Setting APNS token type: PRODUCTION")
    Messaging.messaging().setAPNSToken(deviceToken, type: .prod)
    #endif
    
    // Also set the token property
    Messaging.messaging().apnsToken = deviceToken
    print("✅ APNS token set in Firebase Messaging")
    
    // Call super
    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
    print("✅ Super method called")
  }
  
  override func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    print("💥 CRITICAL: APNS Registration FAILED!")
    print("❌ Error: \(error.localizedDescription)")
    
    // Detailed error analysis
    let nsError = error as NSError
    print("❌ Error domain: \(nsError.domain)")
    print("❌ Error code: \(nsError.code)")
    print("❌ Error userInfo: \(nsError.userInfo)")
    
    // Common error interpretations
    switch nsError.code {
    case 3010:
      print("💡 Error 3010: No valid 'aps-environment' entitlement found")
      print("💡 This usually means:")
      print("   - Provisioning profile doesn't have Push Notifications enabled")
      print("   - aps-environment is missing from entitlements")
      print("   - Code signing issue")
    case 3000:
      print("💡 Error 3000: Device token generation failed")
      print("💡 This usually means:")
      print("   - Running on simulator (APNs not supported)")
      print("   - Network connectivity issues")
    default:
      print("💡 Unknown error code. Check Apple documentation.")
    }
    
    // Call super
    super.application(application, didFailToRegisterForRemoteNotificationsWithError: error)
  }
  
  // MARK: - UNUserNotificationCenterDelegate
  
  @available(iOS 10.0, *)
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    print("📩 Notification will present: \(notification.request.identifier)")
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
    print("👆 Notification tapped: \(response.notification.request.identifier)")
    completionHandler()
  }
}

// MARK: - MessagingDelegate
extension AppDelegate: MessagingDelegate {
  func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
    print("🎊 FCM Token received in AppDelegate!")
    if let token = fcmToken {
      print("🔑 FCM Token: \(token.prefix(20))...")
    } else {
      print("⚠️ FCM Token is nil")
    }
    
    let dataDict: [String: String] = ["token": fcmToken ?? ""]
    NotificationCenter.default.post(
      name: Notification.Name("FCMToken"),
      object: nil,
      userInfo: dataDict
    )
  }
}

// MARK: - Bundle Extension for Entitlements
extension Bundle {
  var entitlements: [String: Any]? {
    guard let path = self.path(forResource: "archived-expanded-entitlements", ofType: "xcent") ??
                     self.path(forResource: "Entitlements", ofType: "plist") else {
      return nil
    }
    return NSDictionary(contentsOfFile: path) as? [String: Any]
  }
}