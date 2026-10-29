import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../errors/app_error.dart';
import 'compliance_components.dart';

final class AsyncPanel<T> extends StatelessWidget {
  const AsyncPanel({
    required this.future,
    required this.builder,
    required this.onRetry,
    super.key,
  });

  final Future<T> future;
  final Widget Function(BuildContext context, T value) builder;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => FutureBuilder<T>(
    future: future,
    builder: (BuildContext context, AsyncSnapshot<T> snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const LoadingSkeleton();
      }
      if (snapshot.hasError) {
        final Object? error = snapshot.error;
        final String safeMessage = error is AppError
            ? error.safeMessage
            : 'Не удалось загрузить данные.';
        return ErrorState(
          message: safeMessage,
          retryLabel: AppLocalizations.of(context).retry,
          onRetry: onRetry,
        );
      }
      return builder(context, snapshot.requireData);
    },
  );
}
