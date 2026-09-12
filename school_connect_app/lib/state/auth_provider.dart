import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_model.dart';
import '../services/frappe_api_service.dart';

/// Auth state for the live (Frappe + sc_auth) build.
///
/// [isDemoMode] is kept for shape compatibility but can never become true
/// in the live build — the app no longer falls back to demo mode.
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

class AuthNotifier extends StateNotifier<AuthState> {
  final FrappeApiService _api;

  AuthNotifier(this._api) : super(AuthState()) {
    _init();
  }

  Future<void> _init() async {
    state = state.copyWith(isLoading: true);
    try {
      final restored = await _api.restoreSession();
      if (restored) {
        state = state.copyWith(
          isLoading: false,
          isAuthenticated: true,
          user: _api.currentUser,
        );
      } else {
        state = state.copyWith(isLoading: false);
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Session restore failed: ${e.toString()}');
    }
  }

  /// Email/password login against the active school site.
  Future<bool> login(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final result = await _api.login(email, password);
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
        error: _userFacingError(e),
      );
      return false;
    }
  }

  /// Login with auto school detection.
  /// The caller should first fetch `public_schools` from the super site and
  /// then probe each school's login endpoint; this method runs one attempt
  /// against the current base URL.
  Future<bool> loginAuto(String email, String password) async {
    return login(email, password);
  }

  /// Sign up a new student (creates User + Student + enrollment, auto-login).
  Future<bool> signupStudent({
    required String fullName,
    required String email,
    required String password,
    String? gender,
    String? city,
    String? userState,
    String? country,
    String? studentGroup,
    String? program,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final result = await _api.signupStudent(
        fullName: fullName,
        email: email,
        password: password,
        gender: gender,
        studentGroup: studentGroup,
        program: program,
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
        error: _userFacingError(e),
      );
      return false;
    }
  }

  /// Change password (old -> new). The caller enforces new != old and new >= 8.
  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _api.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: _userFacingError(e),
      );
      return false;
    }
  }

  /// Sign out: clears local state synchronously first, then calls the server.
  Future<void> logout() async {
    state = AuthState();
    try {
      await _api.logout();
    } catch (_) {}
  }

  void clearError() {
    state = state.copyWith(error: null);
  }

  /// Convert backend/transport errors into user-facing messages.
  /// Never surface raw stack traces.
  static String _userFacingError(Object e) {
    final msg = e.toString();
    if (msg.contains('Cannot connect to server') ||
        msg.contains('Connection failed') ||
        msg.contains('SocketException') ||
        msg.contains('ClientException')) {
      return 'Cannot connect to server. Please check your connection.';
    }
    if (msg.contains('Session expired') || msg.contains('Please login again')) {
      return 'Session expired. Please login again.';
    }
    return 'Something went wrong. Please try again.';
  }
}

/// The live data service (Frappe + sc_auth).
final apiServiceProvider = Provider<FrappeApiService>((ref) => FrappeApiService());

/// Auth state notifier.
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.watch(apiServiceProvider));
});

/// Keep the historical name for screens that already import it.
final sheetsServiceProvider = apiServiceProvider;
