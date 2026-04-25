class CsvUtils {
  // Matches an optional run of whitespace (incl. space, \t, \n, \r) followed by
  // a spreadsheet formula trigger character. Compiled once for hot-path reuse.
  static final RegExp _unsafePrefix = RegExp(r'^\s*[=+\-@\t\r]');

  /// Sanitizes a field to prevent CSV formula injection (CSV Injection).
  ///
  /// If a field starts with one of the characters that can trigger formula
  /// execution in spreadsheet software (`=`, `+`, `-`, `@`, tab, carriage
  /// return) — optionally preceded by leading whitespace, which spreadsheet
  /// apps strip before evaluating formulas — we prepend a single quote (`'`)
  /// to force the cell to be treated as text.
  ///
  /// Reference: https://owasp.org/www-community/attacks/CSV_Injection
  static dynamic sanitizeField(dynamic value) {
    if (value is String) {
      if (value.startsWith(_unsafePrefix)) {
        return "'$value";
      }
    }
    return value;
  }
}
