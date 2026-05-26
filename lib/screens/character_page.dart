import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/avatar_catalog.dart';
import '../state/app_state.dart';
import '../theme/app_ui.dart';
import '../widgets/avatar_preview.dart';
import 'avatar_codex_page.dart';
import 'avatar_evolution_page.dart';
import 'avatar_experience_page.dart';
import 'avatar_shop_page.dart';

class CharacterPage extends StatelessWidget {
  const CharacterPage({super.key});

  double _levelProgress(AppState appState) {
    if (appState.avatarLevel >= AppState.avatarMaxLevel) return 1;
    final currentLevelExp = AppState.avatarExperienceRequiredForLevel(
      appState.avatarLevel,
    );
    final nextLevelExp = appState.avatarNextLevelExperience;
    final span = nextLevelExp - currentLevelExp;
    if (span <= 0) return 1;
    return ((appState.avatarExperience - currentLevelExp) / span).clamp(0, 1);
  }

  void _open(BuildContext context, Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final accentColor = appState.currentIconColor;
    final stage = AvatarCatalog.stageForIndex(
      appState.avatarProfile.faceShapeIndex,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('角色中心'),
        actions: [
          IconButton(
            tooltip: '角色圖鑑',
            onPressed: () => _open(context, const AvatarCodexPage()),
            icon: const Icon(Icons.menu_book_rounded),
          ),
          IconButton(
            tooltip: '進化路線',
            onPressed: () => _open(context, const AvatarEvolutionPage()),
            icon: const Icon(Icons.auto_awesome_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppUI.pagePadding),
        children: [
          _CharacterHeroCard(
            appState: appState,
            stage: stage,
            levelProgress: _levelProgress(appState),
            accentColor: accentColor,
          ),
          const SizedBox(height: AppUI.sectionGap),
          _CharacterShortcutGrid(
            accentColor: accentColor,
            onOpenCodex: () => _open(context, const AvatarCodexPage()),
            onOpenEvolution: () => _open(context, const AvatarEvolutionPage()),
            onOpenExperience: () =>
                _open(context, const AvatarExperiencePage()),
            onOpenShop: () => _open(context, const AvatarShopPage()),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _CharacterHeroCard extends StatelessWidget {
  final AppState appState;
  final AvatarEvolutionStage stage;
  final double levelProgress;
  final Color accentColor;

  const _CharacterHeroCard({
    required this.appState,
    required this.stage,
    required this.levelProgress,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final maxed = appState.avatarLevel >= AppState.avatarMaxLevel;
    final primaryText = AppUI.textPrimaryOf(context);
    final secondaryText = AppUI.textSecondaryOf(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stage.series,
                      style: TextStyle(
                        color: secondaryText,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      stage.name,
                      style: TextStyle(
                        color: primaryText,
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: accentColor.withValues(
                    alpha: AppUI.isDark(context) ? 0.20 : 0.12,
                  ),
                  borderRadius: BorderRadius.circular(AppUI.radiusPill),
                  border: Border.all(
                    color: accentColor.withValues(alpha: 0.22),
                  ),
                ),
                child: Text(
                  'Lv.${appState.avatarLevel}',
                  style: TextStyle(
                    color: accentColor,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 314,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned(
                  bottom: 22,
                  child: Container(
                    width: 186,
                    height: 24,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(
                        alpha: AppUI.isDark(context) ? 0.28 : 0.10,
                      ),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                Positioned(
                  top: 0,
                  child: AvatarPreview(
                    profile: appState.avatarProfile,
                    size: 258,
                    showBackgroundRing: false,
                  ),
                ),
                Positioned(
                  left: 8,
                  bottom: 38,
                  child: _HeroStatPill(
                    icon: Icons.bolt_rounded,
                    label: '${appState.avatarExperience} EXP',
                    color: accentColor,
                  ),
                ),
                Positioned(
                  right: 8,
                  bottom: 38,
                  child: _HeroStatPill(
                    icon: Icons.auto_awesome_rounded,
                    label: stage.stageLabel,
                    color: AppUI.orange,
                  ),
                ),
              ],
            ),
          ),
          _CharacterProgressPanel(
            levelProgress: levelProgress,
            currentExperience: appState.avatarExperience,
            nextLevelExperience: appState.avatarNextLevelExperience,
            remainingExperience: appState.avatarExperienceToNextLevel,
            maxed: maxed,
            accentColor: accentColor,
          ),
        ],
      ),
    );
  }
}

class _HeroStatPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _HeroStatPill({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(AppUI.radiusPill),
        border: Border.all(color: color.withValues(alpha: 0.20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: AppUI.isDark(context) ? 0.26 : 0.08,
            ),
            blurRadius: 14,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: AppUI.textPrimaryOf(context),
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _CharacterProgressPanel extends StatelessWidget {
  final double levelProgress;
  final int currentExperience;
  final int nextLevelExperience;
  final int remainingExperience;
  final bool maxed;
  final Color accentColor;

  const _CharacterProgressPanel({
    required this.levelProgress,
    required this.currentExperience,
    required this.nextLevelExperience,
    required this.remainingExperience,
    required this.maxed,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final primaryText = AppUI.textPrimaryOf(context);
    final secondaryText = AppUI.textSecondaryOf(context);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: AppUI.isDark(context)
              ? Colors.white.withValues(alpha: 0.08)
              : const Color(0xFFE5E7EB),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: AppUI.isDark(context) ? 0.24 : 0.08,
            ),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  maxed ? '等級已滿' : '下一級進度',
                  style: TextStyle(
                    color: primaryText,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                maxed ? '全部階段已解鎖' : '還差 $remainingExperience EXP',
                style: TextStyle(
                  color: secondaryText,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppUI.radiusPill),
            child: LinearProgressIndicator(
              value: levelProgress,
              minHeight: 9,
              backgroundColor: AppUI.isDark(context)
                  ? const Color(0xFF2A2F3A)
                  : const Color(0xFFE5E7EB),
              valueColor: AlwaysStoppedAnimation<Color>(accentColor),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  maxed
                      ? '最高等級'
                      : '$currentExperience / $nextLevelExperience EXP',
                  style: TextStyle(
                    color: secondaryText,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                '${(levelProgress * 100).round()}%',
                style: TextStyle(
                  color: accentColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CharacterShortcutGrid extends StatelessWidget {
  final Color accentColor;
  final VoidCallback onOpenCodex;
  final VoidCallback onOpenEvolution;
  final VoidCallback onOpenExperience;
  final VoidCallback onOpenShop;

  const _CharacterShortcutGrid({
    required this.accentColor,
    required this.onOpenCodex,
    required this.onOpenEvolution,
    required this.onOpenExperience,
    required this.onOpenShop,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 1.45,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _CharacterShortcutButton(
          icon: Icons.menu_book_rounded,
          title: '角色圖鑑',
          subtitle: '收藏',
          color: accentColor,
          onTap: onOpenCodex,
        ),
        _CharacterShortcutButton(
          icon: Icons.auto_awesome_rounded,
          title: '進化路線',
          subtitle: '升階',
          color: accentColor,
          onTap: onOpenEvolution,
        ),
        _CharacterShortcutButton(
          icon: Icons.bolt_rounded,
          title: '角色經驗',
          subtitle: 'EXP',
          color: accentColor,
          onTap: onOpenExperience,
        ),
        _CharacterShortcutButton(
          icon: Icons.storefront_rounded,
          title: '造型商城',
          subtitle: '造型',
          color: accentColor,
          onTap: onOpenShop,
        ),
      ],
    );
  }
}

class _CharacterShortcutButton extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _CharacterShortcutButton({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final primaryText = AppUI.textPrimaryOf(context);
    final secondaryText = AppUI.textSecondaryOf(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: AppUI.isDark(context)
                  ? Colors.white.withValues(alpha: 0.08)
                  : const Color(0xFFE5E7EB),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: AppUI.softCardOf(context, color),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: primaryText,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: secondaryText,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: color, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}
