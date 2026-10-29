import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'core/storage/private_cache_bootstrap.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const PrivateCacheBootstrap(
      child: ProviderScope(child: ComplianceNavigatorApp()),
    ),
  );
}
