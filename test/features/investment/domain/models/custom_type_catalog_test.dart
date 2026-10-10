// #936: rules for the account's reusable custom investment types. The
// catalog is pure: it decides what to write, the notifier writes it.
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/features/investment/domain/entities/custom_investment_type_entity.dart';
import 'package:inv_tracker/features/investment/domain/models/custom_type_catalog.dart';

final _t0 = DateTime.utc(2026, 10, 1);
final _now = DateTime.utc(2026, 10, 10, 9);

CustomInvestmentType _def(
  String id,
  String label, {
  DateTime? created,
  DateTime? removedAt,
}) => CustomInvestmentType(
  id: id,
  label: label,
  createdAt: created ?? _t0,
  updatedAt: created ?? _t0,
  removedAt: removedAt,
);

void main() {
  group('suggestions', () {
    test('lists active types by label, ignoring case', () {
      final all = [
        _def('b', 'wine'),
        _def('a', 'Art Prints'),
        _def('c', 'Vintage Cars'),
      ];
      expect(CustomTypeCatalog.suggestions(all).map((d) => d.label), [
        'Art Prints',
        'Vintage Cars',
        'wine',
      ]);
    });

    test('leaves out removed types', () {
      final all = [_def('a', 'Art Prints'), _def('b', 'Wine', removedAt: _t0)];
      expect(CustomTypeCatalog.suggestions(all).map((d) => d.id), ['a']);
    });

    test('shows one entry for case and spacing variants (oldest wins)', () {
      final all = [
        _def('new', 'ART  prints', created: DateTime.utc(2026, 10, 5)),
        _def('old', 'Art Prints', created: DateTime.utc(2026, 10, 2)),
      ];
      final s = CustomTypeCatalog.suggestions(all);
      expect(s.map((d) => d.id), ['old']);
    });
  });

  group('save', () {
    test('creates a type with the cleaned label and the casing typed', () {
      final change = CustomTypeCatalog.save(
        const [],
        '  Art   Prints ',
        newId: 'id-1',
        now: _now,
      );
      expect(change.issue, isNull);
      expect(change.write, isNotNull);
      expect(change.write!.id, 'id-1');
      expect(change.write!.label, 'Art Prints');
      expect(change.write!.createdAt, _now);
      expect(change.write!.isRemoved, isFalse);
      expect(change.result, change.write);
    });

    test('a blank label is rejected and writes nothing', () {
      final change = CustomTypeCatalog.save(
        const [],
        ' \u200B ',
        newId: 'x',
        now: _now,
      );
      expect(change.issue, CustomTypeIssue.blank);
      expect(change.write, isNull);
      expect(change.result, isNull);
    });

    test('a label over 40 characters is rejected', () {
      final change = CustomTypeCatalog.save(
        const [],
        'a' * 41,
        newId: 'x',
        now: _now,
      );
      expect(change.issue, CustomTypeIssue.tooLong);
      expect(change.write, isNull);
    });

    test(
      'a case or spacing variant of an active type returns it with no write',
      () {
        final existing = _def('a', 'Art Prints');
        final change = CustomTypeCatalog.save(
          [existing],
          'art   PRINTS',
          newId: 'x',
          now: _now,
        );
        expect(change.issue, isNull);
        expect(change.write, isNull);
        expect(change.result, existing);
      },
    );

    test(
      'saving a removed key revives the same definition, keeping its casing',
      () {
        final removed = _def(
          'a',
          'Art Prints',
          removedAt: DateTime.utc(2026, 10, 3),
        );
        final change = CustomTypeCatalog.save(
          [removed],
          'ART PRINTS',
          newId: 'x',
          now: _now,
        );
        expect(change.issue, isNull);
        expect(change.write!.id, 'a');
        expect(change.write!.label, 'Art Prints');
        expect(change.write!.isRemoved, isFalse);
        expect(change.write!.createdAt, _t0);
        expect(change.write!.updatedAt, _now);
      },
    );

    test('at 50 active types a new one is rejected', () {
      final full = [for (var i = 0; i < 50; i++) _def('d$i', 'Type $i')];
      final change = CustomTypeCatalog.save(
        full,
        'One more',
        newId: 'x',
        now: _now,
      );
      expect(change.issue, CustomTypeIssue.atCapacity);
      expect(change.write, isNull);
    });

    test('at 50 active types an existing one is still returned', () {
      final full = [for (var i = 0; i < 50; i++) _def('d$i', 'Type $i')];
      final change = CustomTypeCatalog.save(
        full,
        'type 7',
        newId: 'x',
        now: _now,
      );
      expect(change.issue, isNull);
      expect(change.result!.id, 'd7');
    });

    test('removed types do not count towards the 50', () {
      final all = [
        for (var i = 0; i < 49; i++) _def('d$i', 'Type $i'),
        for (var i = 0; i < 10; i++) _def('r$i', 'Gone $i', removedAt: _t0),
      ];
      final change = CustomTypeCatalog.save(
        all,
        'Fiftieth',
        newId: 'x',
        now: _now,
      );
      expect(change.issue, isNull);
      expect(change.write!.label, 'Fiftieth');
    });

    test('at 50 active types a removed one cannot be revived', () {
      final all = [
        for (var i = 0; i < 50; i++) _def('d$i', 'Type $i'),
        _def('r', 'Gone', removedAt: _t0),
      ];
      final change = CustomTypeCatalog.save(all, 'gone', newId: 'x', now: _now);
      expect(change.issue, CustomTypeIssue.atCapacity);
    });
  });

  group('rename', () {
    test('changes the label of that one definition', () {
      final a = _def('a', 'Art');
      final change = CustomTypeCatalog.rename(
        [a, _def('b', 'Wine')],
        'a',
        'Paintings',
        now: _now,
      );
      expect(change.issue, isNull);
      expect(change.write!.id, 'a');
      expect(change.write!.label, 'Paintings');
      expect(change.write!.updatedAt, _now);
      expect(change.write!.createdAt, a.createdAt);
    });

    test('changing only case or spacing of its own name is allowed', () {
      final change = CustomTypeCatalog.rename(
        [_def('a', 'art prints')],
        'a',
        'Art  Prints',
        now: _now,
      );
      expect(change.issue, isNull);
      expect(change.write!.label, 'Art Prints');
    });

    test('renaming onto another active definition is rejected', () {
      final change = CustomTypeCatalog.rename(
        [_def('a', 'Art'), _def('b', 'Wine')],
        'a',
        ' WINE ',
        now: _now,
      );
      expect(change.issue, CustomTypeIssue.duplicate);
      expect(change.write, isNull);
    });

    test('renaming onto a removed definition is rejected too', () {
      final change = CustomTypeCatalog.rename(
        [_def('a', 'Art'), _def('b', 'Wine', removedAt: _t0)],
        'a',
        'wine',
        now: _now,
      );
      expect(change.issue, CustomTypeIssue.duplicate);
    });

    test('blank, too long and unknown ids are rejected', () {
      final all = [_def('a', 'Art')];
      expect(
        CustomTypeCatalog.rename(all, 'a', '  ', now: _now).issue,
        CustomTypeIssue.blank,
      );
      expect(
        CustomTypeCatalog.rename(all, 'a', 'x' * 41, now: _now).issue,
        CustomTypeIssue.tooLong,
      );
      expect(
        CustomTypeCatalog.rename(all, 'zzz', 'Wine', now: _now).issue,
        CustomTypeIssue.notFound,
      );
    });

    test('an unchanged name writes nothing', () {
      final a = _def('a', 'Art');
      final change = CustomTypeCatalog.rename([a], 'a', 'Art', now: _now);
      expect(change.issue, isNull);
      expect(change.write, isNull);
      expect(change.result, a);
    });
  });

  group('remove', () {
    test('marks that one definition removed and keeps its label', () {
      final change = CustomTypeCatalog.remove(
        [_def('a', 'Art'), _def('b', 'Wine')],
        'a',
        now: _now,
      );
      expect(change.write!.id, 'a');
      expect(change.write!.label, 'Art');
      expect(change.write!.removedAt, _now);
    });

    test('removing twice writes nothing the second time', () {
      final gone = _def('a', 'Art', removedAt: _t0);
      final change = CustomTypeCatalog.remove([gone], 'a', now: _now);
      expect(change.issue, isNull);
      expect(change.write, isNull);
    });

    test('an unknown id is reported', () {
      expect(
        CustomTypeCatalog.remove(const [], 'a', now: _now).issue,
        CustomTypeIssue.notFound,
      );
    });
  });

  group('resolveForInvestment', () {
    test('blank text means no custom type', () {
      final link = CustomTypeCatalog.resolveForInvestment([
        _def('a', 'Art'),
      ], '  ');
      expect(link.id, isNull);
      expect(link.label, isNull);
    });

    test('text matching an active type links to it and adopts its casing', () {
      final link = CustomTypeCatalog.resolveForInvestment([
        _def('a', 'Art Prints'),
      ], 'art   prints');
      expect(link.id, 'a');
      expect(link.label, 'Art Prints');
    });

    test('text matching no type stays a free label with the casing typed', () {
      final link = CustomTypeCatalog.resolveForInvestment([
        _def('a', 'Art Prints'),
      ], ' Stamps ');
      expect(link.id, isNull);
      expect(link.label, 'Stamps');
    });

    test('text matching only a removed type is a free label', () {
      final link = CustomTypeCatalog.resolveForInvestment([
        _def('a', 'Art Prints', removedAt: _t0),
      ], 'art prints');
      expect(link.id, isNull);
      expect(link.label, 'art prints');
    });

    test(
      'unchanged text keeps the existing link, even after the type was renamed',
      () {
        // The investment saved "Art" when the type was called "Art"; the type
        // is now "Paintings". Saving the investment again must not unlink it.
        final link = CustomTypeCatalog.resolveForInvestment(
          [_def('a', 'Paintings')],
          'Art',
          existingId: 'a',
          existingLabel: 'Art',
        );
        expect(link.id, 'a');
        expect(link.label, 'Art');
      },
    );

    test('changed text is resolved afresh', () {
      final link = CustomTypeCatalog.resolveForInvestment(
        [_def('a', 'Paintings'), _def('b', 'Wine')],
        'wine',
        existingId: 'a',
        existingLabel: 'Art',
      );
      expect(link.id, 'b');
      expect(link.label, 'Wine');
    });
  });
}
