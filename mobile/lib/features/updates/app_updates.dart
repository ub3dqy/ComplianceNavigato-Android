import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const updateOrigin = 'https://compliance-pilot.ms777.ru';
const updatePackage = 'ru.ms777.compliancenavigator.staging';
const nativeUpdates = MethodChannel('ru.ms777.compliancenavigator/updates');

final appUpdatesProvider = Provider<AppUpdates>((Ref ref) {
  final service = AppUpdates();
  ref.onDispose(service.dispose);
  return service;
});

final class UpdateFailure implements Exception {
  const UpdateFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

final class UpdateOffer {
  const UpdateOffer({
    required this.version,
    required this.versionCode,
    required this.bytes,
    required this.sha256,
    required this.certificate,
    required this.notes,
    required this.url,
    required this.fileName,
  });

  final String version, sha256, certificate, notes, fileName;
  final int versionCode, bytes;
  final Uri url;

  static UpdateOffer? parse(Object? document, Map<String, dynamic> installed) {
    const fields = <String>{
      'schema',
      'package',
      'version',
      'version_code',
      'bytes',
      'sha256',
      'certificate_sha256',
      'min_sdk',
      'notes',
      'file',
      'source_commit',
      'url',
    };
    if (document is! Map<String, dynamic> ||
        document.length != fields.length ||
        !fields.containsAll(document.keys) ||
        document['schema'] is! int ||
        document['schema'] != 1 ||
        document['package'] != updatePackage ||
        document['min_sdk'] is! int ||
        document['min_sdk'] != 26) {
      throw const UpdateFailure('Не удалось прочитать сведения об обновлении.');
    }
    final version = document['version'];
    final code = document['version_code'];
    final bytes = document['bytes'];
    final sha = document['sha256'];
    final certificate = document['certificate_sha256'];
    final notes = document['notes'];
    final commit = document['source_commit'];
    final installedCode = installed['versionCode'];
    if (installed['package'] != updatePackage ||
        installedCode is! int ||
        installedCode < 1 ||
        version is! String ||
        !RegExp(r'^\d{1,4}\.\d{1,4}\.\d{1,4}$').hasMatch(version) ||
        code is! int ||
        code < 1 ||
        code > 2100000000 ||
        bytes is! int ||
        bytes < 4 ||
        bytes > 512 * 1024 * 1024 ||
        sha is! String ||
        !RegExp(r'^[0-9a-f]{64}$').hasMatch(sha) ||
        certificate is! String ||
        !RegExp(r'^[0-9a-f]{64}$').hasMatch(certificate) ||
        certificate != installed['signerSha256'] ||
        notes is! String ||
        notes.length > 1000 ||
        commit is! String ||
        !RegExp(r'^[0-9a-f]{40}$').hasMatch(commit)) {
      throw const UpdateFailure(
        'Обновление не соответствует установленному приложению.',
      );
    }
    final name = 'compliance-navigator-$code-$sha.apk';
    final expected = Uri.parse('$updateOrigin/android/releases/$name');
    if (document['file'] != name || document['url'] != expected.toString()) {
      throw const UpdateFailure('Адрес обновления не прошёл проверку.');
    }
    if (code <= installedCode) return null;
    return UpdateOffer(
      version: version,
      versionCode: code,
      bytes: bytes,
      sha256: sha,
      certificate: certificate,
      notes: notes,
      url: expected,
      fileName: name,
    );
  }
}

final class UpdateDownload {
  const UpdateDownload(this.state, this.progress, this.message);
  final String state;
  final double progress;
  final String? message;
  bool get active => state == 'running' || state == 'paused';
  bool get ready => state == 'ready';
}

/// Uses a separate, credential-free connection. API tokens never enter updates.
final class AppUpdates {
  AppUpdates({Dio? client, this.channel = nativeUpdates})
    : client =
          client ??
          Dio(BaseOptions(connectTimeout: const Duration(seconds: 20)));
  final Dio client;
  final MethodChannel channel;
  bool presenting = false;
  bool _disposed = false;
  int? lastPresentedVersion;

  Future<UpdateOffer?> check() async {
    final cancel = CancelToken();
    try {
      final info = await channel.invokeMapMethod<String, dynamic>('appInfo');
      if (_disposed || info == null || info['package'] != updatePackage) {
        throw const UpdateFailure('Не удалось определить версию приложения.');
      }
      final response = await client
          .get<ResponseBody>(
            '$updateOrigin/android/latest.json',
            cancelToken: cancel,
            options: Options(
              responseType: ResponseType.stream,
              followRedirects: false,
              maxRedirects: 0,
              receiveTimeout: const Duration(seconds: 20),
              sendTimeout: const Duration(seconds: 20),
              validateStatus: (status) => status == 200,
              headers: <String, String>{'Accept': 'application/json'},
            ),
          )
          .timeout(const Duration(seconds: 25));
      final stream = response.data;
      if (stream == null || (stream.contentLength) > 16384) {
        throw const UpdateFailure(
          'Не удалось прочитать сведения об обновлении.',
        );
      }
      final bytes = <int>[];
      await for (final chunk in stream.stream.timeout(
        const Duration(seconds: 20),
      )) {
        if (_disposed || bytes.length + chunk.length > 16384) {
          throw const UpdateFailure(
            'Не удалось прочитать сведения об обновлении.',
          );
        }
        bytes.addAll(chunk);
      }
      return UpdateOffer.parse(jsonDecode(utf8.decode(bytes)), info);
    } on UpdateFailure {
      rethrow;
    } on Object {
      throw const UpdateFailure(
        'Не удалось проверить обновления. Проверьте интернет и попробуйте ещё раз.',
      );
    } finally {
      if (!cancel.isCancelled) cancel.cancel('Update check completed');
    }
  }

  Map<String, Object> arguments(UpdateOffer offer) => <String, Object>{
    'fileName': offer.fileName,
    'versionCode': offer.versionCode,
    'bytes': offer.bytes,
    'sha256': offer.sha256,
    'url': offer.url.toString(),
  };

  Future<UpdateDownload> downloadState(
    UpdateOffer offer, {
    bool start = false,
  }) async {
    try {
      final value = await channel.invokeMapMethod<String, dynamic>(
        start ? 'startDownload' : 'downloadStatus',
        arguments(offer),
      );
      final state = value?['state'];
      if (!<String>[
        'idle',
        'running',
        'paused',
        'ready',
        'failed',
      ].contains(state)) {
        throw const UpdateFailure('Не удалось узнать состояние загрузки.');
      }
      final received = value?['received'];
      final progress = received is int && value?['bytes'] == offer.bytes
          ? (received / offer.bytes).clamp(0.0, 1.0)
          : 0.0;
      return UpdateDownload(
        state as String,
        progress,
        value?['message'] is String ? value!['message'] as String : null,
      );
    } on PlatformException {
      throw const UpdateFailure(
        'Не удалось скачать обновление. Проверьте интернет и свободное место.',
      );
    }
  }

  Future<void> cancelDownload(UpdateOffer offer) =>
      channel.invokeMethod<void>('cancelDownload', arguments(offer));

  Future<String> install(UpdateOffer offer) async {
    try {
      final state = await channel.invokeMethod<String>(
        'installUpdate',
        arguments(offer),
      );
      if (!<String>[
        'permission_required',
        'installer_opened',
        'ready',
      ].contains(state)) {
        throw const UpdateFailure('Не удалось открыть установку обновления.');
      }
      return state!;
    } on PlatformException catch (error) {
      throw UpdateFailure(
        error.code == 'UPDATE_INVALID'
            ? 'Файл обновления повреждён или не прошёл проверку подписи. Скачайте его заново.'
            : error.code == 'UPDATE_SPACE'
            ? 'Недостаточно места для подготовки обновления. Освободите память и повторите.'
            : 'Не удалось открыть установку обновления.',
      );
    }
  }

  Future<void> cancelInstallation() async {
    try {
      await channel.invokeMethod<void>('cancelUpdate');
    } on Object {
      /* No pending installer remains after activity disposal. */
    }
  }

  void dispose() {
    _disposed = true;
    client.close(force: true);
  }
}
