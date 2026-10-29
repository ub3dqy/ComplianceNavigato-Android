import 'dart:convert';
import 'dart:io';

import 'package:integration_test/integration_test_driver.dart';

Future<void> main() => integrationDriver(
  responseDataCallback: (data) async {
    final directory = Directory(
      '../artifacts/mobile-implementation-20261026/runtime',
    );
    await directory.create(recursive: true);
    await File('${directory.path}/navigation-profile.json')
        .writeAsString(jsonEncode(data));
  },
);
