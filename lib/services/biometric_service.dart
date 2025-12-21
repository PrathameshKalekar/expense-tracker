import 'package:local_auth/local_auth.dart';
import 'package:flutter/services.dart';
import 'dart:developer' as developer;

class BiometricService {
  final LocalAuthentication _localAuth = LocalAuthentication();

  // Check if device supports biometric authentication
  Future<bool> isDeviceSupported() async {
    try {
      final result = await _localAuth.isDeviceSupported();
      developer.log('bioAuth: isDeviceSupported = $result', name: 'bioAuth');
      return result;
    } catch (e) {
      developer.log('bioAuth: isDeviceSupported error = $e', name: 'bioAuth', error: e);
      return false;
    }
  }

  // Check available biometric types
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      final result = await _localAuth.getAvailableBiometrics();
      developer.log('bioAuth: getAvailableBiometrics = $result', name: 'bioAuth');
      return result;
    } catch (e) {
      developer.log('bioAuth: getAvailableBiometrics error = $e', name: 'bioAuth', error: e);
      return [];
    }
  }

  // Check if biometrics are available
  Future<bool> canCheckBiometrics() async {
    try {
      final result = await _localAuth.canCheckBiometrics;
      developer.log('bioAuth: canCheckBiometrics = $result', name: 'bioAuth');
      return result;
    } catch (e) {
      developer.log('bioAuth: canCheckBiometrics error = $e', name: 'bioAuth', error: e);
      return false;
    }
  }

  // Check if device can authenticate (biometrics or device-level auth)
  Future<bool> canAuthenticate() async {
    try {
      final canAuthenticateWithBiometrics = await _localAuth.canCheckBiometrics;
      final canAuthenticate = canAuthenticateWithBiometrics || await _localAuth.isDeviceSupported();
      developer.log('bioAuth: canAuthenticate = $canAuthenticate (withBiometrics: $canAuthenticateWithBiometrics)', name: 'bioAuth');
      return canAuthenticate;
    } catch (e) {
      developer.log('bioAuth: canAuthenticate error = $e', name: 'bioAuth', error: e);
      return false;
    }
  }

  // Authenticate with biometrics
  Future<bool> authenticate() async {
    developer.log('bioAuth: Starting authentication', name: 'bioAuth');
    try {
      // First check if device supports biometrics
      developer.log('bioAuth: Checking device support...', name: 'bioAuth');
      final isSupported = await isDeviceSupported();
      if (!isSupported) {
        developer.log('bioAuth: Device does not support biometrics', name: 'bioAuth');
        return false;
      }
      developer.log('bioAuth: Device supports biometrics', name: 'bioAuth');

      // Check if biometrics can be checked
      developer.log('bioAuth: Checking if biometrics can be checked...', name: 'bioAuth');
      final isAvailable = await canCheckBiometrics();
      if (!isAvailable) {
        developer.log('bioAuth: Cannot check biometrics', name: 'bioAuth');
        return false;
      }
      developer.log('bioAuth: Can check biometrics', name: 'bioAuth');

      // Get available biometric types
      developer.log('bioAuth: Getting available biometric types...', name: 'bioAuth');
      final availableBiometrics = await getAvailableBiometrics();
      if (availableBiometrics.isEmpty) {
        developer.log('bioAuth: No biometric types available', name: 'bioAuth');
        return false;
      }
      developer.log('bioAuth: Available biometrics: $availableBiometrics', name: 'bioAuth');

      // Authenticate with biometrics
      developer.log('bioAuth: Requesting biometric authentication...', name: 'bioAuth');
      final didAuthenticate = await _localAuth.authenticate(
        localizedReason: 'Please authenticate to access your expenses',
        options: const AuthenticationOptions(
          biometricOnly: false, // Allow fallback to device credentials
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );

      developer.log('bioAuth: Authentication result = $didAuthenticate', name: 'bioAuth');
      return didAuthenticate;
    } on PlatformException catch (e) {
      // Handle specific PlatformException errors (local_auth throws PlatformException)
      developer.log('bioAuth: PlatformException - code: ${e.code}, message: ${e.message}', name: 'bioAuth', error: e);

      // Map error codes based on local_auth documentation
      switch (e.code) {
        case 'NotAvailable':
          developer.log('bioAuth: Biometric not available', name: 'bioAuth');
          break;
        case 'NotEnrolled':
          developer.log('bioAuth: No biometrics enrolled', name: 'bioAuth');
          break;
        case 'LockedOut':
        case 'TemporaryLockout':
          developer.log('bioAuth: Temporarily locked out', name: 'bioAuth');
          break;
        case 'PermanentlyLockedOut':
          developer.log('bioAuth: Permanently locked out', name: 'bioAuth');
          break;
        case 'PasscodeNotSet':
          developer.log('bioAuth: Passcode not set', name: 'bioAuth');
          break;
        case 'UserCancel':
          developer.log('bioAuth: User cancelled authentication', name: 'bioAuth');
          break;
        case 'AuthenticationFailed':
          developer.log('bioAuth: Authentication failed', name: 'bioAuth');
          break;
        case 'InvalidContext':
          developer.log('bioAuth: Invalid context', name: 'bioAuth');
          break;
        default:
          developer.log('bioAuth: Unhandled error code: ${e.code}', name: 'bioAuth');
      }
      return false;
    } catch (e, stackTrace) {
      developer.log('bioAuth: Unexpected error during authentication', name: 'bioAuth', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  // Stop authentication (if needed)
  Future<void> stopAuthentication() async {
    await _localAuth.stopAuthentication();
  }
}
