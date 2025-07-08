// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Device Manager';

  @override
  String get deviceConfigurationTitle => 'Device Configuration';

  @override
  String get notConfigured => 'Not configured';

  @override
  String get untrained => 'Untrained';

  @override
  String get untrainedNeedData => 'Untrained - Need Data';

  @override
  String get operational => 'Operational';

  @override
  String get busyTraining => 'Busy - Training';

  @override
  String get busyTesting => 'Busy - Testing';

  @override
  String get error => 'Error';

  @override
  String get deviceName => 'Device Name';

  @override
  String get taskDescription => 'Task Description';

  @override
  String get modelType => 'Model Type';

  @override
  String get binaryClassification => 'Binary Classification';

  @override
  String get generalClassification => 'General Classification';

  @override
  String get regression => 'Regression';

  @override
  String get modelSettings => 'Model Settings';

  @override
  String get trainingDataGallery => 'Training Data Gallery';

  @override
  String get testDataGallery => 'Test Data Gallery';

  @override
  String get hardware => 'Hardware';

  @override
  String get configuration => 'Configuration';

  @override
  String get cameraSetup => 'Camera Setup';

  @override
  String get dataManagement => 'Data Management';

  @override
  String get aiAssistant => 'AI Assistant';

  @override
  String get startChat => 'Start Chat';

  @override
  String get addNewDevice => 'Add New Device';

  @override
  String get enterDeviceName => 'Enter device name';

  @override
  String get cancel => 'Cancel';

  @override
  String get connect => 'Connect';

  @override
  String get add => 'Add';

  @override
  String get delete => 'Delete';

  @override
  String get save => 'Save';

  @override
  String get done => 'Done';

  @override
  String get pleaseFillInAllFields => 'Please fill in all fields';

  @override
  String get needHelpConfiguring =>
      'Need help configuring your device? I can assist you with:';

  @override
  String get settingUpCamera => 'Setting up camera parameters';

  @override
  String get choosingModelType => 'Choosing the right model type';

  @override
  String get understandingData => 'Understanding data requirements';

  @override
  String get configuringActions => 'Configuring actions and notifications';

  @override
  String get logout => 'Logout';

  @override
  String get login => 'Login';

  @override
  String get register => 'Register';

  @override
  String get email => 'Email';

  @override
  String get password => 'Password';

  @override
  String get confirmSettings => 'Save Settings';

  @override
  String errorOccurred(String error) {
    return 'An error occurred: $error';
  }

  @override
  String get ok => 'OK';

  @override
  String get trainingAction => 'training';

  @override
  String get testingAction => 'testing';

  @override
  String statusNotConfigured(String action) {
    return 'Please configure your device before $action';
  }

  @override
  String get statusUntrained => 'Ready to start training';

  @override
  String statusNeedData(String action) {
    return 'Please upload at least 10 training images before $action';
  }

  @override
  String get statusOperational => 'Model is trained and ready for testing';

  @override
  String get statusBusyTraining =>
      'Model is currently being trained. Please wait';

  @override
  String get statusBusyTesting =>
      'Model evaluation is in progress. Please wait';

  @override
  String get statusError => 'An error occurred. Please try again';

  @override
  String statusBusy(String status) {
    return 'Please Wait: $status';
  }

  @override
  String statusDefault(String action) {
    return 'Unable to perform $action in current state';
  }

  @override
  String get busyUploading => 'Busy - Uploading';

  @override
  String get statusBusyUploading =>
      'Files are currently being uploaded. Please wait.';

  @override
  String get addDeviceTitle => 'Add New Device';

  @override
  String get addDeviceEnterName => 'Enter device name';

  @override
  String get logoutConfirmTitle => 'Logout';

  @override
  String get logoutConfirmMessage => 'Are you sure you want to log out?';

  @override
  String get noTaskDescription => 'No task description';

  @override
  String status(String status) {
    return 'Status: $status';
  }

  @override
  String get userNotLoggedIn => 'User not logged in';

  @override
  String uploadProgressTitle(int count) {
    return 'Uploading $count Images';
  }

  @override
  String uploadProgressPercent(int percent) {
    return '$percent% complete';
  }

  @override
  String get uploadComplete => 'Upload Complete';

  @override
  String get uploadFailed => 'Upload Failed';

  @override
  String get uploadSuccessMessage => 'Files uploaded successfully';

  @override
  String get uploadFailedMessage => 'Failed to upload files';

  @override
  String get trainingProgressTitle => 'Training Progress';

  @override
  String get trainingCompleteTitle => 'Training Complete';

  @override
  String trainingAccuracyMessage(String accuracy) {
    return 'Model achieved $accuracy% accuracy';
  }

  @override
  String get trainingErrorTitle => 'Training Error';

  @override
  String trainingErrorMessage(String error) {
    return 'Error during training: $error';
  }

  @override
  String get actionRequiredTitle => 'Action Required';

  @override
  String classDetectedMessage(String className, String confidence) {
    return 'Class $className detected with $confidence% confidence';
  }

  @override
  String get setupProgress => 'Setup Progress';

  @override
  String get deviceConfigPageTitle => 'Device Configuration';

  @override
  String get deviceConfigPageAiAssistant => 'AI Assistant';

  @override
  String get deviceConfigPageAiAssistantHelp =>
      'Need help configuring your device? I can assist you with:';

  @override
  String get deviceConfigPageCameraParams => 'Setting up camera parameters';

  @override
  String get deviceConfigPageModelType => 'Choosing the right model type';

  @override
  String get deviceConfigPageDataRequirements =>
      'Understanding data requirements';

  @override
  String get deviceConfigPageActionsNotifications =>
      'Configuring actions and notifications';

  @override
  String get deviceConfigPageStartChat => 'Start Chat';

  @override
  String get deviceConfigPageHardware => 'Hardware';

  @override
  String get deviceConfigPageCameraSetup => 'Camera Setup';

  @override
  String get deviceConfigPageConfiguration => 'Configuration';

  @override
  String get deviceConfigPageDeviceName => 'Device Name';

  @override
  String get deviceConfigPageTaskDescription => 'Task Description';

  @override
  String get deviceConfigPageWarning => 'Warning';

  @override
  String get deviceConfigPageModelTypeWarning =>
      'Changing the model type will reset all labels to 0.0. Do you want to proceed?';

  @override
  String get deviceConfigPageCancel => 'Cancel';

  @override
  String get deviceConfigPageProceed => 'Proceed';

  @override
  String get deviceConfigPageSelectModelType => 'Select Model Type';

  @override
  String get deviceConfigPageClassification => 'Classification';

  @override
  String get deviceConfigPageRegression => 'Regression';

  @override
  String get deviceConfigPageModelSettings => 'Model Settings';

  @override
  String get deviceConfigPageDataManagement => 'Data Management';

  @override
  String get deviceConfigPageTrainingDataGallery => 'Training Data Gallery';

  @override
  String get deviceConfigPageTestDataGallery => 'Test Data Gallery';

  @override
  String get deviceConfigPageDeleteDevice => 'Delete Device';

  @override
  String get deviceConfigPageNoDescription => 'No description';

  @override
  String deviceConfigPageErrorUpdatingModelType(Object error) {
    return 'Error updating model type: $error';
  }

  @override
  String deviceConfigPageErrorDeletingDevice(Object error) {
    return 'Error deleting device: $error';
  }

  @override
  String get deviceConfigPageDeviceNotFound => 'Device not found';

  @override
  String get deviceConfigPageCannotDelete =>
      'Cannot delete device while operations are in progress';

  @override
  String get deviceConfigPageDeleteConfirmationTitle => 'Delete Device';

  @override
  String get deviceConfigPageDeleteConfirmationContent =>
      'Are you sure you want to delete this device? This will permanently delete all data, images, and settings. This action cannot be undone.';

  @override
  String get deviceDashboardPageLatestOutput => 'Latest Output';

  @override
  String deviceDashboardPageConfidence(Object confidence) {
    return 'Confidence: $confidence%';
  }

  @override
  String deviceDashboardPageConsecutiveOccurrences(Object count) {
    return 'Consecutive occurrences: $count';
  }

  @override
  String get deviceDashboardPageOutputHistory => 'Output History';

  @override
  String get deviceDashboardPageLatestImage => 'Latest Image';

  @override
  String get deviceDashboardPageOutputDistribution => 'Output Distribution';

  @override
  String get deviceDashboardPageToday => 'Today';

  @override
  String get deviceDashboardPageLast7Days => 'Last 7 Days';

  @override
  String get deviceDashboardPageAllTime => 'All Time';

  @override
  String get deviceDashboardPageNoOutputData => 'No output data available';

  @override
  String get deviceDashboardPageNoHourlyData => 'No hourly data available';

  @override
  String get deviceDashboardPageNoDistributionData =>
      'No distribution data available';

  @override
  String get deviceDashboardPageNoDataSelectedRange =>
      'No data for selected time range';

  @override
  String get assistantChat => 'Assistant Chat';

  @override
  String get typeYourMessage => 'Type your message...';

  @override
  String errorInitializingChat(Object error) {
    return 'Error initializing chat: $error';
  }

  @override
  String failedToGetResponse(Object response) {
    return 'Failed to get response: $response';
  }

  @override
  String get espConfigTitle => 'ESP Configuration';

  @override
  String get espConfigDescription =>
      'Configure your ESP device settings below.';

  @override
  String get espWifiSSID => 'WiFi SSID';

  @override
  String get espWifiSSIDHint => 'Enter WiFi network name';

  @override
  String get espWifiPassword => 'WiFi Password';

  @override
  String get espWifiPasswordHint => 'Enter WiFi password';

  @override
  String get espSaveSettings => 'Save Settings';

  @override
  String get espSetupCameraLater => 'Set up camera later';

  @override
  String get permissionsRequired => 'Permissions Required';

  @override
  String get permissionsBluetoothLocationMessage =>
      'This app needs Bluetooth and Location permissions to find and connect to cameras. Please grant these permissions to continue.';

  @override
  String get permissionsBluetoothMessage =>
      'This app needs Bluetooth permissions to find and connect to cameras. Please grant these permissions to continue.';

  @override
  String get espSetupCameraLaterExplanation =>
      'You can either connect a camera now or set it up later';

  @override
  String get noCameraConnected => 'No camera connected';

  @override
  String get saveImages => 'Save Images';

  @override
  String get saveImagesExplanation => 'Store captured images in device storage';

  @override
  String get motionTriggered => 'Motion Triggered';

  @override
  String get motionTriggeredExplanation =>
      'Capture images when motion is detected';

  @override
  String get hours => 'Hours';

  @override
  String get minutes => 'Minutes';

  @override
  String get seconds => 'Seconds';

  @override
  String get captureInterval => 'Capture Interval';

  @override
  String get replace => 'Replace';

  @override
  String get connectedCamera => 'Connected Camera';

  @override
  String get openSettings => 'Open Settings';

  @override
  String get toContinuePleaseEnable =>
      'To continue, please enable the following:';

  @override
  String get swipeToAssignClass => 'swipe to assign class';

  @override
  String get dataCollectionMode => 'Data Collection';

  @override
  String get cameraPermissionDenied => 'no Camera Permission';

  @override
  String get testingMode => 'Testing';

  @override
  String get quickDataCapture => 'SwipeSight';

  @override
  String get quickDataCaptureExplanation => 'Collect Data & Test';

  @override
  String get tapToAssignClass => 'Tap to a Assign Class';

  @override
  String get tapOrSwipeToAssign => 'Tap or Swipe to a Assign Class';

  @override
  String get testResult => 'Test Result';

  @override
  String get confidence => 'Confidence';

  @override
  String get detected => 'Detected';

  @override
  String get processingImage => 'Processing Image';

  @override
  String get retry => 'reload';

  @override
  String get listeningHint => 'listening...';

  @override
  String get speechNotAvailable => 'Speech Not Available...';

  @override
  String get microphonePermissionDenied => 'Microphone Permission Denied';

  @override
  String get deviceConfigPageAdvancedSettings => 'Advanced Settings';

  @override
  String get deviceConfigPageEditDeviceInfo => 'Edit Device Info';

  @override
  String get noSpeechDetected => 'no Speech Detected';

  @override
  String get testCamera => 'Test Camera';

  @override
  String get testCameraDescription =>
      'Use your camera to test the inference model';

  @override
  String get cameraTesting => 'Test Camera';

  @override
  String get deviceConfigPageInferenceMode => 'Inference Mode';

  @override
  String get notificationSettings => 'Notification Settings';

  @override
  String get notificationSettingsDescription =>
      'Configure when to receive notifications';

  @override
  String get notificationConfigTitle => 'Notification Configuration';

  @override
  String get notificationConfigDescription =>
      'Configure when to receive notifications for each detected class.';

  @override
  String get countThreshold => 'Count Threshold';

  @override
  String get locationTrigger => 'Location';

  @override
  String get notifyWhenExceedsThreshold =>
      'Notify when count exceeds threshold:';

  @override
  String get drawRegionToTrigger => 'Draw region to trigger notification:';

  @override
  String get saveSettings => 'Save Settings';

  @override
  String get settingsSaved => 'Notification settings saved';

  @override
  String errorSavingSettings(Object error) {
    return 'Error saving settings: $error';
  }

  @override
  String get addYourFirstDevice => 'Add your first device';

  @override
  String get noDevicesFound => 'no devices found';
}
