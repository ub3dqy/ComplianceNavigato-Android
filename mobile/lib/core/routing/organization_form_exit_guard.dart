import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The mounted form owns its draft and confirmation; no card data is cached.
final class OrganizationFormExitGuard {
  Future<bool> Function()? confirm;
}

final organizationFormExitGuardProvider = Provider<OrganizationFormExitGuard>(
  (Ref ref) => OrganizationFormExitGuard(),
);
