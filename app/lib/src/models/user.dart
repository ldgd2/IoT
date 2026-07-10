// lib/src/models/user.dart
class ColmenaUser {
  final String userId;
  final String username;
  final String email;
  final String createdAt;

  const ColmenaUser({
    required this.userId,
    required this.username,
    required this.email,
    required this.createdAt,
  });

  factory ColmenaUser.fromJson(Map<String, dynamic> json) => ColmenaUser(
        userId: json['user_id'] as String? ?? '',
        username: json['username'] as String? ?? '',
        email: json['email'] as String? ?? '',
        createdAt: json['created_at'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'username': username,
        'email': email,
        'created_at': createdAt,
      };
}
