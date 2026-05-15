import 'dart:async';
import 'dart:developer' as dev;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:clothes_inventory/features/accounts/data/accounts_repository.dart';
import 'package:clothes_inventory/features/products/data/product_repository.dart';
import 'package:clothes_inventory/features/products/domain/product.dart';
import 'package:clothes_inventory/features/invoices/presentation/invoice_print_preview_page.dart';
import 'package:clothes_inventory/features/sales/data/sales_repository.dart';
import 'package:clothes_inventory/features/sales/domain/sale_models.dart';
import 'package:clothes_inventory/features/sales/presentation/sales_cubit.dart';
import 'package:clothes_inventory/features/sales/presentation/widgets/sales_cart_pane.dart';
import 'package:clothes_inventory/features/sales/presentation/widgets/sales_cart_table.dart';
import 'package:clothes_inventory/features/sales/presentation/widgets/sales_cancel_sale_dialog.dart';
import 'package:clothes_inventory/features/sales/presentation/widgets/sales_edit_item_dialog.dart';
import 'package:clothes_inventory/features/sales/presentation/widgets/sales_header_section.dart';
import 'package:clothes_inventory/features/sales/presentation/widgets/sales_invoice_details_dialog.dart';
import 'package:clothes_inventory/features/sales/presentation/widgets/sales_invoices_explorer.dart';
import 'package:clothes_inventory/features/sales/presentation/widgets/sales_products_pane.dart';
import 'package:clothes_inventory/features/sales/presentation/widgets/sales_return_dialog.dart';
import 'package:clothes_inventory/features/license/domain/license_service.dart';
import 'package:clothes_inventory/services/di/service_locator.dart';
import 'package:clothes_inventory/services/printing/a4_invoice_printer.dart';
import 'package:clothes_inventory/services/printing/invoice_print_manager.dart';
import 'package:clothes_inventory/services/printing/thermal_pdf_invoice_printer.dart';
import 'package:clothes_inventory/services/printing/thermal_printer_preferences.dart';
import 'package:clothes_inventory/services/pdf/sales_invoice_pdf_service.dart';

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
