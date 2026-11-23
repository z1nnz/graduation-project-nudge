import 'package:flutter/material.dart';

/// One entry in the cabin menu.
class CabinMenuItem {
  const CabinMenuItem(this.id, this.label, this.icon, this.fallback);

  final String id;
  final String label;

  /// Pixel icon asset; [fallback] shows if it is missing.
  final String icon;
  final IconData fallback;
}

const cabinMenuItems = [
  CabinMenuItem(
    'character',
    '角色',
    'assets/ui/icons/icon_character.png',
    Icons.face,
  ),
  CabinMenuItem(
    'shop',
    '商城',
    'assets/ui/icons/icon_shop.png',
    Icons.storefront,
  ),
  CabinMenuItem(
    'health',
    '健康',
    'assets/ui/icons/icon_health.png',
    Icons.favorite,
  ),
  CabinMenuItem(
    'calendar',
    '日曆',
    'assets/ui/icons/icon_calendar.png',
    Icons.calendar_month,
  ),
  CabinMenuItem(
    'stats',
    '分析',
    'assets/ui/icons/icon_stats.png',
    Icons.insights,
  ),
  CabinMenuItem(
    'wallet',
    '錢包',
    'assets/ui/icons/icon_wallet.png',
    Icons.savings,
  ),
  CabinMenuItem(
    'reminders',
    '提醒',
    'assets/ui/icons/icon_bell.png',
    Icons.notifications,
  ),
  CabinMenuItem('letter', '時光信', 'assets/ui/icons/icon_letter.png', Icons.mail),
  CabinMenuItem(
    'settings',
    '設定',
    'assets/ui/icons/icon_settings.png',
    Icons.settings,
  ),
  CabinMenuItem(
    'account',
    '帳號',
    'assets/ui/icons/icon_account.png',
    Icons.badge,
  ),
];

/// The cabin menu: an icon grid of every feature that is not a room object.
/// [onOpen] receives the chosen item id after the menu closes.
Future<void> showCabinMenu(
  BuildContext context, {
  required ValueChanged<String> onOpen,
}) async {
  final chosen = await showGeneralDialog<String>(
    context: context,
    barrierDismissible: true,
    barrierLabel: '關閉選單',
    barrierColor: const Color(0x99140A05),
    transitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (_, _, _) => const _CabinMenu(),
    transitionBuilder: (context, animation, _, child) {
      if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) return child;
      return SlideTransition(
        position: Tween(begin: const Offset(0, 0.15), end: Offset.zero).animate(
          CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
        ),
        child: FadeTransition(opacity: animation, child: child),
      );
    },
  );
  if (chosen != null) onOpen(chosen);
}

class _CabinMenu extends StatelessWidget {
  const _CabinMenu();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            margin: const EdgeInsets.all(20),
            constraints: const BoxConstraints(maxWidth: 380),
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF8A5A34), Color(0xFF5A3826)],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFC9934F), width: 3),
              boxShadow: const [
                BoxShadow(
                  color: Color(0xCC000000),
                  offset: Offset(0, 6),
                  blurRadius: 18,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Icon(Icons.menu_rounded, color: Color(0xFFFFE6A3)),
                    const SizedBox(width: 8),
                    const Text(
                      '選單',
                      style: TextStyle(
                        fontFamily: 'Cubic11',
                        fontSize: 22,
                        color: Color(0xFFFFF3D6),
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      tooltip: '關閉',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, color: Color(0xFFFFE6A3)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    for (final item in cabinMenuItems) _Slot(item: item),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Slot extends StatelessWidget {
  const _Slot({required this.item});

  final CabinMenuItem item;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: item.label,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => Navigator.pop(context, item.id),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF6E7C8),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF4A2D22), width: 2),
            boxShadow: const [
              BoxShadow(color: Color(0x66000000), offset: Offset(0, 3)),
            ],
          ),
          padding: const EdgeInsets.all(6),
          child: Column(
            children: [
              Expanded(
                child: Image.asset(
                  item.icon,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.none,
                  errorBuilder: (_, _, _) => Icon(
                    item.fallback,
                    size: 34,
                    color: const Color(0xFF8A5A34),
                  ),
                ),
              ),
              Text(
                item.label,
                style: const TextStyle(
                  fontFamily: 'Cubic11',
                  fontSize: 14,
                  color: Color(0xFF3A1D0C),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
