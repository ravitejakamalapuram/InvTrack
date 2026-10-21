// A64 (#811): HealthScoreSnapshotModel.fromFirestore with missing, wrongly typed
// and non-finite fields. A bad snapshot must throw a FormatException that names
// the field, never return a half-built model.
// ignore_for_file: subtype_of_sealed_class
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/features/portfolio_health/data/models/health_score_snapshot_model.dart';

class _FakeDoc extends Fake implements DocumentSnapshot<Object?> {
  _FakeDoc(this._data, {this.id = 'snap-1'});

  final Object? _data;

  @override
  final String id;

  @override
  Object? data() => _data;
}

const _scoreFields = [
  'overallScore',
  'returnsScore',
  'diversificationScore',
  'liquidityScore',
  'goalAlignmentScore',
  'actionReadinessScore',
];

void main() {
  final calculated = Timestamp.fromDate(DateTime(2026, 3, 1, 10));

  Map<String, dynamic> valid() => {
    'overallScore': 72.5,
    'returnsScore': 80,
    'diversificationScore': 60,
    'liquidityScore': 55.5,
    'goalAlignmentScore': 90,
    'actionReadinessScore': 70,
    'calculatedAt': calculated,
  };

  HealthScoreSnapshotModel read(Object? data) =>
      HealthScoreSnapshotModel.fromFirestore(_FakeDoc(data));

  group('HealthScoreSnapshotModel.fromFirestore', () {
    test('a complete document maps, and integer scores become doubles', () {
      final m = read(valid());

      expect(m.id, 'snap-1');
      expect(m.overallScore, 72.5);
      expect(m.returnsScore, 80.0);
      expect(m.calculatedAt, calculated.toDate());
      expect(m.metadata, isNull);
    });

    test('metadata is kept when it is a map and ignored when it is not', () {
      expect(
        read({
          ...valid(),
          'metadata': {'v': 2},
        }).metadata,
        {'v': 2},
      );
      expect(read({...valid(), 'metadata': 'oops'}).metadata, isNull);
    });

    test('null document data is a FormatException', () {
      expect(() => read(null), throwsA(isA<FormatException>()));
    });

    test('document data that is not a map is a FormatException', () {
      expect(() => read(<int>[1, 2]), throwsA(isA<FormatException>()));
    });

    for (final field in _scoreFields) {
      test('missing $field names the field', () {
        final data = valid()..remove(field);

        expect(
          () => read(data),
          throwsA(
            isA<FormatException>().having(
              (e) => e.message,
              'message',
              'Missing required field: $field',
            ),
          ),
        );
      });

      test('a text $field is rejected', () {
        expect(
          () => read({...valid(), field: '72'}),
          throwsA(
            isA<FormatException>().having(
              (e) => e.message,
              'message',
              contains('Invalid type for $field'),
            ),
          ),
        );
      });

      test('a non-finite $field is rejected', () {
        for (final bad in [double.nan, double.infinity]) {
          expect(
            () => read({...valid(), field: bad}),
            throwsA(
              isA<FormatException>().having(
                (e) => e.message,
                'message',
                contains('Invalid value for $field'),
              ),
            ),
          );
        }
      });
    }

    test('missing calculatedAt is rejected', () {
      final data = valid()..remove('calculatedAt');

      expect(
        () => read(data),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            'Missing required field: calculatedAt',
          ),
        ),
      );
    });

    test('a calculatedAt that is not a Timestamp is rejected', () {
      expect(
        () => read({...valid(), 'calculatedAt': '2026-03-01'}),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('Invalid type for calculatedAt'),
          ),
        ),
      );
    });
  });

  group('HealthScoreSnapshotModel.toFirestore', () {
    test('writes the six scores and calculatedAt, and reads back equal', () {
      final model = read(valid());
      final map = model.toFirestore();

      for (final field in _scoreFields) {
        expect(map[field], isA<num>(), reason: field);
      }
      expect(map['calculatedAt'], isA<Timestamp>());
      expect(HealthScoreSnapshotModel.fromFirestore(_FakeDoc(map)), model);
    });
  });
}
