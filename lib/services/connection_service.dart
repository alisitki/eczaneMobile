import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

enum ConnectionType { wifi, hotspot, none }

class ConnectionStatus {
  final bool isConnected;
  final ConnectionType type;
  final String? clientIP;

  ConnectionStatus({
    required this.isConnected,
    required this.type,
    this.clientIP,
  });

  factory ConnectionStatus.connected({
    required ConnectionType type,
    required String clientIP,
  }) {
    return ConnectionStatus(isConnected: true, type: type, clientIP: clientIP);
  }

  factory ConnectionStatus.disconnected() {
    return ConnectionStatus(
      isConnected: false,
      type: ConnectionType.none,
      clientIP: null,
    );
  }

  factory ConnectionStatus.fromJson(
    Map<String, dynamic> json,
    ConnectionType fallbackType,
  ) {
    try {
      final clientIpValue =
          json['clientIp'] ?? json['clientIP'] ?? json['client_ip'];
      ConnectionType actualType;

      final connectionType = json['connectionType']?.toString().toLowerCase();
      if (connectionType == 'wifi') {
        actualType = ConnectionType.wifi;
      } else if (connectionType == 'hotspot') {
        actualType = ConnectionType.hotspot;
      } else {
        actualType = fallbackType;
      }

      return ConnectionStatus.connected(
        type: actualType,
        clientIP: clientIpValue?.toString() ?? 'Unknown',
      );
    } catch (e) {
      debugPrint('Error parsing connection status: $e');
      return ConnectionStatus.disconnected();
    }
  }

  String get displayText {
    if (!isConnected) {
      return 'Nöbetix Pano Bağlantı Kurulamadı';
    }

    switch (type) {
      case ConnectionType.wifi:
        return 'Nöbetix Pano WiFi ile Bağlandı';
      case ConnectionType.hotspot:
        return 'Nöbetix Pano Hotspot ile Bağlandı';
      case ConnectionType.none:
        return 'Nöbetix Pano Bağlantı Kurulamadı';
    }
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ConnectionStatus &&
        other.isConnected == isConnected &&
        other.type == type;
  }

  @override
  int get hashCode => isConnected.hashCode ^ type.hashCode;
}

class ConnectionService {
  static final ConnectionService _instance = ConnectionService._internal();
  factory ConnectionService() => _instance;
  ConnectionService._internal();

  final StreamController<ConnectionStatus> _statusController =
      StreamController<ConnectionStatus>.broadcast();

  Stream<ConnectionStatus> get statusStream => _statusController.stream;

  ConnectionStatus _currentStatus = ConnectionStatus.disconnected();
  ConnectionStatus get currentStatus => _currentStatus;

  // Cache'lenmiş IP'yi döndüren getter
  String? get cachedHostnameIP => _cachedHostnameIP;

  // Belirli bir hostname için cache'lenmiş IP'yi döndür
  String? getCachedHostnameIP(String hostname) {
    if (hostname.contains('raspberrypi.local')) {
      return _cachedHostnameIP;
    }
    return null;
  }

  final String _wifiEndpoint = 'http://raspberrypi.local:3000/api/mobile/check';
  final String _hotspotEndpoint = 'http://192.168.4.1:3000/api/mobile/check';

  Timer? _periodicTimer;

  // DNS cache için
  String? _cachedHostnameIP;
  DateTime? _cacheTime;
  static const Duration _cacheTimeout = Duration(minutes: 5);

  void _updateStatus(ConnectionStatus status) {
    _currentStatus = status;
    if (!_statusController.isClosed) {
      _statusController.add(status);
    }
  }

  Future<ConnectionStatus> checkConnection() async {
    try {
      // Önce WiFi (hostname/mDNS) dene
      final wifiResult = await _checkWifiWithDNSResolve();
      if (wifiResult.isConnected) {
        _updateStatus(wifiResult);
        return wifiResult;
      }

      // Sonra hotspot sabit IP dene
      final hotspotResult = await _checkEndpoint(
        _hotspotEndpoint,
        ConnectionType.hotspot,
      );
      if (hotspotResult.isConnected) {
        _updateStatus(hotspotResult);
        return hotspotResult;
      }

      final disconnected = ConnectionStatus.disconnected();
      _updateStatus(disconnected);
      return disconnected;
    } catch (e) {
      debugPrint('checkConnection fatal error: $e');
      final disconnected = ConnectionStatus.disconnected();
      _updateStatus(disconnected);
      return disconnected;
    }
  }

  Future<ConnectionStatus> _checkWifiWithDNSResolve() async {
    // Önce hostname'i resolve etmeye çalış
    final resolvedIP = await _resolveHostname('raspberrypi.local');

    if (resolvedIP != null) {
      // IP ile URL oluştur (IPv6 link-local formatını düzelt)
      final ipUrl = _buildServiceUrl(resolvedIP, 3000, '/api/mobile/check');
      debugPrint('Using resolved IP URL: $ipUrl');
      return await _checkEndpoint(ipUrl, ConnectionType.wifi);
    } else {
      // Hostname resolve başarısızsa direkt dene
      debugPrint('DNS resolve failed, trying hostname directly...');
      return await _checkEndpoint(_wifiEndpoint, ConnectionType.wifi);
    }
  }

  String _buildServiceUrl(String host, int port, String path) {
    // IPv6 adres tespiti (birden fazla ':' içeriyorsa)
    final isIPv6 = host.contains(':');
    if (isIPv6) {
      // Zone id varsa ayır (ör: fe80::abc%en1)
      String zone = '';
      final zoneIndex = host.indexOf('%');
      if (zoneIndex != -1) {
        zone = host.substring(zoneIndex + 1);
        host = host.substring(0, zoneIndex);
      }
      if (zone.isNotEmpty) {
        // '%' encode et
        zone = zone.replaceAll('%', '%25');
        host = '$host%25$zone';
      }
      // Köşeli parantez ekle (yoksa)
      if (!host.startsWith('[')) {
        host = '[$host]';
      }
    }
    return 'http://$host:$port$path';
  }

  // Dış servisler için sadece host verildiğinde base URL döner (port 3000 varsayım)
  String buildBaseUrlFromHost(String host, {int port = 3000}) {
    final isIPv6 = host.contains(':');
    if (isIPv6) {
      String zone = '';
      final zoneIndex = host.indexOf('%');
      if (zoneIndex != -1) {
        zone = host.substring(zoneIndex + 1);
        host = host.substring(0, zoneIndex);
      }
      if (zone.isNotEmpty) {
        zone = zone.replaceAll('%', '%25');
        host = '$host%25$zone';
      }
      if (!host.startsWith('[')) host = '[$host]';
    }
    return 'http://$host:$port';
  }

  Future<String?> _resolveHostname(String hostname) async {
    try {
      // Cache kontrolü yap
      if (_cachedHostnameIP != null && _cacheTime != null) {
        final cacheAge = DateTime.now().difference(_cacheTime!);
        if (cacheAge < _cacheTimeout) {
          debugPrint('Using cached IP: $hostname -> $_cachedHostnameIP');
          return _cachedHostnameIP;
        }
      }

      debugPrint('Resolving hostname: $hostname');

      // Android için özel mDNS lookup stratejisi
      String? resolvedIP = await _androidMDNSLookup(hostname);

      if (resolvedIP != null) {
        debugPrint('Android mDNS resolved: $hostname -> $resolvedIP');
        _cachedHostnameIP = resolvedIP;
        _cacheTime = DateTime.now();
        return resolvedIP;
      }

      // Standard DNS lookup (fallback)
      for (int attempt = 1; attempt <= 2; attempt++) {
        try {
          final addresses = await InternetAddress.lookup(
            hostname,
          ).timeout(const Duration(seconds: 2));

          if (addresses.isNotEmpty) {
            resolvedIP = addresses.first.address;
            debugPrint(
              'Standard DNS resolved on attempt $attempt: $hostname -> $resolvedIP',
            );

            _cachedHostnameIP = resolvedIP;
            _cacheTime = DateTime.now();
            return resolvedIP;
          }
        } catch (e) {
          debugPrint('DNS resolution attempt $attempt failed: $e');
          if (attempt < 2) {
            await Future.delayed(const Duration(milliseconds: 300));
          }
        }
      }

      debugPrint('All hostname resolution methods failed for: $hostname');
      // Ek olarak tether/hotspot senaryosu için lokal subnet taraması dene
      final subnetCandidate = await _tryLocalSubnetScan();
      if (subnetCandidate != null) {
        debugPrint(
          'Local subnet scan discovered $hostname -> $subnetCandidate',
        );
        _cachedHostnameIP = subnetCandidate;
        _cacheTime = DateTime.now();
        return subnetCandidate;
      }
      return null;
    } catch (e) {
      debugPrint('Hostname resolution failed for $hostname: $e');
      return null;
    }
  }

  Future<String?> _tryLocalSubnetScan() async {
    try {
      // Mevcut interface IP'lerinden /24 subnet çıkar
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );
      String? subnet;
      String? selfHost;
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          final a = addr.address;
          if (a.startsWith('192.168.') || a.startsWith('10.')) {
            final parts = a.split('.');
            if (parts.length == 4) {
              subnet = '${parts[0]}.${parts[1]}.${parts[2]}';
              selfHost = parts[3];
              break;
            }
          }
        }
        if (subnet != null) break;
      }
      if (subnet == null) return null;

      debugPrint('Subnet scan starting on $subnet.0/24 (heuristic limited)');
      final candidates = <String>[];
      // Öncelikli olası IP'ler: .1 (gateway), .2, .3, .10, .20, .30, kendi IP çevresi
      final priority = <int>{1, 2, 3, 10, 20, 30};
      if (selfHost != null) {
        final s = int.tryParse(selfHost);
        if (s != null) {
          for (final delta in [-2, -1, 1, 2, 3, 4, 5]) {
            final cand = s + delta;
            if (cand > 1 && cand < 255) priority.add(cand);
          }
        }
      }
      // İlk seti ekle
      for (final h in priority) {
        candidates.add('$subnet.$h');
      }
      // Genişleme: 4..50 arası (zaten öncelikler eklenmişse atlanır)
      for (int host = 4; host <= 50; host++) {
        final ip = '$subnet.$host';
        if (!candidates.contains(ip)) candidates.add(ip);
      }

      // Paralel limit
      const parallel = 6;
      final deadline = DateTime.now().add(const Duration(seconds: 4));
      for (int i = 0; i < candidates.length; i += parallel) {
        if (DateTime.now().isAfter(deadline)) {
          debugPrint('Subnet scan timeout (global)');
          return null;
        }
        final slice = candidates.skip(i).take(parallel).toList();
        final futures = slice.map((ip) async {
          final url = 'http://$ip:3000/api/mobile/check';
          try {
            final resp = await http
                .get(Uri.parse(url))
                .timeout(const Duration(milliseconds: 700));
            if (resp.statusCode == 200 &&
                resp.body.contains('connectionType')) {
              debugPrint('Subnet scan hit: $ip');
              return ip;
            }
          } catch (_) {}
          return null;
        });
        final results = await Future.wait(futures);
        final found = results.firstWhere((e) => e != null, orElse: () => null);
        if (found != null) return found;
      }
      return null;
    } catch (e) {
      debugPrint('Local subnet scan failed: $e');
      return null;
    }
  }

  Future<String?> _androidMDNSLookup(String hostname) async {
    try {
      final multicastAddr = InternetAddress('224.0.0.251');
      RawDatagramSocket? socket;
      try {
        socket = await RawDatagramSocket.bind(
          InternetAddress.anyIPv4,
          5353,
          reuseAddress: true,
          // reusePort kaldırıldı (desteklemeyen platformlar hata veriyordu)
        );
      } catch (bindErr) {
        debugPrint('mDNS bind 5353 failed ($bindErr), giving up on mDNS');
        return null; // 5353 olmadan güvenilir mDNS alamayız
      }

      try {
        socket.joinMulticast(multicastAddr);
      } catch (e) {
        debugPrint('Multicast join failed: $e');
      }
      socket.multicastHops = 255;
      socket.broadcastEnabled = true;

      final query = _buildMDNSQuery(hostname);
      socket.send(query, multicastAddr, 5353);

      final completer = Completer<String?>();
      late StreamSubscription sub;
      final timer = Timer(const Duration(milliseconds: 1300), () {
        if (!completer.isCompleted) completer.complete(null);
      });
      sub = socket.listen(
        (event) {
          if (event == RawSocketEvent.read && !completer.isCompleted) {
            final dg = socket!.receive();
            if (dg != null) {
              final ip = _parseMDNSResponse(dg.data, hostname);
              if (ip != null) {
                completer.complete(ip);
              }
            }
          }
        },
        onError: (_) {
          if (!completer.isCompleted) completer.complete(null);
        },
        onDone: () {
          if (!completer.isCompleted) completer.complete(null);
        },
      );

      final result = await completer.future;
      await sub.cancel();
      timer.cancel();
      socket.close();
      return result;
    } catch (e) {
      debugPrint('Android mDNS lookup (revised) failed: $e');
      return null;
    }
  }

  List<int> _buildMDNSQuery(String hostname) {
    // Basit mDNS A record query
    final query = <int>[];

    // Header
    query.addAll([0x00, 0x00]); // Transaction ID
    query.addAll([0x01, 0x00]); // Flags: Standard query
    query.addAll([0x00, 0x01]); // Questions: 1
    query.addAll([0x00, 0x00]); // Answer RRs: 0
    query.addAll([0x00, 0x00]); // Authority RRs: 0
    query.addAll([0x00, 0x00]); // Additional RRs: 0

    // Question
    final parts = hostname.split('.');
    for (final part in parts) {
      query.add(part.length);
      query.addAll(part.codeUnits);
    }
    query.add(0x00); // End of name

    query.addAll([0x00, 0x01]); // Type: A
    query.addAll([0x00, 0x01]); // Class: IN

    return query;
  }

  String? _parseMDNSResponse(List<int> data, String hostname) {
    try {
      // Basit mDNS response parser
      if (data.length < 12) return null;

      // Answer sayısını kontrol et
      final answerCount = (data[6] << 8) | data[7];
      if (answerCount == 0) return null;

      // Hostname'i bul ve IP'yi çıkar
      int offset = 12;

      // Question section'u geç
      while (offset < data.length && data[offset] != 0) {
        offset += data[offset] + 1;
      }
      offset += 5; // NULL terminator + type + class

      // Answer section'u parse et
      for (int i = 0; i < answerCount && offset + 10 < data.length; i++) {
        // Name field'i geç
        if ((data[offset] & 0xC0) == 0xC0) {
          offset += 2; // Compressed name
        } else {
          while (offset < data.length && data[offset] != 0) {
            offset += data[offset] + 1;
          }
          offset++; // NULL terminator
        }

        // Type ve Class
        final type = (data[offset] << 8) | data[offset + 1];
        offset += 8; // type + class + ttl

        final dataLength = (data[offset] << 8) | data[offset + 1];
        offset += 2;

        // A record ise IP'yi al
        if (type == 1 && dataLength == 4) {
          final ip =
              '${data[offset]}.${data[offset + 1]}.${data[offset + 2]}.${data[offset + 3]}';
          return ip;
        }

        offset += dataLength;
      }

      return null;
    } catch (e) {
      debugPrint('mDNS response parsing failed: $e');
      return null;
    }
  }

  Future<ConnectionStatus> _checkEndpoint(
    String url,
    ConnectionType type,
  ) async {
    try {
      debugPrint('Checking endpoint: $url');
      final response = await http
          .get(Uri.parse(url), headers: {'Content-Type': 'application/json'})
          .timeout(const Duration(seconds: 5));

      debugPrint('Response status: ${response.statusCode}');
      debugPrint('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        final status = ConnectionStatus.fromJson(jsonData, type);
        debugPrint('Endpoint check successful for $url');
        return status;
      } else {
        debugPrint(
          'Endpoint check failed for $url - Status: ${response.statusCode}',
        );
        return ConnectionStatus.disconnected();
      }
    } catch (e) {
      debugPrint('Endpoint check error for $url: $e');
      return ConnectionStatus.disconnected();
    }
  }

  void dispose() {
    stopPeriodicCheck();
    _statusController.close();
  }

  void startPeriodicCheck() {
    stopPeriodicCheck(); // Önceki timer'ı durdur
    _periodicTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      checkConnection();
    });
    debugPrint('Periodic connection check started (30 seconds interval)');
  }

  void stopPeriodicCheck() {
    _periodicTimer?.cancel();
    _periodicTimer = null;
    debugPrint('Periodic connection check stopped');
  }
}
