import 'dart:io';
import '../lib/net/host_lobby.dart';
import '../lib/net/discovery.dart';

Future<void> main() async {
  // First: reproduce the user's failure mode with a plain bind.
  var rawOk = true;
  try {
    final s = await HttpServer.bind(InternetAddress.anyIPv4, Net.wsPort);
    print('raw bind 47921 ok -> ${s.port}');
    await s.close(force: true);
  } catch (e) {
    rawOk = false;
    print('raw bind 47921 FAILED: $e');
  }

  final lobby = HostLobby(hostName: 'TestHost');
  await lobby.start();
  if (lobby.errorMessage != null) {
    print('HostLobby error: ${lobby.errorMessage}');
    exit(1);
  }
  print('HostLobby started on port ${lobby.port}');
  await lobby.leave();
  if (!rawOk) exit(2);
  exit(0);
}