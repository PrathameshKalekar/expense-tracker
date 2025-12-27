class ExpenseModel {
  final String id;
  final String groupId;
  final String title;
  final double amount;
  final DateTime createdAt;

  ExpenseModel({
    required this.id,
    required this.groupId,
    required this.title,
    required this.amount,
    required this.createdAt,
  });

  // Convert to Firestore document
  Map<String, dynamic> toMap() {
    return {
      'groupId': groupId,
      'title': title,
      'amount': amount,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  // Create from Firestore document
  factory ExpenseModel.fromMap(String id, Map<String, dynamic> map) {
    return ExpenseModel(
      id: id,
      groupId: map['groupId'] ?? '',
      title: map['title'] ?? '',
      amount: (map['amount'] ?? 0).toDouble(),
      createdAt: DateTime.parse(map['createdAt']),
    );
  }
}

