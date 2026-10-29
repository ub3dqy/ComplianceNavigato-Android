import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/auth/auth_state.dart';
import '../../core/routing/app_router.dart';
import '../../core/routing/questionnaire_exit_guard.dart';
import 'app_updates.dart';
import 'update_dialog.dart';

/// A quiet check after login/on return; installation always requires a tap.
final class AutomaticAppUpdates extends ConsumerStatefulWidget {
  const AutomaticAppUpdates({super.key, required this.child});
  final Widget child;
  @override
  ConsumerState<AutomaticAppUpdates> createState() =>
      _AutomaticAppUpdatesState();
}

final class _AutomaticAppUpdatesState extends ConsumerState<AutomaticAppUpdates>
    with WidgetsBindingObserver {
  bool _checking = false;
  DateTime? _nextCheck;
  UpdateOffer? _pending;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_check());
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_check());
  }

  Future<void> _check() async {
    if (!mounted ||
        _checking ||
        ref.read(authControllerProvider).phase != AuthPhase.authenticated) {
      return;
    }
    final service = ref.read(appUpdatesProvider);
    if (service.presenting) return;
    _checking = true;
    try {
      if (_pending == null) {
        if (_nextCheck?.isAfter(DateTime.now()) ?? false) return;
        _pending = await service.check();
        _nextCheck = DateTime.now().add(const Duration(hours: 6));
      }
      if (!mounted ||
          _pending == null ||
          service.presenting ||
          WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed ||
          ref.read(authControllerProvider).phase != AuthPhase.authenticated) {
        return;
      }
      final offer = _pending!;
      // A form owns unsaved input. Offer later instead of interrupting editing.
      if (ref.read(questionnaireExitGuardProvider).confirm != null) return;
      final navigatorContext = ref
          .read(rootNavigatorKeyProvider)
          .currentState
          ?.overlay
          ?.context;
      if (navigatorContext == null || !navigatorContext.mounted) return;
      _pending = null;
      if (service.lastPresentedVersion != offer.versionCode) {
        await showAppUpdates(
          navigatorContext,
          service,
          offer: offer,
          beforeInstall: () async =>
              await ref.read(questionnaireExitGuardProvider).confirm?.call() ??
              true,
        );
      }
    } on Object {
      // Network failure is not evidence of an up-to-date app. Manual checks
      // retain a visible error/retry; background checks retry after 15 minutes.
      _nextCheck = DateTime.now().add(const Duration(minutes: 15));
    } finally {
      _checking = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AuthState>(authControllerProvider, (previous, next) {
      if (next.phase == AuthPhase.authenticated &&
          previous?.phase != next.phase) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) unawaited(_check());
        });
      }
    });
    return widget.child;
  }
}
