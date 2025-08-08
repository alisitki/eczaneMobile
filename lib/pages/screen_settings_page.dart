import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vibration/vibration.dart';
import 'package:http/http.dart' as http;
import 'dart:ui';
import 'dart:convert';
import '../widgets/animated_particles.dart';
import '../widgets/animated_toast.dart';

class ScreenSettingsPage extends StatefulWidget {
  final VoidCallback? onSystemRestart;

  const ScreenSettingsPage({super.key, this.onSystemRestart});

  @override
  State<ScreenSettingsPage> createState() => _ScreenSettingsPageState();
}

class _ScreenSettingsPageState extends State<ScreenSettingsPage> {
  final TextEditingController _widthController = TextEditingController();
  final TextEditingController _heightController = TextEditingController();

  // Yeni state variables
  String? _selectedModel;
  String? _selectedResolution;

  // Preset data
  List<Map<String, dynamic>> _presetData = [];

  // Aktif toast'ları takip etmek için
  OverlayEntry? _activeToastEntry;
  bool _isGuncellePressed = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadPresetData();
    _loadCurrentScreenConfig();
  }

  void _loadPresetData() {
    // JSON data'yı direkt olarak tanımlıyoruz
    _presetData = [
      {
        "model": "P1.86",
        "variants": [
          {"module": "64x160", "width": 344, "height": 860},
          {"module": "64x176", "width": 344, "height": 946},
          {"module": "64x192", "width": 344, "height": 1032},
          {"module": "96x160", "width": 516, "height": 860},
          {"module": "96x176", "width": 516, "height": 946},
          {"module": "96x192", "width": 516, "height": 1032},
        ],
      },
      {
        "model": "P2.5",
        "variants": [
          {"module": "64x160", "width": 256, "height": 640},
          {"module": "64x176", "width": 256, "height": 704},
          {"module": "64x192", "width": 256, "height": 768},
          {"module": "96x160", "width": 384, "height": 640},
          {"module": "96x176", "width": 384, "height": 704},
          {"module": "96x192", "width": 384, "height": 768},
        ],
      },
      {
        "model": "P3.0",
        "variants": [
          {"module": "64x160", "width": 208, "height": 520},
          {"module": "64x176", "width": 208, "height": 572},
          {"module": "64x192", "width": 208, "height": 624},
          {"module": "96x160", "width": 312, "height": 520},
          {"module": "96x176", "width": 312, "height": 572},
          {"module": "96x192", "width": 312, "height": 624},
        ],
      },
    ];
  }

  @override
  void dispose() {
    // Sayfa kapanırken aktif toast'ı kaldır
    _removeActiveToast();
    _widthController.dispose();
    _heightController.dispose();
    super.dispose();
  }

  void _removeActiveToast() {
    if (_activeToastEntry != null) {
      _activeToastEntry!.remove();
      _activeToastEntry = null;
    }
  }

  void _onModelSelected(String? model) {
    setState(() {
      _selectedModel = model;
      _selectedResolution = null; // Reset resolution when model changes
      _widthController.clear();
      _heightController.clear();
    });
  }

  void _onResolutionSelected(String resolution) {
    if (_selectedModel == null) return;

    // Find the corresponding width/height for the selected model and resolution
    final modelData = _presetData.firstWhere(
      (data) => data['model'] == _selectedModel,
    );
    final variant = (modelData['variants'] as List).firstWhere(
      (v) => v['module'] == resolution,
    );

    setState(() {
      _selectedResolution = resolution;
      _widthController.text = variant['width'].toString();
      _heightController.text = variant['height'].toString();
    });
  }

  void _onManualInput() {
    setState(() {
      _selectedModel = null;
      _selectedResolution = null;
    });
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
                          'Ekran Ayarları',
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
                        // Preset Seçimi
                        _buildSectionTitle('Ekran Tipi Seçimi:'),
                        const SizedBox(height: 16),

                        // Model Dropdown
                        _buildModelDropdown(),
                        const SizedBox(height: 16),

                        // Resolution Grid (sadece model seçildiğinde göster)
                        if (_selectedModel != null) ...[
                          _buildResolutionGrid(),
                          const SizedBox(height: 16),
                        ],

                        const SizedBox(height: 32),

                        // Manuel Boyut Girişi
                        _buildSectionTitle('Çözünürlük Ayarı:'),
                        const SizedBox(height: 16),

                        Row(
                          children: [
                            // Genişlik
                            Expanded(
                              child: _buildInputField(
                                controller: _widthController,
                                label: 'Genişlik (px)',
                                onChanged: (value) => _onManualInput(),
                              ),
                            ),
                            const SizedBox(width: 16),
                            // Yükseklik
                            Expanded(
                              child: _buildInputField(
                                controller: _heightController,
                                label: 'Yükseklik (px)',
                                onChanged: (value) => _onManualInput(),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 40),

                        // Aksiyon Butonu (sadece Güncelle)
                        _buildActionButton(
                          title: _isLoading
                              ? 'GÜNCELLENİYOR...'
                              : 'EKRANI GÜNCELLE',
                          color: const Color(0xFF3182CE),
                          onTap: _isLoading ? () {} : _updateScreen,
                        ),

                        const SizedBox(height: 24),

                        // Bilgilendirme Mesajı
                        _buildInfoMessage(),

                        const SizedBox(height: 24),
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
    return Text(
      title,
      style: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      ),
    );
  }

  Widget _buildModelDropdown() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.15),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: DropdownButtonFormField<String>(
            value: _selectedModel,
            hint: Text(
              'Model Seçiniz',
              style: GoogleFonts.inter(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 14,
                letterSpacing: 0.3,
              ),
            ),
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.all(18),
            ),
            dropdownColor: const Color(0xFF1a1a2e),
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            icon: Icon(
              Icons.keyboard_arrow_down_rounded,
              color: Colors.white.withValues(alpha: 0.7),
              size: 24,
            ),
            items: _presetData.map((data) {
              return DropdownMenuItem<String>(
                value: data['model'],
                child: Text(
                  'Model ${data['model']}',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.3,
                  ),
                ),
              );
            }).toList(),
            onChanged: _onModelSelected,
          ),
        ),
      ),
    );
  }

  Widget _buildResolutionGrid() {
    // Tüm unique resolution'ları al (tüm modellerde aynı)
    const resolutions = [
      '64x160',
      '64x176',
      '64x192',
      '96x160',
      '96x176',
      '96x192',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Ekran Ebadı Seçiniz:',
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.white.withValues(alpha: 0.8),
          ),
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 1.2,
          ),
          itemCount: resolutions.length,
          itemBuilder: (context, index) {
            final resolution = resolutions[index];
            return _buildResolutionCard(resolution);
          },
        ),
      ],
    );
  }

  Widget _buildResolutionCard(String resolution) {
    bool isSelected = _selectedResolution == resolution;

    return GestureDetector(
      onTap: () => _onResolutionSelected(resolution),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: isSelected
                  ? Colors.white.withValues(alpha: 0.15)
                  : Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected
                    ? const Color(0xFF60A5FA).withValues(alpha: 0.6)
                    : Colors.white.withValues(alpha: 0.15),
                width: isSelected ? 2 : 1,
              ),
              boxShadow: [
                if (isSelected) ...[
                  // Neon glow for selected state
                  BoxShadow(
                    color: const Color(0xFF60A5FA).withValues(alpha: 0.3),
                    blurRadius: 12,
                    spreadRadius: 0,
                  ),
                ],
                // Subtle depth shadow
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _onResolutionSelected(resolution),
                borderRadius: BorderRadius.circular(14),
                splashColor: Colors.white.withValues(alpha: 0.1),
                child: Container(
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        resolution,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          letterSpacing: 0.3,
                        ),
                      ),
                      if (isSelected) ...[
                        const SizedBox(height: 4),
                        Icon(
                          Icons.check_circle_rounded,
                          color: const Color(0xFF60A5FA),
                          size: 18,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required Function(String) onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        // Soft neumorphic effect
        color: const Color(0xFF1a1a2e),
        boxShadow: [
          // Top-left shadow (darker)
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 8,
            offset: const Offset(-4, -4),
          ),
          // Bottom-right shadow (lighter)
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(4, 4),
          ),
        ],
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.05),
          width: 1,
        ),
      ),
      child: Container(
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: const Color(0xFF1a1a2e),
        ),
        child: TextField(
          controller: controller,
          onChanged: onChanged,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.3,
          ),
          decoration: InputDecoration(
            labelText: label,
            labelStyle: GoogleFonts.inter(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 12,
              fontWeight: FontWeight.w400,
              letterSpacing: 0.3,
            ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.all(18),
            focusedBorder: InputBorder.none,
            enabledBorder: InputBorder.none,
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    final isPressed = _isGuncellePressed;

    return GestureDetector(
      onTapDown: (_) {
        setState(() {
          _isGuncellePressed = true;
        });

        // Sadece hafif dokunma feedback'i
        HapticFeedback.selectionClick();
      },
      onTapUp: (_) {
        // Hemen state'i sıfırla
        setState(() {
          _isGuncellePressed = false;
        });

        // Fonksiyonu çağır (içinde titreşim olacak)
        onTap();
      },
      onTapCancel: () {
        setState(() {
          _isGuncellePressed = false;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeInOut,
        height: isPressed ? 50 : 52,
        transform: Matrix4.identity()..scale(isPressed ? 0.96 : 1.0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: isPressed
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.transparent,
          border: Border.all(
            color: Colors.white.withValues(alpha: isPressed ? 0.9 : 0.7),
            width: isPressed ? 2.5 : 2,
          ),
          boxShadow: [
            if (isPressed) ...[
              BoxShadow(
                color: Colors.white.withValues(alpha: 0.2),
                blurRadius: 8,
                spreadRadius: 0,
              ),
            ] else ...[
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ],
        ),
        child: Container(
          alignment: Alignment.center,
          child: _isLoading
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                    const SizedBox(width: 8),
                    AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 100),
                      style: GoogleFonts.inter(
                        fontSize: isPressed ? 13 : 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(
                          alpha: isPressed ? 0.95 : 0.8,
                        ),
                        letterSpacing: 0.5,
                      ),
                      child: Text(title),
                    ),
                  ],
                )
              : AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 100),
                  style: GoogleFonts.inter(
                    fontSize: isPressed ? 13 : 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(
                      alpha: isPressed ? 0.95 : 0.8,
                    ),
                    letterSpacing: 0.5,
                  ),
                  child: Text(title),
                ),
        ),
      ),
    );
  }

  // Güçlü telefon titreşimi (başarı için)
  Future<void> _triggerVibration() async {
    try {
      final hasVibrator = await Vibration.hasVibrator();
      if (hasVibrator == true) {
        // Başarı: tek güçlü ama kısa titreşim (150ms)
        await Vibration.vibrate(duration: 150);
      } else {
        HapticFeedback.heavyImpact();
      }
    } catch (e) {
      HapticFeedback.heavyImpact();
    }
  }

  // Hata titreşimi (iki kısa titreşim)
  Future<void> _triggerErrorVibration() async {
    try {
      final hasVibrator = await Vibration.hasVibrator();
      if (hasVibrator == true) {
        // Hata: pattern ile iki kısa titreşim (daha güvenilir)
        // Pattern: [bekleme, titreşim, bekleme, titreşim]
        await Vibration.vibrate(
          pattern: [
            0,
            100,
            100,
            100,
          ], // 0ms bekle, 100ms titret, 100ms bekle, 100ms titret
        );
      } else {
        // Fallback: iki kısa haptic
        HapticFeedback.lightImpact();
        await Future.delayed(const Duration(milliseconds: 150));
        HapticFeedback.lightImpact();
      }
    } catch (e) {
      HapticFeedback.lightImpact();
      await Future.delayed(const Duration(milliseconds: 150));
      HapticFeedback.lightImpact();
    }
  }

  // API: Mevcut ekran ayarlarını yükle
  Future<void> _loadCurrentScreenConfig() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await http
          .get(
            Uri.parse('http://192.168.4.1:3000/api/mobile/config/screen'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['screen'] != null) {
          setState(() {
            _widthController.text = data['screen']['width'].toString();
            _heightController.text = data['screen']['height'].toString();
          });
          debugPrint('Screen config loaded: ${data['screen']}');
        } else {
          _showErrorFeedback('Ekran ayarları alınamadı');
        }
      } else {
        _showErrorFeedback('Bağlantı hatası: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Load screen config error: $e');
      _showErrorFeedback('Nöbetix panoya bağlantı kurulamadı');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // API: Ekran ayarlarını güncelle
  Future<void> _updateScreenConfig(int width, int height) async {
    setState(() {
      _isLoading = true;
    });

    // PUT request'i gönder (sonucu önemli değil)
    try {
      final response = await http
          .put(
            Uri.parse('http://192.168.4.1:3000/api/mobile/config/screen'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({'width': width, 'height': height}),
          )
          .timeout(const Duration(seconds: 5));

      debugPrint('PUT response status: ${response.statusCode}');
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        debugPrint('PUT response data: $data');
      }
    } catch (e) {
      debugPrint('PUT request error (normal): $e');
    }

    // PUT başarılı olsun ya da olmasın, sistem restart kontrolüne geç
    debugPrint('Starting system restart sequence...');

    // ConnectionService'i durdur (home page'de)
    widget.onSystemRestart?.call();

    // Başarılı mesajı göster
    _showSuccessFeedback(
      'Sistem Yeniden Başlatılıyor',
      'Ayarlar uygulanıyor, lütfen bekleyin...',
    );

    // Sistem restart kontrolü - hem hotspot hem WiFi kontrol et
    // Loading'i burada kapatmayacağız, _waitForSystemRestart içinde kapatılacak
    await _waitForSystemRestart();
  }

  // Sistem restart kontrolü - hem hotspot hem WiFi kontrol et
  Future<void> _waitForSystemRestart() async {
    debugPrint('Waiting for system restart...');

    // Toast mesajını göster ve 15 saniye boyunca tut
    _showCustomToast(
      icon: Icons.sync,
      iconColor: const Color(0xFF3182CE),
      title: 'Sistem Başlatılıyor',
      subtitle: 'Sistem yeniden başlatılıyor...',
      backgroundColor: const Color(0xFF1a1a2e).withValues(alpha: 0.95),
      autoHide: false, // Otomatik kapanmasın
    );

    // İlk 15 saniye bekle - sistem restart olması için
    debugPrint('Waiting 15 seconds for system to restart...');
    await Future.delayed(const Duration(seconds: 15));

    // Toast mesajını güncelle ve kontroller bitene kadar tut
    _showCustomToast(
      icon: Icons.sync,
      iconColor: const Color(0xFF3182CE),
      title: 'Sistem Başlatılıyor',
      subtitle: 'Bağlantı kontrol ediliyor...',
      backgroundColor: const Color(0xFF1a1a2e).withValues(alpha: 0.95),
      autoHide: false, // Otomatik kapanmasın
    );

    const maxAttempts = 30; // 30 * 2 saniye = 60 saniye max
    int attempts = 0;

    while (attempts < maxAttempts) {
      if (!mounted) return;

      attempts++;
      debugPrint('System restart check attempt: $attempts/$maxAttempts');

      // Hem hotspot hem WiFi kontrol et
      bool isSystemReady = await _checkSystemAvailability();

      if (isSystemReady) {
        debugPrint('System is ready! Returning to home page.');

        // Başarı mesajını göster ve 3 saniye tut
        _showCustomToast(
          icon: Icons.check_circle,
          iconColor: const Color(0xFF38A169),
          title: 'Sistem Hazır',
          subtitle: 'Ana sayfaya dönülüyor...',
          backgroundColor: const Color(0xFF1a1a2e).withValues(alpha: 0.95),
          autoHide: false, // Manuel kontrol
        );

        // 3 saniye bekle, sonra ana sayfaya dön
        await Future.delayed(const Duration(seconds: 3));
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          // Toast'ı temizle
          _removeActiveToast();
          Navigator.pop(context);
        }
        return;
      }

      // Her denemede toast'ı güncelle
      if (mounted) {
        _showCustomToast(
          icon: Icons.sync,
          iconColor: const Color(0xFF3182CE),
          title: 'Sistem Başlatılıyor',
          subtitle: 'Bağlantı kontrol ediliyor... ($attempts/$maxAttempts)',
          backgroundColor: const Color(0xFF1a1a2e).withValues(alpha: 0.95),
          autoHide: false, // Otomatik kapanmasın
        );
      }

      // 2 saniye bekle ve tekrar dene
      await Future.delayed(const Duration(seconds: 2));
    }

    // Timeout durumu - hata mesajını göster ve 5 saniye tut
    debugPrint('System restart timeout after ${maxAttempts * 2} seconds');
    _showCustomToast(
      icon: Icons.error_outline,
      iconColor: const Color(0xFFE53E3E),
      title: 'Zaman Aşımı',
      subtitle: 'Sistem başlatma zaman aşımı. Ana sayfaya dönülüyor...',
      backgroundColor: const Color(0xFF1a1a2e).withValues(alpha: 0.95),
      autoHide: false, // Manuel kontrol
    );

    // 5 saniye bekle ve ana sayfaya dön
    await Future.delayed(const Duration(seconds: 5));
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
      // Toast'ı temizle
      _removeActiveToast();
      Navigator.pop(context);
    }
  }

  // Sistem hazır olup olmadığını kontrol et (hem hotspot hem WiFi)
  Future<bool> _checkSystemAvailability() async {
    try {
      // Önce hotspot kontrol et
      final hotspotResponse = await http
          .get(
            Uri.parse('http://192.168.4.1:3000/api/mobile/check'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(const Duration(seconds: 3));

      if (hotspotResponse.statusCode == 200) {
        debugPrint('System available via hotspot');
        return true;
      }
    } catch (e) {
      debugPrint('Hotspot check failed: $e');
    }

    try {
      // WiFi ile kontrol et (mDNS ile çözümlenmiş IP veya varsayılan)
      // ConnectionService'teki gibi mDNS resolution yapabiliriz
      final wifiResponse = await http
          .get(
            Uri.parse('http://raspberrypi.local:3000/api/mobile/check'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(const Duration(seconds: 3));

      if (wifiResponse.statusCode == 200) {
        debugPrint('System available via WiFi');
        return true;
      }
    } catch (e) {
      debugPrint('WiFi check failed: $e');
    }

    debugPrint('System not available yet');
    return false;
  }

  void _updateScreen() {
    String widthStr = _widthController.text.trim();
    String heightStr = _heightController.text.trim();

    if (widthStr.isEmpty || heightStr.isEmpty) {
      _showErrorFeedback('Lütfen genişlik ve yükseklik değerlerini girin.');
      return;
    }

    int? width = int.tryParse(widthStr);
    int? height = int.tryParse(heightStr);

    if (width == null || height == null) {
      _showErrorFeedback('Lütfen geçerli sayı değerleri girin.');
      return;
    }

    if (width < 100 || width > 1032 || height < 208 || height > 1032) {
      _showErrorFeedback(
        'Genişlik 100-1032, yükseklik 208-1032 arasında olmalıdır.',
      );
      return;
    }

    // API çağrısını yap
    _updateScreenConfig(width, height);
  }

  void _showSuccessFeedback(String title, String subtitle) {
    // Başarı titreşimi (fire-and-forget)
    _triggerVibration().catchError((_) {});

    // Toast'ı biraz geciktir (error ile aynı timing)
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        _showCustomToast(
          icon: Icons.check_circle,
          iconColor: const Color(0xFF38A169),
          title: title,
          subtitle: subtitle,
          backgroundColor: const Color(0xFF1a1a2e).withValues(alpha: 0.95),
          autoHide: false, // Otomatik kapanmasın
        );
      }
    });
  }

  void _showErrorFeedback(String message) {
    // Hata titreşimi (fire-and-forget)
    _triggerErrorVibration().catchError((_) {});

    // Toast'ı biraz geciktir (success ile aynı timing)
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        _showCustomToast(
          icon: Icons.error_outline,
          iconColor: const Color(0xFFE53E3E),
          title: 'Hata',
          subtitle: message,
          backgroundColor: const Color(0xFF1a1a2e).withValues(alpha: 0.95),
        );
      }
    });
  }

  void _showCustomToast({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required Color backgroundColor,
    bool autoHide = true, // Yeni parametre
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
              color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.settings_suggest,
              color: Color(0xFFF59E0B),
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Üretici Ayarı',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFFF59E0B),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Bu ekran çözünürlük ayarları genellikle üretici tarafından önceden yapılandırılmıştır. Normal kullanımda değiştirilmesi gerekmez. '
                  'Eğer manuel ayarlama yapmak istiyorsanız, geçerli değer aralıkları: Genişlik 100-1032px, Yükseklik 208-1032px\'dir. '
                  'Hatalı değerler ekranda görüntü problemlerine neden olabilir.',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: Colors.white.withValues(alpha: 0.8),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
