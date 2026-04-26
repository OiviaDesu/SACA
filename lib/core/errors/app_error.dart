enum AppFailureKind {
  modelMissing,
  permissionDenied,
  recordingFailed,
  transcriptionFailed,
  emptyInput,
  analysisFailed,
}

class AppFailure implements Exception {
  const AppFailure({
    required this.kind,
    required this.message,
    this.debugMessage,
  });

  final AppFailureKind kind;
  final String message;
  final Object? debugMessage;
}

class AppResult<T> {
  const AppResult._({this.value, this.failure});

  const AppResult.success(T value) : this._(value: value);
  const AppResult.failure(AppFailure failure) : this._(failure: failure);

  final T? value;
  final AppFailure? failure;

  bool get isSuccess => failure == null;
}
