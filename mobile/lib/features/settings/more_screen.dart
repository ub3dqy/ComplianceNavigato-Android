import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/compliance_scaffold.dart';

final class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});
  @override
  Widget build(BuildContext context) => ComplianceScaffold(
    appBar: AppBar(title: const Text('Ещё')),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
      children: <Widget>[
        for (final group in const <(String, List<(IconData, String, String)>)>[
          (
            'Работа',
            [
              (Icons.business_outlined, 'Организации', '/organizations'),
              (Icons.language_outlined, 'Сайты', '/websites'),
              (Icons.cloud_outlined, 'Сервисы и страны', '/services'),
            ],
          ),
          (
            'Проверки и документы',
            [
              (Icons.assessment_outlined, 'Оценки', '/assessments'),
              (Icons.radar_outlined, 'Проверка сайтов', '/scanner'),
              (Icons.description_outlined, 'Документы', '/documents'),
              (Icons.attachment_outlined, 'Подтверждения', '/evidence'),
            ],
          ),
          (
            'Контроль и настройки',
            [
              (Icons.summarize_outlined, 'Отчёты', '/reports'),
              (Icons.history_outlined, 'Журнал действий', '/audit'),
              (Icons.settings_outlined, 'Настройки', '/settings'),
            ],
          ),
        ]) ...<Widget>[
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              group.$1.toUpperCase(),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                letterSpacing: 1.1,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Card(
            child: Column(
              children: <Widget>[
                for (
                  var index = 0;
                  index < group.$2.length;
                  index++
                ) ...<Widget>[
                  if (index > 0) const Divider(height: 1),
                  ListTile(
                    minTileHeight: 76,
                    leading: ComplianceIconTile(group.$2[index].$1),
                    title: Text(
                      group.$2[index].$2,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    trailing: const Icon(Icons.chevron_right, size: 18),
                    onTap: () => context.push(group.$2[index].$3),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ],
    ),
  );
}
