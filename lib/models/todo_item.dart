/// 待办事项数据模型
class TodoItem {
  final int? id;
  final String title;
  final String? description;
  final DateTime createdAt;
  final DateTime? dueDate;
  final bool isCompleted;
  final DateTime? completedAt;
  final int? visitRecordId; // 关联的拜访记录ID

  TodoItem({
    this.id,
    required this.title,
    this.description,
    DateTime? createdAt,
    this.dueDate,
    this.isCompleted = false,
    this.completedAt,
    this.visitRecordId,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'title': title,
      'description': description,
      'created_at': createdAt.toIso8601String(),
      'due_date': dueDate?.toIso8601String(),
      'is_completed': isCompleted ? 1 : 0,
      'completed_at': completedAt?.toIso8601String(),
      'visit_record_id': visitRecordId,
    };
  }

  factory TodoItem.fromMap(Map<String, dynamic> map) {
    return TodoItem(
      id: map['id'] as int?,
      title: map['title'] as String,
      description: map['description'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      dueDate: map['due_date'] != null
          ? DateTime.parse(map['due_date'] as String)
          : null,
      isCompleted: (map['is_completed'] as int) == 1,
      completedAt: map['completed_at'] != null
          ? DateTime.parse(map['completed_at'] as String)
          : null,
      visitRecordId: map['visit_record_id'] as int?,
    );
  }

  TodoItem copyWith({
    int? id,
    String? title,
    String? description,
    DateTime? createdAt,
    DateTime? dueDate,
    bool? isCompleted,
    DateTime? completedAt,
    int? visitRecordId,
  }) {
    return TodoItem(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      dueDate: dueDate ?? this.dueDate,
      isCompleted: isCompleted ?? this.isCompleted,
      completedAt: completedAt ?? this.completedAt,
      visitRecordId: visitRecordId ?? this.visitRecordId,
    );
  }
}