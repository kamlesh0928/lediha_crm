// Replaces the default Flutter sample test (which refers to a MyApp class that does not exist here).
import 'package:flutter_test/flutter_test.dart';
import 'package:lediha_crm/core/env.dart';
import 'package:lediha_crm/core/util.dart';

void main() {
  test('normPhone keeps the last 10 digits', () {
    expect(normPhone('+91 98765-43210'), '9876543210');
    expect(normPhone('09876543210'), '9876543210');
    expect(normPhone(null), '');
  });

  test('waNumber adds the India code to 10-digit numbers', () {
    expect(waNumber('9876543210'), '919876543210');
    expect(waNumber('+91 98765 43210'), '919876543210');
  });

  test('label makes snake_case readable', () {
    expect(label('follow_up'), 'Follow up');
    expect(label(null), '-');
  });

  test('toNum is safe with bad input', () {
    expect(toNum('12.5'), 12.5);
    expect(toNum('abc'), 0);
    expect(toNum(null), 0);
  });

  test('app reports missing configuration when started without env.json', () {
    // Tests run without --dart-define, so nothing is configured.
    expect(Env.isConfigured, isFalse);
  });

  test('endOfToday is after now and on the same day', () {
    final end = endOfToday();
    expect(end.isAfter(DateTime.now().subtract(const Duration(seconds: 1))), isTrue);
    expect(sameDay(end, DateTime.now()), isTrue);
  });
}
