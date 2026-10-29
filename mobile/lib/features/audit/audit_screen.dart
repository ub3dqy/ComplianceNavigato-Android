import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/network/api_models.dart';
import '../../core/presentation/human_labels.dart';
import '../../core/widgets/compliance_scaffold.dart';

final class AuditScreen extends ConsumerWidget {
  const AuditScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final organization = ref.watch(currentOrganizationProvider);
    if (organization == null) {
      return const ComplianceScaffold(
        body: Center(child: Text('Выберите организацию.')),
      );
    }
    return _OrganizationAuditView(
      key: ValueKey<String>(organization.id),
      organizationId: organization.id,
    );
  }
}

final class _OrganizationAuditView extends ConsumerStatefulWidget {
  const _OrganizationAuditView({required this.organizationId, super.key});

  final String organizationId;

  @override
  ConsumerState<_OrganizationAuditView> createState() =>
      _OrganizationAuditViewState();
}

final class _OrganizationAuditViewState
    extends ConsumerState<_OrganizationAuditView> {
  final List<AuditEventDto> _items = <AuditEventDto>[];
  String? _cursor;
  bool _loading = false;
  String? _error;
  int _requestSerial = 0;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(() => _load(reset: true));
  }

  Future<void> _load({required bool reset}) async {
    if (_loading && !reset) {
      return;
    }
    final int requestSerial = ++_requestSerial;
    setState(() {
      _loading = true;
      _error = null;
      if (reset) {
        _items.clear();
        _cursor = null;
      }
    });
    try {
      final AuditPageDto page = await ref
          .read(repositoryProvider)
          .auditPage(widget.organizationId, cursor: reset ? null : _cursor);
      if (!mounted || requestSerial != _requestSerial) {
        return;
      }
      setState(() {
        _items.addAll(page.results);
        _cursor = page.nextCursor;
      });
    } on Object catch (error) {
      if (mounted && requestSerial == _requestSerial) {
        setState(() => _error = safeUiError(error));
      }
    } finally {
      if (mounted && requestSerial == _requestSerial) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ComplianceScaffold(
      appBar: AppBar(
        title: const Text('Журнал действий'),
        actions: <Widget>[
          IconButton(
            onPressed: () => _load(reset: true),
            icon: const Icon(Icons.refresh),
            tooltip: 'Обновить',
          ),
        ],
      ),
      body: _items.isEmpty && _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
              itemCount: _items.length + 1,
              itemBuilder: (BuildContext context, int index) {
                if (index == _items.length) {
                  if (_error != null) {
                    return Center(
                      child: TextButton(
                        onPressed: () => _load(reset: false),
                        child: Text(_error!),
                      ),
                    );
                  }
                  if (_cursor == null) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('Больше событий нет.'),
                      ),
                    );
                  }
                  return Center(
                    child: TextButton.icon(
                      onPressed: _loading ? null : () => _load(reset: false),
                      icon: _loading
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(),
                            )
                          : const Icon(Icons.expand_more),
                      label: const Text('Показать ещё'),
                    ),
                  );
                }
                final item = _items[index];
                final safeMetadata = item.metadata.entries
                    .where(
                      (MapEntry<String, Object?> entry) =>
                          !RegExp(
                            r'token|password|secret|email',
                            caseSensitive: false,
                          ).hasMatch(entry.key) &&
                          (entry.value == null ||
                              entry.value is String ||
                              entry.value is num ||
                              entry.value is bool),
                    )
                    .map(
                      (MapEntry<String, Object?> entry) =>
                          '${entry.key}: ${entry.value}',
                    )
                    .join(' · ');
                return Padding(
                  padding: const EdgeInsets.only(left: 9),
                  child: Container(
                    padding: const EdgeInsets.only(left: 20, bottom: 24),
                    decoration: BoxDecoration(
                      border: Border(
                        left: BorderSide(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Icon(
                              Icons.circle_outlined,
                              size: 12,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                item.summary,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          humanDateTime(item.createdAt),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        ExpansionTile(
                          tilePadding: EdgeInsets.zero,
                          title: const Text('Сведения о событии'),
                          children: <Widget>[
                            Text('${item.eventType} · ${item.objectType}'),
                            if (safeMetadata.isNotEmpty) Text(safeMetadata),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
