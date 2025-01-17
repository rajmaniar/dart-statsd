import 'dart:async';

import 'package:statsd/statsd.dart';
import 'package:test/test.dart';
import 'stopwatch_mock.dart';

void main() {
  group('StatsdClient:', () {
    late StatsdClient client;
    late StatsdStubConnection connection;
    setUp(() {
      connection = StatsdStubConnection();
      client = StatsdClient(connection);
    });

    test('it sends counter metrics', () {
      client.count('test');
      client.count('test', 2);
      client.count('test', -2);
      client.count('test', 2, 0.1);
      var expected = [
        'test:1|c',
        'test:2|c',
        'test:-2|c',
        'test:2|c|@0.1',
      ];

      expect(connection.packets, equals(expected));
    });

    test('it sends timing metrics', () {
      var stopwatch = StopwatchMock(527);
      client.time('latency', stopwatch);
      client.time('latency', stopwatch, 0.1);
      var expected = ['latency:527|ms', 'latency:527|ms|@0.1'];

      expect(connection.packets, equals(expected));
    });

    test('it sends timing metrics via timeDuration api', () {
      final duration = Duration(milliseconds: 527);
      client.timeDuration('latencyD', duration);
      client.timeDuration('latencyD', duration, 0.1);
      var expected = ['latencyD:527|ms', 'latencyD:527|ms|@0.1'];

      expect(connection.packets, equals(expected));
    });

    test('it sends gauge metrics', () {
      client.gauge('gauge', 333);
      client.gaugeDelta('gauge', 10);
      client.gaugeDelta('gauge', -4);
      client.gaugeDelta('gauge', 0);
      var expected = ['gauge:333|g', 'gauge:+10|g', 'gauge:-4|g', 'gauge:+0|g'];

      expect(connection.packets, equals(expected));
    });

    test('it sends set metrics', () {
      client.set('uniques', 345);
      var expected = ['uniques:345|s'];

      expect(connection.packets, equals(expected));
    });

    test('it prepends the prefix if provided', () {
      client = StatsdClient(connection, prefix: 'global.');
      client.count('test');
      client.gauge('gauge', 333);
      client.set('uniques', 345);
      var stopwatch = StopwatchMock(527);
      client.time('latency', stopwatch);

      var expected = ['global.test:1|c', 'global.gauge:333|g', 'global.uniques:345|s', 'global.latency:527|ms'];
      expect(connection.packets, equals(expected));
    });

    test('it sends batches of packets', () {
      var stopwatch = StopwatchMock(527);
      client = StatsdClient(connection, prefix: 'global.');
      var batch = client.batch();
      batch
        ..count('test')
        ..gauge('gauge', 333)
        ..gaugeDelta('gauge', 10)
        ..set('uniques', 345)
        ..time('latency', stopwatch);
      batch.send();

      var expected = ['global.test:1|c', 'global.gauge:333|g', 'global.gauge:+10|g', 'global.uniques:345|s', 'global.latency:527|ms'].join('\n');
      expect(connection.packets, equals([expected]));
    });
  });
}

class StatsdStubConnection implements StatsdConnection {
  final packets = <String>[];

  @override
  Future close() => Future.value();

  @override
  Future send(String packet) {
    packets.add(packet);
    return Future.value();
  }
}
