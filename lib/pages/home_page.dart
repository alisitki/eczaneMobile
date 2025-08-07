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

    // Periyodik kontrolü başlat
    _connectionService.startPeriodicCheck();
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

  void _handleManualConnectionCheck() async {
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
                  padding: const EdgeInsets.only(top: 20, bottom: 10),
                  child: Column(
                    children: [
                      // Logo
                      Container(
                        width: 240,
                        height: 140,
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
                      const SizedBox(height: 15),
                      // Sayfa başlığı
                      Text(
                        'KONTROL MERKEZİ',
                        style: GoogleFonts.inter(
                          fontSize: 24,
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
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
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
                                onTap: () =>
                                    _handleCardTap(context, 'Nöbetçi Eczane'),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildControlCard(
                                title: 'Wi-Fi & Ağ\nAyarları',
                                icon: Icons.wifi,
                                iconColor: const Color(0xFF38A169),
                                onTap: () =>
                                    _handleCardTap(context, 'Wi-Fi & Ağ'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // İkinci satır - 2 buton
                        Row(
                          children: [
                            Expanded(
                              child: _buildControlCard(
                                title: 'Medya\nYönetimi',
                                icon: Icons.play_circle_filled,
                                iconColor: const Color(0xFF3182CE),
                                onTap: () => _handleCardTap(context, 'Medya'),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildControlCard(
                                title: 'Ekran\nAyarları',
                                icon: Icons.monitor,
                                iconColor: const Color(0xFF718096),
                                onTap: () => _handleCardTap(context, 'Ekran'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

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
                        const SizedBox(height: 16),

                        // Bağlantıyı Kontrol Et butonu
                        _InteractiveCard(
                          onTap: () => _handleManualConnectionCheck(),
                          child: Container(
                            width: double.infinity,
                            height: 60,
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
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: const Color(
                                        0xFF3182CE,
                                      ).withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(
                                      Icons.sync,
                                      size: 20,
                                      color: Color(0xFF3182CE),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    'Bağlantıyı Kontrol Et',
                                    style: GoogleFonts.inter(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
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

  Widget _buildControlCard({
    required String title,
    required IconData icon,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return _InteractiveCard(
      onTap: onTap,
      child: Container(
        height: 140,
        decoration: BoxDecoration(
          color: const Color(0xFF2A2A3E).withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.1),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 28, color: iconColor),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.white,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleCardTap(BuildContext context, String cardType) async {
    // Haptic feedback
    try {
      final hasVibrator = await Vibration.hasVibrator();
      if (hasVibrator == true) {
        await Vibration.vibrate(duration: 50);
      }
    } catch (e) {
      // Vibration hatası durumunda sessizce devam et
    }

    // Context hala geçerliyse devam et
    if (!context.mounted) return;

    if (cardType == 'Nöbetçi Eczane') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const PharmacySettingsPage()),
      );
    } else if (cardType == 'Ekran') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const ScreenSettingsPage()),
      );
    } else if (cardType == 'Wi-Fi & Ağ') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const WifiSettingsPage()),
      );
    } else if (cardType == 'Medya') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const MediaManagementPage()),
      );
    } else {
      // Diğer sayfalar için geçici SnackBar
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

  const _InteractiveCard({required this.child, required this.onTap});

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
    _animationController.forward();
  }

  void _handleTapUp(TapUpDetails details) {
    _animationController.reverse();
    widget.onTap();
  }

  void _handleTapCancel() {
    _animationController.reverse();
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
