import 'package:flutter_test/flutter_test.dart';

import 'package:prod/services/date_display.dart';
import 'package:prod/services/task_validator.dart';

void main() {
  const validator = TaskValidator();

  test('rejects a blank title and non-positive XP or XP below minCustomXp (Section 11, 28)', () {
    final resultZero = validator.validate(title: '   ', xpText: '0');
    expect(resultZero.isValid, isFalse);
    expect(resultZero.titleError, isNotNull);
    expect(resultZero.xpError, isNotNull);

    // 4 is below minCustomXp (5)
    final resultLow = validator.validate(title: 'Title', xpText: '4');
    expect(resultLow.isValid, isFalse);
    expect(resultLow.xpError, contains('at least 5'));
  });

  test('rejects accidental huge XP values above maxCustomXp (Section 11, 28)', () {
    // 51 is above maxCustomXp (50)
    final result51 = validator.validate(title: 'Task', xpText: '51');
    expect(result51.isValid, isFalse);
    expect(result51.xpError, contains('cannot exceed 50'));

    final result500 = validator.validate(title: 'Task', xpText: '500');
    expect(result500.isValid, isFalse);

    final result50000 = validator.validate(title: 'Task', xpText: '50000');
    expect(result50000.isValid, isFalse);
  });

  test('accepts custom XP within the 5..50 range (Section 11, 28)', () {
    for (final xp in [5, 10, 15, 20, 25, 30, 45, 50]) {
      final result = validator.validate(title: ' Coding ', xpText: '$xp');
      expect(result.isValid, isTrue, reason: '$xp should be valid');
      expect(validator.parseXp('$xp'), xp);
    }
    expect(validator.normalizeDescription('  notes  '), 'notes');
    expect(validator.normalizeDescription('   '), isNull);
  });

  test('preserves legacy tasks with existing XP when originalXp is passed (Section 15, 23)', () {
    final legacyResult = validator.validate(
      title: 'Legacy Quest',
      xpText: '100',
      originalXp: 100,
    );
    expect(legacyResult.isValid, isTrue);
    expect(validator.parseXp('100', originalXp: 100), 100);
  });

  test('detects overdue due dates by calendar day', () {
    expect(
      isDueDateOverdue(DateTime(2026, 9, 4), DateTime(2026, 9, 5)),
      isTrue,
    );
    expect(
      isDueDateOverdue(DateTime(2026, 9, 5), DateTime(2026, 9, 5)),
      isFalse,
    );
  });
}
