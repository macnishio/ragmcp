import 'dart:convert';

import 'package:path/path.dart' as p;

import 'constants.dart';

bool isSupportedTextFile(String fileName) {
  return supportedTextExtensions.contains(p.extension(fileName).toLowerCase());
}

bool _looksBinary(String text) {
  final sample = text.length > 512 ? text.substring(0, 512) : text;
  int controlCount = 0;
  for (final codeUnit in sample.codeUnits) {
    if ((codeUnit >= 0 && codeUnit <= 8) || codeUnit == 65533) {
      controlCount += 1;
    }
  }
  return controlCount > 8;
}

String? extractText(String fileName, List<int> bytes) {
  if (!isSupportedTextFile(fileName)) {
    return null;
  }

  final text = utf8.decode(bytes, allowMalformed: true).replaceAll('\u0000', '');
  if (text.trim().isEmpty || _looksBinary(text)) {
    return null;
  }

  return text;
}
