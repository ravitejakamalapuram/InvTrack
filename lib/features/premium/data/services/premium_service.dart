import 'package:shared_preferences/shared_preferences.dart';

class PremiumService {
  final SharedPreferences _prefs;
  static const String _isPremiumKey = 'is_premium_user';

  PremiumService(this._prefs);

  bool get isPremium => _prefs.getBool(_isPremiumKey) ?? false;

  Future<void> setPremium(bool value) async {
    await _prefs.setBool(_isPremiumKey, value);
  }
}
