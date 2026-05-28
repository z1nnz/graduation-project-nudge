import 'package:flutter/material.dart';
import '../theme/app_ui.dart';

/// A reusable pill widget for selecting user roles.
class RolePill extends StatelessWidget {
  final String label;
  final String role;
  final String activeRole;
  final Color accentColor;
  final VoidCallback onTap;

  const RolePill({
    required this.label,
    required this.role,
    required this.activeRole,
    required this.accentColor,
    required this.onTap,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final selected = role == activeRole;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? accentColor.withValues(alpha: 0.12) : AppUI.surfaceVariantOf(context),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? accentColor : Theme.of(context).dividerColor,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? accentColor : AppUI.textSecondaryOf(context),
              fontSize: 13,
              fontWeight: selected ? FontWeight.bold : FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
