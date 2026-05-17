import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:delta_erp/features/license/domain/license_service.dart';

class ActivationPage extends StatefulWidget {
  const ActivationPage({
    required this.licenseService,
    required this.onActivationSuccess,
    this.initialFailureCode,
    this.initialFailureMessage,
    super.key,
  });

  final LicenseService licenseService;
  final VoidCallback onActivationSuccess;
  final String? initialFailureCode;
  final String? initialFailureMessage;

  @override
  State<ActivationPage> createState() => _ActivationPageState();
}

class _ActivationPageState extends State<ActivationPage> {
  final TextEditingController _codeController = TextEditingController();
  bool _isSubmitting = false;
  String _message = '';
  String _machineCode = '';
  String _machineHash = '';

  @override
  void initState() {
    super.initState();
    _message = _resolveStatusMessage(
      code: widget.initialFailureCode,
      fallback: widget.initialFailureMessage,
    );
    _loadMachineCode();
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _loadMachineCode() async {
    final String code = await widget.licenseService.getMachineCode();
    final String hash = await widget.licenseService.getMachineHash();
    if (!mounted) return;
    setState(() {
      _machineCode = code;
      _machineHash = hash;
    });
  }

  Future<void> _activate() async {
    final String raw = _codeController.text.trim();
    if (raw.isEmpty || _isSubmitting) {
      return;
    }

    setState(() {
      _isSubmitting = true;
      _message = '';
    });

    final result = await widget.licenseService.activateFromCode(raw);

    if (!mounted) return;

    if (result.isValid) {
      widget.onActivationSuccess();
      return;
    }

    setState(() {
      _isSubmitting = false;
      _message = _resolveStatusMessage(
        code: result.code,
        fallback: result.message,
      );
    });
  }

  String _resolveStatusMessage({String? code, String? fallback}) {
    switch (code) {
      case 'trial_locked':
        return 'license.trial_locked'.tr();
      case 'trial_tampered':
        return 'license.trial_tampered'.tr();
      case 'trial_expired':
        return 'license.trial_expired'.tr();
      case 'trial_error':
        return 'license.trial_error'.tr();
      case 'clock_rollback':
        return 'license.clock_rollback'.tr();
      case 'machine_mismatch':
        return 'license.machine_mismatch'.tr();
      case 'signature_invalid':
      case 'invalid_format':
        return 'license.invalid'.tr();
      case 'license_expired':
        return 'license.expired'.tr();
      case 'no_license':
        return 'license.no_active'.tr();
      default:
        if (fallback != null && fallback.trim().isNotEmpty) {
          return fallback;
        }
        final String defaultMessage = 'license.activation_failed'.tr();
        if (code == null || code.trim().isEmpty) {
          return defaultMessage;
        }
        return '$defaultMessage ($code)';
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'license.activation_page_title'.tr(),
                      style: theme.textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'license.activation_page_hint'.tr(),
                    ),
                    const SizedBox(height: 16),
                    SelectableText(
                      '${'license.machine_code'.tr()}: ${_machineCode.isEmpty ? 'common.loading'.tr() : _machineCode}',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    SelectableText(
                      '${'license.machine_hash'.tr()}: ${_machineHash.isEmpty ? 'common.loading'.tr() : _machineHash}',
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _codeController,
                      maxLines: 8,
                      decoration: InputDecoration(
                        border: const OutlineInputBorder(),
                        labelText: 'license.enter_activation_code'.tr(),
                        alignLabelWithHint: true,
                      ),
                    ),
                    if (_message.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 12),
                      Text(
                        _message,
                        style: TextStyle(color: theme.colorScheme.error),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: FilledButton(
                        onPressed: _isSubmitting ? null : _activate,
                        child: Text(
                          _isSubmitting
                              ? 'license.activating'.tr()
                              : 'license.activate'.tr(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
