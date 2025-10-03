import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vibration/vibration.dart';
import '../widgets/animated_particles.dart';
import '../widgets/animated_toast.dart';
import '../services/connection_service.dart';
import 'pharmacy_settings_page.dart';
import 'screen_settings_page.dart';
import 'wifi_settings_page.dart';
import 'media_management_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final ConnectionService _connectionService = ConnectionService();
  ConnectionStatus _connectionStatus = ConnectionStatus.disconnected();
  bool _isCheckingConnection = false;
  StreamSubscription<ConnectionStatus>? _statusSubscription;
  OverlayEntry? _activeToastEntry;

  @override
  void initState() {
    super.initState();
    _initializeConnection();
  }

  @override
  void dispose() {
    _statusSubscription?.cancel();
    _connectionService.stopPeriodicCheck();
    _removeActiveToast();
    super.dispose();
  }

  void _initializeConnection() async {
    // Status stream'i dinle
    _statusSubscription = _connectionService.statusStream.listen((status) {
      if (mounted) {
        final previousStatus = _connectionStatus;
        setState(() {
          _connectionStatus = status;
          _isCheckingConnection =
              false; // Stream'den geldiğinde loading'i kapat
        });

        // Sadece durum değiştiğinde toast göster
        if (previousStatus != status) {
          _showConnectionToast(status);
        }
      }
    });

    // İlk bağlantı kontrolü
    setState(() {
      _isCheckingConnection = true;
    });

    try {
      await _connectionService.checkConnection();
    } catch (e) {
      debugPrint('Connection check failed: $e');
    } finally {
      // Eğer stream'den henüz gelmemişse, manuel olarak loading'i kapat
      if (mounted) {
        setState(() {
          _isCheckingConnection = false;
        });
      }
    }

    // Periyodik kontrolü başlatmıyoruz - sadece açılışta kontrol
    // _connectionService.startPeriodicCheck();
  }

  void _showConnectionToast(ConnectionStatus status) {
    if (!mounted) return;

    if (status.isConnected) {
      String subtitle;
      switch (status.type) {
        case ConnectionType.wifi:
          subtitle = 'Nöbetix Pano WiFi ile Bağlandı';
          break;
        case ConnectionType.hotspot:
          subtitle = 'Nöbetix Pano Hotspot ile Bağlandı';
          break;
        default:
          subtitle = 'Nöbetix Pano Bağlandı';
      }

      _showToast(
        icon: status.type == ConnectionType.wifi
            ? Icons.wifi
            : Icons.portable_wifi_off,
        iconColor: const Color(0xFF38A169),
        title: 'Bağlantı Kuruldu',
        subtitle: subtitle,
        backgroundColor: const Color(0xFF38A169),
      );
    } else {
      _showToast(
        icon: Icons.wifi_off,
        iconColor: const Color(0xFFE53E3E),
        title: 'Bağlantı Hatası',
        subtitle: 'Nöbetix Pano Bağlantı Kurulamadı',
        backgroundColor: const Color(0xFFE53E3E),
      );
    }
  }

  void _showToast({
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
        context: context,
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

    // 3 saniye sonra otomatik kaldır
    Timer(const Duration(seconds: 3), () {
      _removeActiveToast();
    });
  }

  void _removeActiveToast() {
    _activeToastEntry?.remove();
    _activeToastEntry = null;
  }

  Widget _buildConnectionStatusIcon() {
    if (_isCheckingConnection) {
      return const SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF718096)),
        ),
      );
    }

    switch (_connectionStatus.type) {
      case ConnectionType.wifi:
        return const Icon(Icons.wifi, color: Color(0xFF38A169), size: 16);
      case ConnectionType.hotspot:
        return const Icon(
          Icons.portable_wifi_off,
          color: Color(0xFF38A169),
          size: 16,
        );
      case ConnectionType.none:
        return const Icon(Icons.wifi_off, color: Color(0xFFE53E3E), size: 16);
    }
  }

  String _getConnectionStatusText() {
    if (_isCheckingConnection) {
      return 'Bağlantı kontrol ediliyor...';
    }

    if (_connectionStatus.isConnected) {
      switch (_connectionStatus.type) {
        case ConnectionType.wifi:
          return 'Nöbetix Pano WiFi ile Bağlandı';
        case ConnectionType.hotspot:
          return 'Nöbetix Pano Hotspot ile Bağlandı';
        case ConnectionType.none:
          return 'Nöbetix Pano Bağlantı Kurulamadı';
      }
    } else {
      return 'Nöbetix Pano Bağlantı Kurulamadı';
    }
  }

  Color _getConnectionStatusColor() {
    if (_isCheckingConnection) {
      return const Color(0xFF718096);
    }
    return _connectionStatus.isConnected
        ? const Color(0xFF38A169)
        : const Color(0xFFE53E3E);
  }

  // Kartların görsel durumunu kontrol eden method (her zaman aktif görünecek)
  bool _isCardEnabled(String cardType) {
    // Artık tüm kartlar her zaman görsel olarak aktif
    return true;
  }

  void _handleManualConnectionCheck() async {
    // Hotspot ise kullanıcı zaten alttaki karttaki yönergeyi görecek

    // Haptic feedback
    try {
      final hasVibrator = await Vibration.hasVibrator();
      if (hasVibrator == true) {
        await Vibration.vibrate(duration: 50);
      }
    } catch (e) {
      // Vibration hatası durumunda sessizce devam et
    }

    // Manuel bağlantı kontrolü başlat
    setState(() {
      _isCheckingConnection = true;
    });

    try {
      await _connectionService.checkConnection();
    } catch (e) {
      debugPrint('Manual connection check failed: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isCheckingConnection = false;
        });
      }
    }

    // Toast göster
    if (mounted) {
      _showToast(
        icon: Icons.sync,
        iconColor: const Color(0xFF3182CE),
        title: 'Bağlantı Kontrolü',
        subtitle: 'Bağlantı durumu güncellendi',
        backgroundColor: const Color(0xFF3182CE),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height;
    final uiScale = (h / 700).clamp(0.85, 1.0);
    return Scaffold(
      body: Stack(
        children: [
          // Ana arka plan gradient
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF1a1a2e), // Koyu lacivert
                  Color(0xFF000000), // Siyah
                ],
              ),
            ),
          ),
          // Animated particles
          const Positioned.fill(child: AnimatedParticles()),
          // Ana içerik
          SafeArea(
            child: Column(
              children: [
                // Logo ve başlık bölümü
                Padding(
                  padding: const EdgeInsets.only(top: 15, bottom: 20),
                  child: Column(
                    children: [
                      // Logo
                      Container(
                        width: 200,
                        height: 110,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Image.asset(
                            'assets/images/logo.png',
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      // Sayfa başlığı
                      Text(
                        'KONTROL MERKEZİ',
                        style: GoogleFonts.inter(
                          fontSize: 21,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),

                // Ana içerik - 4 buton
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 5),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        // İlk satır - 2 buton
                        Row(
                          children: [
                            Expanded(
                              child: _buildControlCard(
                                title: 'Nöbetçi Eczane\nAyarları',
                                icon: Icons.local_pharmacy,
                                iconColor: const Color(0xFFE53E3E),
                                onTap: () => _handleCardTap('Nöbetçi Eczane'),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildControlCard(
                                title: 'Wi-Fi & Ağ\nAyarları',
                                icon: Icons.wifi,
                                iconColor: const Color(0xFF38A169),
                                onTap: () => _handleCardTap('Wi-Fi & Ağ'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        // İkinci satır - 2 buton
                        Row(
                          children: [
                            Expanded(
                              child: _buildControlCard(
                                title: 'Medya\nYönetimi',
                                icon: Icons.play_circle_filled,
                                iconColor: const Color(0xFF3182CE),
                                onTap: () => _handleCardTap('Medya'),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildControlCard(
                                title: 'Ekran\nAyarları',
                                icon: Icons.monitor,
                                iconColor: const Color(0xFF718096),
                                onTap: () => _handleCardTap('Ekran'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // Bağlantı durumu - kompakt hale getirildi
                        Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 12,
                            horizontal: 16,
                          ),
                          decoration: BoxDecoration(
                            color: _getConnectionStatusColor().withValues(
                              alpha: 0.1,
                            ),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: _getConnectionStatusColor().withValues(
                                alpha: 0.3,
                              ),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _buildConnectionStatusIcon(),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _getConnectionStatusText(),
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    color: _getConnectionStatusColor(),
                                    fontWeight: FontWeight.w500,
                                    height: 1.2,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Bağlantıyı Kontrol Et butonu
                        SizedBox(
                          height: 56 * uiScale,
                          child: _InteractiveCard(
                            onTap: () => _handleManualConnectionCheck(),
                            isEnabled: true,
                            child: Container(
                              width: double.infinity,
                              height: 56 * uiScale,
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFF2A2A3E,
                                ).withValues(alpha: 0.8),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.1),
                                  width: 1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.2),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      width: 32 * uiScale,
                                      height: 32 * uiScale,
                                      decoration: BoxDecoration(
                                        color: const Color(
                                          0xFF3182CE,
                                        ).withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(
                                        Icons.sync,
                                        size: 18,
                                        color: Color(0xFF3182CE),
                                      ),
                                    ),
                                    SizedBox(width: 10 * uiScale),
                                    Text(
                                      'Bağlantıyı Kontrol Et',
                                      style: GoogleFonts.inter(
                                        fontSize: 14 * uiScale,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: 12 * uiScale),
                        _buildHotspotInfoCard(uiScale: uiScale),
                      ],
                    ),
                  ),
                ),

                // Sürüm bilgisi
                Padding(
                  padding: const EdgeInsets.only(bottom: 30),
                  child: Text(
                    'Sürüm V.1.0.0',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.5),
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
              ],
            ),
          ), // SafeArea kapanış parantezi
        ],
      ),
    );
  }

  Widget _buildHotspotInfoCard({double uiScale = 1}) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(10 * uiScale),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2F3C).withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34 * uiScale,
            height: 34 * uiScale,
            decoration: BoxDecoration(
              color: const Color(0xFF3182CE).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.wifi_tethering,
              color: Color(0xFF3182CE),
              size: 18,
            ),
          ),
          SizedBox(width: 8 * uiScale),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hotspot ile Bağlandıysanız',
                  style: GoogleFonts.inter(
                    fontSize: 12.2 * uiScale,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.95),
                  ),
                ),
                SizedBox(height: 4 * uiScale),
                Text(
                  'Üst bildirim çubuğunda "İnternet yok" uyarısı çıkarsa bildirimi açıp "Bağlı kal" / "Ağa bağlı kal" seçeneğini seçin. Aksi halde pano servise erişemez.',
                  style: GoogleFonts.inter(
                    fontSize: 11.2 * uiScale,
                    height: 1.32,
                    color: Colors.white.withValues(alpha: 0.72),
                  ),
                ),
                SizedBox(height: 5 * uiScale),
                Row(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      size: 12,
                      color: Color(0xFF3182CE),
                    ),
                    SizedBox(width: 4 * uiScale),
                    Expanded(
                      child: Text(
                        'Uyarı gelmiyorsa önce bir bağlantı kontrolü yapın; gerekiyorsa mobil veriyi kısa süre kapatıp açın.',
                        style: GoogleFonts.inter(
                          fontSize: 10.5 * uiScale,
                          height: 1.28,
                          color: Colors.white.withValues(alpha: 0.55),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlCard({
    required String title,
    required IconData icon,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    // Kartın aktif olup olmadığını kontrol et - title'dan cardType çıkar
    String cardType;
    if (title.contains('Nöbetçi Eczane')) {
      cardType = 'Nöbetçi Eczane';
    } else if (title.contains('Wi-Fi & Ağ')) {
      cardType = 'Wi-Fi & Ağ';
    } else if (title.contains('Medya')) {
      cardType = 'Medya';
    } else if (title.contains('Ekran')) {
      cardType = 'Ekran';
    } else {
      cardType = title.replaceAll('\n', ' ');
    }

    final isEnabled = _isCardEnabled(cardType);
    final opacity = isEnabled ? 1.0 : 0.4;
    final finalIconColor = isEnabled ? iconColor : const Color(0xFF718096);

    return _InteractiveCard(
      onTap: onTap,
      isEnabled: isEnabled,
      child: Container(
        height: 122,
        decoration: BoxDecoration(
          color: const Color(0xFF2A2A3E).withValues(alpha: 0.8 * opacity),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.1 * opacity),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2 * opacity),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: finalIconColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 26, color: finalIconColor),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13.2,
                fontWeight: FontWeight.w500,
                color: Colors.white.withValues(alpha: opacity),
                height: 1.25,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleCardTap(String cardType) async {
    // Async sonrası güvenlik için her await'ten sonra State.mounted kontrolü yapılacak.
    // Haptic feedback
    try {
      final hasVibrator = await Vibration.hasVibrator();
      if (hasVibrator == true) {
        await Vibration.vibrate(duration: 40, amplitude: 128);
      }
    } catch (e) {
      // Vibration hatası durumunda sessizce devam et
    }

    // Context hala geçerliyse devam et
    if (!mounted) return;
    // Card tıklandığında bağlantı kontrolü yap
    setState(() {
      _isCheckingConnection = true;
    });
    try {
      await _connectionService.checkConnection();
      if (!mounted) return; // async gap sonrası güvenlik
    } catch (e) {
      debugPrint('Card tap connection check failed: $e');
      if (mounted) {
        setState(() {});
      }
    }

    // Bağlantı kontrolü sonrası durumu kontrol et
    if (!_connectionStatus.isConnected) {
      try {
        final hasVibrator = await Vibration.hasVibrator();
        if (hasVibrator == true) {
          await Vibration.vibrate(duration: 200);
        }
      } catch (_) {}
      if (!mounted) return;
      _showToast(
        icon: Icons.wifi_off,
        iconColor: const Color(0xFFE53E3E),
        title: 'Bağlantı Hatası',
        subtitle: 'Nöbetix Panoya bağlanılması gerekiyor',
        backgroundColor: const Color(0xFFE53E3E),
      );
      return;
    }

    // Bağlantı varsa normal navigasyon
    if (cardType == 'Nöbetçi Eczane') {
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const PharmacySettingsPage()),
      );
    } else if (cardType == 'Ekran') {
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const ScreenSettingsPage()),
      );
      // Artık sayfa dönüşlerinde otomatik kontrol yapmıyoruz
      // _quickConnectionCheck();
    } else if (cardType == 'Wi-Fi & Ağ') {
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const WifiSettingsPage()),
      );
      // Artık sayfa dönüşlerinde otomatik kontrol yapmıyoruz
      // _quickConnectionCheck();
    } else if (cardType == 'Medya') {
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const MediaManagementPage()),
      );
    } else {
      // Diğer sayfalar için geçici SnackBar
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$cardType sayfası yakında eklenecek'),
          backgroundColor: const Color(0xFF2A2A3E),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }
  }
}

// Interactive Card Widget with Animation
class _InteractiveCard extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final bool isEnabled;

  const _InteractiveCard({
    required this.child,
    required this.onTap,
    this.isEnabled = true,
  });

  @override
  State<_InteractiveCard> createState() => _InteractiveCardState();
}

class _InteractiveCardState extends State<_InteractiveCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _shadowAnimation;
  late Animation<double> _borderAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _shadowAnimation = Tween<double>(begin: 1.0, end: 0.3).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _borderAnimation = Tween<double>(begin: 0.1, end: 0.3).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    if (widget.isEnabled) {
      _animationController.forward();
    }
  }

  void _handleTapUp(TapUpDetails details) {
    if (widget.isEnabled) {
      _animationController.reverse();
    }
    // isEnabled false olsa bile onTap'i çağır - _handleCardTap içinde kontrol yapılacak
    widget.onTap();
  }

  void _handleTapCancel() {
    if (widget.isEnabled) {
      _animationController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      child: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(
                      alpha: 0.2 * _shadowAnimation.value,
                    ),
                    blurRadius: 10 * _shadowAnimation.value,
                    offset: Offset(0, 4 * _shadowAnimation.value),
                  ),
                  // Glow effect on press
                  if (_animationController.value > 0)
                    BoxShadow(
                      color: Colors.white.withValues(
                        alpha: 0.1 * _animationController.value,
                      ),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                ],
              ),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withValues(
                      alpha: _borderAnimation.value,
                    ),
                    width: 1,
                  ),
                ),
                child: widget.child,
              ),
            ),
          );
        },
      ),
    );
  }
}
