import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/error/app_exception.dart';
import 'package:inv_tracker/features/settings/data/services/account_data_deletion_service.dart';
import 'package:inv_tracker/features/settings/data/services/callable_account_data_deleter.dart';
import 'package:mocktail/mocktail.dart';

class MockCallable extends Mock implements HttpsCallable {}

class MockResult extends Mock implements HttpsCallableResult<dynamic> {}

void main() {
  late MockCallable callable;

  CallableAccountDataDeleter build({Duration? timeout}) =>
      CallableAccountDataDeleter(
        callable: () => callable,
        timeout: timeout ?? const Duration(seconds: 120),
      );

  void returns(Object? data) {
    final result = MockResult();
    when(() => result.data).thenReturn(data);
    when(() => callable.call<dynamic>()).thenAnswer((_) async => result);
  }

  void fails(String code) {
    when(
      () => callable.call<dynamic>(),
    ).thenThrow(FirebaseFunctionsException(message: code, code: code));
  }

  setUp(() => callable = MockCallable());

  test('completes when the function confirms {deleted: true}', () async {
    returns({'deleted': true});
    await build()();
    verify(() => callable.call<dynamic>()).called(1);
  });

  test('an unexpected result is NOT treated as success', () async {
    returns({'deleted': false});
    await expectLater(build()(), throwsStateError);
    returns(null);
    await expectLater(build()(), throwsStateError);
  });

  for (final code in ['not-found', 'unimplemented']) {
    test('"$code" (function not deployed) -> fallback signal', () async {
      fails(code);
      await expectLater(
        build()(),
        throwsA(isA<ServerDeletionUnavailableException>()),
      );
    });
  }

  for (final code in ['unavailable', 'deadline-exceeded']) {
    test('"$code" -> NetworkException', () async {
      fails(code);
      await expectLater(build()(), throwsA(isA<NetworkException>()));
    });
  }

  test('other errors (e.g. internal) are rethrown unchanged', () async {
    fails('internal');
    await expectLater(
      build()(),
      throwsA(
        isA<FirebaseFunctionsException>().having(
          (e) => e.code,
          'code',
          'internal',
        ),
      ),
    );
  });

  test(
    'a call that never returns times out as NetworkException',
    () async {
      when(
        () => callable.call<dynamic>(),
      ).thenAnswer((_) => Completer<HttpsCallableResult<dynamic>>().future);
      final deleter = CallableAccountDataDeleter(
        callable: () => callable,
        timeout: Duration.zero,
      );
      await expectLater(deleter(), throwsA(isA<NetworkException>()));
    },
    timeout: const Timeout(Duration(seconds: 15)),
  );
}
