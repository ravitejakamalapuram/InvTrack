import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:inv_tracker/features/investment/domain/entities/metal_rates.dart';

/// Reads today's metal rates: one public document, `metalRates/latest`,
/// written once a day by the rates job. Not user data, so account deletion
/// and export do not cover it.
class MetalRatesRepository {
  const MetalRatesRepository(this._firestore);

  final FirebaseFirestore _firestore;

  /// The stored rates, or null when there are none or they cannot be read
  /// (offline with nothing cached, signed out). The rate is a nicety, so a
  /// failure is never shown to the user and nothing about it is logged.
  Future<MetalRates?> latest() async {
    try {
      final snapshot = await _firestore.doc('metalRates/latest').get();
      return MetalRates.fromMap(snapshot.data());
    } catch (_) {
      return null;
    }
  }
}
