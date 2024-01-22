import 'dart:async';

import 'package:statsd/statsd.dart';
import 'package:test/test.dart';
import 'stopwatch_mock.dart';

const _dogTagStr = '|#k1:v1,k2:v2';
const _dogTags = {"k1": "v1", "k2": "v2"};

void main() {
  group('StatsdClient:', () {
    late StatsdClient client;
    late StatsdStubConnection connection;
    setUp(() {
      connection = StatsdStubConnection();
      client = StatsdClient(connection, dogTags: _dogTags);
    });

    test('it sends counter metrics', () {
      client.count('test');
      client.count('test', 2);
      client.count('test', -2);
      client.count('test', 2, 0.1);
      var expected = [
        'test:1|c$_dogTagStr',
        'test:2|c$_dogTagStr',
        'test:-2|c$_dogTagStr',
        'test:2|c|@0.1$_dogTagStr',
      ];

      expect(connection.packets, equals(expected));
    });

    test('it sends timing metrics', () {
      var stopwatch = StopwatchMock(527);
      client.time('latency', stopwatch);
      client.time('latency', stopwatch, 0.1);
      var expected = ['latency:527|ms$_dogTagStr', 'latency:527|ms|@0.1$_dogTagStr'];

      expect(connection.packets, equals(expected));
    });

    test('it sends timing metrics via timeDuration api', () {
      final duration = Duration(milliseconds: 527);
      client.timeDuration('latencyD', duration);
      client.timeDuration('latencyD', duration, 0.1);
      var expected = ['latencyD:527|ms$_dogTagStr', 'latencyD:527|ms|@0.1$_dogTagStr'];

      expect(connection.packets, equals(expected));
    });

    test('it sends gauge metrics', () {
      client.gauge('gauge', 333);
      client.gaugeDelta('gauge', 10);
      client.gaugeDelta('gauge', -4);
      client.gaugeDelta('gauge', 0);
      var expected = ['gauge:333|g$_dogTagStr', 'gauge:+10|g$_dogTagStr', 'gauge:-4|g$_dogTagStr', 'gauge:+0|g$_dogTagStr'];

      expect(connection.packets, equals(expected));
    });

    test('it sends set metrics', () {
      client.set('uniques', 345);
      var expected = ['uniques:345|s$_dogTagStr'];

      expect(connection.packets, equals(expected));
    });

    test('it prepends the prefix if provided', () {
      client = StatsdClient(connection, prefix: 'global.', dogTags: _dogTags);
      client.count('test');
      client.gauge('gauge', 333);
      client.set('uniques', 345);
      var stopwatch = StopwatchMock(527);
      client.time('latency', stopwatch);

      var expected = ['global.test:1|c$_dogTagStr', 'global.gauge:333|g$_dogTagStr', 'global.uniques:345|s$_dogTagStr', 'global.latency:527|ms$_dogTagStr'];
      expect(connection.packets, equals(expected));
    });

    test('it sends batches of packets', () {
      var stopwatch = StopwatchMock(527);
      client = StatsdClient(connection, prefix: 'global.', dogTags: _dogTags);
      var batch = client.batch();
      batch
        ..count('test')
        ..gauge('gauge', 333)
        ..gaugeDelta('gauge', 10)
        ..set('uniques', 345)
        ..time('latency', stopwatch);
      batch.send();

      var expected = [
        'global.test:1|c$_dogTagStr',
        'global.gauge:333|g$_dogTagStr',
        'global.gauge:+10|g$_dogTagStr',
        'global.uniques:345|s$_dogTagStr',
        'global.latency:527|ms$_dogTagStr'
      ].join('\n');
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
