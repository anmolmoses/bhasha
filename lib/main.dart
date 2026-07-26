import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'services/storage_service.dart';
import 'services/parent_profile_service.dart';
import 'services/platform_service.dart';
import 'screens/onboarding_screen.dart';
import 'screens/home_screen.dart';
import 'services/overlay_request_handler.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize storage
  await StorageService().init();

  // Saved voice, tone, and glossary must be in memory before the first bubble
  // action arrives, which can happen with no screen ever opened.
  await ParentProfileService().load();

  OverlayRequestHandler().init();

  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bhasha',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: const InitialScreen(),
    );
  }
}

class InitialScreen extends StatefulWidget {
  const InitialScreen({super.key});

  @override
  State<InitialScreen> createState() => _InitialScreenState();
}

class _InitialScreenState extends State<InitialScreen> {
  final _storage = StorageService();

  @override
  void initState() {
    super.initState();
    _checkFirstTime();
  }

  Future<void> _checkFirstTime() async {
    // Small delay for splash effect
    await Future.delayed(const Duration(milliseconds: 500));

    final isFirstTime = !_storage.isFirstTimeSetupComplete();
    final hasApiKey = await _storage.hasSarvamApiKey();

    if (hasApiKey) {
      // Initialize floating action type in overlay service
      final actionType = _storage.getFloatingActionType();
      await PlatformService().updateFloatingActionType(actionType);
    }

    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => isFirstTime || !hasApiKey
              ? const OnboardingScreen()
              : const HomeScreen(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.translate,
              size: 100,
              color: Theme.of(context).primaryColor,
            ),
            const SizedBox(height: 24),
            const Text(
              'Bhasha',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
