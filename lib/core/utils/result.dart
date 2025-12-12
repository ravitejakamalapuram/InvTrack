/// Result type for operations that can succeed or fail.
/// 
/// This provides a clean way to handle errors without exceptions,
/// making error handling explicit and type-safe.
sealed class Result<T> {
  const Result();

  /// Creates a successful result with data.
  factory Result.success(T data) = Success<T>;

  /// Creates a failed result with an error message.
  factory Result.failure(String error) = Failure<T>;

  /// Returns true if this is a success result.
  bool get isSuccess;

  /// Returns true if this is a failure result.
  bool get isFailure => !isSuccess;

  /// Returns the data if success, null if failure.
  T? get data;

  /// Returns the error message if failure, null if success.
  String? get error;

  /// Maps the success value to a new type.
  Result<R> map<R>(R Function(T data) mapper) {
    return switch (this) {
      Success(data: final data) => Result.success(mapper(data)),
      Failure(error: final error) => Result.failure(error),
    };
  }

  /// Executes onSuccess if success, onFailure if failure.
  R when<R>({
    required R Function(T data) success,
    required R Function(String error) failure,
  }) {
    return switch (this) {
      Success(data: final data) => success(data),
      Failure(error: final error) => failure(error),
    };
  }
}

/// Represents a successful operation result.
final class Success<T> extends Result<T> {
  @override
  final T data;

  const Success(this.data);

  @override
  bool get isSuccess => true;

  @override
  String? get error => null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Success<T> && runtimeType == other.runtimeType && data == other.data;

  @override
  int get hashCode => data.hashCode;

  @override
  String toString() => 'Success($data)';
}

/// Represents a failed operation result.
final class Failure<T> extends Result<T> {
  @override
  final String error;

  const Failure(this.error);

  @override
  bool get isSuccess => false;

  @override
  T? get data => null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Failure<T> && runtimeType == other.runtimeType && error == other.error;

  @override
  int get hashCode => error.hashCode;

  @override
  String toString() => 'Failure($error)';
}

