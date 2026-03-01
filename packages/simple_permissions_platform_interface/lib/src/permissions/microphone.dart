part of 'permission.dart';

/// Permissions related to microphone / audio recording.
sealed class MicrophonePermission extends Permission {
  const MicrophonePermission();
}

/// Record audio using the device microphone.
///
/// - **Android**: `android.permission.RECORD_AUDIO`
/// - **iOS**: `AVAudioSession.RecordPermission`
/// - **macOS**: `AVCaptureDevice` microphone authorization
class RecordAudio extends MicrophonePermission {
  const RecordAudio();

  @override
  String get identifier => 'record_audio';
}
