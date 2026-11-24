import 'package:flutter/material.dart';

/// Shared "cosy evening cabin" game look for every App page: wood frames,
/// parchment panels, gold primary buttons and violet accents, matching the
/// pixel companion cabin. Light and dark variants keep text contrast.
class GamePalette {
  const GamePalette._({
    required this.backgroundTop,
    required this.backgroundBottom,
    required this.panel,
    required this.panelBorder,
    required this.ink,
    required this.inkMuted,
    required this.wood,
  });

  final Color backgroundTop;
  final Color backgroundBottom;
  final Color panel;
  final Color panelBorder;
  final Color ink;
  final Color inkMuted;
  final Color wood;

  static const gold = Color(0xFFFFC54D);
  static const goldDeep = Color(0xFFC4710B);
  static const violet = Color(0xFF7C6AE6);
  static const green = Color(0xFF3CCF7A);
  static const red = Color(0xFFD6455D);

  static const light = GamePalette._(
    backgroundTop: Color(0xFFFBEFD9),
    backgroundBottom: Color(0xFFEEDCF7),
    panel: Color(0xFFFFFAF0),
    panelBorder: Color(0xFFA8743F),
    ink: Color(0xFF3A1D0C),
    inkMuted: Color(0xFF7A5532),
    wood: Color(0xFF8A5A34),
  );

  static const dark = GamePalette._(
    backgroundTop: Color(0xFF2A1A14),
    backgroundBottom: Color(0xFF1B1530),
    panel: Color(0xFF3A251C),
    panelBorder: Color(0xFF8A5A34),
    ink: Color(0xFFFBEFE2),
    inkMuted: Color(0xFFD8BFA8),
    wood: Color(0xFFB98552),
  );

  static GamePalette of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;
}

enum GameTone { gold, violet, green, red, wood }

Color _toneColor(GameTone tone, GamePalette p) => switch (tone) {
  GameTone.gold => GamePalette.gold,
  GameTone.violet => GamePalette.violet,
  GameTone.green => GamePalette.green,
  GameTone.red => GamePalette.red,
  GameTone.wood => p.wood,
};

/// Warm gradient page background behind game panels.
/// Theme pieces that make system widgets (dialogs, primary buttons) match
/// the wooden game UI.
class GameTheme {
  GameTheme._();

  static const _wood = Color(0xFF8A5A34);
  static const _ink = Color(0xFF3A1D0C);

  /// Parchment panel with a thick wood frame and pixel-font title.
  static DialogThemeData dialog({required bool dark}) => DialogThemeData(
    backgroundColor: dark ? const Color(0xFF2A1A12) : const Color(0xFFF6E7C8),
    surfaceTintColor: Colors.transparent,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: BorderSide(color: dark ? const Color(0xFFC9934F) : _wood, width: 4),
    ),
    titleTextStyle: TextStyle(
      fontFamily: 'Cubic11',
      fontSize: 22,
      color: dark ? const Color(0xFFFFE6A3) : _ink,
    ),
    contentTextStyle: TextStyle(
      fontSize: 15,
      height: 1.5,
      color: dark ? const Color(0xFFF3E6CF) : _ink,
    ),
  );

  /// Text buttons (cancel, later) in wood brown instead of the seed violet.
  static TextButtonThemeData secondaryButton({required bool dark}) =>
      TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: dark ? const Color(0xFFFFE6A3) : _wood,
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      );

  /// Wooden title bar with the pixel font, on every page.
  static AppBarTheme appBar() => const AppBarTheme(
    backgroundColor: Color(0xFF5A3826),
    foregroundColor: Color(0xFFFFE6A3),
    surfaceTintColor: Colors.transparent,
    centerTitle: false,
    elevation: 0,
    scrolledUnderElevation: 2,
    titleTextStyle: TextStyle(
      fontFamily: 'Cubic11',
      fontSize: 22,
      color: Color(0xFFFFE6A3),
    ),
  );

  static TabBarThemeData tabBar() => const TabBarThemeData(
    labelColor: Color(0xFFFFE6A3),
    unselectedLabelColor: Color(0xFFD8BFA8),
    indicatorColor: GamePalette.gold,
    labelStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
  );

  static ChipThemeData chips({required bool dark}) {
    final p = dark ? GamePalette.dark : GamePalette.light;
    return ChipThemeData(
      backgroundColor: p.panel,
      selectedColor: GamePalette.gold,
      side: BorderSide(color: p.panelBorder, width: 1.5),
      labelStyle: TextStyle(color: p.ink, fontWeight: FontWeight.w800),
      shape: const StadiumBorder(),
    );
  }

  static InputDecorationTheme inputs({required bool dark}) {
    final p = dark ? GamePalette.dark : GamePalette.light;
    OutlineInputBorder border(Color color, [double width = 1.5]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: color, width: width),
        );
    return InputDecorationTheme(
      filled: true,
      fillColor: dark ? const Color(0xFF2A1A12) : const Color(0xFFFFFBF2),
      hintStyle: TextStyle(color: p.inkMuted.withValues(alpha: 0.8)),
      labelStyle: TextStyle(color: p.inkMuted),
      border: border(p.panelBorder),
      enabledBorder: border(p.panelBorder),
      focusedBorder: border(GamePalette.goldDeep, 2.5),
    );
  }

  static PageTransitionsTheme pageTransitions() => PageTransitionsTheme(
    builders: {
      for (final platform in TargetPlatform.values)
        platform: const GameDoorTransitionsBuilder(),
    },
  );

  /// Gold primary buttons, like the HUD and result screens.
  static ElevatedButtonThemeData primaryButton() => ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: GamePalette.gold,
      foregroundColor: const Color(0xFF2A1600),
      disabledBackgroundColor: const Color(0x66C9934F),
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
      textStyle: const TextStyle(fontWeight: FontWeight.w900),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFF8A4A10), width: 2),
      ),
    ),
  );
}

class GameBackground extends StatelessWidget {
  const GameBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final p = GamePalette.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [p.backgroundTop, p.backgroundBottom],
        ),
      ),
      child: child,
    );
  }
}

/// Parchment panel in a wood frame, with an optional title plate.
class GamePanel extends StatelessWidget {
  const GamePanel({
    super.key,
    required this.child,
    this.title,
    this.trailing,
    this.padding = const EdgeInsets.fromLTRB(14, 12, 14, 14),
  });

  final Widget child;
  final String? title;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final p = GamePalette.of(context);
    return Container(
      decoration: BoxDecoration(
        color: p.panel,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: p.panelBorder, width: 3),
        boxShadow: [
          BoxShadow(
            color: p.wood.withValues(alpha: 0.55),
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (title != null) ...[
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: const BoxDecoration(
                    color: GamePalette.gold,
                    shape: BoxShape.circle,
                  ),
                ),
                Expanded(
                  child: Text(
                    title!,
                    style: TextStyle(
                      color: p.ink,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                ?trailing,
              ],
            ),
            const SizedBox(height: 10),
          ],
          DefaultTextStyle.merge(
            style: TextStyle(color: p.ink),
            child: child,
          ),
        ],
      ),
    );
  }
}

/// Chunky game button. Primary is gold with a pressed shadow; secondary is
/// wood. A null [onPressed] renders disabled.
class GameButton extends StatelessWidget {
  const GameButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.primary = true,
    this.expand = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool primary;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final p = GamePalette.of(context);
    final enabled = onPressed != null;
    final face = !enabled
        ? Colors.grey.shade400
        : primary
        ? GamePalette.gold
        : p.wood;
    final edge = !enabled
        ? Colors.grey.shade600
        : primary
        ? GamePalette.goldDeep
        : const Color(0xFF5A3826);
    final textColor = primary || !enabled
        ? const Color(0xFF2A1600)
        : Colors.white;
    final content = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 18, color: textColor),
          const SizedBox(width: 6),
        ],
        Flexible(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.w900,
              fontSize: 15,
            ),
          ),
        ),
      ],
    );
    return Semantics(
      button: true,
      enabled: enabled,
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          decoration: BoxDecoration(
            color: face,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: edge, offset: const Offset(0, 4))],
          ),
          child: ExcludeSemantics(child: content),
        ),
      ),
    );
  }
}

/// Small rounded status label.
class GameChip extends StatelessWidget {
  const GameChip({super.key, required this.label, this.tone = GameTone.wood});

  final String label;
  final GameTone tone;

  @override
  Widget build(BuildContext context) {
    final color = _toneColor(tone, GamePalette.of(context));
    final onColor = tone == GameTone.gold
        ? const Color(0xFF3A1D00)
        : Colors.white;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: onColor,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

/// Pages settle in softly (fade + a slight grow), like stepping through a
/// door, instead of the stock slide. Shared by every route in the app.
class GameDoorTransitionsBuilder extends PageTransitionsBuilder {
  const GameDoorTransitionsBuilder();

  @override
  Duration get transitionDuration => const Duration(milliseconds: 260);

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    return FadeTransition(
      opacity: curved,
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.96, end: 1).animate(curved),
        child: child,
      ),
    );
  }
}
