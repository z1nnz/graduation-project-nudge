import 'package:flutter/material.dart';

class AppUI {
  static const Color primary = Color(0xFF7C6AE6);
  static const Color primaryDark = Color(0xFF6E5AE6);
  static const Color background = Color(0xFFF7F6FB);

  // 舊專案相容用：先保留固定色
  static const Color textPrimary = Color(0xFF2D2A32);
  static const Color textSecondary = Color(0xFF6B7280);

  // 深色模式 helper 用
  static const Color darkTextPrimary = Color(0xFFF3F4F6);
  static const Color darkTextSecondary = Color(0xFFB6BDC9);

  static const Color lightCard = Colors.white;
  static const Color darkCard = Color(0xFF1A1D24);

  static const Color blue = Color(0xFF4F8CFF);
  static const Color green = Color(0xFF10B981);
  static const Color purple = Color(0xFF8B5CF6);
  static const Color orange = Color(0xFFF59E0B);

  static const double radiusCard = 20;
  static const double radiusLarge = 28;
  static const double radiusPill = 999;

  static const double pagePadding = 16;
  static const double sectionGap = 20;
  static const double cardGap = 12;
  static const double innerPadding = 16;

  // 舊專案相容用：保留靜態 TextStyle
  static const TextStyle sectionTitle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.bold,
    color: textPrimary,
  );

  static const TextStyle cardTitle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.bold,
    color: textPrimary,
  );

  static const TextStyle body = TextStyle(
    fontSize: 14,
    color: textSecondary,
    height: 1.5,
  );

  static const TextStyle strongValue = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.bold,
    color: textPrimary,
  );

  static bool isDark(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark;
  }

  static Color textPrimaryOf(BuildContext context) {
    return isDark(context) ? darkTextPrimary : textPrimary;
  }

  static Color textSecondaryOf(BuildContext context) {
    return isDark(context) ? darkTextSecondary : textSecondary;
  }

  static Color cardColorOf(BuildContext context) {
    return isDark(context) ? darkCard : lightCard;
  }

  static Color surfaceVariantOf(BuildContext context) {
    return isDark(context) ? const Color(0xFF202530) : const Color(0xFFF4F1FF);
  }

  static Color scaffoldBackgroundOf(BuildContext context) {
    return Colors.transparent;
  }

  static const List<String> backgroundThemeKeys = [
    'softGlow',
    'nightStudy',
    'sakuraWalk',
    'galaxySleep',
    'gymEnergy',
  ];

  static String backgroundThemeLabel(String key) {
    switch (key) {
      case 'nightStudy':
        return '夜讀星空';
      case 'sakuraWalk':
        return '櫻花步道';
      case 'galaxySleep':
        return '銀河睡眠艙';
      case 'gymEnergy':
        return '健身能量';
      case 'softGlow':
      default:
        return '預設柔光';
    }
  }

  static String backgroundThemeDescription(String key) {
    switch (key) {
      case 'nightStudy':
        return '適合晚間讀書與深度專注，讓整個 App 像安靜書桌。';
      case 'sakuraWalk':
        return '把健康步行和輕任務變成柔和的戶外節奏。';
      case 'galaxySleep':
        return '睡眠、恢復和夜間檢視用的沉靜銀河氛圍。';
      case 'gymEnergy':
        return '運動與行動任務用的高能量綠色主題。';
      case 'softGlow':
      default:
        return '預設背景主題，所有使用者一開始就能套用。';
    }
  }

  static IconData backgroundThemeIcon(String key) {
    switch (key) {
      case 'nightStudy':
        return Icons.menu_book_outlined;
      case 'sakuraWalk':
        return Icons.directions_walk_rounded;
      case 'galaxySleep':
        return Icons.bedtime_outlined;
      case 'gymEnergy':
        return Icons.fitness_center_rounded;
      case 'softGlow':
      default:
        return Icons.auto_awesome_outlined;
    }
  }

  static int backgroundThemePrice(String key) {
    switch (key) {
      case 'nightStudy':
        return 35;
      case 'sakuraWalk':
        return 45;
      case 'galaxySleep':
        return 55;
      case 'gymEnergy':
        return 40;
      case 'softGlow':
      default:
        return 0;
    }
  }

  static List<Color> backgroundThemeColors(String key, bool isDarkMode) {
    if (isDarkMode) {
      switch (key) {
        case 'nightStudy':
          return const [
            Color(0xFF07111F),
            Color(0xFF10233D),
            Color(0xFF111827),
          ];
        case 'sakuraWalk':
          return const [
            Color(0xFF1B1220),
            Color(0xFF2B1D32),
            Color(0xFF161318),
          ];
        case 'galaxySleep':
          return const [
            Color(0xFF080B1E),
            Color(0xFF20144A),
            Color(0xFF111318),
          ];
        case 'gymEnergy':
          return const [
            Color(0xFF101A16),
            Color(0xFF143326),
            Color(0xFF111318),
          ];
        case 'softGlow':
        default:
          return const [
            Color(0xFF10131A),
            Color(0xFF151923),
            Color(0xFF111318),
          ];
      }
    }

    switch (key) {
      case 'nightStudy':
        return const [Color(0xFFF8FBFF), Color(0xFFEAF2FF), Color(0xFFF7F6FB)];
      case 'sakuraWalk':
        return const [Color(0xFFFFFBFC), Color(0xFFFFEDF4), Color(0xFFF7F6FB)];
      case 'galaxySleep':
        return const [Color(0xFFFBFAFF), Color(0xFFEDEBFF), Color(0xFFF7F6FB)];
      case 'gymEnergy':
        return const [Color(0xFFFAFFFC), Color(0xFFE6F8EF), Color(0xFFF7F6FB)];
      case 'softGlow':
      default:
        return const [Color(0xFFFBFAFF), Color(0xFFF4F1FF), Color(0xFFF7F6FB)];
    }
  }

  static BoxDecoration appBackgroundDecoration(
    BuildContext context, {
    String themeKey = 'softGlow',
  }) {
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: backgroundThemeColors(themeKey, isDark(context)),
      ),
    );
  }

  static TextStyle sectionTitleOf(BuildContext context) {
    return TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.bold,
      color: textPrimaryOf(context),
    );
  }

  static TextStyle cardTitleOf(BuildContext context) {
    return TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.bold,
      color: textPrimaryOf(context),
    );
  }

  static TextStyle bodyOf(BuildContext context) {
    return TextStyle(
      fontSize: 14,
      color: textSecondaryOf(context),
      height: 1.5,
    );
  }

  static TextStyle strongValueOf(BuildContext context) {
    return TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.bold,
      color: textPrimaryOf(context),
    );
  }

  static BoxDecoration heroGradient([Color baseColor = primary]) {
    final lightColor = Color.lerp(baseColor, Colors.white, 0.12) ?? baseColor;
    final darkColor = Color.lerp(baseColor, Colors.black, 0.08) ?? baseColor;

    return BoxDecoration(
      gradient: LinearGradient(
        colors: [lightColor, darkColor],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(radiusLarge),
    );
  }

  // 舊專案相容用：保留原本 1 參數版本
  static BoxDecoration softCard(Color color) {
    return BoxDecoration(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(18),
    );
  }

  // 新版深色模式可用
  static BoxDecoration softCardOf(BuildContext context, Color color) {
    final opacity = isDark(context) ? 0.16 : 0.08;
    return BoxDecoration(
      color: color.withValues(alpha: opacity),
      borderRadius: BorderRadius.circular(18),
    );
  }

  static ShapeBorder cardShape() {
    return RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radiusCard),
    );
  }

  // 舊專案相容用
  static Widget sectionHeader(String title) {
    return Text(title, style: sectionTitle);
  }

  // 新版深色模式可用
  static Widget sectionHeaderOf(BuildContext context, String title) {
    return Text(title, style: sectionTitleOf(context));
  }
}

class AppBackground extends StatelessWidget {
  final Widget child;
  final String themeKey;

  const AppBackground({
    super.key,
    required this.child,
    this.themeKey = 'softGlow',
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: AppUI.appBackgroundDecoration(context, themeKey: themeKey),
      child: CustomPaint(
        painter: _AppBackgroundPainter(
          isDark: AppUI.isDark(context),
          themeKey: themeKey,
        ),
        child: child,
      ),
    );
  }
}

class _AppBackgroundPainter extends CustomPainter {
  final bool isDark;
  final String themeKey;

  const _AppBackgroundPainter({required this.isDark, required this.themeKey});

  @override
  void paint(Canvas canvas, Size size) {
    final themeColors = AppUI.backgroundThemeColors(themeKey, isDark);
    final primary = themeColors.length > 1 ? themeColors[1] : AppUI.primary;
    final blue = themeKey == 'galaxySleep' ? AppUI.purple : AppUI.blue;
    final green = themeKey == 'sakuraWalk'
        ? const Color(0xFFEC4899)
        : AppUI.green;

    void drawSoftCircle(
      Offset center,
      double radius,
      Color color,
      double alpha,
    ) {
      final paint = Paint()..color = color.withValues(alpha: alpha);
      canvas.drawCircle(center, radius, paint);
    }

    drawSoftCircle(
      Offset(size.width * 0.12, size.height * 0.10),
      size.width * 0.34,
      primary,
      isDark ? 0.10 : 0.08,
    );
    drawSoftCircle(
      Offset(size.width * 0.92, size.height * 0.26),
      size.width * 0.30,
      blue,
      isDark ? 0.08 : 0.06,
    );
    drawSoftCircle(
      Offset(size.width * 0.18, size.height * 0.86),
      size.width * 0.28,
      green,
      isDark ? 0.06 : 0.05,
    );

    final linePaint = Paint()
      ..color = (isDark ? Colors.white : primary).withValues(
        alpha: isDark ? 0.025 : 0.035,
      )
      ..strokeWidth = 1;

    const gap = 48.0;
    for (double y = 0; y < size.height + gap; y += gap) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y + 22), linePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _AppBackgroundPainter oldDelegate) {
    return oldDelegate.isDark != isDark || oldDelegate.themeKey != themeKey;
  }
}
