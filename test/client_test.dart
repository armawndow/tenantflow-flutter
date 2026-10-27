import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tenantflow_client/gateway.dart';
import 'package:tenantflow_client/work_item.dart';

void main() {
  test('retrying the same payload reuses the idempotency key', () {
    var n = 0;
    final session = CreateSession(() => 'key-${++n}');
    expect(
      session.prepare(' task ', 'detail').key,
      session.prepare('task', 'detail').key,
    );
    expect(n, 1);
  });
  test('editing the payload creates a new request identity', () {
    var n = 0;
    final session = CreateSession(() => 'key-${++n}');
    expect(session.prepare('a', '').key, isNot(session.prepare('b', '').key));
  });
  test('a completed create clears request identity', () {
    var n = 0;
    final session = CreateSession(() => 'key-${++n}');
    final first = session.prepare('a', '').key;
    session.complete();
    expect(session.prepare('a', '').key, isNot(first));
  });
  test('empty title is rejected before network access', () {
    expect(
      () => CreateSession(() => 'key').prepare(' ', ''),
      throwsArgumentError,
    );
  });
  test(
    'create sends key and tenant fixture header without blind retries',
    () async {
      var calls = 0;
      final client = MockClient((request) async {
        calls++;
        expect(request.headers['X-Api-Key'], 'fixture');
        expect(request.headers['Idempotency-Key'], 'request-1');
        return http.Response(
          jsonEncode({
            'id': 'item',
            'title': 'Task',
            'description': '',
            'status': 0,
            'version': 1,
          }),
          201,
        );
      });
      final item = await HttpWorkGateway(
        Uri.parse('http://localhost:5086'),
        'fixture',
        client,
      ).create(const CreateCommand('Task', '', 'request-1'));
      expect(item.version, 1);
      expect(calls, 1);
      client.close();
    },
  );
  test('stale versions surface an explicit 412 conflict', () async {
    final client = MockClient((request) async {
      expect(request.headers['If-Match'], '"3"');
      return http.Response('', 412);
    });
    await expectLater(
      HttpWorkGateway(
        Uri.parse('http://localhost'),
        'fixture',
        client,
      ).changeStatus(const WorkItem('item', 'Task', '', 0, 3), 1),
      throwsA(isA<ApiException>().having((e) => e.status, 'status', 412)),
    );
    client.close();
  });
  test('demo is isolated from the server and rejects stale updates', () async {
    final gateway = DemoWorkGateway();
    final item = (await gateway.list()).first;
    await gateway.changeStatus(item, 1);
    await expectLater(
      gateway.changeStatus(item, 2),
      throwsA(isA<ApiException>()),
    );
  });
  test('unknown API status is rejected', () {
    expect(
      () => WorkItem.fromJson({
        'id': 'x',
        'title': 'x',
        'description': '',
        'status': 9,
        'version': 1,
      }),
      throwsFormatException,
    );
  });
}
