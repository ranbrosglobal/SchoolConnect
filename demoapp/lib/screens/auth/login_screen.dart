import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../state/auth_provider.dart';
import '../../models/user_model.dart';
import '../teacher/teacher_dashboard.dart';
import '../student/student_dashboard.dart';
import '../admin_web_redirect.dart';
import 'signup_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  // 0 = Teacher (default active), 1 = Student
  int _selectedRole = 0;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _emailController.text = 'robert.johnson@school.com';
    _passwordController.text = 'Teacher@123';
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _onRoleChanged(int index) {
    setState(() {
      _selectedRole = index;
      if (index == 0) {
        _emailController.text = 'robert.johnson@school.com';
        _passwordController.text = 'Teacher@123';
      } else {
        _emailController.text = 'alex.smith@school.com';
        _passwordController.text = 'Student@123';
      }
    });
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    final success = await ref.read(authProvider.notifier).login(
      _emailController.text.trim(),
      _passwordController.text,
    );
    if (success && mounted) _navigateToDashboard();
  }

  void _navigateToDashboard() {
    final user = ref.read(authProvider).user;
    if (user == null) return;
    Widget dashboard;
    switch (user.role) {
      case UserRole.superAdmin:
      case UserRole.admin:
      case UserRole.schoolAdmin:
        dashboard = const AdminWebRedirect();
        break;
      case UserRole.instructor:
        dashboard = const TeacherDashboard();
        break;
      case UserRole.student:
        dashboard = const StudentDashboard();
        break;
    }
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => dashboard));
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final isTeacher = _selectedRole == 0;

    // Auto-navigate if session was restored from previous login
    if (authState.isAuthenticated && !_navigated) {
      _navigated = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _navigateToDashboard();
      });
    }

    // Show loading while restoring session
    if (authState.isLoading && authState.user == null) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Restoring session...'),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F3FF),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 24),

                // ── Logo ──────────────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF7C3AED).withOpacity(0.15),
                        blurRadius: 20,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.school, color: Color(0xFF7C3AED), size: 38),
                ),
                const SizedBox(height: 10),
                const Text(
                  'School Connect',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF1E1B4B),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Learn. Teach. Grow. ',
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                    ),
                    const Text('Together.', style: TextStyle(fontSize: 13, color: Color(0xFF7C3AED), fontWeight: FontWeight.w800)),
                  ],
                ),

                const SizedBox(height: 20),

                // ── Welcome ──────────────────────────────────────────────
                const Text(
                  'Welcome back! 👋',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Color(0xFF1E1B4B)),
                ),
                const SizedBox(height: 6),
                Text(
                  'Login to continue your journey',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                ),

                const SizedBox(height: 16),

                // ── Illustration ─────────────────────────────────────────
                SizedBox(
                  height: 200,
                  child: Image.asset(
                    'assets/images/login_illustration.png',
                    fit: BoxFit.contain,
                  ),
                ),

                const SizedBox(height: 16),

                // ── White card ───────────────────────────────────────────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 24,
                        spreadRadius: 4,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      // ── "Login as" toggle ─────────────────────────────
                      const Center(
                        child: Text('Login as',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1E1B4B))),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            // Teacher tab
                            Expanded(
                              child: GestureDetector(
                                onTap: () => _onRoleChanged(0),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 220),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(
                                    gradient: isTeacher
                                        ? const LinearGradient(
                                            colors: [Color(0xFF7C3AED), Color(0xFF5B21B6)],
                                          )
                                        : null,
                                    color: isTeacher ? null : Colors.transparent,
                                    borderRadius: BorderRadius.circular(10),
                                    boxShadow: isTeacher
                                        ? [
                                            BoxShadow(
                                              color: const Color(0xFF7C3AED).withOpacity(0.35),
                                              blurRadius: 8,
                                              offset: const Offset(0, 4),
                                            )
                                          ]
                                        : [],
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.person_outline,
                                          color: isTeacher ? Colors.white : Colors.grey.shade500, size: 18),
                                      const SizedBox(width: 6),
                                      Text('Teacher',
                                          style: TextStyle(
                                            color: isTeacher ? Colors.white : Colors.grey.shade600,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          )),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            // Student tab
                            Expanded(
                              child: GestureDetector(
                                onTap: () => _onRoleChanged(1),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 220),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(
                                    color: !isTeacher ? Colors.white : Colors.transparent,
                                    borderRadius: BorderRadius.circular(10),
                                    boxShadow: !isTeacher
                                        ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))]
                                        : [],
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.school_outlined,
                                          color: !isTeacher ? const Color(0xFF7C3AED) : Colors.grey.shade500, size: 18),
                                      const SizedBox(width: 6),
                                      Text('Student',
                                          style: TextStyle(
                                            color: !isTeacher ? const Color(0xFF7C3AED) : Colors.grey.shade600,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          )),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Purple underline indicator
                      Center(
                        child: Container(
                          margin: const EdgeInsets.only(top: 8),
                          width: 36,
                          height: 4,
                          decoration: BoxDecoration(
                            color: const Color(0xFF7C3AED),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),

                      const SizedBox(height: 22),

                      // ── Email / ID ────────────────────────────────────
                      const Text('Email / ID',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1E1B4B))),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        style: const TextStyle(fontSize: 15, color: Color(0xFF1E1B4B)),
                        decoration: _inputDeco(hint: 'Enter your email or ID', icon: Icons.email_outlined),
                        validator: (v) => v!.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 18),

                      // ── Password ───────────────────────────────────────
                      const Text('Password',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1E1B4B))),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        style: const TextStyle(fontSize: 15, color: Color(0xFF1E1B4B)),
                        decoration: _inputDeco(hint: 'Enter your password', icon: Icons.lock_outline).copyWith(
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                              color: Colors.grey.shade500,
                              size: 20,
                            ),
                            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                          ),
                        ),
                        validator: (v) => v!.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 8),

                      // Forgot password
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () {},
                          style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero),
                          child: const Text('Forgot Password?',
                              style: TextStyle(color: Color(0xFF7C3AED), fontWeight: FontWeight.w700, fontSize: 13)),
                        ),
                      ),

                      if (authState.error != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(authState.error!,
                              style: TextStyle(color: Colors.red.shade700, fontSize: 13)),
                        ),

                      const SizedBox(height: 8),

                      // ── Login button ───────────────────────────────────
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF7C3AED), Color(0xFF5B21B6)],
                            ),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF7C3AED).withOpacity(0.4),
                                blurRadius: 12,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            onPressed: authState.isLoading ? null : _login,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            child: authState.isLoading
                                ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5)
                                : const Text('Login',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
                          ),
                        ),
                      ),

                      const SizedBox(height: 22),

                      // ── Sign up link ───────────────────────────────────
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text("Don't have an account? ",
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                          GestureDetector(
                            onTap: () => Navigator.of(context)
                                .push(MaterialPageRoute(builder: (_) => const SignupScreen())),
                            child: const Row(children: [
                              Text('Sign up as Student',
                                  style: TextStyle(
                                      color: Color(0xFF7C3AED), fontWeight: FontWeight.w800, fontSize: 13)),
                              SizedBox(width: 4),
                              Icon(Icons.arrow_forward, color: Color(0xFF7C3AED), size: 14),
                            ]),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // ── Bottom doodle row ─────────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Icon(Icons.backpack_outlined, size: 52, color: const Color(0xFF7C3AED).withOpacity(0.3)),
                    Icon(Icons.menu_book, size: 36, color: Colors.indigo.withOpacity(0.3)),
                    Icon(Icons.auto_stories_outlined, size: 30, color: Colors.indigo.withOpacity(0.2)),
                    Icon(Icons.eco_outlined, size: 44, color: Colors.green.withOpacity(0.3)),
                  ],
                ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDeco({required String hint, required IconData icon}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
      prefixIcon: Icon(icon, color: const Color(0xFF7C3AED), size: 20),
      filled: true,
      fillColor: const Color(0xFFF8F5FF),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: const Color(0xFF7C3AED).withOpacity(0.25), width: 1.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: const Color(0xFF7C3AED).withOpacity(0.25), width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF7C3AED), width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(vertical: 16),
    );
  }}
