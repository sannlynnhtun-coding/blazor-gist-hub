import 'dart:convert';

import 'models.dart';

List<String> parseTags(String description) {
  if (description.trim().isEmpty) return const [];

  return description
      .split(RegExp(r'\s+'))
      .where((part) => part.startsWith('#') && part.length > 1)
      .map((part) => part.substring(1).replaceAll(RegExp(r'[,.!?;:]+$'), ''))
      .where((tag) => tag.isNotEmpty)
      .toSet()
      .toList()
    ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
}

ImportedGistInput parseImportedGistJson(String jsonText) {
  if (jsonText.trim().isEmpty) {
    throw const FormatException('Paste JSON content first.');
  }

  final Object? decoded;
  try {
    decoded = jsonDecode(jsonText);
  } on FormatException catch (error) {
    throw FormatException('Invalid JSON: ${error.message}');
  }

  if (decoded is! Map<String, Object?>) {
    throw const FormatException('JSON payload must be an object.');
  }

  final rawFiles = decoded['files'];
  if (rawFiles is! Map || rawFiles.isEmpty) {
    throw const FormatException('At least one file is required in files.');
  }

  final files = <String, GistFile>{};
  for (final entry in rawFiles.entries) {
    final filename = entry.key.toString().trim();
    if (filename.isEmpty) {
      throw const FormatException('All file names must be non-empty.');
    }

    final fileObject = entry.value;
    if (fileObject is! Map) {
      throw FormatException("File entry '$filename' is invalid.");
    }
    if (fileObject['content'] is! String ||
        (fileObject['content'] as String).isEmpty ||
        fileObject['truncated'] == true) {
      throw FormatException(
        "File '$filename' needs complete, non-empty text content.",
      );
    }
    if (files.containsKey(filename)) {
      throw FormatException("Duplicate file name '$filename'.");
    }

    files[filename] = GistFile(
      filename: filename,
      content: fileObject['content'] as String,
    );
  }

  return ImportedGistInput(
    description: decoded['description']?.toString().trim() ?? '',
    isPublic: decoded['public'] == true,
    files: files,
  );
}
