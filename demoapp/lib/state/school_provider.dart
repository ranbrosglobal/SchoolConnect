import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/school_profile_model.dart';
import '../services/demo_api_service.dart';
import 'auth_provider.dart';

/// School profile state — the public school info (name / logo / contact)
/// shown on dashboards and settings, editable by the school admin.
class SchoolState {
  final bool isLoading;
  final SchoolProfileModel? profile;
  final String? error;
  final bool isUpdating;

  const SchoolState({
    this.isLoading = false,
    this.profile,
    this.error,
    this.isUpdating = false,
  });

  SchoolState copyWith({
    bool? isLoading,
    SchoolProfileModel? profile,
    String? error,
    bool? isUpdating,
  }) {
    return SchoolState(
      isLoading: isLoading ?? this.isLoading,
      profile: profile ?? this.profile,
      error: error,
      isUpdating: isUpdating ?? this.isUpdating,
    );
  }
}

class SchoolNotifier extends StateNotifier<SchoolState> {
  final DemoApiService _api;

  SchoolNotifier(this._api) : super(const SchoolState());

  /// Load (or reload) the school profile. Auto-refreshes dashboards after an
  /// admin edit because the profile is watched via the provider.
  Future<SchoolProfileModel?> load() async {
    if (state.isLoading && state.profile != null) return state.profile;
    if (state.profile != null && state.error == null) return state.profile;

    state = state.copyWith(isLoading: true, error: null);
    try {
      final profile = await _api.getSchoolProfile();
      state = state.copyWith(isLoading: false, profile: profile);
      return profile;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return state.profile;
    }
  }

  /// Force a fresh fetch (used after the admin edits the profile).
  Future<void> refresh() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final profile = await _api.getSchoolProfile();
      state = state.copyWith(isLoading: false, profile: profile);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<SchoolProfileModel?> update({
    String? schoolName,
    String? motto,
    String? contactEmail,
    String? contactNumber,
    String? website,
    String? address,
  }) async {
    state = state.copyWith(isUpdating: true, error: null);
    try {
      final profile = await _api.updateSchoolProfile(
        schoolName: schoolName,
        motto: motto,
        contactEmail: contactEmail,
        contactNumber: contactNumber,
        website: website,
        address: address,
      );
      state = state.copyWith(isUpdating: false, profile: profile);
      return profile;
    } catch (e) {
      state = state.copyWith(isUpdating: false, error: e.toString());
      rethrow;
    }
  }

  Future<String?> uploadLogo({required String fileName, required List<int> fileBytes}) async {
    state = state.copyWith(isUpdating: true, error: null);
    try {
      final url = await _api.uploadSchoolLogo(fileName: fileName, fileBytes: fileBytes);
      await refresh();
      return url;
    } catch (e) {
      state = state.copyWith(isUpdating: false, error: e.toString());
      rethrow;
    }
  }
}

final schoolProvider =
    StateNotifierProvider<SchoolNotifier, SchoolState>((ref) {
  ref.watch(authProvider); // re-create on auth change (new session/school)
  return SchoolNotifier(ref.watch(demoApiServiceProvider));
});
