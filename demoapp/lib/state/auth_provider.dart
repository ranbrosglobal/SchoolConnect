import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_model.dart';
import '../services/demo_api_service.dart';
import '../services/demo_data_service.dart';

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

// Auth notifier — live backend only (sc_auth custom endpoints).
// No demo fallback: if the backend is unreachable the user sees the error.
class AuthNotifier extends StateNotifier<AuthState> {
  final DemoApiService _apiService;

  AuthNotifier(this._apiService) : super(AuthState()) {
    _init();
  }

  Future<void> _init() async {
    state = state.copyWith(isLoading: true);
    
    try {
      final restored = await _apiService.restoreSession();
      if (restored) {
        state = state.copyWith(
          isLoading: false,
          isAuthenticated: true,
          user: _apiService.currentUser,
        );
      } else {
        state = state.copyWith(isLoading: false);
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<bool> login(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final result = await _apiService.login(email, password);

      if (result.success && result.user != null) {
        state = state.copyWith(
          isLoading: false,
          isAuthenticated: true,
          user: result.user,
          isDemoMode: false,
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
        error: 'Connection to backend failed: ${e.toString()}',
      );
      return false;
    }
  }

  /// Login without picking a school: the service finds which school the user
  /// belongs to (last-used school → registry → fallbacks) and signs them in.
  Future<bool> loginAuto(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final result = await _apiService.loginAnySchool(email, password);

      if (result.success && result.user != null) {
        state = state.copyWith(
          isLoading: false,
          isAuthenticated: true,
          user: result.user,
          isDemoMode: false,
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
        error: 'Connection to backend failed: ${e.toString()}',
      );
      return false;
    }
  }

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
      // Our own signup endpoint creates the User + Student + enrollment
      // and logs the new student in automatically.
      final result = await _apiService.signupStudent(
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
          isDemoMode: false,
        );
        return true;
      }

      state = state.copyWith(
        isLoading: false,
        error: result.error ?? 'Signup failed. Please try again.',
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Connection to backend failed: ${e.toString()}',
      );
      return false;
    }
  }

  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      // Change password via our own endpoint
      await _apiService.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );

      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString().contains('DemoApiException')
            ? 'Current password is incorrect'
            : 'Failed to change password. Please try again.',
      );
      return false;
    }
  }

  Future<void> logout() async {
    // Clear the local session FIRST (synchronously) so the UI navigates to
    // the login screen immediately; the server-side logout follows. This
    // also prevents a restored-session auto-navigation from bouncing the
    // user straight back to the dashboard while logout is in flight.
    state = AuthState();
    try {
      await _apiService.logout();
    } catch (_) {
      // Ignore storage/plugin errors — the local session is already cleared.
    }
  }

  void clearError() {
    state = state.copyWith(error: null);
  }
}

// Providers
final demoApiServiceProvider = Provider<DemoApiService>((ref) => DemoApiService());
final demoServiceProvider = Provider<DemoDataService>((ref) => DemoDataService());

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.watch(demoApiServiceProvider));
});
