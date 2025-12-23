import 'package:kabinet/shared/models/base_model.dart';

/// Тариф оплаты
class PaymentPlan extends BaseModel {
  final String institutionId;
  final String name;
  final double price;
  final int lessonsCount;
  final int validityDays; // Срок действия абонемента в днях

  const PaymentPlan({
    required super.id,
    required super.createdAt,
    required super.updatedAt,
    super.archivedAt,
    required this.institutionId,
    required this.name,
    required this.price,
    required this.lessonsCount,
    this.validityDays = 30,
  });

  /// Цена за одно занятие
  double get pricePerLesson => price / lessonsCount;

  /// Отображение: "8 занятий — 20 000 ₸"
  String get displayName => '$lessonsCount занятий — ${price.toStringAsFixed(0)} ₸';

  /// Отображение со сроком: "8 занятий — 20 000 ₸ (30 дней)"
  String get displayNameWithValidity => '$lessonsCount занятий — ${price.toStringAsFixed(0)} ₸ ($validityDays дн.)';

  factory PaymentPlan.fromJson(Map<String, dynamic> json) => PaymentPlan(
        id: json['id'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
        archivedAt: json['archived_at'] != null
            ? DateTime.parse(json['archived_at'] as String)
            : null,
        institutionId: json['institution_id'] as String,
        name: json['name'] as String,
        price: (json['price'] as num).toDouble(),
        lessonsCount: json['lessons_count'] as int,
        validityDays: json['validity_days'] as int? ?? 30,
      );

  Map<String, dynamic> toJson() => {
        'institution_id': institutionId,
        'name': name,
        'price': price,
        'lessons_count': lessonsCount,
        'validity_days': validityDays,
      };

  PaymentPlan copyWith({
    String? name,
    double? price,
    int? lessonsCount,
    int? validityDays,
  }) =>
      PaymentPlan(
        id: id,
        createdAt: createdAt,
        updatedAt: updatedAt,
        archivedAt: archivedAt,
        institutionId: institutionId,
        name: name ?? this.name,
        price: price ?? this.price,
        lessonsCount: lessonsCount ?? this.lessonsCount,
        validityDays: validityDays ?? this.validityDays,
      );
}
