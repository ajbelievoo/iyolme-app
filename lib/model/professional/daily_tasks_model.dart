class DailyTasksModel {
  DailyTasksModel({this.status, this.message, this.data});

  bool? status;
  String? message;
  List<DailyTask>? data;

  factory DailyTasksModel.fromJson(Map<String, dynamic> json) {
    final dynamic raw = json['data'] ?? json['tasks'] ?? json['daily_tasks'] ?? json['dailyTasks'];
    dynamic list = raw;
    if (raw is Map) {
      list = raw['data'] ?? raw['tasks'] ?? raw['daily_tasks'] ?? raw['dailyTasks'];
    }
    return DailyTasksModel(
      status: json['status'] as bool?,
      message: json['message'] as String?,
      data: (list as List?)
          ?.map((e) => DailyTask.fromJson((e as Map).cast<String, dynamic>()))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'status': status,
        'message': message,
        if (data != null) 'data': data!.map((e) => e.toJson()).toList(),
      };
}

class DailyTask {
  DailyTask({
    this.id,
    this.type,
    this.title,
    this.description,
    this.requiredCount,
    this.progressCount,
    this.remainingCount,
    this.points,
    this.completed,
    this.resetRule,
  });

  int? id;
  String? type;
  String? title;
  String? description;
  int? requiredCount;
  int? progressCount;
  int? remainingCount;
  int? points;
  bool? completed;
  String? resetRule;

  factory DailyTask.fromJson(Map<String, dynamic> json) {
    final required = _toInt(json['required_count'] ?? json['requiredCount'] ?? json['target']);
    final progress = _toInt(json['progress_count'] ?? json['progressCount'] ?? json['completed']);
    final remaining = _toInt(json['remaining_count'] ?? json['remainingCount']);
    final explicitCompleted = _toBool(json['completed']);
    final computedCompleted = (required > 0) && (progress >= required);
    return DailyTask(
      id: _toInt(json['id']),
      type: json['type']?.toString(),
      title: json['title']?.toString(),
      description: json['description']?.toString(),
      requiredCount: required,
      progressCount: progress,
      remainingCount: remaining,
      points: _toInt(json['points']),
      completed: explicitCompleted ?? computedCompleted,
      resetRule: json['reset_rule']?.toString() ?? json['resetRule']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'title': title,
        if (description != null) 'description': description,
        if (requiredCount != null) 'required_count': requiredCount,
        if (progressCount != null) 'progress_count': progressCount,
        if (remainingCount != null) 'remaining_count': remainingCount,
        'points': points,
        if (completed != null) 'completed': completed,
        if (resetRule != null) 'reset_rule': resetRule,
      };
}

int _toInt(dynamic v) {
  if (v == null) return 0;
  if (v is int) return v;
  return int.tryParse('$v') ?? 0;
}

bool? _toBool(dynamic v) {
  if (v == null) return null;
  if (v is bool) return v;
  final s = v.toString().toLowerCase();
  if (s == 'true' || s == '1') return true;
  if (s == 'false' || s == '0') return false;
  return null;
}
