import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/api_config.dart';
import '../models/user_model.dart';
import '../state/auth_provider.dart';
import '../theme/colors.dart';
import '../theme/tokens.dart';
import '../widgets/kit/kit.dart';

/// Sign-in screen.
///
/// One screen for every role: the backend auto-detects the school, and the
/// role lands on the matching app. The role switch is a *hint* that tailors the
/// copy and demo accounts — it never blocks a valid sign-in.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordFocus = FocusNode();

  bool _isTeacherSelected = false;
  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _showDemoPanel = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    ref.listenManual(authProvider, (previous, next) {
      if (previous?.isLoading == true && !next.isLoading) {
        final user = next.user;
        if (next.isAuthenticated && user != null) _navigateToRole(user.role);
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = ref.read(authProvider);
      if (!auth.isLoading && auth.isAuthenticated && auth.user != null) {
        _navigateToRole(auth.user!.role);
      }
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  void _navigateToRole(UserRole? role) {
    final route = switch (role) {
      UserRole.superAdmin => '/SuperAdminPortal',
      UserRole.admin || UserRole.schoolAdmin => '/SchoolAdminDashboard',
      UserRole.instructor => '/TeacherDashboard',
      _ => '/StudentDashboard',
    };
    Navigator.pushReplacementNamed(context, route);
  }

  Future<void> _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'Enter your email and password to continue.');
      HapticFeedback.heavyImpact();
      return;
    }

    setState(() {
      _errorMessage = null;
      _isLoading = true;
    });
    HapticFeedback.lightImpact();

    final success = await ref.read(authProvider.notifier).loginAuto(email, password);
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (success) {
      _navigateToRole(ref.read(authProvider).user?.role);
    } else {
      setState(() =>
          _errorMessage = ref.read(authProvider).error ?? 'Invalid credentials');
      HapticFeedback.heavyImpact();
    }
  }

  void _fillDemo(String email, String password, bool isTeacher) {
    setState(() {
      _emailController.text = email;
      _passwordController.text = password;
      _isTeacherSelected = isTeacher;
      _showDemoPanel = false;
      _errorMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      resizeToAvoidBottomInset: true,
      body: AuroraBackground(
        tint: _isTeacherSelected ? AppColors.teacherAccent : AppColors.studentAccent,
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(22, 18, 22, 26),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _brand(),
                    const SizedBox(height: AppSpace.xl),
                    _card(),
                    const SizedBox(height: AppSpace.lg),
                    _footer(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── Brand block ─────────────────────────────────────────────────────────

  Widget _brand() {
    final accent =
        _isTeacherSelected ? AppColors.teacherAccent : AppColors.studentAccent;
    return Column(
      children: [
        Container(
          width: 62,
          height: 62,
          decoration: BoxDecoration(
            gradient: AppGradients.brand,
            borderRadius: AppRadius.brLg,
            boxShadow: AppShadows.glow(AppColors.primary, strength: 0.38),
          ),
          child: const Icon(Icons.school_rounded, color: Colors.white, size: 30),
        )
            .animate()
            .scale(
              begin: const Offset(0.7, 0.7),
              end: const Offset(1, 1),
              duration: 520.ms,
              curve: Curves.easeOutBack,
            )
            .fadeIn(duration: 380.ms),
        const SizedBox(height: AppSpace.md),
        Text('School Connect', style: AppText.title.copyWith(fontSize: 22)),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Learn. Teach. Grow. ', style: AppText.body.copyWith(fontSize: 12.5)),
            Text(
              'Together.',
              style: AppText.body.copyWith(
                fontSize: 12.5,
                color: accent,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ],
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.12, end: 0, duration: 460.ms, curve: Curves.easeOutCubic);
  }

  // ─── Card ────────────────────────────────────────────────────────────────

  Widget _card() {
    return AppCard(
      padding: const EdgeInsets.all(AppSpace.lg),
      radius: AppRadius.xl,
      shadow: AppShadows.lifted(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Welcome back 👋', style: AppText.title.copyWith(fontSize: 20)),
          const SizedBox(height: 4),
          Text(
            'Sign in to pick up where you left off.',
            style: AppText.body.copyWith(fontSize: 13),
          ),
          const SizedBox(height: AppSpace.lg),
          _roleToggle(),
          const SizedBox(height: AppSpace.lg),
          _field(
            label: 'Email or ID',
            controller: _emailController,
            hint: _isTeacherSelected
                ? 'teacher@school.com'
                : 'student@school.com',
            icon: Icons.alternate_email_rounded,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            onSubmitted: (_) => _passwordFocus.requestFocus(),
          ),
          const SizedBox(height: AppSpace.sm),
          _field(
            label: 'Password',
            controller: _passwordController,
            focusNode: _passwordFocus,
            hint: 'Your password',
            icon: Icons.lock_outline_rounded,
            obscure: _obscurePassword,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _login(),
            suffix: IconButton(
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                size: 18,
                color: AppColors.inkFaint,
              ),
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              tooltip: _obscurePassword ? 'Show password' : 'Hide password',
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => _toast('Ask your school office to reset your password'),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                'Forgot password?',
                style: AppText.caption.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w800,
                  fontSize: 11.5,
                ),
              ),
            ),
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: AppSpace.sm),
            _errorBanner(_errorMessage!),
          ],
          const SizedBox(height: AppSpace.md),
          _submitButton(),
          if (ApiConfig.hasDemoAccounts) ...[
            const SizedBox(height: AppSpace.md),
            _demoToggle(),
            if (_showDemoPanel) ...[
              const SizedBox(height: AppSpace.sm),
              _demoPanel(),
            ],
          ],
        ],
      ),
    ).animate(delay: 90.ms).fadeIn(duration: 420.ms).slideY(begin: 0.10, end: 0, duration: 480.ms, curve: Curves.easeOutCubic);
  }

  Widget _roleToggle() {
    final accent =
        _isTeacherSelected ? AppColors.teacherAccent : AppColors.studentAccent;
    return LayoutBuilder(
      builder: (context, constraints) {
        final half = constraints.maxWidth / 2;
        Widget role(bool teacher) {
          final selected = _isTeacherSelected == teacher;
          return Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _isTeacherSelected = teacher);
              },
              child: SizedBox(
                height: 46,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      teacher ? Icons.cast_for_education_rounded : Icons.school_rounded,
                      size: 15,
                      color: selected ? Colors.white : AppColors.inkFaint,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      teacher ? 'Teacher' : 'Student',
                      style: AppText.caption.copyWith(
                        fontSize: 12.5,
                        color: selected ? Colors.white : AppColors.inkFaint,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return Container(
          height: 52,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainer,
            borderRadius: AppRadius.brPill,
          ),
          child: Stack(
            children: [
              AnimatedPositioned(
                duration: AppMotion.base,
                curve: AppMotion.emphasized,
                left: _isTeacherSelected ? 3 : half,
                top: 3,
                bottom: 3,
                width: half - 3,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: _isTeacherSelected
                        ? AppGradients.teacher
                        : AppGradients.student,
                    borderRadius: AppRadius.brPill,
                    boxShadow: AppShadows.glow(accent, strength: 0.30),
                  ),
                ),
              ),
              Row(children: [role(true), role(false)]),
            ],
          ),
        );
      },
    );
  }

  Widget _field({
    required String label,
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    FocusNode? focusNode,
    bool obscure = false,
    TextInputType? keyboardType,
    TextInputAction? textInputAction,
    ValueChanged<String>? onSubmitted,
    Widget? suffix,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: AppText.eyebrow.copyWith(fontSize: 10)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          focusNode: focusNode,
          obscureText: obscure,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          onSubmitted: onSubmitted,
          style: AppText.body.copyWith(fontSize: 14, color: AppColors.ink),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, size: 18, color: AppColors.primary),
            suffixIcon: suffix,
          ),
        ),
      ],
    );
  }

  Widget _errorBanner(String message) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: AppColors.dangerSoft,
        borderRadius: AppRadius.brSm,
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.28)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, size: 16, color: AppColors.dangerDark),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              message,
              style: AppText.caption.copyWith(
                color: AppColors.dangerDark,
                fontSize: 12,
                height: 1.35,
              ),
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _errorMessage = null),
            child: const Icon(Icons.close_rounded, size: 15, color: AppColors.dangerDark),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 220.ms).slideX(begin: -0.04);
  }

  Widget _submitButton() {
    final accent =
        _isTeacherSelected ? AppColors.teacherAccent : AppColors.studentAccent;
    return Pressable(
      onTap: () {
        if (!_isLoading) _login();
      },
      borderRadius: AppRadius.brMd,
      child: AnimatedContainer(
        duration: AppMotion.base,
        height: 52,
        decoration: BoxDecoration(
          gradient: _isTeacherSelected ? AppGradients.teacher : AppGradients.student,
          borderRadius: AppRadius.brMd,
          boxShadow: AppShadows.glow(accent, strength: 0.34),
        ),
        alignment: Alignment.center,
        child: _isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _isTeacherSelected ? 'Sign in to teach' : 'Sign in to learn',
                    style: AppText.cardTitle.copyWith(
                      color: Colors.white,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward_rounded,
                      size: 17, color: Colors.white),
                ],
              ),
      ),
    );
  }

  Widget _demoToggle() {
    return Pressable(
      onTap: () => setState(() => _showDemoPanel = !_showDemoPanel),
      borderRadius: AppRadius.brSm,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.06),
          borderRadius: AppRadius.brSm,
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.16)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.rocket_launch_rounded, size: 14, color: AppColors.primary),
            const SizedBox(width: 7),
            Text(
              'Try a demo account',
              style: AppText.caption.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w800,
                fontSize: 11.5,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              _showDemoPanel
                  ? Icons.keyboard_arrow_up_rounded
                  : Icons.keyboard_arrow_down_rounded,
              size: 16,
              color: AppColors.primary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _demoPanel() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: AppRadius.brMd,
        border: Border.all(color: AppColors.hairlineBorder),
      ),
      child: Row(
        children: [
          if (ApiConfig.hasDemoStudent)
            Expanded(
              child: _demoChip(
                label: 'Student',
                icon: Icons.school_rounded,
                accent: AppColors.studentAccent,
                onTap: () => _fillDemo(
                  ApiConfig.demoStudentEmail,
                  ApiConfig.demoStudentPassword,
                  false,
                ),
              ),
            ),
          if (ApiConfig.hasDemoStudent && ApiConfig.hasDemoTeacher)
            const SizedBox(width: 8),
          if (ApiConfig.hasDemoTeacher)
            Expanded(
              child: _demoChip(
                label: 'Teacher',
                icon: Icons.cast_for_education_rounded,
                accent: AppColors.teacherAccent,
                onTap: () => _fillDemo(
                  ApiConfig.demoTeacherEmail,
                  ApiConfig.demoTeacherPassword,
                  true,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _demoChip({
    required String label,
    required IconData icon,
    required Color accent,
    required VoidCallback onTap,
  }) {
    return Pressable(
      onTap: onTap,
      borderRadius: AppRadius.brSm,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.08),
          borderRadius: AppRadius.brSm,
          border: Border.all(color: accent.withValues(alpha: 0.28)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: accent),
            const SizedBox(width: 6),
            Text(
              label,
              style: AppText.caption.copyWith(
                fontSize: 11.5,
                color: accent,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _footer() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "Don't have an account? ",
              style: AppText.caption.copyWith(fontSize: 12),
            ),
            GestureDetector(
              onTap: () => Navigator.pushNamed(context, '/SignupStep1'),
              child: Text(
                'Sign up as a student →',
                style: AppText.caption.copyWith(
                  fontSize: 12,
                  color: AppColors.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          'Teachers and admins are created by the school office.',
          textAlign: TextAlign.center,
          style: AppText.caption.copyWith(fontSize: 10.5, color: AppColors.inkFaint),
        ),
      ],
    ).animate(delay: 180.ms).fadeIn(duration: 420.ms);
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}
