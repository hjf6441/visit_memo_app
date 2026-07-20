/// 拜访记录数据模型
class VisitRecord {
  final int? id;
  final DateTime visitTime;
  final List<String> participants;
  final String? contactPerson; // 拜访对象姓名
  final String? contactCompany; // 拜访对象单位
  final String? summary; // 谈话内容摘要
  final String? fullTranscript; // 完整语音转文字原文
  final String result; // 结果：达成意向/需跟进/未果/待补充
  final DateTime createdAt;
  final List<String>? keyPoints; // 关键句

  VisitRecord({
    this.id,
    required this.visitTime,
    this.participants = const [],
    this.contactPerson,
    this.contactCompany,
    this.summary,
    this.fullTranscript,
    this.result = '待补充',
    DateTime? createdAt,
    this.keyPoints,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'visit_time': visitTime.toIso8601String(),
      'participants': participants.join(';'),
      'contact_person': contactPerson,
      'contact_company': contactCompany,
      'summary': summary,
      'full_transcript': fullTranscript,
      'result': result,
      'created_at': createdAt.toIso8601String(),
      'key_points': keyPoints?.join(';'),
    };
  }

  factory VisitRecord.fromMap(Map<String, dynamic> map) {
    return VisitRecord(
      id: map['id'] as int?,
      visitTime: DateTime.parse(map['visit_time'] as String),
      participants: (map['participants'] as String?)?.isNotEmpty == true
          ? (map['participants'] as String).split(';')
          : [],
      contactPerson: map['contact_person'] as String?,
      contactCompany: map['contact_company'] as String?,
      summary: map['summary'] as String?,
      fullTranscript: map['full_transcript'] as String?,
      result: map['result'] as String? ?? '待补充',
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : DateTime.now(),
      keyPoints: (map['key_points'] as String?)?.isNotEmpty == true
          ? (map['key_points'] as String).split(';')
          : [],
    );
  }

  VisitRecord copyWith({
    int? id,
    DateTime? visitTime,
    List<String>? participants,
    String? contactPerson,
    String? contactCompany,
    String? summary,
    String? fullTranscript,
    String? result,
    DateTime? createdAt,
    List<String>? keyPoints,
  }) {
    return VisitRecord(
      id: id ?? this.id,
      visitTime: visitTime ?? this.visitTime,
      participants: participants ?? this.participants,
      contactPerson: contactPerson ?? this.contactPerson,
      contactCompany: contactCompany ?? this.contactCompany,
      summary: summary ?? this.summary,
      fullTranscript: fullTranscript ?? this.fullTranscript,
      result: result ?? this.result,
      createdAt: createdAt ?? this.createdAt,
      keyPoints: keyPoints ?? this.keyPoints,
    );
  }

  /// 格式化的参与人员字符串
  String get participantsDisplay =>
      participants.isNotEmpty ? participants.join('、') : '未记录';

  /// 格式化的拜访对象字符串
  String get contactDisplay {
    if (contactCompany != null && contactPerson != null) {
      return '$contactCompany $contactPerson';
    } else if (contactPerson != null) {
      return contactPerson!;
    } else if (contactCompany != null) {
      return contactCompany!;
    }
    return '未记录';
  }
}