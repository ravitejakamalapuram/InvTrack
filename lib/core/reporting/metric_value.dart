/// A metric that is either known or unknown, never a silent zero (money
/// rule 4). Renderers show an em dash for [Unknown].
library;

enum UnknownReason {
  /// An open investment or the period's opening/closing value is missing.
  awaitingValue,

  /// The metric does not apply (no previous figure to compare, no solution,
  /// or the metric is not computed for this slice).
  notApplicable,
}

sealed class MetricValue {
  const MetricValue();

  /// The number, or null when unknown.
  double? get valueOrNull;
}

final class Known extends MetricValue {
  final double value;
  const Known(this.value);

  @override
  double? get valueOrNull => value;

  @override
  bool operator ==(Object other) => other is Known && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'Known($value)';
}

final class Unknown extends MetricValue {
  final UnknownReason reason;
  const Unknown(this.reason);

  @override
  double? get valueOrNull => null;

  @override
  bool operator ==(Object other) => other is Unknown && other.reason == reason;

  @override
  int get hashCode => reason.hashCode;

  @override
  String toString() => 'Unknown($reason)';
}
