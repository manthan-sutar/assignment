import 'package:flutter/material.dart';
import 'package:flutter_callkit_incoming/entities/entities.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'incoming_call_deduplication.dart';
import '../../presentation/pages/incoming_call_page.dart';

/// Shows incoming-call-style UI (full-screen on Android, CallKit on iOS) when app is in background/killed.
/// Call from FCM background handler and when receiving incoming_call in background.
class CallKitIncomingService {
  CallKitIncomingService._();

  static GlobalKey<NavigatorState>? _navigatorKey;

  /// Set once from main (MaterialApp navigatorKey). Used to push IncomingCallPage when user taps Accept.
  static void setNavigatorKey(GlobalKey<NavigatorState> key) {
    _navigatorKey = key;
  }

  /// Show native call-style incoming screen. Pass [data] from FCM (type, callId, callerName, etc.).
  static Future<void> showIncomingCall(Map<String, dynamic> data) async {
    final callId = data['callId'] as String? ?? '';
    final callerName = data['callerName'] as String? ?? 'Unknown';
    final channelName = data['channelName'] as String? ?? '';
    final callerId = data['callerId'] as String? ?? '';
    if (callId.isEmpty) return;

    final params = CallKitParams(
      id: callId,
      nameCaller: callerName,
      appName: 'Audio & Call App',
      handle: callerId.isNotEmpty ? callerId : callId,
      type: 0, // audio
      duration: 60000, // 1 min ring timeout
      extra: <String, dynamic>{
        'callId': callId,
        'callerName': callerName,
        'channelName': channelName,
        'callerId': callerId,
      },
      textAccept: 'Accept',
      textDecline: 'Decline',
      android: const AndroidParams(
        isCustomNotification: true,
        ringtonePath: 'system_ringtone_default',
        backgroundColor: '#0955fa',
        actionColor: '#4CAF50',
      ),
      ios: const IOSParams(iconName: 'CallKitLogo', handleType: 'generic'),
    );

    await FlutterCallkitIncoming.showCallkitIncoming(params);
  }

  /// Dismiss incoming call UI (e.g. after call ended or declined).
  static Future<void> endCall(String callId) async {
    await FlutterCallkitIncoming.endCall(callId);
  }

  /// Start listening to accept/decline. Call once after app is built (e.g. in main).
  static void listenToCallEvents() {
    FlutterCallkitIncoming.onEvent.listen((CallEvent? event) {
      if (event == null) return;
      switch (event.event) {
        case Event.actionCallAccept:
          _onAccept(event.body);
          break;
        case Event.actionCallDecline:
          _onDecline(event.body);
          break;
        case Event.actionCallEnded:
        case Event.actionCallTimeout:
          break;
        default:
          break;
      }
    });
  }

  static void _onAccept(Map<String, dynamic>? body) {
    if (body == null) return;
    final extra = body['extra'];
    if (extra is! Map<String, dynamic>) return;
    final callId = extra['callId'] as String? ?? '';
    final callerName = extra['callerName'] as String? ?? 'Unknown';
    final channelName = extra['channelName'] as String?;
    final callerId = extra['callerId'] as String?;
    if (callId.isEmpty) return;
    if (!IncomingCallDeduplication.shouldShow(callId)) return;
    if (IncomingCallDeduplication.isIncomingCallUIVisible) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _navigatorKey?.currentContext;
      if (ctx == null) return;
      IncomingCallDeduplication.setIncomingCallUIVisible(true);
      Navigator.of(ctx)
          .push(
            MaterialPageRoute<void>(
              builder: (_) => IncomingCallPage(
                callId: callId,
                callerName: callerName,
                channelName: channelName,
                callerId: callerId,
              ),
            ),
          )
          .then((_) {
            IncomingCallDeduplication.setIncomingCallUIVisible(false);
          });
    });
  }

  static void _onDecline(Map<String, dynamic>? body) {
    if (body == null) return;
    final id = body['id'] as String?;
    if (id != null && id.isNotEmpty) {
      endCall(id);
    }
  }
}
