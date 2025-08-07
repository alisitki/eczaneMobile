import 'dart:math';
import 'package:flutter/material.dart';

class AnimatedParticles extends StatefulWidget {
  const AnimatedParticles({super.key});

  @override
  State<AnimatedParticles> createState() => _AnimatedParticlesState();
}

class _AnimatedParticlesState extends State<AnimatedParticles>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  List<Particle> particles = [];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    )..repeat();

    // 25 adet particle oluştur
    for (int i = 0; i < 25; i++) {
      particles.add(Particle());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          painter: ParticlesPainter(particles, _controller.value),
          size: Size.infinite,
        );
      },
    );
  }
}

class Particle {
  late double x;
  late double y;
  late double speed;
  late double size;
  late double opacity;
  late double phase;

  Particle() {
    final random = Random();
    x = random.nextDouble();
    y = random.nextDouble();
    speed = 0.2 + random.nextDouble() * 0.3; // 0.2-0.5 hızı
    size = 1.0 + random.nextDouble() * 1.5; // 1-2.5px boyut
    opacity = 0.1 + random.nextDouble() * 0.2; // 0.1-0.3 opacity
    phase = random.nextDouble() * 2 * pi; // Fade animasyonu için
  }
}

class ParticlesPainter extends CustomPainter {
  final List<Particle> particles;
  final double animationValue;

  ParticlesPainter(this.particles, this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();

    for (var particle in particles) {
      // Yukarı doğru hareket
      double currentY = particle.y - (animationValue * particle.speed);

      // Ekranın altından çıkınca üstten tekrar başlat
      if (currentY < -0.1) {
        currentY = 1.1;
        particle.y = 1.1;
      }

      // Fade in/out efekti
      double fadeValue = sin(animationValue * 2 * pi + particle.phase).abs();
      double currentOpacity = particle.opacity * fadeValue;

      // Particle çiz
      paint.color = Colors.white.withValues(alpha: currentOpacity);

      canvas.drawCircle(
        Offset(particle.x * size.width, currentY * size.height),
        particle.size,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
