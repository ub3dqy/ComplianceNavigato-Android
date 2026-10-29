import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';

final class ThemeController extends AsyncNotifier<ThemeMode> {
  @override
  Future<ThemeMode> build() => ref.read(preferencesProvider).readThemeMode();

  Future<void> setThemeMode(ThemeMode value) async {
    state = AsyncData<ThemeMode>(value);
    await ref.read(preferencesProvider).writeThemeMode(value);
  }
}
