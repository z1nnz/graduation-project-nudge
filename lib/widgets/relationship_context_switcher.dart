import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/relationship_membership.dart';
import '../state/app_state.dart';
import '../theme/app_ui.dart';

class RelationshipContextSwitcher extends StatelessWidget {
  const RelationshipContextSwitcher({super.key, required this.scope});

  final RelationshipScope scope;

  String _roleLabel(RelationshipRole role) => switch (role) {
    RelationshipRole.guardian => '家長',
    RelationshipRole.child => '孩子',
    RelationshipRole.manager => '團體管理者',
    RelationshipRole.member => '團體成員',
  };

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final memberships = appState.relationshipMemberships
        .where((membership) => membership.scope == scope)
        .toList(growable: false);
    if (memberships.isEmpty) return const SizedBox.shrink();

    final selectedId = scope == RelationshipScope.family
        ? appState.selectedFamilyLinkId
        : appState.selectedGroupId;
    final selected = memberships.firstWhere(
      (membership) => membership.scopeId == selectedId,
      orElse: () => memberships.first,
    );
    final title = scope == RelationshipScope.family ? '目前家庭情境' : '目前團體情境';

    return Card(
      shape: AppUI.cardShape(),
      child: Padding(
        padding: const EdgeInsets.all(AppUI.innerPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  scope == RelationshipScope.family
                      ? Icons.family_restroom_outlined
                      : Icons.groups_outlined,
                  color: appState.currentIconColor,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '你在此情境是「${_roleLabel(selected.role)}」；權限與內容會隨選擇切換。',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppUI.textSecondaryOf(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (memberships.length > 1) ...[
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: selected.scopeId,
                decoration: InputDecoration(
                  labelText: scope == RelationshipScope.family
                      ? '切換家庭關係'
                      : '切換團體',
                  border: const OutlineInputBorder(),
                ),
                items: memberships
                    .map(
                      (membership) => DropdownMenuItem(
                        value: membership.scopeId,
                        child: Text(
                          '${membership.scopeName} · ${_roleLabel(membership.role)}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (scopeId) async {
                  if (scopeId == null || scopeId == selected.scopeId) return;
                  try {
                    if (scope == RelationshipScope.family) {
                      await appState.selectFamilyRelationship(scopeId);
                    } else {
                      await appState.selectGroupRelationship(scopeId);
                    }
                  } catch (error) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text(error.toString())));
                  }
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}
