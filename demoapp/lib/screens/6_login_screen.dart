import 'package:flutter/material.dart';
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
  bool _isTeacherSelected = false; // Default to Student
  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _showDemoPanel = false;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();

    // If a session was restored from storage (app restart), skip the login
    // screen and go straight to the role dashboard. Also prevents a manual
    // login from racing the restore request on the server.
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
        // The admin dashboard lives in the web app — point admins there.
        Navigator.pushReplacementNamed(context, '/AdminWebRedirect');
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

  Future<void> _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your email and password.')),
      );
      return;
    }

    setState(() => _isLoading = true);
    // Auto-detect the user's school (last-used → registry → fallbacks) and
    // sign in there; the school's name/logo/contact then load from its site.
    final success = await ref.read(authProvider.notifier).loginAuto(email, password);
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (success) {
      _navigateToRole(ref.read(authProvider).user?.role);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ref.read(authProvider).error ?? 'Invalid credentials')),
      );
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
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 12,
        bottom: 16,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFE8F5E9), Color(0xFFF5F7FA)],
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primary, AppColors.darkTeal],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(Icons.school_rounded, color: Colors.white, size: 24),
          ),
          const SizedBox(height: 8),
          const Text(
            'School Connect',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 2),
          RichText(
            text: TextSpan(
              style: const TextStyle(fontSize: 11, color: AppColors.outline),
              children: [
                const TextSpan(text: 'Learn. Teach. Grow. '),
                TextSpan(
                  text: 'Together.',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Welcome back! 👋',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A1C1E),
            ),
          ),
          const SizedBox(height: 3),
          const Text(
            'Login to continue your journey',
            style: TextStyle(fontSize: 12, color: AppColors.outline),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginCard() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 18, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildPremiumToggle(),
            const SizedBox(height: 16),
            _buildCompactInput(
              label: 'Email / ID',
              controller: _emailController,
              icon: Icons.email_outlined,
              hint: 'Enter your email or ID',
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 10),
            _buildCompactInput(
              label: 'Password',
              controller: _passwordController,
              icon: Icons.lock_outline,
              hint: 'Enter your password',
              obscure: _obscurePassword,
              suffix: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  color: AppColors.outline,
                  size: 18,
                ),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
            const SizedBox(height: 2),
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
            _buildLoginButton(),
            const SizedBox(height: 12),
            _buildSignUpLink(),
            const SizedBox(height: 10),
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

  Widget _buildPremiumToggle() {
    final screenWidth = MediaQuery.of(context).size.width;
    final toggleWidth = screenWidth - 88;
    final halfWidth = toggleWidth / 2;

    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(23),
      ),
      child: Stack(
        children: [
          // Sliding pill
          AnimatedPositioned(
            duration: const Duration(milliseconds: 250),
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
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: (_isTeacherSelected ? AppColors.primary : AppColors.secondary)
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
              onTap: () => setState(() => _isTeacherSelected = true),
              child: Container(
                alignment: Alignment.center,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.person_rounded,
                      size: 16,
                      color: _isTeacherSelected ? Colors.white : AppColors.outline,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'Teacher',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _isTeacherSelected ? Colors.white : AppColors.outline,
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
              onTap: () => setState(() => _isTeacherSelected = false),
              child: Container(
                alignment: Alignment.center,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.school_rounded,
                      size: 16,
                      color: !_isTeacherSelected ? Colors.white : AppColors.outline,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'Student',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: !_isTeacherSelected ? Colors.white : AppColors.outline,
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
            fontWeight: FontWeight.w600,
            color: Color(0xFF374151),
          ),
        ),
        const SizedBox(height: 5),
        TextField(
          controller: controller,
          obscureText: obscure,
          keyboardType: keyboardType,
          style: const TextStyle(fontSize: 13),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 12),
            prefixIcon: Icon(icon, color: AppColors.primary, size: 18),
            suffixIcon: suffix,
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
      ],
    );
  }

  Widget _buildLoginButton() {
    return SizedBox(
      width: double.infinity,
      height: 42,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _login,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          elevation: 0,
        ),
        child: _isLoading
            ? const SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : const Text(
                'Login',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
      ),
    );
  }  Widget _buildSignUpLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          "Don't have an account? ",
          style: TextStyle(color: AppColors.outline, fontSize: 11),
        ),
        GestureDetector(
          onTap: () => Navigator.pushNamed(context, '/SignupStep1'),
          child: const Text(
            'Sign up as Student →',
            style: TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDemoButton() {
    return GestureDetector(
      onTap: () => setState(() => _showDemoPanel = !_showDemoPanel),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.rocket_launch_rounded,
              size: 14,
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
              _showDemoPanel ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
              size: 16,
              color: AppColors.primary,
            ),
          ],
        ),
      ),
    );
  }

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
              fontWeight: FontWeight.w600,
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
                  onTap: () => _fillDemo('alex.smith@school.com', 'Student@123', false),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _demoAccountChip(
                  label: 'Teacher',
                  icon: Icons.person_rounded,
                  color: AppColors.primary,
                  onTap: () => _fillDemo('robert.johnson@school.com', 'Teacher@123', true),
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
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
