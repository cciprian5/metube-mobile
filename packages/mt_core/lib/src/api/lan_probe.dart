import 'dart:async';
import 'dart:io';

import '../models/server_version.dart';
import 'api_exceptions.dart';
import 'endpoint_resolver.dart';
import 'metube_api_client.dart';

/// A network adapter as the scan sees it: its name and IPv4 addresses.
typedef LanAdapter = ({String name, List<InternetAddress> addresses});

/// A MeTube server found on the local network.
class LanHit {
  const LanHit({required this.url, required this.status, this.version});

  /// `http://<address>:<port>`.
  final String url;

  /// [MTEndpointStatus.ok], or [MTEndpointStatus.unauthorized] for a server
  /// that wants a password (found all the same).
  final MTEndpointStatus status;
  final ServerVersion? version;
}

/// "Search my network": every address of the /24 of each **real** adapter,
/// on each of [scan]'s ports, asked whether it is MeTube. Only when the user clicks:
/// sweeping a network unasked is what a stranger's device would do.
///
/// Two steps per address, both short: a bare TCP connect (most addresses
/// answer nothing, and a refused port answers at once), then, only where
/// the port is open, the client's own [MeTubeApiClient.testConnection], so
/// "it is MeTube" means what it means everywhere else in the app. At most
/// [parallel] at a time.
class LanProbe {
  LanProbe({
    Future<List<LanAdapter>> Function()? adapters,
    Future<bool> Function(InternetAddress host, int port, Duration timeout)?
    connect,
    Future<LanHit?> Function(String url, Duration timeout)? identify,
    this.parallel = 32,
    this.timeout = const Duration(milliseconds: 600),
  }) : _adapters = adapters ?? _systemAdapters,
       _connect = connect ?? _tcpConnect,
       _identify = identify ?? _identifyMeTube;

  final Future<List<LanAdapter>> Function() _adapters;
  final Future<bool> Function(InternetAddress, int, Duration) _connect;
  final Future<LanHit?> Function(String, Duration) _identify;
  final int parallel;
  final Duration timeout;

  /// The names of adapters that are not a real network: WSL's and
  /// Hyper-V's switches, virtual machines, VPN tunnels. Their /24 is a
  /// private island, and sweeping it finds nothing but costs a minute.
  static final _virtual = RegExp(
    r'vEthernet|WSL|Hyper-V|VirtualBox|VMware|VMnet|VPN|TAP|TUN|Tailscale|'
    r'ZeroTier|WireGuard|Loopback|Docker|Npcap',
    caseSensitive: false,
  );

  /// The /24 prefixes ("192.168.1") of the real adapters, each once.
  static List<String> subnetsOf(List<LanAdapter> adapters) => {
    for (final adapter in adapters)
      if (!_virtual.hasMatch(adapter.name))
        for (final address in adapter.addresses)
          if (address.type == InternetAddressType.IPv4 &&
              !address.isLoopback &&
              !address.isLinkLocal)
            address.address.substring(0, address.address.lastIndexOf('.')),
  }.toList();

  /// The servers found, as they are found; stops early when [cancelled]
  /// turns true. Each finished address is counted through [onProgress]
  /// (done, of total).
  Stream<LanHit> scan({
    List<int> ports = const [8081],
    bool Function()? cancelled,
    void Function(int done, int total)? onProgress,
  }) async* {
    final subnets = subnetsOf(await _adapters());
    final hosts = [
      for (final port in ports)
        for (final subnet in subnets)
          for (var last = 1; last < 255; last++)
            (host: '$subnet.$last', port: port),
    ];
    final hits = StreamController<LanHit>();
    var next = 0;
    var done = 0;

    Future<void> worker() async {
      while (next < hosts.length && !(cancelled?.call() ?? false)) {
        final (:host, :port) = hosts[next++];
        try {
          if (await _connect(InternetAddress(host), port, timeout)) {
            final hit = await _identify('http://$host:$port', timeout * 4);
            if (hit != null && !hits.isClosed) hits.add(hit);
          }
        } on Object {
          // An address that misbehaves is no server; the sweep goes on.
        }
        onProgress?.call(++done, hosts.length);
      }
    }

    unawaited(
      Future.wait([for (var i = 0; i < parallel; i++) worker()])
          .whenComplete(hits.close),
    );
    yield* hits.stream;
  }

  static Future<List<LanAdapter>> _systemAdapters() async => [
    for (final adapter in await NetworkInterface.list(
      type: InternetAddressType.IPv4,
    ))
      (name: adapter.name, addresses: adapter.addresses),
  ];

  static Future<bool> _tcpConnect(
    InternetAddress host,
    int port,
    Duration timeout,
  ) async {
    try {
      final socket = await Socket.connect(host, port, timeout: timeout);
      socket.destroy();
      return true;
    } on Object {
      return false;
    }
  }

  static Future<LanHit?> _identifyMeTube(String url, Duration timeout) async {
    final client = MeTubeApiClient(config: ServerConfig(baseUrl: url));
    try {
      await client.testConnection(timeout: timeout).timeout(timeout);
      return LanHit(
        url: url,
        status: MTEndpointStatus.ok,
        version: await client.fetchVersion(timeout: timeout),
      );
    } on AuthFailureException {
      return LanHit(url: url, status: MTEndpointStatus.unauthorized);
    } on Object {
      return null;
    } finally {
      client.close();
    }
  }
}
