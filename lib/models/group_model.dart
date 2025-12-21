class GroupModel {
  final String id;
  final String name;
  final String userId;
  final DateTime createdAt;

  GroupModel({
    required this.id,
    required this.name,
    required this.userId,
    required this.createdAt,
  });

  // Convert to Firestore document
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'userId': userId,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  // Create from Firestore document
  factory GroupModel.fromMap(String id, Map<String, dynamic> map) {
    return GroupModel(
      id: id,
      name: map['name'] ?? '',
      userId: map['userId'] ?? '',
      createdAt: DateTime.parse(map['createdAt']),
    );
  }
}

