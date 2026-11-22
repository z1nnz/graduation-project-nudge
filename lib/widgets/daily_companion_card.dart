import 'package:flutter/material.dart';
import '../models/avatar_profile.dart';
import '../models/daily_next_action.dart';
import '../theme/app_ui.dart';
import 'avatar_preview.dart';

class DailyCompanionCard extends StatelessWidget {
  const DailyCompanionCard({
    super.key,
    required this.action,
    required this.profile,
    required this.onOpenTasks,
    this.confirmedActivityLabel,
    this.feedbackStatus = '登入後查看雲端活動確認',
  });

  final DailyNextAction action;
  final AvatarProfile profile;
  final VoidCallback onOpenTasks;
  final String? confirmedActivityLabel;
  final String feedbackStatus;

  @override
  Widget build(BuildContext context) => Card(
    shape: AppUI.cardShape(),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AvatarPreview(profile: profile, size: 64),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '你的夥伴陪你走下一步',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (confirmedActivityLabel != null) ...[
            Text(
              confirmedActivityLabel!,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
          ],
          Text(feedbackStatus, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 12),
          Text(action.title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(action.detail),
          const SizedBox(height: 12),
          FilledButton(onPressed: onOpenTasks, child: Text(action.button)),
          const SizedBox(height: 8),
          Text(
            '這是個人行動建議；正式獎勵以雲端確認為準。',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    ),
  );
}
