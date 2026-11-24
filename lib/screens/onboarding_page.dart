import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/avatar_catalog.dart';
import '../models/avatar_profile.dart';
import '../state/app_state.dart';
import '../theme/app_ui.dart';
import '../widgets/avatar_preview.dart';
import '../models/companion_pose.dart';
import '../theme/game_ui.dart';
import '../widgets/companion_sprite.dart';
import 'privacy_data_page.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  /// What the companion says on each step.
  static const guideLines = [
    '嗨！我是你的夥伴。先告訴我，你是用什麼身分來的？',
    '你最想先養成哪個習慣呢？我陪你一起。',
    '我先幫你準備三個小委託，做完就能收到金幣喔。',
    '換上你喜歡的樣子吧，之後還能在商城買新衣服。',
    '要不要讓我在重要的時候輕輕提醒你？',
    '最後一步！確認一下資料怎麼用，我們就出發。',
  ];

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
  String _roleSetting = 'personal';

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
    await appState.setUserRole(_roleSetting);
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
    // Gold matches the cabin; the old per-theme accent read as purple.
    const accentColor = GamePalette.goldDeep;
    final canFinish = _privacyChecked || appState.hasAcceptedPrivacyPolicy;

    return Scaffold(
      backgroundColor: const Color(0xFF3B2418),
      body: Stack(
        children: [
          // The cabin, softly blurred, behind the whole welcome.
          Positioned.fill(
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
              child: ColorFiltered(
                colorFilter: const ColorFilter.mode(
                  Color(0x66000000),
                  BlendMode.darken,
                ),
                child: Image.asset(
                  'assets/home/room_base.png',
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppUI.pagePadding,
                    10,
                    AppUI.pagePadding,
                    4,
                  ),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          '歡迎來到夥伴小屋',
                          style: TextStyle(
                            fontFamily: 'Cubic11',
                            fontSize: 26,
                            color: Color(0xFFFFE6A3),
                            shadows: [
                              Shadow(
                                color: Color(0xFF3B2418),
                                offset: Offset(0, 3),
                              ),
                            ],
                          ),
                        ),
                      ),
                      TextButton(
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFFF3D9B0),
                        ),
                        onPressed: () => _skip(appState),
                        child: const Text('略過'),
                      ),
                    ],
                  ),
                ),
                _Guide(
                  key: const Key('onboarding-guide'),
                  profile: appState.avatarProfile,
                  line: OnboardingPage.guideLines[_step.clamp(0, 5)],
                ),
                const SizedBox(height: 6),
                _StepDots(current: _step, accentColor: accentColor),
                Expanded(
                  child: PageView(
                    controller: _controller,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _OnboardingStep(
                        title: '選擇您的自律身份',
                        subtitle: 'Nudge 會依據您的身份載入不同的功能與數據端。',
                        child: _RoleGrid(
                          selectedRole: _roleSetting,
                          accentColor: accentColor,
                          onSelected: (value) =>
                              setState(() => _roleSetting = value),
                        ),
                      ),
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
                              _privacyChecked ||
                              appState.hasAcceptedPrivacyPolicy,
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
                          child: GameButton(
                            label: '上一步',
                            primary: false,
                            expand: true,
                            onPressed: () => _go(_step - 1),
                          ),
                        )
                      else
                        const Spacer(),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GameButton(
                          label: _step == 5 ? '走進小屋' : '下一步',
                          icon: _step == 5
                              ? Icons.door_front_door_rounded
                              : Icons.arrow_forward_rounded,
                          expand: true,
                          onPressed: _step == 5
                              ? (canFinish ? () => _finish(appState) : null)
                              : () => _go(_step + 1),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
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
        GamePanel(
          padding: const EdgeInsets.all(AppUI.innerPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontFamily: 'Cubic11',
                  fontSize: 22,
                  color: GamePalette.of(context).ink,
                ),
              ),
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
      children: List.generate(6, (index) {
        final lit = index <= current;
        final state = lit ? 'on' : 'off';
        return AnimatedScale(
          key: Key('onboarding-star-$index-$state'),
          duration: const Duration(milliseconds: 200),
          scale: index == current ? 1.25 : 1,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Icon(
              lit ? Icons.star_rounded : Icons.star_outline_rounded,
              size: 22,
              color: lit ? GamePalette.gold : const Color(0x99F3D9B0),
            ),
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
                      : GamePalette.of(context).wood.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: selected
                        ? accentColor
                        : GamePalette.of(
                            context,
                          ).panelBorder.withValues(alpha: 0.6),
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
        color: GamePalette.of(context).wood.withValues(alpha: 0.10),
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

  static const List<int> starterIndexes = [0, 3, 6, 9];

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
      itemCount: starterIndexes.length,
      itemBuilder: (context, index) {
        final actualIndex = starterIndexes[index];
        final selected = selectedIndex == actualIndex;
        final profile = AvatarProfile.initial().copyWith(
          faceShapeIndex: actualIndex,
        );
        return InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: () => onSelected(actualIndex),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: selected
                  ? accentColor.withValues(
                      alpha: AppUI.isDark(context) ? 0.22 : 0.12,
                    )
                  : GamePalette.of(context).wood.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: selected
                    ? accentColor
                    : GamePalette.of(
                        context,
                      ).panelBorder.withValues(alpha: 0.6),
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
                  AvatarCatalog.faceShapeLabels[actualIndex],
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
        color: GamePalette.of(context).wood.withValues(alpha: 0.10),
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

class _RoleGrid extends StatelessWidget {
  final String selectedRole;
  final Color accentColor;
  final ValueChanged<String> onSelected;

  const _RoleGrid({
    required this.selectedRole,
    required this.accentColor,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final roles = [
      {
        'key': 'personal',
        'title': '個人自律模式',
        'subtitle': '獨自記錄與精進專注，寫信給未來的自己。',
        'icon': Icons.person_outline_rounded,
      },
      {
        'key': 'child',
        'title': '孩子端',
        'subtitle': '接收家長陪伴邀請與鼓勵卡，匯入學校任務模板。',
        'icon': Icons.face_outlined,
      },
      {
        'key': 'guardian',
        'title': '家長陪伴端',
        'subtitle': '送鼓勵卡、建立共同目標，即時查看孩子的自律數據。',
        'icon': Icons.family_restroom_outlined,
      },
      {
        'key': 'group',
        'title': '教育/團體管理端',
        'subtitle': '班級、補習班或企業自律大考挑戰發佈端。',
        'icon': Icons.business_center_outlined,
      },
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 430;
        return GridView.count(
          crossAxisCount: isNarrow ? 1 : 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: isNarrow ? 3.0 : 1.45,
          children: roles.map((role) {
            final key = role['key'] as String;
            final title = role['title'] as String;
            final subtitle = role['subtitle'] as String;
            final icon = role['icon'] as IconData;
            final selected = selectedRole == key;

            return InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => onSelected(key),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: selected
                      ? accentColor.withValues(
                          alpha: AppUI.isDark(context) ? 0.22 : 0.12,
                        )
                      : GamePalette.of(context).wood.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: selected
                        ? accentColor
                        : GamePalette.of(
                            context,
                          ).panelBorder.withValues(alpha: 0.6),
                    width: selected ? 1.6 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: AppUI.softCardOf(context, accentColor),
                      child: Icon(icon, color: accentColor),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: AppUI.cardTitleOf(context)),
                          const SizedBox(height: 4),
                          Text(
                            subtitle,
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

/// The companion standing on the welcome screen, talking you through it.
class _Guide extends StatelessWidget {
  const _Guide({super.key, required this.profile, required this.line});

  final AvatarProfile profile;
  final String line;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppUI.pagePadding),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          SizedBox(
            width: 92,
            height: 92,
            child: CompanionSprite(
              profile: profile,
              pose: CompanionPose.idle,
              size: 92,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: Container(
                key: ValueKey(line),
                margin: const EdgeInsets.only(bottom: 26),
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFAF0),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFA8743F), width: 3),
                ),
                child: Text(
                  line,
                  style: const TextStyle(
                    color: Color(0xFF3A1D0C),
                    fontWeight: FontWeight.w800,
                    height: 1.4,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
