import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('de'),
    Locale('en'),
  ];

  /// The main title of the application
  ///
  /// In en, this message translates to:
  /// **'Device Manager'**
  String get appTitle;

  /// Title for the device configuration page
  ///
  /// In en, this message translates to:
  /// **'Device Configuration'**
  String get deviceConfigurationTitle;

  /// No description provided for @notConfigured.
  ///
  /// In en, this message translates to:
  /// **'Not configured'**
  String get notConfigured;

  /// No description provided for @untrained.
  ///
  /// In en, this message translates to:
  /// **'Untrained'**
  String get untrained;

  /// No description provided for @untrainedNeedData.
  ///
  /// In en, this message translates to:
  /// **'Untrained - Need Data'**
  String get untrainedNeedData;

  /// No description provided for @operational.
  ///
  /// In en, this message translates to:
  /// **'Operational'**
  String get operational;

  /// No description provided for @busyTraining.
  ///
  /// In en, this message translates to:
  /// **'Busy - Training'**
  String get busyTraining;

  /// No description provided for @busyTesting.
  ///
  /// In en, this message translates to:
  /// **'Busy - Testing'**
  String get busyTesting;

  /// No description provided for @error.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get error;

  /// No description provided for @deviceName.
  ///
  /// In en, this message translates to:
  /// **'Device Name'**
  String get deviceName;

  /// No description provided for @taskDescription.
  ///
  /// In en, this message translates to:
  /// **'Task Description'**
  String get taskDescription;

  /// No description provided for @modelType.
  ///
  /// In en, this message translates to:
  /// **'Model Type'**
  String get modelType;

  /// No description provided for @binaryClassification.
  ///
  /// In en, this message translates to:
  /// **'Binary Classification'**
  String get binaryClassification;

  /// No description provided for @generalClassification.
  ///
  /// In en, this message translates to:
  /// **'General Classification'**
  String get generalClassification;

  /// No description provided for @regression.
  ///
  /// In en, this message translates to:
  /// **'Regression'**
  String get regression;

  /// No description provided for @modelSettings.
  ///
  /// In en, this message translates to:
  /// **'Model Settings'**
  String get modelSettings;

  /// No description provided for @trainingDataGallery.
  ///
  /// In en, this message translates to:
  /// **'Training Data Gallery'**
  String get trainingDataGallery;

  /// No description provided for @testDataGallery.
  ///
  /// In en, this message translates to:
  /// **'Test Data Gallery'**
  String get testDataGallery;

  /// No description provided for @hardware.
  ///
  /// In en, this message translates to:
  /// **'Hardware'**
  String get hardware;

  /// No description provided for @configuration.
  ///
  /// In en, this message translates to:
  /// **'Configuration'**
  String get configuration;

  /// No description provided for @cameraSetup.
  ///
  /// In en, this message translates to:
  /// **'Camera Setup'**
  String get cameraSetup;

  /// No description provided for @dataManagement.
  ///
  /// In en, this message translates to:
  /// **'Data Management'**
  String get dataManagement;

  /// No description provided for @aiAssistant.
  ///
  /// In en, this message translates to:
  /// **'AI Assistant'**
  String get aiAssistant;

  /// No description provided for @startChat.
  ///
  /// In en, this message translates to:
  /// **'Start Chat'**
  String get startChat;

  /// No description provided for @addNewDevice.
  ///
  /// In en, this message translates to:
  /// **'Add New Device'**
  String get addNewDevice;

  /// No description provided for @enterDeviceName.
  ///
  /// In en, this message translates to:
  /// **'Enter device name'**
  String get enterDeviceName;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @connect.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get connect;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @pleaseFillInAllFields.
  ///
  /// In en, this message translates to:
  /// **'Please fill in all fields'**
  String get pleaseFillInAllFields;

  /// No description provided for @needHelpConfiguring.
  ///
  /// In en, this message translates to:
  /// **'Need help configuring your device? I can assist you with:'**
  String get needHelpConfiguring;

  /// No description provided for @settingUpCamera.
  ///
  /// In en, this message translates to:
  /// **'Setting up camera parameters'**
  String get settingUpCamera;

  /// No description provided for @choosingModelType.
  ///
  /// In en, this message translates to:
  /// **'Choosing the right model type'**
  String get choosingModelType;

  /// No description provided for @understandingData.
  ///
  /// In en, this message translates to:
  /// **'Understanding data requirements'**
  String get understandingData;

  /// No description provided for @configuringActions.
  ///
  /// In en, this message translates to:
  /// **'Configuring actions and notifications'**
  String get configuringActions;

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logout;

  /// No description provided for @login.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get login;

  /// No description provided for @register.
  ///
  /// In en, this message translates to:
  /// **'Register'**
  String get register;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @confirmSettings.
  ///
  /// In en, this message translates to:
  /// **'Save Settings'**
  String get confirmSettings;

  /// Error message with placeholder
  ///
  /// In en, this message translates to:
  /// **'An error occurred: {error}'**
  String errorOccurred(String error);

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @trainingAction.
  ///
  /// In en, this message translates to:
  /// **'training'**
  String get trainingAction;

  /// No description provided for @testingAction.
  ///
  /// In en, this message translates to:
  /// **'testing'**
  String get testingAction;

  /// No description provided for @statusNotConfigured.
  ///
  /// In en, this message translates to:
  /// **'Please configure your device before {action}'**
  String statusNotConfigured(String action);

  /// No description provided for @statusUntrained.
  ///
  /// In en, this message translates to:
  /// **'Ready to start training'**
  String get statusUntrained;

  /// No description provided for @statusNeedData.
  ///
  /// In en, this message translates to:
  /// **'Please upload at least 10 training images before {action}'**
  String statusNeedData(String action);

  /// No description provided for @statusOperational.
  ///
  /// In en, this message translates to:
  /// **'Model is trained and ready for testing'**
  String get statusOperational;

  /// No description provided for @statusBusyTraining.
  ///
  /// In en, this message translates to:
  /// **'Model is currently being trained. Please wait'**
  String get statusBusyTraining;

  /// No description provided for @statusBusyTesting.
  ///
  /// In en, this message translates to:
  /// **'Model evaluation is in progress. Please wait'**
  String get statusBusyTesting;

  /// No description provided for @statusError.
  ///
  /// In en, this message translates to:
  /// **'An error occurred. Please try again'**
  String get statusError;

  /// No description provided for @statusBusy.
  ///
  /// In en, this message translates to:
  /// **'Please Wait: {status}'**
  String statusBusy(String status);

  /// No description provided for @statusDefault.
  ///
  /// In en, this message translates to:
  /// **'Unable to perform {action} in current state'**
  String statusDefault(String action);

  /// No description provided for @busyUploading.
  ///
  /// In en, this message translates to:
  /// **'Busy - Uploading'**
  String get busyUploading;

  /// No description provided for @statusBusyUploading.
  ///
  /// In en, this message translates to:
  /// **'Files are currently being uploaded. Please wait.'**
  String get statusBusyUploading;

  /// No description provided for @addDeviceTitle.
  ///
  /// In en, this message translates to:
  /// **'Add New Device'**
  String get addDeviceTitle;

  /// No description provided for @addDeviceEnterName.
  ///
  /// In en, this message translates to:
  /// **'Enter device name'**
  String get addDeviceEnterName;

  /// No description provided for @logoutConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logoutConfirmTitle;

  /// No description provided for @logoutConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to log out?'**
  String get logoutConfirmMessage;

  /// No description provided for @noTaskDescription.
  ///
  /// In en, this message translates to:
  /// **'No task description'**
  String get noTaskDescription;

  /// No description provided for @status.
  ///
  /// In en, this message translates to:
  /// **'Status: {status}'**
  String status(String status);

  /// No description provided for @userNotLoggedIn.
  ///
  /// In en, this message translates to:
  /// **'User not logged in'**
  String get userNotLoggedIn;

  /// No description provided for @uploadProgressTitle.
  ///
  /// In en, this message translates to:
  /// **'Uploading {count} Images'**
  String uploadProgressTitle(int count);

  /// No description provided for @uploadProgressPercent.
  ///
  /// In en, this message translates to:
  /// **'{percent}% complete'**
  String uploadProgressPercent(int percent);

  /// No description provided for @uploadComplete.
  ///
  /// In en, this message translates to:
  /// **'Upload Complete'**
  String get uploadComplete;

  /// No description provided for @uploadFailed.
  ///
  /// In en, this message translates to:
  /// **'Upload Failed'**
  String get uploadFailed;

  /// No description provided for @uploadSuccessMessage.
  ///
  /// In en, this message translates to:
  /// **'Files uploaded successfully'**
  String get uploadSuccessMessage;

  /// No description provided for @uploadFailedMessage.
  ///
  /// In en, this message translates to:
  /// **'Failed to upload files'**
  String get uploadFailedMessage;

  /// No description provided for @trainingProgressTitle.
  ///
  /// In en, this message translates to:
  /// **'Training Progress'**
  String get trainingProgressTitle;

  /// No description provided for @trainingCompleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Training Complete'**
  String get trainingCompleteTitle;

  /// No description provided for @trainingAccuracyMessage.
  ///
  /// In en, this message translates to:
  /// **'Model achieved {accuracy}% accuracy'**
  String trainingAccuracyMessage(String accuracy);

  /// No description provided for @trainingErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Training Error'**
  String get trainingErrorTitle;

  /// No description provided for @trainingErrorMessage.
  ///
  /// In en, this message translates to:
  /// **'Error during training: {error}'**
  String trainingErrorMessage(String error);

  /// No description provided for @actionRequiredTitle.
  ///
  /// In en, this message translates to:
  /// **'Action Required'**
  String get actionRequiredTitle;

  /// No description provided for @classDetectedMessage.
  ///
  /// In en, this message translates to:
  /// **'Class {className} detected with {confidence}% confidence'**
  String classDetectedMessage(String className, String confidence);

  /// No description provided for @setupProgress.
  ///
  /// In en, this message translates to:
  /// **'Setup Progress'**
  String get setupProgress;

  /// No description provided for @deviceConfigPageTitle.
  ///
  /// In en, this message translates to:
  /// **'Device Configuration'**
  String get deviceConfigPageTitle;

  /// No description provided for @deviceConfigPageAiAssistant.
  ///
  /// In en, this message translates to:
  /// **'AI Assistant'**
  String get deviceConfigPageAiAssistant;

  /// No description provided for @deviceConfigPageAiAssistantHelp.
  ///
  /// In en, this message translates to:
  /// **'Need help configuring your device? I can assist you with:'**
  String get deviceConfigPageAiAssistantHelp;

  /// No description provided for @deviceConfigPageCameraParams.
  ///
  /// In en, this message translates to:
  /// **'Setting up camera parameters'**
  String get deviceConfigPageCameraParams;

  /// No description provided for @deviceConfigPageModelType.
  ///
  /// In en, this message translates to:
  /// **'Choosing the right model type'**
  String get deviceConfigPageModelType;

  /// No description provided for @deviceConfigPageDataRequirements.
  ///
  /// In en, this message translates to:
  /// **'Understanding data requirements'**
  String get deviceConfigPageDataRequirements;

  /// No description provided for @deviceConfigPageActionsNotifications.
  ///
  /// In en, this message translates to:
  /// **'Configuring actions and notifications'**
  String get deviceConfigPageActionsNotifications;

  /// No description provided for @deviceConfigPageStartChat.
  ///
  /// In en, this message translates to:
  /// **'Start Chat'**
  String get deviceConfigPageStartChat;

  /// No description provided for @deviceConfigPageHardware.
  ///
  /// In en, this message translates to:
  /// **'Hardware'**
  String get deviceConfigPageHardware;

  /// No description provided for @deviceConfigPageCameraSetup.
  ///
  /// In en, this message translates to:
  /// **'Camera Setup'**
  String get deviceConfigPageCameraSetup;

  /// No description provided for @deviceConfigPageConfiguration.
  ///
  /// In en, this message translates to:
  /// **'Configuration'**
  String get deviceConfigPageConfiguration;

  /// No description provided for @deviceConfigPageDeviceName.
  ///
  /// In en, this message translates to:
  /// **'Device Name'**
  String get deviceConfigPageDeviceName;

  /// No description provided for @deviceConfigPageTaskDescription.
  ///
  /// In en, this message translates to:
  /// **'Task Description'**
  String get deviceConfigPageTaskDescription;

  /// No description provided for @deviceConfigPageWarning.
  ///
  /// In en, this message translates to:
  /// **'Warning'**
  String get deviceConfigPageWarning;

  /// No description provided for @deviceConfigPageModelTypeWarning.
  ///
  /// In en, this message translates to:
  /// **'Changing the model type will reset all labels to 0.0. Do you want to proceed?'**
  String get deviceConfigPageModelTypeWarning;

  /// No description provided for @deviceConfigPageCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get deviceConfigPageCancel;

  /// No description provided for @deviceConfigPageProceed.
  ///
  /// In en, this message translates to:
  /// **'Proceed'**
  String get deviceConfigPageProceed;

  /// No description provided for @deviceConfigPageSelectModelType.
  ///
  /// In en, this message translates to:
  /// **'Select Model Type'**
  String get deviceConfigPageSelectModelType;

  /// No description provided for @deviceConfigPageClassification.
  ///
  /// In en, this message translates to:
  /// **'Classification'**
  String get deviceConfigPageClassification;

  /// No description provided for @deviceConfigPageRegression.
  ///
  /// In en, this message translates to:
  /// **'Regression'**
  String get deviceConfigPageRegression;

  /// No description provided for @deviceConfigPageModelSettings.
  ///
  /// In en, this message translates to:
  /// **'Model Settings'**
  String get deviceConfigPageModelSettings;

  /// No description provided for @deviceConfigPageDataManagement.
  ///
  /// In en, this message translates to:
  /// **'Data Management'**
  String get deviceConfigPageDataManagement;

  /// No description provided for @deviceConfigPageTrainingDataGallery.
  ///
  /// In en, this message translates to:
  /// **'Training Data Gallery'**
  String get deviceConfigPageTrainingDataGallery;

  /// No description provided for @deviceConfigPageTestDataGallery.
  ///
  /// In en, this message translates to:
  /// **'Test Data Gallery'**
  String get deviceConfigPageTestDataGallery;

  /// No description provided for @deviceConfigPageDeleteDevice.
  ///
  /// In en, this message translates to:
  /// **'Delete Device'**
  String get deviceConfigPageDeleteDevice;

  /// No description provided for @deviceConfigPageNoDescription.
  ///
  /// In en, this message translates to:
  /// **'No description'**
  String get deviceConfigPageNoDescription;

  /// No description provided for @deviceConfigPageErrorUpdatingModelType.
  ///
  /// In en, this message translates to:
  /// **'Error updating model type: {error}'**
  String deviceConfigPageErrorUpdatingModelType(Object error);

  /// No description provided for @deviceConfigPageErrorDeletingDevice.
  ///
  /// In en, this message translates to:
  /// **'Error deleting device: {error}'**
  String deviceConfigPageErrorDeletingDevice(Object error);

  /// No description provided for @deviceConfigPageDeviceNotFound.
  ///
  /// In en, this message translates to:
  /// **'Device not found'**
  String get deviceConfigPageDeviceNotFound;

  /// No description provided for @deviceConfigPageCannotDelete.
  ///
  /// In en, this message translates to:
  /// **'Cannot delete device while operations are in progress'**
  String get deviceConfigPageCannotDelete;

  /// No description provided for @deviceConfigPageDeleteConfirmationTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Device'**
  String get deviceConfigPageDeleteConfirmationTitle;

  /// No description provided for @deviceConfigPageDeleteConfirmationContent.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this device? This will permanently delete all data, images, and settings. This action cannot be undone.'**
  String get deviceConfigPageDeleteConfirmationContent;

  /// No description provided for @deviceDashboardPageLatestOutput.
  ///
  /// In en, this message translates to:
  /// **'Latest Output'**
  String get deviceDashboardPageLatestOutput;

  /// No description provided for @deviceDashboardPageConfidence.
  ///
  /// In en, this message translates to:
  /// **'Confidence: {confidence}%'**
  String deviceDashboardPageConfidence(Object confidence);

  /// No description provided for @deviceDashboardPageConsecutiveOccurrences.
  ///
  /// In en, this message translates to:
  /// **'Consecutive occurrences: {count}'**
  String deviceDashboardPageConsecutiveOccurrences(Object count);

  /// No description provided for @deviceDashboardPageOutputHistory.
  ///
  /// In en, this message translates to:
  /// **'Output History'**
  String get deviceDashboardPageOutputHistory;

  /// No description provided for @deviceDashboardPageLatestImage.
  ///
  /// In en, this message translates to:
  /// **'Latest Image'**
  String get deviceDashboardPageLatestImage;

  /// No description provided for @deviceDashboardPageOutputDistribution.
  ///
  /// In en, this message translates to:
  /// **'Output Distribution'**
  String get deviceDashboardPageOutputDistribution;

  /// No description provided for @deviceDashboardPageToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get deviceDashboardPageToday;

  /// No description provided for @deviceDashboardPageLast7Days.
  ///
  /// In en, this message translates to:
  /// **'Last 7 Days'**
  String get deviceDashboardPageLast7Days;

  /// No description provided for @deviceDashboardPageAllTime.
  ///
  /// In en, this message translates to:
  /// **'All Time'**
  String get deviceDashboardPageAllTime;

  /// No description provided for @deviceDashboardPageNoOutputData.
  ///
  /// In en, this message translates to:
  /// **'No output data available'**
  String get deviceDashboardPageNoOutputData;

  /// No description provided for @deviceDashboardPageNoHourlyData.
  ///
  /// In en, this message translates to:
  /// **'No hourly data available'**
  String get deviceDashboardPageNoHourlyData;

  /// No description provided for @deviceDashboardPageNoDistributionData.
  ///
  /// In en, this message translates to:
  /// **'No distribution data available'**
  String get deviceDashboardPageNoDistributionData;

  /// No description provided for @deviceDashboardPageNoDataSelectedRange.
  ///
  /// In en, this message translates to:
  /// **'No data for selected time range'**
  String get deviceDashboardPageNoDataSelectedRange;

  /// No description provided for @assistantChat.
  ///
  /// In en, this message translates to:
  /// **'Assistant Chat'**
  String get assistantChat;

  /// No description provided for @typeYourMessage.
  ///
  /// In en, this message translates to:
  /// **'Type your message...'**
  String get typeYourMessage;

  /// No description provided for @errorInitializingChat.
  ///
  /// In en, this message translates to:
  /// **'Error initializing chat: {error}'**
  String errorInitializingChat(Object error);

  /// No description provided for @failedToGetResponse.
  ///
  /// In en, this message translates to:
  /// **'Failed to get response: {response}'**
  String failedToGetResponse(Object response);

  /// No description provided for @espConfigTitle.
  ///
  /// In en, this message translates to:
  /// **'ESP Configuration'**
  String get espConfigTitle;

  /// No description provided for @espConfigDescription.
  ///
  /// In en, this message translates to:
  /// **'Configure your ESP device settings below.'**
  String get espConfigDescription;

  /// No description provided for @espWifiSSID.
  ///
  /// In en, this message translates to:
  /// **'WiFi SSID'**
  String get espWifiSSID;

  /// No description provided for @espWifiSSIDHint.
  ///
  /// In en, this message translates to:
  /// **'Enter WiFi network name'**
  String get espWifiSSIDHint;

  /// No description provided for @espWifiPassword.
  ///
  /// In en, this message translates to:
  /// **'WiFi Password'**
  String get espWifiPassword;

  /// No description provided for @espWifiPasswordHint.
  ///
  /// In en, this message translates to:
  /// **'Enter WiFi password'**
  String get espWifiPasswordHint;

  /// No description provided for @espSaveSettings.
  ///
  /// In en, this message translates to:
  /// **'Save Settings'**
  String get espSaveSettings;

  /// No description provided for @espSetupCameraLater.
  ///
  /// In en, this message translates to:
  /// **'Set up camera later'**
  String get espSetupCameraLater;

  /// No description provided for @permissionsRequired.
  ///
  /// In en, this message translates to:
  /// **'Permissions Required'**
  String get permissionsRequired;

  /// No description provided for @permissionsBluetoothLocationMessage.
  ///
  /// In en, this message translates to:
  /// **'This app needs Bluetooth and Location permissions to find and connect to cameras. Please grant these permissions to continue.'**
  String get permissionsBluetoothLocationMessage;

  /// No description provided for @permissionsBluetoothMessage.
  ///
  /// In en, this message translates to:
  /// **'This app needs Bluetooth permissions to find and connect to cameras. Please grant these permissions to continue.'**
  String get permissionsBluetoothMessage;

  /// No description provided for @espSetupCameraLaterExplanation.
  ///
  /// In en, this message translates to:
  /// **'You can either connect a camera now or set it up later'**
  String get espSetupCameraLaterExplanation;

  /// No description provided for @noCameraConnected.
  ///
  /// In en, this message translates to:
  /// **'No camera connected'**
  String get noCameraConnected;

  /// No description provided for @saveImages.
  ///
  /// In en, this message translates to:
  /// **'Save Images'**
  String get saveImages;

  /// No description provided for @saveImagesExplanation.
  ///
  /// In en, this message translates to:
  /// **'Store captured images in device storage'**
  String get saveImagesExplanation;

  /// No description provided for @motionTriggered.
  ///
  /// In en, this message translates to:
  /// **'Motion Triggered'**
  String get motionTriggered;

  /// No description provided for @motionTriggeredExplanation.
  ///
  /// In en, this message translates to:
  /// **'Capture images when motion is detected'**
  String get motionTriggeredExplanation;

  /// No description provided for @hours.
  ///
  /// In en, this message translates to:
  /// **'Hours'**
  String get hours;

  /// No description provided for @minutes.
  ///
  /// In en, this message translates to:
  /// **'Minutes'**
  String get minutes;

  /// No description provided for @seconds.
  ///
  /// In en, this message translates to:
  /// **'Seconds'**
  String get seconds;

  /// No description provided for @captureInterval.
  ///
  /// In en, this message translates to:
  /// **'Capture Interval'**
  String get captureInterval;

  /// No description provided for @replace.
  ///
  /// In en, this message translates to:
  /// **'Replace'**
  String get replace;

  /// No description provided for @connectedCamera.
  ///
  /// In en, this message translates to:
  /// **'Connected Camera'**
  String get connectedCamera;

  /// No description provided for @openSettings.
  ///
  /// In en, this message translates to:
  /// **'Open Settings'**
  String get openSettings;

  /// No description provided for @toContinuePleaseEnable.
  ///
  /// In en, this message translates to:
  /// **'To continue, please enable the following:'**
  String get toContinuePleaseEnable;

  /// No description provided for @swipeToAssignClass.
  ///
  /// In en, this message translates to:
  /// **'swipe to assign class'**
  String get swipeToAssignClass;

  /// No description provided for @dataCollectionMode.
  ///
  /// In en, this message translates to:
  /// **'Data Collection'**
  String get dataCollectionMode;

  /// No description provided for @cameraPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'no Camera Permission'**
  String get cameraPermissionDenied;

  /// No description provided for @testingMode.
  ///
  /// In en, this message translates to:
  /// **'Testing'**
  String get testingMode;

  /// No description provided for @quickDataCapture.
  ///
  /// In en, this message translates to:
  /// **'SwipeSight'**
  String get quickDataCapture;

  /// No description provided for @quickDataCaptureExplanation.
  ///
  /// In en, this message translates to:
  /// **'Collect Data & Test'**
  String get quickDataCaptureExplanation;

  /// No description provided for @tapToAssignClass.
  ///
  /// In en, this message translates to:
  /// **'Tap to a Assign Class'**
  String get tapToAssignClass;

  /// No description provided for @tapOrSwipeToAssign.
  ///
  /// In en, this message translates to:
  /// **'Tap or Swipe to a Assign Class'**
  String get tapOrSwipeToAssign;

  /// No description provided for @testResult.
  ///
  /// In en, this message translates to:
  /// **'Test Result'**
  String get testResult;

  /// No description provided for @confidence.
  ///
  /// In en, this message translates to:
  /// **'Confidence'**
  String get confidence;

  /// No description provided for @detected.
  ///
  /// In en, this message translates to:
  /// **'Detected'**
  String get detected;

  /// No description provided for @processingImage.
  ///
  /// In en, this message translates to:
  /// **'Processing Image'**
  String get processingImage;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'reload'**
  String get retry;

  /// No description provided for @listeningHint.
  ///
  /// In en, this message translates to:
  /// **'listening...'**
  String get listeningHint;

  /// No description provided for @speechNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'Speech Not Available...'**
  String get speechNotAvailable;

  /// No description provided for @microphonePermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Microphone Permission Denied'**
  String get microphonePermissionDenied;

  /// No description provided for @deviceConfigPageAdvancedSettings.
  ///
  /// In en, this message translates to:
  /// **'Advanced Settings'**
  String get deviceConfigPageAdvancedSettings;

  /// No description provided for @deviceConfigPageEditDeviceInfo.
  ///
  /// In en, this message translates to:
  /// **'Edit Device Info'**
  String get deviceConfigPageEditDeviceInfo;

  /// No description provided for @noSpeechDetected.
  ///
  /// In en, this message translates to:
  /// **'no Speech Detected'**
  String get noSpeechDetected;

  /// No description provided for @testCamera.
  ///
  /// In en, this message translates to:
  /// **'Test Camera'**
  String get testCamera;

  /// No description provided for @testCameraDescription.
  ///
  /// In en, this message translates to:
  /// **'Use your camera to test the inference model'**
  String get testCameraDescription;

  /// No description provided for @cameraTesting.
  ///
  /// In en, this message translates to:
  /// **'Test Camera'**
  String get cameraTesting;

  /// No description provided for @deviceConfigPageInferenceMode.
  ///
  /// In en, this message translates to:
  /// **'Inference Mode'**
  String get deviceConfigPageInferenceMode;

  /// No description provided for @notificationSettings.
  ///
  /// In en, this message translates to:
  /// **'Notification Settings'**
  String get notificationSettings;

  /// No description provided for @notificationSettingsDescription.
  ///
  /// In en, this message translates to:
  /// **'Configure when to receive notifications'**
  String get notificationSettingsDescription;

  /// No description provided for @notificationConfigTitle.
  ///
  /// In en, this message translates to:
  /// **'Notification Configuration'**
  String get notificationConfigTitle;

  /// No description provided for @notificationConfigDescription.
  ///
  /// In en, this message translates to:
  /// **'Configure when to receive notifications for each detected class.'**
  String get notificationConfigDescription;

  /// No description provided for @countThreshold.
  ///
  /// In en, this message translates to:
  /// **'Count Threshold'**
  String get countThreshold;

  /// No description provided for @locationTrigger.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get locationTrigger;

  /// No description provided for @notifyWhenExceedsThreshold.
  ///
  /// In en, this message translates to:
  /// **'Notify when count exceeds threshold:'**
  String get notifyWhenExceedsThreshold;

  /// No description provided for @drawRegionToTrigger.
  ///
  /// In en, this message translates to:
  /// **'Draw region to trigger notification:'**
  String get drawRegionToTrigger;

  /// No description provided for @saveSettings.
  ///
  /// In en, this message translates to:
  /// **'Save Settings'**
  String get saveSettings;

  /// No description provided for @settingsSaved.
  ///
  /// In en, this message translates to:
  /// **'Notification settings saved'**
  String get settingsSaved;

  /// No description provided for @errorSavingSettings.
  ///
  /// In en, this message translates to:
  /// **'Error saving settings: {error}'**
  String errorSavingSettings(Object error);

  /// No description provided for @addYourFirstDevice.
  ///
  /// In en, this message translates to:
  /// **'Add your first device'**
  String get addYourFirstDevice;

  /// No description provided for @noDevicesFound.
  ///
  /// In en, this message translates to:
  /// **'no devices found'**
  String get noDevicesFound;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['de', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
