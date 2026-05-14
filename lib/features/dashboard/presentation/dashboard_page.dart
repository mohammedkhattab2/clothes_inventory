import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:clothes_inventory/core/widgets/app_brand_header.dart';
import 'package:clothes_inventory/core/widgets/app_error_banner.dart';
import 'package:clothes_inventory/core/widgets/app_inline_loading_indicator.dart';
import 'package:clothes_inventory/core/widgets/app_loading_indicator.dart';
import 'package:clothes_inventory/core/widgets/app_page_shell.dart';
import 'package:clothes_inventory/features/auth/domain/auth_user.dart';
import 'package:clothes_inventory/features/dashboard/data/dashboard_repository.dart';
import 'package:clothes_inventory/features/dashboard/presentation/dashboard_cubit.dart';
import 'package:clothes_inventory/features/dashboard/presentation/widgets/dashboard_charts_section.dart';
import 'package:clothes_inventory/features/dashboard/presentation/widgets/dashboard_executive_spotlight.dart';
import 'package:clothes_inventory/features/dashboard/presentation/widgets/dashboard_filters.dart';
import 'package:clothes_inventory/features/dashboard/presentation/widgets/dashboard_kpi_grid.dart';
import 'package:clothes_inventory/features/dashboard/presentation/widgets/dashboard_top_suppliers_card.dart';
import 'package:clothes_inventory/services/auth/session_service.dart';
import 'package:clothes_inventory/services/di/service_locator.dart';
import 'package:clothes_inventory/services/platform/folder_opener_service.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final _topChartKey = GlobalKey();
  final _trendChartKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final isOwner = getIt<SessionService>().currentUser?.role == UserRole.owner;
    final colorScheme = Theme.of(context).colorScheme;
    final size = MediaQuery.sizeOf(context);
    final isCompact = size.width < 900;
    final isDenseViewport = size.height < 820 || size.width < 1180;
    final isVeryDenseViewport = size.height < 700 || size.width < 1024;
    final sectionGap = isVeryDenseViewport
        ? 8.0
        : (isDenseViewport ? 10.0 : 12.0);
    return BlocProvider(
      create: (_) => getIt<DashboardCubit>()..initialize(),
      child: BlocBuilder<DashboardCubit, DashboardState>(
        builder: (context, state) {
          final snapshot = state.snapshot;
          return AppPageShell(
            isCompact: isCompact,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppSectionPanel(
                  emphasis: true,
                  padding: EdgeInsets.symmetric(
                    horizontal: isVeryDenseViewport
                        ? 8
                        : (isDenseViewport ? 10 : 12),
                    vertical: isVeryDenseViewport
                        ? 6
                        : (isDenseViewport ? 8 : 10),
                  ),
                  child: AppBrandHeader(
                    pageTitle: 'Dashboard Analytics'.tr(),
                    actions: [
                      FilledButton.icon(
                        onPressed: state.exporting || snapshot == null
                            ? null
                            : () => _exportDashboardPdf(context),
                        style: FilledButton.styleFrom(
                          backgroundColor: colorScheme.primary,
                          foregroundColor: colorScheme.onPrimary,
                        ),
                        icon: state.exporting
                            ? const AppInlineLoadingIndicator()
                            : const Icon(Icons.picture_as_pdf_outlined),
                        label: Text(
                          (isOwner ? 'Export PDF' : 'Close Shift Report').tr(),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: state.lastExportPath == null
                            ? null
                            : () => _openExportFolder(
                                context,
                                state.lastExportPath!,
                              ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: colorScheme.onPrimaryContainer,
                          side: BorderSide(color: colorScheme.outlineVariant),
                        ),
                        icon: const Icon(Icons.folder_open_outlined),
                        label: Text('Open Folder'.tr()),
                      ),
                    ],
                    isDense: isDenseViewport,
                  ),
                ),
                if (!isOwner) ...[
                  SizedBox(height: sectionGap),
                  AppSectionPanel(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.badge_outlined, color: colorScheme.primary),
                        const SizedBox(width: 8),
                        Text(
                          'Shift View'.tr(),
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Revenue and expenses only'.tr(),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                SizedBox(height: sectionGap),
                AppSectionPanel(
                  child: DashboardFilters(
                    state: state,
                    isDenseViewport: isDenseViewport,
                  ),
                ),
                SizedBox(height: sectionGap),
                if (state.error != null && snapshot != null) ...[
                  AppErrorBanner(
                    message: state.error!,
                    onRetry: () => context.read<DashboardCubit>().initialize(),
                    retryLabel: 'Refresh'.tr(),
                  ),
                  SizedBox(height: sectionGap),
                ],
                if (state.loading && snapshot == null)
                  Expanded(
                    child: AppLoadingIndicator(
                      label: 'Loading dashboard...'.tr(),
                    ),
                  )
                else if (state.error != null && snapshot == null)
                  Expanded(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 680),
                        child: AppErrorBanner(
                          message: state.error!,
                          onRetry: () =>
                              context.read<DashboardCubit>().initialize(),
                          retryLabel: 'Refresh'.tr(),
                        ),
                      ),
                    ),
                  )
                else if (snapshot != null)
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (isOwner) ...[
                            _buildExecutiveSpotlight(
                              context,
                              snapshot,
                              dense: isDenseViewport,
                            ),
                            SizedBox(height: sectionGap),
                          ],
                          DashboardKpiGrid(
                            snapshot: snapshot,
                            cubit: context.read<DashboardCubit>(),
                            ownerView: isOwner,
                          ),
                          SizedBox(height: sectionGap),
                          DashboardChartsSection(
                            snapshot: snapshot,
                            isDenseViewport: isDenseViewport,
                            topChartKey: _topChartKey,
                            trendChartKey: _trendChartKey,
                          ),
                          SizedBox(height: sectionGap),
                          DashboardTopSuppliersCard(
                            suppliers: snapshot.topSuppliers,
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  const Expanded(child: SizedBox.shrink()),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _exportDashboardPdf(BuildContext context) async {
    final cubit = context.read<DashboardCubit>();
    final currentUser = getIt<SessionService>().currentUser;
    final includeOwnerAnalytics = currentUser?.role == UserRole.owner;
    try {
      final topProductsImage = await _capturePng(_topChartKey);
      final trendImage = await _capturePng(_trendChartKey);
      final path = await cubit.exportDashboardPdf(
        topProductsChart: topProductsImage,
        trendChart: trendImage,
        includeOwnerAnalytics: includeOwnerAnalytics,
        preparedByName:
            (currentUser?.fullName ?? currentUser?.username ?? '')
                .trim()
                .isEmpty
            ? null
            : (currentUser?.fullName ?? currentUser?.username),
      );
      if (!context.mounted) return;
      final successLabel = includeOwnerAnalytics
          ? 'Dashboard PDF exported'.tr()
          : 'Shift close report exported'.tr();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$successLabel: $path')));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${'Dashboard export failed'.tr()}: $e')),
      );
    }
  }

  Future<void> _openExportFolder(
    BuildContext context,
    String exportPath,
  ) async {
    final ok = await getIt<FolderOpenerService>().openContainingFolder(
      exportPath,
    );
    if (!context.mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open export folder.'.tr())),
      );
    }
  }

  Future<Uint8List?> _capturePng(GlobalKey key) async {
    final renderObject = key.currentContext?.findRenderObject();
    if (renderObject is! RenderRepaintBoundary) return null;
    final image = await renderObject.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return bytes?.buffer.asUint8List();
  }

  Widget _buildExecutiveSpotlight(
    BuildContext context,
    DashboardSnapshot snapshot, {
    required bool dense,
  }) => DashboardExecutiveSpotlight(snapshot: snapshot, dense: dense);
}
