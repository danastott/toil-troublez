// Regression: the join screen spins forever when the host is not
// discoverable. Probes are broadcast to a fixed UDP port, so the host must
// answer them by unicast (the scanner's socket is on an ephemeral port and
// can never receive a broadcast). This exercises the real HostLobby and
// TableDiscovery on loopback, on isolated ports so a live app on the
// machine cannot interfere.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:toil_troublez/net/discovery.dart';
import 'package:toil_troublez/net/host_lobby.dart';

const int _testWsPort = 47931;
const int _testDiscoveryPort = 47990;

Future<void> until(bool Function() cond,
    {Duration t = const Duration(seconds: 6)}) async {
  final sw = Stopwatch()..start();
  while (!cond()) {
    if (sw.elapsed > t) fail('timed out after ${t.inSeconds}s');
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
}

void main() {
  test('scanner discovers the host and tracks live seat count', () async {
    await runZonedGuarded(() async {
      final host = HostLobby(
        hostName: 'Dana',
        port: _testWsPort,
        discoveryPort: _testDiscoveryPort,
      );
      await host.start();
      addTearDown(() async {
        await host.leave();
      });

      final scan = TableDiscovery(
        candidates: const ['127.0.0.1'],
        discoveryPort: _testDiscoveryPort,
      );
      await scan.start();
      addTearDown(() async {
        await scan.stop();
      });

      DiscoveredTable? table() =>
          scan.tables.where((t) => t.port == _testWsPort).firstOrNull;

      await until(() => table() != null);
      final t = table()!;
      expect(t.hostName, 'Dana');
      expect(t.players, 1);
      expect(t.started, isFalse);

      // The host re-answers every probe with a fresh snapshot, so a seat
      // change must show up in the join screen's list within a few cycles.
      host.addBot();
      await until(() => table()!.players == 2);
      expect(table()!.players, 2);
    }, (e, st) {
      print('TT-DBG T1 UNCAUGHT: $e'); // ignore: avoid_print
      print(st); // ignore: avoid_print
    });
  });

  test('a host that leaves the network drops off the list', () async {
    await runZonedGuarded(() async {
      final host = HostLobby(
        hostName: 'Bela',
        port: _testWsPort + 100,
        discoveryPort: _testDiscoveryPort + 100,
      );
      await host.start();
      addTearDown(() async {
        await host.leave();
      });

      final scan = TableDiscovery(
        candidates: const ['127.0.0.1'],
        discoveryPort: _testDiscoveryPort + 100,
        staleAfter: const Duration(seconds: 2),
      );
      await scan.start();
      addTearDown(() async {
        await scan.stop();
      });

      DiscoveredTable? table() =>
          scan.tables.where((t) => t.port == _testWsPort + 100).firstOrNull;

      await until(() => table() != null);
      expect(table(), isNotNull);

      // A host that leaves the network (shutdown or crash) stops answering
      // probes; its entry must expire instead of lingering in the list
      // forever.
      await host.leave();
      await until(() => table() == null, t: const Duration(seconds: 8));
      expect(table(), isNull);
    }, (e, st) {
      print('TT-DBG T2 UNCAUGHT: $e'); // ignore: avoid_print
      print(st); // ignore: avoid_print
    });
  });
}
