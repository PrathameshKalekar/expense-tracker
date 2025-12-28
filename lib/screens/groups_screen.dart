import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/biometric_service.dart';
import '../services/secure_storage_service.dart';
import '../services/cloudinary_service.dart';
import '../models/group_model.dart';
import '../models/expense_model.dart';
import 'expenses_screen.dart';
import 'pin_setup_screen.dart';

class GroupsScreen extends StatefulWidget {
  const GroupsScreen({super.key});

  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> {
  final _firestoreService = FirestoreService();
  final _cloudinaryService = CloudinaryService();
  final _authService = AuthService();
  final _biometricService = BiometricService();
  final _groupNameController = TextEditingController();
  final _editGroupNameController = TextEditingController();
  bool _isDeleting = false;

  @override
  void dispose() {
    _groupNameController.dispose();
    _editGroupNameController.dispose();
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
          SnackBar(
            content: const Text('Biometric authentication is not available on this device'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
      return;
    }

    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.fingerprint,
                    color: Theme.of(context).colorScheme.primary,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Biometric Authentication',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade900,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  isEnabled
                      ? 'Biometric authentication is currently enabled. Do you want to disable it?'
                      : 'Do you want to enable biometric authentication? You can use fingerprint or face ID to unlock the app.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey.shade600,
                        height: 1.5,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          side: BorderSide(color: Colors.grey.shade300),
                        ),
                        child: Text(
                          'Cancel',
                          style: TextStyle(color: Colors.grey.shade700),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          if (isEnabled) {
                            await SecureStorageService().setBiometricEnabled(false);
                            if (mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Biometric authentication disabled'),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          } else {
                            Navigator.pop(context);
                            // Test biometric authentication
                            final testResult = await _biometricService.authenticate();
                            if (testResult) {
                              await SecureStorageService().setBiometricEnabled(true);
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Biometric authentication enabled successfully'),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                            } else {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: const Text('Biometric authentication test failed. Please try again.'),
                                    backgroundColor: Colors.red.shade400,
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          backgroundColor: isEnabled ? Colors.red.shade400 : null,
                          foregroundColor: isEnabled ? Colors.white : null,
                          elevation: 0,
                        ),
                        child: Text(isEnabled ? 'Disable' : 'Enable'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }
  }

  void _showGroupOptions(GroupModel group) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.edit_outlined,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                title: const Text('Edit Group'),
                onTap: () {
                  Navigator.pop(context);
                  _showEditGroupDialog(group);
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.share_outlined,
                    color: Colors.blue.shade600,
                  ),
                ),
                title: const Text('Share Expense'),
                onTap: () {
                  Navigator.pop(context);
                  _shareExpensesAsPdf(group);
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.delete_outline,
                    color: Colors.red.shade400,
                  ),
                ),
                title: Text(
                  'Delete Group',
                  style: TextStyle(color: Colors.red.shade400),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _showDeleteGroupDialog(group);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditGroupDialog(GroupModel group) {
    _editGroupNameController.text = group.name;
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.edit_outlined,
                  color: Theme.of(context).colorScheme.primary,
                  size: 32,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Edit Group',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade900,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _editGroupNameController,
                decoration: InputDecoration(
                  labelText: 'Group Name',
                  hintText: 'Enter group name',
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.primary,
                      width: 2,
                    ),
                  ),
                ),
                autofocus: true,
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        side: BorderSide(color: Colors.grey.shade300),
                      ),
                      child: Text(
                        'Cancel',
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        if (_editGroupNameController.text.trim().isNotEmpty) {
                          try {
                            await _firestoreService.updateGroup(
                              group.id,
                              _editGroupNameController.text.trim(),
                            );
                            if (mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Text('Group updated successfully'),
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error: ${e.toString()}'),
                                  backgroundColor: Colors.red.shade400,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: const Text('Update'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDeleteGroupDialog(GroupModel group) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.delete_outline,
                  color: Colors.red.shade400,
                  size: 32,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Delete Group',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade900,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Are you sure you want to delete "${group.name}"? All expenses in this group will also be deleted. This action cannot be undone.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey.shade600,
                      height: 1.5,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        side: BorderSide(color: Colors.grey.shade300),
                      ),
                      child: Text(
                        'Cancel',
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isDeleting
                          ? null
                          : () async {
                              try {
                                setState(() => _isDeleting = true);

                                // Show loading dialog
                                if (mounted) {
                                  showDialog(
                                    context: context,
                                    barrierDismissible: false,
                                    builder: (context) => WillPopScope(
                                      onWillPop: () async => false,
                                      child: Dialog(
                                        backgroundColor: Colors.transparent,
                                        elevation: 0,
                                        child: Container(
                                          padding: const EdgeInsets.all(24),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(16),
                                          ),
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const CircularProgressIndicator(),
                                              const SizedBox(height: 16),
                                              Text(
                                                'Deleting group and expenses...',
                                                style: TextStyle(
                                                  color: Colors.grey.shade700,
                                                  fontSize: 14,
                                                ),
                                              ),
                                              const SizedBox(height: 8),
                                              Text(
                                                'This may take a moment',
                                                style: TextStyle(
                                                  color: Colors.grey.shade500,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                }

                                // Get all expenses with proof images
                                final expenses = await _firestoreService.getExpensesDataForGroup(group.id);

                                // Delete all proof images
                                for (var expense in expenses) {
                                  final proofUrl = expense['proofUrl'] as String?;
                                  if (proofUrl != null && proofUrl.isNotEmpty) {
                                    try {
                                      await _cloudinaryService.deleteProofImage(proofUrl);
                                    } catch (e) {
                                      // Continue even if image deletion fails
                                    }
                                  }
                                }

                                // Delete group and expenses from Firestore
                                await _firestoreService.deleteGroup(group.id);

                                setState(() => _isDeleting = false);

                                if (mounted) {
                                  Navigator.pop(context); // Close loading dialog
                                  Navigator.pop(context); // Close delete confirmation dialog
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: const Text('Group and expenses deleted successfully'),
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                  );
                                }
                              } catch (e) {
                                setState(() => _isDeleting = false);
                                if (mounted) {
                                  Navigator.pop(context); // Close loading dialog
                                  Navigator.pop(context); // Close delete confirmation dialog
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Error: ${e.toString()}'),
                                      backgroundColor: Colors.red.shade400,
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                }
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        backgroundColor: Colors.red.shade400,
                        foregroundColor: Colors.white,
                        elevation: 0,
                      ),
                      child: _isDeleting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text('Delete'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCreateGroupDialog() {
    _groupNameController.clear();
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.folder_outlined,
                  color: Theme.of(context).colorScheme.primary,
                  size: 32,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Create New Group',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade900,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _groupNameController,
                decoration: InputDecoration(
                  labelText: 'Group Name',
                  hintText: 'Enter group name',
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.primary,
                      width: 2,
                    ),
                  ),
                ),
                autofocus: true,
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        side: BorderSide(color: Colors.grey.shade300),
                      ),
                      child: Text(
                        'Cancel',
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        if (_groupNameController.text.trim().isNotEmpty) {
                          try {
                            await _firestoreService.createGroup(
                              _groupNameController.text.trim(),
                            );
                            if (mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Text('Group created successfully'),
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error: ${e.toString()}'),
                                  backgroundColor: Colors.red.shade400,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: const Text('Create'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        title: const Text(
          'Expense Groups',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        actions: [
          PopupMenuButton(
            icon: const Icon(Icons.more_vert),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'pin',
                child: Row(
                  children: [
                    Icon(
                      Icons.lock_outline,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    const Text('Change PIN'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'biometric',
                child: Row(
                  children: [
                    Icon(
                      Icons.fingerprint,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    const Text('Biometric Settings'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(
                      Icons.logout,
                      color: Colors.red.shade400,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Logout',
                      style: TextStyle(color: Colors.red.shade400),
                    ),
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
                    const SnackBar(
                      content: Text('PIN updated successfully'),
                      behavior: SnackBarBehavior.floating,
                    ),
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
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Colors.red.shade300,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading groups',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            );
          }

          final groups = snapshot.data ?? [];

          if (groups.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.folder_open_rounded,
                      size: 64,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'No groups yet',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Create a group to start tracking expenses',
                    style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 14,
                    ),
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
              return TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: Duration(milliseconds: 300 + (index * 50)),
                curve: Curves.easeOut,
                builder: (context, value, child) {
                  return Opacity(
                    opacity: value,
                    child: Transform.translate(
                      offset: Offset(0, 20 * (1 - value)),
                      child: Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 2,
                        child: InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ExpensesScreen(group: group),
                              ),
                            );
                          },
                          onLongPress: () {
                            _showGroupOptions(group);
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Container(
                                  width: 56,
                                  height: 56,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Theme.of(context).colorScheme.primary,
                                        Theme.of(context).colorScheme.primary.withOpacity(0.7),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: const Icon(
                                    Icons.folder_rounded,
                                    color: Colors.white,
                                    size: 28,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        group.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 16,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Created ${_formatDate(group.createdAt)}',
                                        style: TextStyle(
                                          color: Colors.grey.shade600,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  Icons.chevron_right_rounded,
                                  color: Colors.grey.shade400,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateGroupDialog,
        icon: const Icon(Icons.add),
        label: const Text('New Group'),
        elevation: 4,
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

  Future<void> _shareExpensesAsPdf(GroupModel group) async {
    try {
      // Show loading dialog
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => WillPopScope(
            onWillPop: () async => false,
            child: Dialog(
              backgroundColor: Colors.transparent,
              elevation: 0,
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(
                      'Generating PDF...',
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }

      // Get all expenses for the group with proper document IDs
      final expensesCollection = FirebaseFirestore.instance.collection('expenses');
      final expensesSnapshot = await expensesCollection.where('groupId', isEqualTo: group.id).get();

      if (expensesSnapshot.docs.isEmpty) {
        if (mounted) {
          Navigator.pop(context); // Close loading dialog
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No expenses to share'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      // Convert to ExpenseModel list with proper IDs
      final expenses = expensesSnapshot.docs.map((doc) {
        return ExpenseModel.fromMap(doc.id, doc.data());
      }).toList();

      // Sort by date (newest first)
      expenses.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      // Calculate total
      final total = expenses.fold<double>(0, (sum, expense) => sum + expense.amount);

      // Format currency with "Rs" prefix (PDF doesn't support ₹ symbol well)
      String formatCurrency(double amount) {
        return 'Rs ${amount.toStringAsFixed(2)}';
      }

      // Store expense URLs with their indices for later loading
      final Map<int, String> expenseImageUrls = {};
      for (int i = 0; i < expenses.length; i++) {
        final expense = expenses[i];
        if (expense.proofUrl != null && expense.proofUrl!.isNotEmpty) {
          final url = expense.proofUrl!.trim();
          if (url.isNotEmpty) {
            expenseImageUrls[i] = url;
          }
        }
      }

      // Remove emojis from group name (PDF doesn't support emojis well)
      String cleanGroupName = _removeEmojis(group.name);

      // Create PDF
      final pdf = pw.Document();

      // Build expense widgets list - create each widget independently
      final List<pw.Widget> expenseWidgets = [];

      for (int index = 0; index < expenses.length; index++) {
        final expense = expenses[index];

        // Remove emojis from expense title
        String cleanTitle = _removeEmojis(expense.title);

        // Build expense children list
        final List<pw.Widget> expenseChildren = [
          // Expense number and title
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Expanded(
                child: pw.Text(
                  '${index + 1}. $cleanTitle',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.Text(
                formatCurrency(expense.amount),
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue700,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            DateFormat('MMM dd, yyyy').format(expense.createdAt),
            style: pw.TextStyle(
              fontSize: 10,
              color: PdfColors.grey600,
            ),
          ),
        ];

        // Add proof image if available - load fresh for each expense
        final imageUrl = expenseImageUrls[index];
        if (imageUrl != null && imageUrl.isNotEmpty) {
          try {
            // Load image fresh for this specific expense
            final imageData = await _loadImageFromUrl(imageUrl);
            if (imageData.isNotEmpty && imageData.lengthInBytes > 100) {
              // Create a completely independent copy - use List.generate to force new instance
              final imageBytesList = List<int>.generate(
                imageData.length,
                (i) => imageData[i],
              );
              final freshImageBytes = Uint8List.fromList(imageBytesList);

              // Create a new MemoryImage instance for this expense
              final imageProvider = pw.MemoryImage(freshImageBytes);

              // Create the image widget immediately
              final imageWidget = pw.Container(
                width: 400,
                height: 300,
                child: pw.Center(
                  child: pw.Image(
                    imageProvider,
                    fit: pw.BoxFit.contain,
                  ),
                ),
              );

              expenseChildren.add(pw.SizedBox(height: 12));
              expenseChildren.add(imageWidget);
            }
          } catch (e) {
            // If image fails to add, skip it silently
          }
        }

        // Create the expense container widget
        final expenseWidget = pw.Container(
          margin: const pw.EdgeInsets.only(bottom: 25),
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey300, width: 1),
            borderRadius: pw.BorderRadius.circular(8),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: expenseChildren,
          ),
        );

        expenseWidgets.add(expenseWidget);
      }

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          build: (pw.Context context) {
            return [
              // Header
              pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 30),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      cleanGroupName,
                      style: pw.TextStyle(
                        fontSize: 28,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 12),
                    pw.Text(
                      'Total Expenses: ${formatCurrency(total)} | Number of Expenses: ${expenses.length}',
                      style: pw.TextStyle(
                        fontSize: 14,
                        color: PdfColors.grey700,
                      ),
                    ),
                  ],
                ),
              ),

              // Expenses list
              ...expenseWidgets,
            ];
          },
        ),
      );

      // Save PDF to temporary file
      final output = await getTemporaryDirectory();
      final file = File('${output.path}/expenses_${group.id}_${DateTime.now().millisecondsSinceEpoch}.pdf');
      await file.writeAsBytes(await pdf.save());

      // Close loading dialog
      if (mounted) {
        Navigator.pop(context);
      }

      // Share the PDF
      if (mounted) {
        await Share.shareXFiles(
          [XFile(file.path)],
          text: 'Expense Report: ${group.name}',
          subject: 'Expense Report',
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading dialog if still open
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating PDF: ${e.toString()}'),
            backgroundColor: Colors.red.shade400,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<Uint8List> _loadImageFromUrl(String url) async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty && response.bodyBytes.lengthInBytes > 100) {
        // Return a copy to ensure it's a separate instance
        return Uint8List.fromList(response.bodyBytes);
      }
      return Uint8List(0);
    } catch (e) {
      return Uint8List(0);
    }
  }

  // Remove emojis from text (PDF doesn't support emojis well)
  String _removeEmojis(String text) {
    // Remove emojis using regex
    return text
        .replaceAll(
          RegExp(
            r'[\u{1F600}-\u{1F64F}]|[\u{1F300}-\u{1F5FF}]|[\u{1F680}-\u{1F6FF}]|[\u{1F1E0}-\u{1F1FF}]|[\u{2600}-\u{26FF}]|[\u{2700}-\u{27BF}]',
            unicode: true,
          ),
          '',
        )
        .trim();
  }
}
