import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:delta_erp/features/dashboard/presentation/dashboard_cubit.dart';
import 'package:delta_erp/features/dashboard/presentation/widgets/date_filter_button.dart';

class DashboardFilters extends StatelessWidget {
  const DashboardFilters({
    required this.state,
    required this.isDenseViewport,
    super.key,
  });

  final DashboardState state;
  final bool isDenseViewport;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final veryDense = MediaQuery.sizeOf(context).height < 700;

    final InputDecorationTheme inputDecorationTheme = InputDecorationTheme(
      labelStyle: TextStyle(
        color: colorScheme.onSurface.withValues(alpha: 0.8),
        fontWeight: FontWeight.w600,
      ),
      hintStyle: TextStyle(
        color: colorScheme.onSurface.withValues(alpha: 0.6),
        fontWeight: FontWeight.w500,
      ),
      prefixIconColor: colorScheme.onSurface.withValues(alpha: 0.8),
      suffixIconColor: colorScheme.onSurface.withValues(alpha: 0.8),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colorScheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colorScheme.primary, width: 1.4),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colorScheme.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colorScheme.error, width: 1.6),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    );

    final dropdownTextStyle = Theme.of(context).textTheme.titleMedium?.copyWith(
      color: colorScheme.onSurface,
      fontWeight: FontWeight.w700,
    );

    final buttonStyle = OutlinedButton.styleFrom(
      foregroundColor: colorScheme.onSurface,
      side: BorderSide(color: colorScheme.outlineVariant),
      padding: EdgeInsets.symmetric(
        horizontal: veryDense ? 12 : 16,
        vertical: veryDense ? 10 : 12,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      textStyle: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      visualDensity: VisualDensity.compact,
    );

    return Container(
      padding: EdgeInsets.all(veryDense ? 10 : (isDenseViewport ? 12 : 16)),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Wrap(
        spacing: veryDense ? 8 : 10,
        runSpacing: veryDense ? 8 : 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          DateFilterButton(
            label: 'From'.tr(),
            value: state.fromDate,
            onPick: (value) =>
                context.read<DashboardCubit>().setFromDate(value),
          ),
          DateFilterButton(
            label: 'To'.tr(),
            value: state.toDate,
            onPick: (value) => context.read<DashboardCubit>().setToDate(value),
          ),
          SizedBox(
            width: veryDense ? 118 : (isDenseViewport ? 128 : 140),
            child: Theme(
              data: Theme.of(context).copyWith(
                inputDecorationTheme: inputDecorationTheme,
                dropdownMenuTheme: DropdownMenuThemeData(
                  inputDecorationTheme: inputDecorationTheme,
                  textStyle: dropdownTextStyle,
                ),
              ),
              child: DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: state.granularity,
                decoration: InputDecoration(
                  labelText: 'Trend'.tr(),
                  labelStyle: inputDecorationTheme.labelStyle,
                  hintStyle: inputDecorationTheme.hintStyle,
                  prefixIconColor: inputDecorationTheme.prefixIconColor,
                  suffixIconColor: inputDecorationTheme.suffixIconColor,
                  enabledBorder: inputDecorationTheme.enabledBorder,
                  focusedBorder: inputDecorationTheme.focusedBorder,
                  errorBorder: inputDecorationTheme.errorBorder,
                  focusedErrorBorder: inputDecorationTheme.focusedErrorBorder,
                  contentPadding: inputDecorationTheme.contentPadding,
                ),
                items: [
                  DropdownMenuItem(
                    value: 'day',
                    child: Text('Day'.tr(), overflow: TextOverflow.ellipsis),
                  ),
                  DropdownMenuItem(
                    value: 'week',
                    child: Text('Week'.tr(), overflow: TextOverflow.ellipsis),
                  ),
                  DropdownMenuItem(
                    value: 'month',
                    child: Text('Month'.tr(), overflow: TextOverflow.ellipsis),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    context.read<DashboardCubit>().setGranularity(value);
                  }
                },
                style: dropdownTextStyle,
              ),
            ),
          ),
          SizedBox(
            width: veryDense ? 188 : (isDenseViewport ? 200 : 220),
            child: Theme(
              data: Theme.of(context).copyWith(
                inputDecorationTheme: inputDecorationTheme,
                dropdownMenuTheme: DropdownMenuThemeData(
                  inputDecorationTheme: inputDecorationTheme,
                  textStyle: dropdownTextStyle,
                ),
              ),
              child: DropdownButtonFormField<int?>(
                isExpanded: true,
                initialValue: state.categoryId,
                decoration: InputDecoration(
                  labelText: 'Category'.tr(),
                  labelStyle: inputDecorationTheme.labelStyle,
                  hintStyle: inputDecorationTheme.hintStyle,
                  prefixIconColor: inputDecorationTheme.prefixIconColor,
                  suffixIconColor: inputDecorationTheme.suffixIconColor,
                  enabledBorder: inputDecorationTheme.enabledBorder,
                  focusedBorder: inputDecorationTheme.focusedBorder,
                  errorBorder: inputDecorationTheme.errorBorder,
                  focusedErrorBorder: inputDecorationTheme.focusedErrorBorder,
                  contentPadding: inputDecorationTheme.contentPadding,
                ),
                items: [
                  DropdownMenuItem<int?>(
                    value: null,
                    child: Text(
                      'All'.tr(),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                  ...state.categories.map(
                    (c) => DropdownMenuItem<int?>(
                      value: c.id,
                      child: Text(
                        c.name,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ),
                ],
                selectedItemBuilder: (context) => [
                  DropdownMenuItem<int?>(
                    value: null,
                    child: Text(
                      'All'.tr(),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                  ...state.categories.map(
                    (c) => DropdownMenuItem<int?>(
                      value: c.id,
                      child: Text(
                        c.name,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ),
                ],
                onChanged: (value) =>
                    context.read<DashboardCubit>().setCategory(value),
                style: dropdownTextStyle,
              ),
            ),
          ),
          SizedBox(
            width: veryDense ? 188 : (isDenseViewport ? 200 : 220),
            child: Theme(
              data: Theme.of(context).copyWith(
                inputDecorationTheme: inputDecorationTheme,
                dropdownMenuTheme: DropdownMenuThemeData(
                  inputDecorationTheme: inputDecorationTheme,
                  textStyle: dropdownTextStyle,
                ),
              ),
              child: DropdownButtonFormField<int?>(
                isExpanded: true,
                initialValue: state.accountId,
                decoration: InputDecoration(
                  labelText: 'Account'.tr(),
                  labelStyle: inputDecorationTheme.labelStyle,
                  hintStyle: inputDecorationTheme.hintStyle,
                  prefixIconColor: inputDecorationTheme.prefixIconColor,
                  suffixIconColor: inputDecorationTheme.suffixIconColor,
                  enabledBorder: inputDecorationTheme.enabledBorder,
                  focusedBorder: inputDecorationTheme.focusedBorder,
                  errorBorder: inputDecorationTheme.errorBorder,
                  focusedErrorBorder: inputDecorationTheme.focusedErrorBorder,
                  contentPadding: inputDecorationTheme.contentPadding,
                ),
                items: [
                  DropdownMenuItem<int?>(
                    value: null,
                    child: Text(
                      'All'.tr(),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                  ...state.accounts.map(
                    (a) => DropdownMenuItem<int?>(
                      value: a.id,
                      child: Text(
                        a.name,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ),
                ],
                selectedItemBuilder: (context) => [
                  DropdownMenuItem<int?>(
                    value: null,
                    child: Text(
                      'All'.tr(),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                  ...state.accounts.map(
                    (a) => DropdownMenuItem<int?>(
                      value: a.id,
                      child: Text(
                        a.name,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ),
                ],
                onChanged: (value) =>
                    context.read<DashboardCubit>().setAccount(value),
                style: dropdownTextStyle,
              ),
            ),
          ),
          OutlinedButton(
            onPressed: () => context.read<DashboardCubit>().clearFilters(),
            style: buttonStyle,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.refresh_outlined, size: 20),
                SizedBox(width: veryDense ? 6 : 8),
                Text('Reset'.tr()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
