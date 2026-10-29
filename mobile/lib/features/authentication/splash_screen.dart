import 'package:flutter/material.dart';

import '../../core/widgets/compliance_scaffold.dart';

final class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) => ComplianceScaffold(
    body: SafeArea(
      child: Center(
        child: Semantics(
          label: 'Проверка защищённого соединения',
          liveRegion: true,
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ComplianceIconTile(Icons.shield_outlined, size: 60),
              SizedBox(height: 24),
              Text(
                'Комплаенс-Навигатор',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
              ),
              Text('Организации, задачи и документы'),
              SizedBox(height: 20),
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Проверяем защищённое соединение…'),
            ],
          ),
        ),
      ),
    ),
  );
}
