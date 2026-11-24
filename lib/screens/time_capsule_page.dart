import '../theme/game_ui.dart';
import '../widgets/game_facility_scene.dart';
import '../widgets/game_scene_life.dart';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme/app_ui.dart';

class TimeCapsulePage extends StatefulWidget {
  const TimeCapsulePage({super.key});

  @override
  State<TimeCapsulePage> createState() => _TimeCapsulePageState();
}

class _TimeCapsulePageState extends State<TimeCapsulePage> {
  final _titleController = TextEditingController(text: '期末前的我');
  final _messageController = TextEditingController(
    text: '我希望自己每天至少專注 30 分鐘，不要把壓力留到最後一天。',
  );
  bool _saving = false;
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 14));

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  DateTime? _unlockDate(String meta) {
    final dateStr = meta.replaceAll(' 解鎖', '').trim();
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(dateStr)) return null;
    final date = DateTime.tryParse(dateStr);
    if (date == null || date.toIso8601String().substring(0, 10) != dateStr) {
      return null;
    }
    return date;
  }

  bool _isUnlocked(String meta) {
    final date = _unlockDate(meta);
    return date != null && DateTime.now().isAfter(date);
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().add(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    const accentColor = GamePalette.goldDeep;
    final primaryText = GamePalette.of(context).ink;
    final secondaryText = GamePalette.of(context).inkMuted;
    final capsules = appState.timeCapsules;

    return Scaffold(
      appBar: AppBar(title: const Text('時間膠囊備忘')),
      body: GameFacilityScene(
        title: '樹下的時間膠囊',
        background: 'assets/scenes/journal/letter_garden.webp',
        guide: 'letty',
        guideLine: '舊版備忘依裝置日期回顧；正式伺服器密封膠囊在網頁紀錄館，內容到期前由伺服器保護。',
        objectLabel: '查看樹下膠囊',
        objectIcon: Icons.inventory_2_outlined,
        foreground: Positioned.fill(
          child: IgnorePointer(
            child: GameSceneLife(
              kind: 'capsule',
              ready: capsules.any((c) => _isUnlocked(c['meta'] ?? '')),
            ),
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.all(AppUI.pagePadding),
          children: [
            GamePanel(
              child: Text(
                '這裡沿用舊版備忘，依裝置日期回顧，並非伺服器密封。正式密封膠囊請使用網頁紀錄館。',
                style: TextStyle(
                  fontSize: 14,
                  color: GamePalette.of(context).ink,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: GameRecordStyle.hero(accentColor),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.hourglass_empty_rounded,
                        color: GamePalette.inkLight,
                        size: 28,
                      ),
                      SizedBox(width: 10),
                      Text(
                        '時間膠囊',
                        style: TextStyle(
                          color: GamePalette.inkLight,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(
                    '寫給未來的承諾。適合在大考、專案、或活動前使用。時間到期解鎖後，可回顧當時設定的目標與實際成果。',
                    style: TextStyle(
                      color: GamePalette.inkLight,
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppUI.sectionGap),

            // ─── 新增時間膠囊 ──────────────────────────────────────────
            GameArtifact(
              shape: AppUI.cardShape(),
              child: Padding(
                padding: const EdgeInsets.all(AppUI.innerPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('新增時間膠囊', style: AppUI.sectionTitleOf(context)),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: '膠囊標題',
                        hintText: '例如：期末前的我',
                      ),
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: () => _selectDate(context),
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Theme.of(context).dividerColor,
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '解鎖日期',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: secondaryText,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: primaryText,
                                  ),
                                ),
                              ],
                            ),
                            Icon(
                              Icons.calendar_month_outlined,
                              color: accentColor,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _messageController,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: '寫給未來的自己',
                        hintText: '寫下你對未來的期許與自律目標...',
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _saving
                                ? null
                                : () async {
                                    if (appState.currentUser == null ||
                                        appState.isGuestMode) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                            const SnackBar(
                                              content: Text('請先登入帳號後再保存。'),
                                            ),
                                          );
                                      return;
                                    }
                                    final title = _titleController.text.trim();
                                    final msg = _messageController.text.trim();
                                    if (title.isEmpty || msg.isEmpty) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                            const SnackBar(
                                              content: Text('請填寫標題與內容'),
                                            ),
                                          );
                                      return;
                                    }
                                    setState(() => _saving = true);
                                    final dateStr =
                                        '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';
                                    try {
                                      await appState.saveTimeCapsule(
                                        title,
                                        dateStr,
                                        msg,
                                      );
                                      if (!context.mounted) return;

                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                '保存請求已送出，請在下方確認是否出現紀錄。',
                                              ),
                                            ),
                                          );
                                      // Retain the draft while the player confirms the saved record.
                                    } catch (_) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text('這次沒有完成保存，草稿已保留。'),
                                          ),
                                        );
                                      }
                                    } finally {
                                      if (mounted) {
                                        setState(() => _saving = false);
                                      }
                                    }
                                  },
                            icon: const Icon(Icons.send_rounded, size: 18),
                            label: const Text('保存時間膠囊'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: GamePalette.woodDark,
                              foregroundColor: GamePalette.inkLight,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: AppUI.sectionGap),

            // ─── 已保存的膠囊列表 ──────────────────────────────────────
            Text('舊版備忘膠囊', style: AppUI.sectionTitleOf(context)),
            const SizedBox(height: AppUI.cardGap),

            if (capsules.isEmpty)
              GameArtifact(
                shape: AppUI.cardShape(),
                child: Padding(
                  padding: const EdgeInsets.all(AppUI.innerPadding),
                  child: Text(
                    '目前尚未保存任何時間膠囊。',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: secondaryText),
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: capsules.length,
                itemBuilder: (context, index) {
                  final capsule = capsules[index];
                  final isUnlocked = _isUnlocked(capsule['meta'] ?? '');
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppUI.cardGap),
                    child: _buildCapsuleTile(
                      context,
                      capsule,
                      isUnlocked,
                      index,
                      appState,
                      accentColor,
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCapsuleTile(
    BuildContext context,
    Map<String, dynamic> capsule,
    bool isUnlocked,
    int index,
    AppState appState,
    Color accentColor,
  ) {
    final primaryText = GamePalette.of(context).ink;
    final secondaryText = GamePalette.of(context).inkMuted;
    final title = capsule['title'] ?? '自律時間膠囊';
    final meta = capsule['meta'] ?? '未設定日期';
    final message = capsule['message'] ?? '';

    return GameArtifact(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Banner(
          message: isUnlocked ? '已解鎖' : '未解鎖',
          location: BannerLocation.topEnd,
          color: isUnlocked ? GamePalette.green : GamePalette.goldDeep,
          child: ExpansionTile(
            leading: CircleAvatar(
              backgroundColor: (isUnlocked ? GamePalette.green : accentColor)
                  .withValues(alpha: 0.12),
              child: Icon(
                isUnlocked
                    ? Icons.lock_open_outlined
                    : Icons.lock_outline_rounded,
                color: isUnlocked ? GamePalette.green : accentColor,
              ),
            ),
            title: Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: primaryText,
              ),
            ),
            subtitle: Text(
              meta,
              style: TextStyle(fontSize: 14, color: secondaryText),
            ),
            trailing: IconButton(
              icon: const Icon(
                Icons.delete_outline,
                color: GamePalette.red,
                size: 20,
              ),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: GamePalette.of(context).backgroundTop,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                      side: BorderSide(
                        color: GamePalette.of(context).wood,
                        width: 3,
                      ),
                    ),
                    title: const Text('刪除膠囊'),
                    content: const Text('確定要刪除這個時間膠囊嗎？此操作無法復原。'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('取消'),
                      ),
                      TextButton(
                        onPressed: () {
                          appState.deleteTimeCapsule(index);
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('時間膠囊已刪除')),
                          );
                        },
                        child: const Text(
                          '刪除',
                          style: TextStyle(color: GamePalette.red),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Theme.of(context).scaffoldBackgroundColor
                        .withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Theme.of(context).dividerColor
                          .withValues(alpha: 0.5),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (isUnlocked) ...[
                        Text(
                          '當時的你留下的話：',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: secondaryText,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          message,
                          style: TextStyle(
                            fontSize: 14,
                            color: primaryText,
                            height: 1.5,
                          ),
                        ),
                      ] else ...[
                        Row(
                          children: [
                            const Icon(
                              Icons.lock_clock,
                              color: GamePalette.goldDeep,
                              size: 18,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                _unlockDate(meta) == null
                                    ? '日期無法核對，這份備忘暫不展開。'
                                    : '此膠囊將在 $meta 開啟，目前依裝置日期保留為備忘。',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: secondaryText,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
