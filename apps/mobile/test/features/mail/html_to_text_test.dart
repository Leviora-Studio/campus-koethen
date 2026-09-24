import 'package:campus_koethen/features/mail/data/html_to_text.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('normalizes excessive blank lines in a plain-text mail', () {
    expect(
      normalizeMailBody('Hallo\r\n  \r\n\r\n\r\nWelt  \r\n'),
      'Hallo\n\nWelt',
    );
  });

  test('keeps one paragraph break in HTML-derived mail', () {
    expect(
      htmlToPlainText('<div>Hallo</div><div><br></div><div>Welt</div>'),
      'Hallo\n\nWelt',
    );
  });
}
