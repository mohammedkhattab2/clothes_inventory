import 'dart:math' as math;
import 'dart:typed_data';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:clothes_inventory/core/config/company_settings_service.dart';
import 'package:clothes_inventory/features/auth/data/auth_repository.dart';
import 'package:clothes_inventory/services/di/service_locator.dart';
import 'package:clothes_inventory/services/auth/session_service.dart';

enum _LoginMethod { password, pin }

class LoginPage extends StatefulWidget {
  const LoginPage({required this.onLoginSuccess, super.key});

  final ValueChanged<bool> onLoginSuccess;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  late final AnimationController _controller;
  late final Animation<double> _logoPulse;
  late final Animation<double> _cardFade;
  late final Animation<Offset> _cardSlide;
  late final CompanySettingsService _companySettingsService;
  late final AuthRepository _authRepository;
  late final SessionService _sessionService;
  late final VoidCallback _settingsListener;

  bool _obscurePassword = true;
  bool _isSubmitting = false;
  _LoginMethod _loginMethod = _LoginMethod.password;
  Uint8List? _logoBytes;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(
        milliseconds: 3000,
      ), // Slightly longer duration for a more magical feel
    )..repeat(reverse: true);

    _logoPulse =
        Tween<double>(
          begin: 0.95,
          end: 1.05, // Slightly more pronounced pulse
        ).animate(
          CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
        ); // Smoother curve

    _cardFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(
          0,
          0.5,
          curve: Curves.easeOutCubic,
        ), // Extended fade-in
      ),
    );

    _cardSlide =
        Tween<Offset>(
              begin: const Offset(0, 0.1),
              end: Offset.zero,
            ) // More pronounced slide
            .animate(
              CurvedAnimation(
                parent: _controller,
                curve: const Interval(
                  0,
                  0.5,
                  curve: Curves.easeOutCubic,
                ), // Extended slide-in
              ),
            );

    _companySettingsService = getIt<CompanySettingsService>();
    _authRepository = getIt<AuthRepository>();
    _sessionService = getIt<SessionService>();
    _settingsListener = () {
      _refreshLogoBytes();
    };
    _companySettingsService.settingsListenable.addListener(_settingsListener);
    _refreshLogoBytes();
  }

  @override
  void dispose() {
    _companySettingsService.settingsListenable.removeListener(
      _settingsListener,
    );
    _controller.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _refreshLogoBytes() async {
    final bytes = await _companySettingsService.loadLogoBytes();
    if (!mounted) return;
    setState(() {
      _logoBytes = bytes;
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _isSubmitting) return;

    final username = _usernameController.text.trim();
    final secret = _passwordController.text.trim();

    setState(() => _isSubmitting = true);
    await Future<void>.delayed(
      const Duration(milliseconds: 600),
    ); // Longer delay for dramatic effect

    if (!mounted) return;

    final authUser = _loginMethod == _LoginMethod.pin
        ? await _authRepository.loginWithPin(username: username, pin: secret)
        : await _authRepository.loginWithPassword(
            username: username,
            password: secret,
          );

    if (authUser != null) {
      _sessionService.login(authUser);
      widget.onLoginSuccess(false);
      return;
    }

    setState(() => _isSubmitting = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Invalid username or password.'.tr())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final foreground = isDark ? Colors.white : theme.colorScheme.onSurface;
    final secondaryForeground = foreground.withValues(
      alpha: isDark ? 0.85 : 0.9,
    );
    final subtleForeground = foreground.withValues(alpha: 0.72);

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? <Color>[
                    const Color(0xFF041C32).withValues(alpha: 0.9),
                    const Color(0xFF115173).withValues(alpha: 0.8),
                    const Color(0xFFC98B2E).withValues(alpha: 0.7),
                    const Color(0xFF8A2BE2).withValues(alpha: 0.6),
                  ]
                : <Color>[
                    theme.colorScheme.primaryContainer.withValues(alpha: 0.92),
                    theme.colorScheme.surfaceContainerHigh.withValues(
                      alpha: 0.88,
                    ),
                    theme.colorScheme.secondaryContainer.withValues(alpha: 0.84),
                    theme.colorScheme.surface.withValues(alpha: 0.92),
                  ],
            stops: const [
              0.1,
              0.4,
              0.7,
              0.9,
            ], // Added stops for better color distribution
          ),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  final t = _controller.value * 2 * math.pi;
                  return CustomPaint(painter: _LoginBackdropPainter(t));
                },
              ),
            ),
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24), // Slightly more padding
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: 450,
                    ), // Slightly wider constraint
                    child: FadeTransition(
                      opacity: _cardFade,
                      child: SlideTransition(
                        position: _cardSlide,
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(
                            30,
                            36,
                            30,
                            30,
                          ), // Adjusted padding
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.05)
                                : Colors.black.withValues(alpha: 0.035),
                            borderRadius: BorderRadius.circular(
                              32,
                            ), // More rounded corners
                            border: Border.all(
                              color: foreground.withValues(alpha: 0.18),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(
                                  alpha: 0.35,
                                ), // Darker, more pronounced shadow
                                blurRadius: 50,
                                offset: const Offset(0, 25),
                              ),
                              BoxShadow(
                                color: const Color(0xFF8A2BE2).withValues(
                                  alpha: 0.25,
                                ), // More pronounced purple glow
                                blurRadius: 20,
                                offset: const Offset(0, 15),
                              ),
                            ],
                          ),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              mainAxisSize:
                                  MainAxisSize.min, // Use minimum size
                              children: [
                                ScaleTransition(
                                  scale: _logoPulse,
                                  child: Container(
                                    width: 100, // Larger logo container
                                    height: 100,
                                    margin: const EdgeInsets.only(
                                      bottom: 24,
                                    ), // More margin
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? Colors.white.withValues(alpha: 0.1)
                                          : Colors.black.withValues(alpha: 0.06),
                                      borderRadius: BorderRadius.circular(
                                        28,
                                      ), // Rounded corners for logo container
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFFFFC14A)
                                              .withValues(
                                                alpha: 0.4,
                                              ), // Golden glow around logo
                                          blurRadius: 20,
                                          spreadRadius: 5,
                                        ),
                                      ],
                                    ),
                                    padding: const EdgeInsets.all(16),
                                    child: _logoBytes == null
                                        ? Image.asset(
                                            'assets/icon/app_icon.png',
                                            fit: BoxFit.contain,
                                          )
                                        : Image.memory(
                                            _logoBytes!,
                                            fit: BoxFit.contain,
                                          ),
                                  ),
                                ),
                                Text(
                                  'Login'.tr(),
                                  textAlign:
                                      TextAlign.center, // Center align title
                                  style: theme.textTheme.headlineLarge?.copyWith(
                                    // Larger headline
                                  color: foreground,
                                    fontWeight:
                                        FontWeight.w900, // Bolder weight
                                    fontStyle: FontStyle
                                        .italic, // Italic for a magical touch
                                    shadows: [
                                      Shadow(
                                        color: const Color(
                                          0xFFFFC14A,
                                        ).withValues(alpha: 0.6),
                                        blurRadius: 10,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Welcome back, sign in to continue.'.tr(),
                                  textAlign:
                                      TextAlign.center, // Center align subtitle
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    // Slightly larger body text
                                    color: secondaryForeground,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(
                                  height: 30,
                                ), // More spacing before fields
                                SegmentedButton<_LoginMethod>(
                                  segments: const [
                                    ButtonSegment<_LoginMethod>(
                                      value: _LoginMethod.password,
                                      label: Text('Password'),
                                      icon: Icon(Icons.lock_outline_rounded),
                                    ),
                                    ButtonSegment<_LoginMethod>(
                                      value: _LoginMethod.pin,
                                      label: Text('PIN'),
                                      icon: Icon(Icons.pin_outlined),
                                    ),
                                  ],
                                  selected: <_LoginMethod>{_loginMethod},
                                  onSelectionChanged: _isSubmitting
                                      ? null
                                      : (selection) {
                                          if (selection.isEmpty) return;
                                          setState(() {
                                            _loginMethod = selection.first;
                                            _passwordController.clear();
                                          });
                                        },
                                ),
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: _usernameController,
                                  textInputAction: TextInputAction.next,
                                  style: TextStyle(color: foreground),
                                  decoration: _inputDecoration(
                                    context,
                                    label: 'Username'.tr(),
                                    icon: Icons
                                        .person_outline_rounded, // Slightly different icon
                                  ),
                                  validator: (value) {
                                    if ((value ?? '').trim().isEmpty) {
                                      return 'Username is required'.tr();
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: _passwordController,
                                  textInputAction: TextInputAction.done,
                                  keyboardType: _loginMethod == _LoginMethod.pin
                                      ? TextInputType.number
                                      : TextInputType.text,
                                  obscureText: _obscurePassword,
                                  onFieldSubmitted: (_) => _submit(),
                                    style: TextStyle(color: foreground),
                                  decoration:
                                      _inputDecoration(
                                        context,
                                        label: _loginMethod == _LoginMethod.pin
                                            ? 'PIN'.tr()
                                            : 'Password'.tr(),
                                        icon: Icons
                                            .lock_outline_rounded, // Slightly different icon
                                      ).copyWith(
                                        suffixIcon: IconButton(
                                          tooltip: _obscurePassword
                                              ? 'Show password'.tr()
                                              : 'Hide password'.tr(),
                                          color: subtleForeground,
                                          onPressed: () {
                                            setState(() {
                                              _obscurePassword =
                                                  !_obscurePassword;
                                            });
                                          },
                                          icon: Icon(
                                            _obscurePassword
                                                ? Icons.visibility_outlined
                                                : Icons.visibility_off_outlined,
                                            color: subtleForeground,
                                          ),
                                        ),
                                      ),
                                  validator: (value) {
                                    final normalized = (value ?? '').trim();
                                    if (normalized.isEmpty) {
                                      return _loginMethod == _LoginMethod.pin
                                          ? 'PIN is required'.tr()
                                          : 'Password is required'.tr();
                                    }
                                    if (_loginMethod == _LoginMethod.pin &&
                                        !RegExp(
                                          r'^\d{4,6}$',
                                        ).hasMatch(normalized)) {
                                      return 'PIN must be 4-6 digits'.tr();
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(
                                  height: 24,
                                ), // More spacing before button
                                FilledButton(
                                  onPressed: _isSubmitting ? null : _submit,
                                  style: FilledButton.styleFrom(
                                    minimumSize: const Size.fromHeight(
                                      56,
                                    ), // Taller button
                                    backgroundColor: const Color(
                                      0xFFFFC14A,
                                    ), // Accent color
                                    foregroundColor: const Color(
                                      0xFF122B40,
                                    ), // Dark text on button
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(
                                        16,
                                      ), // Rounded button
                                    ),
                                    elevation: 8, // Add shadow to button
                                    shadowColor: const Color(
                                      0xFFFFC14A,
                                    ).withValues(alpha: 0.5),
                                    textStyle: const TextStyle(
                                      fontSize: 18, // Larger text
                                      fontWeight:
                                          FontWeight.w900, // Bolder text
                                    ),
                                  ),
                                  child: _isSubmitting
                                      ? const SizedBox(
                                          height: 24,
                                          width: 24,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 3,
                                            color: Color(
                                              0xFF122B40,
                                            ), // Match button text color
                                          ),
                                        )
                                      : Text('Sign In'.tr()),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  _loginMethod == _LoginMethod.pin
                                      ? 'Default owner username: owner, PIN: 0000'
                                            .tr()
                                      : 'Default owner username: owner, password: 123456'
                                            .tr(),
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: subtleForeground,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                // Optional: Add a subtle "Forgot Password" or "Sign Up" link here if needed
                                // TextButton(
                                //   onPressed: () { /* TODO: Implement forgot password */ },
                                //   child: Text('Forgot Password?'.tr(), style: TextStyle(color: Colors.white70)),
                                // ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(
    BuildContext context, {
    required String label,
    required IconData icon,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final fieldColor = isDark ? Colors.white : theme.colorScheme.onSurface;
    const borderRadius = BorderRadius.all(Radius.circular(16));
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(
        color: fieldColor.withValues(alpha: 0.72),
      ), // Softer label color
      prefixIcon: Icon(
        icon,
        color: fieldColor.withValues(alpha: 0.72),
      ), // Softer icon color
      filled: true,
      fillColor: isDark
          ? Colors.white.withValues(alpha: 0.1)
          : Colors.black.withValues(alpha: 0.08),
      enabledBorder: OutlineInputBorder(
        borderRadius: borderRadius,
        borderSide: BorderSide(
          color: fieldColor.withValues(alpha: 0.24),
        ), // Softer enabled border
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: borderRadius,
        borderSide: BorderSide(
          color: const Color(0xFFFFC14A),
          width: 1.6,
        ), // Slightly thicker accent border
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: borderRadius,
        borderSide: BorderSide(
          color: Theme.of(context).colorScheme.error.withValues(alpha: 0.8),
        ), // Softened error color
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: borderRadius,
        borderSide: BorderSide(
          color: Theme.of(
            context,
          ).colorScheme.error.withValues(alpha: 0.8), // Softened error color
          width: 1.6,
        ),
      ),
    );
  }
}

class _LoginBackdropPainter extends CustomPainter {
  _LoginBackdropPainter(this.t);

  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    // Subtle shimmering effect for the first circle
    paint.color = Color(
      0x40FFFFFF,
    ).withBlue(150).withGreen(150); // Slightly bluish-white shimmer
    canvas.drawCircle(
      Offset(
        size.width * (0.18 + 0.04 * math.sin(t * 1.2)), // Faster shimmer
        size.height *
            (0.20 + 0.03 * math.cos(t * 1.1)), // Slightly varied movement
      ),
      90, // Slightly larger
      paint,
    );

    // More vibrant and magical second circle
    paint.color = Color(
      0x50FFD700,
    ).withAlpha(180); // Brighter gold, more opaque
    canvas.drawCircle(
      Offset(
        size.width *
            (0.8 + 0.03 * math.cos(t * 0.9 + 1.0)), // Different phase and speed
        size.height *
            (0.74 +
                0.04 * math.sin(t * 1.1 + 0.5)), // Different phase and speed
      ),
      160, // Larger
      paint,
    );

    // Adding a new, subtle magical glow effect
    paint.color = const Color(
      0x308A2BE2,
    ).withAlpha(200); // A soft, magical purple glow
    canvas.drawCircle(
      Offset(
        size.width *
            (0.4 + 0.05 * math.sin(t * 1.5)), // Centered more, faster movement
        size.height *
            (0.5 + 0.04 * math.cos(t * 1.3)), // Centered more, faster movement
      ),
      130, // Medium size
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _LoginBackdropPainter oldDelegate) {
    return oldDelegate.t != t;
  }
}
