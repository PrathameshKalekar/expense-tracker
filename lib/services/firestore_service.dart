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
  Future<String> addExpense(String groupId, String title, double amount, {String? proofUrl}) async {
    final expenseData = {
      'groupId': groupId,
      'title': title,
      'amount': amount,
      'createdAt': DateTime.now().toIso8601String(),
      if (proofUrl != null) 'proofUrl': proofUrl,
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

  // Get expense data before deletion (for proof image deletion)
  Future<Map<String, dynamic>?> getExpenseData(String expenseId) async {
    final doc = await _expensesCollection.doc(expenseId).get();
    if (doc.exists) {
      return doc.data() as Map<String, dynamic>?;
    }
    return null;
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

  // Get all expenses for a group (for proof image deletion)
  Future<List<Map<String, dynamic>>> getExpensesDataForGroup(String groupId) async {
    final expensesSnapshot = await _expensesCollection.where('groupId', isEqualTo: groupId).get();
    return expensesSnapshot.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();
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
  Future<void> updateExpense(String expenseId, String title, double amount, {String? proofUrl}) async {
    final updateData = <String, dynamic>{
      'title': title,
      'amount': amount,
    };
    if (proofUrl != null) {
      updateData['proofUrl'] = proofUrl;
    } else if (proofUrl == null && updateData.containsKey('proofUrl')) {
      updateData['proofUrl'] = FieldValue.delete();
    }
    await _expensesCollection.doc(expenseId).update(updateData);
  }

  // Update proof URL for an expense
  Future<void> updateExpenseProof(String expenseId, String? proofUrl) async {
    final updateData = <String, dynamic>{};
    if (proofUrl != null) {
      updateData['proofUrl'] = proofUrl;
    } else {
      updateData['proofUrl'] = FieldValue.delete();
    }
    await _expensesCollection.doc(expenseId).update(updateData);
  }
}
