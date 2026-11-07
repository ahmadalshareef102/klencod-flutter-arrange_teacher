import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';

class Store {
  Store(this.prefs, this.dir, this.db);
  final SharedPreferences prefs;
  final Directory dir;
  Db db;
  static const key = 'arrange_db_v1';

  static Future<Store> open() async {
    final prefs = await SharedPreferences.getInstance();
    final dir = await getApplicationDocumentsDirectory();
    Db db;
    try {
      final s = prefs.getString(key);
      db = s == null ? Db.initial() : Db.fromJson(jsonDecode(s) as Map<String, dynamic>);
    } catch (_) {
      db = Db.initial();
    }
    return Store(prefs, dir, db);
  }

  Future<void> save() => prefs.setString(key, jsonEncode(db.toJson()));

  String newPath(String ext) => '${dir.path}/m_${DateTime.now().microsecondsSinceEpoch}.$ext';

  Future<String> _toUri(dynamic v, String mime) async {
    final p = '${v ?? ''}';
    if (p.isEmpty || p.startsWith('data:')) return p;
    final f = File(p);
    if (!await f.exists()) return '';
    return 'data:$mime;base64,${base64Encode(await f.readAsBytes())}';
  }

  Future<String> _fromUri(String v) async {
    if (!v.startsWith('data:')) return v;
    final c = v.indexOf(',');
    if (c < 0) return '';
    var ext = v.substring(5, c).split(';').first.split('/').last;
    if (ext == 'jpeg') ext = 'jpg';
    if (ext == 'mpeg') ext = 'mp3';
    if (ext.isEmpty) ext = 'bin';
    final p = newPath(ext);
    await File(p).writeAsBytes(base64Decode(v.substring(c + 1)));
    return p;
  }

  /// نفس صيغة نسخة صفحة الويب (الوسائط كروابط data:) لتبقى النسخ متوافقة.
  Future<String> exportJson() async {
    final m = db.toJson();
    for (final it in m['items'] as List) {
      final x = it as Map<String, dynamic>;
      x['img'] = await _toUri(x['img'], 'image/jpeg');
      x['audio'] = await _toUri(x['audio'], 'audio/mp4');
      final pa = x['pa'] as Map<String, dynamic>;
      for (final k in pa.keys.toList()) {
        pa[k] = await _toUri(pa[k], 'audio/mp4');
      }
    }
    return jsonEncode(m);
  }

  Future<bool> importJson(String s) async {
    try {
      final m = jsonDecode(s) as Map<String, dynamic>;
      if (m['items'] is! List) return false;
      for (final it in m['items'] as List) {
        final x = it as Map<String, dynamic>;
        x['img'] = await _fromUri('${x['img'] ?? ''}');
        x['audio'] = await _fromUri('${x['audio'] ?? ''}');
        final raw = x['pa'];
        if (raw is Map) {
          final out = <String, dynamic>{};
          for (final e in raw.entries) {
            out['${e.key}'] = await _fromUri('${e.value}');
          }
          x['pa'] = out;
        }
      }
      db = Db.fromJson(m);
      await save();
      return true;
    } catch (_) {
      return false;
    }
  }
}
