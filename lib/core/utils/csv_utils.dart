/// Utility class for CSV handling
class CsvUtils {
  CsvUtils._();

  /// Sanitize a field value to prevent CSV Formula Injection.
  ///
  /// If a field starts with any of the following characters:
  /// - Equals to (=)
  /// - Plus (+)
  /// - Minus (-)
  /// - At (@)
  /// - Tab (0x09)
  /// - Carriage return (0x0D)
  ///
  /// It can be interpreted as a formula by spreadsheet software (Excel, LibreOffice).
  /// To prevent this, we prepend a single quote (') to force it to be treated as text.
  static dynamic sanitizeField(dynamic value) {
    if (value is String) {
      if (value.isEmpty) return value;

      // Check for dangerous start characters
      if (value.startsWith('=') ||
          value.startsWith('+') ||
          value.startsWith('-') ||
          value.startsWith('@') ||
          value.startsWith('\t') ||
          value.startsWith('\r')) {
        return "'$value";
      }
    }
    return value;
  }
}
