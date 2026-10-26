import 'package:flutter/services.dart';

Future<void> copyImage(Uint8List bytes) =>
    const MethodChannel('gisthub/files').invokeMethod<void>('copyImage', bytes);

Future<void> saveExport(String name, String mime, Uint8List bytes) async {
  await const MethodChannel(
    'gisthub/files',
  ).invokeMethod<void>('save', {'name': name, 'mime': mime, 'bytes': bytes});
}

Future<({String name, Uint8List bytes})?> pickFile() async {
  final result = await const MethodChannel(
    'gisthub/files',
  ).invokeMapMethod<String, Object?>('open');
  if (result == null) return null;
  return (name: result['name'] as String, bytes: result['bytes'] as Uint8List);
}
