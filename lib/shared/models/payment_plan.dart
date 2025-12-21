import 'package:kabinet/shared/models/base_model.dart';

/// Тариф оплаты
class PaymentPlan extends BaseModel {
  final String institutionId;
  final String name;
  final double price;
  final int lessonsCount;

  const PaymentPlan({
    required super.id,
    required super.createdAt,
    required super.updatedAt,
    super.archivedAt,
    required this.institutionId,
    required this.name,
    required this.price,
    required this.lessonsCount,
  });

  /// Цена за одно занятие
  double get pricePerLesson => price / lessonsCount;

  /// Отображение: "8 занятий — 20 000 ₸"
  String get displayName => '$lessonsCount занятий — ${price.toStringAsFixed(0)} ₸';

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
      );

  Map<String, dynamic> toJson() => {
        'institution_id': institutionId,
        'name': name,
        'price': price,
        'lessons_count': lessonsCount,
      };

  PaymentPlan copyWith({
    String? name,
    double? price,
    int? lessonsCount,
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
      );
}
