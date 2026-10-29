import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'fns_extract_file.dart';

/// Discard interrupted SAF cache copies before any account is opened.
class PrivateCacheBootstrap extends StatefulWidget {
  const PrivateCacheBootstrap({
    required this.child,
    this.clearCache,
    super.key,
  });

  final Widget child;
  final Future<void> Function()? clearCache;

  @override
  State<PrivateCacheBootstrap> createState() => _PrivateCacheBootstrapState();
}

class _PrivateCacheBootstrapState extends State<PrivateCacheBootstrap> {
  bool _ready = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _clear();
  }

  Future<void> _clear() async {
    setState(() => _failed = false);
    try {
      await (widget.clearCache ?? clearPrivatePickerCache)();
      if (mounted) setState(() => _ready = true);
    } on Object {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) => _ready
      ? widget.child
      : MaterialApp(
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          home: Builder(
            builder: (context) => Scaffold(
              body: SafeArea(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: SingleChildScrollView(
                      child: _failed
                          ? Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.error_outline,
                                  color: Theme.of(context).colorScheme.error,
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'Не удалось очистить временные файлы прошлого запуска. Повторите попытку, чтобы безопасно открыть приложение.',
                                ),
                                const SizedBox(height: 16),
                                FilledButton(
                                  onPressed: _clear,
                                  child: const Text('Повторить очистку'),
                                ),
                              ],
                            )
                          : const CircularProgressIndicator(),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
}
