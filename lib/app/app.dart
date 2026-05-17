import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:delta_erp/app/app_startup_coordinator.dart';
import 'package:delta_erp/app/startup_splash_overlay.dart';
import 'package:delta_erp/core/theme/app_theme.dart';
import 'package:delta_erp/core/theme/theme_cubit.dart';
import 'package:delta_erp/core/utils/translation_utils.dart';
import 'package:delta_erp/features/backup/data/backup_lifecycle_service.dart';
import 'package:delta_erp/features/auth/presentation/login_page.dart';
import 'package:delta_erp/features/license/domain/license_service.dart';
import 'package:delta_erp/features/license/presentation/activation_page.dart';
import 'package:delta_erp/services/auth/session_service.dart';
import 'package:delta_erp/services/di/service_locator.dart';
import 'package:delta_erp/services/router/app_router.dart';

class DeltaErpApp extends StatefulWidget {
  const DeltaErpApp({super.key});

  @override
  State<DeltaErpApp> createState() => _DeltaErpAppState();
}

class _DeltaErpAppState extends State<DeltaErpApp> {
  bool _isCheckingLicense = true;
  bool _isLicenseActive = false;
  late final ThemeCubit _themeCubit;
  late final LicenseService _licenseService;
  late final SessionService _sessionService;
  late final BackupLifecycleService _backupLifecycleService;
  late final AppStartupCoordinator _startupCoordinator;
  AppLifecycleListener? _lifecycleListener;
  bool _isExitBackupInProgress = false;
  bool _isBackgroundBackupInProgress = false;
  DateTime? _lastBackgroundBackupAt;
  static const int _maxStartupLicenseRetries = 2;
  String? _lastLicenseFailureCode;
  String? _lastLicenseFailureMessage;

  @override
  void initState() {
    super.initState();
    _themeCubit = getIt<ThemeCubit>();
    unawaited(_themeCubit.loadThemeMode());
    _licenseService = getIt<LicenseService>();
    _sessionService = getIt<SessionService>();
    _backupLifecycleService = getIt<BackupLifecycleService>();
    _startupCoordinator = getIt<AppStartupCoordinator>();
    _lifecycleListener = AppLifecycleListener(
      onDetach: _onAppDetach,
      onPause: _onAppBackgrounded,
      onHide: _onAppBackgrounded,
    );
    unawaited(_runDeferredStartupTasks());
    _checkLicense();
  }

  Future<void> _runDeferredStartupTasks() async {
    try {
      await _startupCoordinator.runDeferredStartupTasks();
    } catch (error, stackTrace) {
      assert(() {
        debugPrint('Deferred startup coordinator failed: $error\n$stackTrace');
        return true;
      }());
    }
  }

  void _onAppDetach() {
    _scheduleBackgroundBackup(isExit: true);
  }

  void _onAppBackgrounded() {
    _scheduleBackgroundBackup(isExit: false);
  }

  void _scheduleBackgroundBackup({required bool isExit}) {
    if (_isBackgroundBackupInProgress) {
      return;
    }
    if (isExit) {
      if (_isExitBackupInProgress) {
        return;
      }
      _isExitBackupInProgress = true;
    }
    final now = DateTime.now();
    if (_lastBackgroundBackupAt != null &&
        now.difference(_lastBackgroundBackupAt!) <
            const Duration(minutes: 2)) {
      return;
    }
    _lastBackgroundBackupAt = now;
    _isBackgroundBackupInProgress = true;
    unawaited(_handleBackgroundBackupSafe(isExit: isExit));
  }

  Future<void> _handleBackgroundBackupSafe({required bool isExit}) async {
    try {
      if (isExit) {
        await _backupLifecycleService.handleAppExit();
      } else {
        await _backupLifecycleService.handleAppBackground();
      }
    } catch (error, stackTrace) {
      assert(() {
        debugPrint('Background backup failed: $error\n$stackTrace');
        return true;
      }());
    } finally {
      _isBackgroundBackupInProgress = false;
    }
  }

  @override
  void dispose() {
    _lifecycleListener?.dispose();
    super.dispose();
  }

  Future<void> _checkLicense() async {
    _debugStartupLicense('startup_check_begin');

    bool isValid = false;
    String? lastFailureCode;
    String? lastFailureMessage;
    String? lastCode;
    String? lastMessage;
    for (int attempt = 0; attempt <= _maxStartupLicenseRetries; attempt++) {
      final result = await _licenseService.validateCurrentLicense();
      isValid = result.isValid;
      lastCode = result.code;
      lastMessage = result.message;
      if (!result.isValid) {
        lastFailureCode = result.code;
        lastFailureMessage = result.message;
      }
      _debugStartupLicense(
        'attempt_$attempt',
        code: result.code,
        message: result.message,
        isValid: result.isValid,
      );

      if (isValid) {
        break;
      }

      final bool shouldRetry =
          result.code == 'machine_mismatch' ||
          result.code == 'invalid_format' ||
          result.code == 'signature_invalid';
      if (!shouldRetry) {
        break;
      }
    }

    _debugStartupLicense(
      'startup_check_end',
      code: lastCode,
      message: lastMessage,
      isValid: isValid,
    );

    if (!mounted) return;
    setState(() {
      _isCheckingLicense = false;
      _isLicenseActive = isValid;
      _lastLicenseFailureCode = lastFailureCode;
      _lastLicenseFailureMessage = lastFailureMessage;
    });
  }

  void _debugStartupLicense(
    String stage, {
    String? code,
    String? message,
    bool? isValid,
  }) {
    assert(() {
      final StringBuffer buffer = StringBuffer()
        ..write('[LicenseStartup] stage=$stage');
      if (isValid != null) {
        buffer.write(' isValid=$isValid');
      }
      if (code != null && code.isNotEmpty) {
        buffer.write(' code=$code');
      }
      if (message != null && message.isNotEmpty) {
        buffer.write(' message=$message');
      }
      debugPrint(buffer.toString());
      return true;
    }());
  }

  void _onActivationSuccess() {
    if (!mounted) return;
    setState(() {
      _isLicenseActive = true;
      _isCheckingLicense = false;
    });
  }

  Future<void> _handleLoginSuccess(bool _) async {
    if (!mounted) return;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<ThemeCubit>.value(
      value: _themeCubit,
      child: BlocBuilder<ThemeCubit, ThemeMode>(
        bloc: _themeCubit,
        builder: (context, themeMode) {
          return MaterialApp.router(
            title: trIfExists('DeltaErp', context: context),
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: themeMode,
            locale: context.locale,
            supportedLocales: context.supportedLocales,
            localizationsDelegates: context.localizationDelegates,
            routerConfig: appRouter,
            builder: (context, child) {
              if (_isCheckingLicense) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }

              if (!_isLicenseActive) {
                return Navigator(
                  onGenerateRoute: (settings) {
                    return MaterialPageRoute<void>(
                      builder: (_) => ActivationPage(
                        licenseService: _licenseService,
                        onActivationSuccess: _onActivationSuccess,
                        initialFailureCode: _lastLicenseFailureCode,
                        initialFailureMessage: _lastLicenseFailureMessage,
                      ),
                      settings: settings,
                    );
                  },
                );
              }

              final content = ValueListenableBuilder(
                valueListenable: _sessionService.currentUserListenable,
                builder: (context, user, childContent) {
                  if (_sessionService.isLoggedIn) {
                    return child ?? const SizedBox.shrink();
                  }

                  return Navigator(
                    onGenerateRoute: (settings) {
                      return MaterialPageRoute<void>(
                        builder: (_) =>
                            LoginPage(onLoginSuccess: _handleLoginSuccess),
                        settings: settings,
                      );
                    },
                  );
                },
              );

              return StartupSplashOverlay(child: content);
            },
          );
        },
      ),
    );
  }
}
