import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/auth/auth_state.dart';
import '../../core/network/api_models.dart';

final canCreateOrganizationProvider = Provider<bool>((ref) {
  final auth = ref.watch(authControllerProvider);
  if (auth.phase != AuthPhase.authenticated || auth.user == null) return false;
  if (auth.user!.isSuperuser) return true;
  final selection = ref.watch(organizationControllerProvider);
  final value = selection.value;
  return !selection.isLoading &&
      !selection.hasError &&
      value != null &&
      !value.isRefreshing &&
      value.refreshError == null &&
      value.items.any((item) => item.role == 'owner');
});

final class OrganizationSelection {
  const OrganizationSelection({
    required this.items,
    required this.current,
    this.isRefreshing = false,
    this.refreshError,
  });

  final List<OrganizationSummaryDto> items;
  final OrganizationSummaryDto? current;
  final bool isRefreshing;
  final Object? refreshError;
}

final class OrganizationController
    extends AsyncNotifier<OrganizationSelection> {
  int _operation = 0;
  bool _disposed = false;
  Future<void>? _preferencesTail;

  @override
  OrganizationSelection build() {
    ref.onDispose(() {
      _disposed = true;
      _operation++;
    });
    return const OrganizationSelection(
      items: <OrganizationSummaryDto>[],
      current: null,
    );
  }

  bool _isCurrent(int operation) => !_disposed && operation == _operation;

  Future<void> _queuePreference(Future<void> Function() operation) async {
    final previous = _preferencesTail;
    final completion = Completer<void>();
    _preferencesTail = completion.future;
    try {
      if (previous != null) await previous;
      await operation();
    } finally {
      completion.complete();
      if (identical(_preferencesTail, completion.future)) {
        _preferencesTail = null;
      }
    }
  }

  void _invalidateContext() {
    ref.read(organizationGenerationProvider.notifier).advance();
    ref.read(apiClientProvider).cancelInFlightRequests();
  }

  Future<void> load() async {
    final operation = ++_operation;
    final previous = state.value;
    OrganizationSelection? safePrevious = previous;
    state = previous == null
        ? const AsyncLoading<OrganizationSelection>()
        : AsyncData(
            OrganizationSelection(
              items: previous.items,
              current: previous.current,
              isRefreshing: true,
            ),
          );
    try {
      final List<OrganizationSummaryDto> items = await ref
          .read(repositoryProvider)
          .organizations();
      if (!_isCurrent(operation)) return;
      final String? remembered = await ref
          .read(preferencesProvider)
          .readLastOrganizationId();
      if (!_isCurrent(operation)) return;
      final current = _selectValid(items, previous?.current?.id ?? remembered);
      safePrevious = OrganizationSelection(
        items: items,
        current: items
            .where((item) => item.id == previous?.current?.id)
            .firstOrNull,
      );
      if (current?.id != previous?.current?.id) {
        state = const AsyncLoading<OrganizationSelection>();
        _invalidateContext();
        await ref.read(transientFileServiceProvider).purge();
        if (!_isCurrent(operation)) return;
      }
      final preferences = ref.read(preferencesProvider);
      await _queuePreference(() async {
        if (_isCurrent(operation)) {
          await preferences.writeLastOrganizationId(current?.id);
        }
      });
      if (_isCurrent(operation)) {
        state = AsyncData(
          OrganizationSelection(items: items, current: current),
        );
      }
    } on Object catch (error, stackTrace) {
      if (_isCurrent(operation)) {
        state = safePrevious == null
            ? AsyncError<OrganizationSelection>(error, stackTrace)
            : AsyncData(
                OrganizationSelection(
                  items: safePrevious.items,
                  current: safePrevious.current,
                  refreshError: error,
                ),
              );
      }
    }
  }

  Future<bool> select(String organizationId) async {
    final OrganizationSelection? selection = state.value;
    if (selection == null) {
      return false;
    }
    final OrganizationSummaryDto? selected = selection.items
        .where((OrganizationSummaryDto item) => item.id == organizationId)
        .firstOrNull;
    if (selected == null) {
      return false;
    }
    if (selection.current?.id == selected.id) {
      return true;
    }
    final operation = ++_operation;
    state = const AsyncLoading<OrganizationSelection>();
    _invalidateContext();
    try {
      await ref.read(transientFileServiceProvider).purge();
      if (!_isCurrent(operation)) return false;
      final preferences = ref.read(preferencesProvider);
      await _queuePreference(() async {
        if (_isCurrent(operation)) {
          await preferences.writeLastOrganizationId(selected.id);
        }
      });
      if (!_isCurrent(operation)) return false;
      state = AsyncData<OrganizationSelection>(
        OrganizationSelection(items: selection.items, current: selected),
      );
      return true;
    } on Object {
      if (_isCurrent(operation)) {
        state = AsyncData<OrganizationSelection>(selection);
      }
      return false;
    }
  }

  /// The API has already created the card and its owner membership. Never POST
  /// again merely because selecting its local context failed.
  Future<bool> acceptCreated(OrganizationDto organization) async {
    _operation++;
    final previous = state.value;
    final items =
        <OrganizationSummaryDto>[
          ...?previous?.items.where((item) => item.id != organization.id),
          OrganizationSummaryDto(
            id: organization.id,
            shortName: organization.shortName,
            kind: organization.kind,
            role: 'owner',
            updatedAt: organization.updatedAt,
          ),
        ]..sort(
          (a, b) =>
              a.shortName.toLowerCase().compareTo(b.shortName.toLowerCase()),
        );
    state = AsyncData(
      OrganizationSelection(items: items, current: previous?.current),
    );
    return select(organization.id);
  }

  Future<void> clearStoredSelection() {
    final preferences = ref.read(preferencesProvider);
    return _queuePreference(preferences.clearSessionSelection);
  }

  Future<void> clear() async {
    clearInMemory();
    await clearStoredSelection();
  }

  void clearInMemory() {
    _operation++;
    state = const AsyncData<OrganizationSelection>(
      OrganizationSelection(items: <OrganizationSummaryDto>[], current: null),
    );
    ref.read(organizationGenerationProvider.notifier).advance();
  }

  static OrganizationSummaryDto? _selectValid(
    List<OrganizationSummaryDto> items,
    String? remembered,
  ) {
    if (items.isEmpty) {
      return null;
    }
    if (remembered != null) {
      for (final OrganizationSummaryDto item in items) {
        if (item.id == remembered) {
          return item;
        }
      }
    }
    return items.first;
  }
}

final class OrganizationGenerationController extends Notifier<int> {
  @override
  int build() => 0;

  void advance() => state += 1;
}
