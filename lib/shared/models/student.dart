import 'package:kabinet/shared/models/base_model.dart';

/// Ученик
class Student extends BaseModel {
  final String institutionId;
  final String name;
  final String? phone;
  final String? comment;
  final int prepaidLessonsCount;

  /// Остаток занятий из другой школы (при переносе ученика)
  /// Списывается в первую очередь, не влияет на статистику доходов
  final int legacyBalance;

  /// ID учеников, из которых была создана эта карточка при объединении
  final List<String>? mergedFrom;

  const Student({
    required super.id,
    required super.createdAt,
    required super.updatedAt,
    super.archivedAt,
    required this.institutionId,
    required this.name,
    this.phone,
    this.comment,
    this.prepaidLessonsCount = 0,
    this.legacyBalance = 0,
    this.mergedFrom,
  });

  /// Общий баланс занятий (алиас для prepaidLessonsCount)
  int get balance => prepaidLessonsCount;

  /// Баланс только из абонементов (без legacy)
  int get subscriptionBalance => prepaidLessonsCount - legacyBalance;

  /// Есть ли долг (отрицательный баланс)
  bool get hasDebt => prepaidLessonsCount < 0;

  /// Есть ли остаток из другой школы
  bool get hasLegacyBalance => legacyBalance > 0;

  /// Это групповая карточка (объединённая из нескольких учеников)
  bool get isMerged => mergedFrom != null && mergedFrom!.isNotEmpty;

  /// Количество занятий для отображения (с учётом знака)
  String get prepaidDisplay => prepaidLessonsCount >= 0
      ? '$prepaidLessonsCount'
      : '$prepaidLessonsCount';

  factory Student.fromJson(Map<String, dynamic> json) => Student(
        id: json['id'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
        archivedAt: json['archived_at'] != null
            ? DateTime.parse(json['archived_at'] as String)
            : null,
        institutionId: json['institution_id'] as String,
        name: json['name'] as String,
        phone: json['phone'] as String?,
        comment: json['comment'] as String?,
        prepaidLessonsCount: json['prepaid_lessons_count'] as int? ?? 0,
        legacyBalance: json['legacy_balance'] as int? ?? 0,
        mergedFrom: (json['merged_from'] as List<dynamic>?)
            ?.map((e) => e as String)
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'institution_id': institutionId,
        'name': name,
        'phone': phone,
        'comment': comment,
        'legacy_balance': legacyBalance,
      };

  Student copyWith({
    String? name,
    String? phone,
    String? comment,
    int? prepaidLessonsCount,
    int? legacyBalance,
    List<String>? mergedFrom,
  }) =>
      Student(
        id: id,
        createdAt: createdAt,
        updatedAt: updatedAt,
        archivedAt: archivedAt,
        institutionId: institutionId,
        name: name ?? this.name,
        phone: phone ?? this.phone,
        comment: comment ?? this.comment,
        prepaidLessonsCount: prepaidLessonsCount ?? this.prepaidLessonsCount,
        legacyBalance: legacyBalance ?? this.legacyBalance,
        mergedFrom: mergedFrom ?? this.mergedFrom,
      );
}
