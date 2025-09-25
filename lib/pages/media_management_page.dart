import 'dart:io';
// ignore: depend_on_referenced_packages
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vibration/vibration.dart';
import 'package:file_picker/file_picker.dart';
import '../widgets/animated_particles.dart';
import '../widgets/animated_toast.dart';
import '../services/media_service.dart';

class MediaManagementPage extends StatefulWidget {
  const MediaManagementPage({super.key});

  @override
  State<MediaManagementPage> createState() => _MediaManagementPageState();
}

class _MediaManagementPageState extends State<MediaManagementPage> {
  // Filtre durumu (0: Tümü, 1: Aktif, 2: Pasif)
  int _selectedFilter = 0;

  // Button press states
  bool _isAddMediaPressed = false;
  bool _isUpdateScreenPressed = false;
  bool _isFilterAllPressed = false;
  bool _isFilterActivePressed = false;
  bool _isFilterInactivePressed = false;

  // Backend medya verileri
  final MediaService _mediaService = MediaService();
  List<MediaItemDto> _mediaItems = [];

  bool _isLoading = true;
  String? _errorMessage;
  bool _isApplying = false;
  bool _isUploading = false;
  MediaKind? _currentUploadingKind;
  double? _currentUploadProgress; // future use if backend supports
  final Set<String> _togglingIds = {};

  // Aktif toast'ları takip etmek için
  OverlayEntry? _activeToastEntry;

  // Video thumbnail cache (mediaId -> bytes)
  final Map<String, Uint8List?> _videoThumbCache = {};
  bool _videoThumbPluginFailed = false; // MissingPluginException guard
  final Map<String, int> _videoThumbRetryCounts =
      {}; // backend thumb retry attempts
  static const int _maxVideoThumbRetries = 6; // ~ progressive retry

  @override
  void initState() {
    super.initState();
    if (kDebugMode) {
      // ignore: avoid_print
      print('[MediaPage] initState -> loading media');
    }
    _loadMedia();
  }

  @override
  void dispose() {
    _removeActiveToast();
    super.dispose();
  }

  Future<void> _loadMedia() async {
    if (kDebugMode) {
      // ignore: avoid_print
      print('[MediaPage] _loadMedia start');
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final items = await _mediaService.getMediaList();
      if (!mounted) return;
      setState(() {
        _mediaItems = items;
        _isLoading = false;
      });
      if (kDebugMode) {
        // ignore: avoid_print
        print('[MediaPage] _loadMedia success items=${items.length}');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Medya listesi alınamadı: $e';
        _isLoading = false;
      });
      if (kDebugMode) {
        // ignore: avoid_print
        print('[MediaPage] _loadMedia error: $e');
      }
    }
  }

  void _removeActiveToast() {
    if (_activeToastEntry != null) {
      _activeToastEntry!.remove();
      _activeToastEntry = null;
    }
  }

  // Filtrelenmiş medya listesi
  List<MediaItemDto> get _filteredMediaItems {
    switch (_selectedFilter) {
      case 1:
        return _mediaItems.where((item) => item.active).toList();
      case 2:
        return _mediaItems.where((item) => !item.active).toList();
      default:
        return _mediaItems;
    }
  }

  void _showSuccessToast(String message) {
    _removeActiveToast();
    if (mounted) {
      // Titreşim feedback'i
      _triggerVibration();

      _showCustomToast(
        icon: Icons.check_circle,
        iconColor: const Color(0xFF38A169),
        title: 'Başarılı',
        subtitle: message,
        backgroundColor: const Color(0xFF1a1a2e).withValues(alpha: 0.95),
      );
    }
  }

  void _showWarningToast(String message) {
    _removeActiveToast();
    if (mounted) {
      // Titreşim feedback'i
      _triggerErrorVibration();

      _showCustomToast(
        icon: Icons.warning,
        iconColor: const Color(0xFFf39c12),
        title: 'Uyarı',
        subtitle: message,
        backgroundColor: const Color(0xFF1a1a2e).withValues(alpha: 0.95),
      );
    }
  }

  // Başarı vibrasyonu (tek titreşim)
  void _triggerVibration() async {
    try {
      final hasVibrator = await Vibration.hasVibrator();
      if (hasVibrator == true) {
        await Vibration.vibrate(duration: 150);
      } else {
        // Vibration desteklenmiyorsa haptic feedback kullan
        HapticFeedback.lightImpact();
      }
    } catch (e) {
      // Vibration hatası durumunda haptic feedback'e geri dön
      HapticFeedback.lightImpact();
    }
  }

  // Hata vibrasyonu (çift titreşim)
  void _triggerErrorVibration() async {
    try {
      final hasVibrator = await Vibration.hasVibrator();
      if (hasVibrator == true) {
        await Vibration.vibrate(pattern: [0, 100, 100, 100]);
      } else {
        // Vibration desteklenmiyorsa haptic feedback kullan
        HapticFeedback.lightImpact();
        await Future.delayed(const Duration(milliseconds: 100));
        HapticFeedback.lightImpact();
      }
    } catch (e) {
      // Vibration hatası durumunda haptic feedback'e geri dön
      HapticFeedback.lightImpact();
      await Future.delayed(const Duration(milliseconds: 100));
      HapticFeedback.lightImpact();
    }
  }

  void _showCustomToast({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required Color backgroundColor,
  }) {
    // Önceki toast varsa kaldır
    _removeActiveToast();

    final overlay = Overlay.of(context, rootOverlay: true);

    _activeToastEntry = OverlayEntry(
      builder: (ctx) => AnimatedToastOverlay(
        context: context, // Scaffold context'ini geç
        icon: icon,
        iconColor: iconColor,
        title: title,
        subtitle: subtitle,
        backgroundColor: backgroundColor,
        onDismiss: () {
          _removeActiveToast();
        },
      ),
    );

    overlay.insert(_activeToastEntry!);
  }

  Future<void> _toggleMediaStatus(String mediaId) async {
    if (kDebugMode) {
      // ignore: avoid_print
      print('[MediaPage] toggle requested for id=$mediaId');
    }
    final index = _mediaItems.indexWhere((m) => m.id == mediaId);
    if (index == -1 || _togglingIds.contains(mediaId)) return;
    final original = _mediaItems[index];
    final newActive = !original.active;
    setState(() {
      _togglingIds.add(mediaId);
      _mediaItems[index] = MediaItemDto(
        id: original.id,
        name: original.name,
        type: original.type,
        active: newActive,
        thumbUrl: original.thumbUrl,
        url: original.url,
        duration: original.duration,
      );
    });
    try {
      final updated = await _mediaService.setMediaActive(mediaId, newActive);
      if (!mounted) return;
      setState(() {
        _mediaItems[index] = updated;
      });
      if (kDebugMode) {
        // ignore: avoid_print
        print(
          '[MediaPage] toggle success id=$mediaId active=${updated.active}',
        );
      }
      if (updated.active) {
        _showSuccessToast('${updated.name} aktifleştirildi');
      } else {
        _showWarningToast('${updated.name} pasifleştirildi');
      }
    } catch (e) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('[MediaPage] toggle error id=$mediaId error=$e');
      }
      if (!mounted) return;
      // Revert
      setState(() {
        _mediaItems[index] = original;
      });
      _showWarningToast('Güncellenemedi: $e');
    } finally {
      if (mounted) {
        setState(() {
          _togglingIds.remove(mediaId);
        });
      }
    }
  }

  Future<void> _editDuration(MediaItemDto media) async {
    final controller = TextEditingController(
      text: (media.duration / 1000).round().toString(),
    );
    final result = await showDialog<int>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2C3E50),
          title: Text(
            'Süre (saniye)',
            style: GoogleFonts.inter(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Örn: 10',
              hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(
                  color: Colors.white.withValues(alpha: 0.2),
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: Color(0xFF3182CE)),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('İPTAL'),
            ),
            TextButton(
              onPressed: () {
                final val = int.tryParse(controller.text.trim());
                if (val == null || val <= 0) {
                  Navigator.pop(ctx);
                  return;
                }
                Navigator.pop(ctx, val);
              },
              child: const Text('KAYDET'),
            ),
          ],
        );
      },
    );
    if (result == null) return;
    final newMs = result * 1000;
    final index = _mediaItems.indexWhere((m) => m.id == media.id);
    if (index == -1) return;
    final original = _mediaItems[index];
    setState(() {
      _mediaItems[index] = MediaItemDto(
        id: original.id,
        name: original.name,
        type: original.type,
        active: original.active,
        thumbUrl: original.thumbUrl,
        url: original.url,
        duration: newMs,
      );
    });
    try {
      final updated = await _mediaService.setMediaDuration(media.id, newMs);
      if (!mounted) return;
      setState(() {
        _mediaItems[index] = updated;
      });
      _showSuccessToast(
        'Süre güncellendi (${(updated.duration / 1000).toStringAsFixed(0)} sn)',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _mediaItems[index] = original; // revert
      });
      _showWarningToast('Süre güncellenemedi: $e');
    }
  }

  void _showAddMediaBottomSheet() {
    HapticFeedback.lightImpact();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF2C3E50),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    const Icon(
                      Icons.add_photo_alternate,
                      color: Color(0xFF3498db),
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Medya Dosyası Seç',
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _buildMediaTypeButton('Fotoğraf Seç', Icons.photo_library, () {
                  Navigator.pop(context);
                  _pickAndUploadFile(MediaKind.image);
                }),
                const SizedBox(height: 12),
                _buildMediaTypeButton('Video Seç', Icons.video_library, () {
                  Navigator.pop(context);
                  _pickAndUploadFile(MediaKind.video);
                }),
                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMediaTypeButton(
    String title,
    IconData icon,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF34495e).withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFF3498db), size: 24),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: Colors.white.withValues(alpha: 0.3),
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndUploadFile(MediaKind kind) async {
    if (_isUploading) return;
    try {
      setState(() {
        _isUploading = true;
        _currentUploadingKind = kind;
        _currentUploadProgress = null;
      });
      if (kDebugMode) {
        // ignore: avoid_print
        print('[MediaPage] upload start type=$kind');
      }
      final result = await FilePicker.platform.pickFiles(
        type: kind == MediaKind.image ? FileType.image : FileType.video,
        allowMultiple: false,
      );
      if (result == null || result.files.isEmpty) {
        if (kDebugMode) {
          // ignore: avoid_print
          print('[MediaPage] upload canceled/no file selected');
        }
        _showWarningToast('Dosya seçilmedi');
        return;
      }
      final path = result.files.single.path;
      if (path == null) {
        _showWarningToast('Dosya yolu alınamadı');
        return;
      }
      final file = File(path);
      if (kDebugMode) {
        // ignore: avoid_print
        print('[MediaPage] uploading file=${file.path.split('/').last}');
      }
      final uploaded = await _mediaService.uploadMedia(file, kind);
      if (!mounted) return;
      setState(() {
        _mediaItems.add(uploaded);
      });
      // Eğer video ise backend thumb oluşmuş mu doğrulamak için polling başlat
      if (uploaded.type == MediaKind.video &&
          uploaded.thumbUrl != null &&
          uploaded.thumbUrl!.isNotEmpty) {
        _pollBackendVideoThumb(uploaded);
      }
      if (kDebugMode) {
        // ignore: avoid_print
        print(
          '[MediaPage] upload success id=${uploaded.id} name=${uploaded.name}',
        );
      }
      _showSuccessToast('${uploaded.name} yüklendi');
    } catch (e) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('[MediaPage] upload error: $e');
      }
      _showWarningToast('Yükleme hatası: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
          _currentUploadingKind = null;
          _currentUploadProgress = null;
        });
      }
    }
  }

  void _pollBackendVideoThumb(MediaItemDto media) {
    // Zaten cache'te varsa gerek yok
    if (_videoThumbCache.containsKey(media.id)) return;
    final thumbUrl = media.thumbUrl;
    if (thumbUrl == null || thumbUrl.isEmpty) return;
    int attempt = 0;
    const maxAttempts = 8; // ~ birkaç saniye

    Future<void> attemptFetch() async {
      if (!mounted) return;
      if (_videoThumbCache.containsKey(media.id)) return; // artık geldi
      attempt++;
      final cacheBuster = attempt == 1
          ? ''
          : (thumbUrl.contains('?') ? '&p=$attempt' : '?p=$attempt');
      final url = '$thumbUrl$cacheBuster';
      if (kDebugMode) {
        // ignore: avoid_print
        print(
          '[MediaPage] polling thumb attempt=$attempt id=${media.id} url=$url',
        );
      }
      try {
        final client = HttpClient();
        client.connectionTimeout = const Duration(seconds: 3);
        final request = await client.getUrl(Uri.parse(url));
        final response = await request.close();
        if (response.statusCode == 200) {
          final bytes = await consolidateHttpClientResponseBytes(response);
          if (bytes.isNotEmpty) {
            if (!mounted) return;
            setState(() {
              _videoThumbCache[media.id] = bytes;
            });
            if (kDebugMode) {
              // ignore: avoid_print
              print('[MediaPage] thumb polling success id=${media.id}');
            }
            client.close(force: true);
            return; // tamam
          }
        }
        client.close(force: true);
      } catch (e) {
        if (kDebugMode) {
          // ignore: avoid_print
          print(
            '[MediaPage] thumb polling error attempt=$attempt id=${media.id} error=$e',
          );
        }
      }
      if (attempt < maxAttempts) {
        // Artan gecikme: 300ms * attempt
        final delay = Duration(milliseconds: 300 * attempt);
        Future.delayed(delay, attemptFetch);
      } else {
        if (kDebugMode) {
          // ignore: avoid_print
          print(
            '[MediaPage] thumb polling stopped (max attempts) id=${media.id}',
          );
        }
      }
    }

    // İlk başlat
    attemptFetch();
  }

  Future<void> _confirmAndDelete(MediaItemDto media) async {
    HapticFeedback.lightImpact();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2C3E50),
        title: Text(
          'Silinsin mi?',
          style: GoogleFonts.inter(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          '"${media.name}" kalıcı olarak silinecek. Emin misiniz?',
          style: GoogleFonts.inter(
            color: Colors.white.withValues(alpha: 0.8),
            fontSize: 14,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('İPTAL'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'SİL',
              style: TextStyle(color: Color(0xFFE74C3C)),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final index = _mediaItems.indexWhere((m) => m.id == media.id);
    if (index == -1) return;
    final removed = media;
    setState(() {
      _mediaItems.removeAt(index);
    });
    try {
      await _mediaService.deleteMedia(media.id);
      _showSuccessToast('Silindi');
    } catch (e) {
      if (mounted) {
        setState(() {
          _mediaItems.insert(index, removed); // revert
        });
      }
      _showWarningToast('Silinemedi: $e');
    }
  }

  Future<void> _updateScreen() async {
    if (_isApplying) return;
    final activeIds = _mediaItems
        .where((m) => m.active)
        .map((m) => m.id)
        .toList();
    if (activeIds.isEmpty) {
      _showWarningToast(
        'Ekranı güncellemek için en az bir aktif medya gerekli',
      );
      return;
    }
    setState(() => _isApplying = true);
    if (kDebugMode) {
      // ignore: avoid_print
      print('[MediaPage] apply start activeIds=${activeIds.length}');
    }
    try {
      await _mediaService.applyActiveMedia(activeIds);
      if (!mounted) return;
      _showSuccessToast('Ekran güncellendi (${activeIds.length} medya)');
    } catch (e) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('[MediaPage] apply error: $e');
      }
      _showWarningToast('Ekran güncellenemedi: $e');
    } finally {
      if (mounted) {
        setState(() => _isApplying = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Arka plan gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF1a1a2e), Color(0xFF000000)],
              ),
            ),
          ),

          // Animated particles arka plan
          const AnimatedParticles(),

          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                _buildFilterSection(),
                Expanded(child: _buildBodyContent()),
              ],
            ),
          ),

          if (_isUploading) _buildUploadingOverlay(),
        ],
      ),
    );
  }

  Widget _buildUploadingOverlay() {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: _isUploading ? 1 : 0,
      child: Container(
        width: double.infinity,
        height: double.infinity,
        color: Colors.black.withValues(alpha: 0.65),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 72,
                height: 72,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    const CircularProgressIndicator(
                      strokeWidth: 6,
                      color: Color(0xFF3182CE),
                    ),
                    Icon(
                      _currentUploadingKind == MediaKind.video
                          ? Icons.video_library
                          : Icons.image,
                      color: Colors.white,
                      size: 32,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _currentUploadingKind == MediaKind.video
                    ? 'Video yükleniyor...'
                    : 'Medya yükleniyor...',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (_currentUploadProgress != null) ...[
                const SizedBox(height: 8),
                Text(
                  '${(_currentUploadProgress! * 100).toStringAsFixed(0)}%',
                  style: GoogleFonts.inter(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 13,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBodyContent() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF3182CE)),
      );
    }
    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              color: Colors.white.withValues(alpha: 0.6),
              size: 48,
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3182CE),
                foregroundColor: Colors.white,
              ),
              onPressed: _loadMedia,
              child: const Text('Tekrar Dene'),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      color: const Color(0xFF3182CE),
      onRefresh: _loadMedia,
      child: _buildMediaGrid(),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              if (mounted) Navigator.pop(context);
            },
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF34495e).withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Medya Yönetimi',
                  style: GoogleFonts.inter(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'Fotoğraf,Video,İçerik Yönetimi',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF3182CE).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.perm_media,
              color: Color(0xFF3182CE),
              size: 24,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSection() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          // Yeni Medya Ekle butonu
          GestureDetector(
            onTapDown: (_) {
              HapticFeedback.lightImpact();
              setState(() => _isAddMediaPressed = true);
            },
            onTapUp: (_) => setState(() => _isAddMediaPressed = false),
            onTapCancel: () => setState(() => _isAddMediaPressed = false),
            onTap: _showAddMediaBottomSheet,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOutCubic,
              width: double.infinity,
              height: 52,
              decoration: BoxDecoration(
                color: _isAddMediaPressed
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withValues(
                    alpha: _isAddMediaPressed ? 0.6 : 0.3,
                  ),
                  width: 1.5,
                ),
                boxShadow: _isAddMediaPressed
                    ? null
                    : [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.add_circle_outline,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'YENİ MEDYA EKLE',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Nöbetix Ekran Güncelle butonu
          GestureDetector(
            onTapDown: (_) {
              HapticFeedback.lightImpact();
              setState(() => _isUpdateScreenPressed = true);
            },
            onTapUp: (_) => setState(() => _isUpdateScreenPressed = false),
            onTapCancel: () => setState(() => _isUpdateScreenPressed = false),
            onTap: _updateScreen,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOutCubic,
              width: double.infinity,
              height: 52,
              decoration: BoxDecoration(
                color: _isUpdateScreenPressed
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withValues(
                    alpha: _isUpdateScreenPressed ? 0.6 : 0.3,
                  ),
                  width: 1.5,
                ),
                boxShadow: _isUpdateScreenPressed
                    ? null
                    : [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.refresh, color: Colors.white, size: 20),
                  const SizedBox(width: 12),
                  Text(
                    'NÖBETİX EKRAN GÜNCELLE',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Filtre butonları
          Row(
            children: [
              Expanded(child: _buildFilterButton('TÜMÜ', 0)),
              const SizedBox(width: 12),
              Expanded(child: _buildFilterButton('AKTİF', 1)),
              const SizedBox(width: 12),
              Expanded(child: _buildFilterButton('PASİF', 2)),
            ],
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildFilterButton(String title, int filterIndex) {
    final isSelected = _selectedFilter == filterIndex;
    bool isPressed = false;

    // Her buton için press state'ini belirle
    switch (filterIndex) {
      case 0:
        isPressed = _isFilterAllPressed;
        break;
      case 1:
        isPressed = _isFilterActivePressed;
        break;
      case 2:
        isPressed = _isFilterInactivePressed;
        break;
    }

    return GestureDetector(
      onTapDown: (_) {
        HapticFeedback.lightImpact();
        setState(() {
          switch (filterIndex) {
            case 0:
              _isFilterAllPressed = true;
              break;
            case 1:
              _isFilterActivePressed = true;
              break;
            case 2:
              _isFilterInactivePressed = true;
              break;
          }
        });
      },
      onTapUp: (_) {
        setState(() {
          _isFilterAllPressed = false;
          _isFilterActivePressed = false;
          _isFilterInactivePressed = false;
          _selectedFilter = filterIndex;
        });
      },
      onTapCancel: () {
        setState(() {
          _isFilterAllPressed = false;
          _isFilterActivePressed = false;
          _isFilterInactivePressed = false;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
        height: 44,
        decoration: BoxDecoration(
          color: isPressed
              ? Colors.white.withValues(alpha: 0.1)
              : (isSelected
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.white.withValues(alpha: 0.05)),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF27AE60).withValues(alpha: 0.8) // Yeşil border
                : Colors.white.withValues(alpha: isPressed ? 0.6 : 0.3),
            width: 1.5,
          ),
          boxShadow: isPressed
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Center(
          child: Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white, // Yazı rengi her zaman beyaz
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMediaGrid() {
    final filteredItems = _filteredMediaItems;

    if (filteredItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.photo_library_outlined,
              size: 64,
              color: Colors.white.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'Henüz medya dosyası yok',
              style: GoogleFonts.inter(
                fontSize: 18,
                color: Colors.white.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Yeni medya eklemek için yukarıdaki butona tıklayın',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Colors.white.withValues(alpha: 0.4),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2, // 4'den 2'ye geri döndük - overflow sorunu çözüldü
          childAspectRatio:
              1.1, // 0.85'den 1.1'e çıkardık - kartlar daha kısa/geniş
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: filteredItems.length,
        itemBuilder: (context, index) {
          return _buildMediaCard(filteredItems[index]);
        },
      ),
    );
  }

  Widget _buildMediaCard(MediaItemDto media) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        color: const Color(0xFF34495e).withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: media.active
              ? const Color(0xFF38A169).withValues(alpha: 0.6) // Yeşil - Aktif
              : const Color(
                  0xFFE74C3C,
                ).withValues(alpha: 0.6), // Kırmızı - Pasif
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: media.active
                ? const Color(0xFF38A169).withValues(
                    alpha: 0.2,
                  ) // Yeşil gölge - Aktif
                : const Color(
                    0xFFE74C3C,
                  ).withValues(alpha: 0.2), // Kırmızı gölge - Pasif
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Thumbnail bölümü
          Expanded(
            flex: 3,
            child: GestureDetector(
              onTap: () => _editDuration(media),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF2C3E50),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(14),
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: _buildThumbnail(media),
                      ),
                    ),
                    // Delete button
                    Positioned(
                      left: 4,
                      top: 4,
                      child: GestureDetector(
                        onTap: () => _confirmAndDelete(media),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.55),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.2),
                              width: 1,
                            ),
                          ),
                          child: const Icon(
                            Icons.delete_outline,
                            size: 14,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 4,
                      top: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.2),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.timer,
                              size: 12,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              '${(media.duration / 1000).round()}s',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Bilgi bölümü - sabit yükseklik
          SizedBox(
            height: 40, // Sabit 40px yükseklik - tam toggle boyutu kadar
            child: Padding(
              padding: const EdgeInsets.all(
                4,
              ), // 8'den 4'e küçülttük - daha dar alan
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center, // Dikey ortalama
                mainAxisSize: MainAxisSize.min, // overflow önlemek için
                children: [
                  // Aktif/Pasif toggle - sola dayalı yazı, sağa dayalı toggle
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        media.active ? 'AKTİF' : 'PASİF',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: media.active
                              ? const Color(0xFF38A169)
                              : Colors.white.withValues(alpha: 0.5),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      GestureDetector(
                        onTap: _togglingIds.contains(media.id)
                            ? null
                            : () => _toggleMediaStatus(media.id),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 40, // 44'den 40'a küçülttük
                          height: 22, // 24'den 22'ye küçülttük
                          decoration: BoxDecoration(
                            color: media.active
                                ? const Color(0xFF38A169)
                                : Colors.white.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(11),
                          ),
                          child: AnimatedAlign(
                            duration: const Duration(milliseconds: 200),
                            alignment: media.active
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Container(
                              width: 18, // 20'den 18'e küçülttük
                              height: 18, // 20'den 18'e küçülttük
                              margin: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThumbnail(MediaItemDto media) {
    if (media.type == MediaKind.image && media.thumbUrl != null) {
      final url = media.thumbUrl!;
      final isNetwork = url.startsWith('http');
      // Varsayım: Backend tam URL döner. Aksi halde burada base ile birleştirme yapılmalı.
      return isNetwork
          ? Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (_, error, stackTrace) =>
                  _buildDefaultThumbnail(media.type),
            )
          : Image.asset(
              url,
              fit: BoxFit.cover,
              errorBuilder: (_, error, stackTrace) =>
                  _buildDefaultThumbnail(media.type),
            );
    } else if (media.type == MediaKind.video) {
      Widget base;
      // Cache -> memory image
      if (_videoThumbCache.containsKey(media.id) &&
          _videoThumbCache[media.id] != null) {
        base = Image.memory(
          _videoThumbCache[media.id]!,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          errorBuilder: (context, error, stackTrace) => _buildVideoThumbnail(),
        );
      } else if (media.thumbUrl != null && media.thumbUrl!.isNotEmpty) {
        // Backend thumb
        final vurl = media.thumbUrl!;
        final net = vurl.startsWith('http');
        // Cache-busting query param if we retried
        final retry = _videoThumbRetryCounts[media.id] ?? 0;
        final cacheBustedUrl = retry == 0 ? vurl : '$vurl?retry=$retry';
        base = net
            ? Image.network(
                cacheBustedUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, err, stack) {
                  if (kDebugMode) {
                    // ignore: avoid_print
                    print(
                      '[MediaPage] backend thumb load error id=${media.id} attempt=$retry err=$err',
                    );
                  }
                  _scheduleBackendThumbRetry(media);
                  return _buildVideoThumbnail();
                },
              )
            : Image.asset(
                cacheBustedUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, err, stack) {
                  if (kDebugMode) {
                    // ignore: avoid_print
                    print(
                      '[MediaPage] backend asset thumb load error id=${media.id} attempt=$retry err=$err',
                    );
                  }
                  _scheduleBackendThumbRetry(media);
                  return _buildVideoThumbnail();
                },
              );
      } else {
        base = _buildVideoThumbnail();
      }
      // Thumb üretimini deneyelim (plugin çalışıyorsa ve cache'te yoksa)
      if (!_videoThumbPluginFailed && !_videoThumbCache.containsKey(media.id)) {
        _maybeGenerateVideoThumb(media);
      }
      return Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(child: base),
          // Koyu overlay (hafif)
          Container(color: Colors.black.withValues(alpha: 0.15)),
          // Play ikonu
          Center(
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.play_arrow,
                color: Colors.white,
                size: 28,
              ),
            ),
          ),
        ],
      );
    }
    return _buildDefaultThumbnail(media.type);
  }

  Future<void> _maybeGenerateVideoThumb(MediaItemDto media) async {
    // Yalnızca video
    if (media.type != MediaKind.video) return;
    // Zaten cache'te varsa tekrar üretme
    if (_videoThumbCache.containsKey(media.id)) return;
    if (_videoThumbPluginFailed) return; // plugin yoksa boşuna deneme
    // URL yoksa (henüz upload edilmiş ve backend dönmemiş olabilir) vazgeç
    final videoUrl = media.url;
    if (videoUrl == null || videoUrl.isEmpty) return;
    // Şimdilik sadece network http(s) destekliyoruz
    if (!videoUrl.startsWith('http')) return;
    // Geçici null koy ki tekrar tekrar tetiklenmesin
    _videoThumbCache[media.id] = null;
    try {
      if (kDebugMode) {
        // ignore: avoid_print
        print('[MediaPage] generating video thumb id=${media.id}');
      }
      // video_thumbnail paketi import edilince kullanılacak
      // ignore: depend_on_referenced_packages
      final videoThumbnail = await VideoThumbnail.thumbnailData(
        video: videoUrl,
        imageFormat: ImageFormat.JPEG,
        quality: 75,
      );
      if (!mounted) return;
      if (videoThumbnail != null) {
        setState(() {
          _videoThumbCache[media.id] = videoThumbnail;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('[MediaPage] video thumb error id=${media.id} error=$e');
      }
      if (e is MissingPluginException) {
        // Plugin yoksa tekrar denemeyelim
        _videoThumbPluginFailed = true;
      }
    }
  }

  void _scheduleBackendThumbRetry(MediaItemDto media) {
    if (media.thumbUrl == null || media.thumbUrl!.isEmpty) return;
    final current = _videoThumbRetryCounts[media.id] ?? 0;
    if (current >= _maxVideoThumbRetries) return;
    // Bir sonraki deneme için artan gecikme (300ms * attempt)
    final delay = Duration(milliseconds: 300 * (current + 1));
    _videoThumbRetryCounts[media.id] = current + 1;
    if (kDebugMode) {
      // ignore: avoid_print
      print(
        '[MediaPage] scheduling thumb retry id=${media.id} attempt=${current + 1} delay=${delay.inMilliseconds}ms',
      );
    }
    Future.delayed(delay, () {
      if (!mounted) return;
      // Sadece hala memory cache oluşmadıysa ve max'a ulaşmadıysa setState ile tekrar dene
      if ((_videoThumbCache[media.id] == null) &&
          (_videoThumbRetryCounts[media.id] ?? 0) <= _maxVideoThumbRetries) {
        setState(
          () {},
        ); // rebuild -> Image.network yeniden deneyecek (cache bust param ile)
      }
    });
  }

  Widget _buildVideoThumbnail() {
    return SizedBox(
      width: double.infinity,
      height: double.infinity,
      child: Stack(
        children: [
          // Mock video thumbnail (logo.png'yi kullan)
          Center(
            child: Image.asset(
              'assets/images/logo.png',
              fit: BoxFit.contain,
              width: double.infinity,
              height: double.infinity,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  color: const Color(0xFF2C3E50),
                  child: const Icon(
                    Icons.videocam,
                    size: 48,
                    color: Color(0xFF3182CE),
                  ),
                );
              },
            ),
          ),

          // Koyu overlay
          SizedBox(
            width: double.infinity,
            height: double.infinity,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.3),
              ),
            ),
          ),

          // Play button overlay
          Center(
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.play_arrow,
                color: Colors.white,
                size: 32,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDefaultThumbnail(MediaKind type) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: const Color(0xFF2C3E50),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            type == MediaKind.image ? Icons.image : Icons.play_circle_fill,
            size: 48,
            color: const Color(0xFF3182CE),
          ),
          const SizedBox(height: 8),
          Text(
            type == MediaKind.image ? 'Fotoğraf' : 'Video',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}
