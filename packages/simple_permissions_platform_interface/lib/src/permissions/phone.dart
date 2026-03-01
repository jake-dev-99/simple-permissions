part of 'permission.dart';

/// Permissions related to phone/telephony access.
sealed class PhonePermission extends Permission {
  const PhonePermission();
}

/// Read the phone state (IMEI, network info, call state).
///
/// - **Android**: `android.permission.READ_PHONE_STATE`
/// - **iOS**: Not applicable (no equivalent concept)
class ReadPhoneState extends PhonePermission {
  const ReadPhoneState();

  @override
  String get identifier => 'read_phone_state';
}

/// Read the device's own phone number(s).
///
/// - **Android**: `android.permission.READ_PHONE_NUMBERS` (API 26+)
/// - **iOS**: Not applicable
class ReadPhoneNumbers extends PhonePermission {
  const ReadPhoneNumbers();

  @override
  String get identifier => 'read_phone_numbers';
}

/// Initiate phone calls.
///
/// - **Android**: `android.permission.CALL_PHONE`
/// - **iOS**: Not applicable (uses tel: URL scheme)
class MakeCalls extends PhonePermission {
  const MakeCalls();

  @override
  String get identifier => 'make_calls';
}

/// Answer incoming phone calls programmatically.
///
/// - **Android**: `android.permission.ANSWER_PHONE_CALLS` (API 26+)
/// - **iOS**: Not applicable (CallKit handles this)
class AnswerCalls extends PhonePermission {
  const AnswerCalls();

  @override
  String get identifier => 'answer_calls';
}

/// Manage the app's own calls via the self-managed ConnectionService API.
///
/// - **Android**: `android.permission.MANAGE_OWN_CALLS` (API 26+)
/// - **iOS**: Not applicable
class ManageOwnCalls extends PhonePermission {
  const ManageOwnCalls();

  @override
  String get identifier => 'manage_own_calls';
}

/// Read the device call log.
///
/// - **Android**: `android.permission.READ_CALL_LOG`
/// - **iOS**: Not applicable (no system call log API)
class ReadCallLog extends PhonePermission {
  const ReadCallLog();

  @override
  String get identifier => 'read_call_log';
}

/// Write to the device call log.
///
/// - **Android**: `android.permission.WRITE_CALL_LOG`
/// - **iOS**: Not applicable
class WriteCallLog extends PhonePermission {
  const WriteCallLog();

  @override
  String get identifier => 'write_call_log';
}

/// Read voicemail messages.
///
/// - **Android**: `android.permission.READ_VOICEMAIL`
/// - **iOS**: Not applicable
class ReadVoicemail extends PhonePermission {
  const ReadVoicemail();

  @override
  String get identifier => 'read_voicemail';
}

/// Add voicemail entries.
///
/// - **Android**: `android.permission.ADD_VOICEMAIL`
/// - **iOS**: Not applicable
class AddVoicemail extends PhonePermission {
  const AddVoicemail();

  @override
  String get identifier => 'add_voicemail';
}

/// Accept call handover from another app.
///
/// - **Android**: `android.permission.ACCEPT_HANDOVER`
/// - **iOS**: Not applicable
class AcceptHandover extends PhonePermission {
  const AcceptHandover();

  @override
  String get identifier => 'accept_handover';
}
