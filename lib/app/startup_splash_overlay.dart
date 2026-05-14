import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:clothes_inventory/core/config/company_settings_service.dart';
import 'package:clothes_inventory/services/di/service_locator.dart';

class StartupSplashOverlay extends StatefulWidget {
  const StartupSplashOverlay({super.key, required this.child});

  final Widget child;

  @override
  State<StartupSplashOverlay> createState() => _StartupSplashOverlayState();
}

class _StartupSplashOverlayState extends State<StartupSplashOverlay>
    with SingleTickerProviderStateMixin {
  static const _holdDuration = Duration(milliseconds: 2200);
  static const _fadeDuration = Duration(milliseconds: 700);

  late final AnimationController _controller;
  late final Animation<double> _iconPulse;
  late final Animation<double> _contentFade;
  late final Animation<Offset> _contentSlide;
  late final CompanySettingsService _companySettingsService;
  late final VoidCallback _settingsListener;

  Uint8List? _logoBytes;
  bool _dismissed = false;

  @override
  void initState() {
    super.initState();
    _companySettingsService = getIt<CompanySettingsService>();
    _settingsListener = () {
      _refreshLogoBytes();
    };
    _companySettingsService.settingsListenable.addListener(_settingsListener);
    _refreshLogoBytes();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _iconPulse = Tween<double>(
      begin: 0.96,
      end: 1.04,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    _contentFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0, 0.5)),
    );

    _contentSlide = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    Future<void>.delayed(_holdDuration, () {
      if (!mounted) return;
      setState(() => _dismissed = true);
    });
  }

  @override
  void dispose() {
    _companySettingsService.settingsListenable.removeListener(
      _settingsListener,
    );
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        IgnorePointer(
          ignoring: _dismissed,
          child: AnimatedOpacity(
            opacity: _dismissed ? 0 : 1,
            duration: _fadeDuration,
            curve: Curves.easeInOut,
            onEnd: () {
              if (mounted && _dismissed) {
                setState(() {});
              }
            },
            child: _dismissed
                ? const SizedBox.shrink()
                : _SplashScene(
                    iconPulse: _iconPulse,
                    contentFade: _contentFade,
                    contentSlide: _contentSlide,
                    controller: _controller,
                    logoBytes: _logoBytes,
                  ),
          ),
        ),
      ],
    );
  }

  Future<void> _refreshLogoBytes() async {
    final bytes = await _companySettingsService.loadLogoBytes();
    if (!mounted) return;
    setState(() {
      _logoBytes = bytes;
    });
  }
}

class _SplashScene extends StatelessWidget {
  const _SplashScene({
    required this.iconPulse,
    required this.contentFade,
    required this.contentSlide,
    required this.controller,
    required this.logoBytes,
  });

  final Animation<double> iconPulse;
  final Animation<double> contentFade;
  final Animation<Offset> contentSlide;
  final AnimationController controller;
  final Uint8List? logoBytes;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final Color foreground = isDark
        ? Colors.white
        : theme.colorScheme.onPrimaryContainer;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? const <Color>[
                  Color(0xFF0B2B40),
                  Color(0xFF0D5973),
                  Color(0xFF8A6A1A),
                ]
              : <Color>[
                  theme.colorScheme.primaryContainer,
                  theme.colorScheme.secondaryContainer,
                  theme.colorScheme.tertiaryContainer,
                ],
        ),
      ),
      child: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: AnimatedBuilder(
                animation: controller,
                builder: (context, _) {
                  final t = controller.value * 2 * math.pi;
                  return CustomPaint(painter: _OrbPainter(t));
                },
              ),
            ),
            Center(
              child: FadeTransition(
                opacity: contentFade,
                child: SlideTransition(
                  position: contentSlide,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedBuilder(
                        animation: controller,
                        builder: (context, child) {
                          // Subtle rotation for a more magical feel
                          return Transform.rotate(
                            angle:
                                controller.value *
                                0.1 *
                                math.pi, // Small rotation
                            child: child,
                          );
                        },
                        child: ScaleTransition(
                          scale: iconPulse,
                          child: Container(
                            width: 124,
                            height: 124,
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: foreground.withValues(
                                alpha: isDark ? 0.16 : 0.12,
                              ),
                              borderRadius: BorderRadius.circular(32),
                              border: Border.all(
                                color: foreground.withValues(
                                  alpha: isDark ? 0.35 : 0.3,
                                ),
                              ),
                              boxShadow: [
                                const BoxShadow(
                                  color: Color(0x50000000),
                                  blurRadius: 34,
                                  offset: Offset(0, 14),
                                ),
                                // Add a subtle glow effect
                                BoxShadow(
                                  color: foreground.withValues(
                                    alpha: isDark ? 0.4 : 0.25,
                                  ),
                                  blurRadius: 20,
                                  spreadRadius: 5,
                                ),
                              ],
                            ),
                            child: logoBytes == null
                                ? Image.asset(
                                    'assets/icon/app_icon.png',
                                    fit: BoxFit.contain,
                                  )
                                : Image.memory(logoBytes!, fit: BoxFit.contain),
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      Text(
                        'Clothes Inventory POS',
                        style:
                            Theme.of(context).textTheme.headlineLarge?.copyWith(
                              color: foreground,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ) ??
                            TextStyle(
                              color: foreground,
                              fontSize: 30,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Fast. Precise. Professional.',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: foreground.withValues(alpha: 0.8),
                              fontWeight: FontWeight.w500,
                            ) ??
                            TextStyle(
                              color: foreground.withValues(alpha: 0.8),
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                      ),
                      const SizedBox(height: 26),
                      SizedBox(
                        width: 170,
                        child: AnimatedBuilder(
                          animation: controller,
                          builder: (context, _) {
                            return LinearProgressIndicator(
                              minHeight: 5,
                              borderRadius: BorderRadius.circular(999),
                              value: controller.value,
                              color: const Color(0xFFFFC44D),
                              backgroundColor: foreground.withValues(
                                alpha: isDark ? 0.22 : 0.3,
                              ),
                            );
                          },
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
    );
  }
}

class _OrbPainter extends CustomPainter {
  _OrbPainter(this.t);

  final double t;
  Size? size; // Make size nullable and assign in paint

  @override
  void paint(Canvas canvas, Size size) {
    this.size = size; // Assign size here
    final paint = Paint()..style = PaintingStyle.fill;

    // Animated particles
    _drawParticle(
      canvas,
      paint,
      0.25,
      0.22,
      70,
      0.03 * math.sin(t),
      0.02 * math.cos(t),
      const Color(0x80FFFFFF),
    );
    _drawParticle(
      canvas,
      paint,
      0.72,
      0.28,
      110,
      0.02 * math.cos(t + 1.4),
      0.03 * math.sin(t + 0.5),
      const Color(0x38FFD36D),
    );
    _drawParticle(
      canvas,
      paint,
      0.62,
      0.79,
      145,
      0.02 * math.sin(t + 2.1),
      0.03 * math.cos(t + 0.9),
      const Color(0x4D5BC0FF),
    );

    // Add more particles for a magical effect
    _drawParticle(
      canvas,
      paint,
      0.4,
      0.6,
      90,
      0.04 * math.cos(t * 0.8),
      0.03 * math.sin(t * 0.8),
      const Color(0x60FFC107),
    ); // Golden particle
    _drawParticle(
      canvas,
      paint,
      0.1,
      0.8,
      60,
      0.03 * math.sin(t * 1.2),
      0.02 * math.cos(t * 1.2),
      const Color(0x50ADD8E6),
    ); // Light blue particle
  }

  void _drawParticle(
    Canvas canvas,
    Paint paint,
    double x,
    double y,
    double radius,
    double offsetX,
    double offsetY,
    Color color,
  ) {
    paint.color = color;
    canvas.drawCircle(
      Offset(
        size!.width * (x + offsetX), // Use ! for non-null assertion
        size!.height * (y + offsetY), // Use ! for non-null assertion
      ),
      radius,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _OrbPainter oldDelegate) => oldDelegate.t != t;
}
