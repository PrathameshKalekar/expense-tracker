import 'package:flutter/material.dart';
import '../services/secure_storage_service.dart';
import 'pin_setup_screen.dart';
import 'pin_auth_screen.dart';
import 'groups_screen.dart';

class PinWrapper extends StatefulWidget {
  const PinWrapper({super.key});

  @override
  State<PinWrapper> createState() => _PinWrapperState();
}

class _PinWrapperState extends State<PinWrapper> {
  bool _isAuthenticated = false;
  bool _isChecking = true;
  bool _needsPinSetup = false;

  @override
  void initState() {
    super.initState();
    _checkPinStatus();
  }

  Future<void> _checkPinStatus() async {
    final hasPin = await SecureStorageService().hasPin();
    setState(() {
      _needsPinSetup = !hasPin;
      _isChecking = false;
    });

    if (hasPin) {
      _showPinAuth();
    }
  }

  Future<void> _showPinAuth() async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const PinAuthScreen(),
        fullscreenDialog: true,
      ),
    );

    if (result == true) {
      setState(() {
        _isAuthenticated = true;
      });
    }
  }

  Future<void> _handlePinSetupComplete() async {
    setState(() {
      _needsPinSetup = false;
      _isAuthenticated = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isChecking) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_needsPinSetup) {
      return PinSetupScreen(
        onPinSetupComplete: _handlePinSetupComplete,
      );
    }

    if (!_isAuthenticated) {
      return const PinAuthScreen();
    }

    return const GroupsScreen();
  }
}
