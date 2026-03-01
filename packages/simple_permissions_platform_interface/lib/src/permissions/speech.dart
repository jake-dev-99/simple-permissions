part of 'permission.dart';

/// Permissions related to speech recognition.
sealed class SpeechPermission extends Permission {
  const SpeechPermission();
}

/// Access to on-device/system speech recognition authorization.
///
/// - **iOS**: `SFSpeechRecognizer` authorization (requires
///   `NSSpeechRecognitionUsageDescription`)
/// - **Android**: Not applicable in this plugin (no direct runtime equivalent)
/// - **macOS**: Not currently implemented in this plugin
class SpeechRecognition extends SpeechPermission {
  const SpeechRecognition();

  @override
  String get identifier => 'speech_recognition';
}
