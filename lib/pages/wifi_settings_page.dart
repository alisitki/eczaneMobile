import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vibration/vibration.dart';
import '../widgets/animated_particles.dart';
import '../widgets/animated_toast.dart';

class WifiSettingsPage extends StatefulWidget {
  const WifiSettingsPage({super.key});

  @override
  State<WifiSettingsPage> createState() => _WifiSettingsPageState();
}

class _WifiSettingsPageState extends State<WifiSettingsPage> {
  // Mock bağlantı durumu (0: Aynı Wi-Fi, 1: Hotspot, 2: Bağlantı yok)
  int connectionStatus = 2;

  // Form controllers
  final TextEditingController hotspotSSIDController = TextEditingController();
  final TextEditingController hotspotPasswordController =
      TextEditingController();
  final TextEditingController wifiSSIDController = TextEditingController();
  final TextEditingController wifiPasswordController = TextEditingController();

  // Aktif toast'ları takip etmek için
  OverlayEntry? _activeToastEntry;

  // Button press states
  bool _isHotspotPressed = false;
  bool _isWiFiPressed = false;

  @override
  void dispose() {
    // Sayfa kapanırken aktif toast'ı kaldır
    _removeActiveToast();
    hotspotSSIDController.dispose();
    hotspotPasswordController.dispose();
    wifiSSIDController.dispose();
    wifiPasswordController.dispose();
    super.dispose();
  }

  void _removeActiveToast() {
    if (_activeToastEntry != null) {
      _activeToastEntry!.remove();
      _activeToastEntry = null;
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
                // Başlık bölümü
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 20,
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(
                          Icons.arrow_back_ios,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          'Wi-Fi & Ağ Ayarları',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(
                        width: 48,
                      ), // Geri butonuyla dengelemek için
                    ],
                  ),
                ),

                // Form içeriği
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Bağlantı Durumu Kartı
                        _buildConnectionStatusCard(),

                        const SizedBox(height: 32),

                        // Hotspot Bağlantı Bölümü
                        _buildHotspotSection(),

                        const SizedBox(height: 32),

                        // Wi-Fi Bağlantı Bölümü
                        _buildWiFiSection(),

                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(
        title,
        style: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildConnectionStatusCard() {
    String statusText;
    IconData statusIcon;
    Color statusColor;

    switch (connectionStatus) {
      case 0:
        statusText = "Ekran ile aynı Wi-Fi ağına bağlısınız.";
        statusIcon = Icons.wifi;
        statusColor = const Color(0xFF38A169);
        break;
      case 1:
        statusText = "Ekranın Hotspot ağına bağlısınız.";
        statusIcon = Icons.wifi_tethering;
        statusColor = const Color(0xFF3182CE);
        break;
      default:
        statusText =
            "Ekrana bağlantı kurulamadı. Lütfen Wi-Fi ayarlarından bağlanın.";
        statusIcon = Icons.wifi_off;
        statusColor = const Color(0xFFE53E3E);
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A3E).withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: statusColor.withValues(alpha: 0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(statusIcon, color: statusColor, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bağlantı Durumu',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  statusText,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHotspotSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Nöbetix Ekrana\'a Bağlanma :'),

        _buildInputField(
          controller: hotspotSSIDController,
          label: 'Nöbetix SSID',
          icon: Icons.wifi_tethering,
        ),

        const SizedBox(height: 16),

        _buildInputField(
          controller: hotspotPasswordController,
          label: 'Nöbetix Şifresi',
          icon: Icons.lock,
          isPassword: true,
        ),

        const SizedBox(height: 20),

        _buildActionButton(
          text: 'NÖBETİX EKRAN\'A BAĞLAN',
          onPressed: _connectToHotspot,
          isPressed: _isHotspotPressed,
          onPressChanged: (pressed) =>
              setState(() => _isHotspotPressed = pressed),
        ),
      ],
    );
  }

  Widget _buildWiFiSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Nöbetix Ekran\'ı Wi-Fi Ağına Bağlama'),

        _buildInputField(
          controller: wifiSSIDController,
          label: 'Wi-Fi SSID',
          icon: Icons.wifi,
        ),

        const SizedBox(height: 16),

        _buildInputField(
          controller: wifiPasswordController,
          label: 'Wi-Fi Şifresi',
          icon: Icons.lock,
          isPassword: true,
        ),

        const SizedBox(height: 20),

        _buildActionButton(
          text: 'NÖBETİX EKRAN\'I AĞA BAĞLA',
          onPressed: _connectRPiToWiFi,
          isPressed: _isWiFiPressed,
          onPressChanged: (pressed) => setState(() => _isWiFiPressed = pressed),
        ),
      ],
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isPassword = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A3E).withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword,
        style: GoogleFonts.inter(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.inter(
            color: Colors.white.withValues(alpha: 0.6),
            fontSize: 14,
          ),
          prefixIcon: Icon(
            icon,
            color: Colors.white.withValues(alpha: 0.6),
            size: 20,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required String text,
    required VoidCallback onPressed,
    required bool isPressed,
    required Function(bool) onPressChanged,
  }) {
    return GestureDetector(
      onTapDown: (_) {
        HapticFeedback.lightImpact();
        onPressChanged(true);
      },
      onTapUp: (_) => onPressChanged(false),
      onTapCancel: () => onPressChanged(false),
      onTap: onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
        width: double.infinity,
        height: 52,
        decoration: BoxDecoration(
          color: isPressed
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withValues(alpha: isPressed ? 0.6 : 0.3),
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
            text,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }

  void _connectToHotspot() {
    final ssid = hotspotSSIDController.text.trim();

    if (ssid.isEmpty) {
      _showErrorFeedback('Lütfen SSID alanını doldurun.');
      return;
    }

    // Mock başarılı bağlantı
    _showSuccessFeedback(
      'Hotspot\'a Bağlanıldı',
      'Ekranın hotspot\'ına başarıyla bağlanıldı',
    );
  }

  void _connectRPiToWiFi() {
    final ssid = wifiSSIDController.text.trim();

    if (ssid.isEmpty) {
      _showErrorFeedback('Lütfen SSID alanını doldurun.');
      return;
    }

    // Mock başarılı bağlantı
    _showSuccessFeedback(
      'RPi Ağa Bağlandı',
      'Raspberry Pi Wi-Fi ağına başarıyla bağlandı',
    );
  }

  void _showSuccessFeedback(String title, String subtitle) async {
    // Önce vibrasyon, sonra toast için kısa gecikme
    await Future.delayed(const Duration(milliseconds: 100));

    _triggerVibration();

    _showCustomToast(
      icon: Icons.check_circle,
      iconColor: const Color(0xFF38A169),
      title: title,
      subtitle: subtitle,
      backgroundColor: const Color(0xFF1a1a2e).withValues(alpha: 0.95),
    );
  }

  void _showErrorFeedback(String message) async {
    // Önce vibrasyon, sonra toast için kısa gecikme
    await Future.delayed(const Duration(milliseconds: 100));

    _triggerErrorVibration();

    _showCustomToast(
      icon: Icons.error_outline,
      iconColor: const Color(0xFFE53E3E),
      title: 'Hata',
      subtitle: message,
      backgroundColor: const Color(0xFF1a1a2e).withValues(alpha: 0.95),
    );
  }

  // Başarı vibrasyonu (tek titreşim)
  void _triggerVibration() async {
    try {
      final hasVibrator = await Vibration.hasVibrator();
      if (hasVibrator == true) {
        await Vibration.vibrate(duration: 150);
      } else {
        // Vibration desteklenmiyorsa haptic feedback kullan
        HapticFeedback.mediumImpact();
      }
    } catch (e) {
      // Vibration hatası durumunda haptic feedback'e geri dön
      HapticFeedback.mediumImpact();
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
}
