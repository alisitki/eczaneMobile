import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vibration/vibration.dart';
import 'dart:convert';
// import 'dart:io';
import 'package:http/http.dart' as http;
import '../widgets/animated_particles.dart';
import '../widgets/animated_toast.dart';
import '../services/connection_service.dart';

class PharmacySettingsPage extends StatefulWidget {
  const PharmacySettingsPage({super.key});

  @override
  State<PharmacySettingsPage> createState() => _PharmacySettingsPageState();
}

class _PharmacySettingsPageState extends State<PharmacySettingsPage> {
  final ConnectionService _connectionService = ConnectionService();
  String? selectedCity;
  String? selectedDistrict;
  TimeOfDay startTime = const TimeOfDay(hour: 19, minute: 0);
  TimeOfDay endTime = const TimeOfDay(hour: 8, minute: 0);
  bool saturdayDuty = false;
  bool sundayDuty = false;

  // Aktif toast'ları takip etmek için
  OverlayEntry? _activeToastEntry;

  // Button press state
  bool _isGuncellePressed = false;

  // JSON verilerinden yüklenecek listeler
  List<Map<String, String>> cityList = [];
  List<Map<String, String>> districtList = [];
  List<String> cities = [];
  Map<String, List<String>> districts = {};

  // API loading states
  bool _isSavingConfig = false;
  bool _isMarkingToday = false;
  bool _isTodayButtonPressed = false;
  bool _isUnmarkingToday = false;
  bool _isTodayOffButtonPressed = false;
  bool _isConfigLoading = false;

  // Türkçe alfabetik sıralama için
  String _turkishSort(String text) {
    return text
        .toLowerCase()
        .replaceAll('ç', 'c_')
        .replaceAll('ğ', 'g_')
        .replaceAll('ı', 'i_')
        .replaceAll('ö', 'o_')
        .replaceAll('ş', 's_')
        .replaceAll('ü', 'u_');
  }

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

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

  Future<void> _initializeData() async {
    // Şehir/ilçe + konfigürasyon yükleme boyunca overlay göstermek için
    if (mounted) setState(() => _isConfigLoading = true);
    try {
      // Önce şehir/ilçe listelerini yükle, ardından backend config'i çek
      await _loadCitiesAndDistricts();
      // ConnectionService'in ilk durumunu hazırlamak için küçük bir gecikme
      await Future.delayed(const Duration(milliseconds: 200));
      if (!mounted) return;
      await _loadCurrentNobetciConfig();
    } finally {
      if (mounted) setState(() => _isConfigLoading = false);
    }
  }

  Future<String> _getApiBaseUrl() async {
    const hostname = 'raspberrypi.local';
    // Güncel bağlantıyı kontrol et
    try {
      await _connectionService.checkConnection();
    } catch (_) {
      // sessiz geç
    }

    final status = _connectionService.currentStatus;

    if (status.type == ConnectionType.wifi) {
      // Önce cache'lenmiş/resolved IP'yi dene
      final cached = _connectionService.getCachedHostnameIP(hostname);
      if (cached != null && cached.isNotEmpty) {
        return 'http://$cached:3000';
      }
      // Hostname fallback
      return 'http://$hostname:3000';
    }

    // Hotspot ya da none: sabit IP
    return 'http://192.168.4.1:3000';
  }

  // JSON dosyalarından il ve ilçe verilerini yükle
  Future<void> _loadCitiesAndDistricts() async {
    try {
      // İl verilerini yükle
      final cityJsonString = await rootBundle.loadString('il.json');
      final List<dynamic> cityJsonData = json.decode(cityJsonString);

      cityList = cityJsonData
          .map(
            (item) => {
              'id': item['id'].toString(),
              'name': item['name'].toString(),
            },
          )
          .toList();

      // İl listesini Türkçe alfabetik sıraya koy
      cityList.sort(
        (a, b) => _turkishSort(a['name']!).compareTo(_turkishSort(b['name']!)),
      );
      cities = cityList.map((city) => city['name']!).toList();

      // İlçe verilerini yükle
      final districtJsonString = await rootBundle.loadString('ilce.json');
      final List<dynamic> districtJsonData = json.decode(districtJsonString);

      districtList = districtJsonData
          .map(
            (item) => {
              'id': item['id'].toString(),
              'il_id': item['il_id'].toString(),
              'name': item['name'].toString(),
            },
          )
          .toList();

      // İlçeleri il ID'sine göre grupla
      districts = {};
      for (var city in cityList) {
        String cityId = city['id']!;
        String cityName = city['name']!;

        List<String> cityDistricts = districtList
            .where((district) => district['il_id'] == cityId)
            .map((district) => district['name']!)
            .toList();

        // İlçeleri Türkçe alfabetik sıraya koy
        cityDistricts.sort(
          (a, b) => _turkishSort(a).compareTo(_turkishSort(b)),
        );
        districts[cityName] = cityDistricts;
      }

      setState(() {});
    } catch (e) {
      // Hata durumunda varsayılan veri kullan
      _loadDefaultData();
    }
  }

  // Varsayılan veri yükleme (fallback)
  void _loadDefaultData() {
    cities = ['İstanbul', 'Ankara', 'İzmir', 'Bursa', 'Antalya', 'Adana'];

    districts = {
      'İstanbul': ['Kadıköy', 'Beşiktaş', 'Şişli', 'Bakırköy'],
      'Ankara': ['Çankaya', 'Keçiören', 'Mamak', 'Etimesgut'],
      'İzmir': ['Konak', 'Karşıyaka', 'Bornova', 'Buca'],
    };

    setState(() {});
  }

  // Mevcut nöbetçi eczane ayarlarını yükle
  Future<void> _loadCurrentNobetciConfig() async {
    try {
      final baseUrl = await _getApiBaseUrl();
      const path = '/api/mobile/config/nobetci';
      final url = '$baseUrl$path';
      final response = await http
          .get(Uri.parse(url), headers: {'Content-Type': 'application/json'})
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['nobetci'] != null) {
          final config = data['nobetci'];

          setState(() {
            selectedCity = config['il']?.toString();
            selectedDistrict = config['ilce']?.toString();

            // İl dropdown'da var mı kontrol et (case-insensitive)
            if (selectedCity != null) {
              final cityMatch = cities.firstWhere(
                (city) => city.toLowerCase() == selectedCity!.toLowerCase(),
                orElse: () => '',
              );
              selectedCity = cityMatch.isEmpty ? null : cityMatch;
            }

            // İlçe dropdown'da var mı kontrol et (case-insensitive)
            if (selectedDistrict != null && selectedCity != null) {
              final cityDistricts = districts[selectedCity!] ?? [];
              final districtMatch = cityDistricts.firstWhere(
                (district) =>
                    district.toLowerCase() == selectedDistrict!.toLowerCase(),
                orElse: () => '',
              );
              selectedDistrict = districtMatch.isEmpty ? null : districtMatch;
            }

            // Saat formatını parse et (HH:mm)
            if (config['dutyStart'] != null) {
              final startParts = config['dutyStart'].toString().split(':');
              if (startParts.length == 2) {
                startTime = TimeOfDay(
                  hour: int.parse(startParts[0]),
                  minute: int.parse(startParts[1]),
                );
              }
            }

            if (config['dutyEnd'] != null) {
              final endParts = config['dutyEnd'].toString().split(':');
              if (endParts.length == 2) {
                endTime = TimeOfDay(
                  hour: int.parse(endParts[0]),
                  minute: int.parse(endParts[1]),
                );
              }
            }

            saturdayDuty = config['saturdayDuty'] == true;
            sundayDuty = config['sundayDuty'] == true;
          });
        }
      }
    } catch (e) {
      // Hata durumunda sessizce devam et
    }
  }

  // Nöbetçi eczane ayarlarını güncelle
  Future<void> _updateNobetciConfig() async {
    if (selectedCity == null || selectedDistrict == null) {
      _showErrorFeedback('Lütfen il ve ilçe seçimi yapın.');
      return;
    }

    setState(() => _isSavingConfig = true);

    try {
      final baseUrl = await _getApiBaseUrl();
      const path = '/api/mobile/config/nobetci';
      final url = '$baseUrl$path';

      final requestData = {
        'il': selectedCity,
        'ilce': selectedDistrict,
        'dutyStart':
            '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}',
        'dutyEnd':
            '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}',
        'saturdayDuty': saturdayDuty,
        'sundayDuty': sundayDuty,
      };

      final response = await http
          .put(
            Uri.parse(url),
            headers: {'Content-Type': 'application/json'},
            body: json.encode(requestData),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          _showSuccessFeedback(
            'Ayarlar Kaydedildi',
            'Nöbetçi eczane ayarları başarıyla güncellendi',
          );
        } else {
          _showErrorFeedback('Ayarlar kaydedilemedi. Tekrar deneyin.');
        }
      } else {
        _showErrorFeedback('Sunucu hatası: ${response.statusCode}');
      }
    } catch (e) {
      _showErrorFeedback(
        'Bağlantı hatası. İnternet bağlantınızı kontrol edin.',
      );
    } finally {
      setState(() => _isSavingConfig = false);
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

                        // Bugün Nöbetçiyim / Değilim butonları
                        _buildActionButton(
                          text: _isMarkingToday
                              ? 'İŞLENİYOR...'
                              : 'BUGÜN NÖBETÇİYİM',
                          onPressed: _isMarkingToday ? () {} : _markTodayOnDuty,
                          isPressed: _isTodayButtonPressed,
                          onPressChanged: (pressed) =>
                              setState(() => _isTodayButtonPressed = pressed),
                        ),

                        const SizedBox(height: 12),

                        _buildActionButton(
                          text: _isUnmarkingToday
                              ? 'İŞLENİYOR...'
                              : 'BUGÜN NÖBETÇİ DEĞİLİM',
                          onPressed: _isUnmarkingToday
                              ? () {}
                              : _unmarkTodayOnDuty,
                          isPressed: _isTodayOffButtonPressed,
                          onPressChanged: (pressed) => setState(
                            () => _isTodayOffButtonPressed = pressed,
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Ayarları Güncelle butonu
                        _buildActionButton(
                          text: 'NÖBET AYARLARINI GÜNCELLE',
                          onPressed: _updateScreen,
                          isPressed: _isGuncellePressed,
                          onPressChanged: (pressed) =>
                              setState(() => _isGuncellePressed = pressed),
                        ),

                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Yükleme overlay'i - default değerlerin görünmesini engelle
          if (_isConfigLoading)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.4),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Ayarlar yükleniyor...',
                        style: GoogleFonts.inter(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
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
          value: enabled && items.contains(value) ? value : null,
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

  void _updateScreen() {
    if (_isSavingConfig) return; // Zaten kaydetme işlemi devam ediyorsa
    _updateNobetciConfig();
  }

  Future<void> _markTodayOnDuty() async {
    setState(() => _isMarkingToday = true);
    try {
      final baseUrl = await _getApiBaseUrl();
      const path = '/api/mobile/nobetci/self-duty/activate';
      final url = '$baseUrl$path';

      final response = await http
          .post(Uri.parse(url), headers: {'Content-Type': 'application/json'})
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          _showSuccessFeedback(
            'İşlem Başarılı',
            'Bugün nöbetçi olarak işaretlendi',
          );
        } else {
          _showErrorFeedback('İşlem başarısız. Tekrar deneyin.');
        }
      } else {
        _showErrorFeedback('Sunucu hatası: ${response.statusCode}');
      }
    } catch (e) {
      _showErrorFeedback('Bağlantı hatası. Lütfen tekrar deneyin.');
    } finally {
      if (mounted) setState(() => _isMarkingToday = false);
    }
  }

  Future<void> _unmarkTodayOnDuty() async {
    setState(() => _isUnmarkingToday = true);
    try {
      final baseUrl = await _getApiBaseUrl();
      const path = '/api/mobile/nobetci/self-duty/deactivate';
      final url = '$baseUrl$path';

      final response = await http
          .post(Uri.parse(url), headers: {'Content-Type': 'application/json'})
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          _showSuccessFeedback(
            'İşlem Başarılı',
            'Bugün nöbetçi değil olarak işaretlendi',
          );
        } else {
          _showErrorFeedback('İşlem başarısız. Tekrar deneyin.');
        }
      } else {
        _showErrorFeedback('Sunucu hatası: ${response.statusCode}');
      }
    } catch (e) {
      _showErrorFeedback('Bağlantı hatası. Lütfen tekrar deneyin.');
    } finally {
      if (mounted) setState(() => _isUnmarkingToday = false);
    }
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
