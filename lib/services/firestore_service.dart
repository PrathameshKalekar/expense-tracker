import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/group_model.dart';
import '../models/expense_model.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Groups Collection
  CollectionReference get _groupsCollection => _firestore.collection('groups');

  // Expenses Collection
  CollectionReference get _expensesCollection => _firestore.collection('expenses');

  // Create a new group
  Future<String> createGroup(String name) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final groupData = {
      'name': name,
      'userId': user.uid,
      'createdAt': DateTime.now().toIso8601String(),
    };

    final docRef = await _groupsCollection.add(groupData);
    return docRef.id;
  }

  // Get all groups for current user
  Stream<List<GroupModel>> getGroups() {
    final user = _auth.currentUser;
    if (user == null) {
      return Stream.value([]);
    }

    return _groupsCollection.where('userId', isEqualTo: user.uid).snapshots().map((snapshot) {
      final groups = snapshot.docs.map((doc) => GroupModel.fromMap(doc.id, doc.data() as Map<String, dynamic>)).toList();
      // Sort by createdAt descending
      groups.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return groups;
    });
  }

  // Add an expense to a group
  Future<String> addExpense(String groupId, String title, double amount) async {
    final expenseData = {
      'groupId': groupId,
      'title': title,
      'amount': amount,
      'createdAt': DateTime.now().toIso8601String(),
    };

    final docRef = await _expensesCollection.add(expenseData);
    return docRef.id;
  }

  // Get all expenses for a group
  Stream<List<ExpenseModel>> getExpenses(String groupId) {
    return _expensesCollection.where('groupId', isEqualTo: groupId).snapshots().map((snapshot) {
      final expenses = snapshot.docs.map((doc) => ExpenseModel.fromMap(doc.id, doc.data() as Map<String, dynamic>)).toList();
      // Sort by createdAt descending
      expenses.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return expenses;
    });
  }

  // Delete an expense
  Future<void> deleteExpense(String expenseId) async {
    await _expensesCollection.doc(expenseId).delete();
  }

  // Get total expenses for a group
  Future<double> getTotalExpenses(String groupId) async {
    final snapshot = await _expensesCollection.where('groupId', isEqualTo: groupId).get();

    double total = 0;
    for (var doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      total += (data['amount'] ?? 0).toDouble();
    }
    return total;
  }

  // Update a group
  Future<void> updateGroup(String groupId, String name) async {
    await _groupsCollection.doc(groupId).update({
      'name': name,
    });
  }

  // Delete a group and all its expenses
  Future<void> deleteGroup(String groupId) async {
    // First, delete all expenses in this group
    final expensesSnapshot = await _expensesCollection.where('groupId', isEqualTo: groupId).get();

    final batch = _firestore.batch();
    for (var doc in expensesSnapshot.docs) {
      batch.delete(doc.reference);
    }

    // Then delete the group
    batch.delete(_groupsCollection.doc(groupId));

    await batch.commit();
  }

  // Update an expense
  Future<void> updateExpense(String expenseId, String title, double amount) async {
    await _expensesCollection.doc(expenseId).update({
      'title': title,
      'amount': amount,
    });
  }
}
