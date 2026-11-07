/// Base sealed class representing the outcome of a library scan.
sealed class ScanResult<T> {
  const ScanResult();

  /// Creates a successful scan result containing [data].
  const factory ScanResult.success(T data) = ScanSuccess<T>;

  /// Creates a failed scan result containing [error].
  const factory ScanResult.failure(ScanException error) = ScanFailure<T>;

  /// Returns true if the scan was successful.
  bool get isSuccess;

  /// Returns true if the scan failed.
  bool get isFailure => !isSuccess;

  /// The result data if successful; throws [StateError] if failure.
  T get data;

  /// The scan error if failure; null if successful.
  ScanException? get error;

  /// The result data if successful; null if failure.
  T? get dataOrNull;

  /// Pattern matching fold method.
  R fold<R>({
    required R Function(T data) onSuccess,
    required R Function(ScanException error) onFailure,
  });
}

/// Represents a successful scan operation.
class ScanSuccess<T> extends ScanResult<T> {
  const ScanSuccess(this.data);

  @override
  final T data;

  @override
  bool get isSuccess => true;

  @override
  ScanException? get error => null;

  @override
  T? get dataOrNull => data;

  @override
  R fold<R>({
    required R Function(T data) onSuccess,
    required R Function(ScanException error) onFailure,
  }) =>
      onSuccess(data);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ScanSuccess<T> && other.data == data;

  @override
  int get hashCode => data.hashCode;

  @override
  String toString() => 'ScanSuccess($data)';
}

/// Represents a failed scan operation.
class ScanFailure<T> extends ScanResult<T> {
  const ScanFailure(this.error);

  @override
  final ScanException error;

  @override
  bool get isSuccess => false;

  @override
  T get data => throw StateError('Cannot get data from ScanFailure: $error');

  @override
  T? get dataOrNull => null;

  @override
  R fold<R>({
    required R Function(T data) onSuccess,
    required R Function(ScanException error) onFailure,
  }) =>
      onFailure(error);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ScanFailure<T> && other.error == error;

  @override
  int get hashCode => error.hashCode;

  @override
  String toString() => 'ScanFailure($error)';
}

/// Exception representing an error encountered during directory scanning.
class ScanException implements Exception {
  final String message;
  final Object? cause;

  const ScanException(this.message, [this.cause]);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ScanException &&
          runtimeType == other.runtimeType &&
          message == other.message &&
          cause == other.cause;

  @override
  int get hashCode => Object.hash(message, cause);

  @override
  String toString() =>
      'ScanException: $message${cause != null ? ' (Cause: $cause)' : ''}';
}
