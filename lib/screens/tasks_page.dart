import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/task_model.dart';
import '../state/app_state.dart';
import '../theme/app_ui.dart';

class TasksPage extends StatefulWidget {
  const TasksPage({super.key});

  @override
  State<TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends State<TasksPage> {
  String selectedFilter = '全部';
  String selectedSort = '智慧排序';
  String selectedViewMode = '今日';

  final List<String> categories = [
    '讀書',
    '運動',
    '睡眠',
    '工作',
    '家事',
    '健康',
    '自律房',
    '自定義',
  ];

  final List<String> deadlineCategories = [
    '報告',
    '作業',
    '考試準備',
    '工作期限',
    '專題',
    '申請',
    '其他期限',
  ];

  final List<String> filters = [
    '全部',
    '讀書',
    '運動',
    '睡眠',
    '工作',
    '家事',
    '健康',
    '自律房',
    '自定義',
  ];

  final List<String> priorities = ['高', '中', '低'];

  final List<String> sortOptions = ['智慧排序', '優先級高到低', '截止日最近', '未完成優先', '分類排序'];

  final List<String> viewModes = ['今日', '自動追蹤', '截止日', '已完成'];

  Color getCategoryColor(String category) {
    switch (category) {
      case '讀書':
        return const Color(0xFF4F8CFF);
      case '報告':
      case '作業':
      case '專題':
        return const Color(0xFF6366F1);
      case '考試準備':
        return const Color(0xFF8B5CF6);
      case '工作期限':
      case '申請':
        return const Color(0xFFF59E0B);
      case '運動':
        return const Color(0xFF10B981);
      case '睡眠':
        return const Color(0xFF8B5CF6);
      case '工作':
        return const Color(0xFF6366F1);
      case '家事':
        return const Color(0xFFF97316);
      case '健康':
        return const Color(0xFFEC4899);
      case '共讀':
      case '自律房':
        return const Color(0xFFF59E0B);
      case '自定義':
      case '其他期限':
        return const Color(0xFFF59E0B);
      default:
        return Colors.grey;
    }
  }

  IconData getCategoryIcon(String category) {
    switch (category) {
      case '讀書':
        return Icons.menu_book_outlined;
      case '報告':
        return Icons.description_outlined;
      case '作業':
        return Icons.assignment_outlined;
      case '考試準備':
        return Icons.school_outlined;
      case '工作期限':
        return Icons.work_history_outlined;
      case '專題':
        return Icons.folder_special_outlined;
      case '申請':
        return Icons.outbox_outlined;
      case '運動':
        return Icons.fitness_center;
      case '睡眠':
        return Icons.bedtime_outlined;
      case '工作':
        return Icons.work_outline;
      case '家事':
        return Icons.home_outlined;
      case '健康':
        return Icons.favorite_border;
      case '共讀':
      case '自律房':
        return Icons.groups_2_outlined;
      case '自定義':
      case '其他期限':
        return Icons.edit_note_outlined;
      default:
        return Icons.label_outline;
    }
  }

  Color getPriorityColor(String priority) {
    switch (priority) {
      case '高':
        return const Color(0xFFEF4444);
      case '中':
        return const Color(0xFFF59E0B);
      case '低':
        return const Color(0xFF10B981);
      default:
        return const Color(0xFF6B7280);
    }
  }

  int _priorityRank(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.high:
        return 0;
      case TaskPriority.medium:
        return 1;
      case TaskPriority.low:
        return 2;
    }
  }

  int _categoryRank(String category) {
    final fixedIndex = categories.indexOf(category);
    if (fixedIndex >= 0) return fixedIndex;
    final deadlineIndex = deadlineCategories.indexOf(category);
    if (deadlineIndex >= 0) return categories.length + deadlineIndex;
    return categories.length + deadlineCategories.length;
  }

  int _daysUntil(DateTime? dueDate) {
    if (dueDate == null) return 999999;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(dueDate.year, dueDate.month, dueDate.day);
    return target.difference(today).inDays;
  }

  bool _isPriorityTask(TaskModel task) {
    if (task.isDone) return false;
    if (task.priority == TaskPriority.high) return true;
    if (task.taskType == TaskType.deadline && _daysUntil(task.dueDate) <= 1) {
      return true;
    }
    return false;
  }

  String _taskTypeValue(TaskModel task) {
    return TaskModel.taskTypeToStringValue(task.taskType);
  }

  String _priorityChinese(TaskModel task) {
    return TaskModel.priorityToChinese(task.priority);
  }

  List<TaskModel> getFilteredTasks(List<TaskModel> tasks) {
    return tasks.where((task) {
      switch (selectedViewMode) {
        case '自動追蹤':
          if (!task.isAutoTracked) return false;
          break;
        case '截止日':
          if (task.taskType != TaskType.deadline) return false;
          break;
        case '已完成':
          if (!task.isDone) return false;
          break;
        case '今日':
        default:
          if (task.isDone) return false;
          break;
      }

      if (selectedFilter == '全部') return true;
      if (selectedFilter == '自律房') {
        return task.category == '自律房' || task.category == '共讀';
      }
      return task.category == selectedFilter;
    }).toList();
  }

  List<TaskModel> getSortedTasks(List<TaskModel> tasks) {
    final sorted = List<TaskModel>.from(tasks);

    int compareTask(TaskModel a, TaskModel b) {
      switch (selectedSort) {
        case '優先級高到低':
          final p = _priorityRank(
            a.priority,
          ).compareTo(_priorityRank(b.priority));
          if (p != 0) return p;
          if (a.isDone != b.isDone) return a.isDone ? 1 : -1;
          return 0;

        case '截止日最近':
          if (a.taskType != b.taskType) {
            if (a.taskType == TaskType.deadline) return -1;
            if (b.taskType == TaskType.deadline) return 1;
          }
          final d = _daysUntil(a.dueDate).compareTo(_daysUntil(b.dueDate));
          if (d != 0) return d;
          if (a.isDone != b.isDone) return a.isDone ? 1 : -1;
          return _priorityRank(a.priority).compareTo(_priorityRank(b.priority));

        case '未完成優先':
          if (a.isDone != b.isDone) return a.isDone ? 1 : -1;
          if (a.taskType != b.taskType) {
            if (a.taskType == TaskType.deadline) return -1;
            if (b.taskType == TaskType.deadline) return 1;
          }
          return _priorityRank(a.priority).compareTo(_priorityRank(b.priority));

        case '分類排序':
          final c = _categoryRank(
            a.category,
          ).compareTo(_categoryRank(b.category));
          if (c != 0) return c;
          if (a.isDone != b.isDone) return a.isDone ? 1 : -1;
          return _priorityRank(a.priority).compareTo(_priorityRank(b.priority));

        case '智慧排序':
        default:
          if (a.isDone != b.isDone) return a.isDone ? 1 : -1;

          if (a.taskType != b.taskType) {
            if (a.taskType == TaskType.deadline) return -1;
            if (b.taskType == TaskType.deadline) return 1;
          }

          final p = _priorityRank(
            a.priority,
          ).compareTo(_priorityRank(b.priority));
          if (p != 0) return p;

          if (a.taskType == TaskType.deadline &&
              b.taskType == TaskType.deadline) {
            final d = _daysUntil(a.dueDate).compareTo(_daysUntil(b.dueDate));
            if (d != 0) return d;
          }

          return _categoryRank(a.category).compareTo(_categoryRank(b.category));
      }
    }

    sorted.sort(compareTask);
    return sorted;
  }

  String _formatDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  String _displayTaskType(TaskType taskType) {
    return taskType == TaskType.fixed ? '每日固定活動' : '有截止日任務';
  }

  String _displayDueDate(DateTime? dueDate) {
    if (dueDate == null) return '未設定截止日';

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(dueDate.year, dueDate.month, dueDate.day);
    final diff = target.difference(today).inDays;

    if (diff == 0) return '今天';
    if (diff == 1) return '明天';
    if (diff < 0) return '已逾期';
    return '${dueDate.month}/${dueDate.day}';
  }

  String _unitLabelForSource(TaskSourceType? type) {
    switch (type) {
      case TaskSourceType.focusMinutes:
      case TaskSourceType.exerciseMinutes:
      case TaskSourceType.studyRoom:
        return '分鐘';
      case TaskSourceType.sleepHours:
        return '小時';
      case TaskSourceType.steps:
        return '步';
      case TaskSourceType.manual:
      case TaskSourceType.system:
      case null:
        return '';
    }
  }

  String _autoTaskDefaultTitle(TaskSourceType type, String targetText) {
    switch (type) {
      case TaskSourceType.focusMinutes:
        return '專注 $targetText 分鐘';
      case TaskSourceType.sleepHours:
        return '睡眠 $targetText 小時';
      case TaskSourceType.steps:
        return '步數 $targetText 步';
      case TaskSourceType.exerciseMinutes:
        return '運動 $targetText 分鐘';
      case TaskSourceType.studyRoom:
        return '自律房 $targetText 分鐘';
      case TaskSourceType.manual:
      case TaskSourceType.system:
        return '自動追蹤任務';
    }
  }

  Future<void> _pickCustomDate(
    BuildContext context,
    void Function(DateTime?) onChanged,
    DateTime? currentDate, {
    DateTime? firstDateOverride,
  }) async {
    final now = DateTime.now();
    final firstDate = firstDateOverride ?? DateTime(now.year - 1);
    final initialDate = currentDate != null && currentDate.isAfter(firstDate)
        ? currentDate
        : firstDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: DateTime(now.year + 3),
    );
    if (picked != null) {
      onChanged(picked);
    }
  }

  void showDeleteDialog(int originalIndex, String title) {
    final task = context.read<AppState>().taskModels[originalIndex];
    final canDeleteSystemTask =
        task.title == '完成今日自律房目標' || task.title == '完成今日共讀目標';

    if (task.isSystemTask && !canDeleteSystemTask) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('系統任務不能刪除')));
      return;
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('刪除任務'),
          content: Text('確定要刪除「$title」嗎？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () {
                context.read<AppState>().deleteTask(originalIndex);
                Navigator.pop(context);
              },
              child: const Text('刪除'),
            ),
          ],
        );
      },
    );
  }

  void showAddTaskDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TaskTypePickerSheet(
        onDailyTap: () {
          Navigator.pop(context);
          _showManualTaskDialog(
            initialTaskType: 'fixed',
            lockTaskType: true,
            flowTitle: '新增每日固定活動',
            flowDescription: '適合喝水、家事、背單字、整理房間等每天自己勾選的習慣。',
          );
        },
        onDeadlineTap: () {
          Navigator.pop(context);
          _showManualTaskDialog(
            initialTaskType: 'deadline',
            lockTaskType: true,
            flowTitle: '新增截止日任務',
            flowDescription: '適合報告、作業、考試準備。截止日前不能勾選，到期完成可拿額外自律幣。',
          );
        },
        onAutoTap: () {
          Navigator.pop(context);
          _showAutoTaskDialog(
            lockTaskType: true,
            flowTitle: '新增自動追蹤任務',
            flowDescription: '選擇專注、睡眠、步數或運動，系統會依資料自動判定完成。',
            allowedSources: const {
              TaskSourceType.focusMinutes,
              TaskSourceType.sleepHours,
              TaskSourceType.steps,
              TaskSourceType.exerciseMinutes,
            },
          );
        },
      ),
    );
  }

  void _showManualTaskDialog({
    TaskModel? editingTask,
    int? editingIndex,
    String initialTaskType = 'fixed',
    bool lockTaskType = false,
    String? flowTitle,
    String? flowDescription,
  }) {
    final titleController = TextEditingController(
      text: editingTask?.title ?? '',
    );
    int flowStep = 0;
    String selectedTaskType = editingTask == null
        ? initialTaskType
        : _taskTypeValue(editingTask);
    String selectedCategory =
        editingTask?.category ?? (selectedTaskType == 'deadline' ? '報告' : '讀書');
    final now = DateTime.now();
    final minDeadlineDate = DateTime(
      now.year,
      now.month,
      now.day,
    ).add(const Duration(days: AppState.deadlineTaskMinLeadDays));
    DateTime? selectedDueDate =
        editingTask?.dueDate ??
        (initialTaskType == 'deadline' ? minDeadlineDate : null);
    String selectedPriority = editingTask == null
        ? '中'
        : _priorityChinese(editingTask);

    showDialog(
      context: context,
      builder: (context) {
        final accentColor = context.read<AppState>().currentIconColor;
        final primaryText = AppUI.textPrimaryOf(context);
        final secondaryText = AppUI.textSecondaryOf(context);

        return StatefulBuilder(
          builder: (context, setDialogState) {
            final categoryOptions = selectedTaskType == 'deadline'
                ? deadlineCategories
                : categories;
            final dropdownCategories =
                categoryOptions.contains(selectedCategory)
                ? categoryOptions
                : [selectedCategory, ...categoryOptions];
            final isDeadline = selectedTaskType == 'deadline';

            TaskModel previewTask() {
              final now = DateTime.now();
              return TaskModel(
                id: editingTask?.id ?? 'preview',
                userId: 'local_user',
                title: titleController.text.trim().isEmpty
                    ? '尚未輸入任務名稱'
                    : titleController.text.trim(),
                category: selectedCategory,
                taskType: TaskModel.taskTypeFromString(selectedTaskType),
                priority: TaskModel.priorityFromChinese(selectedPriority),
                dueDate: selectedTaskType == 'fixed' ? null : selectedDueDate,
                createdAt: editingTask?.createdAt ?? now,
                updatedAt: now,
              );
            }

            bool validateCurrentStep() {
              if (flowStep == 0 && titleController.text.trim().isEmpty) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('請先輸入任務名稱')));
                return false;
              }
              if (flowStep == 1 &&
                  editingTask == null &&
                  selectedTaskType == 'deadline' &&
                  (selectedDueDate == null ||
                      selectedDueDate!.isBefore(minDeadlineDate))) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      '截止日任務需設定至少 ${AppState.deadlineTaskMinLeadDays} 天後的日期',
                    ),
                  ),
                );
                return false;
              }
              if (flowStep == 1 &&
                  selectedTaskType == 'deadline' &&
                  selectedDueDate != null &&
                  !context.read<AppState>().canCreateDeadlineTaskForDate(
                    selectedDueDate!,
                    excludingIndex: editingIndex,
                  )) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      '這個月份最多只能設定 ${AppState.deadlineTaskMonthlyCreateLimit} 個截止日任務',
                    ),
                  ),
                );
                return false;
              }
              return true;
            }

            void saveTask() {
              final title = titleController.text.trim();
              if (title.isEmpty) return;

              if (editingTask == null) {
                context.read<AppState>().addTask(
                  title,
                  selectedCategory,
                  taskType: selectedTaskType,
                  dueDate: selectedTaskType == 'fixed'
                      ? null
                      : (selectedDueDate == null
                            ? null
                            : _formatDate(selectedDueDate!)),
                  priority: selectedPriority,
                );
              } else {
                context.read<AppState>().updateTask(
                  index: editingIndex!,
                  title: title,
                  category: selectedCategory,
                  taskType: selectedTaskType,
                  dueDate: selectedTaskType == 'fixed'
                      ? null
                      : (selectedDueDate == null
                            ? null
                            : _formatDate(selectedDueDate!)),
                  priority: selectedPriority,
                );
              }

              Navigator.pop(context);
            }

            return AlertDialog(
              title: Text(
                editingTask == null ? (flowTitle ?? '新增一般任務') : '編輯一般任務',
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _TaskFlowStepper(
                      currentStep: flowStep,
                      accentColor: accentColor,
                    ),
                    const SizedBox(height: 16),
                    if (editingTask == null && flowDescription != null) ...[
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          flowDescription,
                          style: TextStyle(
                            fontSize: 13,
                            color: secondaryText,
                            height: 1.45,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (flowStep == 0) ...[
                      TextField(
                        controller: titleController,
                        decoration: const InputDecoration(
                          labelText: '任務名稱',
                          hintText: '請輸入任務內容',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: selectedCategory,
                        decoration: const InputDecoration(
                          labelText: '任務分類',
                          border: OutlineInputBorder(),
                        ),
                        items: dropdownCategories.map((category) {
                          return DropdownMenuItem<String>(
                            value: category,
                            child: Text(category),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value == null) return;
                          setDialogState(() {
                            selectedCategory = value;
                          });
                        },
                      ),
                      if (!lockTaskType) ...[
                        const SizedBox(height: 16),
                        _FormSectionTitle(title: '任務型態', color: primaryText),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: _SegmentChip(
                                label: '每日固定活動',
                                selected: selectedTaskType == 'fixed',
                                accentColor: accentColor,
                                onTap: () {
                                  setDialogState(() {
                                    selectedTaskType = 'fixed';
                                    selectedDueDate = null;
                                  });
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _SegmentChip(
                                label: '有截止日任務',
                                selected: selectedTaskType == 'deadline',
                                accentColor: accentColor,
                                onTap: () {
                                  setDialogState(() {
                                    selectedTaskType = 'deadline';
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                    if (flowStep == 1) ...[
                      if (isDeadline) ...[
                        _FormSectionTitle(title: '截止日', color: primaryText),
                        const SizedBox(height: 10),
                        InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () => _pickCustomDate(
                            context,
                            (picked) {
                              setDialogState(() {
                                selectedDueDate = picked;
                              });
                            },
                            selectedDueDate,
                            firstDateOverride: editingTask == null
                                ? minDeadlineDate
                                : null,
                          ),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: Theme.of(context).dividerColor,
                              ),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.calendar_today_outlined,
                                  size: 18,
                                  color: secondaryText,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    selectedDueDate == null
                                        ? '選擇截止日'
                                        : _displayDueDate(selectedDueDate),
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: selectedDueDate == null
                                          ? secondaryText
                                          : primaryText,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                if (selectedDueDate != null)
                                  GestureDetector(
                                    onTap: () {
                                      setDialogState(() {
                                        selectedDueDate = null;
                                      });
                                    },
                                    child: Icon(
                                      Icons.close,
                                      size: 18,
                                      color: secondaryText,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          '截止日任務到期後才能勾選完成，完成後會走額外自律幣獎勵。',
                          style: TextStyle(
                            color: secondaryText,
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      _FormSectionTitle(title: '優先級', color: primaryText),
                      const SizedBox(height: 10),
                      Row(
                        children: priorities.map((priority) {
                          final color = getPriorityColor(priority);
                          final selected = selectedPriority == priority;

                          return Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(
                                right: priority != priorities.last ? 8 : 0,
                              ),
                              child: GestureDetector(
                                onTap: () {
                                  setDialogState(() {
                                    selectedPriority = priority;
                                  });
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: selected
                                        ? color
                                        : Theme.of(context).cardColor,
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(
                                      color: selected
                                          ? color
                                          : Theme.of(context).dividerColor,
                                    ),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    priority,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: selected ? Colors.white : color,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                    if (flowStep == 2)
                      _TaskRewardPreviewCard(
                        task: previewTask(),
                        potentialScore: context
                            .read<AppState>()
                            .taskPotentialScoreForTask(previewTask()),
                        reason: context
                            .read<AppState>()
                            .taskRewardReasonForTask(previewTask()),
                        accentColor: accentColor,
                        dueDateText: isDeadline
                            ? _displayDueDate(selectedDueDate)
                            : '每日固定活動',
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    if (flowStep == 0) {
                      Navigator.pop(context);
                      return;
                    }
                    setDialogState(() {
                      flowStep -= 1;
                    });
                  },
                  child: Text(flowStep == 0 ? '取消' : '上一步'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (!validateCurrentStep()) {
                      return;
                    }
                    if (flowStep < 2) {
                      setDialogState(() {
                        flowStep += 1;
                      });
                      return;
                    }
                    saveTask();
                  },
                  child: Text(
                    flowStep < 2 ? '下一步' : (editingTask == null ? '新增' : '儲存'),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showAutoTaskDialog({
    TaskModel? editingTask,
    int? editingIndex,
    TaskSourceType? initialSource,
    Set<TaskSourceType>? allowedSources,
    bool fixedSource = false,
    bool lockTaskType = false,
    String? flowTitle,
    String? flowDescription,
  }) {
    final titleController = TextEditingController(
      text: editingTask?.title ?? '',
    );

    TaskSourceType? selectedSource = editingTask?.sourceType ?? initialSource;
    final targetController = TextEditingController(
      text: editingTask?.targetValue == null
          ? ''
          : (editingTask!.targetValue! % 1 == 0
                ? editingTask.targetValue!.toInt().toString()
                : editingTask.targetValue!.toString()),
    );
    String selectedCategory =
        editingTask?.category ??
        (initialSource == TaskSourceType.studyRoom ? '自律房' : '健康');
    bool useCustomTitle = editingTask != null;
    String selectedTaskType = editingTask == null
        ? 'fixed'
        : _taskTypeValue(editingTask);

    showDialog(
      context: context,
      builder: (context) {
        final accentColor = context.read<AppState>().currentIconColor;
        final primaryText = AppUI.textPrimaryOf(context);
        final secondaryText = AppUI.textSecondaryOf(context);

        void syncTitleFromTarget() {
          if (!useCustomTitle &&
              selectedSource != null &&
              targetController.text.trim().isNotEmpty) {
            titleController.text = _autoTaskDefaultTitle(
              selectedSource!,
              targetController.text.trim(),
            );
          }
        }

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(
                editingTask == null ? (flowTitle ?? '新增自動追蹤任務') : '編輯自動追蹤任務',
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (editingTask == null && flowDescription != null) ...[
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          flowDescription,
                          style: TextStyle(
                            fontSize: 13,
                            color: secondaryText,
                            height: 1.45,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    _FormSectionTitle(title: '追蹤類型', color: primaryText),
                    const SizedBox(height: 6),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        fixedSource
                            ? '這個流程固定連到自律房，不會混入健康或專注來源。'
                            : '選擇資料來源後，系統會依目標值自動判定完成。',
                        style: TextStyle(
                          fontSize: 12,
                          color: secondaryText,
                          height: 1.4,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (fixedSource &&
                        selectedSource == TaskSourceType.studyRoom)
                      _FixedSourceCard(
                        icon: Icons.groups_2_outlined,
                        title: '自律房',
                        subtitle: '依你在自律房累積的今日進度自動判定完成',
                        color: const Color(0xFFF59E0B),
                      )
                    else
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          if (allowedSources == null ||
                              allowedSources.contains(
                                TaskSourceType.focusMinutes,
                              ))
                            _AutoSourceChip(
                              icon: Icons.timer_outlined,
                              label: '專注',
                              selected:
                                  selectedSource == TaskSourceType.focusMinutes,
                              color: const Color(0xFF4F8CFF),
                              onTap: () {
                                setDialogState(() {
                                  selectedSource = TaskSourceType.focusMinutes;
                                  selectedCategory = '讀書';
                                  syncTitleFromTarget();
                                });
                              },
                            ),
                          if (allowedSources == null ||
                              allowedSources.contains(
                                TaskSourceType.sleepHours,
                              ))
                            _AutoSourceChip(
                              icon: Icons.bedtime_outlined,
                              label: '睡眠',
                              selected:
                                  selectedSource == TaskSourceType.sleepHours,
                              color: const Color(0xFF8B5CF6),
                              onTap: () {
                                setDialogState(() {
                                  selectedSource = TaskSourceType.sleepHours;
                                  selectedCategory = '睡眠';
                                  syncTitleFromTarget();
                                });
                              },
                            ),
                          if (allowedSources == null ||
                              allowedSources.contains(TaskSourceType.steps))
                            _AutoSourceChip(
                              icon: Icons.directions_walk,
                              label: '步數',
                              selected: selectedSource == TaskSourceType.steps,
                              color: const Color(0xFF10B981),
                              onTap: () {
                                setDialogState(() {
                                  selectedSource = TaskSourceType.steps;
                                  selectedCategory = '運動';
                                  syncTitleFromTarget();
                                });
                              },
                            ),
                          if (allowedSources == null ||
                              allowedSources.contains(
                                TaskSourceType.exerciseMinutes,
                              ))
                            _AutoSourceChip(
                              icon: Icons.local_fire_department_outlined,
                              label: '運動',
                              selected:
                                  selectedSource ==
                                  TaskSourceType.exerciseMinutes,
                              color: const Color(0xFFF97316),
                              onTap: () {
                                setDialogState(() {
                                  selectedSource =
                                      TaskSourceType.exerciseMinutes;
                                  selectedCategory = '運動';
                                  syncTitleFromTarget();
                                });
                              },
                            ),
                          if (allowedSources == null ||
                              allowedSources.contains(TaskSourceType.studyRoom))
                            _AutoSourceChip(
                              icon: Icons.groups_2_outlined,
                              label: '自律房',
                              selected:
                                  selectedSource == TaskSourceType.studyRoom,
                              color: const Color(0xFFF59E0B),
                              onTap: () {
                                setDialogState(() {
                                  selectedSource = TaskSourceType.studyRoom;
                                  selectedCategory = '自律房';
                                  syncTitleFromTarget();
                                });
                              },
                            ),
                        ],
                      ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: targetController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: selectedSource == null
                            ? '目標值'
                            : '目標值（${_unitLabelForSource(selectedSource)}）',
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: (_) {
                        setDialogState(syncTitleFromTarget);
                      },
                    ),
                    const SizedBox(height: 16),
                    SwitchListTile(
                      value: useCustomTitle,
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        '自訂任務名稱',
                        style: TextStyle(
                          color: primaryText,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Text(
                        useCustomTitle ? '自行輸入顯示名稱' : '系統自動幫你產生名稱',
                        style: TextStyle(color: secondaryText),
                      ),
                      onChanged: (value) {
                        setDialogState(() {
                          useCustomTitle = value;
                          syncTitleFromTarget();
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: titleController,
                      enabled: useCustomTitle,
                      decoration: InputDecoration(
                        labelText: '任務名稱',
                        border: const OutlineInputBorder(),
                        hintText: '例如：專注 30 分鐘',
                        filled: !useCustomTitle,
                      ),
                    ),
                    if (!lockTaskType) ...[
                      const SizedBox(height: 16),
                      _FormSectionTitle(title: '任務型態', color: primaryText),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _SegmentChip(
                              label: '每日固定活動',
                              selected: selectedTaskType == 'fixed',
                              accentColor: accentColor,
                              onTap: () {
                                setDialogState(() {
                                  selectedTaskType = 'fixed';
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _SegmentChip(
                              label: '有截止日任務',
                              selected: selectedTaskType == 'deadline',
                              accentColor: accentColor,
                              onTap: () {
                                setDialogState(() {
                                  selectedTaskType = 'deadline';
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (selectedTaskType == 'deadline') ...[
                      const SizedBox(height: 12),
                      Text(
                        '自動追蹤任務通常建議使用「每日固定活動」會更自然。',
                        style: TextStyle(
                          fontSize: 12,
                          color: secondaryText,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('取消'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final title = titleController.text.trim();
                    final targetValue = double.tryParse(
                      targetController.text.trim(),
                    );

                    if (selectedSource == null ||
                        targetValue == null ||
                        targetValue <= 0) {
                      return;
                    }

                    final finalTitle = title.isEmpty
                        ? _autoTaskDefaultTitle(
                            selectedSource!,
                            targetController.text.trim(),
                          )
                        : title;

                    if (editingTask == null) {
                      context.read<AppState>().addTask(
                        finalTitle,
                        selectedCategory,
                        taskType: selectedTaskType,
                        dueDate: null,
                        priority: '中',
                        isAutoTracked: true,
                        sourceType: selectedSource,
                        targetValue: targetValue,
                        unitLabel: _unitLabelForSource(selectedSource),
                      );
                    } else {
                      context.read<AppState>().updateTask(
                        index: editingIndex!,
                        title: finalTitle,
                        category: selectedCategory,
                        taskType: selectedTaskType,
                        dueDate: null,
                        priority: '中',
                        isAutoTracked: true,
                        sourceType: selectedSource,
                        targetValue: targetValue,
                        unitLabel: _unitLabelForSource(selectedSource),
                      );
                    }

                    Navigator.pop(context);
                  },
                  child: Text(editingTask == null ? '新增' : '儲存'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void showEditTaskDialog({
    required int originalIndex,
    required TaskModel oldTask,
  }) {
    if (oldTask.isSystemTask) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('系統任務由自律房自動同步，不能手動編輯')));
      return;
    }

    if (oldTask.isAutoTracked) {
      _showAutoTaskDialog(editingTask: oldTask, editingIndex: originalIndex);
    } else {
      _showManualTaskDialog(editingTask: oldTask, editingIndex: originalIndex);
    }
  }

  Widget _buildSectionHeader({
    required String title,
    required int count,
    required IconData icon,
    required Color color,
  }) {
    final primaryText = AppUI.textPrimaryOf(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Text(
            '$title（$count）',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: primaryText,
            ),
          ),
        ],
      ),
    );
  }

  void _showTaskDetailSheet(TaskModel task) {
    final appState = context.read<AppState>();
    final primaryText = AppUI.textPrimaryOf(context);
    final secondaryText = AppUI.textSecondaryOf(context);
    final categoryColor = getCategoryColor(task.category);
    final priority = _priorityChinese(task);
    final priorityColor = getPriorityColor(priority);
    final potentialScore = appState.taskPotentialScoreForTask(task);
    final isDeadlineTask = task.taskType == TaskType.deadline;
    final isDeadlineReady = appState.isDeadlineTaskReady(task);
    final deadlineStatus = appState.deadlineTaskStatusForTask(task);
    final rewardReason = appState.taskRewardReasonForTask(task);
    final rewardWeight = appState.taskRewardWeightForTask(task);

    void showInfo(String title, String detail) {
      showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(detail),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('知道了'),
            ),
          ],
        ),
      );
    }

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: AppUI.softCardOf(context, categoryColor),
                      child: Icon(
                        getCategoryIcon(task.category),
                        color: categoryColor,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        task.title,
                        style: TextStyle(
                          color: primaryText,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _TaskTag(
                      text: task.category,
                      bgColor: categoryColor.withValues(alpha: 0.12),
                      textColor: categoryColor,
                    ),
                    _TaskTag(
                      text: priority,
                      bgColor: priorityColor.withValues(alpha: 0.12),
                      textColor: priorityColor,
                    ),
                    _TaskTag(
                      text: _displayTaskType(task.taskType),
                      bgColor: AppUI.isDark(context)
                          ? const Color(0xFF242A36)
                          : const Color(0xFFF3F4F6),
                      textColor: secondaryText,
                    ),
                    if (task.taskType == TaskType.deadline)
                      _TaskTag(
                        text: _displayDueDate(task.dueDate),
                        bgColor: AppUI.isDark(context)
                            ? const Color(0xFF242A36)
                            : const Color(0xFFF3F4F6),
                        textColor: secondaryText,
                      ),
                    if (task.isAutoTracked &&
                        task.sourceType != null &&
                        task.targetValue != null)
                      _TaskTag(
                        text:
                            '${TaskModel.sourceTypeToChinese(task.sourceType)} ≥ ${task.targetValue! % 1 == 0 ? task.targetValue!.toInt() : task.targetValue}${task.unitLabel ?? ''}',
                        bgColor: const Color(0xFFEFF6FF),
                        textColor: const Color(0xFF2563EB),
                        icon: Icons.auto_awesome_outlined,
                      ),
                    if (task.isSystemTask)
                      const _TaskTag(
                        text: '系統同步',
                        bgColor: Color(0xFFFFF7ED),
                        textColor: AppUI.orange,
                        icon: Icons.lock_outline,
                      ),
                  ],
                ),
                const SizedBox(height: 18),
                _DetailInfoRow(
                  icon: isDeadlineTask
                      ? Icons.monetization_on_outlined
                      : Icons.insights_outlined,
                  title: isDeadlineTask ? '到期獎勵' : '分數占比',
                  value: isDeadlineTask
                      ? '每個 +${AppState.deadlineTaskBonusCoins}，每月最多 ${AppState.deadlineTaskMonthlyCreateLimit} 個'
                      : '約 $potentialScore 分',
                  color: isDeadlineTask
                      ? AppUI.orange
                      : const Color(0xFF2563EB),
                  onTap: () => showInfo(
                    isDeadlineTask ? '截止日任務獎勵' : '是否列入今日分數',
                    isDeadlineTask
                        ? '截止日任務不列入每天分數與每日自律幣上限；每月最多建立 ${AppState.deadlineTaskMonthlyCreateLimit} 個，到期完成後每個可額外獲得 ${AppState.deadlineTaskBonusCoins} 枚自律幣。'
                        : '這個任務會列入今日加權自律分數。系統會依任務來源與權重估算完成後可推進的分數。',
                  ),
                ),
                const SizedBox(height: 10),
                _DetailInfoRow(
                  icon: Icons.scale_outlined,
                  title: '權重原因',
                  value: isDeadlineTask
                      ? rewardReason
                      : '$rewardReason · ${rewardWeight.toStringAsFixed(1)}x',
                  color: const Color(0xFF10B981),
                  onTap: () => showInfo(
                    '分數權重',
                    isDeadlineTask
                        ? '截止日任務的重點是到期驗收與額外自律幣，不會拉高每天固定分數。'
                        : '自動追蹤、健康、專注與自律房任務通常權重較高；手動日常任務權重較低，避免簡單任務過度影響分數。',
                  ),
                ),
                if (isDeadlineTask && deadlineStatus.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _DetailInfoRow(
                    icon: isDeadlineReady
                        ? Icons.check_circle_outline
                        : Icons.lock_clock_outlined,
                    title: '驗收狀態',
                    value: deadlineStatus,
                    color: isDeadlineReady
                        ? const Color(0xFF10B981)
                        : const Color(0xFFF59E0B),
                    onTap: () => showInfo(
                      '截止日規則',
                      '截止日任務需要至少提前 ${AppState.deadlineTaskMinLeadDays} 天建立，未到驗收日不會算進今日任務分母，也不能提前勾選。',
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                _DetailInfoRow(
                  icon: Icons.info_outline,
                  title: '完成方式',
                  value: task.isAutoTracked || task.isSystemTask
                      ? '由系統依資料自動判定'
                      : '由你手動勾選完成',
                  color: const Color(0xFFF59E0B),
                  onTap: () => showInfo(
                    task.isAutoTracked ? '自動追蹤來源' : '完成方式',
                    task.isAutoTracked && task.sourceType != null
                        ? '此任務會讀取 ${TaskModel.sourceTypeToChinese(task.sourceType)} 資料，達到目標值後由系統判定完成。'
                        : '這類任務沒有外部資料來源，需要由使用者自己確認完成。',
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTaskCard({
    required TaskModel task,
    required int originalIndex,
    required Color accentColor,
  }) {
    final title = task.title;
    final category = task.category;
    final isDone = task.isDone;
    final priority = _priorityChinese(task);
    final isSystemTask = task.isSystemTask;
    final isAutoTracked = task.isAutoTracked;
    final canDeleteSystemTask =
        task.title == '完成今日自律房目標' || task.title == '完成今日共讀目標';

    final categoryColor = getCategoryColor(category);
    final priorityColor = getPriorityColor(priority);
    final primaryText = AppUI.textPrimaryOf(context);
    final secondaryText = AppUI.textSecondaryOf(context);
    final appState = context.read<AppState>();
    final isDeadlineTask = task.taskType == TaskType.deadline;
    final isDeadlineReady = appState.isDeadlineTaskReady(task);
    final deadlineStatus = appState.deadlineTaskStatusForTask(task);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 180),
        opacity: isDone ? 0.78 : 1,
        child: Card(
          elevation: 0,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => _showTaskDetailSheet(task),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSystemTask
                      ? AppUI.orange.withValues(alpha: 0.28)
                      : isDone
                      ? Theme.of(context).dividerColor
                      : categoryColor.withValues(alpha: 0.18),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: categoryColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        getCategoryIcon(category),
                        color: categoryColor,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isDone ? secondaryText : primaryText,
                              decoration: isDone
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _TaskTag(
                                text: category,
                                bgColor: categoryColor.withValues(alpha: 0.12),
                                textColor: categoryColor,
                              ),
                              if (isDeadlineTask)
                                _TaskTag(
                                  text: isDeadlineReady
                                      ? '到期獎勵'
                                      : _displayDueDate(task.dueDate),
                                  bgColor: isDeadlineReady
                                      ? const Color(0xFFFFF7ED)
                                      : const Color(0xFFF3F4F6),
                                  textColor: isDeadlineReady
                                      ? AppUI.orange
                                      : secondaryText,
                                  icon: isDeadlineReady
                                      ? Icons.monetization_on_outlined
                                      : Icons.lock_clock_outlined,
                                ),
                              if (isAutoTracked || isSystemTask)
                                _TaskTag(
                                  text: '自動判定',
                                  bgColor: const Color(0xFFE8F7EC),
                                  textColor: const Color(0xFF16A34A),
                                  icon: Icons.auto_awesome_outlined,
                                )
                              else
                                _TaskTag(
                                  text: priority,
                                  bgColor: priorityColor.withValues(
                                    alpha: 0.12,
                                  ),
                                  textColor: priorityColor,
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (isDeadlineTask && deadlineStatus.isNotEmpty) ...[
                            Text(
                              deadlineStatus,
                              style: TextStyle(
                                fontSize: 12,
                                height: 1.35,
                                color: isDeadlineReady
                                    ? AppUI.orange
                                    : secondaryText,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                          if (!isSystemTask || canDeleteSystemTask)
                            Row(
                              children: [
                                if (!isSystemTask) ...[
                                  _ActionTextButton(
                                    icon: Icons.edit_outlined,
                                    label: '編輯',
                                    onTap: () {
                                      showEditTaskDialog(
                                        originalIndex: originalIndex,
                                        oldTask: task,
                                      );
                                    },
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                _ActionTextButton(
                                  icon: Icons.delete_outline,
                                  label: '刪除',
                                  onTap: () {
                                    showDeleteDialog(originalIndex, title);
                                  },
                                ),
                              ],
                            )
                          else
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: AppUI.orange.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.info_outline,
                                    size: 16,
                                    color: AppUI.orange,
                                  ),
                                  const SizedBox(width: 6),
                                  const Text(
                                    '由自律房自動同步',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppUI.orange,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Transform.scale(
                      scale: 1.06,
                      child: Checkbox(
                        activeColor: accentColor,
                        value: isDone,
                        onChanged:
                            isAutoTracked ||
                                isSystemTask ||
                                (isDeadlineTask && !isDeadlineReady)
                            ? null
                            : (value) {
                                final appState = context.read<AppState>();
                                final beforeScore =
                                    appState.todayWeightedDisciplineScore;
                                final beforeCoins = appState.disciplineCoins;
                                appState.toggleTask(
                                  originalIndex,
                                  value ?? false,
                                );
                                final afterScore =
                                    appState.todayWeightedDisciplineScore;
                                final afterCoins = appState.disciplineCoins;
                                final scoreDelta = afterScore - beforeScore;
                                final coinDelta = afterCoins - beforeCoins;

                                if ((value ?? false) &&
                                    (scoreDelta > 0 || coinDelta > 0)) {
                                  final coinText = coinDelta > 0
                                      ? '，獲得 +$coinDelta 自律幣'
                                      : '';
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        '自律分數 +$scoreDelta$coinText',
                                      ),
                                    ),
                                  );
                                }
                              },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final accentColor = appState.currentIconColor;
    final secondaryText = AppUI.textSecondaryOf(context);

    final allTasks = appState.taskModels;
    final todayTasks = appState.todayActionableTaskModels;
    final filteredTasks = getFilteredTasks(allTasks);
    final sortedTasks = getSortedTasks(filteredTasks);
    final completedCount = appState.todayActionableTaskCompleted;
    final autoCount = allTasks.where((task) => task.isAutoTracked).length;
    final deadlineCount = allTasks
        .where((task) => task.taskType == TaskType.deadline)
        .length;
    final progress = todayTasks.isEmpty
        ? 0.0
        : completedCount / todayTasks.length;
    final weightedScore = appState.todayWeightedDisciplineScore;
    final nextMilestone = appState.nextScoreCoinMilestone;
    final priorityTasks = sortedTasks
        .where(
          (task) =>
              _isPriorityTask(task) &&
              !task.isDone &&
              !(task.taskType == TaskType.deadline &&
                  !appState.isDeadlineTaskReady(task)),
        )
        .toList();

    final normalTasks = sortedTasks
        .where(
          (task) =>
              !_isPriorityTask(task) &&
              !task.isDone &&
              !(task.taskType == TaskType.deadline &&
                  !appState.isDeadlineTaskReady(task)),
        )
        .toList();

    final waitingDeadlineTasks = sortedTasks
        .where(
          (task) =>
              task.taskType == TaskType.deadline &&
              !task.isDone &&
              !appState.isDeadlineTaskReady(task),
        )
        .toList();

    final completedTasks = sortedTasks.where((task) => task.isDone).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('任務管理')),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            padding: const EdgeInsets.all(18),
            decoration: AppUI.heroGradient(accentColor),
            child: Row(
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.checklist_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '今日任務進度',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '$completedCount / ${todayTasks.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        nextMilestone == null
                            ? '加權自律分數 $weightedScore 分，已達今日最高門檻'
                            : '加權自律分數 $weightedScore 分，下一檻 $nextMilestone 分',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 10,
                          backgroundColor: Colors.white24,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 48,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemBuilder: (context, index) {
                final mode = viewModes[index];
                final count = switch (mode) {
                  '自動追蹤' => autoCount,
                  '截止日' => deadlineCount,
                  '已完成' => completedCount,
                  _ => allTasks.length - completedCount,
                };
                return ChoiceChip(
                  label: Text('$mode $count'),
                  selected: selectedViewMode == mode,
                  onSelected: (_) {
                    setState(() {
                      selectedViewMode = mode;
                    });
                  },
                );
              },
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemCount: viewModes.length,
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: selectedFilter,
                    decoration: const InputDecoration(
                      labelText: '分類',
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(),
                    ),
                    items: filters
                        .map(
                          (filter) => DropdownMenuItem(
                            value: filter,
                            child: Text(filter),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        selectedFilter = value;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: selectedSort,
                    decoration: const InputDecoration(
                      labelText: '排序',
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(),
                    ),
                    items: sortOptions
                        .map(
                          (option) => DropdownMenuItem(
                            value: option,
                            child: Text(option),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        selectedSort = value;
                      });
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
              children: [
                if (priorityTasks.isNotEmpty) ...[
                  _buildSectionHeader(
                    title: '優先處理',
                    count: priorityTasks.length,
                    icon: Icons.priority_high_rounded,
                    color: const Color(0xFFEF4444),
                  ),
                  ...priorityTasks.map(
                    (task) => _buildTaskCard(
                      task: task,
                      originalIndex: allTasks.indexOf(task),
                      accentColor: accentColor,
                    ),
                  ),
                ],
                if (normalTasks.isNotEmpty) ...[
                  _buildSectionHeader(
                    title: '進行中',
                    count: normalTasks.length,
                    icon: Icons.pending_actions_outlined,
                    color: accentColor,
                  ),
                  ...normalTasks.map(
                    (task) => _buildTaskCard(
                      task: task,
                      originalIndex: allTasks.indexOf(task),
                      accentColor: accentColor,
                    ),
                  ),
                ],
                if (waitingDeadlineTasks.isNotEmpty) ...[
                  _buildSectionHeader(
                    title: '等待驗收',
                    count: waitingDeadlineTasks.length,
                    icon: Icons.lock_clock_outlined,
                    color: AppUI.orange,
                  ),
                  ...waitingDeadlineTasks.map(
                    (task) => _buildTaskCard(
                      task: task,
                      originalIndex: allTasks.indexOf(task),
                      accentColor: accentColor,
                    ),
                  ),
                ],
                if (completedTasks.isNotEmpty) ...[
                  _buildSectionHeader(
                    title: '已完成',
                    count: completedTasks.length,
                    icon: Icons.check_circle_outline,
                    color: const Color(0xFF16A34A),
                  ),
                  ...completedTasks.map(
                    (task) => _buildTaskCard(
                      task: task,
                      originalIndex: allTasks.indexOf(task),
                      accentColor: accentColor,
                    ),
                  ),
                ],
                if (sortedTasks.isEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        selectedFilter == '全部'
                            ? '目前還沒有任務，先新增一個吧。'
                            : '這個分類目前沒有任務。',
                        style: TextStyle(color: secondaryText, fontSize: 14),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null,
        onPressed: showAddTaskDialog,
        backgroundColor: accentColor.withValues(alpha: 0.18),
        foregroundColor: accentColor,
        icon: const Icon(Icons.add),
        label: const Text('新增任務'),
      ),
    );
  }
}

class _TaskTypePickerSheet extends StatelessWidget {
  final VoidCallback onDailyTap;
  final VoidCallback onDeadlineTap;
  final VoidCallback onAutoTap;

  const _TaskTypePickerSheet({
    required this.onDailyTap,
    required this.onDeadlineTap,
    required this.onAutoTap,
  });

  @override
  Widget build(BuildContext context) {
    final primaryText = AppUI.textPrimaryOf(context);
    final secondaryText = AppUI.textSecondaryOf(context);
    final cardColor = Theme.of(context).cardColor;

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42,
                height: 5,
                decoration: BoxDecoration(
                  color: Theme.of(context).dividerColor,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                '新增任務',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: primaryText,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '先選任務來源，下一步再補名稱與目標。',
                style: TextStyle(fontSize: 14, color: secondaryText),
              ),
              const SizedBox(height: 18),
              _PickerCard(
                title: '每日固定活動',
                subtitle: '喝水、家事、整理房間等每天可以自己勾選的習慣。',
                icon: Icons.edit_note_outlined,
                color: const Color(0xFF7C6AE6),
                backgroundColor: cardColor,
                onTap: onDailyTap,
              ),
              const SizedBox(height: 12),
              _PickerCard(
                title: '有截止日任務',
                subtitle: '報告、作業、考試準備等需要在指定日期前完成的任務。',
                icon: Icons.event_available_outlined,
                color: const Color(0xFFF59E0B),
                backgroundColor: cardColor,
                onTap: onDeadlineTap,
              ),
              const SizedBox(height: 12),
              _PickerCard(
                title: '自動追蹤任務',
                subtitle: '專注、睡眠、步數、運動，由系統依資料自動判定完成。',
                icon: Icons.auto_awesome_outlined,
                color: const Color(0xFF4F8CFF),
                backgroundColor: cardColor,
                onTap: onAutoTap,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PickerCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final Color backgroundColor;
  final VoidCallback onTap;

  const _PickerCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.backgroundColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final primaryText = AppUI.textPrimaryOf(context);
    final secondaryText = AppUI.textSecondaryOf(context);

    return Material(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: primaryText,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.45,
                        color: secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.arrow_forward_ios, size: 16, color: secondaryText),
            ],
          ),
        ),
      ),
    );
  }
}

class _TaskFlowStepper extends StatelessWidget {
  final int currentStep;
  final Color accentColor;

  const _TaskFlowStepper({
    required this.currentStep,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final labels = const ['填目標', '設規則', '看獎勵'];
    final secondaryText = AppUI.textSecondaryOf(context);

    return Row(
      children: List.generate(labels.length, (index) {
        final selected = currentStep == index;
        final done = currentStep > index;
        final color = selected || done ? accentColor : secondaryText;

        return Expanded(
          child: Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: selected
                        ? accentColor.withValues(
                            alpha: AppUI.isDark(context) ? 0.24 : 0.12,
                          )
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(AppUI.radiusPill),
                    border: Border.all(
                      color: selected
                          ? accentColor
                          : Theme.of(context).dividerColor,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        done ? Icons.check_circle : Icons.circle_outlined,
                        color: color,
                        size: 15,
                      ),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          labels[index],
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: color,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (index != labels.length - 1) const SizedBox(width: 6),
            ],
          ),
        );
      }),
    );
  }
}

class _TaskRewardPreviewCard extends StatelessWidget {
  final TaskModel task;
  final int potentialScore;
  final String reason;
  final Color accentColor;
  final String dueDateText;

  const _TaskRewardPreviewCard({
    required this.task,
    required this.potentialScore,
    required this.reason,
    required this.accentColor,
    required this.dueDateText,
  });

  @override
  Widget build(BuildContext context) {
    final primaryText = AppUI.textPrimaryOf(context);
    final secondaryText = AppUI.textSecondaryOf(context);
    final isDeadline = task.taskType == TaskType.deadline;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: AppUI.softCardOf(context, accentColor),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.receipt_long_outlined, color: accentColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '任務預覽',
                  style: TextStyle(
                    color: primaryText,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            task.title,
            style: TextStyle(
              color: primaryText,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _PreviewPill(text: task.category, color: accentColor),
              _PreviewPill(
                text: isDeadline ? '截止日任務' : '每日固定',
                color: isDeadline ? AppUI.orange : AppUI.green,
              ),
              _PreviewPill(text: dueDateText, color: AppUI.blue),
              _PreviewPill(
                text: isDeadline ? '額外自律幣' : '約 $potentialScore 分',
                color: AppUI.purple,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            isDeadline ? '截止日任務不進入每日分數權重，到期完成後會走額外自律幣獎勵。' : reason,
            style: TextStyle(
              color: secondaryText,
              fontSize: 13,
              height: 1.45,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewPill extends StatelessWidget {
  final String text;
  final Color color;

  const _PreviewPill({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: AppUI.softCardOf(context, color),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _FormSectionTitle extends StatelessWidget {
  final String title;
  final Color color;

  const _FormSectionTitle({required this.title, required this.color});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }
}

class _SegmentChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color accentColor;
  final VoidCallback onTap;

  const _SegmentChip({
    required this.label,
    required this.selected,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final primaryText = AppUI.textPrimaryOf(context);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? accentColor : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? accentColor : Theme.of(context).dividerColor,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: selected ? Colors.white : primaryText,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _AutoSourceChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _AutoSourceChip({
    required this.icon,
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final primaryText = AppUI.textPrimaryOf(context);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 110,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: 0.14)
              : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? color : Theme.of(context).dividerColor,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: selected ? color : primaryText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FixedSourceCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;

  const _FixedSourceCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final primaryText = AppUI.textPrimaryOf(context);
    final secondaryText = AppUI.textSecondaryOf(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.38)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: primaryText,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.35,
                    color: secondaryText,
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

class _TaskTag extends StatelessWidget {
  final String text;
  final Color bgColor;
  final Color textColor;
  final IconData? icon;

  const _TaskTag({
    required this.text,
    required this.bgColor,
    required this.textColor,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 170),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: textColor),
            const SizedBox(width: 5),
          ],
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailInfoRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color color;
  final VoidCallback? onTap;

  const _DetailInfoRow({
    required this.icon,
    required this.title,
    required this.value,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final primaryText = AppUI.textPrimaryOf(context);
    final secondaryText = AppUI.textSecondaryOf(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppUI.radiusCard),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.all(12),
          decoration: AppUI.softCardOf(context, color),
          child: Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: secondaryText,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Flexible(
                child: Text(
                  value,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: primaryText,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (onTap != null) ...[
                const SizedBox(width: 6),
                Icon(Icons.info_outline, color: color, size: 16),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionTextButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionTextButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final secondary = AppUI.textSecondaryOf(context);

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: secondary),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: secondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
