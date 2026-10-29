import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract interface class PreferencesStore {
  Future<ThemeMode> readThemeMode();
  Future<void> writeThemeMode(ThemeMode value);
  Future<bool> readBiometricEnabled();
  Future<void> writeBiometricEnabled(bool value);
  Future<String?> readLastOrganizationId();
  Future<void> writeLastOrganizationId(String? value);
  Future<void> clearSessionSelection();
}

final class AppPreferences implements PreferencesStore {
  AppPreferences({Future<SharedPreferences> Function()? loadPreferences})
    : _loadPreferences = loadPreferences ?? SharedPreferences.getInstance;

  static const String _themeKey = 'theme_mode_v1';
  static const String _biometricKey = 'biometric_enabled_v1';
  static const String _organizationKey = 'last_organization_id_v1';

  final Future<SharedPreferences> Function() _loadPreferences;
  Future<SharedPreferences> get _preferences => _loadPreferences();

  @override
  Future<ThemeMode> readThemeMode() async {
    final String? raw = (await _preferences).getString(_themeKey);
    return ThemeMode.values.firstWhere(
      (ThemeMode value) => value.name == raw,
      orElse: () => ThemeMode.system,
    );
  }

  @override
  Future<void> writeThemeMode(ThemeMode value) async {
    await (await _preferences).setString(_themeKey, value.name);
  }

  @override
  Future<bool> readBiometricEnabled() async =>
      (await _preferences).getBool(_biometricKey) ?? false;

  @override
  Future<void> writeBiometricEnabled(bool value) async {
    await (await _preferences).setBool(_biometricKey, value);
  }

  @override
  Future<String?> readLastOrganizationId() async {
    final preferences = await _preferences;
    // Legacy SharedPreferences changes its cache before the platform confirms a
    // write. Read the stored value so a failed write cannot become a selection.
    await preferences.reload();
    return preferences.getString(_organizationKey);
  }

  @override
  Future<void> writeLastOrganizationId(String? value) async {
    final SharedPreferences preferences = await _preferences;
    final stored = value == null
        ? await preferences.remove(_organizationKey)
        : await preferences.setString(_organizationKey, value);
    if (!stored) {
      throw StateError('Could not save organization selection.');
    }
  }

  @override
  Future<void> clearSessionSelection() => writeLastOrganizationId(null);
}
