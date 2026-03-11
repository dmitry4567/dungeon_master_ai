/// Модель пользователя
class User {
  final String id;
  final String email;
  final String name;
  final DateTime createdAt;
  final String? avatarUrl;

  const User({
    required this.id,
    required this.email,
    required this.name,
    required this.createdAt,
    this.avatarUrl,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      email: json['email'] as String,
      name: json['name'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      avatarUrl: json['avatar_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'created_at': createdAt.toIso8601String(),
      if (avatarUrl != null) 'avatar_url': avatarUrl,
    };
  }
}
