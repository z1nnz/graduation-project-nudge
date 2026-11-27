import 'package:flutter/material.dart';

import '../theme/game_ui.dart';

class GamePixelSwitch extends StatelessWidget {
  const GamePixelSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.semanticLabel = '像素撥桿',
    this.activeColor,
    this.activeThumbColor,
  });
  final bool value;
  final ValueChanged<bool>? onChanged;
  final String semanticLabel;
  final Color? activeColor, activeThumbColor;
  @override
  Widget build(BuildContext context) => Semantics(
    label: semanticLabel,
    toggled: value,
    enabled: onChanged != null,
    button: true,
    excludeSemantics: true,
    onTap: onChanged == null ? null : () => onChanged!(!value),
    child: Tooltip(
      message: value ? '開啟' : '關閉',
      child: TextButton(
        onPressed: onChanged == null ? null : () => onChanged!(!value),
        style: TextButton.styleFrom(
          padding: EdgeInsets.zero,
          minimumSize: const Size(64, 44),
          shape: const RoundedRectangleBorder(),
        ),
        child: Container(
          width: 64,
          height: 44,
          decoration: BoxDecoration(
            color: GamePalette.woodDeep,
            border: Border.all(color: GamePalette.of(context).wood, width: 3),
          ),
          child: Stack(
            children: [
              Positioned(
                left: value ? 34 : 4,
                top: 6,
                width: 20,
                height: 26,
                child: ColoredBox(
                  color: onChanged == null
                      ? GamePalette.inkSoft
                      : GamePalette.gold,
                ),
              ),
              Positioned(
                left: value ? 5 : 32,
                top: 9,
                child: Text(
                  value ? '開' : '關',
                  style: const TextStyle(
                    fontFamily: 'Cubic11',
                    fontSize: 14,
                    color: GamePalette.inkLight,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class GameSwitchTile extends StatelessWidget {
  const GameSwitchTile({
    super.key,
    required this.value,
    required this.onChanged,
    this.title,
    this.subtitle,
    this.secondary,
    this.contentPadding,
    this.dense,
    this.activeColor,
    this.isThreeLine = false,
  });
  final bool value, isThreeLine;
  final ValueChanged<bool>? onChanged;
  final Widget? title, subtitle, secondary;
  final EdgeInsetsGeometry? contentPadding;
  final bool? dense;
  final Color? activeColor;
  @override
  Widget build(BuildContext context) => MergeSemantics(
    child: Semantics(
      toggled: value,
      enabled: onChanged != null,
      child: ListTile(
        title: title,
        subtitle: subtitle,
        leading: secondary,
        contentPadding: contentPadding,
        dense: dense,
        isThreeLine: isThreeLine,
        onTap: onChanged == null ? null : () => onChanged!(!value),
        trailing: ExcludeFocus(
          child: ExcludeSemantics(
            child: GamePixelSwitch(value: value, onChanged: onChanged),
          ),
        ),
      ),
    ),
  );
}
