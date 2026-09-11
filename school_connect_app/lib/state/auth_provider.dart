import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_model.dart';
import '../services/google_sheets_service.dart';

// Auth state
class AuthState {
  final bool isLoading;
  final bool isAuthenticated;
  final UserModel? user;
  final String? error;
  final bool isDemoMode;

  AuthState({
    this.isLoading = false,
    this.isAuthenticated = false,
    this.user,
    this.error,
    this.isDemoMode = false,
  });

  AuthState copyWith({
    bool? isLoading,
    bool? isAuthenticated,
    UserModel? user,
    String? error,
    bool? isDemoMode,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      user: user ?? this.user,
      error: error,
      isDemoMode: isDemoMode ?? this.isDemoMode,
    );
  }
}

// Auth notifier - direct backend login (no Firebase Auth).
class AuthNotifier extends StateNotifier<AuthState> {
  final GoogleSheetsService _sheetsService;

  AuthNotifier(this._sheetsService) : super(AuthState()) {
    _init();
  }

  Future<void> _init() async {
    state = state.copyWith(isLoading: true);

    try {
      final restored = await _sheetsService.restoreSession();
      if (restored) {
        state = state.copyWith(
          isLoading: false,
          isAuthenticated: true,
          user: _sheetsService.currentUser,
        );
      } else {
        state = state.copyWith(isLoading: false);
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Email/password login via backend.
  Future<bool> login(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final result = await _sheetsService.login(email, password);

      if (result.success && result.user != null) {
        state = state.copyWith(
          isLoading: false,
          isAuthenticated: true,
          user: result.user,
        );
        return true;
      }

      state = state.copyWith(
        isLoading: false,
        error: result.error ?? 'Invalid email or password.',
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Connection failed: ${e.toString()}',
      );
      return false;
    }
  }

  /// Login with auto school detection.
  Future<bool> loginAuto(String email, String password) async {
    return login(email, password);
  }

  /// Sign in with Google (Firebase) and create a backend session.
  Future<bool> signInWithGoogle() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final result = await _sheetsService.signInWithGoogle();
      if (result.success && result.user != null) {
        state = state.copyWith(
          isLoading: false,
          isAuthenticated: true,
          user: result.user,
        );
        return true;
      }
      state = state.copyWith(isLoading: false, error: result.error ?? 'Google sign-in failed.');
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Google sign-in failed: ${e.toString()}');
      return false;
    }
  }

  /// Sign in with Apple (Firebase) and create a backend session.
  Future<bool> signInWithApple() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final result = await _sheetsService.signInWithApple();
      if (result.success && result.user != null) {
        state = state.copyWith(
          isLoading: false,
          isAuthenticated: true,
          user: result.user,
        );
        return true;
      }
      state = state.copyWith(isLoading: false, error: result.error ?? 'Apple sign-in failed.');
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Apple sign-in failed: ${e.toString()}');
      return false;
    }
  }

  /// Sign up student.
  Future<bool> signupStudent({
    required String fullName,
    required String email,
    required String password,
    int? age,
    String? gender,
    String? city,
    String? userState,
    String? country,
    required String school,
    String? studentGroup,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final result = await _sheetsService.signupStudent(
        fullName: fullName,
        email: email,
        password: password,
        gender: gender,
        studentGroup: studentGroup,
        city: city,
        state: userState,
        country: country,
      );

      if (result.success && result.user != null) {
        state = state.copyWith(
          isLoading: false,
          isAuthenticated: true,
          user: result.user,
        );
        return true;
      }

      state = state.copyWith(
        isLoading: false,
        error: result.error ?? 'Signup failed.',
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Signup failed: ${e.toString()}',
      );
      return false;
    }
  }

  /// Change password via backend.
  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      await _sheetsService.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to change password: ${e.toString()}',
      );
      return false;
    }
  }

  /// Sign out and clear local data.
  Future<void> logout() async {
    state = AuthState();
    try {
      await _sheetsService.signOut();
    } catch (_) {}
  }

  void clearError() {
    state = state.copyWith(error: null);
  }
}

// Providers
final sheetsServiceProvider = Provider<GoogleSheetsService>((ref) => GoogleSheetsService());

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.watch(sheetsServiceProvider));
});
