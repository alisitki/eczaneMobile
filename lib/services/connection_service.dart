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
      // WiFi'yi önce kontrol et (hostname resolve ile)
      final wifiResult = await _checkWifiWithDNSResolve();

      if (wifiResult.isConnected) {
        debugPrint('Selected: WiFi connection (skipping hotspot check)');
        _updateStatus(wifiResult);
        return wifiResult;
      }

      // WiFi başarısızsa hotspot'u kontrol et
      debugPrint('WiFi failed, checking hotspot...');
      final hotspotResult = await _checkEndpoint(
        _hotspotEndpoint,
        ConnectionType.hotspot,
      );

      if (hotspotResult.isConnected) {
        debugPrint('Selected: Hotspot connection');
        _updateStatus(hotspotResult);
        return hotspotResult;
      }

      // Hiçbir bağlantı yoksa
      final disconnectedStatus = ConnectionStatus.disconnected();
      _updateStatus(disconnectedStatus);
      return disconnectedStatus;
    } catch (e) {
      debugPrint('Connection check error: $e');
      final disconnectedStatus = ConnectionStatus.disconnected();
      _updateStatus(disconnectedStatus);
      return disconnectedStatus;
    }
  }

  Future<ConnectionStatus> _checkWifiWithDNSResolve() async {
    // Önce hostname'i resolve etmeye çalış
    final resolvedIP = await _resolveHostname('raspberrypi.local');

    if (resolvedIP != null) {
      // IP ile URL oluştur
      final ipUrl = 'http://$resolvedIP:3000/api/mobile/check';
      debugPrint('Using resolved IP URL: $ipUrl');
      return await _checkEndpoint(ipUrl, ConnectionType.wifi);
    } else {
      // Hostname resolve başarısızsa direkt dene
      debugPrint('DNS resolve failed, trying hostname directly...');
      return await _checkEndpoint(_wifiEndpoint, ConnectionType.wifi);
    }
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
      return null;
    } catch (e) {
      debugPrint('Hostname resolution failed for $hostname: $e');
      return null;
    }
  }

  Future<String?> _androidMDNSLookup(String hostname) async {
    try {
      // Android'de raw socket ile mDNS query
      final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);

      // mDNS query oluştur
      final query = _buildMDNSQuery(hostname);

      // Multicast adresine gönder (224.0.0.251:5353)
      final mcastAddr = InternetAddress('224.0.0.251');
      socket.send(query, mcastAddr, 5353);

      // Yanıt bekle
      final completer = Completer<String?>();
      late StreamSubscription subscription;

      Timer(const Duration(seconds: 2), () {
        if (!completer.isCompleted) {
          subscription.cancel();
          socket.close();
          completer.complete(null);
        }
      });

      subscription = socket.listen((event) {
        if (event == RawSocketEvent.read && !completer.isCompleted) {
          final packet = socket.receive();
          if (packet != null) {
            final ip = _parseMDNSResponse(packet.data, hostname);
            if (ip != null) {
              subscription.cancel();
              socket.close();
              completer.complete(ip);
            }
          }
        }
      });

      return await completer.future;
    } catch (e) {
      debugPrint('Android mDNS lookup failed: $e');
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
