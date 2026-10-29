import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/network/api_models.dart';
import '../../core/network/compliance_repository.dart';
import '../../core/presentation/human_labels.dart';
import '../../core/widgets/compliance_components.dart';
import '../../core/widgets/compliance_scaffold.dart';

typedef DocumentsKey = ({String organizationId, int generation});
typedef DocumentsSnapshot = ({
  List<DocumentTemplateDto> templates,
  List<GeneratedDocumentDto> documents,
});

final documentsProvider = FutureProvider.autoDispose
    .family<DocumentsSnapshot, DocumentsKey>((Ref ref, DocumentsKey key) async {
      final values = await Future.wait<Object>(<Future<Object>>[
        ref.read(repositoryProvider).documentTemplates(key.organizationId),
        ref.read(repositoryProvider).documents(key.organizationId),
      ]);
      return (
        templates: values[0] as List<DocumentTemplateDto>,
        documents: values[1] as List<GeneratedDocumentDto>,
      );
    });

final class DocumentsScreen extends ConsumerWidget {
  const DocumentsScreen({super.key});

  Future<void> _generate(
    BuildContext context,
    WidgetRef ref,
    OrganizationSummaryDto organization,
    DocumentsKey key,
    List<DocumentTemplateDto> templates,
  ) async {
    final int generation = currentOrganizationGeneration(ref);
    String? selected = templates.isEmpty ? null : templates.first.id;
    final accepted =
        await showDialog<bool>(
          context: context,
          builder: (BuildContext context) => StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) =>
                AlertDialog(
                  scrollable: true,
                  title: const Text('Создать документ'),
                  content: DropdownButtonFormField<String>(
                    initialValue: selected,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Шаблон'),
                    items: templates
                        .map(
                          (DocumentTemplateDto item) =>
                              DropdownMenuItem<String>(
                                value: item.id,
                                child: Text(item.title),
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
                      child: const Text('Создать'),
                    ),
                  ],
                ),
          ),
        ) ??
        false;
    if (!accepted ||
        selected == null ||
        !isCurrentOrganization(ref, organization.id, generation: generation)) {
      return;
    }
    try {
      await ref
          .read(repositoryProvider)
          .generateDocument(organization.id, selected!);
      if (isCurrentOrganization(ref, organization.id, generation: generation)) {
        ref.invalidate(documentsProvider(key));
      }
    } on Object catch (error) {
      if (context.mounted &&
          isCurrentOrganization(ref, organization.id, generation: generation)) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(safeUiError(error))));
      }
    }
  }

  Future<void> _download(
    BuildContext context,
    WidgetRef ref,
    String organizationId,
    GeneratedDocumentDto document,
    String format,
  ) async {
    final repository = ref.read(repositoryProvider);
    final transientFiles = ref.read(transientFileServiceProvider);
    final int generation = currentOrganizationGeneration(ref);
    try {
      final String? path = document.downloadUrls[format];
      if (path == null) {
        throw StateError('Формат недоступен.');
      }
      final DownloadPayload payload = await repository.download(path);
      if (!context.mounted ||
          !isCurrentOrganization(ref, organizationId, generation: generation)) {
        return;
      }
      final File file = await transientFiles.save(
        payload,
        scope: organizationId,
        fallbackName: 'document-${document.id}.$format',
        allowedExtensions: <String>{'.$format'},
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
    final value = ref.watch(documentsProvider(key));
    return ComplianceScaffold(
      appBar: AppBar(
        title: const Text('Документы'),
        actions: <Widget>[
          IconButton(
            onPressed: () => ref.invalidate(documentsProvider(key)),
            icon: const Icon(Icons.refresh),
            tooltip: 'Обновить',
          ),
        ],
      ),
      floatingActionButton: organization.role == 'viewer'
          ? null
          : FloatingActionButton.extended(
              tooltip: 'Создать документ',
              onPressed: value.value == null
                  ? null
                  : () => _generate(
                      context,
                      ref,
                      organization,
                      key,
                      value.value!.templates,
                    ),
              icon: const Icon(Icons.add),
              label: const Text('Создать'),
            ),
      body: value.when(
        loading: () => const LoadingSkeleton(includeHero: false),
        error: (Object error, StackTrace _) => ErrorState(
          message: safeUiError(error),
          onRetry: () => ref.invalidate(documentsProvider(key)),
        ),
        data: (data) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
          children: <Widget>[
            const ComplianceNotice(
              'Документ остаётся черновиком до проверки и утверждения человеком.',
            ),
            const SizedBox(height: 24),
            if (data.documents.isEmpty) const Text('Документов пока нет.'),
            for (final item in data.documents)
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
                            const ComplianceIconTile(
                              Icons.description_outlined,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    item.template.title,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    humanDateTime(item.createdAt),
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall,
                                  ),
                                  const SizedBox(height: 12),
                                  SemanticStatusBadge(
                                    label: item.status == 'completed'
                                        ? 'Черновик готов'
                                        : humanStatus(item.status),
                                    status: item.status == 'failed'
                                        ? SemanticStatus.error
                                        : SemanticStatus.needsHumanReview,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        ExpansionTile(
                          title: const Text('Сведения о документе'),
                          tilePadding: EdgeInsets.zero,
                          children: <Widget>[
                            Text(
                              item.sha256.isEmpty
                                  ? 'Целостность требует проверки'
                                  : 'Контрольная сумма сохранена',
                            ),
                            Text(
                              'Версия шаблона ${item.template.version} · нормативная база ${item.baselineVersion}',
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: <Widget>[
                            FilledButton.tonalIcon(
                              onPressed: item.downloadUrls.isEmpty
                                  ? null
                                  : () => _download(
                                      context,
                                      ref,
                                      organization.id,
                                      item,
                                      item.downloadUrls.containsKey('html')
                                          ? 'html'
                                          : item.downloadUrls.keys.first,
                                    ),
                              icon: const Icon(Icons.visibility_outlined),
                              label: const Text('Открыть'),
                            ),
                            PopupMenuButton<String>(
                              tooltip: 'Форматы',
                              onSelected: (format) => _download(
                                context,
                                ref,
                                organization.id,
                                item,
                                format,
                              ),
                              itemBuilder: (_) => item.downloadUrls.keys
                                  .map(
                                    (format) => PopupMenuItem<String>(
                                      value: format,
                                      child: Text(
                                        'Открыть ${format.toUpperCase()}',
                                      ),
                                    ),
                                  )
                                  .toList(growable: false),
                              child: const SizedBox(
                                height: 48,
                                child: Center(
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 16,
                                    ),
                                    child: Text('Форматы'),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ExpansionTile(
              title: const Text('Доступные шаблоны'),
              children: <Widget>[
                for (final item in data.templates)
                  ListTile(
                    title: Text(item.title),
                    subtitle: Text(
                      'Версия ${item.version} · нормативная база ${item.baselineVersion}',
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
