import 'package:path/path.dart' as path;

const Set<String> safeDownloadExtensions = <String>{
  '.html',
  '.docx',
  '.json',
  '.txt',
  '.csv',
  '.pdf',
  '.xlsx',
  '.png',
  '.jpg',
  '.jpeg',
};

String validatedFilename({
  required String? contentDisposition,
  required String fallback,
  Set<String> allowedExtensions = safeDownloadExtensions,
}) {
  String candidate = _filenameFromHeader(contentDisposition) ?? fallback;
  candidate = candidate.trim();
  final String base = path.basename(candidate);
  final String extension = path.extension(base).toLowerCase();
  final bool safe =
      base == candidate &&
      base.length <= 180 &&
      base.isNotEmpty &&
      !base.startsWith('.') &&
      !base.contains('..') &&
      !base.contains(RegExp(r'[\x00-\x1f<>:"/\\|?*]')) &&
      allowedExtensions.contains(extension);
  if (!safe) {
    final String fallbackBase = path.basename(fallback);
    final String fallbackExtension = path.extension(fallbackBase).toLowerCase();
    if (fallbackBase != fallback ||
        !allowedExtensions.contains(fallbackExtension)) {
      throw const FormatException('Unsafe fallback filename.');
    }
    return fallbackBase;
  }
  return base;
}

String? _filenameFromHeader(String? value) {
  if (value == null || value.contains(RegExp(r'[\r\n]'))) {
    return null;
  }
  final RegExpMatch? encoded = RegExp(
    r'''filename\*\s*=\s*UTF-8''([^;]+)''',
    caseSensitive: false,
  ).firstMatch(value);
  if (encoded != null) {
    try {
      return Uri.decodeComponent(encoded.group(1)!);
    } on FormatException {
      return null;
    }
  }
  return RegExp(
    r'''filename\s*=\s*"([^"]+)"''',
    caseSensitive: false,
  ).firstMatch(value)?.group(1);
}
