import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/firestore_service.dart';
import '../models/group_model.dart';
import '../models/expense_model.dart';

class ExpensesScreen extends StatefulWidget {
  final GroupModel group;

  const ExpensesScreen({super.key, required this.group});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  final _firestoreService = FirestoreService();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  bool _isSelectionMode = false;
  final Set<String> _selectedExpenseIds = <String>{};

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  void _enterSelectionMode() {
    setState(() {
      _isSelectionMode = true;
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedExpenseIds.clear();
    });
  }

  void _toggleExpenseSelection(String expenseId) {
    setState(() {
      if (_selectedExpenseIds.contains(expenseId)) {
        _selectedExpenseIds.remove(expenseId);
      } else {
        _selectedExpenseIds.add(expenseId);
      }
      if (_selectedExpenseIds.isEmpty) {
        _isSelectionMode = false;
      }
    });
  }

  Future<void> _markSelectedAsDontCount(bool dontCount) async {
    if (_selectedExpenseIds.isEmpty) return;

    try {
      for (final expenseId in _selectedExpenseIds) {
        await _firestoreService.toggleExpenseDontCount(expenseId, dontCount);
      }

      if (mounted) {
        final count = _selectedExpenseIds.length;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              dontCount ? '$count expense(s) marked as "Don\'t Count"' : '$count expense(s) will be counted',
            ),
          ),
        );
        _exitSelectionMode();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  void _showAddExpenseDialog() {
    _titleController.clear();
    _amountController.clear();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Expense'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Title',
                hintText: 'Enter expense title',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Amount',
                hintText: 'Enter amount',
                prefixText: '₹ ',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final title = _titleController.text.trim();
              final amountText = _amountController.text.trim();

              if (title.isEmpty || amountText.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please fill all fields')),
                );
                return;
              }

              final amount = double.tryParse(amountText);
              if (amount == null || amount <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a valid amount')),
                );
                return;
              }

              try {
                await _firestoreService.addExpense(
                  widget.group.id,
                  title,
                  amount,
                );
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Expense added successfully')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: ${e.toString()}')),
                  );
                }
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(symbol: '₹', decimalDigits: 0);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isSelectionMode ? '${_selectedExpenseIds.length} selected' : widget.group.name),
        leading: _isSelectionMode
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: _exitSelectionMode,
              )
            : null,
      ),
      body: Column(
        children: [
          // Total expenses card
          StreamBuilder<List<ExpenseModel>>(
            stream: _firestoreService.getExpenses(widget.group.id),
            builder: (context, snapshot) {
              double total = 0;
              if (snapshot.hasData) {
                total = snapshot.data!.where((expense) => !expense.dontCount).fold(0, (sum, expense) => sum + expense.amount);
              }

              return Container(
                width: double.infinity,
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.deepPurple,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    const Text(
                      'Total Expenses',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      currencyFormat.format(total),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          // Expenses list
          Expanded(
            child: StreamBuilder<List<ExpenseModel>>(
              stream: _firestoreService.getExpenses(widget.group.id),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text('Error: ${snapshot.error}'),
                  );
                }

                final expenses = snapshot.data ?? [];

                if (expenses.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.receipt_long,
                          size: 64,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No expenses yet',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.grey),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Tap + to add your first expense',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                return Column(
                  children: [
                    if (_isSelectionMode && expenses.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        color: Colors.deepPurple.shade50,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            TextButton.icon(
                              icon: const Icon(Icons.select_all),
                              label: const Text('Select All'),
                              onPressed: () {
                                setState(() {
                                  _selectedExpenseIds.clear();
                                  for (var expense in expenses) {
                                    _selectedExpenseIds.add(expense.id);
                                  }
                                });
                              },
                            ),
                            Row(
                              children: [
                                ElevatedButton.icon(
                                  icon: const Icon(Icons.block, size: 18),
                                  label: const Text("Don't Count"),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.orange,
                                    foregroundColor: Colors.white,
                                  ),
                                  onPressed: _selectedExpenseIds.isEmpty ? null : () => _markSelectedAsDontCount(true),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton.icon(
                                  icon: const Icon(Icons.check_circle, size: 18),
                                  label: const Text('Count'),
                                  onPressed: _selectedExpenseIds.isEmpty ? null : () => _markSelectedAsDontCount(false),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: expenses.length,
                        itemBuilder: (context, index) {
                          final expense = expenses[index];
                          final isSelected = _selectedExpenseIds.contains(expense.id);
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            color: expense.dontCount
                                ? Colors.grey.shade100
                                : isSelected
                                    ? Colors.blue.shade50
                                    : null,
                            child: InkWell(
                              onLongPress: () {
                                if (!_isSelectionMode) {
                                  _enterSelectionMode();
                                }
                                _toggleExpenseSelection(expense.id);
                              },
                              onTap: () {
                                if (_isSelectionMode) {
                                  _toggleExpenseSelection(expense.id);
                                }
                              },
                              child: ListTile(
                                leading: _isSelectionMode
                                    ? Checkbox(
                                        value: isSelected,
                                        onChanged: (value) {
                                          _toggleExpenseSelection(expense.id);
                                        },
                                      )
                                    : CircleAvatar(
                                        backgroundColor: expense.dontCount ? Colors.grey.shade300 : Colors.deepPurple.shade100,
                                        child: Icon(
                                          Icons.attach_money,
                                          color: expense.dontCount ? Colors.grey : Colors.deepPurple,
                                        ),
                                      ),
                                title: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        expense.title,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          decoration: expense.dontCount ? TextDecoration.lineThrough : null,
                                          color: expense.dontCount ? Colors.grey : null,
                                        ),
                                      ),
                                    ),
                                    if (expense.dontCount && !_isSelectionMode)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        margin: const EdgeInsets.only(left: 8),
                                        decoration: BoxDecoration(
                                          color: Colors.orange.shade100,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          "Don't Count",
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.orange.shade800,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                subtitle: Text(
                                  _formatDate(expense.createdAt),
                                  style: TextStyle(
                                    color: expense.dontCount ? Colors.grey : null,
                                  ),
                                ),
                                trailing: Text(
                                  currencyFormat.format(expense.amount),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: expense.dontCount ? Colors.grey : null,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddExpenseDialog,
        child: const Icon(Icons.add),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return DateFormat('MMM dd, yyyy').format(date);
  }
}
