import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:developer' as developer;
import '../services/secure_storage_service.dart';
import '../services/biometric_service.dart';

class PinAuthScreen extends StatefulWidget {
  const PinAuthScreen({super.key});

  @override
  State<PinAuthScreen> createState() => _PinAuthScreenState();
}

class _PinAuthScreenState extends State<PinAuthScreen> {
  final List<TextEditingController> _controllers = List.generate(
    4,
    (index) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(4, (index) => FocusNode());
  String _enteredPin = '';
  bool _isLoading = false;
  final _biometricService = BiometricService();
  bool _biometricAvailable = false;
  bool _biometricEnabled = false;

  @override
  void initState() {
    super.initState();
    _initializeAuth();
  }

  Future<void> _initializeAuth() async {
    developer.log('bioAuth: Initializing authentication in PIN auth screen', name: 'bioAuth');
    await _checkBiometricSettings();

    // If biometric is available and enabled, try it first
    if (_biometricAvailable && _biometricEnabled) {
      developer.log('bioAuth: Biometric available and enabled, attempting authentication', name: 'bioAuth');
      await Future.delayed(const Duration(milliseconds: 300));
      final authenticated = await tryBiometricAuth();

      if (!authenticated && mounted) {
        developer.log('bioAuth: Authentication failed, focusing on PIN input', name: 'bioAuth');
        // If biometric failed, focus on PIN input
        _focusNodes[0].requestFocus();
      }
    } else {
      developer.log('bioAuth: Biometric not available or not enabled, focusing on PIN', name: 'bioAuth');
      // If biometric not available, focus on PIN
      _focusNodes[0].requestFocus();
    }
  }

  Future<void> _checkBiometricSettings() async {
    developer.log('bioAuth: Checking biometric settings in PIN auth screen', name: 'bioAuth');
    final isSupported = await _biometricService.isDeviceSupported();
    final canCheck = await _biometricService.canCheckBiometrics();
    final isEnabled = await SecureStorageService().isBiometricEnabled();

    final isAvailable = isSupported && canCheck;
    developer.log('bioAuth: PIN auth - isSupported: $isSupported, canCheck: $canCheck, isEnabled: $isEnabled, available: $isAvailable', name: 'bioAuth');

    setState(() {
      _biometricAvailable = isAvailable;
      _biometricEnabled = isEnabled;
    });
  }

  Future<bool> tryBiometricAuth() async {
    developer.log('bioAuth: Attempting biometric authentication', name: 'bioAuth');
    if (!_biometricAvailable || !_biometricEnabled) {
      developer.log('bioAuth: Cannot authenticate - available: $_biometricAvailable, enabled: $_biometricEnabled', name: 'bioAuth');
      return false;
    }

    try {
      // Show a brief message that biometric is being requested
      developer.log('bioAuth: Calling biometric service authenticate', name: 'bioAuth');
      final authenticated = await _biometricService.authenticate();
      developer.log('bioAuth: Authentication returned: $authenticated', name: 'bioAuth');

      if (authenticated && mounted) {
        developer.log('bioAuth: Authentication successful, navigating away', name: 'bioAuth');
        Navigator.of(context).pop(true);
        return true;
      } else if (mounted) {
        developer.log('bioAuth: Authentication failed or cancelled', name: 'bioAuth');
        // If user cancelled or failed, show message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Biometric authentication cancelled or failed. Please enter PIN.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
      return false;
    } catch (e, stackTrace) {
      developer.log('bioAuth: Exception during authentication', name: 'bioAuth', error: e, stackTrace: stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Biometric error: ${e.toString()}'),
          ),
        );
      }
      return false;
    }
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
        _enteredPin += value;
      });

      if (index < 3) {
        _focusNodes[index + 1].requestFocus();
      } else {
        _focusNodes[index].unfocus();
        _verifyPin();
      }
    } else if (value.isEmpty && index > 0) {
      setState(() {
        if (_enteredPin.isNotEmpty) {
          _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
        }
      });
      _focusNodes[index - 1].requestFocus();
    }
  }

  Future<void> _verifyPin() async {
    if (_enteredPin.length != 4) return;

    setState(() => _isLoading = true);

    final storedPin = await SecureStorageService().getPin();

    await Future.delayed(const Duration(milliseconds: 300));

    if (storedPin == _enteredPin) {
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } else {
      setState(() {
        _isLoading = false;
        _enteredPin = '';
        for (var controller in _controllers) {
          controller.clear();
        }
        _focusNodes[0].requestFocus();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Incorrect PIN. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                'Enter PIN',
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              if (_isLoading)
                const CircularProgressIndicator()
              else
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(4, (index) {
                    final isFilled = _enteredPin.length > index;
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
                          fillColor: isFilled ? Colors.deepPurple.shade100 : Colors.grey.shade100,
                        ),
                        onChanged: (value) => _onPinChanged(index, value),
                      ),
                    );
                  }),
                ),
              if (_biometricAvailable && _biometricEnabled) ...[
                const SizedBox(height: 32),
                IconButton(
                  icon: const Icon(Icons.fingerprint, size: 48),
                  onPressed: () async {
                    await tryBiometricAuth();
                  },
                  tooltip: 'Use Biometric',
                ),
                const Text('Or use biometric'),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
