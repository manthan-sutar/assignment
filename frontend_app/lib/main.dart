import 'package:flutter/material.dart';
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
import 'features/call/presentation/pages/dashboard_page.dart';
import 'features/reels/domain/repositories/reels_repository.dart';
import 'features/reels/data/datasources/reels_remote_datasource.dart';
import 'features/reels/data/repositories/reels_repository_impl.dart';
import 'features/reels/presentation/bloc/reels_bloc.dart';

/**
 * Main Entry Point
 * Initializes Firebase, sets up dependency injection, and starts the app
 */
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

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

  runApp(MyApp(firebaseInitialized: firebaseInitialized));
}

/// Set in main() so they survive hot reload and are never null when used.
AuthRepository? _authRepository;
ReelsRepository? _reelsRepository;

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

  const MyApp({super.key, required this.firebaseInitialized});

  @override
  Widget build(BuildContext context) {
    final authRepo = _authRepository;
    final reelsRepo = _reelsRepository;
    assert(authRepo != null, 'AuthRepository not set; ensure main() ran');
    assert(reelsRepo != null, 'ReelsRepository not set; ensure main() ran');

    return MultiBlocProvider(
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
      ],
      child: MaterialApp(
        title: 'Audio & Call App',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
          useMaterial3: true,
        ),
        home: firebaseInitialized
            ? BlocBuilder<AuthBloc, AuthState>(
                builder: (context, state) {
                  if (state is AuthAuthenticated) {
                    return const DashboardPage();
                  } else if (state is AuthInitial) {
                    // Full-screen loader only for initial auth check on app start
                    return const Scaffold(
                      body: Center(child: CircularProgressIndicator()),
                    );
                  } else {
                    // AuthLoading: keep sign-in flow visible (loaders on buttons).
                    // Other states: show sign-in page.
                    return const SignInPage();
                  }
                },
              )
            : const _FirebaseNotConfiguredPage(),
      ),
    );
  }
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
