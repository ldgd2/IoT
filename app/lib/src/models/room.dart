// lib/src/models/room.dart
class Room {
  final String roomId;
  final String userId;
  final String name;
  final String icon;
  final String createdAt;

  const Room({
    required this.roomId,
    required this.userId,
    required this.name,
    this.icon = 'home',
    this.createdAt = '',
  });

  factory Room.fromJson(Map<String, dynamic> json) => Room(
        roomId: json['room_id'] as String? ?? '',
        userId: json['user_id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        icon: json['icon'] as String? ?? 'home',
        createdAt: json['created_at'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'room_id': roomId,
        'user_id': userId,
        'name': name,
        'icon': icon,
        'created_at': createdAt,
      };
}
