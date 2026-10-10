import 'package:inv_tracker/features/investment/domain/entities/custom_investment_type_entity.dart';
import 'package:inv_tracker/features/investment/domain/repositories/custom_investment_type_repository.dart';
import 'package:rxdart/rxdart.dart';

/// In-memory [CustomInvestmentTypeRepository]. Sharing one instance between
/// two containers stands in for the app being restarted.
class FakeCustomInvestmentTypeRepository
    implements CustomInvestmentTypeRepository {
  FakeCustomInvestmentTypeRepository([
    Iterable<CustomInvestmentType> seed = const [],
  ]) {
    for (final def in seed) {
      _defs[def.id] = def;
    }
    _subject = BehaviorSubject.seeded(_snapshot());
  }

  final Map<String, CustomInvestmentType> _defs = {};
  late final BehaviorSubject<List<CustomInvestmentType>> _subject;

  /// How many definitions were written, for "no write" assertions.
  int writes = 0;

  List<CustomInvestmentType> get definitions => _snapshot();

  List<CustomInvestmentType> _snapshot() => List.unmodifiable(_defs.values);

  @override
  Stream<List<CustomInvestmentType>> watchAll() => _subject.stream;

  @override
  Future<List<CustomInvestmentType>> getAll() async => _snapshot();

  /// How many times every definition was deleted, for Replace assertions.
  int deleteAlls = 0;

  @override
  Future<void> deleteAll() async {
    deleteAlls++;
    _defs.clear();
    _subject.add(_snapshot());
  }

  @override
  Future<void> put(CustomInvestmentType type) async {
    writes++;
    _defs[type.id] = type;
    _subject.add(_snapshot());
  }
}
