import 'package:flutter/material.dart';

import '../models/avatar_catalog.dart';
import '../theme/app_ui.dart';
import 'avatar_preview.dart';

class AvatarIconPreview extends StatelessWidget {
  final int index;
  final double size;
  final bool selected;

  const AvatarIconPreview({
    super.key,
    required this.index,
    this.size = 72,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    final asset = AvatarCatalog.iconAssetForIndex(index);
    final ringColor = selected
        ? AppUI.green
        : Colors.white.withValues(alpha: AppUI.isDark(context) ? 0.18 : 0.82);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: AppUI.isDark(context)
              ? const [Color(0xFF24304A), Color(0xFF111827)]
              : const [Color(0xFFFFFFFF), Color(0xFFEDE9FE)],
        ),
        border: Border.all(color: ringColor, width: selected ? 3 : 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: AppUI.isDark(context) ? 0.28 : 0.10,
            ),
            blurRadius: size * 0.14,
            offset: Offset(0, size * 0.06),
          ),
        ],
      ),
      child: ClipOval(
        child: Transform.scale(
          scale: 1.18,
          child: buildAvatarImage(
            asset,
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }
}
