import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _sloganController;
  late AnimationController _versionController;
  late AnimationController _fadeOutController;

  late Animation<double> _logoOpacity;
  late Animation<double> _logoScale;
  late Animation<double> _sloganOpacity;
  late Animation<double> _versionOpacity;
  late Animation<double> _fadeOutOpacity;

  // Audio player for splash sound
  late AudioPlayer _audioPlayer;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _initializeAnimations();
    _startAnimationSequence();
  }

  void _initializeAnimations() {
    // Logo animation - scale ve opacity birlikte
    _logoController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeOutCubic),
    );
    _logoScale = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeOutBack),
    );

    // Slogan animation
    _sloganController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _sloganOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _sloganController, curve: Curves.easeOutQuart),
    );

    // Version animation
    _versionController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _versionOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _versionController, curve: Curves.easeOutQuad),
    );

    // Fade out animation - tüm ekranı kapatır
    _fadeOutController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeOutOpacity = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _fadeOutController, curve: Curves.easeInQuad),
    );
  }

  void _startAnimationSequence() async {
    // Başlangıçta 1.0 saniye tam siyah ekran
    await Future.delayed(const Duration(milliseconds: 1000));

    // Ses başlasın (0.5 saniye build-up)
    try {
      _audioPlayer.play(AssetSource('audio/splash.mp3'));
    } catch (e) {
      debugPrint('Audio error: $e');
    }

    // 0.5 saniye ses build-up sonra logo gelsin
    await Future.delayed(const Duration(milliseconds: 500));

    // Logo yavaşça ve büyüyerek gelsin (ses ile perfect timing)
    await _logoController.forward();
    await Future.delayed(const Duration(milliseconds: 800));

    // Slogan smooth gelsin
    await _sloganController.forward();
    await Future.delayed(const Duration(milliseconds: 600));

    // Version gelsin
    await _versionController.forward();

    // Tüm elementleri birlikte izlemek için bekle
    await Future.delayed(const Duration(milliseconds: 1500));

    // Fade out başlasın - tüm ekran yavaşça kayboluyor
    await _fadeOutController.forward();

    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/home');
    }
  }

  @override
  void dispose() {
    _logoController.dispose();
    _sloganController.dispose();
    _versionController.dispose();
    _fadeOutController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: AnimatedBuilder(
        animation: _fadeOutOpacity,
        builder: (context, child) {
          return Opacity(
            opacity: _fadeOutOpacity.value,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF1a1a1a), // Dark gray
                    Colors.black, // Pure black
                    Color(0xFF0d0d0d), // Very dark gray
                  ],
                ),
              ),
              child: SafeArea(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Spacer(flex: 2),

                      // Logo - Scale ve Opacity birlikte
                      AnimatedBuilder(
                        animation: _logoController,
                        builder: (context, child) {
                          return Opacity(
                            opacity: _logoOpacity.value,
                            child: Transform.scale(
                              scale: _logoScale.value,
                              child: Container(
                                padding: const EdgeInsets.all(20),
                                child: Image.asset(
                                  'assets/images/logo.png',
                                  width: 280,
                                  height: 120,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 25),

                      // Slogan
                      AnimatedBuilder(
                        animation: _sloganOpacity,
                        builder: (context, child) {
                          return Opacity(
                            opacity: _sloganOpacity.value,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 40,
                              ),
                              child: Image.asset(
                                'assets/images/slogan.png',
                                width: 240,
                                height: 80,
                                fit: BoxFit.contain,
                              ),
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 20),

                      // Version
                      AnimatedBuilder(
                        animation: _versionOpacity,
                        builder: (context, child) {
                          return Opacity(
                            opacity: _versionOpacity.value,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 40,
                              ),
                              child: Image.asset(
                                'assets/images/version.png',
                                width: 120,
                                fit: BoxFit.contain,
                              ),
                            ),
                          );
                        },
                      ),

                      const Spacer(flex: 2),

                      // Spinner kaldırıldı - sadece boşluk
                      const Spacer(),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
