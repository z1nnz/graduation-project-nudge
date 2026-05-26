import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/avatar_catalog.dart';
import '../models/avatar_profile.dart';
import '../state/app_state.dart';
import '../theme/app_ui.dart';
import '../widgets/avatar_preview.dart';
import 'privacy_data_page.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _controller = PageController();
  int _step = 0;
  String _goal = 'study';
  int _avatarIndex = 0;
  bool _taskReminder = true;
  bool _sleepReminder = true;
  bool _roomReminder = true;
  bool _deadlineReminder = true;
  bool _privacyChecked = false;

  static const List<_GoalOption> _goals = [
    _GoalOption(
      key: 'study',
      title: '讀書與專注',
      subtitle: '建立每日專注、報告與考試節奏',
      icon: Icons.menu_book_outlined,
    ),
    _GoalOption(
      key: 'health',
      title: '健康作息',
      subtitle: '先穩住睡眠、步數與運動',
      icon: Icons.favorite_border,
    ),
    _GoalOption(
      key: 'life',
      title: '生活管理',
      subtitle: '整理日常、家事與固定習慣',
      icon: Icons.home_repair_service_outlined,
    ),
    _GoalOption(
      key: 'team',
      title: '朋友一起',
      subtitle: '用自律房和好友互相陪跑',
      icon: Icons.groups_2_outlined,
    ),
  ];

  List<_TaskTemplate> get _templates {
    switch (_goal) {
      case 'health':
        return const [
          _TaskTemplate('睡滿 7 小時', '睡眠', '高', Icons.nights_stay_outlined),
          _TaskTemplate('步行 6000 步', '運動', '中', Icons.directions_walk),
          _TaskTemplate('運動 20 分鐘', '運動', '中', Icons.local_fire_department),
        ];
      case 'life':
        return const [
          _TaskTemplate('整理房間 10 分鐘', '家事', '中', Icons.cleaning_services),
          _TaskTemplate('喝水 1500 ml', '健康', '低', Icons.water_drop_outlined),
          _TaskTemplate('睡前整理明日任務', '工作', '中', Icons.edit_note),
        ];
      case 'team':
        return const [
          _TaskTemplate('進入一間自律房', '自律房', '中', Icons.groups_2_outlined),
          _TaskTemplate('完成 25 分鐘專注', '讀書', '高', Icons.timer_outlined),
          _TaskTemplate('送出一則好友鼓勵', '社交', '低', Icons.favorite_border),
        ];
      case 'study':
      default:
        return const [
          _TaskTemplate('完成 25 分鐘專注', '讀書', '高', Icons.timer_outlined),
          _TaskTemplate('整理今天待辦', '工作', '中', Icons.checklist_rounded),
          _TaskTemplate('複習 10 個重點', '讀書', '中', Icons.school_outlined),
        ];
    }
  }

  void _go(int nextStep) {
    setState(() => _step = nextStep);
    _controller.animateToPage(
      nextStep,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _finish(AppState appState) async {
    final existingTitles = appState.tasks
        .map((task) => task['title'] as String? ?? '')
        .toSet();

    for (final template in _templates) {
      if (existingTitles.contains(template.title)) continue;
      appState.addTask(
        template.title,
        template.category,
        taskType: 'fixed',
        priority: template.priority,
      );
    }

    await appState.updateAvatarProfile(
      AvatarProfile.initial().copyWith(faceShapeIndex: _avatarIndex),
    );
    await appState.setReminderEnabled('tasks', _taskReminder);
    await appState.setReminderEnabled('sleep', _sleepReminder);
    await appState.setReminderEnabled('rooms', _roomReminder);
    await appState.setReminderEnabled('deadline', _deadlineReminder);
    if (_privacyChecked && !appState.hasAcceptedPrivacyPolicy) {
      await appState.acceptPrivacyPolicy();
    }
    await appState.completeOnboarding();
    if (mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _skip(AppState appState) async {
    await appState.completeOnboarding();
    if (mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final accentColor = appState.currentIconColor;
    final canFinish = _privacyChecked || appState.hasAcceptedPrivacyPolicy;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppUI.pagePadding,
                14,
                AppUI.pagePadding,
                8,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '開始使用 Nudge',
                          style: AppUI.sectionTitleOf(context),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '用 5 個步驟建立你的第一天自律節奏。',
                          style: AppUI.bodyOf(context),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () => _skip(appState),
                    child: const Text('略過'),
                  ),
                ],
              ),
            ),
            _StepDots(current: _step, accentColor: accentColor),
            Expanded(
              child: PageView(
                controller: _controller,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _OnboardingStep(
                    title: '你現在最想養成什麼？',
                    subtitle: 'Nudge 會依目標先建立第一批任務。',
                    child: _GoalGrid(
                      goals: _goals,
                      selectedGoal: _goal,
                      accentColor: accentColor,
                      onSelected: (value) => setState(() => _goal = value),
                    ),
                  ),
                  _OnboardingStep(
                    title: '先放進 3 個起步任務',
                    subtitle: '這些不是壓力，是讓系統開始陪跑的第一批目標。',
                    child: Column(
                      children: _templates
                          .map(
                            (template) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _TemplateCard(
                                template: template,
                                accentColor: accentColor,
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  _OnboardingStep(
                    title: '選一個今天的角色',
                    subtitle: '之後可以在商城購買更多完整角色。',
                    child: _AvatarPicker(
                      selectedIndex: _avatarIndex,
                      accentColor: accentColor,
                      onSelected: (index) =>
                          setState(() => _avatarIndex = index),
                    ),
                  ),
                  _OnboardingStep(
                    title: '打開重要提醒',
                    subtitle: '提醒是必做功能，先決定哪些事情要被 Nudge 輕推一下。',
                    child: Column(
                      children: [
                        _ReminderSwitch(
                          title: '任務提醒',
                          subtitle: '每天提醒還沒完成的今日任務',
                          icon: Icons.checklist_rounded,
                          value: _taskReminder,
                          color: AppUI.blue,
                          onChanged: (value) =>
                              setState(() => _taskReminder = value),
                        ),
                        _ReminderSwitch(
                          title: '睡眠提醒',
                          subtitle: '睡前提醒，讓健康任務更穩',
                          icon: Icons.nights_stay_outlined,
                          value: _sleepReminder,
                          color: AppUI.purple,
                          onChanged: (value) =>
                              setState(() => _sleepReminder = value),
                        ),
                        _ReminderSwitch(
                          title: '自律房提醒',
                          subtitle: '朋友開始時提醒你回到房間',
                          icon: Icons.groups_2_outlined,
                          value: _roomReminder,
                          color: AppUI.green,
                          onChanged: (value) =>
                              setState(() => _roomReminder = value),
                        ),
                        _ReminderSwitch(
                          title: '截止日提醒',
                          subtitle: '到期前提醒驗收與拆解任務',
                          icon: Icons.flag_outlined,
                          value: _deadlineReminder,
                          color: AppUI.orange,
                          onChanged: (value) =>
                              setState(() => _deadlineReminder = value),
                        ),
                      ],
                    ),
                  ),
                  _OnboardingStep(
                    title: '資料與隱私確認',
                    subtitle: '健康、睡眠與步數都屬於敏感資料，使用前要先讓使用者清楚知道用途。',
                    child: _PrivacyConsentCard(
                      checked:
                          _privacyChecked || appState.hasAcceptedPrivacyPolicy,
                      locked: appState.hasAcceptedPrivacyPolicy,
                      accentColor: accentColor,
                      onChanged: (value) =>
                          setState(() => _privacyChecked = value ?? false),
                      onOpenPrivacy: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const PrivacyDataPage(),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppUI.pagePadding,
                8,
                AppUI.pagePadding,
                AppUI.pagePadding,
              ),
              child: Row(
                children: [
                  if (_step > 0)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _go(_step - 1),
                        child: const Text('上一步'),
                      ),
                    )
                  else
                    const Spacer(),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: accentColor,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _step == 4
                          ? (canFinish ? () => _finish(appState) : null)
                          : () => _go(_step + 1),
                      child: Text(_step == 4 ? '進入首頁' : '下一步'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GoalOption {
  final String key;
  final String title;
  final String subtitle;
  final IconData icon;

  const _GoalOption({
    required this.key,
    required this.title,
    required this.subtitle,
    required this.icon,
  });
}

class _TaskTemplate {
  final String title;
  final String category;
  final String priority;
  final IconData icon;

  const _TaskTemplate(this.title, this.category, this.priority, this.icon);
}

class _OnboardingStep extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const _OnboardingStep({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppUI.pagePadding),
      children: [
        Container(
          padding: const EdgeInsets.all(AppUI.innerPadding),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(AppUI.radiusCard),
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppUI.sectionTitleOf(context)),
              const SizedBox(height: 8),
              Text(subtitle, style: AppUI.bodyOf(context)),
              const SizedBox(height: 18),
              child,
            ],
          ),
        ),
      ],
    );
  }
}

class _StepDots extends StatelessWidget {
  final int current;
  final Color accentColor;

  const _StepDots({required this.current, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (index) {
        final selected = current == index;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: selected ? 28 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: selected
                ? accentColor
                : AppUI.textSecondaryOf(context).withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(AppUI.radiusPill),
          ),
        );
      }),
    );
  }
}

class _GoalGrid extends StatelessWidget {
  final List<_GoalOption> goals;
  final String selectedGoal;
  final Color accentColor;
  final ValueChanged<String> onSelected;

  const _GoalGrid({
    required this.goals,
    required this.selectedGoal,
    required this.accentColor,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 430;
        return GridView.count(
          crossAxisCount: isNarrow ? 1 : 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: isNarrow ? 3.25 : 1.45,
          children: goals.map((goal) {
            final selected = selectedGoal == goal.key;
            return InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => onSelected(goal.key),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: selected
                      ? accentColor.withValues(
                          alpha: AppUI.isDark(context) ? 0.22 : 0.12,
                        )
                      : AppUI.surfaceVariantOf(context),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: selected
                        ? accentColor
                        : Theme.of(context).dividerColor,
                    width: selected ? 1.6 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: AppUI.softCardOf(context, accentColor),
                      child: Icon(goal.icon, color: accentColor),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(goal.title, style: AppUI.cardTitleOf(context)),
                          const SizedBox(height: 4),
                          Text(
                            goal.subtitle,
                            style: AppUI.bodyOf(context),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _TemplateCard extends StatelessWidget {
  final _TaskTemplate template;
  final Color accentColor;

  const _TemplateCard({required this.template, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppUI.surfaceVariantOf(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: AppUI.softCardOf(context, accentColor),
            child: Icon(template.icon, color: accentColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(template.title, style: AppUI.cardTitleOf(context)),
                const SizedBox(height: 4),
                Text(
                  '${template.category} · ${template.priority}優先',
                  style: AppUI.bodyOf(context),
                ),
              ],
            ),
          ),
          const Icon(Icons.add_task_rounded),
        ],
      ),
    );
  }
}

class _AvatarPicker extends StatelessWidget {
  final int selectedIndex;
  final Color accentColor;
  final ValueChanged<int> onSelected;

  const _AvatarPicker({
    required this.selectedIndex,
    required this.accentColor,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.78,
      ),
      itemCount: AvatarCatalog.faceShapeLabels.length,
      itemBuilder: (context, index) {
        final selected = selectedIndex == index;
        final profile = AvatarProfile.initial().copyWith(faceShapeIndex: index);
        return InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: () => onSelected(index),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: selected
                  ? accentColor.withValues(
                      alpha: AppUI.isDark(context) ? 0.22 : 0.12,
                    )
                  : AppUI.surfaceVariantOf(context),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: selected ? accentColor : Theme.of(context).dividerColor,
                width: selected ? 1.6 : 1,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  height: 132,
                  child: Center(
                    child: AvatarPreview(
                      profile: profile,
                      size: 112,
                      showBackgroundRing: false,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  AvatarCatalog.faceShapeLabels[index],
                  style: AppUI.cardTitleOf(context),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ReminderSwitch extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool value;
  final Color color;
  final ValueChanged<bool> onChanged;

  const _ReminderSwitch({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.value,
    required this.color,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppUI.surfaceVariantOf(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: AppUI.softCardOf(context, color),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppUI.cardTitleOf(context)),
                const SizedBox(height: 4),
                Text(subtitle, style: AppUI.bodyOf(context)),
              ],
            ),
          ),
          Switch(value: value, activeThumbColor: color, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _PrivacyConsentCard extends StatelessWidget {
  final bool checked;
  final bool locked;
  final Color accentColor;
  final ValueChanged<bool?> onChanged;
  final VoidCallback onOpenPrivacy;

  const _PrivacyConsentCard({
    required this.checked,
    required this.locked,
    required this.accentColor,
    required this.onChanged,
    required this.onOpenPrivacy,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: AppUI.softCardOf(context, accentColor),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.privacy_tip_outlined, color: accentColor),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Nudge 會使用任務、專注、睡眠、步數與運動分鐘來計算自律分數；健康資料只用於自動追蹤與統計，不會把原始資料公開給好友。',
                  style: TextStyle(
                    color: AppUI.textPrimaryOf(context),
                    height: 1.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        CheckboxListTile(
          value: checked,
          onChanged: locked ? null : onChanged,
          activeColor: accentColor,
          contentPadding: EdgeInsets.zero,
          title: Text(
            locked ? '已同意隱私與健康資料說明' : '我已閱讀並同意隱私與健康資料說明',
            style: AppUI.cardTitleOf(context),
          ),
          subtitle: Text(
            '之後可以到「隱私與資料」頁解除同意並清除本機資料。',
            style: AppUI.bodyOf(context),
          ),
        ),
        TextButton.icon(
          onPressed: onOpenPrivacy,
          icon: const Icon(Icons.open_in_new_rounded),
          label: const Text('查看完整隱私與資料頁'),
        ),
      ],
    );
  }
}
