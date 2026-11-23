import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:inv_tracker/features/investment/domain/entities/metal_rates.dart';
import 'package:inv_tracker/features/investment/domain/repositories/metal_rates_repository.dart';

/// Reads `metalRates/latest`. Not user data, so account deletion and export do
/// not cover it.
class FirestoreMetalRatesRepository implements MetalRatesRepository {
  const FirestoreMetalRatesRepository(this._firestore);

  final FirebaseFirestore _firestore;

  /// The rate is a nicety, so a failure (offline with nothing cached, signed
  /// out) is never shown to the user and nothing about it is logged.
  @override
  Future<MetalRates?> latest() async {
    try {
      final snapshot = await _firestore.doc('metalRates/latest').get();
      return MetalRates.fromMap(snapshot.data());
    } catch (_) {
      return null;
    }
  }
}
