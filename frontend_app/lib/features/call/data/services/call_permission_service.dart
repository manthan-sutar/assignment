import 'package:permission_handler/permission_handler.dart';

/// Handles microphone (and optional camera) permissions for Agora calls and streaming.
class CallPermissionService {
  /// Request microphone permission. Returns true if granted or already granted.
  Future<bool> requestMicrophone() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  /// Check if microphone permission is granted (without requesting).
  Future<bool> get isMicrophoneGranted async {
    return await Permission.microphone.isGranted;
  }

  /// Open app settings (e.g. when user previously denied).
  Future<bool> openSettings() => openAppSettings();
}
