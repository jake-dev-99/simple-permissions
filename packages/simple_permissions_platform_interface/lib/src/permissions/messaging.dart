part of 'permission.dart';

/// Permissions related to SMS/MMS messaging.
sealed class MessagingPermission extends Permission {
  const MessagingPermission();
}

/// Send SMS messages.
///
/// - **Android**: `android.permission.SEND_SMS`
/// - **iOS**: Not applicable (uses MFMessageComposeViewController)
class SendSms extends MessagingPermission {
  const SendSms();

  @override
  String get identifier => 'send_sms';
}

/// Read SMS messages from the device inbox.
///
/// - **Android**: `android.permission.READ_SMS`
/// - **iOS**: Not applicable
class ReadSms extends MessagingPermission {
  const ReadSms();

  @override
  String get identifier => 'read_sms';
}

/// Receive incoming SMS messages via broadcast.
///
/// - **Android**: `android.permission.RECEIVE_SMS`
/// - **iOS**: Not applicable
class ReceiveSms extends MessagingPermission {
  const ReceiveSms();

  @override
  String get identifier => 'receive_sms';
}

/// Receive incoming MMS messages.
///
/// - **Android**: `android.permission.RECEIVE_MMS`
/// - **iOS**: Not applicable
class ReceiveMms extends MessagingPermission {
  const ReceiveMms();

  @override
  String get identifier => 'receive_mms';
}

/// Receive WAP push messages.
///
/// - **Android**: `android.permission.RECEIVE_WAP_PUSH`
/// - **iOS**: Not applicable
class ReceiveWapPush extends MessagingPermission {
  const ReceiveWapPush();

  @override
  String get identifier => 'receive_wap_push';
}
