enum TaskType { fixed, deadline }

enum TaskPriority { high, medium, low }

enum TaskSourceType {
  manual,
  focusMinutes,
  sleepHours,
  steps,
  exerciseMinutes,
  studyRoom,
  system,
}

class TaskModel {
  final String id;
  final String userId;
  final String title;
  final String category;
  final TaskType taskType;
  final TaskPriority priority;
  final DateTime? dueDate;
  final bool isDone;
  final bool isSystemTask;
  final bool isAutoTracked;
  final TaskSourceType? sourceType;
  final double? targetValue;
  final String? unitLabel;
  final String? sourceId;
  final bool resetDaily;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? completedAt;

  const TaskModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.category,
    required this.taskType,
    required this.priority,
    this.dueDate,
    this.isDone = false,
    this.isSystemTask = false,
    this.isAutoTracked = false,
    this.sourceType,
    this.targetValue,
    this.unitLabel,
    this.sourceId,
    this.resetDaily = false,
    required this.createdAt,
    required this.updatedAt,
    this.completedAt,
  });

  TaskModel copyWith({
    String? id,
    String? userId,
    String? title,
    String? category,
    TaskType? taskType,
    TaskPriority? priority,
    DateTime? dueDate,
    bool clearDueDate = false,
    bool? isDone,
    bool? isSystemTask,
    bool? isAutoTracked,
    TaskSourceType? sourceType,
    bool clearSourceType = false,
    double? targetValue,
    bool clearTargetValue = false,
    String? unitLabel,
    bool clearUnitLabel = false,
    String? sourceId,
    bool clearSourceId = false,
    bool? resetDaily,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? completedAt,
    bool clearCompletedAt = false,
  }) {
    return TaskModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      category: category ?? this.category,
      taskType: taskType ?? this.taskType,
      priority: priority ?? this.priority,
      dueDate: clearDueDate ? null : (dueDate ?? this.dueDate),
      isDone: isDone ?? this.isDone,
      isSystemTask: isSystemTask ?? this.isSystemTask,
      isAutoTracked: isAutoTracked ?? this.isAutoTracked,
      sourceType: clearSourceType ? null : (sourceType ?? this.sourceType),
      targetValue: clearTargetValue ? null : (targetValue ?? this.targetValue),
      unitLabel: clearUnitLabel ? null : (unitLabel ?? this.unitLabel),
      sourceId: clearSourceId ? null : (sourceId ?? this.sourceId),
      resetDaily: resetDaily ?? this.resetDaily,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      completedAt: clearCompletedAt ? null : (completedAt ?? this.completedAt),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'title': title,
      'category': category,
      'taskType': taskType.name,
      'priority': priority.name,
      'dueDate': dueDate?.toIso8601String(),
      'isDone': isDone,
      'isSystemTask': isSystemTask,
      'isAutoTracked': isAutoTracked,
      'sourceType': sourceType?.name,
      'targetValue': targetValue,
      'unitLabel': unitLabel,
      'sourceId': sourceId,
      'resetDaily': resetDaily,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
    };
  }

  factory TaskModel.fromJson(Map<String, dynamic> json) {
    final taskTypeRaw = json['taskType'] as String? ?? 'fixed';
    final priorityRaw = json['priority'] as String? ?? 'medium';
    final sourceTypeRaw = json['sourceType'] as String?;

    return TaskModel(
      id: json['id'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      title: json['title'] as String? ?? '',
      category: json['category'] as String? ?? '自定義',
      taskType: TaskType.values.firstWhere(
        (e) => e.name == taskTypeRaw,
        orElse: () => TaskType.fixed,
      ),
      priority: TaskPriority.values.firstWhere(
        (e) => e.name == priorityRaw,
        orElse: () => TaskPriority.medium,
      ),
      dueDate: json['dueDate'] == null
          ? null
          : DateTime.tryParse(json['dueDate'] as String),
      isDone: json['isDone'] as bool? ?? false,
      isSystemTask: json['isSystemTask'] as bool? ?? false,
      isAutoTracked: json['isAutoTracked'] as bool? ?? false,
      sourceType: sourceTypeRaw == null
          ? null
          : TaskSourceType.values.firstWhere(
              (e) => e.name == sourceTypeRaw,
              orElse: () => TaskSourceType.manual,
            ),
      targetValue: (json['targetValue'] as num?)?.toDouble(),
      unitLabel: json['unitLabel'] as String?,
      sourceId: json['sourceId'] as String?,
      resetDaily: json['resetDaily'] as bool? ?? false,
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      updatedAt:
          DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.now(),
      completedAt: json['completedAt'] == null
          ? null
          : DateTime.tryParse(json['completedAt'] as String),
    );
  }

  static TaskPriority priorityFromChinese(String value) {
    switch (value) {
      case '高':
        return TaskPriority.high;
      case '低':
        return TaskPriority.low;
      case '中':
      default:
        return TaskPriority.medium;
    }
  }

  static String priorityToChinese(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.high:
        return '高';
      case TaskPriority.medium:
        return '中';
      case TaskPriority.low:
        return '低';
    }
  }

  static TaskType taskTypeFromString(String value) {
    switch (value) {
      case 'deadline':
        return TaskType.deadline;
      case 'fixed':
      default:
        return TaskType.fixed;
    }
  }

  static String taskTypeToStringValue(TaskType type) {
    return type.name;
  }

  static String sourceTypeToChinese(TaskSourceType? type) {
    switch (type) {
      case TaskSourceType.focusMinutes:
        return '專注';
      case TaskSourceType.sleepHours:
        return '睡眠';
      case TaskSourceType.steps:
        return '步數';
      case TaskSourceType.exerciseMinutes:
        return '運動';
      case TaskSourceType.studyRoom:
        return '自律房';
      case TaskSourceType.system:
        return '系統';
      case TaskSourceType.manual:
      case null:
        return '手動';
    }
  }
}
