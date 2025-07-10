import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'theme.dart';
import 'services/database_service.dart';
import 'services/notification_service.dart';
import 'services/supabase_service.dart';
import 'pages/onboarding_page.dart';
import 'pages/main_tracker_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  if (kIsWeb) {
    databaseFactory = databaseFactoryFfiWeb;
  }
  
  // Initialize services with error handling
  try {
    await NotificationService().initialize();
  } catch (e) {
    debugPrint('Failed to initialize notification service: $e');
  }
  
  try {
    await SupabaseService.initialize();
  } catch (e) {
    debugPrint('Failed to initialize Supabase service: $e');
  }
  
  runApp(const ProviderScope(child: SavageStreakApp()));
}

class SavageStreakApp extends StatelessWidget {
  const SavageStreakApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Savage Streak',
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: ThemeMode.dark,
      home: const SplashScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkForExistingHabit();
  }

  Future<void> _checkForExistingHabit() async {
    // Small delay for splash effect
    await Future.delayed(const Duration(milliseconds: 1000));
    
    final habit = await DatabaseService().getCurrentHabit();
    
    if (mounted) {
      if (habit != null) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const MainTrackerPage()),
        );
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const OnboardingPage()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              '🔥',
              style: TextStyle(fontSize: 80),
            ),
            const SizedBox(height: 24),
            Text(
              'Savage Streak',
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                color: const Color(0xFF00D07E),
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'One habit. No excuses.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: const Color(0xFF9E9E9E),
              ),
            ),
            const SizedBox(height: 48),
            const CircularProgressIndicator(
              color: Color(0xFF00D07E),
            ),
          ],
        ),
      ),
    );
  }
}