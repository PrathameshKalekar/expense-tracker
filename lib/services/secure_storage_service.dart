import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  static const String _pinKey = 'user_pin';
  static const String _biometricEnabledKey = 'biometric_enabled';
  static const String _pinStoredInBackendKey = 'pin_in_backend';

  // Store PIN locally
  Future<void> storePin(String pin) async {
    await _storage.write(key: _pinKey, value: pin);
  }

  // Get PIN from local storage
  Future<String?> getPin() async {
    return await _storage.read(key: _pinKey);
  }

  // Check if PIN is set
  Future<bool> hasPin() async {
    final pin = await getPin();
    return pin != null && pin.isNotEmpty;
  }

  // Delete PIN
  Future<void> deletePin() async {
    await _storage.delete(key: _pinKey);
  }

  // Store biometric enabled status
  Future<void> setBiometricEnabled(bool enabled) async {
    await _storage.write(key: _biometricEnabledKey, value: enabled.toString());
  }

  // Check if biometric is enabled
  Future<bool> isBiometricEnabled() async {
    final value = await _storage.read(key: _biometricEnabledKey);
    return value == 'true';
  }

  // Store PIN in backend status
  Future<void> setPinStoredInBackend(bool stored) async {
    await _storage.write(key: _pinStoredInBackendKey, value: stored.toString());
  }

  // Check if PIN is stored in backend
  Future<bool> isPinStoredInBackend() async {
    final value = await _storage.read(key: _pinStoredInBackendKey);
    return value == 'true';
  }
}

