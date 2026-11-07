import 'dart:math';

class Lbl {
  final int id;
  final String name;
  Lbl(this.id, this.name);
  Map<String, dynamic> toJson() => {'id': id, 'name': name};
  factory Lbl.fromJson(Map<String, dynamic> j) =>
      Lbl((j['id'] as num).toInt(), '${j['name']}');
}

class Item {
  int id, grade, subject;
  String type, text, img, audio;
  bool listen;
  Map<int, String> pa;

  Item({
    required this.id,
    required this.grade,
    required this.subject,
    required this.type,
    required this.text,
    this.img = '',
    this.audio = '',
    this.listen = false,
    Map<int, String>? pa,
  }) : pa = pa ?? {};

  Map<String, dynamic> toJson() => {
        'id': id,
        'grade': grade,
        'subject': subject,
        'type': type,
        'text': text,
        'img': img,
        'listen': listen,
        'audio': audio,
        'pa': <String, dynamic>{for (final e in pa.entries) '${e.key}': e.value},
      };

  factory Item.fromJson(Map<String, dynamic> j) {
    final p = <int, String>{};
    final raw = j['pa'];
    if (raw is Map) {
      raw.forEach((k, v) {
        final i = int.tryParse('$k');
        if (i != null && v is String && v.isNotEmpty) p[i] = v;
      });
    }
    return Item(
      id: (j['id'] as num).toInt(),
      grade: (j['grade'] as num?)?.toInt() ?? 0,
      subject: (j['subject'] as num?)?.toInt() ?? 0,
      type: '${j['type'] ?? 'syl'}',
      text: '${j['text'] ?? ''}',
      img: '${j['img'] ?? ''}',
      audio: '${j['audio'] ?? ''}',
      listen: j['listen'] == true,
      pa: p,
    );
  }
}

class Db {
  List<Lbl> grades, subjects;
  List<Item> items;
  int n;
  Db(this.grades, this.subjects, this.items, this.n);

  factory Db.initial() => Db([Lbl(1, 'الصف الأول')], [Lbl(2, 'لغتي')], [], 10);

  Map<String, dynamic> toJson() => {
        'grades': grades.map((e) => e.toJson()).toList(),
        'subjects': subjects.map((e) => e.toJson()).toList(),
        'items': items.map((e) => e.toJson()).toList(),
        'n': n,
      };

  factory Db.fromJson(Map<String, dynamic> j) => Db(
        ((j['grades'] as List?) ?? []).map((e) => Lbl.fromJson(e as Map<String, dynamic>)).toList(),
        ((j['subjects'] as List?) ?? []).map((e) => Lbl.fromJson(e as Map<String, dynamic>)).toList(),
        ((j['items'] as List?) ?? []).map((e) => Item.fromJson(e as Map<String, dynamic>)).toList(),
        (j['n'] as num?)?.toInt() ?? 10,
      );
}

const typeNames = {'syl': 'أصوات/مقاطع', 'wrd': 'كلمات', 'snt': 'جمل'};
const typeHints = {
  'syl': 'اكتب المقاطع مفصولة بشرطة، مثال: ثَعْ-لَ-ب',
  'wrd': 'اكتب الجملة كاملة، تُقسم كلماتها تلقائياً',
  'snt': 'اكتب كل جملة في سطر منفصل بالترتيب الصحيح',
};

List<String> partsOf(String type, String text) {
  final t = text.trim();
  if (type == 'syl') {
    return t.split(RegExp(r'[-–|]')).map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
  }
  if (type == 'wrd') {
    return t.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
  }
  return t.split(RegExp(r'\n+')).map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
}

List<T> shuffled<T>(List<T> a, [Random? rnd]) {
  final r = rnd ?? Random();
  var b = List<T>.of(a);
  var n = 0;
  do {
    b = List<T>.of(a);
    for (var i = b.length - 1; i > 0; i--) {
      final j = r.nextInt(i + 1);
      final tmp = b[i];
      b[i] = b[j];
      b[j] = tmp;
    }
    n++;
  } while (b.length > 1 && n < 9 && _same(a, b));
  return b;
}

bool _same<T>(List<T> a, List<T> b) {
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

int newId() => DateTime.now().millisecondsSinceEpoch + Random().nextInt(1000);
