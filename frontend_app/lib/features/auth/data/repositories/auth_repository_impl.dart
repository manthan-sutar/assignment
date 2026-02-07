import 'dart:async';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../../domain/entities/display_user_entity.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_datasource.dart';
import '../datasources/auth_local_datasource.dart';
import '../../../../core/errors/auth_exceptions.dart';

/**
 * Auth Repository Implementation
 * Implements AuthRepository interface
 * Handles Firebase Phone Auth and backend API communication
 */
class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource remoteDataSource;
  final AuthLocalDataSource localDataSource;
  final FirebaseAuth? firebaseAuth;
  String? _verificationId;
  String? _phoneNumber;

  AuthRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
    required this.firebaseAuth,
  });

  /// Check if Firebase Auth is available
  void _checkFirebaseAuth() {
    if (firebaseAuth == null) {
      throw SignInException(
        'Firebase is not initialized. Please configure Firebase first.',
      );
    }
  }

  @override
  Future<String> sendOTP(String phoneNumber) async {
    _checkFirebaseAuth();
    try {
      _phoneNumber = phoneNumber;
      _verificationId = null; // Reset verification ID

      // Use Completer to wait for the codeSent callback
      final completer = Completer<String>();

      // Send OTP to phone number
      firebaseAuth!.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) async {
          // Auto-verification completed (Android auto-retrieval)
          // For test numbers, codeSent should still be called first
        },
        verificationFailed: (FirebaseAuthException e) {
          if (!completer.isCompleted) {
            completer.completeError(
              SignInException('Verification failed: ${e.message}'),
            );
          }
        },
        codeSent: (String verificationId, int? resendToken) {
          _verificationId = verificationId;
          if (!completer.isCompleted) {
            completer.complete(verificationId);
          }
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
          // Fallback: if codeSent wasn't called, use this
          if (!completer.isCompleted) {
            completer.complete(verificationId);
          }
        },
        timeout: const Duration(seconds: 60),
      );

      // Wait for the codeSent callback
      // Use a reasonable timeout that's longer than the Firebase timeout
      try {
        final verificationId = await completer.future.timeout(
          const Duration(seconds: 70), // Slightly longer than Firebase timeout
          onTimeout: () {
            // If we have verificationId from codeAutoRetrievalTimeout, use it
            if (_verificationId != null) {
              return _verificationId!;
            }
            throw SignInException(
              'OTP request timed out. Please check your phone number and try again.',
            );
          },
        );
        return verificationId;
      } catch (e) {
        if (e is SignInException) rethrow;
        // Final check: if we have verificationId, return it
        if (_verificationId != null) {
          return _verificationId!;
        }
        throw SignInException('Failed to send OTP: ${e.toString()}');
      }
    } catch (e) {
      if (e is SignInException) rethrow;
      throw SignInException('Failed to send OTP: ${e.toString()}');
    }
  }

  @override
  Future<UserEntity?> verifyOTPAndSignIn(
    String verificationId,
    String otp,
  ) async {
    try {
      // Create credential from verification ID and OTP
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: otp,
      );

      _checkFirebaseAuth();
      // Sign in with credential
      final userCredential = await firebaseAuth!.signInWithCredential(
        credential,
      );

      if (userCredential.user == null) {
        throw SignInException('Failed to sign in');
      }

      // Get Firebase ID token
      final idToken = await userCredential.user?.getIdToken();
      if (idToken == null) {
        throw SignInException('Failed to get Firebase token');
      }

      // Call backend to check if user exists
      final userModel = await remoteDataSource.signIn(idToken);

      if (userModel != null) {
        // User exists - save to local storage
        await localDataSource.saveUser(userModel);
        await localDataSource.saveToken(idToken);
        return userModel.toEntity();
      } else {
        // User not found - keep Firebase user signed in (OTP was verified)
        // Don't sign out - we need the Firebase user for sign-up
        // Store the ID token temporarily so we can use it for sign-up
        await localDataSource.saveToken(idToken);
        return null;
      }
    } catch (e) {
      if (e is SignInException) rethrow;
      throw SignInException('OTP verification failed: ${e.toString()}');
    }
  }

  @override
  Future<UserEntity> signUpWithPhone(bool consent) async {
    if (!consent) {
      throw SignUpException('User consent is required');
    }

    _checkFirebaseAuth();
    try {
      // For sign-up after OTP verification, user should already be signed in to Firebase
      // So we just need to call backend sign-up endpoint
      final firebaseUser = firebaseAuth!.currentUser;
      if (firebaseUser == null) {
        throw SignUpException('User not authenticated');
      }

      final idToken = await firebaseUser.getIdToken();
      if (idToken == null) {
        throw SignUpException('Failed to get Firebase token');
      }

      // Call backend to create user
      final userModel = await remoteDataSource.signUp(idToken, consent);

      // Save to local storage
      await localDataSource.saveUser(userModel);
      await localDataSource.saveToken(idToken);

      return userModel.toEntity();
    } catch (e) {
      if (e is SignUpException) rethrow;
      throw SignUpException('Sign up failed: ${e.toString()}');
    }
  }

  @override
  Future<UserEntity?> getCurrentUser() async {
    try {
      // Check local storage first
      final localUser = await localDataSource.getUser();
      if (localUser != null) {
        return localUser.toEntity();
      }

      // Check Firebase Auth
      if (firebaseAuth == null) {
        return null;
      }
      final firebaseUser = firebaseAuth!.currentUser;
      if (firebaseUser != null) {
        final idToken = await firebaseUser.getIdToken();
        if (idToken != null) {
          // Verify with backend
          final userModel = await remoteDataSource.signIn(idToken);
          if (userModel != null) {
            await localDataSource.saveUser(userModel);
            return userModel.toEntity();
          }
        }
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  @override
  Future<void> signOut() async {
    try {
      if (firebaseAuth != null) {
        await firebaseAuth!.signOut();
      }
      await localDataSource.clearAuthData();
      _verificationId = null;
      _phoneNumber = null;
    } catch (e) {
      throw Exception('Sign out failed: ${e.toString()}');
    }
  }

  @override
  Future<String?> getCurrentIdToken() async {
    try {
      final token = await localDataSource.getToken();
      if (token != null && token.isNotEmpty) return token;
      if (firebaseAuth == null) return null;
      final firebaseUser = firebaseAuth!.currentUser;
      if (firebaseUser == null) return null;
      final idToken = await firebaseUser.getIdToken();
      if (idToken != null) await localDataSource.saveToken(idToken);
      return idToken;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<bool> isAuthenticated() async {
    final user = await getCurrentUser();
    return user != null;
  }

  @override
  Future<Map<String, String>?> getFirebaseUserInfo() async {
    if (firebaseAuth == null) {
      return null;
    }
    final firebaseUser = firebaseAuth!.currentUser;
    if (firebaseUser != null) {
      return {
        'uid': firebaseUser.uid,
        'phoneNumber': firebaseUser.phoneNumber ?? '',
      };
    }
    return null;
  }

  @override
  Future<UserEntity> updateProfile(
    String displayName, {
    String? photoPath,
  }) async {
    _checkFirebaseAuth();
    var token = await localDataSource.getToken();
    if (token == null || token.isEmpty) {
      final firebaseUser = firebaseAuth!.currentUser;
      if (firebaseUser == null) {
        throw ProfileUpdateException('Not signed in');
      }
      final idToken = await firebaseUser.getIdToken();
      if (idToken == null) {
        throw ProfileUpdateException('Failed to get token');
      }
      await localDataSource.saveToken(idToken);
      token = idToken;
    }
    final idToken = await localDataSource.getToken();
    if (idToken == null || idToken.isEmpty) {
      throw ProfileUpdateException('Not signed in');
    }
    final File? file = (photoPath != null && photoPath.isNotEmpty)
        ? File(photoPath)
        : null;
    try {
      final userModel = await remoteDataSource.updateProfile(
        idToken,
        displayName,
        photoFile: file,
      );
      await localDataSource.saveUser(userModel);
      return userModel.toEntity();
    } catch (e) {
      if (e is ProfileUpdateException) rethrow;
      throw ProfileUpdateException('Profile update failed: ${e.toString()}');
    }
  }

  @override
  Future<List<DisplayUserEntity>> getUsers() async {
    final token = await localDataSource.getToken();
    if (token == null || token.isEmpty) {
      if (firebaseAuth != null && firebaseAuth!.currentUser != null) {
        final idToken = await firebaseAuth!.currentUser!.getIdToken();
        if (idToken != null) {
          await localDataSource.saveToken(idToken);
        }
      }
    }
    final idToken = await localDataSource.getToken();
    if (idToken == null || idToken.isEmpty) return [];
    try {
      final list = await remoteDataSource.getUsers(idToken);
      return list
          .map(
            (e) => DisplayUserEntity(
              id: e.id,
              displayName: e.displayName,
              photoURL: e.photoURL,
            ),
          )
          .toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Future<void> updateFcmToken(String? fcmToken) async {
    final idToken = await getCurrentIdToken();
    if (idToken == null || idToken.isEmpty) return;
    try {
      await remoteDataSource.updateFcmToken(idToken, fcmToken);
    } catch (e) {
      debugPrint('updateFcmToken failed: $e');
    }
  }
}
