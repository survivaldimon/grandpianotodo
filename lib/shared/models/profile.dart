/// Профиль пользователя (расширение auth.users)
/// Не наследует BaseModel, так как профили не архивируются
class Profile {
  final String id;
  final String fullName;
  final String? avatarUrl;
  final String email;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Profile({
    required this.id,
    required this.fullName,
    required this.email,
    required this.createdAt,
    required this.updatedAt,
    this.avatarUrl,
  });

  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
        id: json['id'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
        fullName: json['full_name'] as String,
        email: json['email'] as String,
        avatarUrl: json['avatar_url'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'full_name': fullName,
        'avatar_url': avatarUrl,
      };

  Profile copyWith({
    String? fullName,
    String? avatarUrl,
    String? email,
  }) =>
      Profile(
        id: id,
        createdAt: createdAt,
        updatedAt: updatedAt,
        fullName: fullName ?? this.fullName,
        email: email ?? this.email,
        avatarUrl: avatarUrl ?? this.avatarUrl,
      );
}
