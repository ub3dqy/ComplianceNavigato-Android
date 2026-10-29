import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/auth/auth_state.dart';
import '../../core/widgets/compliance_scaffold.dart';
import '../../l10n/app_localizations.dart';
import '../updates/app_updates.dart';
import '../updates/update_dialog.dart';

final class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

final class _LoginScreenState extends ConsumerState<LoginScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (ref.read(authControllerProvider).busy) return;
    if (!_formKey.currentState!.validate()) {
      return;
    }
    await ref
        .read(authControllerProvider.notifier)
        .login(email: _email.text, password: _password.text);
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations strings = AppLocalizations.of(context);
    final AuthState state = ref.watch(authControllerProvider);
    return ComplianceScaffold(
      showOrganization: false,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: AutofillGroup(
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: ComplianceIconTile(
                          Icons.shield_outlined,
                          size: 60,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        strings.loginTitle,
                        textAlign: TextAlign.left,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Войдите, чтобы продолжить работу с организацией.',
                      ),
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: _email,
                        autofillHints: const <String>[AutofillHints.username],
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autocorrect: false,
                        decoration: InputDecoration(labelText: strings.email),
                        validator: (String? value) =>
                            value != null && value.contains('@')
                            ? null
                            : 'Введите корректный адрес.',
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _password,
                        autofillHints: const <String>[AutofillHints.password],
                        obscureText: _obscure,
                        enableSuggestions: false,
                        autocorrect: false,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _submit(),
                        decoration: InputDecoration(
                          labelText: strings.password,
                          suffixIcon: IconButton(
                            tooltip: _obscure
                                ? 'Показать пароль'
                                : 'Скрыть пароль',
                            onPressed: () =>
                                setState(() => _obscure = !_obscure),
                            icon: Icon(
                              _obscure
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                          ),
                        ),
                        validator: (String? value) => value?.isNotEmpty == true
                            ? null
                            : 'Введите пароль.',
                      ),
                      if (state.safeError != null) ...<Widget>[
                        const SizedBox(height: 14),
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
                      FilledButton.icon(
                        onPressed: state.busy ? null : _submit,
                        icon: state.busy
                            ? const SizedBox.square(
                                dimension: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.login),
                        label: Text(strings.signIn),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Публичной регистрации нет. Доступ выдаёт владелец пилота.',
                        textAlign: TextAlign.center,
                      ),
                      TextButton.icon(
                        onPressed: () => showAppUpdates(
                          context,
                          ref.read(appUpdatesProvider),
                        ),
                        icon: const Icon(Icons.system_update_outlined),
                        label: const Text('Обновить приложение'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
