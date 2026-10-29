import 'dart:io';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart' show PlatformFile;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/network/api_models.dart';
import '../../core/presentation/human_labels.dart';
import '../../core/storage/system_file_picker.dart';
import '../../core/widgets/compliance_components.dart';
import '../../core/widgets/compliance_scaffold.dart';

typedef EvidenceKey = ({String organizationId, int generation});

final evidenceProvider = FutureProvider.autoDispose
    .family<List<EvidenceDto>, EvidenceKey>(
      (Ref ref, EvidenceKey key) =>
          ref.read(repositoryProvider).evidence(key.organizationId),
    );

final class EvidenceScreen extends ConsumerStatefulWidget {
  const EvidenceScreen({super.key});

  @override
  ConsumerState<EvidenceScreen> createState() => _EvidenceScreenState();
}

final class _EvidenceScreenState extends ConsumerState<EvidenceScreen> {
  double? _progress;
  CancelToken? _uploadCancelToken;

  @override
  void dispose() {
    _uploadCancelToken?.cancel('screen_disposed');
    super.dispose();
  }

  void _cancelUpload() {
    final CancelToken? token = _uploadCancelToken;
    if (token != null && !token.isCancelled) {
      token.cancel('user_cancelled');
    }
  }

  Future<void> _upload(
    BuildContext context,
    OrganizationSummaryDto organization,
    EvidenceKey key,
  ) async {
    final int generation = currentOrganizationGeneration(ref);
    final SystemFilePicker picker = ref.read(systemFilePickerProvider);
    CancelToken? cancelToken;
    try {
      final PlatformFile? selected = await picker.pickEvidence();
      if (!context.mounted ||
          !isCurrentOrganization(
            ref,
            organization.id,
            generation: generation,
          ) ||
          selected?.path == null) {
        return;
      }
      final int? selectedSize = await selected!.length();
      if (!context.mounted ||
          !isCurrentOrganization(
            ref,
            organization.id,
            generation: generation,
          )) {
        return;
      }
      if (selectedSize == null || selectedSize < 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Не удалось определить размер файла. Выберите другой файл.',
            ),
          ),
        );
        return;
      }
      if (selectedSize > 20 * 1024 * 1024) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Файл больше 20 МБ.')));
        return;
      }
      String title = selected.name;
      bool processingAuthorizedConfirmed = false;
      final accepted =
          await showDialog<bool>(
            context: context,
            builder: (BuildContext context) => StatefulBuilder(
              builder: (BuildContext context, StateSetter setDialogState) =>
                  AlertDialog(
                    scrollable: true,
                    title: const Text('Загрузка подтверждения'),
                    content: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          const Text(
                            'Файл будет доступен участникам этой организации '
                            'с соответствующими правами. Загружайте только '
                            'необходимые для работы сведения.',
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            initialValue: title,
                            onChanged: (String value) => title = value,
                            decoration: const InputDecoration(
                              labelText: 'Название',
                            ),
                          ),
                          const SizedBox(height: 8),
                          CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            controlAffinity: ListTileControlAffinity.leading,
                            value: processingAuthorizedConfirmed,
                            onChanged: (bool? value) => setDialogState(
                              () => processingAuthorizedConfirmed =
                                  value ?? false,
                            ),
                            title: const Text(
                              'Подтверждаю право использовать файл в этой организации',
                            ),
                          ),
                        ],
                      ),
                    ),
                    actions: <Widget>[
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Отмена'),
                      ),
                      FilledButton(
                        onPressed: processingAuthorizedConfirmed
                            ? () => Navigator.pop(context, true)
                            : null,
                        child: const Text('Загрузить'),
                      ),
                    ],
                  ),
            ),
          ) ??
          false;
      if (!accepted ||
          title.trim().isEmpty ||
          !isCurrentOrganization(
            ref,
            organization.id,
            generation: generation,
          )) {
        return;
      }
      cancelToken = CancelToken();
      setState(() {
        _uploadCancelToken = cancelToken;
        _progress = 0;
      });
      await ref
          .read(repositoryProvider)
          .uploadEvidence(
            organizationId: organization.id,
            title: title.trim(),
            filePath: selected.path!,
            fileName: selected.name,
            processingAuthorizedConfirmed: processingAuthorizedConfirmed,
            cancelToken: cancelToken,
            onAuthReplay: () {
              if (mounted &&
                  identical(_uploadCancelToken, cancelToken) &&
                  isCurrentOrganization(
                    ref,
                    organization.id,
                    generation: generation,
                  )) {
                setState(() => _progress = 0);
              }
            },
            onProgress: (int sent, int total) {
              if (mounted &&
                  identical(_uploadCancelToken, cancelToken) &&
                  isCurrentOrganization(
                    ref,
                    organization.id,
                    generation: generation,
                  )) {
                setState(
                  () => _progress = total == 0
                      ? null
                      : (sent / total).clamp(0.0, 1.0).toDouble(),
                );
              }
            },
          );
      if (isCurrentOrganization(ref, organization.id, generation: generation)) {
        ref.invalidate(evidenceProvider(key));
      }
    } on Object catch (error) {
      if (context.mounted &&
          isCurrentOrganization(ref, organization.id, generation: generation)) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(safeUiError(error))));
      }
    } finally {
      if (mounted &&
          cancelToken != null &&
          identical(_uploadCancelToken, cancelToken)) {
        setState(() {
          _uploadCancelToken = null;
          _progress = null;
        });
      }
      try {
        await picker.clearTemporaryFiles();
      } on Object {
        if (context.mounted &&
            isCurrentOrganization(
              ref,
              organization.id,
              generation: generation,
            )) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Временную копию файла не удалось удалить. '
                'Закройте приложение и перезапустите устройство.',
              ),
            ),
          );
        }
      }
    }
  }

  Future<void> _open(
    BuildContext context,
    String organizationId,
    EvidenceDto item,
  ) async {
    final repository = ref.read(repositoryProvider);
    final transientFiles = ref.read(transientFileServiceProvider);
    final int generation = currentOrganizationGeneration(ref);
    try {
      final payload = await repository.download(item.downloadUrl);
      if (!context.mounted ||
          !isCurrentOrganization(ref, organizationId, generation: generation)) {
        return;
      }
      final File file = await transientFiles.save(
        payload,
        scope: organizationId,
        fallbackName: item.originalName,
        allowedExtensions: <String>{'.${item.extension.toLowerCase()}'},
      );
      if (!context.mounted ||
          !isCurrentOrganization(ref, organizationId, generation: generation)) {
        await transientFiles.discard(file);
        return;
      }
      await transientFiles.open(
        file,
        isAllowed: () =>
            context.mounted &&
            isCurrentOrganization(ref, organizationId, generation: generation),
      );
    } on Object catch (error) {
      if (context.mounted &&
          isCurrentOrganization(ref, organizationId, generation: generation)) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(safeUiError(error))));
      }
    }
  }

  Future<void> _delete(
    BuildContext context,
    OrganizationSummaryDto organization,
    EvidenceKey key,
    EvidenceDto item,
  ) async {
    final int generation = currentOrganizationGeneration(ref);
    final accepted =
        await showDialog<bool>(
          context: context,
          builder: (BuildContext context) => AlertDialog(
            scrollable: true,
            title: const Text('Удалить подтверждение?'),
            content: Text(item.title),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Отмена'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Удалить'),
              ),
            ],
          ),
        ) ??
        false;
    if (!accepted ||
        !isCurrentOrganization(ref, organization.id, generation: generation)) {
      return;
    }
    try {
      await ref.read(repositoryProvider).deleteEvidence(organization.id, item);
      if (isCurrentOrganization(ref, organization.id, generation: generation)) {
        ref.invalidate(evidenceProvider(key));
      }
    } on Object catch (error) {
      if (context.mounted &&
          isCurrentOrganization(ref, organization.id, generation: generation)) {
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
    final value = ref.watch(evidenceProvider(key));
    final canEdit = organization.role != 'viewer';
    return ComplianceScaffold(
      appBar: AppBar(
        title: const Text('Подтверждения'),
        actions: <Widget>[
          if (_uploadCancelToken != null)
            IconButton(
              onPressed: _cancelUpload,
              icon: const Icon(Icons.stop_circle_outlined),
              tooltip: 'Отменить загрузку',
            ),
        ],
        bottom: _progress == null
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(4),
                child: LinearProgressIndicator(value: _progress),
              ),
      ),
      floatingActionButton: canEdit
          ? FloatingActionButton.extended(
              tooltip: 'Добавить подтверждение',
              onPressed: _uploadCancelToken == null
                  ? () => _upload(context, organization, key)
                  : null,
              icon: const Icon(Icons.upload_file),
              label: const Text('Загрузить'),
            )
          : null,
      body: value.when(
        loading: () => const LoadingSkeleton(includeHero: false),
        error: (Object error, StackTrace _) => ErrorState(
          message: safeUiError(error),
          onRetry: () => ref.invalidate(evidenceProvider(key)),
        ),
        data: (items) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
          children: <Widget>[
            const Text('Файлы, которые подтверждают выполненные действия.'),
            const SizedBox(height: 16),
            if (items.isEmpty) const Text('Подтверждений пока нет.'),
            for (final item in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            const ComplianceIconTile(Icons.attachment_outlined),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    item.title,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    '${item.originalName} · ${(item.sizeBytes / 1024).toStringAsFixed(1)} КБ',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: <Widget>[
                            FilledButton.tonalIcon(
                              onPressed: () =>
                                  _open(context, organization.id, item),
                              icon: const Icon(Icons.visibility_outlined),
                              label: const Text('Открыть'),
                            ),
                            OutlinedButton(
                              onPressed: !canEdit
                                  ? null
                                  : () => _delete(
                                      context,
                                      organization,
                                      key,
                                      item,
                                    ),
                              child: const Text('Удалить'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
