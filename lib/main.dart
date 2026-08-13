import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'theme/app_theme.dart';
import 'dictionary/dictionary_service.dart';
import 'features/home/home_screen.dart';
import 'features/auth/auth_service.dart';
import 'features/hints/hint_service.dart';
import 'core/supabase_bootstrap.dart';
import 'core/push_notification_service.dart';
import 'core/ad_service.dart';
import 'core/billing_service.dart';
import 'core/tap_feedback.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseBootstrap.initialize();
  unawaited(PushNotificationService.initialize());
  unawaited(AdService().initialize());
  unawaited(BillingService().initialize());
  runApp(const ProviderScope(child: LetterLoomApp()));
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(_requestStartupPermissions());
  });
}

Future<void> _requestStartupPermissions() async {
  // Keep the permission sequence intentional: notification permission first,
  // then microphone permission for multiplayer voice chat.
  await PushNotificationService.initialize();
  await PushNotificationService.requestPermissionAndRegister();
  await Permission.microphone.request();
}

class LetterLoomApp extends StatelessWidget {
  const LetterLoomApp({super.key});

  @override
  Widget build(BuildContext context) {
    return TapFeedback(
      child: MaterialApp(
        navigatorKey: PushNotificationService.navigatorKey,
        title: 'LetterLoom',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: const SplashScreen(),
      ),
    );
  }
}

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late AnimationController _logoPulseController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _logoPulseAnimation;
  String _loadingStatus = "Threading the Loom...";
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _logoPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1050),
    )..repeat(reverse: true);
    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _logoPulseAnimation = Tween<double>(begin: 0.96, end: 1.035).animate(
      CurvedAnimation(parent: _logoPulseController, curve: Curves.easeInOut),
    );
    _controller.forward();
    _initDictionary();
  }

  Future<void> _initDictionary() async {
    // Home never mounts with guest/default header data for a restored account.
    await Future.wait([
      _warmDictionary(),
      ref.read(authProvider.notifier).ready,
      ref.read(hintServiceProvider.notifier).ready,
      Future<void>.delayed(const Duration(milliseconds: 350)),
    ]);
    unawaited(
      BillingService().recoverPendingPurchases(
        onPurchaseFulfilled: () =>
            ref.read(hintServiceProvider.notifier).refresh(),
        onError: (error) => debugPrint('[Billing] Recovery: $error'),
      ),
    );
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
    _logoPulseController.dispose();
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
              ScaleTransition(
                scale: _logoPulseAnimation,
                child: Container(
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
                    child: Padding(
                      padding: const EdgeInsets.all(3),
                      child: Image.asset(
                        'assets/images/logo.png',
                        fit: BoxFit.contain,
                      ),
                    ),
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
                  Text('→', style: _splashOrnamentStyle()),
                  const Text(
                    'Solo Offline · Online Play',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      color: AppTheme.mutedIvory,
                      letterSpacing: 0.7,
                    ),
                  ),
                  Text('←', style: _splashOrnamentStyle()),
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
