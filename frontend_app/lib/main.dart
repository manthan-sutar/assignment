import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
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

/// Top-level FCM background handler (required for background/terminated messages).
/// Shows call-style full-screen UI (CallKit on iOS, full-screen on Android) for incoming calls.
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await FirebaseConfig.initialize();
  final data = message.data;
  if (data['type'] == 'incoming_call') {
    try {
      await CallKitIncomingService.showIncomingCall(data);
    } catch (e) {
      debugPrint('CallKit showIncomingCall error: $e');
    }
  }
}

/**
 * Main Entry Point
 * Initializes Firebase, sets up dependency injection, and starts the app.
 * All of this runs in the same zone so Flutter bindings and runApp stay consistent.
 */
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  runZonedGuarded(
    () async {
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
      _reelsRepository = _createReelsRepository(authLocalDataSource);
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
    },
    (error, stack) {
      if (error is PlatformException) {
        final code = error.code.toLowerCase();
        final msg = (error.message ?? '').toLowerCase();
        if (code == 'abort' || msg.contains('loading interrupted')) return;
        if (msg.contains('already exists') || code.contains('already exists'))
          return;
      }
      throw error;
    },
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
 * Create Reels Repository (depends on auth local for API token)
 */
ReelsRepository _createReelsRepository(
  AuthLocalDataSource authLocalDataSource,
) {
  return ReelsRepositoryImpl(
    remoteDataSource: ReelsRemoteDataSource(),
    authLocalDataSource: authLocalDataSource,
  );
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
                    fcmService?.uploadTokenToBackend();
                    signalingService?.connect();
                  }
                },
                child: BlocBuilder<AuthBloc, AuthState>(
                  builder: (context, state) {
                    if (state is AuthAuthenticated) {
                      final needsOnboarding =
                          state.user.displayName == null ||
                          state.user.displayName!.trim().isEmpty;
                      return _IncomingCallListener(
                        child: needsOnboarding
                            ? const OnboardingPage()
                            : const DashboardPage(),
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

/// Listens to WebSocket and FCM for incoming_call and pushes [IncomingCallPage].
class _IncomingCallListener extends StatefulWidget {
  const _IncomingCallListener({required this.child});

  final Widget child;

  @override
  State<_IncomingCallListener> createState() => _IncomingCallListenerState();
}

class _IncomingCallListenerState extends State<_IncomingCallListener> {
  StreamSubscription<IncomingCallPayload>? _wsSub;
  StreamSubscription<RemoteMessage>? _fcmSub;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_wsSub != null) return;
    // First mount (or after hot restart): reset so hot reload doesn't leave flag stuck
    IncomingCallDeduplication.setIncomingCallUIVisible(false);
    try {
      final signaling = context.read<SignalingService>();
      _wsSub = signaling.incomingCall.listen((payload) {
        if (!mounted) return;
        if (!IncomingCallDeduplication.shouldShow(payload.callId)) return;
        if (IncomingCallDeduplication.isIncomingCallUIVisible) return;
        IncomingCallDeduplication.setIncomingCallUIVisible(true);
        Navigator.of(context)
            .push(
              MaterialPageRoute<void>(
                builder: (_) => IncomingCallPage(
                  callId: payload.callId,
                  callerName: payload.callerName,
                  channelName: payload.channelName,
                  callerId: payload.callerId,
                ),
              ),
            )
            .then((_) {
              IncomingCallDeduplication.setIncomingCallUIVisible(false);
            });
      });
    } catch (_) {}
    try {
      final fcm = context.read<FcmService>();
      _fcmSub = fcm.foregroundMessages.listen((message) {
        final data = message.data;
        if (data['type'] != 'incoming_call') return;
        if (!mounted) return;
        final callId = (data['callId'] as String?) ?? '';
        if (!IncomingCallDeduplication.shouldShow(callId)) return;
        if (IncomingCallDeduplication.isIncomingCallUIVisible) return;
        IncomingCallDeduplication.setIncomingCallUIVisible(true);
        Navigator.of(context)
            .push(
              MaterialPageRoute<void>(
                builder: (_) => IncomingCallPage(
                  callId: callId,
                  callerName: (data['callerName'] as String?) ?? 'Unknown',
                  channelName: data['channelName'] as String?,
                  callerId: data['callerId'] as String?,
                ),
              ),
            )
            .then((_) {
              IncomingCallDeduplication.setIncomingCallUIVisible(false);
            });
      });
    } catch (_) {}
    _handleInitialFcmMessage();
  }

  /// When app was opened from a notification tap (background/killed), open IncomingCallPage
  /// only if the offer is still valid (ringing). Avoids false/stale call on restart.
  Future<void> _handleInitialFcmMessage() async {
    final message = await FirebaseMessaging.instance.getInitialMessage();
    if (message == null || !mounted) return;
    final data = message.data;
    if (data['type'] != 'incoming_call') return;
    final callId = data['callId'] as String?;
    if (callId == null || callId.isEmpty) return;
    if (!IncomingCallDeduplication.shouldShow(callId)) return;
    if (!mounted) return;
    final nav = Navigator.of(context);
    final callRepo = context.read<CallRepository>();
    final callerNameFromPayload = (data['callerName'] as String?) ?? 'Unknown';
    final channelName = data['channelName'] as String?;
    final callerId = data['callerId'] as String?;
    try {
      final offer = await callRepo.getOffer(callId);
      if (!mounted) return;
      if (offer == null || (offer['status'] as String?) != 'ringing') {
        return;
      }
      if (IncomingCallDeduplication.isIncomingCallUIVisible) return;
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
          });
    } catch (_) {}
  }

  @override
  void dispose() {
    _wsSub?.cancel();
    _fcmSub?.cancel();
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
