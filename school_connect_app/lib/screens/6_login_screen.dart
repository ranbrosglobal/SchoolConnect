import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/colors.dart';
import '../state/auth_provider.dart';
import '../models/user_model.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isTeacherSelected = false;
  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _showDemoPanel = false;
  String? _errorMessage;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.0, 0.8, curve: Curves.easeOutCubic),
    ));
    _animController.forward();

    // If a session was restored from storage, navigate straight to role dashboard
    ref.listenManual(authProvider, (previous, next) {
      if (previous?.isLoading == true && !next.isLoading) {
        final user = next.user;
        if (next.isAuthenticated && user != null) {
          _navigateToRole(user.role);
        }
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = ref.read(authProvider).user;
      if (!ref.read(authProvider).isLoading &&
          ref.read(authProvider).isAuthenticated &&
          user != null) {
        _navigateToRole(user.role);
      }
    });
  }

  void _navigateToRole(UserRole? role) {
    switch (role) {
      case UserRole.superAdmin:
        Navigator.pushReplacementNamed(context, '/SuperAdminPortal');
      case UserRole.admin:
      case UserRole.schoolAdmin:
        Navigator.pushReplacementNamed(context, '/SchoolAdminDashboard');
      case UserRole.instructor:
        Navigator.pushReplacementNamed(context, '/TeacherDashboard');
      default:
        Navigator.pushReplacementNamed(context, '/StudentDashboard');
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _animController.dispose();
    super.dispose();
  }

  void _setError(String? msg) {
    setState(() => _errorMessage = msg);
  }

  Future<void> _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      _setError('Please enter your email and password.');
      return;
    }

    _setError(null);
    setState(() => _isLoading = true);
    HapticFeedback.lightImpact();

    final success = await ref.read(authProvider.notifier).loginAuto(email, password);
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (success) {
      _navigateToRole(ref.read(authProvider).user?.role);
    } else {
      _setError(ref.read(authProvider).error ?? 'Invalid credentials');
    }
  }

  void _fillDemo(String email, String password, bool isTeacher) {
    setState(() {
      _emailController.text = email;
      _passwordController.text = password;
      _isTeacherSelected = isTeacher;
      _showDemoPanel = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: FadeTransition(
        opacity: _fadeAnim,
        child: SlideTransition(
          position: _slideAnim,
          child: SizedBox(
            height: size.height,
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: _buildLoginCard(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Header ─────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 14,
        bottom: 20,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFE0F7EF), Color(0xFFF5F7FA)],
        ),
      ),
      child: Column(
        children: [
          // App icon
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primary, AppColors.darkTeal],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.35),
                  blurRadius: 12,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: const Icon(Icons.school_rounded, color: Colors.white, size: 26),
          ),
          const SizedBox(height: 10),
          // Brand name
          const Text(
            'School Connect',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 3),
          // Tagline
          RichText(
            text: TextSpan(
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.outline,
                letterSpacing: 0.2,
              ),
              children: [
                const TextSpan(text: 'Learn. Teach. Grow. '),
                TextSpan(
                  text: 'Together.',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          // Greeting
          const Text(
            'Welcome back! 👋',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1A1C1E),
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 3),
          const Text(
            'Sign in to continue your journey',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.outline,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Login Card ─────────────────────────────────────────────────────
  Widget _buildLoginCard() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 24,
            spreadRadius: 2,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Role toggle
            _buildPremiumToggle(),
            const SizedBox(height: 18),

            // Email field
            _buildCompactInput(
              label: 'Email / ID',
              controller: _emailController,
              icon: Icons.email_outlined,
              hint: 'Enter your email or ID',
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 12),

            // Password field
            _buildCompactInput(
              label: 'Password',
              controller: _passwordController,
              icon: Icons.lock_outline,
              hint: 'Enter your password',
              obscure: _obscurePassword,
              suffix: IconButton(
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: AppColors.outline,
                  size: 18,
                ),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
            const SizedBox(height: 2),

            // Forgot password
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {},
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  'Forgot Password?',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Error message
            if (_errorMessage != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFECACA)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Color(0xFFDC2626), size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(
                          color: Color(0xFFDC2626),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => _setError(null),
                      child: const Icon(Icons.close, color: Color(0xFFDC2626), size: 14),
                    ),
                  ],
                ),
              ),

            // Login button
            _buildLoginButton(),
            const SizedBox(height: 14),

            // Sign up link
            _buildSignUpLink(),
            const SizedBox(height: 12),

            // Demo button
            _buildDemoButton(),
            if (_showDemoPanel) ...[
              const SizedBox(height: 12),
              _buildDemoPanel(),
            ],
          ],
        ),
      ),
    );
  }

  // ─── Role Toggle ────────────────────────────────────────────────────
  Widget _buildPremiumToggle() {
    final screenWidth = MediaQuery.of(context).size.width;
    final toggleWidth = screenWidth - 88;
    final halfWidth = toggleWidth / 2;

    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Stack(
        children: [
          // Sliding pill
          AnimatedPositioned(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeInOut,
            left: _isTeacherSelected ? 3 : halfWidth,
            top: 3,
            bottom: 3,
            width: halfWidth - 3,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _isTeacherSelected
                      ? [AppColors.primary, AppColors.darkTeal]
                      : [AppColors.secondary, const Color(0xFF5C6BC0)],
                ),
                borderRadius: BorderRadius.circular(19),
                boxShadow: [
                  BoxShadow(
                    color: (_isTeacherSelected
                            ? AppColors.primary
                            : AppColors.secondary)
                        .withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
            ),
          ),
          // Teacher
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: halfWidth,
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _isTeacherSelected = true);
              },
              child: Container(
                alignment: Alignment.center,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.person_rounded,
                      size: 15,
                      color:
                          _isTeacherSelected ? Colors.white : AppColors.outline,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'Teacher',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _isTeacherSelected
                            ? Colors.white
                            : AppColors.outline,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Student
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            width: halfWidth,
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _isTeacherSelected = false);
              },
              child: Container(
                alignment: Alignment.center,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.school_rounded,
                      size: 15,
                      color: !_isTeacherSelected
                          ? Colors.white
                          : AppColors.outline,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'Student',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: !_isTeacherSelected
                            ? Colors.white
                            : AppColors.outline,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Text Input ─────────────────────────────────────────────────────
  Widget _buildCompactInput({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    required String hint,
    bool obscure = false,
    TextInputType? keyboardType,
    Widget? suffix,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Color(0xFF374151),
          ),
        ),
        const SizedBox(height: 5),
        TextField(
          controller: controller,
          obscureText: obscure,
          keyboardType: keyboardType,
          style: const TextStyle(fontSize: 13, color: Color(0xFF1F2937)),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 12),
            prefixIcon: Icon(icon, color: AppColors.primary, size: 18),
            suffixIcon: suffix,
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                  color: AppColors.primary, width: 1.5),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
      ],
    );
  }

  // ─── Login Button ───────────────────────────────────────────────────
  Widget _buildLoginButton() {
    return SizedBox(
      width: double.infinity,
      height: 44,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.primary, AppColors.darkTeal],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.35),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: _isLoading ? null : _login,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            foregroundColor: Colors.white,
            disabledBackgroundColor: Colors.transparent,
            disabledForegroundColor: Colors.white.withValues(alpha: 0.6),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 0,
          ),
          child: _isLoading
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Text(
                  'Login',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
        ),
      ),
    );
  }

  // ─── Sign Up Link ───────────────────────────────────────────────────
  Widget _buildSignUpLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          "Don't have an account? ",
          style: TextStyle(
            color: AppColors.outline,
            fontSize: 11,
            fontWeight: FontWeight.w400,
          ),
        ),
        GestureDetector(
          onTap: () => Navigator.pushNamed(context, '/SignupStep1'),
          child: const Text(
            'Sign up as Student →',
            style: TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
        ),
      ],
    );
  }

  // ─── Demo Button ────────────────────────────────────────────────────
  Widget _buildDemoButton() {
    return GestureDetector(
      onTap: () => setState(() => _showDemoPanel = !_showDemoPanel),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.15),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.rocket_launch_rounded,
              size: 13,
              color: AppColors.primary,
            ),
            const SizedBox(width: 6),
            Text(
              'Try Demo Account',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              _showDemoPanel
                  ? Icons.keyboard_arrow_up
                  : Icons.keyboard_arrow_down,
              size: 16,
              color: AppColors.primary,
            ),
          ],
        ),
      ),
    );
  }

  // ─── Demo Panel ─────────────────────────────────────────────────────
  Widget _buildDemoPanel() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.hairlineBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Quick Demo Access',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFF374151),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _demoAccountChip(
                  label: 'Student',
                  icon: Icons.school_rounded,
                  color: AppColors.secondary,
                  onTap: () => _fillDemo(
                      'alex.smith@school.com', 'Student@123', false),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _demoAccountChip(
                  label: 'Teacher',
                  icon: Icons.person_rounded,
                  color: AppColors.primary,
                  onTap: () => _fillDemo(
                      'robert.johnson@school.com', 'Teacher@123', true),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _demoAccountChip({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
