import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:developer' as developer;
import '../services/secure_storage_service.dart';
import '../services/biometric_service.dart';

class PinSetupScreen extends StatefulWidget {
  final VoidCallback? onPinSetupComplete;

  const PinSetupScreen({super.key, this.onPinSetupComplete});

  @override
  State<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends State<PinSetupScreen> {
  final List<TextEditingController> _controllers = List.generate(
    4,
    (index) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(4, (index) => FocusNode());
  String _enteredPin = '';
  String _confirmPin = '';
  bool _isConfirming = false;
  bool _biometricAvailable = false;
  final _biometricService = BiometricService();

  @override
  void initState() {
    super.initState();
    _checkBiometricAvailability();
    _focusNodes[0].requestFocus();
  }

  Future<void> _checkBiometricAvailability() async {
    developer.log('bioAuth: Checking biometric availability in PIN setup', name: 'bioAuth');
    final isSupported = await _biometricService.isDeviceSupported();
    final canCheck = await _biometricService.canCheckBiometrics();
    final isAvailable = isSupported && canCheck;
    developer.log('bioAuth: PIN setup - isSupported: $isSupported, canCheck: $canCheck, available: $isAvailable', name: 'bioAuth');
    setState(() {
      _biometricAvailable = isAvailable;
    });
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _onPinChanged(int index, String value) {
    if (value.length == 1) {
      setState(() {
        if (!_isConfirming) {
          _enteredPin += value;
        } else {
          _confirmPin += value;
        }
      });

      if (index < 3) {
        _focusNodes[index + 1].requestFocus();
      } else {
        _focusNodes[index].unfocus();
        _handlePinComplete();
      }
    } else if (value.isEmpty && index > 0) {
      setState(() {
        if (!_isConfirming) {
          if (_enteredPin.isNotEmpty) {
            _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
          }
        } else {
          if (_confirmPin.isNotEmpty) {
            _confirmPin = _confirmPin.substring(0, _confirmPin.length - 1);
          }
        }
      });
      _focusNodes[index - 1].requestFocus();
    }
  }

  void _handlePinComplete() {
    if (!_isConfirming) {
      if (_enteredPin.length == 4) {
        setState(() {
          _isConfirming = true;
          _confirmPin = '';
        });
        // Clear all fields and refocus first
        for (var controller in _controllers) {
          controller.clear();
        }
        _focusNodes[0].requestFocus();
      }
    } else {
      if (_confirmPin.length == 4) {
        if (_enteredPin == _confirmPin) {
          _savePin();
        } else {
          _showError('PINs do not match. Please try again.');
          setState(() {
            _enteredPin = '';
            _confirmPin = '';
            _isConfirming = false;
          });
          for (var controller in _controllers) {
            controller.clear();
          }
          _focusNodes[0].requestFocus();
        }
      }
    }
  }

  Future<void> _savePin() async {
    developer.log('bioAuth: Saving PIN', name: 'bioAuth');
    await SecureStorageService().storePin(_enteredPin);

    // Ask user if they want to use biometric
    if (_biometricAvailable && mounted) {
      developer.log('bioAuth: Biometric available, showing confirmation dialog', name: 'bioAuth');
      final useBiometric = await _showBiometricConfirmationDialog();
      developer.log('bioAuth: User choice = $useBiometric', name: 'bioAuth');

      if (useBiometric == true) {
        developer.log('bioAuth: User chose to enable biometric, testing authentication...', name: 'bioAuth');
        // Test biometric to make sure it works
        final testResult = await _biometricService.authenticate();
        developer.log('bioAuth: Test authentication result = $testResult', name: 'bioAuth');

        if (testResult) {
          developer.log('bioAuth: Test successful, enabling biometric', name: 'bioAuth');
          await SecureStorageService().setBiometricEnabled(true);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Biometric authentication enabled'),
              ),
            );
          }
        } else {
          developer.log('bioAuth: Test failed, biometric not enabled', name: 'bioAuth');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Biometric authentication failed. You can enable it later in settings.'),
              ),
            );
          }
        }
      } else {
        developer.log('bioAuth: User chose not to use biometric', name: 'bioAuth');
      }
    } else {
      developer.log('bioAuth: Biometric not available or widget not mounted', name: 'bioAuth');
    }

    if (mounted) {
      if (widget.onPinSetupComplete != null) {
        widget.onPinSetupComplete!();
      } else {
        Navigator.of(context).pop(true);
      }
    }
  }

  Future<bool?> _showBiometricConfirmationDialog() async {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Use Biometric Authentication?'),
        content: const Text(
          'Do you want to use fingerprint or face ID to unlock the app? You can still use your PIN if biometric fails.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('No, use PIN only'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Yes, use biometric'),
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isConfirming ? 'Confirm PIN' : 'Set PIN'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.lock_outline,
                size: 80,
                color: Colors.deepPurple,
              ),
              const SizedBox(height: 32),
              Text(
                _isConfirming ? 'Confirm your PIN' : 'Create a 4-digit PIN',
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, (index) {
                  return Container(
                    width: 60,
                    height: 60,
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    child: TextField(
                      controller: _controllers[index],
                      focusNode: _focusNodes[index],
                      textAlign: TextAlign.center,
                      keyboardType: TextInputType.number,
                      maxLength: 1,
                      obscureText: true,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      decoration: InputDecoration(
                        counterText: '',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade100,
                      ),
                      onChanged: (value) => _onPinChanged(index, value),
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
