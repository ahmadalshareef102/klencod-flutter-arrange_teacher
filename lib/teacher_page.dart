import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'models.dart';
import 'store.dart';
import 'widgets.dart';

class TeacherPage extends StatefulWidget {
  const TeacherPage({super.key, required this.store, required this.onChanged});
  final Store store;
  final VoidCallback onChanged;

  @override
  State<TeacherPage> createState() => _TeacherPageState();
}

class _TeacherPageState extends State<TeacherPage> {
  final ng = TextEditingController();
  final ns = TextEditingController();
  final tx = TextEditingController();
  final scroll = ScrollController();
  final rec = AudioRecorder();
  final pv = AudioPlayer();

  int? ig, isub;
  int fg = 0, fs = 0;
  String type = 'syl';
  String img = '', au = '';
  Map<int, String> pa = {};
  bool listen = false;
  int? editId;
  String? recKey;

  Db get db => widget.store.db;

  @override
  void dispose() {
    ng.dispose();
    ns.dispose();
    tx.dispose();
    scroll.dispose();
    rec.dispose();
    pv.dispose();
    super.dispose();
  }

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<bool> _confirm(String m) async {
    final r = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        content: Text(m),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('إلغاء')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('موافق')),
        ],
      ),
    );
    return r == true;
  }

  Future<void> _commit() async {
    await widget.store.save();
    if (!mounted) return;
    setState(() {});
    widget.onChanged();
  }

  Future<void> addLbl(List<Lbl> l, TextEditingController c) async {
    final v = c.text.trim();
    if (v.isEmpty) return;
    l.add(Lbl(newId(), v));
    c.clear();
    await _commit();
  }

  Future<void> delLbl(List<Lbl> l, Lbl x) async {
    if (!await _confirm('حذف؟ ستبقى الأسئلة المرتبطة محفوظة لكن دون تصنيف')) return;
    l.removeWhere((e) => e.id == x.id);
    await _commit();
  }

  Future<void> toggleRec(String k) async {
    if (recKey != null) {
      if (recKey == k) {
        final p = await rec.stop();
        setState(() {
          if (p != null) {
            if (k == 'all') {
              au = p;
            } else {
              pa[int.parse(k)] = p;
            }
          }
          recKey = null;
        });
      }
      return;
    }
    if (!await rec.hasPermission()) {
      _snack('تعذر تشغيل الميكروفون. اسمح للتطبيق بالوصول إليه من الإعدادات.');
      return;
    }
    await rec.start(const RecordConfig(encoder: AudioEncoder.aacLc),
        path: widget.store.newPath('m4a'));
    setState(() => recKey = k);
  }

  Future<void> _play(String p) async {
    try {
      await pv.stop();
      await pv.play(DeviceFileSource(p));
    } catch (_) {}
  }

  Widget recRow(String k, String path) {
    final on = recKey == k;
    return Row(children: [
      OutlinedButton(
        style: on ? OutlinedButton.styleFrom(backgroundColor: Colors.red.shade700, foregroundColor: Colors.white) : null,
        onPressed: () => toggleRec(k),
        child: Text(on ? '⏹ إيقاف' : '🎙 تسجيل'),
      ),
      if (path.isNotEmpty && !on) ...[
        const SizedBox(width: 6),
        OutlinedButton(onPressed: () => _play(path), child: const Text('▶')),
        const SizedBox(width: 6),
        OutlinedButton(
          onPressed: () => setState(() {
            if (k == 'all') {
              au = '';
            } else {
              pa.remove(int.parse(k));
            }
          }),
          child: const Text('✕'),
        ),
      ],
    ]);
  }

  Future<void> pickImg() async {
    final r = await FilePicker.platform.pickFiles(type: FileType.image);
    final p = r?.files.single.path;
    if (p == null) return;
    final ext = p.contains('.') ? p.split('.').last : 'jpg';
    final np = widget.store.newPath(ext);
    await File(p).copy(np);
    setState(() => img = np);
  }

  void clr() {
    setState(() {
      editId = null;
      img = '';
      au = '';
      pa = {};
      tx.clear();
      listen = false;
    });
  }

  Future<void> saveItem() async {
    final t = tx.text.trim();
    if (t.isEmpty) return _snack('اكتب النص');
    if (recKey != null) return _snack('أوقف التسجيل أولاً');
    if (partsOf(type, t).length < 2) return _snack('يلزم قطعتان على الأقل');
    final o = Item(
      id: editId ?? newId(),
      grade: pickValid(ig, db.grades) ?? 0,
      subject: pickValid(isub, db.subjects) ?? 0,
      type: type,
      text: t,
      img: img,
      listen: listen,
      audio: au,
      pa: Map<int, String>.of(pa),
    );
    if (editId != null) {
      final i = db.items.indexWhere((x) => x.id == editId);
      if (i >= 0) db.items[i] = o;
    } else {
      db.items.add(o);
    }
    clr();
    await _commit();
  }

  void edit(Item x) {
    setState(() {
      editId = x.id;
      img = x.img;
      au = x.audio;
      pa = Map<int, String>.of(x.pa);
      ig = x.grade;
      isub = x.subject;
      type = x.type;
      tx.text = x.text;
      listen = x.listen;
    });
    scroll.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
  }

  Future<void> del(Item x) async {
    if (!await _confirm('حذف السؤال؟')) return;
    db.items.removeWhere((e) => e.id == x.id);
    await _commit();
  }

  Future<void> export() async {
    final s = await widget.store.exportJson();
    final r = await FilePicker.platform.saveFile(
      fileName: 'arrange-backup.json',
      bytes: Uint8List.fromList(utf8.encode(s)),
    );
    if (r != null && mounted) _snack('تم حفظ النسخة الاحتياطية');
  }

  Future<void> import() async {
    final r = await FilePicker.platform
        .pickFiles(type: FileType.custom, allowedExtensions: ['json'], withData: true);
    final b = r?.files.single.bytes;
    if (b == null) return;
    final ok = await widget.store.importJson(utf8.decode(b));
    if (!mounted) return;
    if (ok) {
      setState(() {});
      widget.onChanged();
      _snack('تم الاستيراد');
    } else {
      _snack('ملف غير صالح');
    }
  }

  Widget _labels(String title, List<Lbl> l, TextEditingController c, String hint) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
                child: TextField(
                    controller: c,
                    decoration: InputDecoration(hintText: hint, border: const OutlineInputBorder()))),
            const SizedBox(width: 8),
            FilledButton(onPressed: () => addLbl(l, c), child: const Text('+ إضافة')),
          ]),
          Wrap(spacing: 6, children: [
            for (final x in l)
              InputChip(label: Text(x.name), onDeleted: () => delLbl(l, x)),
          ]),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final gg = pickValid(ig, db.grades), ss = pickValid(isub, db.subjects);
    final p = partsOf(type, tx.text);
    final shown = db.items
        .where((x) => (fg == 0 || x.grade == fg) && (fs == 0 || x.subject == fs))
        .toList();
    String nm(List<Lbl> l, int id) {
      for (final e in l) {
        if (e.id == id) return e.name;
      }
      return '—';
    }

    return ListView(
      controller: scroll,
      padding: const EdgeInsets.all(12),
      children: [
        _labels('الصفوف', db.grades, ng, 'مثال: الصف الأول'),
        _labels('المواد', db.subjects, ns, 'مثال: لغتي'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(editId == null ? 'إضافة سؤال' : 'تعديل سؤال',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                    child: Dd<int>(
                        label: 'الصف',
                        value: gg,
                        items: lblItems(db.grades),
                        onChanged: (v) => setState(() => ig = v))),
                const SizedBox(width: 8),
                Expanded(
                    child: Dd<int>(
                        label: 'المادة',
                        value: ss,
                        items: lblItems(db.subjects),
                        onChanged: (v) => setState(() => isub = v))),
              ]),
              const SizedBox(height: 8),
              Dd<String>(
                label: 'نوع التمرين',
                value: type,
                items: const [
                  DropdownMenuItem(value: 'syl', child: Text('ترتيب أصوات / مقاطع → كلمة')),
                  DropdownMenuItem(value: 'wrd', child: Text('ترتيب كلمات → جملة')),
                  DropdownMenuItem(value: 'snt', child: Text('ترتيب جمل → فقرة')),
                ],
                onChanged: (v) => setState(() => type = v ?? 'syl'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: tx,
                minLines: 3,
                maxLines: 6,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                    labelText: typeHints[type], border: const OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              const Text('🎙 تسجيل صوتك (يُستخدم بدل صوت الجهاز)'),
              const SizedBox(height: 4),
              recRow('all', au),
              const SizedBox(height: 12),
              const Text('تسجيل كل قطعة على حدة (اختياري، مفيد للأصوات والمقاطع)'),
              if (p.isEmpty) const Text('اكتب النص أولاً', style: TextStyle(fontSize: 12)),
              for (var i = 0; i < p.length; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(children: [
                    Expanded(child: Text(p[i])),
                    recRow('$i', pa[i] ?? ''),
                  ]),
                ),
              const SizedBox(height: 8),
              Row(children: [
                OutlinedButton(onPressed: pickImg, child: const Text('🖼 صورة (اختياري)')),
                if (img.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  if (File(img).existsSync())
                    Image.file(File(img), width: 44, height: 44, cacheWidth: 120),
                  IconButton(onPressed: () => setState(() => img = ''), icon: const Icon(Icons.close)),
                ],
              ]),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('وضع الاستماع: يسمع الطالب النص ثم يرتب'),
                value: listen,
                onChanged: (v) => setState(() => listen = v),
              ),
              Row(children: [
                Expanded(child: FilledButton(onPressed: saveItem, child: const Text('💾 حفظ السؤال'))),
                const SizedBox(width: 8),
                Expanded(child: OutlinedButton(onPressed: clr, child: const Text('جديد'))),
              ]),
            ]),
          ),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const Text('الأسئلة المحفوظة', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                    child: Dd<int>(
                        label: 'الصف',
                        value: fg == 0 || db.grades.any((e) => e.id == fg) ? fg : 0,
                        items: lblItems(db.grades, all: true),
                        onChanged: (v) => setState(() => fg = v ?? 0))),
                const SizedBox(width: 8),
                Expanded(
                    child: Dd<int>(
                        label: 'المادة',
                        value: fs == 0 || db.subjects.any((e) => e.id == fs) ? fs : 0,
                        items: lblItems(db.subjects, all: true),
                        onChanged: (v) => setState(() => fs = v ?? 0))),
              ]),
              if (shown.isEmpty)
                const Padding(padding: EdgeInsets.all(8), child: Text('لا توجد أسئلة')),
              for (final x in shown)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: x.img.isNotEmpty && File(x.img).existsSync()
                      ? Image.file(File(x.img), width: 40, height: 40, cacheWidth: 120)
                      : null,
                  title: Text(x.text.replaceAll('\n', ' ⏎ '), maxLines: 2, overflow: TextOverflow.ellipsis),
                  subtitle: Text(
                      '${nm(db.grades, x.grade)} · ${nm(db.subjects, x.subject)} · ${typeNames[x.type]}'
                      '${x.listen ? ' · 🔊' : ''}${x.audio.isNotEmpty || x.pa.isNotEmpty ? ' · 🎙' : ''}'),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    IconButton(onPressed: () => edit(x), icon: const Icon(Icons.edit)),
                    IconButton(onPressed: () => del(x), icon: const Icon(Icons.delete, color: Colors.red)),
                  ]),
                ),
            ]),
          ),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const Text('نسخ احتياطي', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: OutlinedButton(onPressed: export, child: const Text('⬇ تصدير'))),
                const SizedBox(width: 8),
                Expanded(child: OutlinedButton(onPressed: import, child: const Text('⬆ استيراد'))),
              ]),
            ]),
          ),
        ),
      ],
    );
  }
}
