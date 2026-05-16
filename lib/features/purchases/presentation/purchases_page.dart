import 'dart:async';
import 'dart:developer' as dev;

import 'package:easy_localization/easy_localization.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:clothes_inventory/core/barcode/barcode_pos_input.dart';
import 'package:clothes_inventory/features/accounts/data/accounts_repository.dart';
import 'package:clothes_inventory/features/invoices/presentation/invoice_print_preview_page.dart';
import 'package:clothes_inventory/features/purchase_ocr/presentation/purchase_ocr_review_page.dart';
import 'package:clothes_inventory/features/products/data/product_repository.dart';
import 'package:clothes_inventory/features/purchases/data/purchases_repository.dart';
import 'package:clothes_inventory/features/purchases/domain/purchase_models.dart';
import 'package:clothes_inventory/features/purchases/presentation/purchases_cubit.dart';
import 'package:clothes_inventory/features/purchases/presentation/utils/purchases_formatters.dart';
import 'package:clothes_inventory/features/purchases/presentation/widgets/purchases_cart_pane.dart';
import 'package:clothes_inventory/features/purchases/presentation/widgets/purchases_cart_table_content.dart';
import 'package:clothes_inventory/features/purchases/presentation/widgets/purchases_cancel_dialog.dart';
import 'package:clothes_inventory/features/purchases/presentation/widgets/purchases_edit_item_dialog.dart';
import 'package:clothes_inventory/features/purchases/presentation/widgets/purchases_checkout_toolbar.dart';
import 'package:clothes_inventory/features/purchases/presentation/widgets/purchases_invoice_details_dialog.dart';
import 'package:clothes_inventory/features/purchases/presentation/widgets/purchases_return_dialog.dart';
import 'package:clothes_inventory/features/purchases/presentation/widgets/purchases_supplier_dialog.dart';
import 'package:clothes_inventory/features/license/domain/license_service.dart';
import 'package:clothes_inventory/services/di/service_locator.dart';
import 'package:clothes_inventory/services/printing/a4_invoice_printer.dart';
import 'package:clothes_inventory/services/printing/invoice_print_manager.dart';
import 'package:clothes_inventory/services/printing/thermal_pdf_invoice_printer.dart';
import 'package:clothes_inventory/services/printing/thermal_printer_preferences.dart';

part 'purchases_page_state.part.dart';

enum _PurchasePaymentStatus { full, partial, deferred }

class PurchasesPage extends StatefulWidget {
  const PurchasesPage({
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
  State<PurchasesPage> createState() => _PurchasesPageState();
}
