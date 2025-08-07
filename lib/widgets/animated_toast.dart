import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Overlay entry that positions & styles the toast correctly.
class AnimatedToastOverlay extends StatelessWidget {
  final BuildContext context; // sayfadan gelen context
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final Color backgroundColor;
  final VoidCallback onDismiss;

  const AnimatedToastOverlay({
    super.key,
    required this.context,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.backgroundColor,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext _) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 16,
      left: 16,
      right: 16,
      child: Material(
        color: Colors.transparent,
        child: DefaultTextStyle(
          style: Theme.of(context).textTheme.bodyMedium!,
          child: AnimatedToast(
            icon: icon,
            iconColor: iconColor,
            title: title,
            subtitle: subtitle,
            backgroundColor: backgroundColor,
            onDismiss: onDismiss,
          ),
        ),
      ),
    );
  }
}

/// Core toast widget (animasyon + içerik)
class AnimatedToast extends StatefulWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final Color backgroundColor;
  final VoidCallback onDismiss;

  const AnimatedToast({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.backgroundColor,
    required this.onDismiss,
  });

  @override
  State<AnimatedToast> createState() => _AnimatedToastState();
}

class _AnimatedToastState extends State<AnimatedToast>
    with TickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();

    _ctrl = AnimationController(
      duration: const Duration(milliseconds: 500), // Daha hızlı giriş
      vsync: this,
    )..forward();

    _scale =
        Tween<double>(
          begin: 0.9, // Daha yumuşak başlangıç
          end: 1,
        ).animate(
          CurvedAnimation(
            parent: _ctrl,
            curve: Curves.easeOutCubic, // Daha smooth curve
          ),
        );

    _opacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0, 0.7, curve: Curves.easeOutCubic),
      ),
    );

    _slide = Tween<Offset>(
      begin: const Offset(0, -0.3), // Daha az hareket
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));

    // 3 sn sonra otomatik kapan
    Future.delayed(const Duration(seconds: 3), _dismiss);
  }

  Future<void> _dismiss() async {
    if (mounted) {
      try {
        // Daha smooth çıkış animasyonu
        _ctrl.duration = const Duration(milliseconds: 300);
        await _ctrl.reverse();
        if (mounted) {
          widget.onDismiss();
        }
      } catch (e) {
        // Controller might be disposed, just call onDismiss
        if (mounted) {
          widget.onDismiss();
        }
      }
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Color alpha(Color c, double opacity) =>
        c.withAlpha((opacity * 255).round());

    return SlideTransition(
      position: _slide,
      child: ScaleTransition(
        scale: _scale,
        child: FadeTransition(
          opacity: _opacity,
          child: GestureDetector(
            onTap: _dismiss,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: widget.backgroundColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withAlpha(25), // %10
                  width: 1,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color.fromARGB(77, 0, 0, 0), // %30 siyah
                    blurRadius: 20,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // ikon kutusu
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: alpha(widget.iconColor, .15), // %15 ikon rengi
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(widget.icon, color: widget.iconColor, size: 24),
                  ),
                  const SizedBox(width: 12),
                  // metinler
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.title,
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            decoration: TextDecoration.none,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.subtitle,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                            color: Colors.white.withAlpha(179), // %70
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: _dismiss,
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(25), // %10
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(
                        Icons.close,
                        color: Color.fromARGB(153, 255, 255, 255), // %60
                        size: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
