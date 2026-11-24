import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/focus_sound.dart';
import '../theme/game_ui.dart';

Future<void> _openMusicApp(MusicApp app) async {
  await launchUrl(app.uri, mode: LaunchMode.externalApplication);
}

/// Bottom sheet on the focus desk: ambient loops plus shortcuts to music apps.
Future<void> showFocusSoundSheet(
  BuildContext context,
  FocusSoundController controller,
) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: SingleChildScrollView(
          child: FocusSoundPanel(controller: controller),
        ),
      ),
    ),
  );
}

class FocusSoundPanel extends StatelessWidget {
  const FocusSoundPanel({
    super.key,
    required this.controller,
    this.onOpenMusicApp = _openMusicApp,
  });

  final FocusSoundController controller;
  final Future<void> Function(MusicApp app) onOpenMusicApp;

  @override
  Widget build(BuildContext context) {
    final p = GamePalette.of(context);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => GamePanel(
        title: '讀書的聲音',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 1.35,
              children: [
                _SoundTile(
                  key: const ValueKey('sound-off'),
                  emoji: '🔇',
                  label: '安靜',
                  selected: controller.current == null,
                  onTap: () => controller.select(null),
                ),
                for (final sound in FocusSound.all)
                  _SoundTile(
                    key: ValueKey('sound-${sound.id}'),
                    semanticsKey: ValueKey('sound-${sound.id}-sem'),
                    emoji: sound.emoji,
                    label: sound.label,
                    selected: controller.current?.id == sound.id,
                    onTap: () => controller.select(sound.id),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.volume_down_rounded, color: p.inkMuted),
                Expanded(
                  child: Slider(
                    value: controller.volume,
                    activeColor: GamePalette.goldDeep,
                    onChanged: controller.current == null
                        ? null
                        : controller.setVolume,
                  ),
                ),
                Icon(Icons.volume_up_rounded, color: p.inkMuted),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '用自己的音樂 App 放歌',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 15,
                color: p.ink,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '音樂會和上面的環境音一起播放，計時不會中斷。',
              style: TextStyle(fontSize: 13, color: p.inkMuted),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final app in MusicApp.all)
                  GameButton(
                    label: app.label,
                    icon: Icons.music_note_rounded,
                    primary: false,
                    onPressed: () => onOpenMusicApp(app),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SoundTile extends StatelessWidget {
  const _SoundTile({
    super.key,
    this.semanticsKey,
    required this.emoji,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final Key? semanticsKey;
  final String emoji;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = GamePalette.of(context);
    return Semantics(
      key: semanticsKey,
      button: true,
      selected: selected,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          decoration: BoxDecoration(
            color: selected ? GamePalette.gold : p.wood.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? GamePalette.goldDeep : p.panelBorder,
              width: selected ? 3 : 2,
            ),
          ),
          child: ExcludeSemantics(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(emoji, style: const TextStyle(fontSize: 24)),
                const SizedBox(height: 2),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: selected ? const Color(0xFF2A1600) : p.ink,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
