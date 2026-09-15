import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'theme/app_theme.dart';
import 'routes.dart';
import 'screens/6_login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Firebase is only needed for Google/Apple sign-in (demo mode).
  // The live build uses the SQLite-backed API with email/password auth and does
  // not require Firebase. Wrap in try/catch so a missing SHA fingerprint or
  // misconfigured google-services.json does not crash the entire app.
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    ).timeout(const Duration(seconds: 8));
  } catch (e) {
    debugPrint('Firebase init skipped: $e');
  }
  runApp(
    const ProviderScope(
      child: SchoolConnectApp(),
    ),
  );
}

class SchoolConnectApp extends StatelessWidget {
  const SchoolConnectApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'School Connect',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routes: AppRoutes.routes,
      home: const LoginScreen(),
      // Smooth page transitions
      themeMode: ThemeMode.light,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.noScaling,
          ),
          child: child!,
        );
      },
    );
  }
}
