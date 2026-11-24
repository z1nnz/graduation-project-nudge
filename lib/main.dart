import 'theme/app_text_scale.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'state/app_state.dart';
import 'services/notification_service.dart';
import 'services/firebase_app_check_service.dart';
import 'screens/home_page.dart';
import 'screens/statistics_page.dart';
import 'screens/social_page.dart';
import 'screens/group_management_page.dart';
import 'screens/guardian_center_page.dart';
import 'theme/app_ui.dart';
import 'theme/game_ui.dart';
import 'screens/onboarding_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.initialize();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    await FirebaseAppCheckService.activate();
    debugPrint('Firebase initialized successfully');
  } catch (e) {
    debugPrint('Firebase initialization failed: $e');
    debugPrint(
      'Please ensure google-services.json and GoogleService-Info.plist are correctly configured.',
    );
  }
  runApp(const NudgeApp());
}

class NudgeApp extends StatelessWidget {
  const NudgeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppState()..loadAllLocalData(),
      child: const _AppRoot(),
    );
  }
}

class _AppRoot extends StatelessWidget {
  const _AppRoot();

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    const seedColor = Color(0xFF7C6AE6);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Nudge',
      themeMode: appState.currentThemeMode,
      builder: (context, child) {
        final mediaQuery = MediaQuery.of(context);
        final width = mediaQuery.size.width;
        final height = mediaQuery.size.height;
        final adjustedMediaQuery = mediaQuery.copyWith(
          textScaler: TextScaler.linear(
            appTextScale(
              width: width,
              height: height,
              system: mediaQuery.textScaler.scale(1),
            ),
          ),
        );

        final iconScale = width <= 400 || height <= 760
            ? 0.92
            : width <= 430
            ? 0.97
            : 1.0;

        return AppBackground(
          themeKey: appState.backgroundThemeSetting,
          child: MediaQuery(
            data: adjustedMediaQuery,
            child: IconTheme.merge(
              data: IconThemeData(size: 24 * iconScale),
              child: child ?? const SizedBox.shrink(),
            ),
          ),
        );
      },
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: seedColor,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: Colors.transparent,
        cardColor: GamePalette.light.panel,
        dividerColor: const Color(0xFFE5E7EB),
        shadowColor: Colors.black.withValues(alpha: 0.05),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Color(0xFF2D2A32)),
          bodyMedium: TextStyle(color: Color(0xFF2D2A32)),
          bodySmall: TextStyle(color: Color(0xFF6B7280)),
          titleLarge: TextStyle(color: Color(0xFF2D2A32)),
          titleMedium: TextStyle(color: Color(0xFF2D2A32)),
          titleSmall: TextStyle(color: Color(0xFF2D2A32)),
        ),
        cardTheme: CardThemeData(
          color: GamePalette.light.panel,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: AppUI.cardFrame, width: 2),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: GamePalette.gold,
            foregroundColor: const Color(0xFF2A1600),
            textStyle: const TextStyle(fontWeight: FontWeight.w900),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          foregroundColor: Color(0xFF2D2A32),
          centerTitle: false,
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          indicatorColor: seedColor.withValues(alpha: 0.14),
          labelTextStyle: WidgetStateProperty.all(
            const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF2D2A32),
            ),
          ),
          iconTheme: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const IconThemeData(color: seedColor);
            }
            return const IconThemeData(color: Color(0xFF6B7280));
          }),
        ),
        elevatedButtonTheme: GameTheme.primaryButton(),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
          labelStyle: const TextStyle(color: Color(0xFF6B7280)),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: seedColor, width: 1.4),
          ),
        ),
        dialogTheme: GameTheme.dialog(dark: false),
        textButtonTheme: GameTheme.secondaryButton(dark: false),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: seedColor,
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: Colors.transparent,
        cardColor: GamePalette.dark.panel,
        dividerColor: const Color(0xFF2A2F3A),
        shadowColor: Colors.black.withValues(alpha: 0.20),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Color(0xFFF3F4F6)),
          bodyMedium: TextStyle(color: Color(0xFFF3F4F6)),
          bodySmall: TextStyle(color: Color(0xFFB6BDC9)),
          titleLarge: TextStyle(color: Color(0xFFF3F4F6)),
          titleMedium: TextStyle(color: Color(0xFFF3F4F6)),
          titleSmall: TextStyle(color: Color(0xFFF3F4F6)),
        ),
        cardTheme: CardThemeData(
          color: GamePalette.dark.panel,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: AppUI.cardFrame, width: 2),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: GamePalette.gold,
            foregroundColor: const Color(0xFF2A1600),
            textStyle: const TextStyle(fontWeight: FontWeight.w900),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          foregroundColor: Color(0xFFF3F4F6),
          centerTitle: false,
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: const Color(0xFF161A21),
          surfaceTintColor: Colors.transparent,
          indicatorColor: seedColor.withValues(alpha: 0.22),
          labelTextStyle: WidgetStateProperty.all(
            const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFFF3F4F6),
            ),
          ),
          iconTheme: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const IconThemeData(color: seedColor);
            }
            return const IconThemeData(color: Color(0xFFB6BDC9));
          }),
        ),
        elevatedButtonTheme: GameTheme.primaryButton(),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF1A1D24),
          hintStyle: const TextStyle(color: Color(0xFF8B93A1)),
          labelStyle: const TextStyle(color: Color(0xFFB6BDC9)),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFF2A2F3A)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: seedColor, width: 1.4),
          ),
        ),
        dialogTheme: GameTheme.dialog(dark: true),
        textButtonTheme: GameTheme.secondaryButton(dark: true),
      ),
      // App always goes directly to main shell — sign in/register via Account tab
      home: !appState.isHydrated
          ? const _AppLoadingScreen()
          : (appState.hasCompletedOnboarding
                ? const MainShell()
                : const OnboardingPage()),
    );
  }
}

class _AppLoadingScreen extends StatelessWidget {
  const _AppLoadingScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 34,
              height: 34,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
            const SizedBox(height: 16),
            Text('正在準備 Nudge', style: AppUI.cardTitleOf(context)),
          ],
        ),
      ),
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int currentIndex = 0;
  String? _scheduledPushRoute;

  void changeTab(int index) {
    setState(() {
      currentIndex = index;
    });
  }

  void openStatisticsPage() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const StatisticsPage()),
    );
  }

  void _schedulePushRoute(AppState appState) {
    final route = appState.pendingPushNotificationRoute;
    if (route == null || route == _scheduledPushRoute) return;
    _scheduledPushRoute = route;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final pendingRoute = appState.takePendingPushNotificationRoute();
      _scheduledPushRoute = null;
      if (pendingRoute == null) return;
      switch (pendingRoute) {
        case 'guardian':
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const GuardianCenterPage()),
          );
          break;
        case 'groups':
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const GroupManagementPage()),
          );
          break;
        default:
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SocialPage()),
          );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    _schedulePushRoute(appState);

    // The cabin is the whole App: room objects open every feature, so there
    // is no bottom navigation bar.
    return HomePage(
      onNavigate: changeTab,
      onOpenStatistics: openStatisticsPage,
    );
  }
}
