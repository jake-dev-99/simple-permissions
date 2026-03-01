/// Maps [Permission] sealed class types to Android [PermissionHandler]s.
///
/// This is the central dispatch table for the Android implementation. Every
/// concrete [Permission] type must have a registered handler. The registry
/// is queried by [SimplePermissionsAndroid] to resolve check/request calls.
library;

import 'package:simple_permissions_platform_interface/simple_permissions_platform_interface.dart';

import 'handlers/permission_handler.dart';

/// Android permission string constants.
///
/// Centralised here to avoid scatter and typos across handler registrations.
abstract final class AndroidPermission {
  // Camera
  static const camera = 'android.permission.CAMERA';

  // Location
  static const fineLocation = 'android.permission.ACCESS_FINE_LOCATION';
  static const coarseLocation = 'android.permission.ACCESS_COARSE_LOCATION';
  static const backgroundLocation =
      'android.permission.ACCESS_BACKGROUND_LOCATION';

  // Contacts
  static const readContacts = 'android.permission.READ_CONTACTS';
  static const writeContacts = 'android.permission.WRITE_CONTACTS';

  // Storage (pre-33 + granular 33+)
  static const readExternalStorage =
      'android.permission.READ_EXTERNAL_STORAGE';
  static const readMediaImages = 'android.permission.READ_MEDIA_IMAGES';
  static const readMediaVideo = 'android.permission.READ_MEDIA_VIDEO';
  static const readMediaAudio = 'android.permission.READ_MEDIA_AUDIO';
  static const readMediaVisualUserSelected =
      'android.permission.READ_MEDIA_VISUAL_USER_SELECTED';

  // Phone / Telephony
  static const readPhoneState = 'android.permission.READ_PHONE_STATE';
  static const readPhoneNumbers = 'android.permission.READ_PHONE_NUMBERS';
  static const callPhone = 'android.permission.CALL_PHONE';
  static const answerPhoneCalls = 'android.permission.ANSWER_PHONE_CALLS';
  static const manageOwnCalls = 'android.permission.MANAGE_OWN_CALLS';
  static const readCallLog = 'android.permission.READ_CALL_LOG';
  static const writeCallLog = 'android.permission.WRITE_CALL_LOG';

  // Messaging (SMS/MMS)
  static const sendSms = 'android.permission.SEND_SMS';
  static const readSms = 'android.permission.READ_SMS';
  static const receiveSms = 'android.permission.RECEIVE_SMS';
  static const receiveMms = 'android.permission.RECEIVE_MMS';
  static const receiveWapPush = 'android.permission.RECEIVE_WAP_PUSH';

  // Bluetooth (31+ granular, <31 legacy)
  static const bluetoothConnect = 'android.permission.BLUETOOTH_CONNECT';
  static const bluetoothScan = 'android.permission.BLUETOOTH_SCAN';
  static const bluetoothAdvertise = 'android.permission.BLUETOOTH_ADVERTISE';
  static const bluetooth = 'android.permission.BLUETOOTH';
  static const bluetoothAdmin = 'android.permission.BLUETOOTH_ADMIN';

  // Calendar
  static const readCalendar = 'android.permission.READ_CALENDAR';
  static const writeCalendar = 'android.permission.WRITE_CALENDAR';

  // Notification
  static const postNotifications = 'android.permission.POST_NOTIFICATIONS';

  // Microphone
  static const recordAudio = 'android.permission.RECORD_AUDIO';

  // Sensors
  static const bodySensors = 'android.permission.BODY_SENSORS';
  static const activityRecognition =
      'android.permission.ACTIVITY_RECOGNITION';

  // System
  static const scheduleExactAlarm = 'android.permission.SCHEDULE_EXACT_ALARM';
  static const requestInstallPackages =
      'android.permission.REQUEST_INSTALL_PACKAGES';
  static const systemAlertWindow = 'android.permission.SYSTEM_ALERT_WINDOW';

  // Wi-Fi
  static const nearbyWifiDevices = 'android.permission.NEARBY_WIFI_DEVICES';

  // Roles
  static const roleSms = 'android.app.role.SMS';
  static const roleDialer = 'android.app.role.DIALER';
  static const roleBrowser = 'android.app.role.BROWSER';
  static const roleAssistant = 'android.app.role.ASSISTANT';
}

/// Builds and returns the handler registry.
///
/// A fresh `Map` is returned each call, so callers can hold a reference without
/// worrying about shared mutation.
Map<Type, PermissionHandler> buildAndroidPermissionRegistry() {
  return <Type, PermissionHandler>{
    // =========================================================================
    // Camera
    // =========================================================================
    CameraAccess: const RuntimePermissionHandler(AndroidPermission.camera),

    // =========================================================================
    // Location
    // =========================================================================
    CoarseLocation: const RuntimePermissionHandler(
      AndroidPermission.coarseLocation,
    ),
    FineLocation: const RuntimePermissionHandler(
      AndroidPermission.fineLocation,
    ),
    BackgroundLocation: const RuntimePermissionHandler(
      AndroidPermission.backgroundLocation,
      minSdk: 29, // ACCESS_BACKGROUND_LOCATION added in API 29
    ),

    // =========================================================================
    // Contacts
    // =========================================================================
    ReadContacts: const RuntimePermissionHandler(
      AndroidPermission.readContacts,
    ),
    WriteContacts: const RuntimePermissionHandler(
      AndroidPermission.writeContacts,
    ),

    // =========================================================================
    // Storage — version-split at API 33 (TIRAMISU)
    // =========================================================================
    ReadExternalStorage: const RuntimePermissionHandler(
      AndroidPermission.readExternalStorage,
      maxSdk: 32,
    ),
    ReadMediaImages: const RuntimePermissionHandler(
      AndroidPermission.readMediaImages,
      minSdk: 33,
    ),
    ReadMediaVideo: const RuntimePermissionHandler(
      AndroidPermission.readMediaVideo,
      minSdk: 33,
    ),
    ReadMediaAudio: const RuntimePermissionHandler(
      AndroidPermission.readMediaAudio,
      minSdk: 33,
    ),
    ReadMediaVisualUserSelected: const RuntimePermissionHandler(
      AndroidPermission.readMediaVisualUserSelected,
      minSdk: 34,
    ),

    // =========================================================================
    // Phone / Telephony
    // =========================================================================
    ReadPhoneState: const RuntimePermissionHandler(
      AndroidPermission.readPhoneState,
    ),
    ReadPhoneNumbers: const RuntimePermissionHandler(
      AndroidPermission.readPhoneNumbers,
    ),
    MakeCalls: const RuntimePermissionHandler(AndroidPermission.callPhone),
    AnswerCalls: const RuntimePermissionHandler(
      AndroidPermission.answerPhoneCalls,
    ),
    ManageOwnCalls: const RuntimePermissionHandler(
      AndroidPermission.manageOwnCalls,
    ),
    ReadCallLog: const RuntimePermissionHandler(AndroidPermission.readCallLog),
    WriteCallLog: const RuntimePermissionHandler(
      AndroidPermission.writeCallLog,
    ),

    // =========================================================================
    // Messaging (SMS/MMS)
    // =========================================================================
    SendSms: const RuntimePermissionHandler(AndroidPermission.sendSms),
    ReadSms: const RuntimePermissionHandler(AndroidPermission.readSms),
    ReceiveSms: const RuntimePermissionHandler(AndroidPermission.receiveSms),
    ReceiveMms: const RuntimePermissionHandler(AndroidPermission.receiveMms),
    ReceiveWapPush: const RuntimePermissionHandler(
      AndroidPermission.receiveWapPush,
    ),

    // =========================================================================
    // Bluetooth — version-split at API 31 (S)
    // =========================================================================
    BluetoothConnect: const RuntimePermissionHandler(
      AndroidPermission.bluetoothConnect,
      minSdk: 31,
    ),
    BluetoothScan: const RuntimePermissionHandler(
      AndroidPermission.bluetoothScan,
      minSdk: 31,
    ),
    BluetoothAdvertise: const RuntimePermissionHandler(
      AndroidPermission.bluetoothAdvertise,
      minSdk: 31,
    ),
    BluetoothLegacy: const RuntimePermissionHandler(
      AndroidPermission.bluetooth,
      maxSdk: 30,
    ),
    BluetoothAdminLegacy: const RuntimePermissionHandler(
      AndroidPermission.bluetoothAdmin,
      maxSdk: 30,
    ),

    // =========================================================================
    // Calendar
    // =========================================================================
    ReadCalendar: const RuntimePermissionHandler(
      AndroidPermission.readCalendar,
    ),
    WriteCalendar: const RuntimePermissionHandler(
      AndroidPermission.writeCalendar,
    ),

    // =========================================================================
    // Notification — API 33+
    // =========================================================================
    PostNotifications: const RuntimePermissionHandler(
      AndroidPermission.postNotifications,
      minSdk: 33,
    ),

    // =========================================================================
    // Microphone
    // =========================================================================
    RecordAudio: const RuntimePermissionHandler(AndroidPermission.recordAudio),

    // =========================================================================
    // Sensors
    // =========================================================================
    BodySensors: const RuntimePermissionHandler(
      AndroidPermission.bodySensors,
    ),
    ActivityRecognition: const RuntimePermissionHandler(
      AndroidPermission.activityRecognition,
      minSdk: 29,
    ),

    // =========================================================================
    // System — special flows
    // =========================================================================
    BatteryOptimizationExemption: const SystemSettingHandler(
      SystemSettingType.batteryOptimization,
    ),
    // ScheduleExactAlarm, RequestInstallPackages, SystemAlertWindow require
    // settings-intent flows that aren't yet wired through Pigeon. Register
    // them as runtime permissions for now (the Kotlin side resolves them
    // correctly via isPermissionApplicable).
    ScheduleExactAlarm: const RuntimePermissionHandler(
      AndroidPermission.scheduleExactAlarm,
      minSdk: 31,
    ),
    RequestInstallPackages: const RuntimePermissionHandler(
      AndroidPermission.requestInstallPackages,
    ),
    SystemAlertWindow: const RuntimePermissionHandler(
      AndroidPermission.systemAlertWindow,
    ),

    // =========================================================================
    // Roles
    // =========================================================================
    DefaultSmsApp: const RoleHandler(AndroidPermission.roleSms),
    DefaultDialerApp: const RoleHandler(AndroidPermission.roleDialer),
    DefaultBrowserApp: const RoleHandler(AndroidPermission.roleBrowser),
    DefaultAssistantApp: const RoleHandler(AndroidPermission.roleAssistant),

    // =========================================================================
    // Wi-Fi — API 33+
    // =========================================================================
    NearbyWifiDevices: const RuntimePermissionHandler(
      AndroidPermission.nearbyWifiDevices,
      minSdk: 33,
    ),
  };
  // Note: TrackingPermission (AppTrackingTransparency), HealthPermission
  // (ReadHealth, WriteHealth) are intentionally NOT registered — they are
  // iOS-only concepts and will resolve to notApplicable on Android.
}
