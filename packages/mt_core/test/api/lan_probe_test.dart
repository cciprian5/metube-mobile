import 'dart:async';
import 'dart:io';

import 'package:mt_core/mt_core.dart';
import 'package:test/test.dart';

LanAdapter _adapter(String name, List<String> addresses) =>
    (name: name, addresses: [for (final a in addresses) InternetAddress(a)]);

void main() {
  group('the subnets swept', () {
    test('the /24 of each real adapter, once; never a virtual one', () {
      final subnets = LanProbe.subnetsOf([
        _adapter('Ethernet', ['192.168.1.20']),
        _adapter('Wi-Fi', ['192.168.1.33', '10.0.0.5']),
        _adapter('vEthernet (WSL (Hyper-V firewall))', ['172.28.16.1']),
        _adapter('vEthernet (Default Switch)', ['172.17.0.1']),
        _adapter('VirtualBox Host-Only Network', ['192.168.56.1']),
        _adapter('NordVPN TAP', ['10.8.0.2']),
        _adapter('Tailscale', ['100.64.0.3']),
        _adapter('Loopback Pseudo-Interface 1', ['127.0.0.1']),
        _adapter('Ethernet 2', ['169.254.10.4']),
      ]);
      expect(subnets, ['192.168.1', '10.0.0']);
    });
  });

  group('a scan', () {
    test('finds the servers that answer as MeTube, password or not, and '
        'counts every address', () async {
      final asked = <String>[];
      final probe = LanProbe(
        adapters: () async => [
          _adapter('Ethernet', ['192.168.1.20']),
        ],
        connect: (host, port, _) async =>
            port == 8081 &&
            {'192.168.1.5', '192.168.1.9'}.contains(host.address),
        identify: (url, _) async {
          asked.add(url);
          return switch (url) {
            'http://192.168.1.5:8081' => LanHit(
              url: url,
              status: MTEndpointStatus.ok,
              version: const ServerVersion(version: '2026.10.01'),
            ),
            'http://192.168.1.9:8081' => LanHit(
              url: url,
              status: MTEndpointStatus.unauthorized,
            ),
            _ => null,
          };
        },
      );
      var total = 0;
      var done = 0;
      final hits = await probe
          .scan(
            onProgress: (d, t) {
              done = d;
              total = t;
            },
          )
          .toList();
      expect(hits.map((h) => h.url).toSet(), {
        'http://192.168.1.5:8081',
        'http://192.168.1.9:8081',
      });
      expect(asked, hasLength(2), reason: 'only open ports are asked');
      expect((done, total), (254, 254));
    });

    test('the ports given are swept, each on every address', () async {
      final ports = <int>{};
      await LanProbe(
        adapters: () async => [
          _adapter('Ethernet', ['192.168.1.20']),
        ],
        connect: (_, port, _) async {
          ports.add(port);
          return false;
        },
      ).scan(ports: [8081, 8086]).drain<void>();
      expect(ports, {8081, 8086});
    });

    test('never more than [parallel] addresses at once', () async {
      var now = 0;
      var most = 0;
      await LanProbe(
        parallel: 32,
        adapters: () async => [
          _adapter('Ethernet', ['192.168.1.20']),
          _adapter('Wi-Fi', ['10.0.0.5']),
        ],
        connect: (_, _, _) async {
          most = now + 1 > most ? now + 1 : most;
          now++;
          await Future<void>.delayed(const Duration(milliseconds: 1));
          now--;
          return false;
        },
      ).scan().drain<void>();
      expect(most, 32);
    });

    test('stops early when cancelled', () async {
      var swept = 0;
      var stop = false;
      await LanProbe(
        parallel: 4,
        adapters: () async => [
          _adapter('Ethernet', ['192.168.1.20']),
        ],
        connect: (_, _, _) async {
          if (++swept == 10) stop = true;
          await Future<void>.delayed(Duration.zero);
          return false;
        },
      ).scan(cancelled: () => stop).drain<void>();
      expect(swept, lessThan(20));
    });

    test(
      'an address that throws is no server, and the sweep goes on',
      () async {
        final hits = await LanProbe(
          adapters: () async => [
            _adapter('Ethernet', ['192.168.1.20']),
          ],
          connect: (host, _, _) async {
            if (host.address == '192.168.1.1') throw const SocketException('x');
            return host.address == '192.168.1.2';
          },
          identify: (url, _) async =>
              LanHit(url: url, status: MTEndpointStatus.ok),
        ).scan().toList();
        expect(hits.single.url, 'http://192.168.1.2:8081');
      },
    );
  });
}
