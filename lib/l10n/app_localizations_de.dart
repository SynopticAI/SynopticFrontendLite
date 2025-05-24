// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get appTitle => 'Geräteverwaltung';

  @override
  String get deviceConfigurationTitle => 'Gerätekonfiguration';

  @override
  String get notConfigured => 'Nicht konfiguriert';

  @override
  String get untrained => 'Untrainiert';

  @override
  String get untrainedNeedData => 'Untrainiert - Daten erforderlich';

  @override
  String get operational => 'Betriebsbereit';

  @override
  String get busyTraining => 'Beschäftigt - Training';

  @override
  String get busyTesting => 'Beschäftigt - Test';

  @override
  String get error => 'Fehler';

  @override
  String get deviceName => 'Gerätename';

  @override
  String get taskDescription => 'Aufgabenbeschreibung';

  @override
  String get modelType => 'Modelltyp';

  @override
  String get binaryClassification => 'Binäre Klassifikation';

  @override
  String get generalClassification => 'Allgemeine Klassifikation';

  @override
  String get regression => 'Regression';

  @override
  String get modelSettings => 'Modelleinstellungen';

  @override
  String get trainingDataGallery => 'Trainingsdaten-Galerie';

  @override
  String get testDataGallery => 'Testdaten-Galerie';

  @override
  String get hardware => 'Hardware';

  @override
  String get configuration => 'Konfiguration';

  @override
  String get cameraSetup => 'Kameraeinrichtung';

  @override
  String get dataManagement => 'Datenverwaltung';

  @override
  String get aiAssistant => 'KI-Assistent';

  @override
  String get startChat => 'Chat starten';

  @override
  String get addNewDevice => 'Neues Gerät hinzufügen';

  @override
  String get enterDeviceName => 'Gerätename eingeben';

  @override
  String get cancel => 'Abbrechen';

  @override
  String get connect => 'Verbinden';

  @override
  String get add => 'Hinzufügen';

  @override
  String get delete => 'Löschen';

  @override
  String get save => 'Speichern';

  @override
  String get done => 'Fertig';

  @override
  String get pleaseFillInAllFields => 'Bitte alle Felder füllen';

  @override
  String get needHelpConfiguring =>
      'Benötigen Sie Hilfe bei der Konfiguration? Ich kann Ihnen helfen bei:';

  @override
  String get settingUpCamera => 'Einrichten der Kameraparameter';

  @override
  String get choosingModelType => 'Auswahl des richtigen Modelltyps';

  @override
  String get understandingData => 'Verständnis der Datenanforderungen';

  @override
  String get configuringActions =>
      'Konfigurieren von Aktionen und Benachrichtigungen';

  @override
  String get logout => 'Abmelden';

  @override
  String get login => 'Anmelden';

  @override
  String get register => 'Registrieren';

  @override
  String get email => 'E-Mail';

  @override
  String get password => 'Passwort';

  @override
  String get confirmSettings => 'Einstellungen speichern';

  @override
  String errorOccurred(String error) {
    return 'Ein Fehler ist aufgetreten: $error';
  }

  @override
  String get ok => 'OK';

  @override
  String get trainingAction => 'Training';

  @override
  String get testingAction => 'Test';

  @override
  String statusNotConfigured(String action) {
    return 'Bitte konfigurieren Sie Ihr Gerät vor dem $action';
  }

  @override
  String get statusUntrained => 'Bereit zum Starten des Trainings';

  @override
  String statusNeedData(String action) {
    return 'Bitte laden Sie mindestens 10 Trainingsbilder vor dem $action hoch';
  }

  @override
  String get statusOperational => 'Modell ist trainiert und bereit für Tests';

  @override
  String get statusBusyTraining =>
      'Modell wird derzeit trainiert. Bitte warten';

  @override
  String get statusBusyTesting => 'Modellevaluierung läuft. Bitte warten';

  @override
  String get statusError =>
      'Ein Fehler ist aufgetreten. Bitte versuchen Sie es erneut';

  @override
  String statusBusy(String status) {
    return 'Bitte warten: $status';
  }

  @override
  String statusDefault(String action) {
    return '$action im aktuellen Zustand nicht möglich';
  }

  @override
  String get busyUploading => 'Beschäftigt - Hochladen';

  @override
  String get statusBusyUploading =>
      'Dateien werden derzeit hochgeladen. Bitte warten.';

  @override
  String get addDeviceTitle => 'Neues Gerät hinzufügen';

  @override
  String get addDeviceEnterName => 'Gerätename eingeben';

  @override
  String get logoutConfirmTitle => 'Abmelden';

  @override
  String get logoutConfirmMessage =>
      'Sind Sie sicher, dass Sie sich abmelden möchten?';

  @override
  String get noTaskDescription => 'Keine Aufgabenbeschreibung';

  @override
  String status(String status) {
    return 'Status: $status';
  }

  @override
  String get userNotLoggedIn => 'Benutzer nicht angemeldet';

  @override
  String uploadProgressTitle(int count) {
    return 'Lade $count Bilder hoch';
  }

  @override
  String uploadProgressPercent(int percent) {
    return '$percent% abgeschlossen';
  }

  @override
  String get uploadComplete => 'Upload abgeschlossen';

  @override
  String get uploadFailed => 'Upload fehlgeschlagen';

  @override
  String get uploadSuccessMessage => 'Dateien erfolgreich hochgeladen';

  @override
  String get uploadFailedMessage => 'Fehler beim Hochladen der Dateien';

  @override
  String get trainingProgressTitle => 'Trainingsfortschritt';

  @override
  String get trainingCompleteTitle => 'Training abgeschlossen';

  @override
  String trainingAccuracyMessage(String accuracy) {
    return 'Modell erreichte $accuracy% Genauigkeit';
  }

  @override
  String get trainingErrorTitle => 'Trainingsfehler';

  @override
  String trainingErrorMessage(String error) {
    return 'Fehler während des Trainings: $error';
  }

  @override
  String get actionRequiredTitle => 'Aktion erforderlich';

  @override
  String classDetectedMessage(String className, String confidence) {
    return 'Klasse $className mit $confidence% Konfidenz erkannt';
  }

  @override
  String get setupProgress => 'Einrichtungsfortschritt';

  @override
  String get deviceConfigPageTitle => 'Gerätekonfiguration';

  @override
  String get deviceConfigPageAiAssistant => 'KI-Assistent';

  @override
  String get deviceConfigPageAiAssistantHelp =>
      'Brauchen Sie Hilfe bei der Einrichtung Ihres Geräts? Ich kann Sie unterstützen bei:';

  @override
  String get deviceConfigPageCameraParams =>
      'Kameraeinstellungen konfigurieren';

  @override
  String get deviceConfigPageModelType => 'Den richtigen Modelltyp auswählen';

  @override
  String get deviceConfigPageDataRequirements => 'Datenanforderungen verstehen';

  @override
  String get deviceConfigPageActionsNotifications =>
      'Aktionen und Benachrichtigungen';

  @override
  String get deviceConfigPageStartChat => 'Chat starten';

  @override
  String get deviceConfigPageHardware => 'Hardware';

  @override
  String get deviceConfigPageCameraSetup => 'Kameraeinstellungen';

  @override
  String get deviceConfigPageConfiguration => 'Konfiguration';

  @override
  String get deviceConfigPageDeviceName => 'Gerätename';

  @override
  String get deviceConfigPageTaskDescription => 'Aufgabenbeschreibung';

  @override
  String get deviceConfigPageWarning => 'Warnung';

  @override
  String get deviceConfigPageModelTypeWarning =>
      'Das Ändern des Modelltyps setzt alle Labels auf 0.0 zurück. Möchten Sie fortfahren?';

  @override
  String get deviceConfigPageCancel => 'Abbrechen';

  @override
  String get deviceConfigPageProceed => 'Fortfahren';

  @override
  String get deviceConfigPageSelectModelType => 'Modelltyp auswählen';

  @override
  String get deviceConfigPageClassification => 'Klassifikation';

  @override
  String get deviceConfigPageRegression => 'Regression';

  @override
  String get deviceConfigPageModelSettings => 'Modelleinstellungen';

  @override
  String get deviceConfigPageDataManagement => 'Datenverwaltung';

  @override
  String get deviceConfigPageTrainingDataGallery => 'Trainingsdaten-Galerie';

  @override
  String get deviceConfigPageTestDataGallery => 'Testdaten-Galerie';

  @override
  String get deviceConfigPageDeleteDevice => 'Gerät löschen';

  @override
  String get deviceConfigPageNoDescription => 'Keine Beschreibung';

  @override
  String deviceConfigPageErrorUpdatingModelType(Object error) {
    return 'Fehler beim Aktualisieren des Modelltyps: $error';
  }

  @override
  String deviceConfigPageErrorDeletingDevice(Object error) {
    return 'Fehler beim Löschen des Geräts: $error';
  }

  @override
  String get deviceConfigPageDeviceNotFound => 'Gerät nicht gefunden';

  @override
  String get deviceConfigPageCannotDelete =>
      'Gerät kann nicht gelöscht werden, während Vorgänge laufen';

  @override
  String get deviceConfigPageDeleteConfirmationTitle => 'Gerät löschen';

  @override
  String get deviceConfigPageDeleteConfirmationContent =>
      'Möchten Sie dieses Gerät wirklich löschen? Dadurch werden alle Daten, Bilder und Einstellungen dauerhaft gelöscht. Diese Aktion kann nicht rückgängig gemacht werden.';

  @override
  String get deviceDashboardPageLatestOutput => 'Neueste Ausgabe';

  @override
  String deviceDashboardPageConfidence(Object confidence) {
    return 'Vertrauen: $confidence%';
  }

  @override
  String deviceDashboardPageConsecutiveOccurrences(Object count) {
    return 'Aufeinanderfolgende Vorkommen: $count';
  }

  @override
  String get deviceDashboardPageOutputHistory => 'Ausgabeverlauf';

  @override
  String get deviceDashboardPageLatestImage => 'Neuestes Bild';

  @override
  String get deviceDashboardPageOutputDistribution => 'Ausgabeverteilung';

  @override
  String get deviceDashboardPageToday => 'Heute';

  @override
  String get deviceDashboardPageLast7Days => 'Letzte 7 Tage';

  @override
  String get deviceDashboardPageAllTime => 'Alle Zeiten';

  @override
  String get deviceDashboardPageNoOutputData => 'Keine Ausgabedaten verfügbar';

  @override
  String get deviceDashboardPageNoHourlyData =>
      'Keine stündlichen Daten verfügbar';

  @override
  String get deviceDashboardPageNoDistributionData =>
      'Keine Verteilungsdaten verfügbar';

  @override
  String get deviceDashboardPageNoDataSelectedRange =>
      'Keine Daten für den ausgewählten Zeitraum verfügbar';

  @override
  String get assistantChat => 'Assistenten-Chat';

  @override
  String get typeYourMessage => 'Geben Sie Ihre Nachricht ein...';

  @override
  String errorInitializingChat(Object error) {
    return 'Fehler beim Initialisieren des Chats: $error';
  }

  @override
  String failedToGetResponse(Object response) {
    return 'Antwort konnte nicht abgerufen werden: $response';
  }

  @override
  String get espConfigTitle => 'ESP-Konfiguration';

  @override
  String get espConfigDescription =>
      'Konfigurieren Sie unten die Einstellungen Ihres ESP-Geräts.';

  @override
  String get espWifiSSID => 'WiFi-SSID';

  @override
  String get espWifiSSIDHint => 'Geben Sie den Namen des WiFi-Netzwerks ein';

  @override
  String get espWifiPassword => 'WiFi-Passwort';

  @override
  String get espWifiPasswordHint => 'Geben Sie das WiFi-Passwort ein';

  @override
  String get espSaveSettings => 'Einstellungen speichern';

  @override
  String get espSetupCameraLater => 'Kamera später einrichten';

  @override
  String get permissionsRequired => 'Berechtigungen benötigt';

  @override
  String get permissionsBluetoothLocationMessage =>
      'Bluetooth und GPS Berechtigungen werden zum verbinde der Kamera benötigt. Bitte geben sie diese Funktionen frei.';

  @override
  String get permissionsBluetoothMessage =>
      'Bluetooth Berechtigungen werden zum verbinde der Kamera benötigt. Bitte geben sie diese Funktionen frei.';

  @override
  String get espSetupCameraLaterExplanation =>
      'Sie können die Kamera sowohl jetzt als auch später einrichten';

  @override
  String get noCameraConnected => 'Keine Kamera verbunden';

  @override
  String get saveImages => 'Bilder speichern';

  @override
  String get saveImagesExplanation =>
      'Speichere aufgenommene Bilder im Gerätspeicher';

  @override
  String get motionTriggered => 'Bewegungsauslöser';

  @override
  String get motionTriggeredExplanation =>
      'Nimmt Bilder auf wenn Bewegung erkannt wird';

  @override
  String get hours => 'Stunden';

  @override
  String get minutes => 'Minuten';

  @override
  String get seconds => 'Sekunden';

  @override
  String get captureInterval => 'Aufnahme-Intervall';

  @override
  String get replace => 'Ersetzen';

  @override
  String get connectedCamera => 'Verbundene Kamera';

  @override
  String get openSettings => 'Einstellungen öffnen';

  @override
  String get toContinuePleaseEnable =>
      'Um fortzufahren, bitte folgendes anschalten:';

  @override
  String get swipeToAssignClass => 'Wischen zur Klassifizierung';

  @override
  String get dataCollectionMode => 'Daten sammeln';

  @override
  String get cameraPermissionDenied => 'Keine Kamera Berechtigung';

  @override
  String get testingMode => 'Testen';

  @override
  String get quickDataCapture => 'SwipeSight';

  @override
  String get quickDataCaptureExplanation => 'Daten Sammeln & Testen';

  @override
  String get tapToAssignClass => 'Tippen zum Klassifizieren';

  @override
  String get tapOrSwipeToAssign => 'Tippen oder Wischen zum Klassifizieren';

  @override
  String get testResult => 'Test Resultat';

  @override
  String get confidence => 'Sicherheit';

  @override
  String get detected => 'Erkannt';

  @override
  String get processingImage => 'Verarbeite Bild';

  @override
  String get retry => 'neu laden';

  @override
  String get listeningHint => 'höre zu...';

  @override
  String get speechNotAvailable => 'Sprache nicht verfügbar...';

  @override
  String get microphonePermissionDenied => 'Mikrofon Zugang benötigt';

  @override
  String get deviceConfigPageAdvancedSettings => 'Erweiterte Einstellung';

  @override
  String get deviceConfigPageEditDeviceInfo => 'Geräte Info Bearbeiten';

  @override
  String get noSpeechDetected => 'keine Sprache erkannt';

  @override
  String get testCamera => 'Test Kamera';

  @override
  String get testCameraDescription =>
      'Benutze deine Kamera um die KI zu testen';

  @override
  String get cameraTesting => 'Kamera testen';

  @override
  String get deviceConfigPageInferenceMode => 'Ausgabe Modus';

  @override
  String get notificationSettings => 'Benachrichtigungseinstellungen';

  @override
  String get notificationSettingsDescription =>
      'Konfigurieren Sie, wann Sie Benachrichtigungen erhalten';

  @override
  String get notificationConfigTitle => 'Benachrichtigungskonfiguration';

  @override
  String get notificationConfigDescription =>
      'Konfigurieren Sie, wann Sie für jede erkannte Klasse Benachrichtigungen erhalten.';

  @override
  String get countThreshold => 'Anzahlschwellenwert';

  @override
  String get locationTrigger => 'Standort';

  @override
  String get notifyWhenExceedsThreshold =>
      'Benachrichtigen, wenn die Anzahl den Schwellenwert überschreitet:';

  @override
  String get drawRegionToTrigger =>
      'Zeichnen Sie einen Bereich, um eine Benachrichtigung auszulösen:';

  @override
  String get saveSettings => 'Einstellungen speichern';

  @override
  String get settingsSaved => 'Benachrichtigungseinstellungen gespeichert';

  @override
  String errorSavingSettings(Object error) {
    return 'Fehler beim Speichern der Einstellungen: $error';
  }
}
