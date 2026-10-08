/// Keeps personal text out of crash reports (CLAUDE.md rule 7).
///
/// An error's message can hold a document path, an email, a name or an
/// amount, so a report carries only the error's type and, for Firebase and
/// platform errors, their machine code. The stack trace is kept: it holds
/// code locations, not user data.
library;

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:inv_tracker/core/error/app_exception.dart';

/// A value that can hold no free text: a code, an id, a count label.
final _token = RegExp(r'^[A-Za-z0-9_.:-]{1,64}$');

/// Whether [value] may be sent to Crashlytics as is: a number, a bool, or a
/// short token with no spaces, `@` or `/`.
bool isSafeCrashValue(Object? value) =>
    value is num ||
    value is bool ||
    (value is String && _token.hasMatch(value));

/// [error] reduced to its type and code, for example
/// `FirebaseException(cloud_firestore/not-found)`. Never its message.
String describeForCrashReport(Object? error) {
  final type = error.runtimeType.toString();
  final code = switch (error) {
    FirebaseException(:final plugin, :final code) => '$plugin/$code',
    PlatformException(:final code) => code,
    AuthException(:final code) => code.name,
    _ => null,
  };
  // Each part of a Firebase code must be a token on its own.
  final safe = code != null && code.split('/').every(isSafeCrashValue);
  return safe ? '$type($code)' : type;
}

/// What a crash report records in place of the original error.
@immutable
class RedactedError implements Exception {
  RedactedError(Object? error) : description = describeForCrashReport(error);

  final String description;

  @override
  String toString() => description;
}

/// A warning or error logged without an error object. Its text is the
/// developer-written log message, which the report's reason carries anyway,
/// so it is sent as is.
@immutable
class LoggedMessage implements Exception {
  const LoggedMessage(this.message);

  final String message;

  @override
  String toString() => message;
}

/// [details] with the exception reduced to its type and code. The context and
/// extra information are dropped: they describe widgets, whose keys and text
/// can hold user data. The stack and library are kept.
FlutterErrorDetails redactFlutterErrorDetails(FlutterErrorDetails details) =>
    FlutterErrorDetails(
      exception: RedactedError(details.exception),
      stack: details.stack,
      library: details.library,
      silent: details.silent,
    );
