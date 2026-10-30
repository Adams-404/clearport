import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Tiny JSON store in the app's private support directory.
///
/// Writes go to a temp file first so a crash mid-write can't corrupt the
/// existing history.
class Store {
  Store._(this._file);

  /// Used when the platform directory is unavailable (e.g. widget tests).
  Store.memory([Map<String, dynamic>? initial])
    : _file = null,
      _memoryData = initial;

  final File? _file;
  Map<String, dynamic>? _memoryData;

  static Future<Store> open() async {
    try {
      final directory = await getApplicationSupportDirectory();
      await directory.create(recursive: true);
      return Store._(File('${directory.path}/clearport.json'));
    } catch (_) {
      return Store.memory();
    }
  }

  Future<Map<String, dynamic>?> read() async {
    final file = _file;
    if (file == null) {
      final data = _memoryData;
      return data == null ? null : Map<String, dynamic>.from(data);
    }
    try {
      if (!await file.exists()) return null;
      final text = await file.readAsString();
      if (text.trim().isEmpty) return null;
      final decoded = jsonDecode(text);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      // A corrupt file should not brick the app; start clean instead.
      return null;
    }
  }

  Future<void> write(Map<String, dynamic> data) async {
    final file = _file;
    if (file == null) {
      _memoryData = Map<String, dynamic>.from(data);
      return;
    }
    final temp = File('${file.path}.tmp');
    try {
      await temp.writeAsString(jsonEncode(data), flush: true);
      try {
        await temp.rename(file.path);
      } on FileSystemException {
        // Windows cannot rename over an existing file.
        if (await file.exists()) await file.delete();
        await temp.rename(file.path);
      }
    } catch (_) {
      // Persistence is best-effort; the session keeps working in memory.
    }
  }
}
