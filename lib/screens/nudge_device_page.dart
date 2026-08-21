import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/nudge_device_coordinator.dart';
import '../services/nudge_device_runtime.dart';
import '../state/app_state.dart';
import '../theme/app_ui.dart';

typedef NudgeDeviceRuntimeBuilder = NudgeDeviceRuntime Function();

class NudgeDevicePage extends StatefulWidget {
  const NudgeDevicePage({super.key, this.runtimeBuilder});

  final NudgeDeviceRuntimeBuilder? runtimeBuilder;

  @override
  State<NudgeDevicePage> createState() => _NudgeDevicePageState();
}

class _NudgeDevicePageState extends State<NudgeDevicePage> {
  NudgeDeviceRuntime? _runtime;
  NudgeDeviceCoordinator? _coordinator;
  Object? _initializationError;
  bool _initialized = false;
  bool _busy = false;
  int _durationMinutes = 25;
  int _pendingCloudEvents = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    try {
      final runtime =
          widget.runtimeBuilder?.call() ??
          context.read<AppState>().createNudgeDeviceRuntime();
      _runtime = runtime;
      _coordinator = runtime.coordinator..addListener(_onDeviceChanged);
      unawaited(_refreshPendingCloudEvents());
    } catch (error) {
      _initializationError = error;
    }
  }

  void _onDeviceChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _refreshPendingCloudEvents() async {
    final runtime = _runtime;
    if (runtime == null) return;
    final count = await runtime.pendingCloudEvents();
    if (mounted) setState(() => _pendingCloudEvents = count);
  }

  Future<void> _perform(Future<void> Function() operation) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await operation();
      await _refreshPendingCloudEvents();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('裝置操作失敗：$error')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _configureFocus() async {
    final coordinator = _coordinator;
    final runtime = _runtime;
    if (coordinator == null || runtime == null) return;
    final now = DateTime.now().toUtc();
    final sessionId = 'device-focus-${now.microsecondsSinceEpoch}';
    final activityCorrelationId = await runtime.prepareFocusCorrelation();
    await coordinator.configureFocus(
      sessionId: sessionId,
      activityCorrelationId: activityCorrelationId,
      durationSeconds: _durationMinutes * 60,
    );
  }

  Future<void> _flushCloud() async {
    final runtime = _runtime;
    if (runtime == null) return;
    final report = await runtime.flushCloudEvents();
    if (!mounted) return;
    final message = report.retryBlocked
        ? '目前離線，事件已保留，恢復網路後會重試。'
        : report.permanentlyRejected > 0
        ? '有 ${report.permanentlyRejected} 筆事件被 Cloud 拒絕，請檢查裝置指派。'
        : '已同步 ${report.succeeded.length} 筆裝置活動到 Cloud。';
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _statusLabel(NudgeDeviceCoordinatorState state) =>
      switch (state.status) {
        NudgeDeviceConnectionStatus.idle => '尚未連線',
        NudgeDeviceConnectionStatus.scanning => '正在搜尋裝置',
        NudgeDeviceConnectionStatus.connected => '已連線',
        NudgeDeviceConnectionStatus.disconnected => '連線已中斷',
        NudgeDeviceConnectionStatus.error => '裝置發生錯誤',
      };

  String _phaseLabel(String phase) => switch (phase) {
    'running' => '專注中',
    'paused' => '已暫停',
    'completed' => '本輪完成',
    _ => '待機',
  };

  String _remainingLabel(int seconds) {
    final minutes = seconds ~/ 60;
    final remainder = seconds % 60;
    return '$minutes:${remainder.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _coordinator?.removeListener(_onDeviceChanged);
    final runtime = _runtime;
    if (runtime != null) unawaited(runtime.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final error = _initializationError;
    final coordinator = _coordinator;
    final state = coordinator?.state ?? const NudgeDeviceCoordinatorState();
    final connected = state.status == NudgeDeviceConnectionStatus.connected;

    return Scaffold(
      appBar: AppBar(title: const Text('Nudge 專注裝置')),
      body: ListView(
        padding: const EdgeInsets.all(AppUI.pagePadding),
        children: [
          Card(
            shape: AppUI.cardShape(),
            child: Padding(
              padding: const EdgeInsets.all(AppUI.innerPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('連線狀態', style: AppUI.sectionTitleOf(context)),
                  const SizedBox(height: 10),
                  Text(
                    error == null ? _statusLabel(state) : '此平台無法使用 BLE',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  if (state.deviceId != null) ...[
                    const SizedBox(height: 4),
                    Text('裝置：${state.deviceId}'),
                  ],
                  if (state.errorMessage != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      state.errorMessage!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  if (error != null) ...[
                    const SizedBox(height: 8),
                    Text('$error'),
                  ],
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: error == null && !_busy && !connected
                          ? () => _perform(coordinator!.start)
                          : null,
                      icon: const Icon(Icons.bluetooth_searching_rounded),
                      label: const Text('搜尋並連線'),
                    ),
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('本輪專注', style: AppUI.sectionTitleOf(context)),
                  const SizedBox(height: 10),
                  Text(
                    '${_phaseLabel(state.phase)}・${_remainingLabel(state.remainingSeconds)}',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: [15, 25, 45]
                        .map(
                          (minutes) => ChoiceChip(
                            label: Text('$minutes 分鐘'),
                            selected: _durationMinutes == minutes,
                            onSelected: connected && !_busy
                                ? (_) =>
                                      setState(() => _durationMinutes = minutes)
                                : null,
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: connected && !_busy
                          ? () => _perform(_configureFocus)
                          : null,
                      icon: const Icon(Icons.timer_outlined),
                      label: const Text('傳送專注設定'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children:
                        [
                              ('開始', 'start'),
                              ('暫停', 'pause'),
                              ('繼續', 'resume'),
                              ('完成', 'complete'),
                            ]
                            .map(
                              (action) => FilledButton.tonal(
                                onPressed: connected && !_busy
                                    ? () => _perform(
                                        () =>
                                            coordinator!.sendAction(action.$2),
                                      )
                                    : null,
                                child: Text(action.$1),
                              ),
                            )
                            .toList(),
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('活動帳本同步', style: AppUI.sectionTitleOf(context)),
                  const SizedBox(height: 8),
                  Text(
                    '裝置待確認 ${state.pendingEvents} 筆・App 待上傳 $_pendingCloudEvents 筆',
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: !_busy && _runtime != null
                        ? () => _perform(_flushCloud)
                        : null,
                    icon: const Icon(Icons.cloud_upload_outlined),
                    label: const Text('立即同步到 Cloud'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppUI.cardGap),
          Card(
            shape: AppUI.cardShape(),
            child: const Padding(
              padding: EdgeInsets.all(AppUI.innerPadding),
              child: Text(
                '只有指派給目前帳號的裝置可以連線與送出活動。裝置事件會先安全寫入 App 活動帳本，再回覆 ACK；房間只接收指派且仍有權限的彙整成果。',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
