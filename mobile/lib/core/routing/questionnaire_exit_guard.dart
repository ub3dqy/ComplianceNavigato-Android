import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The route owns the decision, including programmatic go and Android Back.
/// The callback belongs only to the mounted form; no answers are cached here.
final class QuestionnaireExitGuard {
  Future<bool> Function()? confirm;
}

final questionnaireExitGuardProvider = Provider<QuestionnaireExitGuard>(
  (Ref ref) => QuestionnaireExitGuard(),
);
