import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/colors.dart';
import '../state/auth_provider.dart';
import '../widgets/auth_scaffold.dart';

class SignupStep4 extends ConsumerStatefulWidget {
  const SignupStep4({super.key});

  @override
  ConsumerState<SignupStep4> createState() => _SignupStep4State();
}

class _SignupStep4State extends ConsumerState<SignupStep4> {
  Map<String, dynamic>? get _data =>
      ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

  Future<void> _createAccount() async {
    final data = _data;
    if (data == null) return;

    final success = await ref.read(authProvider.notifier).signupStudent(
      fullName: data['fullName'] as String,
      email: data['email'] as String,
      password: data['password'] as String,
      age: data['age'] as int?,
      gender: data['gender'] as String?,
      city: data['city'] as String?,
      userState: data['state'] as String?,
      country: data['country'] as String?,
      school: data['school'] as String,
      studentGroup: data['studentGroup'] as String?,
    );

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Account created! Welcome to School Connect.'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.of(context).pushNamedAndRemoveUntil(
        '/StudentDashboard',
        (route) => false,
      );
    } else {
      final error = ref.read(authProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error ?? 'Signup failed. Please try again.'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    final authState = ref.watch(authProvider);

    return AuthScaffold(
      icon: Icons.task_alt_rounded,
      title: 'Almost there!',
      subtitle: 'Double-check your details before creating your account',
      currentStep: 4,
      footer: _buildFooter(authState),
      child: data == null
          ? const SizedBox.shrink()
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildReviewTile(context, Icons.person_outline, 'Full Name', data['fullName']?.toString() ?? ''),
                _buildReviewTile(context, Icons.email_outlined, 'Email', data['email']?.toString() ?? ''),
                _buildReviewTile(context, Icons.cake_outlined, 'Age', '${data['age'] ?? '-'}'),
                _buildReviewTile(context, Icons.wc_outlined, 'Gender', data['gender']?.toString() ?? '-'),
                _buildReviewTile(context, Icons.location_city_outlined, 'City', data['city']?.toString() ?? ''),
                _buildReviewTile(context, Icons.map_outlined, 'State', data['state']?.toString() ?? ''),
                _buildReviewTile(context, Icons.flag_outlined, 'Country', data['country']?.toString() ?? ''),
                _buildReviewTile(context, Icons.school_outlined, 'School', data['schoolName']?.toString() ?? ''),
                _buildReviewTile(context, Icons.class_outlined, 'Class', data['studentGroupName']?.toString() ?? '-'),
              ],
            ),
    );
  }

  Widget _buildFooter(dynamic authState) {
    final isLoading = authState.isLoading;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ElevatedButton(
          onPressed: isLoading ? null : _createAccount,
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 54),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          child: isLoading
              ? const SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Create Account', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: isLoading ? null : () => Navigator.pop(context),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 54),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          child: const Text('Back', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ),
      ],
    );
  }

  Widget _buildReviewTile(BuildContext context, IconData icon, String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.hairlineBorder),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 22),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 12, color: AppColors.outline)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
