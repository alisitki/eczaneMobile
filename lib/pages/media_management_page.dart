import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vibration/vibration.dart';
import '../widgets/animated_particles.dart';
import '../widgets/animated_toast.dart';

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

  // Mock medya verileri
  final List<MediaItem> _mediaItems = [
    MediaItem(
      id: '1',
      name: 'eczane_logo.jpg',
      type: MediaType.image,
      isActive: true,
      thumbnailPath: 'assets/images/logo.png',
    ),
    MediaItem(
      id: '2',
      name: 'tanitim_video.mp4',
      type: MediaType.video,
      isActive: true,
      thumbnailPath: null,
    ),
    MediaItem(
      id: '3',
      name: 'kampanya_banner.png',
      type: MediaType.image,
      isActive: false,
      thumbnailPath: 'assets/images/slogan.png',
    ),
    MediaItem(
      id: '4',
      name: 'rehber_video.mp4',
      type: MediaType.video,
      isActive: false,
      thumbnailPath: null,
    ),
    MediaItem(
      id: '5',
      name: 'acilis_fotografi.jpg',
      type: MediaType.image,
      isActive: true,
      thumbnailPath: 'assets/images/version.png',
    ),
    MediaItem(
      id: '6',
      name: 'etkinlik_video.mp4',
      type: MediaType.video,
      isActive: true,
      thumbnailPath: null,
    ),
  ];

  // Aktif toast'ları takip etmek için
  OverlayEntry? _activeToastEntry;

  @override
  void dispose() {
    _removeActiveToast();
    super.dispose();
  }

  void _removeActiveToast() {
    if (_activeToastEntry != null) {
      _activeToastEntry!.remove();
      _activeToastEntry = null;
    }
  }

  // Filtrelenmiş medya listesi
  List<MediaItem> get _filteredMediaItems {
    switch (_selectedFilter) {
      case 1:
        return _mediaItems.where((item) => item.isActive).toList();
      case 2:
        return _mediaItems.where((item) => !item.isActive).toList();
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

  void _toggleMediaStatus(String mediaId) {
    setState(() {
      final mediaIndex = _mediaItems.indexWhere((item) => item.id == mediaId);
      if (mediaIndex != -1) {
        _mediaItems[mediaIndex].isActive = !_mediaItems[mediaIndex].isActive;
        final isActive = _mediaItems[mediaIndex].isActive;
        final mediaName = _mediaItems[mediaIndex].name;

        if (isActive) {
          _showSuccessToast('$mediaName aktifleştirildi');
        } else {
          _showWarningToast('$mediaName pasifleştirildi');
        }
      }
    });
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
                  _mockFileSelection('image');
                }),
                const SizedBox(height: 12),
                _buildMediaTypeButton('Video Seç', Icons.video_library, () {
                  Navigator.pop(context);
                  _mockFileSelection('video');
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

  void _mockFileSelection(String type) {
    // Mock dosya seçimi
    final fileName = type == 'image' ? 'yeni_fotograf.jpg' : 'yeni_video.mp4';
    final newMedia = MediaItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: fileName,
      type: type == 'image' ? MediaType.image : MediaType.video,
      isActive: true,
      thumbnailPath: type == 'image' ? 'assets/images/logo.png' : null,
    );

    setState(() {
      _mediaItems.add(newMedia);
    });

    _showSuccessToast('$fileName başarıyla eklendi');
  }

  void _updateScreen() {
    // Aktif medya dosyalarını say
    final activeMediaCount = _mediaItems.where((item) => item.isActive).length;

    if (activeMediaCount == 0) {
      _showWarningToast(
        'Ekranı güncellemek için en az bir aktif medya seçili olmalı',
      );
      return;
    }

    // Mock backend güncelleme
    _showSuccessToast(
      'Ekran güncellendi! $activeMediaCount aktif medya gönderildi',
    );
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
                Expanded(child: _buildMediaGrid()),
              ],
            ),
          ),
        ],
      ),
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

  Widget _buildMediaCard(MediaItem media) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        color: const Color(0xFF34495e).withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: media.isActive
              ? const Color(0xFF38A169).withValues(alpha: 0.6) // Yeşil - Aktif
              : const Color(
                  0xFFE74C3C,
                ).withValues(alpha: 0.6), // Kırmızı - Pasif
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: media.isActive
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
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(
                6,
              ), // Thumbnail etrafında 6px boşluk
              decoration: BoxDecoration(
                color: const Color(0xFF2C3E50),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(14),
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8), // İç radius daha küçük
                child: _buildThumbnail(media),
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
                        media.isActive ? 'AKTİF' : 'PASİF',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: media.isActive
                              ? const Color(0xFF38A169)
                              : Colors.white.withValues(alpha: 0.5),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      GestureDetector(
                        onTap: () => _toggleMediaStatus(media.id),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 40, // 44'den 40'a küçülttük
                          height: 22, // 24'den 22'ye küçülttük
                          decoration: BoxDecoration(
                            color: media.isActive
                                ? const Color(0xFF38A169)
                                : Colors.white.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(11),
                          ),
                          child: AnimatedAlign(
                            duration: const Duration(milliseconds: 200),
                            alignment: media.isActive
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

  Widget _buildThumbnail(MediaItem media) {
    if (media.type == MediaType.image && media.thumbnailPath != null) {
      return Center(
        child: Image.asset(
          media.thumbnailPath!,
          fit: BoxFit.contain,
          width: double.infinity,
          height: double.infinity,
          errorBuilder: (context, error, stackTrace) {
            return _buildDefaultThumbnail(media.type);
          },
        ),
      );
    } else if (media.type == MediaType.video) {
      // Video için mock thumbnail + play button overlay
      return _buildVideoThumbnail();
    } else {
      return _buildDefaultThumbnail(media.type);
    }
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

  Widget _buildDefaultThumbnail(MediaType type) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: const Color(0xFF2C3E50),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            type == MediaType.image ? Icons.image : Icons.play_circle_fill,
            size: 48,
            color: const Color(0xFF3182CE),
          ),
          const SizedBox(height: 8),
          Text(
            type == MediaType.image ? 'Fotoğraf' : 'Video',
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

// Medya türü enum
enum MediaType { image, video }

// Medya öğesi modeli
class MediaItem {
  final String id;
  final String name;
  final MediaType type;
  bool isActive;
  final String? thumbnailPath;

  MediaItem({
    required this.id,
    required this.name,
    required this.type,
    required this.isActive,
    this.thumbnailPath,
  });
}
