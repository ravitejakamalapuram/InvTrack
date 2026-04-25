class CsvUtils {
  /// Sanitizes a field to prevent CSV formula injection (CSV Injection).
  ///
  /// If a field starts with one of the characters that can trigger formula execution
  /// in spreadsheet software (=, +, -, @, tab, carriage return), we prepend a single quote (')
  /// to force it to be treated as text.
  ///
  /// Reference: https://owasp.org/www-community/attacks/CSV_Injection
  static dynamic sanitizeField(dynamic value) {
    if (value is String) {
      if (value.startsWith(RegExp(r'^[\s]*[=+\-@\t\r]'))) {
        return "'$value";
      }
    }
    return value;
  }
}
