class HouseholdRole {
  HouseholdRole({
    required this.id,
    required this.name,
    required this.color,
    this.isAdmin = false,
  });

  factory HouseholdRole.fromJson(Map<String, dynamic> json) {
    return HouseholdRole(
      id: json['id'] as String,
      name: json['name'] as String,
      color: json['color'] as String,
      isAdmin: json['isAdmin'] as bool? ?? false,
    );
  }

  final String id;
  final String name;
  final String color;
  final bool isAdmin;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'color': color,
      'isAdmin': isAdmin,
    };
  }
}

