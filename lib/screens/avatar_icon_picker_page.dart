import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/avatar_catalog.dart';
import '../state/app_state.dart';
import '../theme/app_ui.dart';
import '../widgets/avatar_icon_preview.dart';

class AvatarIconPickerPage extends StatelessWidget {
  const AvatarIconPickerPage({super.key});

  Future<void> _selectIcon(
    BuildContext context,
    AppState appState,
    AvatarEvolutionStage stage,
  ) async {
    if (!appState.isAvatarIconUnlocked(stage.index)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${stage.name} 頭像需要 ${appState.avatarEvolutionRequirementText(stage.index)}。',
          ),
        ),
      );
      return;
    }

    await appState.updateAvatarIconIndex(stage.index);
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('已套用 ${stage.name} 頭像')));
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final selectedIndex = appState.avatarProfile.avatarIconIndex;

    return Scaffold(
      appBar: AppBar(title: const Text('頭像')),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final crossAxisCount = constraints.maxWidth >= 520 ? 4 : 3;

          return GridView.builder(
            padding: const EdgeInsets.all(AppUI.pagePadding),
            itemCount: AvatarCatalog.evolutionStages.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.88,
            ),
            itemBuilder: (context, index) {
              final stage = AvatarCatalog.evolutionStages[index];
              final unlocked = appState.isAvatarIconUnlocked(stage.index);
              final selected = selectedIndex == stage.index;

              return _AvatarIconTile(
                stage: stage,
                unlocked: unlocked,
                selected: selected,
                onTap: () => _selectIcon(context, appState, stage),
              );
            },
          );
        },
      ),
    );
  }
}

class _AvatarIconTile extends StatelessWidget {
  final AvatarEvolutionStage stage;
  final bool unlocked;
  final bool selected;
  final VoidCallback onTap;

  const _AvatarIconTile({
    required this.stage,
    required this.unlocked,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = selected
        ? AppUI.green
        : Theme.of(context).dividerColor.withValues(alpha: 0.74);

    return Material(
      color: Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(AppUI.radiusCard),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppUI.radiusCard),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppUI.radiusCard),
            border: Border.all(color: borderColor, width: selected ? 2 : 1),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final avatarSize = (constraints.maxWidth * 0.62).clamp(
                68.0,
                112.0,
              );

              return Column(
                children: [
                  Expanded(
                    child: Center(
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Opacity(
                            opacity: unlocked ? 1 : 0.42,
                            child: AvatarIconPreview(
                              index: stage.index,
                              size: avatarSize,
                              selected: selected,
                            ),
                          ),
                          if (!unlocked) ...[
                            Container(
                              width: avatarSize,
                              height: avatarSize,
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.36),
                                shape: BoxShape.circle,
                              ),
                            ),
                            Center(
                              child: Container(
                                width: avatarSize * 0.34,
                                height: avatarSize * 0.34,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.94),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.lock_rounded,
                                  color: Colors.black.withValues(alpha: 0.44),
                                  size: avatarSize * 0.22,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  SizedBox(
                    height: 36,
                    child: selected
                        ? Padding(
                            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                            child: Container(
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: AppUI.green.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(
                                  AppUI.radiusPill,
                                ),
                              ),
                              child: const Text(
                                '使用中',
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: AppUI.green,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
