import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vibration/vibration.dart';
import 'dart:ui';
import '../widgets/animated_particles.dart';
import '../widgets/animated_toast.dart';

class ScreenSettingsPage extends StatefulWidget {
  const ScreenSettingsPage({super.key});

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
  OverlayEntry? _activeToastEntry; // Button press state
  bool _isKaydetPressed = false;
  bool _isGuncellePressed = false;

  @override
  void initState() {
    super.initState();
    _loadPresetData();
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

                        // Aksiyon Butonları
                        Row(
                          children: [
                            Expanded(
                              child: _buildActionButton(
                                title: 'KAYDET',
                                color: const Color(0xFF38A169),
                                onTap: _saveSettings,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildActionButton(
                                title: 'EKRANI GÜNCELLE',
                                color: const Color(0xFF3182CE),
                                onTap: _updateScreen,
                              ),
                            ),
                          ],
                        ),

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
    final isKaydet = title.contains('KAYDET');
    final isPressed = isKaydet ? _isKaydetPressed : _isGuncellePressed;

    return GestureDetector(
      onTapDown: (_) {
        setState(() {
          if (isKaydet) {
            _isKaydetPressed = true;
          } else {
            _isGuncellePressed = true;
          }
        });

        // Sadece hafif dokunma feedback'i
        HapticFeedback.selectionClick();
      },
      onTapUp: (_) {
        // Hemen state'i sıfırla
        setState(() {
          if (isKaydet) {
            _isKaydetPressed = false;
          } else {
            _isGuncellePressed = false;
          }
        });

        // Fonksiyonu çağır (içinde titreşim olacak)
        onTap();
      },
      onTapCancel: () {
        setState(() {
          if (isKaydet) {
            _isKaydetPressed = false;
          } else {
            _isGuncellePressed = false;
          }
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
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 100),
            style: GoogleFonts.inter(
              fontSize: isPressed ? 13 : 14,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: isPressed ? 0.95 : 0.8),
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

  void _saveSettings() {
    String width = _widthController.text;
    String height = _heightController.text;

    if (width.isEmpty || height.isEmpty) {
      _showErrorFeedback('Lütfen genişlik ve yükseklik değerlerini girin.');
      return;
    }

    // Burada ayarları kaydetme işlemi yapılacak
    _showSuccessFeedback(
      'Ayarlar Kaydedildi',
      'Ekran ayarları başarıyla kaydedildi',
    );
  }

  void _updateScreen() {
    String width = _widthController.text;
    String height = _heightController.text;

    if (width.isEmpty || height.isEmpty) {
      _showErrorFeedback('Lütfen genişlik ve yükseklik değerlerini girin.');
      return;
    }

    // Burada ekranı güncelleme işlemi yapılacak
    _showSuccessFeedback(
      'Ekran Güncellendi',
      'Pano ekranı başarıyla güncellendi',
    );
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
