// lib/services/auth_service.dart
import 'dart:async';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
import 'package:flutter/material.dart';

class AuthService {
  // Singleton pattern
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  // Authentication state stream
  final StreamController<AuthState> _authStateController =
      StreamController<AuthState>.broadcast();
  Stream<AuthState> get authStateStream => _authStateController.stream;

  // Current auth session
  AuthSession? _currentSession;
  AuthSession? get currentSession => _currentSession;

  // Current user
  AuthUser? _currentUser;
  AuthUser? get currentUser => _currentUser;

  // Initialize the auth service
  Future<void> initialize() async {
    try {
      // Get current auth session
      final session = await Amplify.Auth.fetchAuthSession();
      _currentSession = session;

      // Update auth state
      if (session.isSignedIn) {
        final result = await Amplify.Auth.getCurrentUser();
        _currentUser = result;
        _authStateController.add(AuthState.signedIn);
      } else {
        _authStateController.add(AuthState.signedOut);
      }

      // Listen for auth state changes
      Amplify.Hub.listen(HubChannel.Auth, (event) {
        _handleAuthEvent(event);
      });
    } catch (e) {
      safePrint('Error initializing AuthService: $e');
      _authStateController.add(AuthState.error);
    }
  }

  // Handle auth events
  void _handleAuthEvent(HubEvent event) async {
    try {
      switch (event.eventName) {
        case 'signedIn':
          final result = await Amplify.Auth.getCurrentUser();
          _currentUser = result;
          _authStateController.add(AuthState.signedIn);
          break;
        case 'signedOut':
          _currentUser = null;
          _currentSession = null;
          _authStateController.add(AuthState.signedOut);
          break;
        case 'sessionExpired':
          _currentUser = null;
          _currentSession = null;
          _authStateController.add(AuthState.signedOut);
          break;
        default:
          break;
      }
    } catch (e) {
      safePrint('Error handling auth event: $e');
    }
  }

  // Sign up with email and password
  Future<SignUpResult> signUp({
    required String username,
    required String password,
    required String email,
  }) async {
    try {
      final userAttributes = {AuthUserAttributeKey.email: email};

      final result = await Amplify.Auth.signUp(
        username: username,
        password: password,
        options: SignUpOptions(userAttributes: userAttributes),
      );

      return result;
    } catch (e) {
      safePrint('Error signing up: $e');
      rethrow;
    }
  }

  // Confirm sign up with verification code
  Future<SignUpResult> confirmSignUp({
    required String username,
    required String confirmationCode,
  }) async {
    try {
      final result = await Amplify.Auth.confirmSignUp(
        username: username,
        confirmationCode: confirmationCode,
      );

      return result;
    } catch (e) {
      safePrint('Error confirming sign up: $e');
      rethrow;
    }
  }

  // Resend confirmation code
  Future<ResendSignUpCodeResult> resendConfirmationCode({
    required String username,
  }) async {
    try {
      final result = await Amplify.Auth.resendSignUpCode(username: username);

      return result;
    } catch (e) {
      safePrint('Error resending confirmation code: $e');
      rethrow;
    }
  }

  // Sign in with username and password
  Future<SignInResult> signIn({
    required String username,
    required String password,
  }) async {
    try {
      final result = await Amplify.Auth.signIn(
        username: username,
        password: password,
      );

      // If sign in is complete, fetch current user
      if (result.isSignedIn) {
        final userResult = await Amplify.Auth.getCurrentUser();
        _currentUser = userResult;
        _authStateController.add(AuthState.signedIn);
      }

      return result;
    } catch (e) {
      safePrint('Error signing in: $e');
      rethrow;
    }
  }

  // Confirm sign in (for MFA if enabled)
  Future<SignInResult> confirmSignIn({required String confirmationCode}) async {
    try {
      final result = await Amplify.Auth.confirmSignIn(
        confirmationValue: confirmationCode,
      );

      if (result.isSignedIn) {
        final userResult = await Amplify.Auth.getCurrentUser();
        _currentUser = userResult;
        _authStateController.add(AuthState.signedIn);
      }

      return result;
    } catch (e) {
      safePrint('Error confirming sign in: $e');
      rethrow;
    }
  }

  // Reset password
  Future<ResetPasswordResult> resetPassword({required String username}) async {
    try {
      final result = await Amplify.Auth.resetPassword(username: username);

      return result;
    } catch (e) {
      safePrint('Error resetting password: $e');
      rethrow;
    }
  }

  // Confirm reset password
  Future<void> confirmResetPassword({
    required String username,
    required String newPassword,
    required String confirmationCode,
  }) async {
    try {
      await Amplify.Auth.confirmResetPassword(
        username: username,
        newPassword: newPassword,
        confirmationCode: confirmationCode,
      );
    } catch (e) {
      safePrint('Error confirming reset password: $e');
      rethrow;
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await Amplify.Auth.signOut();
      _currentUser = null;
      _currentSession = null;
      _authStateController.add(AuthState.signedOut);
    } catch (e) {
      safePrint('Error signing out: $e');
      rethrow;
    }
  }

  // Fetch user attributes
  Future<List<AuthUserAttribute>> fetchUserAttributes() async {
    try {
      final attributes = await Amplify.Auth.fetchUserAttributes();
      return attributes;
    } catch (e) {
      safePrint('Error fetching user attributes: $e');
      rethrow;
    }
  }

  // Update user attribute
  Future<void> updateUserAttribute({
    required AuthUserAttributeKey attributeKey,
    required String value,
  }) async {
    try {
      await Amplify.Auth.updateUserAttribute(
        userAttributeKey: attributeKey,
        value: value,
      );
    } catch (e) {
      safePrint('Error updating user attribute: $e');
      rethrow;
    }
  }

  // Dispose
  void dispose() {
    _authStateController.close();
  }
}

// Auth state enum
enum AuthState { loading, signedIn, signedOut, error }
