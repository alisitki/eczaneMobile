import 'dart:convert';
import 'dart:io';

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

  MediaItemDto({
    required this.id,
    required this.name,
    required this.type,
    required this.active,
    this.thumbUrl,
    this.url,
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
    );
  }
}

class MediaService {
  final ConnectionService _connectionService = ConnectionService();

  Future<String> _getApiBaseUrl() async {
    try {
      await _connectionService.checkConnection();
    } catch (_) {}

    final status = _connectionService.currentStatus;
    switch (status.type) {
      case ConnectionType.wifi:
        final cached = _connectionService.getCachedHostnameIP(
          'raspberrypi.local',
        );
        if (cached != null && cached.isNotEmpty) {
          return 'http://$cached:3000';
        }
        return 'http://raspberrypi.local:3000';
      case ConnectionType.hotspot:
      case ConnectionType.none:
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
    final res = await http
        .get(uri, headers: _jsonHeaders)
        .timeout(const Duration(seconds: 10));
    if (res.statusCode != 200) {
      throw HttpException('Media list failed: ${res.statusCode}');
    }
    final data = json.decode(res.body);
    final items = (data['items'] ?? data['media'] ?? []) as List;
    return items
        .map((e) => MediaItemDto.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  /// PUT /api/mobile/media/{id}/status { active: bool }
  Future<MediaItemDto> setMediaActive(String id, bool active) async {
    final base = await _getApiBaseUrl();
    final uri = Uri.parse('$base/api/mobile/media/$id/status');
    final res = await http
        .put(uri, headers: _jsonHeaders, body: json.encode({'active': active}))
        .timeout(const Duration(seconds: 10));
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

    final request = http.MultipartRequest('POST', uri);
    request.fields['type'] = type == MediaKind.video ? 'video' : 'image';
    request.files.add(await http.MultipartFile.fromPath('file', file.path));

    final streamed = await request.send().timeout(const Duration(minutes: 2));
    final res = await http.Response.fromStream(streamed);
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
    final res = await http
        .post(uri, headers: _jsonHeaders, body: body)
        .timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) {
      throw HttpException('Apply media failed: ${res.statusCode}');
    }
  }
}
