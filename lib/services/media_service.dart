import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

import 'package:http/http.dart' as http;

import '../services/connection_service.dart';

/// Media item type used by service layer
enum MediaKind { image, video }

/// Media item DTO to match backend
class MediaItemDto {
  final String id;
  final String name;
  final MediaKind type;
  final bool active;
  final String? thumbUrl;
  final String? url;
  final int duration; // milliseconds

  MediaItemDto({
    required this.id,
    required this.name,
    required this.type,
    required this.active,
    this.thumbUrl,
    this.url,
    required this.duration,
  });

  factory MediaItemDto.fromJson(Map<String, dynamic> json) {
    final typeStr = (json['type'] ?? '').toString().toLowerCase();
    final mediaType = typeStr == 'video' ? MediaKind.video : MediaKind.image;
    return MediaItemDto(
      id: json['id'].toString(),
      name: json['name']?.toString() ?? '',
      type: mediaType,
      active: json['active'] == true || json['isActive'] == true,
      thumbUrl: json['thumbUrl']?.toString() ?? json['thumbnail']?.toString(),
      url: json['url']?.toString(),
      duration: _parseDuration(json),
    );
  }

  static int _parseDuration(Map<String, dynamic> json) {
    final raw = json['duration'] ?? json['displayMs'] ?? 10000;
    if (raw is int) return raw;
    if (raw is double) return raw.toInt();
    final parsed = int.tryParse(raw.toString());
    return parsed != null && parsed > 0 ? parsed : 10000;
  }
}

class MediaService {
  final ConnectionService _connectionService = ConnectionService();

  Future<String> _getApiBaseUrl() async {
    try {
      await _connectionService.checkConnection();
    } catch (_) {}

    final status = _connectionService.currentStatus;
    if (kDebugMode) {
      // ignore: avoid_print
      print('[MediaService] connection status: ${status.type}');
    }
    switch (status.type) {
      case ConnectionType.wifi:
        final cached = _connectionService.getCachedHostnameIP(
          'raspberrypi.local',
        );
        if (cached != null && cached.isNotEmpty) {
          if (kDebugMode) {
            // ignore: avoid_print
            print('[MediaService] using cached hostname ip: $cached');
          }
          return 'http://$cached:3000';
        }
        if (kDebugMode) {
          // ignore: avoid_print
          print('[MediaService] using raspberrypi.local directly');
        }
        return 'http://raspberrypi.local:3000';
      case ConnectionType.hotspot:
      case ConnectionType.none:
        if (kDebugMode) {
          // ignore: avoid_print
          print('[MediaService] falling back to hotspot ip 192.168.4.1');
        }
        return 'http://192.168.4.1:3000';
    }
  }

  Map<String, String> get _jsonHeaders => const {
    'Content-Type': 'application/json',
  };

  /// GET /api/mobile/media
  Future<List<MediaItemDto>> getMediaList() async {
    final base = await _getApiBaseUrl();
    final uri = Uri.parse('$base/api/mobile/media');
    if (kDebugMode) {
      // ignore: avoid_print
      print('[MediaService] => GET $uri');
    }
    final res = await http
        .get(uri, headers: _jsonHeaders)
        .timeout(const Duration(seconds: 10));
    if (kDebugMode) {
      // ignore: avoid_print
      print('[MediaService] <= ${res.statusCode} (len=${res.body.length})');
      if (res.statusCode == 200) {
        // ignore: avoid_print
        print('[MediaService] body: ${res.body}');
      }
    }
    if (res.statusCode != 200) {
      throw HttpException('Media list failed: ${res.statusCode}');
    }
    final data = json.decode(res.body);
    final items = (data['items'] ?? data['media'] ?? []) as List;
    if (kDebugMode) {
      // ignore: avoid_print
      print('[MediaService] parsed ${items.length} media items');
    }
    return items
        .map((e) => MediaItemDto.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  /// PUT /api/mobile/media/{id}/status { active: bool }
  Future<MediaItemDto> setMediaActive(String id, bool active) async {
    final base = await _getApiBaseUrl();
    final uri = Uri.parse('$base/api/mobile/media/$id/status');
    if (kDebugMode) {
      // ignore: avoid_print
      print('[MediaService] => PUT $uri body={"active":$active}');
    }
    final res = await http
        .put(uri, headers: _jsonHeaders, body: json.encode({'active': active}))
        .timeout(const Duration(seconds: 10));
    if (kDebugMode) {
      // ignore: avoid_print
      print('[MediaService] <= ${res.statusCode}');
      if (res.statusCode == 200) {
        // ignore: avoid_print
        print('[MediaService] body: ${res.body}');
      }
    }
    if (res.statusCode != 200) {
      throw HttpException('Toggle media failed: ${res.statusCode}');
    }
    final data = json.decode(res.body);
    final item = data['item'] ?? data['media'];
    return MediaItemDto.fromJson((item as Map).cast<String, dynamic>());
  }

  /// POST /api/mobile/media multipart: file, type=image|video
  Future<MediaItemDto> uploadMedia(File file, MediaKind type) async {
    final base = await _getApiBaseUrl();
    final uri = Uri.parse('$base/api/mobile/media');
    if (kDebugMode) {
      // ignore: avoid_print
      print(
        '[MediaService] => POST $uri file=${file.path.split('/').last} (${await file.length()} bytes) type=$type',
      );
    }

    final request = http.MultipartRequest('POST', uri);
    request.fields['type'] = type == MediaKind.video ? 'video' : 'image';
    request.fields['duration'] = '10000'; // default 10s
    request.files.add(await http.MultipartFile.fromPath('file', file.path));

    final streamed = await request.send().timeout(const Duration(minutes: 2));
    final res = await http.Response.fromStream(streamed);
    if (kDebugMode) {
      // ignore: avoid_print
      print('[MediaService] <= ${res.statusCode} upload response');
      if (res.statusCode == 200 || res.statusCode == 201) {
        // ignore: avoid_print
        print('[MediaService] body: ${res.body}');
      }
    }
    if (res.statusCode != 200 && res.statusCode != 201) {
      throw HttpException('Upload media failed: ${res.statusCode}');
    }
    final data = json.decode(res.body);
    final item = data['item'] ?? data['media'];
    return MediaItemDto.fromJson((item as Map).cast<String, dynamic>());
  }

  /// POST /api/mobile/media/apply { activeIds: [] } optional
  Future<void> applyActiveMedia(List<String> activeIds) async {
    final base = await _getApiBaseUrl();
    final uri = Uri.parse('$base/api/mobile/media/apply');
    final body = json.encode({'activeIds': activeIds});
    if (kDebugMode) {
      // ignore: avoid_print
      print('[MediaService] => POST $uri activeIds=${activeIds.length}');
    }
    final res = await http
        .post(uri, headers: _jsonHeaders, body: body)
        .timeout(const Duration(seconds: 15));
    if (kDebugMode) {
      // ignore: avoid_print
      print('[MediaService] <= ${res.statusCode} apply response');
    }
    if (res.statusCode != 200) {
      throw HttpException('Apply media failed: ${res.statusCode}');
    }
  }

  /// PUT /api/mobile/media/{id}/duration { duration: ms }
  Future<MediaItemDto> setMediaDuration(String id, int durationMs) async {
    final base = await _getApiBaseUrl();
    final uri = Uri.parse('$base/api/mobile/media/$id/duration');
    if (kDebugMode) {
      // ignore: avoid_print
      print('[MediaService] => PUT $uri body={"duration":$durationMs}');
    }
    final res = await http
        .put(
          uri,
          headers: _jsonHeaders,
          body: json.encode({'duration': durationMs}),
        )
        .timeout(const Duration(seconds: 10));
    if (kDebugMode) {
      // ignore: avoid_print
      print('[MediaService] <= ${res.statusCode} (set duration)');
      if (res.statusCode == 200) {
        // ignore: avoid_print
        print('[MediaService] body: ${res.body}');
      } else {
        // ignore: avoid_print
        print('[MediaService] error body: ${res.body}');
      }
    }
    if (res.statusCode != 200) {
      throw HttpException('Set duration failed: ${res.statusCode}');
    }
    final data = json.decode(res.body);
    final item = data['item'] ?? data['media'];
    return MediaItemDto.fromJson((item as Map).cast<String, dynamic>());
  }

  /// DELETE /api/mobile/media/{id}
  Future<void> deleteMedia(String id) async {
    final base = await _getApiBaseUrl();
    final uri = Uri.parse('$base/api/mobile/media/$id');
    if (kDebugMode) {
      // ignore: avoid_print
      print('[MediaService] => DELETE $uri');
    }
    final res = await http
        .delete(uri, headers: _jsonHeaders)
        .timeout(const Duration(seconds: 10));
    if (kDebugMode) {
      // ignore: avoid_print
      print('[MediaService] <= ${res.statusCode} (delete media)');
      if (res.statusCode >= 200 && res.statusCode < 300) {
        // ignore: avoid_print
        print('[MediaService] delete success body: ${res.body}');
      } else {
        // ignore: avoid_print
        print('[MediaService] delete error body: ${res.body}');
      }
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw HttpException('Delete media failed: ${res.statusCode}');
    }
  }
}
