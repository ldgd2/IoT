// lib/src/services/mdns_resolver.dart
import 'dart:async';
import 'package:multicast_dns/multicast_dns.dart';

import 'package:bthapp/src/services/mdns_bridge.dart';
class MdnsResolver {
  /// Resuelve A/AAAA para `host` (p.ej. "mi-esp.local")
  static Future<String?> resolveHost(
    String host, {
    Duration timeout = const Duration(seconds: 3),
  }) async {
    await MdnsBridge.acquire();
    final client = MDnsClient();
    try {
      await client.start();

      // IPv4 primero
      final v4 = await client
          .lookup<IPAddressResourceRecord>(ResourceRecordQuery.addressIPv4(host))
          .toList()
          .timeout(timeout);
      if (v4.isNotEmpty) return v4.first.address.address;

      // Luego IPv6
      final v6 = await client
          .lookup<IPAddressResourceRecord>(ResourceRecordQuery.addressIPv6(host))
          .toList()
          .timeout(timeout);
      if (v6.isNotEmpty) return v6.first.address.address;

      return null;
    } catch (_) {
      return null;
    } finally {
      try {
        // En algunas versiones stop() es void (no await)
        client.stop();
      } catch (_) {}
      await MdnsBridge.release();
    }
  }

  /// Navega un servicio mDNS, p.ej. service: '_http._tcp.local'
  static Future<List<MdnsHit>> browse({
    required String service,
    Duration timeout = const Duration(seconds: 4),
  }) async {
    await MdnsBridge.acquire();
    final client = MDnsClient();
    final hits = <MdnsHit>[];
    try {
      await client.start();

      // 1) PTR records para el servicio
      final ptrs = await client
          .lookup<PtrResourceRecord>(ResourceRecordQuery.serverPointer(service))
          .toList()
          .timeout(timeout);

      for (final ptr in ptrs) {
        // 2) SRV para cada nombre
        final srvs = await client
            .lookup<SrvResourceRecord>(ResourceRecordQuery.service(ptr.domainName))
            .toList()
            .timeout(timeout);

        for (final srv in srvs) {
          String? ip;

          // 3) A (IPv4) del host objetivo
          final aRecs = await client
              .lookup<IPAddressResourceRecord>(ResourceRecordQuery.addressIPv4(srv.target))
              .toList()
              .timeout(timeout);
          if (aRecs.isNotEmpty) {
            ip = aRecs.first.address.address;
          }

          hits.add(MdnsHit(
            name: ptr.domainName,
            host: srv.target,
            ip: ip,
            port: srv.port,
          ));
        }
      }

      return hits;
    } catch (_) {
      return hits;
    } finally {
      try {
        // En algunas versiones stop() es void (no await)
        client.stop();
      } catch (_) {}
      await MdnsBridge.release();
    }
  }
}

class MdnsHit {
  final String name; // e.g. "mi-esp._http._tcp.local"
  final String host; // e.g. "mi-esp.local"
  final String? ip;  // puede venir null si no hubo A/AAAA
  final int port;
  MdnsHit({
    required this.name,
    required this.host,
    required this.ip,
    required this.port,
  });
}
