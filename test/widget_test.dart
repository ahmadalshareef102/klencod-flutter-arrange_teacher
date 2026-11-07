import 'package:flutter_test/flutter_test.dart';
import 'package:arrange_teacher/models.dart';

void main() {
  test('تقسيم المقاطع والكلمات والجمل', () {
    expect(partsOf('syl', 'ثَعْ-لَ-ب'), ['ثَعْ', 'لَ', 'ب']);
    expect(partsOf('wrd', 'ذهب  الولد إلى المدرسة'), ['ذهب', 'الولد', 'إلى', 'المدرسة']);
    expect(partsOf('snt', 'الأولى\n\nالثانية'), ['الأولى', 'الثانية']);
  });

  test('الخلط يحافظ على العناصر', () {
    final a = [1, 2, 3, 4, 5];
    final b = shuffled(a);
    expect(b.length, a.length);
    expect(b.toSet(), a.toSet());
  });

  test('نسخة قاعدة البيانات ذهاباً وإياباً', () {
    final db = Db.initial();
    db.items.add(Item(id: 1, grade: 1, subject: 2, type: 'wrd', text: 'جملة قصيرة', pa: {0: 'x.m4a'}));
    final back = Db.fromJson(db.toJson());
    expect(back.items.first.pa[0], 'x.m4a');
    expect(back.grades.first.name, 'الصف الأول');
  });
}
