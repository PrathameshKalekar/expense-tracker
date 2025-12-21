import 'package:local_auth/local_auth.dart';
import 'package:flutter/services.dart';

class BiometricService {
  final LocalAuthentication _localAuth = LocalAuthentication();

  // Check if device supports biometric authentication
  Future<bool> isDeviceSupported() async {
    try {
      return await _localAuth.isDeviceSupported();
    } catch (e) {
      return false;
    }
  }

  // Check available biometric types
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } catch (e) {
      return [];
    }
  }

  // Check if biometrics are available
  Future<bool> canCheckBiometrics() async {
    try {
      return await _localAuth.canCheckBiometrics;
    } catch (e) {
      return false;
    }
  }

  // Check if device can authenticate (biometrics or device-level auth)
  Future<bool> canAuthenticate() async {
    try {
      final canAuthenticateWithBiometrics = await _localAuth.canCheckBiometrics;
      final canAuthenticate = canAuthenticateWithBiometrics || await _localAuth.isDeviceSupported();
      return canAuthenticate;
    } catch (e) {
      return false;
    }
  }

  // Authenticate with biometrics
  Future<bool> authenticate() async {
    try {
      // First check if device supports biometrics
      final isSupported = await isDeviceSupported();
      if (!isSupported) {
        return false;
      }

      // Check if biometrics can be checked
      final isAvailable = await canCheckBiometrics();
      if (!isAvailable) {
        return false;
      }

      // Get available biometric types
      final availableBiometrics = await getAvailableBiometrics();
      if (availableBiometrics.isEmpty) {
        return false;
      }

      // Authenticate with biometrics
      final didAuthenticate = await _localAuth.authenticate(
        localizedReason: 'Please authenticate to access your expenses',
        options: const AuthenticationOptions(
          biometricOnly: false, // Allow fallback to device credentials
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );

      return didAuthenticate;
    } on PlatformException {
      // Handle specific PlatformException errors
      return false;
    } catch (_) {
      return false;
    }
  }

  // Stop authentication (if needed)
  Future<void> stopAuthentication() async {
    await _localAuth.stopAuthentication();
  }
}
