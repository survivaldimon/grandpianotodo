import 'package:kabinet/l10n/app_localizations.dart';
import 'package:kabinet/shared/models/payment.dart';
import 'package:kabinet/shared/models/student.dart';

/// Статус подписки (абонемента)
enum SubscriptionStatus {
  active,    // Активный
  frozen,    // Заморожен
  expired,   // Истёк срок
  exhausted, // Занятия закончились
}

/// Участник семейного абонемента
class SubscriptionMember {
  final String id;
  final String subscriptionId;
  final String studentId;
  final DateTime createdAt;
  final Student? student;

  const SubscriptionMember({
    required this.id,
    required this.subscriptionId,
    required this.studentId,
    required this.createdAt,
    this.student,
  });

  factory SubscriptionMember.fromJson(Map<String, dynamic> json) =>
      SubscriptionMember(
        id: json['id'] as String,
        subscriptionId: json['subscription_id'] as String,
        studentId: json['student_id'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
        student: json['students'] != null
            ? Student.fromJson(json['students'] as Map<String, dynamic>)
            : null,
      );

  Map<String, dynamic> toJson() => {
        'subscription_id': subscriptionId,
        'student_id': studentId,
      };
}

/// Абонемент студента
class Subscription {
  final String id;
  final String institutionId;
  final String? studentId; // nullable для семейных абонементов
  final String? paymentId;

  /// Занятия
  final int lessonsTotal;
  final int lessonsRemaining;

  /// Сроки действия
  final DateTime startsAt;
  final DateTime expiresAt;

  /// Заморозка
  final bool isFrozen;
  final DateTime? frozenUntil;
  final int frozenDaysTotal;

  /// Семейный абонемент
  final bool isFamily;

  /// Метаданные
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Связанные объекты (join)
  final Student? student;
  final Payment? payment;
  final List<SubscriptionMember>? members; // Участники семейного абонемента

  const Subscription({
    required this.id,
    required this.institutionId,
    this.studentId,
    this.paymentId,
    required this.lessonsTotal,
    required this.lessonsRemaining,
    required this.startsAt,
    required this.expiresAt,
    this.isFrozen = false,
    this.frozenUntil,
    this.frozenDaysTotal = 0,
    this.isFamily = false,
    required this.createdAt,
    required this.updatedAt,
    this.student,
    this.payment,
    this.members,
  });

  /// Использованные занятия
  int get lessonsUsed => lessonsTotal - lessonsRemaining;

  /// Процент использования
  double get usagePercent => lessonsTotal > 0 ? lessonsUsed / lessonsTotal : 0;

  /// Дней до истечения
  int get daysUntilExpiration {
    if (isFrozen) return -1; // Заморозка - срок не идёт
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final expiry = DateTime(expiresAt.year, expiresAt.month, expiresAt.day);
    return expiry.difference(today).inDays;
  }

  /// Дней до разморозки
  int get daysUntilUnfreeze {
    if (!isFrozen || frozenUntil == null) return 0;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final until = DateTime(frozenUntil!.year, frozenUntil!.month, frozenUntil!.day);
    return until.difference(today).inDays;
  }

  /// Статус подписки
  SubscriptionStatus get status {
    if (isFrozen) return SubscriptionStatus.frozen;
    if (lessonsRemaining <= 0) return SubscriptionStatus.exhausted;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final expiry = DateTime(expiresAt.year, expiresAt.month, expiresAt.day);

    if (expiry.isBefore(today)) return SubscriptionStatus.expired;
    return SubscriptionStatus.active;
  }

  /// Активна ли подписка (можно списывать занятия)
  bool get isActive => status == SubscriptionStatus.active;

  /// Истекает ли скоро (в течение 7 дней)
  bool get isExpiringSoon {
    if (status != SubscriptionStatus.active) return false;
    return daysUntilExpiration <= 7 && daysUntilExpiration >= 0;
  }

  /// Строковое представление статуса (устаревший, используйте getLocalizedStatusName)
  @Deprecated('Use getLocalizedStatusName(l10n) instead')
  String get statusDisplayName {
    switch (status) {
      case SubscriptionStatus.active:
        return 'Активен';
      case SubscriptionStatus.frozen:
        return 'Заморожен';
      case SubscriptionStatus.expired:
        return 'Истёк';
      case SubscriptionStatus.exhausted:
        return 'Исчерпан';
    }
  }

  /// Локализованное строковое представление статуса
  String getLocalizedStatusName(AppLocalizations l10n) {
    switch (status) {
      case SubscriptionStatus.active:
        return l10n.statusActive;
      case SubscriptionStatus.frozen:
        return l10n.statusFrozen;
      case SubscriptionStatus.expired:
        return l10n.statusExpired;
      case SubscriptionStatus.exhausted:
        return l10n.statusExhausted;
    }
  }

  /// Название тарифа (если есть)
  String? get paymentPlanName => payment?.paymentPlan?.name;

  /// Это семейный абонемент?
  bool get isFamilySubscription => isFamily || (members != null && members!.length > 1);

  /// Получить всех участников семейного абонемента
  List<Student> get memberStudents {
    if (members == null || members!.isEmpty) {
      return student != null ? [student!] : [];
    }
    return members!
        .where((m) => m.student != null)
        .map((m) => m.student!)
        .toList();
  }

  /// Имена всех участников через запятую
  String get displayMemberNames {
    final students = memberStudents;
    if (students.isEmpty) return student?.name ?? '';
    return students.map((s) => s.name).join(', ');
  }

  /// Количество участников
  int get memberCount => members?.length ?? (studentId != null ? 1 : 0);

  factory Subscription.fromJson(Map<String, dynamic> json) => Subscription(
        id: json['id'] as String,
        institutionId: json['institution_id'] as String,
        studentId: json['student_id'] as String?,
        paymentId: json['payment_id'] as String?,
        lessonsTotal: json['lessons_total'] as int,
        lessonsRemaining: json['lessons_remaining'] as int,
        startsAt: DateTime.parse(json['starts_at'] as String),
        expiresAt: DateTime.parse(json['expires_at'] as String),
        isFrozen: json['is_frozen'] as bool? ?? false,
        frozenUntil: json['frozen_until'] != null
            ? DateTime.parse(json['frozen_until'] as String)
            : null,
        frozenDaysTotal: json['frozen_days_total'] as int? ?? 0,
        isFamily: json['is_family'] as bool? ?? false,
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
        student: json['students'] != null
            ? Student.fromJson(json['students'] as Map<String, dynamic>)
            : null,
        payment: json['payments'] != null
            ? Payment.fromJson(json['payments'] as Map<String, dynamic>)
            : null,
        members: json['subscription_members'] != null
            ? (json['subscription_members'] as List)
                .map((m) => SubscriptionMember.fromJson(m as Map<String, dynamic>))
                .toList()
            : null,
      );

  Map<String, dynamic> toJson() => {
        'institution_id': institutionId,
        'student_id': studentId,
        'payment_id': paymentId,
        'lessons_total': lessonsTotal,
        'lessons_remaining': lessonsRemaining,
        'starts_at': startsAt.toIso8601String().split('T').first,
        'expires_at': expiresAt.toIso8601String().split('T').first,
        'is_frozen': isFrozen,
        'frozen_until': frozenUntil?.toIso8601String().split('T').first,
        'frozen_days_total': frozenDaysTotal,
        'is_family': isFamily,
      };

  Subscription copyWith({
    int? lessonsRemaining,
    DateTime? expiresAt,
    bool? isFrozen,
    DateTime? frozenUntil,
    int? frozenDaysTotal,
    bool? isFamily,
    List<SubscriptionMember>? members,
  }) =>
      Subscription(
        id: id,
        institutionId: institutionId,
        studentId: studentId,
        paymentId: paymentId,
        lessonsTotal: lessonsTotal,
        lessonsRemaining: lessonsRemaining ?? this.lessonsRemaining,
        startsAt: startsAt,
        expiresAt: expiresAt ?? this.expiresAt,
        isFrozen: isFrozen ?? this.isFrozen,
        frozenUntil: frozenUntil ?? this.frozenUntil,
        frozenDaysTotal: frozenDaysTotal ?? this.frozenDaysTotal,
        isFamily: isFamily ?? this.isFamily,
        createdAt: createdAt,
        updatedAt: updatedAt,
        student: student,
        payment: payment,
        members: members ?? this.members,
      );
}

/// Сводка по подпискам студента
class StudentSubscriptionSummary {
  final String studentId;
  final String studentName;
  final int activeBalance;      // Активные занятия
  final int expiredBalance;     // Истёкшие занятия
  final DateTime? nearestExpiration; // Ближайшая дата истечения
  final bool hasFrozenSubscription;  // Есть ли замороженные

  const StudentSubscriptionSummary({
    required this.studentId,
    required this.studentName,
    required this.activeBalance,
    required this.expiredBalance,
    this.nearestExpiration,
    required this.hasFrozenSubscription,
  });

  /// Общий баланс (активные + истёкшие)
  int get totalBalance => activeBalance + expiredBalance;

  /// Есть ли истёкшие занятия
  bool get hasExpiredLessons => expiredBalance > 0;

  /// Скоро ли истекает (в течение 7 дней)
  bool get isExpiringSoon {
    if (nearestExpiration == null || activeBalance <= 0) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final expiry = DateTime(nearestExpiration!.year, nearestExpiration!.month, nearestExpiration!.day);
    final days = expiry.difference(today).inDays;
    return days <= 7 && days >= 0;
  }

  factory StudentSubscriptionSummary.fromJson(Map<String, dynamic> json) =>
      StudentSubscriptionSummary(
        studentId: json['student_id'] as String,
        studentName: json['student_name'] as String,
        activeBalance: json['active_balance'] as int? ?? 0,
        expiredBalance: json['expired_balance'] as int? ?? 0,
        nearestExpiration: json['nearest_expiration'] != null
            ? DateTime.parse(json['nearest_expiration'] as String)
            : null,
        hasFrozenSubscription: json['has_frozen_subscription'] as bool? ?? false,
      );
}
