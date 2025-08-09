import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vibration/vibration.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../widgets/animated_particles.dart';
import '../widgets/animated_toast.dart';
import '../services/connection_service.dart';

class WifiSettingsPage extends StatefulWidget {
  const WifiSettingsPage({super.key});

  @override
  State<WifiSettingsPage> createState() => _WifiSettingsPageState();
}

class _WifiSettingsPageState extends State<WifiSettingsPage> {
  // Form controllers
  final TextEditingController wifiSSIDController = TextEditingController();
  final TextEditingController wifiPasswordController = TextEditingController();
  final ConnectionService _connectionService = ConnectionService();

  // Aktif toast'ları takip etmek için
  OverlayEntry? _activeToastEntry;

  // Button press states
  bool _isWiFiPressed = false;
  bool _isLoading = false;
  bool _isPasswordVisible = false; // Şifre görünürlük kontrolü

  @override
  void initState() {
    super.initState();
    _loadCurrentNetworkConfig();
  }

  @override
  void dispose() {
    // Sayfa kapanırken aktif toast'ı kaldır
    _removeActiveToast();
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

  // Bağlantı türüne göre API base URL'ini döndüren helper method
  Future<String> _getApiBaseUrl() async {
    try {
      await _connectionService.checkConnection();
    } catch (e) {
      debugPrint('Connection check failed in wifi settings: $e');
    }

    final connectionStatus = _connectionService.currentStatus;

    switch (connectionStatus.type) {
      case ConnectionType.wifi:
        final cachedIP = _connectionService.getCachedHostnameIP(
          'raspberrypi.local',
        );
        if (cachedIP != null && cachedIP.isNotEmpty) {
          return 'http://$cachedIP:3000';
        }
        return 'http://raspberrypi.local:3000';

      case ConnectionType.hotspot:
      case ConnectionType.none:
        return 'http://192.168.4.1:3000';
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
          text: _isLoading ? 'GÜNCELLENİYOR...' : 'NÖBETİX EKRAN\'I AĞA BAĞLA',
          onPressed: _isLoading ? () {} : _connectRPiToWiFi,
          isPressed: _isWiFiPressed,
          onPressChanged: (pressed) => setState(() => _isWiFiPressed = pressed),
        ),

        const SizedBox(height: 24),

        _buildInfoMessage(),
      ],
    );
  }

  Widget _buildInfoMessage() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A3E).withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF3182CE).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.info_outline,
              color: Color(0xFF3182CE),
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              'Nöbetix Ekran Sistemi\'nin düzgün çalışabilmesi için internet bağlantısına ihtiyaç vardır. Lütfen yukarıdaki alanlara modeminizin ağ adını (SSID) ve şifresini girerek Nöbetix Ekran\'ın internet ağınıza bağlanmasını sağlayın.',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: Colors.white.withValues(alpha: 0.8),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
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
        obscureText: isPassword && !_isPasswordVisible,
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
          suffixIcon: isPassword
              ? IconButton(
                  icon: Icon(
                    _isPasswordVisible
                        ? Icons.visibility_off
                        : Icons.visibility,
                    color: Colors.white.withValues(alpha: 0.6),
                    size: 20,
                  ),
                  onPressed: () {
                    setState(() {
                      _isPasswordVisible = !_isPasswordVisible;
                    });
                  },
                )
              : null,
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

  // API: Mevcut network ayarlarını yükle
  Future<void> _loadCurrentNetworkConfig() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final baseUrl = await _getApiBaseUrl();
      final response = await http
          .get(
            Uri.parse('$baseUrl/api/mobile/config/network'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(const Duration(seconds: 10));

      debugPrint('GET network config response status: ${response.statusCode}');
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        debugPrint('GET network config response data: $data');

        if (data['success'] == true && data['network'] != null) {
          final network = data['network'];
          setState(() {
            wifiSSIDController.text = network['ssid'] ?? '';
            wifiPasswordController.text = network['password'] ?? '';
          });
          debugPrint('Network config loaded: SSID=${network['ssid']}');
        }
      }
    } catch (e) {
      debugPrint('Network config load error: $e');
      // Hata durumunda kullanıcıya bilgi vermeyeceğiz, sessizce devam ederiz
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // API: Network ayarlarını güncelle
  Future<void> _updateNetworkConfig(String ssid, String password) async {
    setState(() {
      _isLoading = true;
    });

    // PUT request'i gönder
    try {
      final baseUrl = await _getApiBaseUrl();
      final response = await http
          .put(
            Uri.parse('$baseUrl/api/mobile/config/network'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({'ssid': ssid, 'password': password}),
          )
          .timeout(const Duration(seconds: 5));

      debugPrint('PUT network config response status: ${response.statusCode}');
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        debugPrint('PUT network config response data: $data');

        // Başarılı mesajı göster
        _showSuccessFeedback(
          'WiFi Ayarları Güncellendi',
          'Ayarlar başarıyla kaydedildi',
        );

        // Loading'i kapat
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
        return;
      } else {
        _showErrorFeedback('WiFi ayarları güncellenemedi');
      }
    } catch (e) {
      debugPrint('PUT network config request error: $e');
      _showErrorFeedback('Nöbetix panoya bağlantı kurulamadı');
    }

    // Loading'i kapat
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _connectRPiToWiFi() {
    final ssid = wifiSSIDController.text.trim();
    final password = wifiPasswordController.text.trim();

    // Validation
    if (ssid.isEmpty) {
      _showErrorFeedback('Lütfen SSID alanını doldurun.');
      return;
    }

    if (password.length < 8) {
      _showErrorFeedback('WiFi şifresi en az 8 karakter olmalıdır.');
      return;
    }

    // API çağrısını yap
    _updateNetworkConfig(ssid, password);
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
    bool autoHide = true, // Yeni parametre ekle
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
        autoHide: autoHide, // Parametre geç
        onDismiss: () {
          _removeActiveToast();
        },
      ),
    );

    overlay.insert(_activeToastEntry!);
  }
}
