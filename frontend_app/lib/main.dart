import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/config/firebase_config.dart';
import 'features/auth/data/datasources/auth_remote_datasource.dart';
import 'features/auth/data/datasources/auth_local_datasource.dart';
import 'features/auth/data/repositories/auth_repository_impl.dart';
import 'features/auth/domain/repositories/auth_repository.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/auth/presentation/bloc/auth_event.dart';
import 'features/auth/presentation/bloc/auth_state.dart';
import 'features/auth/presentation/pages/sign_in_page.dart';
import 'features/auth/presentation/pages/onboarding_page.dart';
import 'features/call/data/datasources/call_remote_datasource.dart';
import 'features/call/data/repositories/call_repository_impl.dart';
import 'features/call/data/services/fcm_service.dart';
import 'features/call/data/services/signaling_service.dart';
import 'features/call/domain/repositories/call_repository.dart';
import 'features/call/presentation/pages/dashboard_page.dart';
import 'features/live/data/repositories/live_repository_impl.dart';
import 'features/live/domain/repositories/live_repository.dart';
import 'features/call/data/services/callkit_incoming_service.dart';
import 'features/call/data/services/incoming_call_deduplication.dart';
import 'features/call/presentation/pages/incoming_call_page.dart';
import 'features/reels/domain/repositories/reels_repository.dart';
import 'features/reels/data/datasources/reels_remote_datasource.dart';
import 'features/reels/data/repositories/reels_repository_impl.dart';
import 'features/reels/presentation/bloc/reels_bloc.dart';
import 'features/live/presentation/bloc/live_hub/live_hub_bloc.dart';
import 'features/live/presentation/pages/live_hub_page.dart';

/// Top-level FCM background handler (required for background/terminated messages).
/// Shows call-style full-screen UI (CallKit on iOS, full-screen on Android) for incoming calls.
/// Must be data-only FCM (no notification payload) for this to run when app is in background.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint(
    'BG handler invoked: from=${message.from} data=${message.data} notification=${message.notification}',
  );
  await FirebaseConfig.initialize();
  final data = message.data;
  final type = data['type'];
  if (type != 'incoming_call') {
    debugPrint('BG handler: ignoring message with type=$type');
    return;
  }
  try {
    debugPrint(
      'BG handler: processing incoming_call callId=${data['callId']} callerName=${data['callerName']}',
    );
    await CallKitIncomingService.showIncomingCall(data);
    debugPrint('BG handler: CallKitIncomingService.showIncomingCall completed');
  } catch (e, st) {
    debugPrint('BG handler: CallKit showIncomingCall error: $e');
    debugPrint('$st');
  }
}

/**
 * Main Entry Point
 * Initializes Firebase, sets up dependency injection, and starts the app.
 * Kept in the root zone so Flutter's runApp() assertions are satisfied.
 */
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Global error handling hooks (optional, non-fatal filtering).
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
  };
  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    if (error is PlatformException) {
      final code = error.code.toLowerCase();
      final msg = (error.message ?? '').toLowerCase();
      if (code == 'abort' || msg.contains('loading interrupted')) {
        return true; // handled
      }
      if (msg.contains('already exists') || code.contains('already exists')) {
        return true; // handled
      }
    }
    return false; // let Flutter handle
  };

  // Initialize Firebase
  bool firebaseInitialized = false;
  try {
    await FirebaseConfig.initialize();
    firebaseInitialized = FirebaseConfig.isInitialized;
  } catch (e) {
    debugPrint('Firebase initialization error: $e');
    firebaseInitialized = false;
  }

  // Initialize SharedPreferences
  final prefs = await SharedPreferences.getInstance();

  final authLocalDataSource = AuthLocalDataSource(prefs);
  _authRepository = _createAuthRepository(
    prefs,
    firebaseInitialized,
    authLocalDataSource,
  );
  _reelsRepository = _createReelsRepository();
  _callRepository = CallRepositoryImpl(
    remoteDataSource: CallRemoteDataSource(),
    getIdToken: () => _authRepository!.getCurrentIdToken(),
  );
  _liveRepository = LiveRepositoryImpl(
    getIdToken: () => _authRepository!.getCurrentIdToken(),
  );

  FcmService? fcmService;
  SignalingService? signalingService;
  if (firebaseInitialized) {
    fcmService = FcmService(authRepository: _authRepository!);
    await fcmService.initialize();
    signalingService = SignalingService(authRepository: _authRepository!);
  }

  final navigatorKey = GlobalKey<NavigatorState>();
  CallKitIncomingService.setNavigatorKey(navigatorKey);
  CallKitIncomingService.listenToCallEvents();

  runApp(
    MyApp(
      firebaseInitialized: firebaseInitialized,
      fcmService: fcmService,
      signalingService: signalingService,
      navigatorKey: navigatorKey,
    ),
  );
}

/// Set in main() so they survive hot reload and are never null when used.
AuthRepository? _authRepository;
ReelsRepository? _reelsRepository;
CallRepository? _callRepository;
LiveRepository? _liveRepository;

/**
 * Create Auth Repository with all dependencies
 */
AuthRepository _createAuthRepository(
  SharedPreferences prefs,
  bool firebaseInitialized,
  AuthLocalDataSource localDataSource,
) {
  final remoteDataSource = AuthRemoteDataSource();

  // Only get FirebaseAuth instance if Firebase is initialized
  FirebaseAuth? firebaseAuth;
  if (firebaseInitialized) {
    try {
      firebaseAuth = FirebaseAuth.instance;
    } catch (e) {
      debugPrint('FirebaseAuth instance error: $e');
      firebaseAuth = null;
    }
  }

  return AuthRepositoryImpl(
    remoteDataSource: remoteDataSource,
    localDataSource: localDataSource,
    firebaseAuth: firebaseAuth,
  );
}

/**
 * Create Reels Repository (uses reels feed API with cursor + limit)
 */
ReelsRepository _createReelsRepository() {
  return ReelsRepositoryImpl(remoteDataSource: ReelsRemoteDataSource());
}

class MyApp extends StatelessWidget {
  final bool firebaseInitialized;
  final FcmService? fcmService;
  final SignalingService? signalingService;
  final GlobalKey<NavigatorState>? navigatorKey;

  const MyApp({
    super.key,
    required this.firebaseInitialized,
    this.fcmService,
    this.signalingService,
    this.navigatorKey,
  });

  @override
  Widget build(BuildContext context) {
    final authRepo = _authRepository;
    final reelsRepo = _reelsRepository;
    final callRepo = _callRepository;
    assert(authRepo != null, 'AuthRepository not set; ensure main() ran');
    assert(reelsRepo != null, 'ReelsRepository not set; ensure main() ran');
    assert(callRepo != null, 'CallRepository not set; ensure main() ran');

    final signalingChild = MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>(
          create: (context) {
            final bloc = AuthBloc(authRepository: authRepo!);
            if (firebaseInitialized) {
              bloc.add(const CheckAuthStatus());
            }
            return bloc;
          },
        ),
        BlocProvider<ReelsBloc>(
          create: (context) => ReelsBloc(reelsRepository: reelsRepo!),
        ),
        BlocProvider<LiveHubBloc>(
          create: (context) =>
              LiveHubBloc(liveRepository: context.read<LiveRepository>()),
        ),
      ],
      child: MaterialApp(
        navigatorKey: navigatorKey,
        title: 'Audio & Call App',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
          useMaterial3: true,
        ),
        home: firebaseInitialized
            ? BlocListener<AuthBloc, AuthState>(
                listener: (context, state) {
                  if (state is AuthAuthenticated) {
                    fcmService?.subscribeToLiveTopic();
                  }
                },
                child: BlocBuilder<AuthBloc, AuthState>(
                  builder: (context, state) {
                    if (state is AuthAuthenticated) {
                      final needsOnboarding =
                          state.user.displayName == null ||
                          state.user.displayName!.trim().isEmpty;
                      return _ConnectionReadyGate(
                        navigatorKey: navigatorKey,
                        child: _IncomingCallListener(
                          navigatorKey: navigatorKey,
                          child: needsOnboarding
                              ? const OnboardingPage()
                              : const DashboardPage(),
                        ),
                      );
                    }
                    // No full-screen loader: show sign-in immediately.
                    // Auth check runs in background; we switch to dashboard when authenticated.
                    return const SignInPage();
                  },
                ),
              )
            : const _FirebaseNotConfiguredPage(),
      ),
    );
    Widget child = signalingChild;
    if (firebaseInitialized && fcmService != null) {
      child = RepositoryProvider<FcmService>.value(
        value: fcmService!,
        child: child,
      );
    }
    if (firebaseInitialized && signalingService != null) {
      child = RepositoryProvider<SignalingService>.value(
        value: signalingService!,
        child: child,
      );
    }
    final liveRepo = _liveRepository;
    assert(liveRepo != null, 'LiveRepository not set');
    return RepositoryProvider<AuthRepository>.value(
      value: authRepo!,
      child: RepositoryProvider<CallRepository>.value(
        value: callRepo!,
        child: RepositoryProvider<LiveRepository>.value(
          value: liveRepo!,
          child: child,
        ),
      ),
    );
  }
}

/// Waits for FCM token upload and signaling connection before showing [child].
/// Fixes first-login: callee is ready to receive calls before dashboard is shown.
class _ConnectionReadyGate extends StatefulWidget {
  const _ConnectionReadyGate({required this.navigatorKey, required this.child});

  final GlobalKey<NavigatorState>? navigatorKey;
  final Widget child;

  @override
  State<_ConnectionReadyGate> createState() => _ConnectionReadyGateState();
}

class _ConnectionReadyGateState extends State<_ConnectionReadyGate>
    with WidgetsBindingObserver {
  bool _ready = false;
  bool _started = false;

  static const int _fcmUploadMaxAttempts = 3;
  static const Duration _retryDelay = Duration(seconds: 2);

  Future<void> _ensureReady() async {
    // Brief delay so auth/FCM are ready after first sign-in (avoids first-install race).
    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    // Retry FCM token upload so server has token for incoming push.
    final fcm = context.read<FcmService>();
    for (var attempt = 1; attempt <= _fcmUploadMaxAttempts; attempt++) {
      if (!mounted) return;
      try {
        await fcm.uploadTokenToBackend();
        break;
      } catch (e) {
        if (kDebugMode) {
          debugPrint(
            'ConnectionReadyGate: FCM upload attempt $attempt/$_fcmUploadMaxAttempts failed: $e',
          );
        }
        if (attempt < _fcmUploadMaxAttempts) {
          await Future<void>.delayed(_retryDelay);
        }
      }
    }
    if (!mounted) return;
    // Connect signaling (with retry once on timeout) so WebSocket can deliver incoming_call.
    final signaling = context.read<SignalingService>();
    for (var attempt = 1; attempt <= 2; attempt++) {
      if (!mounted) return;
      try {
        await signaling.connect();
        break;
      } catch (e) {
        if (kDebugMode) {
          debugPrint(
            'ConnectionReadyGate: signaling connect attempt $attempt/2 failed: $e',
          );
        }
        if (attempt < 2) await Future<void>.delayed(_retryDelay);
      }
    }
    if (mounted) setState(() => _ready = true);
  }

  void _onAppResumed() {
    if (!_ready || !mounted) return;
    // Re-upload FCM token and reconnect signaling when app comes to foreground
    // so we recover from failed first attempt or stale connection.
    final fcm = context.read<FcmService>();
    fcm.uploadTokenToBackend();
    final signaling = context.read<SignalingService>();
    if (!signaling.isConnected) signaling.connect();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _onAppResumed();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _ensureReady();
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Preparing…'),
            ],
          ),
        ),
      );
    }
    return widget.child;
  }
}

/// Listens to WebSocket and FCM for incoming_call and pushes [IncomingCallPage].
class _IncomingCallListener extends StatefulWidget {
  const _IncomingCallListener({
    required this.navigatorKey,
    required this.child,
  });

  final GlobalKey<NavigatorState>? navigatorKey;
  final Widget child;

  @override
  State<_IncomingCallListener> createState() => _IncomingCallListenerState();
}

class _IncomingCallListenerState extends State<_IncomingCallListener> {
  StreamSubscription<IncomingCallPayload>? _wsSub;
  StreamSubscription<RemoteMessage>? _fcmSub;
  StreamSubscription<RemoteMessage>? _fcmOpenedSub;

  void _navigateToLiveHub() {
    if (!mounted) return;
    final nav = widget.navigatorKey?.currentState;
    if (nav == null) return;
    try {
      final liveHubBloc = context.read<LiveHubBloc>();
      nav.push(
        MaterialPageRoute<void>(
          builder: (_) => BlocProvider<LiveHubBloc>.value(
            value: liveHubBloc,
            child: const LiveHubPage(),
          ),
        ),
      );
    } catch (e) {
      if (kDebugMode)
        debugPrint('IncomingCallListener: could not navigate to live hub: $e');
    }
  }

  void _pushIncomingCallPage({
    required String callId,
    required String callerName,
    String? channelName,
    String? callerId,
  }) {
    if (!mounted) return;
    if (!IncomingCallDeduplication.shouldShow(callId)) return;
    if (IncomingCallDeduplication.isIncomingCallUIVisible) return;
    final nav = widget.navigatorKey?.currentState ?? Navigator.of(context);
    IncomingCallDeduplication.setIncomingCallUIVisible(true);
    nav
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
          IncomingCallDeduplication.onIncomingCallDismissed(callId);
        });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_wsSub != null) return;
    IncomingCallDeduplication.setIncomingCallUIVisible(false);
    // WebSocket: subscribe so in-app incoming call shows when app is in foreground
    try {
      final signaling = context.read<SignalingService>();
      _wsSub = signaling.incomingCall.listen((payload) {
        if (!mounted) return;
        _pushIncomingCallPage(
          callId: payload.callId,
          callerName: payload.callerName,
          channelName: payload.channelName,
          callerId: payload.callerId,
        );
      });
    } catch (e, st) {
      debugPrint('IncomingCallListener: SignalingService not available: $e');
      if (kDebugMode) debugPrint('$st');
    }
    // FCM foreground: same for data messages when app is open
    try {
      final fcm = context.read<FcmService>();
      _fcmSub = fcm.foregroundMessages.listen((message) {
        final data = message.data;
        if (!mounted) return;
        if (data['type'] == 'live_started') {
          _navigateToLiveHub();
          return;
        }
        if (data['type'] != 'incoming_call') return;
        final callId = (data['callId'] as String?) ?? '';
        final callerName = (data['callerName'] as String?) ?? 'Unknown';
        final channelName = data['channelName'] as String?;
        final callerId = data['callerId'] as String?;
        _pushIncomingCallPage(
          callId: callId,
          callerName: callerName,
          channelName: channelName,
          callerId: callerId,
        );
      });
      _fcmOpenedSub = FirebaseMessaging.onMessageOpenedApp.listen((message) {
        final data = message.data;
        if (data['type'] == 'live_started' && mounted) _navigateToLiveHub();
      });
    } catch (e, st) {
      debugPrint('IncomingCallListener: FcmService not available: $e');
      if (kDebugMode) debugPrint('$st');
    }
    _handleInitialFcmMessage();
  }

  /// When app was opened from a notification tap (background/killed), open IncomingCallPage
  /// or LiveHubPage depending on message type.
  Future<void> _handleInitialFcmMessage() async {
    final message = await FirebaseMessaging.instance.getInitialMessage();
    if (message == null || !mounted) return;
    final data = message.data;
    if (data['type'] == 'live_started') {
      _navigateToLiveHub();
      return;
    }
    if (data['type'] != 'incoming_call') return;
    final callId = data['callId'] as String?;
    if (callId == null || callId.isEmpty) return;
    if (!mounted) return;
    CallRepository callRepo;
    try {
      callRepo = context.read<CallRepository>();
    } catch (e) {
      debugPrint('IncomingCallListener: CallRepository not available: $e');
      return;
    }
    final callerNameFromPayload = (data['callerName'] as String?) ?? 'Unknown';
    final channelName = data['channelName'] as String?;
    final callerId = data['callerId'] as String?;
    try {
      final offer = await callRepo.getOffer(callId);
      if (!mounted) return;
      // Don't show incoming screen for ended/cancelled calls (stale notification).
      if (offer == null || (offer['status'] as String?) != 'ringing') return;
      if (!IncomingCallDeduplication.shouldShow(callId)) return;
      if (IncomingCallDeduplication.isIncomingCallUIVisible) return;
      final nav = widget.navigatorKey?.currentState ?? Navigator.of(context);
      IncomingCallDeduplication.setIncomingCallUIVisible(true);
      nav
          .push(
            MaterialPageRoute<void>(
              builder: (_) => IncomingCallPage(
                callId: callId,
                callerName:
                    (offer['callerName'] as String?) ?? callerNameFromPayload,
                channelName: (offer['channelName'] as String?) ?? channelName,
                callerId: callerId,
              ),
            ),
          )
          .then((_) {
            IncomingCallDeduplication.setIncomingCallUIVisible(false);
            IncomingCallDeduplication.onIncomingCallDismissed(callId);
          });
    } catch (e) {
      debugPrint('IncomingCallListener: getOffer failed: $e');
      IncomingCallDeduplication.onIncomingCallDismissed(callId);
    }
  }

  @override
  void dispose() {
    _wsSub?.cancel();
    _fcmSub?.cancel();
    _fcmOpenedSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/**
 * Firebase Not Configured Page
 * Shown when Firebase is not properly configured
 */
class _FirebaseNotConfiguredPage extends StatelessWidget {
  const _FirebaseNotConfiguredPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.error_outline, size: 80, color: Colors.red),
              const SizedBox(height: 24),
              const Text(
                'Firebase Not Configured',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Text(
                'Please configure Firebase to use the app:\n\n'
                '1. Run: \$HOME/.pub-cache/bin/flutterfire configure\n'
                '2. Select your Firebase project\n'
                '3. Restart the app',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey[700]),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () {
                  // Instructions are already shown above
                  // User needs to run: flutterfire configure
                },
                child: const Text('Got it'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
