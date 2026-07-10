class Hub {
  final String id;
  final String name;
  final String localUrl;
  final bool online;

  Hub({
    required this.id,
    required this.name,
    required this.localUrl,
    required this.online,
  });

  factory Hub.fromJson(Map<String, dynamic> json) {
    return Hub(
      id: json['hub_id'] as String,
      name: json['name'] as String,
      localUrl: json['local_url'] as String? ?? '',
      online: json['online'] == 1 || json['online'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'hub_id': id,
      'name': name,
      'local_url': localUrl,
      'online': online ? 1 : 0,
    };
  }
}
