import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'models.dart';
import 'store.dart';
import 'widgets.dart';

class QItem {
  QItem(this.it) : parts = partsOf(it.type, it.text) {
    order = shuffled(List<int>.generate(parts.length, (i) => i));
    done = List<int>.filled(parts.length, -1);
  }
  final Item it;
  final List<String> parts;
  late List<int> order;
  late List<int> done;
  int err = 0;
  bool said = false;
  bool get complete => done.every((v) => v >= 0);
}

class QuizPage extends StatefulWidget {
  const QuizPage({super.key, required this.store});
  final Store store;

  @override
  State<QuizPage> createState() => _QuizPageState();
}

class _QuizPageState extends State<QuizPage> {
  int? g, s;
  String t = '';
  final nc = TextEditingController();
  bool challenge = true;
  List<QItem> q = [];
  int qi = 0;
  bool finished = false;
  String msg = '';
  int? wrong;
  final player = AudioPlayer();
  final tts = FlutterTts();

  Db get db => widget.store.db;

  @override
  void initState() {
    super.initState();
    nc.text = '${db.n}';
    tts.setLanguage('ar-SA');
    tts.setSpeechRate(0.4);
  }

  @override
  void dispose() {
    nc.dispose();
    player.dispose();
    tts.stop();
    super.dispose();
  }

  void gen() {
    final gg = pickValid(g, db.grades), ss = pickValid(s, db.subjects);
    g = gg;
    s = ss;
    db.n = int.tryParse(nc.text) ?? 10;
    if (db.n < 1) db.n = 10;
    widget.store.save();
    final a = db.items
        .where((x) =>
            x.grade == gg &&
            x.subject == ss &&
            (t.isEmpty || x.type == t) &&
            partsOf(x.type, x.text).length >= 2)
        .toList();
    if (a.isEmpty) {
      setState(() => msg = 'لا توجد أسئلة لهذا الصف والمادة. أضفها من «إدارة المعلم».');
      return;
    }
    final list = shuffled(a).take(db.n).map((x) => QItem(x)).toList();
    setState(() {
      q = list;
      qi = 0;
      finished = false;
      msg = 'تم إنشاء اختبار من ${list.length} سؤال ✔';
    });
    _auto();
  }

  void _auto() {
    if (q.isEmpty || finished) return;
    final c = q[qi];
    if (c.it.listen && !c.said) {
      c.said = true;
      Future.delayed(const Duration(milliseconds: 300), say);
    }
  }

  Future<void> _playFile(String p) async {
    try {
      await player.stop();
      await player.play(DeviceFileSource(p));
    } catch (_) {}
  }

  Future<void> say() async {
    if (q.isEmpty) return;
    final c = q[qi], it = c.it;
    try {
      if (it.audio.isNotEmpty) {
        await _playFile(it.audio);
        return;
      }
      final all = List<int>.generate(c.parts.length, (i) => i)
          .every((i) => (it.pa[i] ?? '').isNotEmpty);
      if (all) {
        for (var i = 0; i < c.parts.length; i++) {
          await player.stop();
          await player.play(DeviceFileSource(it.pa[i]!));
          await player.onPlayerComplete.first;
        }
        return;
      }
      await tts.stop();
      await tts.speak(c.parts.join(it.type == 'syl' ? '' : ' '));
    } catch (_) {}
  }

  void tap(int pi) {
    final c = q[qi], it = c.it;
    if ((it.pa[pi] ?? '').isNotEmpty) {
      _playFile(it.pa[pi]!);
    } else if (it.audio.isEmpty && it.pa.isEmpty && (it.type == 'syl' || it.type == 'wrd')) {
      tts.stop();
      tts.speak(c.parts[pi]);
    }
    var k = -1;
    if (challenge) {
      k = c.done.indexOf(-1);
      if (k < 0) return;
      if (c.parts[k] != c.parts[pi]) {
        c.err++;
        HapticFeedback.heavyImpact();
        setState(() => wrong = pi);
        Future.delayed(const Duration(milliseconds: 400), () {
          if (mounted) setState(() => wrong = null);
        });
        return;
      }
    } else {
      for (var i = 0; i < c.parts.length; i++) {
        if (c.done[i] < 0 && c.parts[i] == c.parts[pi]) {
          k = i;
          break;
        }
      }
      if (k < 0) return;
    }
    setState(() => c.done[k] = pi);
    SystemSound.play(SystemSoundType.click);
    HapticFeedback.lightImpact();
  }

  void undo(int i) {
    final c = q[qi];
    if (c.done[i] >= 0) setState(() => c.done[i] = -1);
  }

  void resetQ() {
    final c = q[qi];
    setState(() {
      c.done = List<int>.filled(c.parts.length, -1);
      c.order = shuffled(c.order);
    });
  }

  void next() {
    setState(() {
      if (qi == q.length - 1) {
        finished = true;
      } else {
        qi++;
      }
    });
    _auto();
  }

  void prev() {
    if (qi > 0) {
      setState(() => qi--);
      _auto();
    }
  }

  @override
  Widget build(BuildContext context) {
    final th = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _setup(),
        if (q.isNotEmpty) finished ? _result() : _play(th),
      ],
    );
  }

  Widget _setup() {
    final gg = pickValid(g, db.grades), ss = pickValid(s, db.subjects);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              Expanded(
                  child: Dd<int>(
                      label: 'الصف',
                      value: gg,
                      items: lblItems(db.grades),
                      onChanged: (v) => setState(() => g = v))),
              const SizedBox(width: 8),
              Expanded(
                  child: Dd<int>(
                      label: 'المادة',
                      value: ss,
                      items: lblItems(db.subjects),
                      onChanged: (v) => setState(() => s = v))),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                  flex: 3,
                  child: Dd<String>(
                    label: 'نوع التمرين',
                    value: t,
                    items: [
                      const DropdownMenuItem(value: '', child: Text('الكل')),
                      const DropdownMenuItem(value: 'syl', child: Text('ترتيب أصوات / مقاطع')),
                      const DropdownMenuItem(value: 'wrd', child: Text('ترتيب كلمات لجملة')),
                      const DropdownMenuItem(value: 'snt', child: Text('ترتيب جمل لفقرة')),
                    ],
                    onChanged: (v) => setState(() => t = v ?? ''),
                  )),
              const SizedBox(width: 8),
              Expanded(
                  flex: 2,
                  child: TextField(
                    controller: nc,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        labelText: 'عدد الأسئلة', border: OutlineInputBorder()),
                  )),
            ]),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('وضع التحدي: الخطأ يُحتسب ولا يُقبل'),
              value: challenge,
              onChanged: (v) => setState(() => challenge = v),
            ),
            FilledButton(onPressed: gen, child: const Text('⟳ إنشاء / تحديث الاختبار')),
            if (msg.isNotEmpty)
              Padding(padding: const EdgeInsets.only(top: 8), child: Text(msg)),
          ],
        ),
      ),
    );
  }

  Widget _play(ThemeData th) {
    final c = q[qi];
    final snt = c.it.type == 'snt';
    final fs = snt ? 18.0 : (c.parts.length > 6 ? 22.0 : 28.0);
    final hasImg = c.it.img.isNotEmpty && File(c.it.img).existsSync();
    return Column(children: [
      Container(
        constraints: const BoxConstraints(minHeight: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: const Color(0xFF44B89C), borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          if (hasImg)
            Expanded(
              flex: 4,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(File(c.it.img), height: 170, fit: BoxFit.contain, cacheWidth: 600),
              ),
            ),
          if (hasImg) const SizedBox(width: 10),
          Expanded(
            flex: 7,
            child: Container(
              constraints: const BoxConstraints(minHeight: 130),
              padding: const EdgeInsets.all(18),
              decoration: const BoxDecoration(
                color: Color(0xFF8347B0),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(40),
                  topRight: Radius.circular(40),
                  bottomRight: Radius.circular(40),
                  bottomLeft: Radius.circular(6),
                ),
              ),
              child: Wrap(
                alignment: WrapAlignment.center,
                runAlignment: WrapAlignment.center,
                spacing: 4,
                runSpacing: 6,
                children: [
                  for (var i = 0; i < c.parts.length; i++)
                    GestureDetector(
                      onTap: () => undo(i),
                      child: Container(
                        constraints: const BoxConstraints(minWidth: 34, minHeight: 44),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                                width: 3,
                                color: c.done[i] >= 0 ? Colors.transparent : Colors.white54),
                          ),
                        ),
                        child: Text(
                          c.done[i] >= 0 ? c.parts[c.done[i]] : '',
                          style: TextStyle(color: Colors.white, fontSize: fs, height: 1.5),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(children: [
          for (var i = 0; i < q.length; i++)
            Expanded(
              child: Container(
                height: 16,
                margin: const EdgeInsets.symmetric(horizontal: 1.5),
                decoration: BoxDecoration(
                  color: q[i].complete ? const Color(0xFF4CBA4C) : Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(4),
                  border: i == qi ? Border.all(color: th.colorScheme.primary, width: 2) : null,
                ),
              ),
            ),
        ]),
      ),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        alignment: WrapAlignment.center,
        children: [
          for (final pi in c.order)
            Builder(builder: (_) {
              final used = c.done.contains(pi);
              return Opacity(
                opacity: used ? 0.45 : 1,
                child: GestureDetector(
                  onTap: used ? null : () => tap(pi),
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 60),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: th.colorScheme.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          width: 2,
                          color: wrong == pi ? Colors.red : th.colorScheme.outlineVariant),
                    ),
                    child: Text(c.parts[pi], style: TextStyle(fontSize: snt ? 18 : 24)),
                  ),
                ),
              );
            }),
        ],
      ),
      const SizedBox(height: 12),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        OutlinedButton(onPressed: say, child: const Text('🔊 استماع')),
        const SizedBox(width: 8),
        OutlinedButton(onPressed: resetQ, child: const Text('↺ إعادة')),
      ]),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: OutlinedButton(onPressed: prev, child: const Text('السابق'))),
        const SizedBox(width: 8),
        Expanded(
            child: FilledButton(
                onPressed: next,
                child: Text(qi == q.length - 1 ? 'إنهاء ✔' : 'التالي ←'))),
      ]),
    ]);
  }

  Widget _result() {
    final ok = q.where((x) => x.complete).length;
    final er = q.fold<int>(0, (a, x) => a + x.err);
    final clean = q.where((x) => x.err == 0).length;
    final r = clean / q.length;
    final stars = r >= .85 ? 3 : (r >= .5 ? 2 : 1);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(children: [
          const Text('🎉 أحسنت!', style: TextStyle(fontSize: 24)),
          Text('⭐' * stars, style: const TextStyle(fontSize: 38)),
          Text('أنهيت $ok من ${q.length}', style: const TextStyle(fontSize: 20)),
          if (challenge)
            Text('بدون أخطاء: $clean · عدد الأخطاء: $er',
                style: const TextStyle(fontSize: 16)),
          const SizedBox(height: 16),
          FilledButton(onPressed: gen, child: const Text('اختبار جديد')),
        ]),
      ),
    );
  }
}
