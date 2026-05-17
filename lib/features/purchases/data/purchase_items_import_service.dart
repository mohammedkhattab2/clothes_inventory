import 'dart:convert';

import 'package:csv/csv.dart';
import 'package:delta_erp/core/utils/number_utils.dart';
import 'package:delta_erp/features/products/domain/product.dart';
import 'package:spreadsheet_decoder/spreadsheet_decoder.dart';

class PurchaseImportIssue {
  const PurchaseImportIssue({required this.rowNumber, required this.message});

  final int rowNumber;
  final String message;
}

class PurchaseImportLine {
  const PurchaseImportLine({
    required this.product,
    required this.quantity,
    required this.unitPrice,
    required this.discount,
  });

  final Product product;
  final double quantity;
  final double unitPrice;
  final double discount;
}

class PurchaseImportResult {
  const PurchaseImportResult({
    required this.lines,
    required this.issues,
    required this.warnings,
    required this.totalRows,
  });

  final List<PurchaseImportLine> lines;
  final List<PurchaseImportIssue> issues;
  final List<PurchaseImportIssue> warnings;
  final int totalRows;

  int get addedRows => lines.length;
  int get skippedRows => issues.length;
}

class PurchaseItemsImportService {
  PurchaseImportResult parseAndResolve({
    required List<int> fileBytes,
    required String fileName,
    required List<Product> products,
  }) {
    final extension = _extractExtension(fileName).toLowerCase();
    final rows = switch (extension) {
      'csv' => _parseCsvRows(fileBytes),
      'xlsx' || 'xls' => _parseExcelRows(fileBytes),
      _ => throw StateError('Unsupported file type: .$extension'),
    };

    if (rows.isEmpty) {
      throw const FormatException('The selected file is empty.');
    }

    final resolved = _resolveRows(rows: rows, products: products);
    return resolved;
  }

  List<List<String>> _parseCsvRows(List<int> bytes) {
    final decoded = utf8.decode(bytes, allowMalformed: true);
    final rows = const CsvToListConverter(
      shouldParseNumbers: false,
      eol: '\n',
    ).convert(decoded);
    return rows
        .map(
          (row) => row.map((cell) => (cell ?? '').toString().trim()).toList(),
        )
        .toList(growable: false);
  }

  List<List<String>> _parseExcelRows(List<int> bytes) {
    final decoder = SpreadsheetDecoder.decodeBytes(bytes, update: false);
    if (decoder.tables.isEmpty) return const <List<String>>[];

    final firstTable = decoder.tables.values.firstWhere(
      (table) => table.rows.isNotEmpty,
      orElse: () => decoder.tables.values.first,
    );

    return firstTable.rows
        .map(
          (row) => row.map((cell) => (cell ?? '').toString().trim()).toList(),
        )
        .toList(growable: false);
  }

  PurchaseImportResult _resolveRows({
    required List<List<String>> rows,
    required List<Product> products,
  }) {
    final headerIndex = _findHeaderRowIndex(rows);
    if (headerIndex < 0) {
      throw const FormatException(
        'Missing required columns. Expected Quantity and Name. Barcode is optional.',
      );
    }

    final header = rows[headerIndex];
    final columns = _resolveHeaderColumns(header);
    if (columns.quantity == null || columns.name == null) {
      throw const FormatException(
        'Missing required columns. Expected Quantity and Name. Barcode is optional.',
      );
    }

    final barcodeMap = <String, Product>{};
    final nameMap = <String, List<Product>>{};
    for (final product in products) {
      final barcode = (product.barcode ?? '').trim();
      if (barcode.isNotEmpty) {
        barcodeMap[barcode] = product;
      }

      final normalizedName = _normalizeLookupKey(product.name);
      if (normalizedName.isNotEmpty) {
        nameMap.putIfAbsent(normalizedName, () => <Product>[]).add(product);
      }
    }

    final issues = <PurchaseImportIssue>[];
    final warnings = <PurchaseImportIssue>[];
    final aggregated = <int, _AggregatedImportLine>{};
    var totalRows = 0;

    for (var i = headerIndex + 1; i < rows.length; i++) {
      final row = rows[i];
      if (_isRowEmpty(row)) continue;
      totalRows++;

      final rowNumber = i + 1;
      final barcode = _readCell(row, columns.barcode).trim();
      final productName = _readCell(row, columns.name).trim();
      final qtyRaw = _readCell(row, columns.quantity).trim();
      final unitPriceRaw = _readCell(row, columns.unitPrice).trim();
      final discountRaw = _readCell(row, columns.discount).trim();

      final normalizedName = _normalizeLookupKey(productName);
      if (barcode.isEmpty && normalizedName.isNotEmpty) {
        final candidates = nameMap[normalizedName];
        if (candidates != null && candidates.length > 1) {
          issues.add(
            PurchaseImportIssue(
              rowNumber: rowNumber,
              message:
                  'Ambiguous product name. Please provide barcode for exact match.',
            ),
          );
          continue;
        }
      }

      final product = _resolveProduct(
        barcode: barcode,
        productName: productName,
        barcodeMap: barcodeMap,
        nameMap: nameMap,
      );
      if (product == null) {
        issues.add(
          PurchaseImportIssue(
            rowNumber: rowNumber,
            message: 'Unknown product (barcode/name not found).',
          ),
        );
        continue;
      }

      final quantity = _parseFlexibleNumber(qtyRaw);
      if (quantity == null || quantity <= 0) {
        issues.add(
          PurchaseImportIssue(
            rowNumber: rowNumber,
            message: 'Invalid quantity. Quantity must be a positive number.',
          ),
        );
        continue;
      }

      if (product.unitType == UnitType.piece && !isIntegerLike(quantity)) {
        issues.add(
          PurchaseImportIssue(
            rowNumber: rowNumber,
            message: 'Piece products require whole quantity.',
          ),
        );
        continue;
      }

      final unitPrice = unitPriceRaw.isEmpty
          ? product.purchasePrice
          : _parseFlexibleNumber(unitPriceRaw);
      if (unitPrice == null || unitPrice < 0) {
        issues.add(
          PurchaseImportIssue(
            rowNumber: rowNumber,
            message: 'Invalid unit price. Unit price must be zero or positive.',
          ),
        );
        continue;
      }

      final discount = discountRaw.isEmpty
          ? 0.0
          : _parseFlexibleNumber(discountRaw);
      if (discount == null || discount < 0) {
        issues.add(
          PurchaseImportIssue(
            rowNumber: rowNumber,
            message: 'Invalid discount. Discount must be zero or positive.',
          ),
        );
        continue;
      }

      final lineTotal = quantity * unitPrice;
      if (discount > lineTotal + 0.000001) {
        issues.add(
          PurchaseImportIssue(
            rowNumber: rowNumber,
            message: 'Discount exceeds line total.',
          ),
        );
        continue;
      }

      final productId = product.id;
      if (productId == null) {
        issues.add(
          PurchaseImportIssue(
            rowNumber: rowNumber,
            message: 'Product has no valid ID in local database.',
          ),
        );
        continue;
      }

      final existing = aggregated[productId];
      if (existing == null) {
        aggregated[productId] = _AggregatedImportLine(
          product: product,
          quantity: roundQuantity(quantity),
          unitPrice: roundCurrency(unitPrice),
          discount: roundCurrency(discount),
        );
        continue;
      }

      existing.quantity = roundQuantity(existing.quantity + quantity);
      existing.discount = roundCurrency(existing.discount + discount);
      final roundedPrice = roundCurrency(unitPrice);
      if ((existing.unitPrice - roundedPrice).abs() > 0.000001) {
        warnings.add(
          PurchaseImportIssue(
            rowNumber: rowNumber,
            message:
                'Duplicate product with different price. Last imported price was applied.',
          ),
        );
      }
      existing.unitPrice = roundedPrice;
    }

    final lines = aggregated.values
        .map(
          (line) => PurchaseImportLine(
            product: line.product,
            quantity: line.quantity,
            unitPrice: line.unitPrice,
            discount: line.discount,
          ),
        )
        .toList(growable: false);

    return PurchaseImportResult(
      lines: lines,
      issues: issues,
      warnings: warnings,
      totalRows: totalRows,
    );
  }

  int _findHeaderRowIndex(List<List<String>> rows) {
    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      if (_isRowEmpty(row)) continue;
      final columns = _resolveHeaderColumns(row);
      if (columns.quantity != null && columns.name != null) {
        return i;
      }
    }
    return -1;
  }

  _HeaderColumns _resolveHeaderColumns(List<String> headerCells) {
    int? barcode;
    int? name;
    int? quantity;
    int? unitPrice;
    int? discount;

    for (var i = 0; i < headerCells.length; i++) {
      final key = _normalizeLookupKey(headerCells[i]);
      if (key.isEmpty) continue;

      if (barcode == null && _barcodeAliases.contains(key)) {
        barcode = i;
        continue;
      }
      if (name == null && _nameAliases.contains(key)) {
        name = i;
        continue;
      }
      if (quantity == null && _quantityAliases.contains(key)) {
        quantity = i;
        continue;
      }
      if (unitPrice == null && _unitPriceAliases.contains(key)) {
        unitPrice = i;
        continue;
      }
      if (discount == null && _discountAliases.contains(key)) {
        discount = i;
      }
    }

    return _HeaderColumns(
      barcode: barcode,
      name: name,
      quantity: quantity,
      unitPrice: unitPrice,
      discount: discount,
    );
  }

  Product? _resolveProduct({
    required String barcode,
    required String productName,
    required Map<String, Product> barcodeMap,
    required Map<String, List<Product>> nameMap,
  }) {
    if (barcode.isNotEmpty) {
      final byBarcode = barcodeMap[barcode];
      if (byBarcode != null) return byBarcode;
    }

    final normalizedName = _normalizeLookupKey(productName);
    if (normalizedName.isEmpty) {
      return null;
    }
    final candidates = nameMap[normalizedName];
    if (candidates == null || candidates.isEmpty) {
      return null;
    }

    if (candidates.length == 1) {
      return candidates.first;
    }

    return null;
  }

  String _extractExtension(String fileName) {
    final normalized = fileName.trim();
    final dotIndex = normalized.lastIndexOf('.');
    if (dotIndex < 0 || dotIndex == normalized.length - 1) {
      return '';
    }
    return normalized.substring(dotIndex + 1);
  }

  String _readCell(List<String> row, int? columnIndex) {
    if (columnIndex == null || columnIndex < 0 || columnIndex >= row.length) {
      return '';
    }
    return row[columnIndex];
  }

  bool _isRowEmpty(List<String> row) {
    for (final cell in row) {
      if (cell.trim().isNotEmpty) {
        return false;
      }
    }
    return true;
  }

  String _normalizeLookupKey(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll('_', ' ')
        .replaceAll('-', ' ')
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  double? _parseFlexibleNumber(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;

    const arabicIndicDigits = {
      '٠': '0',
      '١': '1',
      '٢': '2',
      '٣': '3',
      '٤': '4',
      '٥': '5',
      '٦': '6',
      '٧': '7',
      '٨': '8',
      '٩': '9',
    };

    var normalized = trimmed;
    arabicIndicDigits.forEach((key, value) {
      normalized = normalized.replaceAll(key, value);
    });

    normalized = normalized
        .replaceAll('٬', '')
        .replaceAll('٫', '.')
        .replaceAll('،', '.')
        .replaceAll(',', '.');

    return double.tryParse(normalized);
  }

  static const Set<String> _barcodeAliases = {
    'barcode',
    'barcode optional',
    'barcode (optional)',
    'bar code',
    'code',
    'sku',
    'barcodes',
    'باركود',
    'الباركود',
    'الباركود اختياري',
    'الباركود (اختياري)',
    'كود',
  };

  static const Set<String> _nameAliases = {
    'name',
    'product',
    'product name',
    'item',
    'item name',
    'منتج',
    'المنتج',
    'اسم المنتج',
    'اسم',
    'الاسم',
    'اسم الصنف',
    'الصنف',
  };

  static const Set<String> _quantityAliases = {
    'quantity',
    'quantitiy',
    'purchased quantity',
    'qty',
    'qnt',
    'quant',
    'الكمية المشتراة',
    'الكمية',
    'كمية',
  };

  static const Set<String> _unitPriceAliases = {
    'unit price',
    'price',
    'purchase price',
    'cost',
    'unit cost',
    'سعر',
    'سعر الوحدة',
    'سعر الشراء',
  };

  static const Set<String> _discountAliases = {
    'discount',
    'disc',
    'خصم',
    'الخصم',
  };
}

class _HeaderColumns {
  const _HeaderColumns({
    required this.barcode,
    required this.name,
    required this.quantity,
    required this.unitPrice,
    required this.discount,
  });

  final int? barcode;
  final int? name;
  final int? quantity;
  final int? unitPrice;
  final int? discount;
}

class _AggregatedImportLine {
  _AggregatedImportLine({
    required this.product,
    required this.quantity,
    required this.unitPrice,
    required this.discount,
  });

  final Product product;
  double quantity;
  double unitPrice;
  double discount;
}
