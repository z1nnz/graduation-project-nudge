import 'package:flutter/material.dart';

import '../models/relationship_membership.dart';
import '../theme/app_ui.dart';

class RelationshipRoleSurfaceCard extends StatelessWidget {
  const RelationshipRoleSurfaceCard({
    super.key,
    required this.role,
  });

  final RelationshipRole role;

  _RoleSurface get _surface => switch (role) {
    RelationshipRole.guardian => const _RoleSurface(
      title: '家長陪伴介面',
      description: '用提議與鼓勵陪伴孩子，保留孩子對資料與目標的最後決定權。',
      actions: ['提出共同目標', '傳送鼓勵', '查看已同意分享的摘要'],
      boundary: '不能替孩子調整分享、接受目標或代為完成活動。',
      icon: Icons.family_restroom_outlined,
    ),
    RelationshipRole.child => const _RoleSurface(
      title: '孩子自主介面',
      description: '你掌握家庭分享、共同目標決定與自己的活動紀錄。',
      actions: ['調整分享範圍', '接受或婉拒共同目標', '回應鼓勵'],
      boundary: '家長只能看到你主動同意分享的摘要，不能查看逐筆紀錄。',
      icon: Icons.shield_outlined,
    ),
    RelationshipRole.manager => const _RoleSurface(
      title: '團體管理介面',
      description: '建立團隊一起前進的框架，讓每位成員保有活動自主權。',
      actions: ['發布共同框架', '管理成員與管理權', '查看已同意分享彙總'],
      boundary: '不能替成員開始、暫停或結束活動，也不能強制開啟成果分享。',
      icon: Icons.admin_panel_settings_outlined,
    ),
    RelationshipRole.member => const _RoleSurface(
      title: '團體成員介面',
      description: '依自己的節奏參與團體框架，活動與分享仍由你控制。',
      actions: ['自行開始與完成活動', '參與或退出挑戰', '開啟或撤回成果分享'],
      boundary: '管理者只能定義共同框架，不能替你操作活動或公開個人紀錄。',
      icon: Icons.person_outline,
    ),
  };

  @override
  Widget build(BuildContext context) {
    final surface = _surface;
    final accent = Theme.of(context).colorScheme.primary;
    return Card(
      key: ValueKey('relationship-role-${role.name}'),
      shape: AppUI.cardShape(),
      child: Padding(
        padding: const EdgeInsets.all(AppUI.innerPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(surface.icon, color: accent),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        surface.title,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        surface.description,
                        style: TextStyle(
                          color: AppUI.textSecondaryOf(context),
                          fontSize: 12,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: surface.actions
                  .map(
                    (action) => Chip(
                      avatar: const Icon(Icons.check_circle_outline, size: 16),
                      label: Text(action),
                    ),
                  )
                  .toList(growable: false),
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.lock_outline, size: 17),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    surface.boundary,
                    style: TextStyle(
                      color: AppUI.textSecondaryOf(context),
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RoleSurface {
  const _RoleSurface({
    required this.title,
    required this.description,
    required this.actions,
    required this.boundary,
    required this.icon,
  });

  final String title;
  final String description;
  final List<String> actions;
  final String boundary;
  final IconData icon;
}
