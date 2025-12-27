import 'package:kabinet/shared/models/payment_plan.dart';
import 'package:kabinet/shared/models/profile.dart';
import 'package:kabinet/shared/models/student.dart';
import 'package:kabinet/shared/models/subscription.dart';

/// Оплата
class Payment {
  final String id;
  final String institutionId;
  final String studentId;
  final String? paymentPlanId;
  final double amount; // Может быть отрицательным для корректировок
  final int lessonsCount; // Может быть отрицательным для корректировок
  final bool isCorrection; // Флаг корректирующей записи
  final String? correctionReason; // Причина корректировки (обязательна если isCorrection=true)
  final DateTime paidAt;
  final String recordedBy;
  final String? comment;
  final DateTime createdAt;

  /// Связанные объекты (join)
  final Student? student;
  final PaymentPlan? paymentPlan;
  final Profile? recordedByProfile;
  final Subscription? subscription; // Подписка с участниками (для семейных)

  const Payment({
    required this.id,
    required this.institutionId,
    required this.studentId,
    this.paymentPlanId,
    required this.amount,
    required this.lessonsCount,
    this.isCorrection = false,
    this.correctionReason,
    required this.paidAt,
    required this.recordedBy,
    this.comment,
    required this.createdAt,
    this.student,
    this.paymentPlan,
    this.recordedByProfile,
    this.subscription,
  });

  /// Это семейный абонемент?
  bool get isFamilySubscription => subscription?.isFamilySubscription ?? false;

  /// Имена всех участников (для семейных абонементов)
  String get displayMemberNames {
    if (subscription != null && subscription!.isFamilySubscription) {
      return subscription!.displayMemberNames;
    }
    return student?.name ?? '';
  }

  /// Это корректирующая запись с отрицательными значениями?
  bool get isNegative => amount < 0 || lessonsCount < 0;

  factory Payment.fromJson(Map<String, dynamic> json) {
    // Подписка приходит как список (one-to-many), берём первую
    Subscription? subscription;
    final subscriptionsData = json['subscriptions'];
    if (subscriptionsData is List && subscriptionsData.isNotEmpty) {
      subscription = Subscription.fromJson(subscriptionsData.first as Map<String, dynamic>);
    }

    return Payment(
      id: json['id'] as String,
      institutionId: json['institution_id'] as String,
      studentId: json['student_id'] as String,
      paymentPlanId: json['payment_plan_id'] as String?,
      amount: (json['amount'] as num).toDouble(),
      lessonsCount: json['lessons_count'] as int,
      isCorrection: json['is_correction'] as bool? ?? false,
      correctionReason: json['correction_reason'] as String?,
      paidAt: DateTime.parse(json['paid_at'] as String),
      recordedBy: json['recorded_by'] as String,
      comment: json['comment'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      student: json['students'] != null
          ? Student.fromJson(json['students'] as Map<String, dynamic>)
          : null,
      paymentPlan: json['payment_plans'] != null
          ? PaymentPlan.fromJson(
              json['payment_plans'] as Map<String, dynamic>)
          : null,
      recordedByProfile: json['profiles'] != null
          ? Profile.fromJson(json['profiles'] as Map<String, dynamic>)
          : null,
      subscription: subscription,
    );
  }

  Map<String, dynamic> toJson() => {
        'institution_id': institutionId,
        'student_id': studentId,
        'payment_plan_id': paymentPlanId,
        'amount': amount,
        'lessons_count': lessonsCount,
        'is_correction': isCorrection,
        'correction_reason': correctionReason,
        'paid_at': paidAt.toIso8601String(),
        'recorded_by': recordedBy,
        'comment': comment,
      };
}
