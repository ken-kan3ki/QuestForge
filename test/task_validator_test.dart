import 'package:flutter_test/flutter_test.dart';

import 'package:prod/services/date_display.dart';
import 'package:prod/services/task_validator.dart';

void main() {
  const validator = TaskValidator();

  test('rejects a blank title and non-positive XP or XP below minCustomXp', () {
    final resultZero = validator.validate(title: '   ', xpText: '0');
    expect(resultZero.isValid, isFalse);
    expect(resultZero.titleError, isNotNull);
    expect(resultZero.xpError, isNotNull);

    final resultLow = validator.validate(title: 'Title', xpText: '24');
    expect(resultLow.isValid, isFalse);
    expect(resultLow.xpError, contains('at least 25'));
  });

  test('rejects accidental huge XP values above maxCustomXp', () {
    final result501 = validator.validate(title: 'Task', xpText: '501');
    expect(result501.isValid, isFalse);
    expect(result501.xpError, contains('cannot exceed 500'));

    final result5000 = validator.validate(title: 'Task', xpText: '5000');
    expect(result5000.isValid, isFalse);

    final result50000 = validator.validate(title: 'Task', xpText: '50000');
    expect(result50000.isValid, isFalse);
  });

  test('accepts custom XP within the 25..500 range', () {
    for (final xp in [25, 50, 100, 150, 250, 350, 400, 500]) {
      final result = validator.validate(title: ' Coding ', xpText: '$xp');
      expect(result.isValid, isTrue, reason: '$xp should be valid');
      expect(validator.parseXp('$xp'), xp);
    }
    expect(validator.normalizeDescription('  notes  '), 'notes');
    expect(validator.normalizeDescription('   '), isNull);
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
