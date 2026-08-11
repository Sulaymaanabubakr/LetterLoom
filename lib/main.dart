import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'theme/app_theme.dart';
import 'dictionary/dictionary_service.dart';
import 'features/home/home_screen.dart';
import 'core/supabase_bootstrap.dart';
import 'core/push_notification_service.dart';
import 'core/ad_service.dart';
import 'core/billing_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseBootstrap.initialize();
  unawaited(PushNotificationService.initialize());
  unawaited(AdService().initialize());
  unawaited(BillingService().initialize());
  runApp(const ProviderScope(child: LetterLoomApp()));
}

class LetterLoomApp extends StatelessWidget {
  const LetterLoomApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LetterLoom',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  String _loadingStatus = "Threading the Loom...";
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _controller.forward();
    _initDictionary();
  }

  Future<void> _initDictionary() async {
    unawaited(_warmDictionary());
    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const HomeScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 350),
      ),
    );
  }

  Future<void> _warmDictionary() async {
    try {
      await DictionaryService().load();
    } catch (_) {
      // Word validation will surface the normal dictionary error when needed.
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.forestGreen,
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo Symbol
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppTheme.shinyGold.withValues(alpha: 0.8),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      offset: const Offset(0, 8),
                      blurRadius: 14,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Image.asset(
                    'assets/images/logo.png',
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              // App Name
              const Text(
                'LetterLoom',
                style: TextStyle(
                  fontFamily: 'Lora',
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.ivoryText,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('➔  ', style: _splashOrnamentStyle()),
                  const Text(
                    'Solo Offline · Online Play',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      color: AppTheme.mutedIvory,
                      letterSpacing: 0.7,
                    ),
                  ),
                  Text('  ➔', style: _splashOrnamentStyle()),
                ],
              ),
              const SizedBox(height: 64),
              if (!_hasError)
                const SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppTheme.shinyGold,
                    ),
                    strokeWidth: 2.5,
                  ),
                ),
              const SizedBox(height: 16),
              Text(
                _loadingStatus,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  color: _hasError
                      ? Colors.redAccent
                      : AppTheme.ivoryText.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  TextStyle _splashOrnamentStyle() => const TextStyle(
    fontFamily: 'Inter',
    fontSize: 12,
    fontWeight: FontWeight.bold,
    color: AppTheme.shinyGold,
  );
}
