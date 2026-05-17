import 'dart:async';
import 'dart:developer' as dev;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:delta_erp/core/barcode/barcode_pos_input.dart';
import 'package:delta_erp/core/utils/number_utils.dart';
import 'package:delta_erp/features/accounts/data/accounts_repository.dart';
import 'package:delta_erp/features/products/data/product_repository.dart';
import 'package:delta_erp/features/products/domain/product.dart';
import 'package:delta_erp/features/invoices/presentation/invoice_print_preview_page.dart';
import 'package:delta_erp/features/sales/data/sales_repository.dart';
import 'package:delta_erp/features/sales/domain/sale_models.dart';
import 'package:delta_erp/features/sales/presentation/sales_cubit.dart';
import 'package:delta_erp/features/sales/presentation/widgets/sales_cart_pane.dart';
import 'package:delta_erp/features/sales/presentation/widgets/sales_cart_table.dart';
import 'package:delta_erp/features/sales/presentation/widgets/sales_cancel_sale_dialog.dart';
import 'package:delta_erp/features/sales/presentation/widgets/sales_invoice_details_dialog.dart';
import 'package:delta_erp/features/sales/presentation/widgets/sales_invoices_explorer.dart';
import 'package:delta_erp/features/sales/presentation/widgets/sales_checkout_toolbar.dart';
import 'package:delta_erp/features/sales/presentation/widgets/sales_return_dialog.dart';
import 'package:delta_erp/features/license/domain/license_service.dart';
import 'package:delta_erp/services/di/service_locator.dart';
import 'package:delta_erp/services/printing/a4_invoice_printer.dart';
import 'package:delta_erp/services/printing/invoice_print_manager.dart';
import 'package:delta_erp/services/printing/thermal_pdf_invoice_printer.dart';
import 'package:delta_erp/services/printing/thermal_printer_preferences.dart';
import 'package:delta_erp/services/pdf/sales_invoice_pdf_service.dart';

part 'sales_page_state.part.dart';

enum _SalePriceTier { retail, halfWholesale, wholesale }

class SalesPage extends StatefulWidget {
  const SalesPage({
    this.selectedInvoiceId,
    this.fromDate,
    this.toDate,
    this.accountId,
    this.categoryId,
    this.initialInvoicePage = 0,
    this.invoicePageSize = 50,
    this.navSource,
    super.key,
  });

  final int? selectedInvoiceId;
  final DateTime? fromDate;
  final DateTime? toDate;
  final int? accountId;
  final int? categoryId;
  final int initialInvoicePage;
  final int invoicePageSize;
  final String? navSource;

  @override
  State<SalesPage> createState() => _SalesPageState();
}
