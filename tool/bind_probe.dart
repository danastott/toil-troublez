import 'dart:io';

Future<void> main() async {
  final ports = <int>[47920, 47921, 47922, 47923, 47924];
  for (final p in ports) {
    try {
      final s = await HttpServer.bind(InternetAddress.anyIPv4, p);
      print('bind anyIPv4:$p ok -> ${s.port}');
      await s.close(force: true);
    } catch (e) {
      print('bind anyIPv4:$p FAILED: ${e.runtimeType}: $e');
    }
  }
  // IPv6 side too: some macOS setups only have IPv6 interfaces.
  try {
    final s = await HttpServer.bind(InternetAddress.anyIPv6, 47921);
    print('bind anyIPv6:47921 ok -> ${s.port}');
    await s.close(force: true);
  } catch (e) {
    print('bind anyIPv6:47921 FAILED: ${e.runtimeType}');
  }
  try {
    final raw = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 47925);
    print('udp anyIPv4:47925 ok -> ${raw.port}');
    raw.close();
  } catch (e) {
    print('udp anyIPv4:47925 FAILED: ${e.runtimeType}');
  }
  exit(0);
}
