import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:clothes_inventory/core/utils/translation_utils.dart';
import 'package:clothes_inventory/core/widgets/app_brand_header.dart';
import 'package:clothes_inventory/core/widgets/app_page_shell.dart';
import 'package:clothes_inventory/features/backup/presentation/backup_cubit.dart';
import 'package:clothes_inventory/services/di/service_locator.dart';
import 'package:clothes_inventory/features/backup/data/backup_lifecycle_service.dart';

class BackupPage extends StatelessWidget {
  const BackupPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<BackupCubit>(
      create: (_) => getIt<BackupCubit>()..loadOverview(),
      child: const _BackupView(),
    );
  }
}

class _BackupView extends StatefulWidget {
  const _BackupView();

  @override
  State<_BackupView> createState() => _BackupViewState();
}

class _BackupViewState extends State<_BackupView> {
  bool _settingsInitialized = false;
  bool _autoBackupEnabled = true;
  int _debounceThresholdMinutes = 1440;
  int _retentionCount = 5;
  bool _networkMode = false;
  String? _backupDirectory;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final isCompact = size.width < 900;

    return BlocConsumer<BackupCubit, BackupState>(
      listenWhen: (previous, current) =>
          previous.status != current.status &&
          (current.status == BackupStatus.success ||
              current.status == BackupStatus.error),
      listener: (context, state) async {
        final message = state.message;
        if (message == null || message.trim().isEmpty) {
          return;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(trIfExists(message, context: context))),
        );

        final requiresRestart =
            (state.operationMeta ??
                const <String, dynamic>{})['requiresRestart'] ==
            true;
        if (requiresRestart) {
          await showDialog<void>(
            context: context,
            builder: (dialogContext) {
              return AlertDialog(
                title: Text('backup.restore_complete_title'.tr()),
                content: Text('backup.restart_message'.tr()),
                actions: [
                  FilledButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: Text('OK'.tr()),
                  ),
                ],
              );
            },
          );
          if (!context.mounted) {
            return;
          }
          await getIt<BackupLifecycleService>().restartApplication();
        }

        if (!context.mounted) {
          return;
        }
        context.read<BackupCubit>().clearTransient();
      },
      builder: (context, state) {
        final cubit = context.read<BackupCubit>();
        if (!_settingsInitialized) {
          _settingsInitialized = true;
          _autoBackupEnabled = state.autoBackupEnabled;
          _debounceThresholdMinutes = state.debounceThresholdMinutes;
          _retentionCount = state.retentionCount;
          _networkMode = state.isNetworkMode;
          _backupDirectory = state.backupDirectory;
        }

        final lastBackupAt = state.lastBackupAt;
        final lastBackupSize = state.lastBackupSizeBytes;
        final lastBackupPath = state.lastBackupPath;

        return AppPageShell(
          isCompact: isCompact,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppSectionPanel(
                emphasis: true,
                child: AppBrandHeader(
                  pageTitle: 'backup.title'.tr(),
                  pageSubtitle: 'backup.subtitle'.tr(),
                  description: 'backup.description'.tr(),
                  isDense: false,
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: SingleChildScrollView(
                  child: AppSectionPanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            FilledButton.icon(
                              onPressed: state.status == BackupStatus.loading
                                  ? null
                                  : () => _onCreateBackup(context, cubit),
                              icon: const Icon(Icons.save_outlined),
                              label: Text('backup.create'.tr()),
                            ),
                            OutlinedButton.icon(
                              onPressed: state.status == BackupStatus.loading
                                  ? null
                                  : () => _onRestoreBackup(context, cubit),
                              icon: const Icon(Icons.restore_page_outlined),
                              label: Text('backup.restore'.tr()),
                            ),
                            OutlinedButton.icon(
                              onPressed: state.status == BackupStatus.loading
                                  ? null
                                  : () => _onDryRunValidation(context, cubit),
                              icon: const Icon(Icons.verified_outlined),
                              label: Text('backup.dry_run'.tr()),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color: Theme.of(context).colorScheme.errorContainer
                                .withValues(alpha: 0.45),
                            border: Border.all(
                              color: Theme.of(
                                context,
                              ).colorScheme.error.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Text(
                            'backup.restore_warning'.tr(),
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildInfoRow(
                          context,
                          label: 'backup.last_backup'.tr(),
                          value: lastBackupAt == null
                              ? 'backup.not_available'.tr()
                              : DateFormat(
                                  'yyyy-MM-dd HH:mm:ss',
                                ).format(lastBackupAt.toLocal()),
                        ),
                        _buildInfoRow(
                          context,
                          label: 'backup.last_size'.tr(),
                          value: lastBackupSize == null
                              ? '-'
                              : _formatBytes(lastBackupSize),
                        ),
                        _buildInfoRow(
                          context,
                          label: 'backup.last_path'.tr(),
                          value: lastBackupPath ?? '-',
                        ),
                        const SizedBox(height: 8),
                        FutureBuilder<String>(
                          future: cubit.getDefaultBackupDirectory(),
                          builder: (context, snapshot) {
                            return _buildInfoRow(
                              context,
                              label: 'backup.default_location'.tr(),
                              value: snapshot.data ?? '...',
                            );
                          },
                        ),
                        const SizedBox(height: 8),
                        _buildInfoRow(
                          context,
                          label: 'backup.health'.tr(),
                          value: state.isHealthy
                              ? 'backup.healthy'.tr()
                              : 'backup.overdue'.tr(),
                        ),
                        const SizedBox(height: 8),
                        _buildOperationDetails(context, state),
                        const SizedBox(height: 16),
                        Text(
                          'backup.settings'.tr(),
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 10),
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          value: _autoBackupEnabled,
                          onChanged: state.status == BackupStatus.loading
                              ? null
                              : (value) =>
                                    setState(() => _autoBackupEnabled = value),
                          title: Text('backup.auto_enabled'.tr()),
                          subtitle: Text('backup.auto_enabled_hint'.tr()),
                        ),
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          value: _networkMode,
                          onChanged: state.status == BackupStatus.loading
                              ? null
                              : (value) => setState(() => _networkMode = value),
                          title: Text('backup.network_mode'.tr()),
                          subtitle: Text('backup.network_mode_hint'.tr()),
                        ),
                        _buildInfoRow(
                          context,
                          label: 'backup.threshold_minutes'.tr(),
                          value: _debounceThresholdMinutes.toString(),
                        ),
                        Slider(
                          min: 15,
                          max: 7 * 24 * 60,
                          divisions: ((7 * 24 * 60) - 15) ~/ 15,
                          value: _debounceThresholdMinutes.toDouble(),
                          label: _debounceThresholdMinutes.toString(),
                          onChanged: state.status == BackupStatus.loading
                              ? null
                              : (value) {
                                  setState(() {
                                    _debounceThresholdMinutes = value.round();
                                  });
                                },
                        ),
                        _buildInfoRow(
                          context,
                          label: 'backup.retention'.tr(),
                          value: _retentionCount.toString(),
                        ),
                        Slider(
                          min: 1,
                          max: 30,
                          divisions: 29,
                          value: _retentionCount.toDouble(),
                          label: _retentionCount.toString(),
                          onChanged: state.status == BackupStatus.loading
                              ? null
                              : (value) {
                                  setState(() {
                                    _retentionCount = value.round();
                                  });
                                },
                        ),
                        _buildInfoRow(
                          context,
                          label: 'backup.custom_location'.tr(),
                          value:
                              _backupDirectory ?? 'backup.not_available'.tr(),
                        ),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            OutlinedButton.icon(
                              onPressed: state.status == BackupStatus.loading
                                  ? null
                                  : () => _onPickBackupDirectory(),
                              icon: const Icon(Icons.folder_open_outlined),
                              label: Text('backup.pick_location'.tr()),
                            ),
                            OutlinedButton.icon(
                              onPressed: state.status == BackupStatus.loading
                                  ? null
                                  : () =>
                                        setState(() => _backupDirectory = null),
                              icon: const Icon(Icons.restore_outlined),
                              label: Text('backup.use_default'.tr()),
                            ),
                            FilledButton.icon(
                              onPressed: state.status == BackupStatus.loading
                                  ? null
                                  : () => _onSaveSettings(context, cubit),
                              icon: const Icon(Icons.save_as_outlined),
                              label: Text('backup.save_settings'.tr()),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        Text(
                          'backup.history_title'.tr(),
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 10),
                        if (state.backupHistory.isEmpty)
                          Text('backup.history_empty'.tr())
                        else
                          Column(
                            children: state.backupHistory
                                .take(20)
                                .map(
                                  (entry) => Card(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    child: ListTile(
                                      title: Text(
                                        DateFormat(
                                          'yyyy-MM-dd HH:mm:ss',
                                        ).format(entry.createdAt.toLocal()),
                                      ),
                                      subtitle: Text(
                                        '${_formatBytes(entry.sizeBytes)}\n${entry.path}',
                                      ),
                                      isThreeLine: true,
                                      trailing: IconButton(
                                        tooltip: 'Delete'.tr(),
                                        icon: const Icon(Icons.delete_outline),
                                        onPressed:
                                            state.status == BackupStatus.loading
                                            ? null
                                            : () => _onDeleteBackup(
                                                context,
                                                cubit,
                                                entry.path,
                                              ),
                                      ),
                                    ),
                                  ),
                                )
                                .toList(growable: false),
                          ),
                        if (state.status == BackupStatus.loading) ...[
                          const SizedBox(height: 16),
                          const LinearProgressIndicator(),
                          const SizedBox(height: 8),
                          Text(state.message ?? 'backup.working'.tr()),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoRow(
    BuildContext context, {
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 180,
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(child: SelectableText(value)),
        ],
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  Widget _buildOperationDetails(BuildContext context, BackupState state) {
    final meta = state.operationMeta;
    if (meta == null || meta.isEmpty) {
      return const SizedBox.shrink();
    }

    final sizeBytes = (meta['sizeBytes'] as num?)?.toInt();
    final durationMs = (meta['durationMs'] as num?)?.toInt();
    final path = meta['path'] as String?;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'backup.last_operation'.tr(),
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        if (sizeBytes != null)
          _buildInfoRow(
            context,
            label: 'backup.last_size'.tr(),
            value: _formatBytes(sizeBytes),
          ),
        if (durationMs != null)
          _buildInfoRow(
            context,
            label: 'backup.duration_ms'.tr(),
            value: durationMs.toString(),
          ),
        if (path != null && path.trim().isNotEmpty)
          _buildInfoRow(context, label: 'backup.last_path'.tr(), value: path),
      ],
    );
  }

  Future<void> _onCreateBackup(BuildContext context, BackupCubit cubit) async {
    final suggested =
        'backup_${DateFormat('yyyy-MM-dd_HH-mm-ss-SSS').format(DateTime.now())}.zip';
    final targetPath = await FilePicker.platform.saveFile(
      dialogTitle: 'backup.save_dialog'.tr(),
      fileName: suggested,
      type: FileType.custom,
      allowedExtensions: const ['zip'],
    );

    if (targetPath == null || targetPath.trim().isEmpty) {
      return;
    }

    if (!context.mounted) {
      return;
    }

    final result = await cubit.createBackup(destinationPath: targetPath);
    final requiresOverwrite =
        (result.meta ??
            const <String, dynamic>{})['requiresOverwriteConfirmation'] ==
        true;
    if (!requiresOverwrite || !context.mounted) {
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('backup.overwrite_title'.tr()),
          content: Text('backup.overwrite_message'.tr()),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text('Cancel'.tr()),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text('backup.overwrite_confirm'.tr()),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      await cubit.createBackup(
        destinationPath: targetPath,
        overwriteConfirmed: true,
      );
    }
  }

  Future<void> _onRestoreBackup(BuildContext context, BackupCubit cubit) async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['zip'],
      allowMultiple: false,
      dialogTitle: 'backup.restore_dialog'.tr(),
    );

    final path = picked?.files.single.path;
    if (path == null || path.trim().isEmpty) {
      return;
    }

    if (!context.mounted) {
      return;
    }

    if (!File(path).existsSync()) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('backup.file_not_found'.tr())));
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('backup.restore_confirm_title'.tr()),
          content: Text('backup.restore_warning'.tr()),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text('Cancel'.tr()),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text('backup.restore_confirm'.tr()),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    await cubit.restoreBackup(backupPath: path, confirmed: true);
  }

  Future<void> _onDryRunValidation(
    BuildContext context,
    BackupCubit cubit,
  ) async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['zip'],
      allowMultiple: false,
      dialogTitle: 'backup.restore_dialog'.tr(),
    );

    final path = picked?.files.single.path;
    if (path == null || path.trim().isEmpty) {
      return;
    }

    if (!context.mounted) {
      return;
    }

    await cubit.dryRunValidateBackup(path);
  }

  Future<void> _onPickBackupDirectory() async {
    try {
      final selected = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'backup.pick_location'.tr(),
      );

      if (!mounted) {
        return;
      }

      if (selected == null || selected.trim().isEmpty) {
        return;
      }

      final selectedDirectory = Directory(selected);
      if (!await selectedDirectory.exists()) {
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('backup.invalid_directory'.tr())),
        );
        return;
      }

      setState(() {
        _backupDirectory = selected;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('backup.pick_location_failed'.tr())),
      );
    }
  }

  Future<void> _onSaveSettings(BuildContext context, BackupCubit cubit) async {
    await cubit.saveSettings(
      autoBackupEnabled: _autoBackupEnabled,
      debounceThresholdMinutes: _debounceThresholdMinutes,
      retentionCount: _retentionCount,
      isNetworkMode: _networkMode,
      backupDirectory: _backupDirectory,
    );

    if (!context.mounted) {
      return;
    }

    await cubit.loadOverview();
  }

  Future<void> _onDeleteBackup(
    BuildContext context,
    BackupCubit cubit,
    String path,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('backup.delete_title'.tr()),
          content: Text('backup.delete_message'.tr()),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text('Cancel'.tr()),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text('Delete'.tr()),
            ),
          ],
        );
      },
    );

    if (confirm != true) {
      return;
    }

    await cubit.deleteBackup(path);
  }
}
