import 'package:flutter_test/flutter_test.dart';
import 'package:arrange_teacher/config.dart';

void main() {
  test('عنوان الصفحة المحلية صحيح', () {
    expect(appUrl, 'http://localhost:8080/index.html');
    expect(appHost, 'localhost');
  });
}
