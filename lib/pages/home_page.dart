import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vibration/vibration.dart';
import '../widgets/animated_particles.dart';
import 'pharmacy_settings_page.dart';
import 'screen_settings_page.dart';
import 'wifi_settings_page.dart';
import 'media_management_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

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
                        const SizedBox(height: 16),
                        // Üçüncü satır - Sistem Durum Kontrolü (yatay)
                        _InteractiveCard(
                          onTap: () => _handleCardTap(context, 'Sistem Durum'),
                          child: Container(
                            width: double.infinity,
                            height: 70,
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFF2A2A3E,
                              ).withValues(alpha: 0.8),
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
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: const Color(
                                        0xFF9F7AEA,
                                      ).withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(
                                      Icons.analytics_outlined,
                                      size: 24,
                                      color: Color(0xFF9F7AEA),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Text(
                                    'Sistem Durum Kontrolü',
                                    style: GoogleFonts.inter(
                                      fontSize: 16,
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

                // Bağlantı durumu ve sürüm bilgisi
                Padding(
                  padding: const EdgeInsets.only(bottom: 30),
                  child: Column(
                    children: [
                      // Bağlantı durumu
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.check_circle,
                            color: Color(0xFF38A169),
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Nobetix Pano Bağlantısı Başarılı',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: const Color(0xFF38A169),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Sürüm bilgisi
                      Text(
                        'Sürüm V.1.0.0',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.5),
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
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
