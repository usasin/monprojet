import 'dart:async';

import 'package:ai_prospect_gps/services/prospect_search_session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('successful search work returns its original value', () async {
    final session = ProspectSearchSession();

    final result = await session.waitFor(
      Future.value(['node_1', 'node_2']),
      timeout: const Duration(seconds: 1),
    );

    expect(result, ['node_1', 'node_2']);
  });

  test('cancel releases a wait while the network future is still pending',
      () async {
    final source = Completer<String>();
    final session = ProspectSearchSession();
    final waiting = session.waitFor(
      source.future,
      timeout: const Duration(seconds: 1),
    );
    final assertion = expectLater(
      waiting,
      throwsA(isA<ProspectSearchCancelled>()),
    );

    session.cancel();
    await assertion;

    expect(source.isCompleted, isFalse);
  });

  test('a response arriving after cancel cannot publish search results',
      () async {
    final source = Completer<List<String>>();
    final session = ProspectSearchSession();
    final published = <String>[];
    final waiting = session
        .waitFor(source.future, timeout: const Duration(seconds: 1))
        .then<Object>((ids) {
      published.addAll(ids);
      return ids;
    }, onError: (Object error) => error);

    session.cancel();
    expect(await waiting, isA<ProspectSearchCancelled>());
    source.complete(['node_99']);
    await Future<void>.delayed(Duration.zero);

    expect(published, isEmpty);
  });

  test('a provider error arriving after cancel is consumed safely', () async {
    final source = Completer<int>();
    final session = ProspectSearchSession();
    final assertion = expectLater(
      session.waitFor(source.future, timeout: const Duration(seconds: 1)),
      throwsA(isA<ProspectSearchCancelled>()),
    );

    session.cancel();
    await assertion;
    source.completeError(StateError('late network failure'));
    await Future<void>.delayed(Duration.zero);
  });

  test('cancel is idempotent and applies to every current waiter', () async {
    final session = ProspectSearchSession();
    final first = Completer<int>();
    final second = Completer<int>();
    final assertions = [
      expectLater(
        session.waitFor(first.future, timeout: const Duration(seconds: 1)),
        throwsA(isA<ProspectSearchCancelled>()),
      ),
      expectLater(
        session.waitFor(second.future, timeout: const Duration(seconds: 1)),
        throwsA(isA<ProspectSearchCancelled>()),
      ),
    ];

    session.cancel();
    session.cancel();
    await Future.wait(assertions);

    expect(first.isCompleted, isFalse);
    expect(second.isCompleted, isFalse);
  });

  test('work cannot restart within a session that has been cancelled',
      () async {
    final session = ProspectSearchSession();
    session.cancel();

    await expectLater(
      session.waitFor(Future.value(42), timeout: const Duration(seconds: 1)),
      throwsA(isA<ProspectSearchCancelled>()),
    );
  });

  test('an unresponsive operation ends with a distinguishable timeout',
      () async {
    final source = Completer<int>();
    final session = ProspectSearchSession();

    await expectLater(
      session.waitFor(source.future, timeout: const Duration(milliseconds: 10)),
      throwsA(isA<TimeoutException>()),
    );

    expect(source.isCompleted, isFalse);
  });

  test('the original provider error remains distinguishable from cancellation',
      () async {
    final session = ProspectSearchSession();
    final failure = StateError('unavailable');

    await expectLater(
      session.waitFor(Future<int>.error(failure),
          timeout: const Duration(seconds: 1)),
      throwsA(same(failure)),
    );
  });
}
