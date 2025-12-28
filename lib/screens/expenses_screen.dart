import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/firestore_service.dart';
import '../services/cloudinary_service.dart';
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
  final _cloudinaryService = CloudinaryService();
  final _imagePicker = ImagePicker();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _editTitleController = TextEditingController();
  final _editAmountController = TextEditingController();
  File? _selectedProofImage;
  File? _selectedEditProofImage;
  String? _currentEditProofUrl;
  bool _isUploading = false;
  bool _isDeleting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _editTitleController.dispose();
    _editAmountController.dispose();
    super.dispose();
  }

  Future<bool> _requestPermission(Permission permission, String permissionType) async {
    final status = await permission.status;
    if (status.isGranted) {
      return true;
    }

    if (status.isDenied) {
      final result = await permission.request();
      return result.isGranted;
    }

    if (status.isPermanentlyDenied) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Permission Required'),
            content: Text(
              '$permissionType permission is permanently denied. Please enable it from app settings.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  openAppSettings();
                },
                child: const Text('Open Settings'),
              ),
            ],
          ),
        );
      }
      return false;
    }

    return false;
  }

  Future<void> _pickImage(ImageSource source, {bool isEdit = false, String? expenseId, VoidCallback? onImageSelected}) async {
    try {
      // Request appropriate permission based on source
      Permission permission;
      String permissionType;

      if (source == ImageSource.camera) {
        permission = Permission.camera;
        permissionType = 'Camera';
      } else {
        // For gallery, check platform
        if (Platform.isAndroid) {
          // Android 13+ uses photos permission, older versions use storage
          permission = Permission.photos;
        } else {
          permission = Permission.photos;
        }
        permissionType = 'Storage';
      }

      final hasPermission = await _requestPermission(permission, permissionType);

      if (!hasPermission) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                source == ImageSource.camera ? 'Camera permission is required to take photos' : 'Storage permission is required to access photos',
              ),
              backgroundColor: Colors.orange.shade400,
              behavior: SnackBarBehavior.floating,
              action: SnackBarAction(
                label: 'Settings',
                textColor: Colors.white,
                onPressed: () => openAppSettings(),
              ),
            ),
          );
        }
        return;
      }

      final XFile? image = await _imagePicker.pickImage(
        source: source,
        imageQuality: 100,
      );

      if (image != null) {
        setState(() {
          if (isEdit) {
            _selectedEditProofImage = File(image.path);
          } else {
            _selectedProofImage = File(image.path);
          }
        });

        // Trigger dialog rebuild if callback provided
        if (onImageSelected != null) {
          onImageSelected();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking image: ${e.toString()}'),
            backgroundColor: Colors.red.shade400,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showImageSourceDialog({bool isEdit = false, String? expenseId, VoidCallback? onImageSelected}) {
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
                color: Colors.black.withValues(alpha: .1),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Select Image Source',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade900,
                    ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Flexible(
                    child: InkWell(
                      onTap: () {
                        Navigator.pop(context);
                        _pickImage(ImageSource.camera, isEdit: isEdit, expenseId: expenseId, onImageSelected: onImageSelected);
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.camera_alt,
                              size: 32,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(height: 8),
                            const Text('Camera'),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Flexible(
                    child: InkWell(
                      onTap: () {
                        Navigator.pop(context);
                        _pickImage(ImageSource.gallery, isEdit: isEdit, expenseId: expenseId, onImageSelected: onImageSelected);
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.photo_library,
                              size: 32,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(height: 8),
                            const Text('Gallery'),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
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
            ],
          ),
        ),
      ),
    );
  }

  void _showExpenseOptions(ExpenseModel expense) {
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
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: .1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.edit_outlined,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                title: const Text('Edit Expense'),
                onTap: () {
                  Navigator.pop(context);
                  _showEditExpenseDialog(expense);
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
                    expense.proofUrl != null ? Icons.image_outlined : Icons.add_photo_alternate_outlined,
                    color: Colors.blue.shade400,
                  ),
                ),
                title: Text(expense.proofUrl != null ? 'Update Proof' : 'Add Proof'),
                onTap: () {
                  Navigator.pop(context);
                  _currentEditProofUrl = expense.proofUrl;
                  _showImageSourceDialog(isEdit: true, expenseId: expense.id);
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
                  'Delete Expense',
                  style: TextStyle(color: Colors.red.shade400),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _showDeleteExpenseDialog(expense);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditExpenseDialog(ExpenseModel expense) {
    _editTitleController.text = expense.title;
    _editAmountController.text = expense.amount.toString();
    _selectedEditProofImage = null;
    _currentEditProofUrl = expense.proofUrl;
    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: .1),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            padding: const EdgeInsets.all(28),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: .1),
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
                    'Edit Expense',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade900,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _editTitleController,
                    decoration: InputDecoration(
                      labelText: 'Title',
                      hintText: 'Enter expense title',
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
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _editAmountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Amount',
                      hintText: 'Enter amount',
                      prefixText: '₹ ',
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
                  ),
                  const SizedBox(height: 16),
                  // Proof Image Section - Compact
                  InkWell(
                    onTap: () {
                      _showImageSourceDialog(
                          isEdit: true,
                          expenseId: expense.id,
                          onImageSelected: () {
                            setDialogState(() {});
                          });
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: (_selectedEditProofImage != null || _currentEditProofUrl != null) ? Colors.blue.shade50 : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: (_selectedEditProofImage != null || _currentEditProofUrl != null) ? Colors.blue.shade300 : Colors.grey.shade300,
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            (_selectedEditProofImage != null || _currentEditProofUrl != null) ? Icons.check_circle : Icons.add_photo_alternate_outlined,
                            color: (_selectedEditProofImage != null || _currentEditProofUrl != null) ? Colors.blue.shade600 : Colors.grey.shade600,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              (_selectedEditProofImage != null || _currentEditProofUrl != null) ? 'Proof image uploaded' : 'Add/Update proof image',
                              style: TextStyle(
                                color: (_selectedEditProofImage != null || _currentEditProofUrl != null) ? Colors.blue.shade700 : Colors.grey.shade700,
                                fontSize: 14,
                                fontWeight: (_selectedEditProofImage != null || _currentEditProofUrl != null) ? FontWeight.w500 : FontWeight.normal,
                              ),
                            ),
                          ),
                          if (_selectedEditProofImage != null || _currentEditProofUrl != null)
                            IconButton(
                              icon: Icon(Icons.close, size: 18, color: Colors.red.shade400),
                              onPressed: () {
                                setState(() {
                                  _selectedEditProofImage = null;
                                  _currentEditProofUrl = null;
                                });
                                setDialogState(() {});
                              },
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            setState(() {
                              _selectedEditProofImage = null;
                              _currentEditProofUrl = null;
                            });
                            Navigator.pop(context);
                          },
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
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Theme.of(context).colorScheme.primary,
                                Theme.of(context).colorScheme.primary.withValues(alpha: .8),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Theme.of(context).colorScheme.primary.withValues(alpha: .3),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () async {
                                final title = _editTitleController.text.trim();
                                final amountText = _editAmountController.text.trim();

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
                                  setState(() => _isUploading = true);
                                  String? proofUrl;

                                  // Upload new proof image if selected
                                  if (_selectedEditProofImage != null) {
                                    // Delete old proof image first (check both expense.proofUrl and _currentEditProofUrl)
                                    final oldProofUrl = expense.proofUrl ?? _currentEditProofUrl;
                                    if (oldProofUrl != null && oldProofUrl.isNotEmpty) {
                                      try {
                                        await _cloudinaryService.deleteProofImage(oldProofUrl);
                                      } catch (e) {
                                        // Continue with upload even if deletion fails
                                      }
                                    }

                                    // Upload new proof image
                                    proofUrl = await _cloudinaryService.uploadProofImage(
                                      _selectedEditProofImage!,
                                      expense.id,
                                    );
                                  } else if (expense.proofUrl != null && _currentEditProofUrl == null) {
                                    // User removed the proof image - delete it
                                    try {
                                      await _cloudinaryService.deleteProofImage(expense.proofUrl!);
                                    } catch (e) {
                                      // Ignore deletion errors
                                    }
                                    proofUrl = null;
                                  } else {
                                    // No change to proof image - keep existing
                                    proofUrl = expense.proofUrl;
                                  }

                                  await _firestoreService.updateExpense(
                                    expense.id,
                                    title,
                                    amount,
                                    proofUrl: proofUrl,
                                  );

                                  setState(() {
                                    _isUploading = false;
                                    _selectedEditProofImage = null;
                                    _currentEditProofUrl = null;
                                  });

                                  if (mounted) {
                                    Navigator.pop(context);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: const Text('Expense updated successfully'),
                                        behavior: SnackBarBehavior.floating,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  setState(() => _isUploading = false);
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
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                alignment: Alignment.center,
                                child: _isUploading
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                        ),
                                      )
                                    : const Text(
                                        'Update',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showDeleteExpenseDialog(ExpenseModel expense) {
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
                color: Colors.black.withValues(alpha: .1),
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
                'Delete Expense',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade900,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Are you sure you want to delete "${expense.title}"? This action cannot be undone.',
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
                                                'Deleting expense...',
                                                style: TextStyle(
                                                  color: Colors.grey.shade700,
                                                  fontSize: 14,
                                                ),
                                              ),
                                              const SizedBox(height: 8),
                                              Text(
                                                expense.proofUrl != null ? 'Removing proof image' : 'Deleting expense',
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

                                // Delete proof image if exists (use expense.proofUrl directly)
                                if (expense.proofUrl != null && expense.proofUrl!.isNotEmpty) {
                                  try {
                                    await _cloudinaryService.deleteProofImage(expense.proofUrl!);
                                  } catch (e) {
                                    // Continue even if image deletion fails
                                  }
                                }

                                // Delete expense from Firestore
                                await _firestoreService.deleteExpense(expense.id);

                                setState(() => _isDeleting = false);

                                if (mounted) {
                                  Navigator.pop(context); // Close loading dialog
                                  Navigator.pop(context); // Close delete confirmation dialog
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: const Text('Expense deleted successfully'),
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

  void _showAddExpenseDialog() {
    _titleController.clear();
    _amountController.clear();
    _selectedProofImage = null;
    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: .1),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            padding: const EdgeInsets.all(28),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: .1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.add_circle_outline,
                      color: Theme.of(context).colorScheme.primary,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Add Expense',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade900,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _titleController,
                    decoration: InputDecoration(
                      labelText: 'Title',
                      hintText: 'Enter expense title',
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
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Amount',
                      hintText: 'Enter amount',
                      prefixText: '₹ ',
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
                  ),
                  const SizedBox(height: 16),
                  // Proof Image Section - Compact
                  InkWell(
                    onTap: () {
                      _showImageSourceDialog(
                          isEdit: false,
                          onImageSelected: () {
                            setDialogState(() {});
                          });
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: _selectedProofImage != null ? Colors.blue.shade50 : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _selectedProofImage != null ? Colors.blue.shade300 : Colors.grey.shade300,
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _selectedProofImage != null ? Icons.check_circle : Icons.add_photo_alternate_outlined,
                            color: _selectedProofImage != null ? Colors.blue.shade600 : Colors.grey.shade600,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              _selectedProofImage != null
                                  ? 'Proof: ${_selectedProofImage!.path.split('/').last.length > 25 ? _selectedProofImage!.path.split('/').last.substring(0, 25) + '...' : _selectedProofImage!.path.split('/').last}'
                                  : 'Add proof image (optional)',
                              style: TextStyle(
                                color: _selectedProofImage != null ? Colors.blue.shade700 : Colors.grey.shade700,
                                fontSize: 14,
                                fontWeight: _selectedProofImage != null ? FontWeight.w500 : FontWeight.normal,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                          if (_selectedProofImage != null)
                            IconButton(
                              icon: Icon(Icons.close, size: 18, color: Colors.red.shade400),
                              onPressed: () {
                                setState(() {
                                  _selectedProofImage = null;
                                });
                                setDialogState(() {});
                              },
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Row(
                    children: [
                      Flexible(
                        child: OutlinedButton(
                          onPressed: () {
                            setState(() {
                              _selectedProofImage = null;
                            });
                            Navigator.pop(context);
                          },
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
                      Flexible(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Theme.of(context).colorScheme.primary,
                                Theme.of(context).colorScheme.primary.withValues(alpha: .8),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Theme.of(context).colorScheme.primary.withValues(alpha: .3),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: _isUploading
                                  ? null
                                  : () async {
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
                                        setState(() => _isUploading = true);

                                        // Show loading dialog during upload
                                        if (mounted && _selectedProofImage != null) {
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
                                                        'Uploading proof image...',
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

                                        String? proofUrl;

                                        // Upload proof image if selected
                                        if (_selectedProofImage != null) {
                                          try {
                                            // Create expense first to get ID
                                            final expenseId = await _firestoreService.addExpense(
                                              widget.group.id,
                                              title,
                                              amount,
                                            );

                                            // Upload proof image
                                            proofUrl = await _cloudinaryService.uploadProofImage(
                                              _selectedProofImage!,
                                              expenseId,
                                            );

                                            if (proofUrl == null || proofUrl.isEmpty) {
                                              throw Exception('Failed to upload image: No URL returned');
                                            }

                                            // Update expense with proof URL
                                            await _firestoreService.updateExpense(
                                              expenseId,
                                              title,
                                              amount,
                                              proofUrl: proofUrl,
                                            );
                                          } catch (uploadError) {
                                            // Close loading dialog if open
                                            if (mounted && _selectedProofImage != null) {
                                              Navigator.pop(context);
                                            }
                                            throw Exception('Failed to upload proof image: ${uploadError.toString()}');
                                          }
                                        } else {
                                          await _firestoreService.addExpense(
                                            widget.group.id,
                                            title,
                                            amount,
                                          );
                                        }

                                        // Close loading dialog if open
                                        final hadProofImage = _selectedProofImage != null;
                                        if (mounted && hadProofImage) {
                                          Navigator.pop(context);
                                        }

                                        setState(() {
                                          _isUploading = false;
                                          _selectedProofImage = null;
                                        });

                                        if (mounted) {
                                          Navigator.pop(context);
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                hadProofImage && proofUrl != null ? 'Expense and proof image added successfully' : 'Expense added successfully',
                                              ),
                                              behavior: SnackBarBehavior.floating,
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                            ),
                                          );
                                        }
                                      } catch (e) {
                                        setState(() => _isUploading = false);
                                        // Close loading dialog if open
                                        if (mounted) {
                                          try {
                                            Navigator.pop(context);
                                          } catch (_) {}
                                        }
                                        if (mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text('Error: ${e.toString()}'),
                                              backgroundColor: Colors.red.shade400,
                                              behavior: SnackBarBehavior.floating,
                                              duration: const Duration(seconds: 4),
                                            ),
                                          );
                                        }
                                      }
                                    },
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                alignment: Alignment.center,
                                child: _isUploading
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                        ),
                                      )
                                    : const Text(
                                        'Add',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(symbol: '₹', decimalDigits: 2);

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        title: Text(
          widget.group.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      body: Column(
        children: [
          // Total expenses card with gradient
          StreamBuilder<List<ExpenseModel>>(
            stream: _firestoreService.getExpenses(widget.group.id),
            builder: (context, snapshot) {
              double total = 0;
              if (snapshot.hasData) {
                total = snapshot.data!.fold(0, (sum, expense) => sum + expense.amount);
              }

              return Container(
                width: double.infinity,
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Theme.of(context).colorScheme.primary,
                      Theme.of(context).colorScheme.primary.withValues(alpha: .8),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: .3),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.account_balance_wallet_rounded,
                          color: Colors.white.withValues(alpha: .9),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Total Expenses',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: .9),
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      currencyFormat.format(total),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -1,
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
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
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
                          'Error loading expenses',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final expenses = snapshot.data ?? [];

                if (expenses.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.receipt_long_rounded,
                            size: 64,
                            color: Colors.grey.shade400,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'No expenses yet',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                color: Colors.grey.shade700,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tap + to add your first expense',
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
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: expenses.length,
                  itemBuilder: (context, index) {
                    final expense = expenses[index];
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
                              elevation: 1,
                              child: InkWell(
                                onLongPress: () {
                                  _showExpenseOptions(expense);
                                },
                                borderRadius: BorderRadius.circular(16),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 48,
                                        height: 48,
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              Theme.of(context).colorScheme.primary,
                                              Theme.of(context).colorScheme.primary.withValues(alpha: .7),
                                            ],
                                          ),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: const Icon(
                                          Icons.currency_rupee_rounded,
                                          color: Colors.white,
                                          size: 24,
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    expense.title,
                                                    style: const TextStyle(
                                                      fontWeight: FontWeight.w600,
                                                      fontSize: 16,
                                                    ),
                                                  ),
                                                ),
                                                if (expense.proofUrl != null)
                                                  Container(
                                                    padding: const EdgeInsets.all(4),
                                                    decoration: BoxDecoration(
                                                      color: Colors.blue.shade50,
                                                      borderRadius: BorderRadius.circular(4),
                                                    ),
                                                    child: Icon(
                                                      Icons.image,
                                                      size: 16,
                                                      color: Colors.blue.shade600,
                                                    ),
                                                  ),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              _formatDate(expense.createdAt),
                                              style: TextStyle(
                                                color: Colors.grey.shade600,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            currencyFormat.format(expense.amount),
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 18,
                                              color: Theme.of(context).colorScheme.primary,
                                            ),
                                          ),
                                          if (expense.proofUrl != null) const SizedBox(height: 4),
                                          if (expense.proofUrl != null)
                                            InkWell(
                                              onTap: () => _showProofImage(expense.proofUrl!),
                                              borderRadius: BorderRadius.circular(4),
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: Colors.blue.shade50,
                                                  borderRadius: BorderRadius.circular(4),
                                                  border: Border.all(
                                                    color: Colors.blue.shade300,
                                                    width: 1,
                                                  ),
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Icon(
                                                      Icons.image_outlined,
                                                      size: 12,
                                                      color: Colors.blue.shade700,
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      'View proof',
                                                      style: TextStyle(
                                                        fontSize: 10,
                                                        color: Colors.blue.shade700,
                                                        fontWeight: FontWeight.w500,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                        ],
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
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddExpenseDialog,
        icon: const Icon(Icons.add),
        label: const Text('Add Expense'),
        elevation: 4,
      ),
    );
  }

  String _formatDate(DateTime date) {
    return DateFormat('MMM dd, yyyy').format(date);
  }

  void _showProofImage(String imageUrl) {
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
                color: Colors.black.withValues(alpha: .2),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.image_outlined,
                      color: Theme.of(context).colorScheme.primary,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Proof Image',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade900,
                            ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: Colors.grey.shade600),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              // Image
              Flexible(
                child: InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 3.0,
                  child: Container(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.7,
                    ),
                    child: ClipRRect(
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(24),
                        bottomRight: Radius.circular(24),
                      ),
                      child: Image.network(
                        imageUrl,
                        fit: BoxFit.contain,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Container(
                            height: 300,
                            alignment: Alignment.center,
                            child: CircularProgressIndicator(
                              value: loadingProgress.expectedTotalBytes != null ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes! : null,
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            height: 300,
                            alignment: Alignment.center,
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.error_outline,
                                  size: 48,
                                  color: Colors.red.shade300,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Failed to load image',
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
