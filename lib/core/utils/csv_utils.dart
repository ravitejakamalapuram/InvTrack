class CsvUtils {
  // Matches any run of guard quotes, then an optional run of whitespace (incl.
  // space, \t, \n, \r), then a spreadsheet formula trigger character. The
  // quote case keeps a stored "'=x" distinct from a guarded "=x" on restore.
  // Compiled once for hot-path reuse.
  static final RegExp _injectionPattern = RegExp(r"^'*\s*[=+\-@\t\r]");

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
      if (_injectionPattern.hasMatch(value)) {
        return "'$value";
      }
    }
    return value;
  }

  /// Undoes [sanitizeField] for a file this app exported itself: drops the
  /// guard quote, but only when what follows would have needed one.
  static String restoreField(String value) {
    if (value.startsWith("'") &&
        _injectionPattern.hasMatch(value.substring(1))) {
      return value.substring(1);
    }
    return value;
  }
}
