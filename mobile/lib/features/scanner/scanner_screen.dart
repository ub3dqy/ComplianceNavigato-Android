import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/network/api_models.dart';
import '../../core/presentation/human_labels.dart';
import '../../core/widgets/compliance_components.dart';
import '../../core/widgets/compliance_scaffold.dart';

typedef ScannerKey = ({String organizationId, int generation});
typedef ScannerSnapshot = ({
  List<WebsiteDto> websites,
  List<SiteScanDto> scans,
});

final scannerProvider = FutureProvider.autoDispose
    .family<ScannerSnapshot, ScannerKey>((Ref ref, ScannerKey key) async {
      final values = await Future.wait<Object>(<Future<Object>>[
        ref.read(repositoryProvider).websites(key.organizationId),
        ref.read(repositoryProvider).scans(key.organizationId),
      ]);
      return (
        websites: values[0] as List<WebsiteDto>,
        scans: values[1] as List<SiteScanDto>,
      );
    });

final class ScannerScreen extends ConsumerStatefulWidget {
  const ScannerScreen({this.websiteId, super.key});
  final String? websiteId;

  @override
  ConsumerState<ScannerScreen> createState() => _ScannerScreenState();
}

final class _ScannerScreenState extends ConsumerState<ScannerScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      final organization = ref.read(currentOrganizationProvider);
      if (organization != null) {
        ref.invalidate(
          scannerProvider((
            organizationId: organization.id,
            generation: ref.read(organizationGenerationProvider),
          )),
        );
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _start(
    BuildContext context,
    OrganizationSummaryDto organization,
    ScannerKey key,
    List<WebsiteDto> websites,
  ) async {
    String? selected = websites
        .where((WebsiteDto item) => item.scanAuthorityConfirmed)
        .firstOrNull
        ?.id;
    if (widget.websiteId != null) {
      final chosen = websites
          .where(
            (item) =>
                item.id == widget.websiteId && item.scanAuthorityConfirmed,
          )
          .firstOrNull;
      if (chosen == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Сначала подтвердите право на проверку выбранного сайта.',
            ),
          ),
        );
        return;
      }
      selected = chosen.id;
    }
    final accepted =
        await showDialog<bool>(
          context: context,
          builder: (BuildContext context) => StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) =>
                AlertDialog(
                  scrollable: true,
                  title: const Text('Новая проверка сайта'),
                  content: DropdownButtonFormField<String>(
                    initialValue: selected,
                    decoration: const InputDecoration(
                      labelText: 'Сайт с подтверждёнными полномочиями',
                    ),
                    items: websites
                        .where((WebsiteDto item) => item.scanAuthorityConfirmed)
                        .map(
                          (WebsiteDto item) => DropdownMenuItem<String>(
                            value: item.id,
                            child: Text(item.name),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: (String? value) =>
                        setState(() => selected = value),
                  ),
                  actions: <Widget>[
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Отмена'),
                    ),
                    FilledButton(
                      onPressed: selected == null
                          ? null
                          : () => Navigator.pop(context, true),
                      child: const Text('Запустить'),
                    ),
                  ],
                ),
          ),
        ) ??
        false;
    if (!accepted || selected == null) {
      return;
    }
    try {
      await ref.read(repositoryProvider).createScan(organization.id, selected!);
      ref.invalidate(scannerProvider(key));
    } on Object catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(safeUiError(error))));
      }
    }
  }

  Future<void> _cancelOrRetry(
    BuildContext context,
    OrganizationSummaryDto organization,
    ScannerKey key,
    SiteScanDto scan,
  ) async {
    try {
      if (const <String>{'queued', 'running'}.contains(scan.status)) {
        await ref.read(repositoryProvider).cancelScan(organization.id, scan);
      } else {
        await ref
            .read(repositoryProvider)
            .createScan(organization.id, scan.websiteId);
      }
      ref.invalidate(scannerProvider(key));
    } on Object catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(safeUiError(error))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final organization = ref.watch(currentOrganizationProvider);
    if (organization == null) {
      return const ComplianceScaffold(
        body: Center(child: Text('Выберите организацию.')),
      );
    }
    final key = (
      organizationId: organization.id,
      generation: ref.watch(organizationGenerationProvider),
    );
    final value = ref.watch(scannerProvider(key));
    return ComplianceScaffold(
      appBar: AppBar(
        title: const Text('Проверка сайтов'),
        actions: <Widget>[
          IconButton(
            onPressed: () => ref.invalidate(scannerProvider(key)),
            icon: const Icon(Icons.refresh),
            tooltip: 'Обновить',
          ),
        ],
      ),
      floatingActionButton: organization.role == 'viewer'
          ? null
          : FloatingActionButton.extended(
              tooltip: 'Новая проверка',
              onPressed: value.value == null
                  ? null
                  : () => _start(
                      context,
                      organization,
                      key,
                      value.value!.websites,
                    ),
              icon: const Icon(Icons.radar),
              label: const Text('Запустить'),
            ),
      body: value.when(
        loading: () => const LoadingSkeleton(includeHero: false),
        error: (Object error, StackTrace _) => ErrorState(
          message: safeUiError(error),
          onRetry: () => ref.invalidate(scannerProvider(key)),
        ),
        data: (ScannerSnapshot data) => data.scans.isEmpty
            ? const Center(child: Text('Проверок пока нет.'))
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                itemCount: data.scans.length,
                itemBuilder: (BuildContext context, int index) {
                  final scan = data.scans[index];
                  final progressMessage = humanProgressMessage(
                    scan.progressMessage,
                  );
                  final active = const <String>{
                    'queued',
                    'running',
                  }.contains(scan.status);
                  return Padding(
                    padding: EdgeInsets.zero,
                    child: ComplianceDetailCard(
                      leading: active
                          ? SizedBox.square(
                              dimension: 32,
                              child: CircularProgressIndicator(
                                value: scan.progressPercent / 100,
                              ),
                            )
                          : const Icon(Icons.travel_explore),
                      title: Text(scan.requestedUrl),
                      subtitle: Text(
                        '${humanStatus(scan.status)} · ${scan.progressPercent}%'
                        '${progressMessage.isEmpty ? '' : ' · $progressMessage'}',
                      ),
                      trailing: organization.role == 'viewer'
                          ? null
                          : IconButton(
                              tooltip: active ? 'Отменить' : 'Повторить',
                              onPressed: () => _cancelOrRetry(
                                context,
                                organization,
                                key,
                                scan,
                              ),
                              icon: Icon(
                                active ? Icons.cancel_outlined : Icons.replay,
                              ),
                            ),
                      children: <Widget>[
                        if (scan.errorSummary.isNotEmpty)
                          ListTile(
                            leading: const Icon(Icons.error_outline),
                            title: Text(scan.errorSummary),
                          ),
                        if (scan.incompleteReason.isNotEmpty)
                          ListTile(
                            leading: const Icon(Icons.warning_amber),
                            title: Text(scan.incompleteReason),
                          ),
                        ListTile(
                          title: Text(
                            'Страниц: ${scan.pagesScanned} · находок: ${scan.findings.length}',
                          ),
                        ),
                        ...scan.pages.map(
                          (SiteScanPageDto page) => ListTile(
                            leading: Icon(
                              page.isHttps
                                  ? Icons.lock_outline
                                  : Icons.lock_open,
                            ),
                            title: Text(page.finalUrl),
                            subtitle: Text(
                              'Ответ сайта: ${page.statusCode} · форм: ${page.formsCount}\n'
                              'Внешние домены: ${page.externalDomains.isEmpty ? 'нет' : page.externalDomains.join(', ')}',
                            ),
                          ),
                        ),
                        ...scan.findings.map(
                          (SiteScanFindingDto finding) => ListTile(
                            leading: Icon(
                              finding.needsReview
                                  ? Icons.fact_check_outlined
                                  : Icons.info_outline,
                            ),
                            title: Text(finding.title),
                            subtitle: Text(
                              'Уверенность: ${humanConfidence(finding.confidence)}\n'
                              '${finding.description}',
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }
}
