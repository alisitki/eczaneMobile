import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vibration/vibration.dart';
import '../widgets/animated_particles.dart';
import '../widgets/animated_toast.dart';

class PharmacySettingsPage extends StatefulWidget {
  const PharmacySettingsPage({super.key});

  @override
  State<PharmacySettingsPage> createState() => _PharmacySettingsPageState();
}

class _PharmacySettingsPageState extends State<PharmacySettingsPage> {
  String? selectedCity;
  String? selectedDistrict;
  TimeOfDay startTime = const TimeOfDay(hour: 19, minute: 0);
  TimeOfDay endTime = const TimeOfDay(hour: 8, minute: 0);
  bool saturdayDuty = false;
  bool sundayDuty = false;
  bool todayIsMyDuty = false;

  // Aktif toast'ları takip etmek için
  OverlayEntry? _activeToastEntry;

  // Button press state
  bool _isKaydetPressed = false;
  bool _isGuncellePressed = false;

  @override
  void dispose() {
    // Sayfa kapanırken aktif toast'ı kaldır
    _removeActiveToast();
    super.dispose();
  }

  void _removeActiveToast() {
    if (_activeToastEntry != null) {
      _activeToastEntry!.remove();
      _activeToastEntry = null;
    }
  }

  // Mock data - gerçek JSON'dan gelecek
  final List<String> cities = [
    'İstanbul',
    'Ankara',
    'İzmir',
    'Bursa',
    'Antalya',
    'Adana',
  ];

  final Map<String, List<String>> districts = {
    'İstanbul': ['Kadıköy', 'Beşiktaş', 'Şişli', 'Bakırköy'],
    'Ankara': ['Çankaya', 'Keçiören', 'Mamak', 'Etimesgut'],
    'İzmir': ['Konak', 'Karşıyaka', 'Bornova', 'Buca'],
  };

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
                          'Nöbetçi Eczane Ayarları',
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
                        // İl Seç
                        _buildSectionTitle('İl Seç:'),
                        _buildDropdown(
                          value: selectedCity,
                          items: cities,
                          hint: 'İl seçiniz...',
                          onChanged: (value) {
                            setState(() {
                              selectedCity = value;
                              selectedDistrict =
                                  null; // İl değişince ilçeyi sıfırla
                            });
                          },
                        ),

                        const SizedBox(height: 24),

                        // İlçe Seç
                        _buildSectionTitle('İlçe Seç:'),
                        _buildDropdown(
                          value: selectedDistrict,
                          items: selectedCity != null
                              ? (districts[selectedCity!] ?? [])
                              : [],
                          hint: 'İlçe seçiniz...',
                          onChanged: (value) {
                            setState(() {
                              selectedDistrict = value;
                            });
                          },
                          enabled: selectedCity != null,
                        ),

                        const SizedBox(height: 32),

                        // Nöbet Saatleri
                        _buildSectionTitle('Nöbet Başlangıç Saati:'),
                        _buildTimeSelector(
                          time: startTime,
                          onTap: () => _selectTime(context, true),
                        ),

                        const SizedBox(height: 20),

                        _buildSectionTitle('Nöbet Bitiş Saati:'),
                        _buildTimeSelector(
                          time: endTime,
                          onTap: () => _selectTime(context, false),
                        ),

                        const SizedBox(height: 32),

                        // Hafta sonu nöbetleri
                        _buildCheckboxTile(
                          title: 'Cumartesi Nöbeti',
                          value: saturdayDuty,
                          onChanged: (value) {
                            setState(() {
                              saturdayDuty = value!;
                            });
                          },
                        ),

                        const SizedBox(height: 16),

                        _buildCheckboxTile(
                          title: 'Pazar Nöbeti',
                          value: sundayDuty,
                          onChanged: (value) {
                            setState(() {
                              sundayDuty = value!;
                            });
                          },
                        ),

                        const SizedBox(height: 32),

                        // Bugün nöbetçi
                        _buildCheckboxTile(
                          title: 'Bugün Nöbetçi Benim',
                          value: todayIsMyDuty,
                          onChanged: (value) {
                            setState(() {
                              todayIsMyDuty = value!;
                            });
                          },
                        ),

                        const SizedBox(height: 40),

                        // Butonlar
                        Row(
                          children: [
                            Expanded(
                              child: _buildActionButton(
                                text: 'KAYDET',
                                onPressed: _saveSettings,
                                isPressed: _isKaydetPressed,
                                onPressChanged: (pressed) =>
                                    setState(() => _isKaydetPressed = pressed),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildActionButton(
                                text: 'EKRANI\nGÜNCELLE',
                                onPressed: _updateScreen,
                                isPressed: _isGuncellePressed,
                                onPressChanged: (pressed) => setState(
                                  () => _isGuncellePressed = pressed,
                                ),
                              ),
                            ),
                          ],
                        ),

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
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildDropdown({
    required String? value,
    required List<String> items,
    required String hint,
    required Function(String?) onChanged,
    bool enabled = true,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A3E).withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          hint: Text(
            hint,
            style: GoogleFonts.inter(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 14,
            ),
          ),
          isExpanded: true,
          icon: Icon(
            Icons.keyboard_arrow_down,
            color: enabled ? Colors.white : Colors.white.withValues(alpha: 0.3),
          ),
          dropdownColor: const Color(0xFF2A2A3E),
          style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
          items: enabled
              ? items.map((String item) {
                  return DropdownMenuItem<String>(
                    value: item,
                    child: Text(item),
                  );
                }).toList()
              : null,
          onChanged: enabled ? onChanged : null,
        ),
      ),
    );
  }

  Widget _buildTimeSelector({
    required TimeOfDay time,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF2A2A3E).withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Saat
            Container(
              width: 60,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF1a1a2e),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
              child: Center(
                child: Text(
                  time.hour.toString().padLeft(2, '0'),
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),

            const SizedBox(width: 12),

            Text(
              ':',
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),

            const SizedBox(width: 12),

            // Dakika
            Container(
              width: 60,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF1a1a2e),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
              child: Center(
                child: Text(
                  time.minute.toString().padLeft(2, '0'),
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCheckboxTile({
    required String title,
    required bool value,
    required Function(bool?) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A3E).withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
          ),
          Checkbox(
            value: value,
            onChanged: onChanged,
            fillColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return const Color(0xFF38A169);
              }
              return Colors.transparent;
            }),
            checkColor: Colors.white,
            side: BorderSide(
              color: Colors.white.withValues(alpha: 0.3),
              width: 2,
            ),
          ),
        ],
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

  Future<void> _selectTime(BuildContext context, bool isStartTime) async {
    final currentTime = isStartTime ? startTime : endTime;
    int selectedHour = currentTime.hour;
    int selectedMinute = currentTime.minute;

    final result = await showDialog<TimeOfDay>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2A2A3E),
          title: Text(
            isStartTime ? 'Nöbet Başlangıç Saati' : 'Nöbet Bitiş Saati',
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          content: SizedBox(
            height: 200,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Saat seçici
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        'Saat',
                        style: GoogleFonts.inter(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: CupertinoPicker(
                          backgroundColor: Colors.transparent,
                          itemExtent: 40,
                          scrollController: FixedExtentScrollController(
                            initialItem: selectedHour,
                          ),
                          onSelectedItemChanged: (int index) {
                            selectedHour = index;
                          },
                          children: List.generate(24, (index) {
                            return Center(
                              child: Text(
                                index.toString().padLeft(2, '0'),
                                style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            );
                          }),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 20),

                // İki nokta ayırıcı
                Padding(
                  padding: const EdgeInsets.only(top: 24),
                  child: Text(
                    ':',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),

                const SizedBox(width: 20),

                // Dakika seçici
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        'Dakika',
                        style: GoogleFonts.inter(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: CupertinoPicker(
                          backgroundColor: Colors.transparent,
                          itemExtent: 40,
                          scrollController: FixedExtentScrollController(
                            initialItem: selectedMinute,
                          ),
                          onSelectedItemChanged: (int index) {
                            selectedMinute = index;
                          },
                          children: List.generate(60, (index) {
                            return Center(
                              child: Text(
                                index.toString().padLeft(2, '0'),
                                style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            );
                          }),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'İptal',
                style: GoogleFonts.inter(
                  color: Colors.white.withValues(alpha: 0.7),
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(
                  context,
                ).pop(TimeOfDay(hour: selectedHour, minute: selectedMinute));
              },
              child: Text(
                'Tamam',
                style: GoogleFonts.inter(
                  color: const Color(0xFF38A169),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (result != null) {
      setState(() {
        if (isStartTime) {
          startTime = result;
        } else {
          endTime = result;
        }
      });
    }
  }

  void _saveSettings() {
    if (selectedCity == null || selectedDistrict == null) {
      _showErrorFeedback('Lütfen il ve ilçe seçimi yapın.');
      return;
    }

    // Burada ayarları kaydetme işlemi yapılacak
    _showSuccessFeedback(
      'Ayarlar Kaydedildi',
      'Nöbetçi eczane ayarları başarıyla kaydedildi',
    );
  }

  void _updateScreen() {
    if (selectedCity == null || selectedDistrict == null) {
      _showErrorFeedback('Lütfen il ve ilçe seçimi yapın.');
      return;
    }

    // Burada ekranı güncelleme işlemi yapılacak
    _showSuccessFeedback(
      'Ekran Güncellendi',
      'Pano ekranı başarıyla güncellendi',
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
