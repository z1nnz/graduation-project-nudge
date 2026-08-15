import 'package:flutter/material.dart';

import '../models/room_resonance.dart';
import '../theme/app_ui.dart';

class RoomResonancePanel extends StatefulWidget {
  const RoomResonancePanel({
    super.key,
    required this.accent,
    required this.currentUserId,
    required this.available,
    required this.sharingEnabled,
    required this.signals,
    required this.memberNames,
    required this.onSharingChanged,
    required this.onPublish,
    required this.onWithdraw,
    required this.onAcknowledge,
  });

  final Color accent;
  final String currentUserId;
  final bool available;
  final bool sharingEnabled;
  final List<RoomResonanceSignal> signals;
  final Map<String, String> memberNames;
  final Future<void> Function(bool enabled) onSharingChanged;
  final Future<void> Function(RoomResonanceCue cue) onPublish;
  final Future<void> Function() onWithdraw;
  final Future<void> Function(
    RoomResonanceSignal signal,
    RoomResonanceResponse response,
  )
  onAcknowledge;

  @override
  State<RoomResonancePanel> createState() => _RoomResonancePanelState();
}

class _RoomResonancePanelState extends State<RoomResonancePanel> {
  bool _busy = false;

  RoomResonanceSignal? get _mySignal {
    for (final signal in widget.signals) {
      if (signal.ownerUserId == widget.currentUserId) return signal;
    }
    return null;
  }

  Future<void> _run(Future<void> Function() operation) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await operation();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('共振同步失敗：$error')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final secondary = AppUI.textSecondaryOf(context);
    final otherSignals = widget.available
        ? widget.signals
              .where((signal) => signal.ownerUserId != widget.currentUserId)
              .toList(growable: false)
        : const <RoomResonanceSignal>[];
    return Card(
      shape: AppUI.cardShape(),
      child: Padding(
        padding: const EdgeInsets.all(AppUI.innerPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.waves_rounded, color: widget.accent),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    '非同步共振',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                ),
                Switch.adaptive(
                  value: widget.sharingEnabled,
                  onChanged: _busy || !widget.available
                      ? null
                      : (enabled) =>
                            _run(() => widget.onSharingChanged(enabled)),
                ),
              ],
            ),
            Text(
              widget.available
                  ? '由你選擇是否分享一個 24 小時內有效的有限提示；同房成員看不到精確健康、專注數值或 Ledger 明細。'
                  : '登入正式帳號並取得核准成員資格後，才能選擇分享；訪客模式不會建立共振資料。',
              style: TextStyle(color: secondary, fontSize: 12, height: 1.4),
            ),
            if (widget.available && widget.sharingEnabled) ...[
              const SizedBox(height: 14),
              if (_mySignal == null) ...[
                const Text(
                  '現在想讓同儕知道什麼？',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: RoomResonanceCue.values
                      .map((cue) {
                        return ActionChip(
                          label: Text(cue.label),
                          onPressed: _busy
                              ? null
                              : () => _run(() => widget.onPublish(cue)),
                        );
                      })
                      .toList(growable: false),
                ),
              ] else
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: widget.accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('你目前分享', style: TextStyle(fontSize: 11)),
                            Text(
                              _mySignal!.cue.label,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: _busy ? null : () => _run(widget.onWithdraw),
                        child: const Text('立即撤回'),
                      ),
                    ],
                  ),
                ),
            ],
            const SizedBox(height: 16),
            Text(
              otherSignals.isEmpty ? '目前沒有其他共振訊號。' : '房內正在共振',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            if (otherSignals.isNotEmpty) ...[
              const SizedBox(height: 8),
              ...otherSignals.map((signal) {
                final name = widget.memberNames[signal.ownerUserId] ?? '自律夥伴';
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: widget.accent.withValues(alpha: 0.22),
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: TextStyle(color: secondary)),
                        const SizedBox(height: 3),
                        Text(
                          signal.cue.label,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: RoomResonanceResponse.values
                              .map((response) {
                                return ActionChip(
                                  label: Text(response.label),
                                  onPressed: _busy
                                      ? null
                                      : () => _run(
                                          () => widget.onAcknowledge(
                                            signal,
                                            response,
                                          ),
                                        ),
                                );
                              })
                              .toList(growable: false),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${signal.acknowledgementCount} 個支持回應',
                          style: TextStyle(color: secondary, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }
}
