import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'state/app_state.dart';
import 'services/notification_service.dart';
import 'screens/home_page.dart';
import 'screens/focus_page.dart';
import 'screens/health_page.dart';
import 'screens/statistics_page.dart';
import 'screens/social_page.dart';
import 'screens/character_page.dart';
import 'screens/account_page.dart';
import 'theme/app_ui.dart';
import 'screens/onboarding_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.initialize();
  try {
    await Firebase.initializeApp();
    debugPrint('Firebase initialized successfully');
  } catch (e) {
    debugPrint('Firebase initialization failed: $e');
    debugPrint('Please ensure google-services.json and GoogleService-Info.plist are correctly configured.');
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
        final compactScale = width <= 400 || height <= 760
            ? 0.90
            : width <= 430
            ? 0.96
            : 1.0;
        final systemTextScale = mediaQuery.textScaler
            .scale(1)
            .clamp(0.85, 1.12)
            .toDouble();
        final adjustedMediaQuery = mediaQuery.copyWith(
          textScaler: TextScaler.linear(systemTextScale * compactScale),
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
        cardColor: Colors.white,
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
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
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
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
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
        dialogTheme: DialogThemeData(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: seedColor,
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: Colors.transparent,
        cardColor: const Color(0xFF1A1D24),
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
          color: const Color(0xFF1A1D24),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
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
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
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
        dialogTheme: DialogThemeData(
          backgroundColor: const Color(0xFF1A1D24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
        ),
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

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final accentColor = appState.currentIconColor;

    final pages = [
      HomePage(onNavigate: changeTab, onOpenStatistics: openStatisticsPage),
      const CharacterPage(),
      const FocusPage(),
      const SocialPage(),
      const HealthPage(),
      const AccountPage(),
    ];

    return Scaffold(
      body: IndexedStack(index: currentIndex, children: pages),
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarTheme.of(context).copyWith(
          indicatorColor: accentColor.withValues(
            alpha: AppUI.isDark(context) ? 0.22 : 0.14,
          ),
          iconTheme: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return IconThemeData(color: accentColor);
            }
            return IconThemeData(
              color: AppUI.isDark(context)
                  ? const Color(0xFFB6BDC9)
                  : const Color(0xFF6B7280),
            );
          }),
        ),
        child: NavigationBar(
          selectedIndex: currentIndex,
          onDestinationSelected: changeTab,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: '首頁',
            ),
            NavigationDestination(
              icon: Icon(Icons.auto_awesome_outlined),
              selectedIcon: Icon(Icons.auto_awesome),
              label: '角色',
            ),
            NavigationDestination(
              icon: Icon(Icons.timer_outlined),
              selectedIcon: Icon(Icons.timer),
              label: '專注',
            ),
            NavigationDestination(
              icon: Icon(Icons.people_alt_outlined),
              selectedIcon: Icon(Icons.people_alt),
              label: '社交',
            ),
            NavigationDestination(
              icon: Icon(Icons.favorite_border),
              selectedIcon: Icon(Icons.favorite),
              label: '健康',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline_rounded),
              selectedIcon: Icon(Icons.person_rounded),
              label: '帳號',
            ),
          ],
        ),
      ),
    );
  }
}
