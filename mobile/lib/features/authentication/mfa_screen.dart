import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/auth/auth_state.dart';
import '../../core/widgets/compliance_scaffold.dart';
import '../../l10n/app_localizations.dart';

final class MfaScreen extends ConsumerStatefulWidget {
  const MfaScreen({super.key});

  @override
  ConsumerState<MfaScreen> createState() => _MfaScreenState();
}

final class _MfaScreenState extends ConsumerState<MfaScreen> {
  final TextEditingController _code = TextEditingController();
  bool _recovery = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations strings = AppLocalizations.of(context);
    final AuthState state = ref.watch(authControllerProvider);
    return ComplianceScaffold(
      showOrganization: false,
      appBar: AppBar(
        leading: IconButton(
          tooltip: strings.cancel,
          onPressed: ref.read(authControllerProvider.notifier).cancelMfa,
          icon: const Icon(Icons.arrow_back),
        ),
        title: Text(strings.mfaTitle),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: ComplianceIconTile(Icons.lock_outline, size: 60),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    _recovery ? 'Резервный код' : 'Подтвердите вход',
                    style: Theme.of(context).textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _recovery
                        ? 'Используйте один из заранее сохранённых одноразовых кодов.'
                        : 'Введите шестизначный код из приложения-аутентификатора.',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _code,
                    keyboardType: _recovery
                        ? TextInputType.visiblePassword
                        : TextInputType.number,
                    inputFormatters: _recovery
                        ? null
                        : <TextInputFormatter>[
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(6),
                          ],
                    autofocus: true,
                    autocorrect: false,
                    enableSuggestions: false,
                    textInputAction: TextInputAction.done,
                    onSubmitted: state.busy
                        ? null
                        : (String value) => ref
                              .read(authControllerProvider.notifier)
                              .submitMfa(value),
                    decoration: InputDecoration(
                      labelText: _recovery ? 'Резервный код' : strings.mfaCode,
                    ),
                  ),
                  if (state.safeError != null) ...<Widget>[
                    const SizedBox(height: 12),
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        state.safeError!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: state.busy
                        ? null
                        : () => ref
                              .read(authControllerProvider.notifier)
                              .submitMfa(_code.text),
                    child: Text(strings.continueAction),
                  ),
                  TextButton(
                    onPressed: state.busy
                        ? null
                        : () => setState(() {
                            _recovery = !_recovery;
                            _code.clear();
                          }),
                    child: Text(
                      _recovery
                          ? 'Ввести код из приложения'
                          : 'Использовать резервный код',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
