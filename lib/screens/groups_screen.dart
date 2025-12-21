import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/biometric_service.dart';
import '../services/secure_storage_service.dart';
import '../models/group_model.dart';
import 'expenses_screen.dart';
import 'pin_setup_screen.dart';

class GroupsScreen extends StatefulWidget {
  const GroupsScreen({super.key});

  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> {
  final _firestoreService = FirestoreService();
  final _authService = AuthService();
  final _biometricService = BiometricService();
  final _groupNameController = TextEditingController();

  @override
  void dispose() {
    _groupNameController.dispose();
    super.dispose();
  }

  Future<void> _showBiometricSettings() async {
    final isSupported = await _biometricService.isDeviceSupported();
    final canCheck = await _biometricService.canCheckBiometrics();
    final isEnabled = await SecureStorageService().isBiometricEnabled();
    final isAvailable = isSupported && canCheck;

    if (!isAvailable) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Biometric authentication is not available on this device'),
          ),
        );
      }
      return;
    }

    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Biometric Authentication'),
          content: Text(
            isEnabled
                ? 'Biometric authentication is currently enabled. Do you want to disable it?'
                : 'Do you want to enable biometric authentication? You can use fingerprint or face ID to unlock the app.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            if (isEnabled)
              ElevatedButton(
                onPressed: () async {
                  await SecureStorageService().setBiometricEnabled(false);
                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Biometric authentication disabled'),
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                ),
                child: const Text('Disable'),
              )
            else
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);
                  // Test biometric authentication
                  final testResult = await _biometricService.authenticate();
                  if (testResult) {
                    await SecureStorageService().setBiometricEnabled(true);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Biometric authentication enabled successfully'),
                        ),
                      );
                    }
                  } else {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Biometric authentication test failed. Please try again.'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
                child: const Text('Enable'),
              ),
          ],
        ),
      );
    }
  }

  void _showCreateGroupDialog() {
    _groupNameController.clear();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create New Group'),
        content: TextField(
          controller: _groupNameController,
          decoration: const InputDecoration(
            labelText: 'Group Name',
            hintText: 'Enter group name',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (_groupNameController.text.trim().isNotEmpty) {
                try {
                  await _firestoreService.createGroup(
                    _groupNameController.text.trim(),
                  );
                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Group created successfully')),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: ${e.toString()}')),
                    );
                  }
                }
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Expense Groups'),
        actions: [
          PopupMenuButton(
            icon: const Icon(Icons.more_vert),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'pin',
                child: Row(
                  children: [
                    Icon(Icons.lock_outline),
                    SizedBox(width: 8),
                    Text('Change PIN'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'biometric',
                child: Row(
                  children: [
                    Icon(Icons.fingerprint),
                    SizedBox(width: 8),
                    Text('Biometric Settings'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout),
                    SizedBox(width: 8),
                    Text('Logout'),
                  ],
                ),
              ),
            ],
            onSelected: (value) async {
              if (value == 'pin') {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const PinSetupScreen(),
                  ),
                );
                if (result == true && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('PIN updated successfully')),
                  );
                }
              } else if (value == 'biometric') {
                await _showBiometricSettings();
              } else if (value == 'logout') {
                await _authService.signOut();
              }
            },
          ),
        ],
      ),
      body: StreamBuilder<List<GroupModel>>(
        stream: _firestoreService.getGroups(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Error: ${snapshot.error}'),
            );
          }

          final groups = snapshot.data ?? [];

          if (groups.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.folder_open,
                    size: 64,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No groups yet',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.grey,
                        ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Create a group to start tracking expenses',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: groups.length,
            itemBuilder: (context, index) {
              final group = groups[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.folder),
                  ),
                  title: Text(
                    group.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    'Created ${_formatDate(group.createdAt)}',
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ExpensesScreen(group: group),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateGroupDialog,
        child: const Icon(Icons.add),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}
