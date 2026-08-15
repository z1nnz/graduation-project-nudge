import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/discipline_identity_snapshot.dart';
import '../state/app_state.dart';
import '../theme/app_ui.dart';
import 'focus_page.dart';

class DisciplineIdentityPage extends StatefulWidget {
  const DisciplineIdentityPage({super.key});

  @override
  State<DisciplineIdentityPage> createState() => _DisciplineIdentityPageState();
}

class _DisciplineIdentityPageState extends State<DisciplineIdentityPage> {
  bool _requestedInitialRefresh = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final appState = context.read<AppState>();
    if (_requestedInitialRefresh ||
        appState.disciplineIdentitySnapshot != null ||
        appState.currentUser == null ||
        appState.isGuestMode) {
      return;
    }
    _requestedInitialRefresh = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_refresh(appState));
    });
  }

  Future<void> _refresh(AppState appState) async {
    try {
      await appState.refreshDisciplineIdentity();
    } catch (_) {
      // AppState exposes a user-facing error on this page.
    }
  }

  void _startRecovery(int minutes) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FocusPage(initialFocusMinutes: minutes),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final snapshot = appState.disciplineIdentitySnapshot;
    return ListView(
      padding: const EdgeInsets.all(AppUI.pagePadding),
      children: [
        if (snapshot == null)
          Card(
            shape: AppUI.cardShape(),
            child: Padding(
              padding: const EdgeInsets.all(AppUI.innerPadding),
              child: Column(
                children: [
                  const Icon(Icons.auto_awesome_outlined, size: 42),
                  const SizedBox(height: 12),
                  Text(
                    appState.isRefreshingDisciplineIdentity
                        ? '正在整理近 28 個自律日'
                        : '建立你的第一張自律人格快照',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    appState.disciplineIdentityError ??
                        '只使用 Cloud 已接受的 Activity Ledger 紀錄，不讀取好友、家庭或團體的私人資料。',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppUI.textSecondaryOf(context),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed:
                        appState.isRefreshingDisciplineIdentity ||
                            appState.currentUser == null ||
                            appState.isGuestMode
                        ? null
                        : () => _refresh(appState),
                    icon: appState.isRefreshingDisciplineIdentity
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh_rounded),
                    label: const Text('更新自律人格'),
                  ),
                ],
              ),
            ),
          )
        else ...[
          DisciplineIdentityCard(
            snapshot: snapshot,
            onStartRecovery: _startRecovery,
          ),
          const SizedBox(height: AppUI.cardGap),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: appState.isRefreshingDisciplineIdentity
                  ? null
                  : () => _refresh(appState),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('依最新 Ledger 更新'),
            ),
          ),
        ],
      ],
    );
  }
}

class DisciplineIdentityCard extends StatelessWidget {
  const DisciplineIdentityCard({
    super.key,
    required this.snapshot,
    required this.onStartRecovery,
  });

  final DisciplineIdentitySnapshot snapshot;
  final ValueChanged<int> onStartRecovery;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final secondary = AppUI.textSecondaryOf(context);
    final isRecovery =
        snapshot.needsGentleReturn ||
        snapshot.recoveryState == DisciplineRecoveryState.returning;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: AppUI.heroGradient(accent),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '近 28 個自律日',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
              const SizedBox(height: 5),
              Text(
                snapshot.personaTitle,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                snapshot.personaDescription,
                style: const TextStyle(color: Colors.white, height: 1.4),
              ),
              const SizedBox(height: 12),
              const Chip(
                avatar: Icon(Icons.lock_outline, size: 16),
                label: Text('目前僅自己可見'),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppUI.cardGap),
        Card(
          shape: AppUI.cardShape(),
          child: Padding(
            padding: const EdgeInsets.all(AppUI.innerPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '可驗證的行動證據',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _MetricChip(label: '活躍日', value: '${snapshot.activeDays}'),
                    _MetricChip(
                      label: '完成活動',
                      value: '${snapshot.completedSessions}',
                    ),
                    _MetricChip(
                      label: '專注',
                      value: '${snapshot.focusMinutes} 分',
                    ),
                    _MetricChip(
                      label: '運動',
                      value: '${snapshot.exerciseMinutes} 分',
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  '這不是性格診斷；快照由 canonical Activity Ledger 更新，會隨你的新行動改變。',
                  style: TextStyle(color: secondary, fontSize: 12, height: 1.4),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppUI.cardGap),
        Card(
          shape: AppUI.cardShape(),
          child: Padding(
            padding: const EdgeInsets.all(AppUI.innerPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(Icons.restart_alt_rounded, color: accent),
                    const SizedBox(width: 8),
                    Text(
                      isRecovery ? '復原步驟' : '下一個小行動',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  snapshot.recoveryMessage,
                  style: const TextStyle(height: 1.4),
                ),
                const SizedBox(height: 6),
                Text(
                  '中斷不扣分，也不需要補做錯過的份量；完成的新活動會保留原本歷史。',
                  style: TextStyle(color: secondary, fontSize: 12, height: 1.4),
                ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: () =>
                      onStartRecovery(snapshot.recommendedFocusMinutes),
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: Text(
                    isRecovery
                        ? '開始 ${snapshot.recommendedFocusMinutes} 分鐘復原步驟'
                        : '開始 ${snapshot.recommendedFocusMinutes} 分鐘行動',
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Chip(label: Text('$label $value'));
  }
}
