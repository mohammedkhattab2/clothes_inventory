import 'dart:convert';

import 'package:csv/csv.dart';
import 'package:delta_erp/core/utils/number_utils.dart';
import 'package:delta_erp/features/products/data/products_import_service.dart';
import 'package:delta_erp/features/products/domain/product.dart';
import 'package:spreadsheet_decoder/spreadsheet_decoder.dart';

class InventoryProductsImportIssue {
  const InventoryProductsImportIssue({
    required this.rowNumber,
    required this.message,
  });

  final int rowNumber;
  final String message;
}

class InventoryProductsImportRow {
  const InventoryProductsImportRow({
    required this.product,
    required this.openingQuantity,
  });

  final ProductsImportRow product;
  final double openingQuantity;
}

class InventoryProductsImportParseResult {
  const InventoryProductsImportParseResult({
    required this.rows,
    required this.issues,
    required this.warnings,
    required this.totalRows,
  });

  final List<InventoryProductsImportRow> rows;
  final List<InventoryProductsImportIssue> issues;
  final List<InventoryProductsImportIssue> warnings;
  final int totalRows;

  int get skippedRows => issues.length;
}

class InventoryProductsImportService {
  InventoryProductsImportParseResult parse({
    required List<int> fileBytes,
    required String fileName,
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

    final headerIndex = _findHeaderRowIndex(rows);
    if (headerIndex < 0) {
      throw const FormatException(
        'Missing required columns. Expected Quantity and Name. Barcode is optional.',
      );
    }

    final columns = _resolveHeaderColumns(rows[headerIndex]);
    if (columns.name == null || columns.openingQuantity == null) {
      throw const FormatException(
        'Missing required columns. Expected Quantity and Name. Barcode is optional.',
      );
    }

    return _resolveRows(rows, headerIndex, columns);
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
        .map((row) => row.map(_excelCellToString).toList())
        .toList(growable: false);
  }

  int _findHeaderRowIndex(List<List<String>> rows) {
    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      if (_isRowEmpty(row)) continue;
      final columns = _resolveHeaderColumns(row);
      if (columns.name != null && columns.openingQuantity != null) {
        return i;
      }
    }
    return -1;
  }

  InventoryProductsImportParseResult _resolveRows(
    List<List<String>> rows,
    int headerIndex,
    _HeaderColumns columns,
  ) {
    final issues = <InventoryProductsImportIssue>[];
    final warnings = <InventoryProductsImportIssue>[];
    final resolvedRows = <InventoryProductsImportRow>[];
    final barcodeIndexMap = <String, int>{};
    var totalRows = 0;

    for (var i = headerIndex + 1; i < rows.length; i++) {
      final row = rows[i];
      if (_isRowEmpty(row)) continue;
      totalRows++;

      final rowNumber = i + 1;
      final rawName = _readCell(row, columns.name).trim();
      final rawBarcode = _readCell(row, columns.barcode);
      final rawUnitType = _readCell(row, columns.unitType).trim();
      final rawSalePrice = _readCell(row, columns.salePrice).trim();
      final rawHalfWholesale = _readCell(
        row,
        columns.salePriceHalfWholesale,
      ).trim();
      final rawWholesale = _readCell(row, columns.salePriceWholesale).trim();
      final rawPurchasePrice = _readCell(row, columns.purchasePrice).trim();
      final rawLowStock = _readCell(row, columns.lowStockThreshold).trim();
      final rawOpeningQty = _readCell(row, columns.openingQuantity).trim();
      final purchaseProvided = rawPurchasePrice.isNotEmpty;
      final retailProvided = rawSalePrice.isNotEmpty;
      final halfWholesaleProvided = rawHalfWholesale.isNotEmpty;
      final wholesaleProvided = rawWholesale.isNotEmpty;

      if (rawName.isEmpty) {
        issues.add(
          InventoryProductsImportIssue(
            rowNumber: rowNumber,
            message: 'Name is required for each imported row.',
          ),
        );
        continue;
      }

      final unitType = _parseUnitType(rawUnitType);
      if (unitType == null) {
        issues.add(
          InventoryProductsImportIssue(
            rowNumber: rowNumber,
            message: 'Invalid unit type. Use piece/weight or قطعة/وزن.',
          ),
        );
        continue;
      }

      final salePrice = _parseFlexibleNumber(rawSalePrice, defaultValue: 0);
      final halfWholesale = _parseFlexibleNumber(
        rawHalfWholesale,
        defaultValue: 0,
      );
      final wholesale = _parseFlexibleNumber(rawWholesale, defaultValue: 0);
      final purchasePrice = _parseFlexibleNumber(
        rawPurchasePrice,
        defaultValue: 0,
      );
      final lowStockThreshold = _parseFlexibleNumber(
        rawLowStock,
        defaultValue: 0,
      );
      final openingQty = _parseFlexibleNumber(rawOpeningQty);

      if (salePrice == null) {
        issues.add(
          InventoryProductsImportIssue(
            rowNumber: rowNumber,
            message: 'Invalid retail price.',
          ),
        );
        continue;
      }
      if (halfWholesale == null) {
        issues.add(
          InventoryProductsImportIssue(
            rowNumber: rowNumber,
            message: 'Invalid half wholesale price.',
          ),
        );
        continue;
      }
      if (wholesale == null) {
        issues.add(
          InventoryProductsImportIssue(
            rowNumber: rowNumber,
            message: 'Invalid wholesale price.',
          ),
        );
        continue;
      }
      if (purchasePrice == null) {
        issues.add(
          InventoryProductsImportIssue(
            rowNumber: rowNumber,
            message: 'Invalid purchase price.',
          ),
        );
        continue;
      }
      if (lowStockThreshold == null) {
        issues.add(
          InventoryProductsImportIssue(
            rowNumber: rowNumber,
            message: 'Invalid low stock threshold.',
          ),
        );
        continue;
      }

      if (openingQty == null || openingQty < 0) {
        issues.add(
          InventoryProductsImportIssue(
            rowNumber: rowNumber,
            message: 'Quantity must be zero or greater.',
          ),
        );
        continue;
      }

      if (unitType == UnitType.piece && !isIntegerLike(openingQty)) {
        issues.add(
          InventoryProductsImportIssue(
            rowNumber: rowNumber,
            message: 'Piece products require whole quantity.',
          ),
        );
        continue;
      }

      if (salePrice < 0 ||
          halfWholesale < 0 ||
          wholesale < 0 ||
          purchasePrice < 0 ||
          lowStockThreshold < 0) {
        issues.add(
          InventoryProductsImportIssue(
            rowNumber: rowNumber,
            message: 'Numeric values must be zero or positive.',
          ),
        );
        continue;
      }

      if (purchaseProvided &&
          ((retailProvided && salePrice < purchasePrice) ||
              (halfWholesaleProvided && halfWholesale < purchasePrice) ||
              (wholesaleProvided && wholesale < purchasePrice))) {
        issues.add(
          InventoryProductsImportIssue(
            rowNumber: rowNumber,
            message: 'Sale price cannot be less than purchase price.',
          ),
        );
        continue;
      }

      final normalizedBarcode = _normalizeBarcodeValue(rawBarcode);
      final candidate = InventoryProductsImportRow(
        product: ProductsImportRow(
          name: rawName,
          barcode: normalizedBarcode,
          unitType: unitType,
          salePrice: salePrice,
          salePriceHalfWholesale: halfWholesale,
          salePriceWholesale: wholesale,
          purchasePrice: purchasePrice,
          lowStockThreshold: lowStockThreshold,
        ),
        openingQuantity: unitType == UnitType.piece
            ? openingQty.roundToDouble()
            : openingQty,
      );

      if (normalizedBarcode == null) {
        resolvedRows.add(candidate);
        continue;
      }

      final existingRowIndex = barcodeIndexMap[normalizedBarcode];
      if (existingRowIndex != null) {
        resolvedRows[existingRowIndex] = candidate;
        warnings.add(
          InventoryProductsImportIssue(
            rowNumber: rowNumber,
            message:
                'Duplicate barcode in file. Last row was used for this barcode.',
          ),
        );
        continue;
      }

      barcodeIndexMap[normalizedBarcode] = resolvedRows.length;
      resolvedRows.add(candidate);
    }

    return InventoryProductsImportParseResult(
      rows: resolvedRows,
      issues: issues,
      warnings: warnings,
      totalRows: totalRows,
    );
  }

  _HeaderColumns _resolveHeaderColumns(List<String> headerCells) {
    int? name;
    int? barcode;
    int? unitType;
    int? salePrice;
    int? salePriceHalfWholesale;
    int? salePriceWholesale;
    int? purchasePrice;
    int? lowStockThreshold;
    int? openingQuantity;

    for (var i = 0; i < headerCells.length; i++) {
      final key = _normalizeLookupKey(headerCells[i]);
      if (key.isEmpty) continue;

      if (name == null && _nameAliases.contains(key)) {
        name = i;
        continue;
      }
      if (barcode == null &&
          (_barcodeAliases.contains(key) || _looksLikeBarcodeHeader(key))) {
        barcode = i;
        continue;
      }
      if (unitType == null && _unitTypeAliases.contains(key)) {
        unitType = i;
        continue;
      }
      if (salePrice == null && _salePriceAliases.contains(key)) {
        salePrice = i;
        continue;
      }
      if (salePriceHalfWholesale == null &&
          _salePriceHalfWholesaleAliases.contains(key)) {
        salePriceHalfWholesale = i;
        continue;
      }
      if (salePriceWholesale == null &&
          _salePriceWholesaleAliases.contains(key)) {
        salePriceWholesale = i;
        continue;
      }
      if (purchasePrice == null && _purchasePriceAliases.contains(key)) {
        purchasePrice = i;
        continue;
      }
      if (lowStockThreshold == null &&
          _lowStockThresholdAliases.contains(key)) {
        lowStockThreshold = i;
        continue;
      }
      if (openingQuantity == null && _openingQuantityAliases.contains(key)) {
        openingQuantity = i;
      }
    }

    return _HeaderColumns(
      name: name,
      barcode: barcode,
      unitType: unitType,
      salePrice: salePrice,
      salePriceHalfWholesale: salePriceHalfWholesale,
      salePriceWholesale: salePriceWholesale,
      purchasePrice: purchasePrice,
      lowStockThreshold: lowStockThreshold,
      openingQuantity: openingQuantity,
    );
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

  String _excelCellToString(Object? cell) {
    if (cell == null) return '';
    if (cell is String) return cell.trim();
    if (cell is int) return cell.toString();
    if (cell is double) {
      if (!cell.isFinite) return '';
      final rounded = cell.roundToDouble();
      if ((cell - rounded).abs() < 0.000001) {
        return rounded.toStringAsFixed(0);
      }

      final fixed = cell.toStringAsFixed(12);
      return fixed
          .replaceFirst(RegExp(r'0+$'), '')
          .replaceFirst(RegExp(r'\.$'), '');
    }
    return cell.toString().trim();
  }

  String? _normalizeBarcodeValue(String raw) {
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

    normalized = normalized.replaceAll(RegExp(r'\s+'), '');
    final numericCandidate = normalized
        .replaceAll('٬', '')
        .replaceAll('٫', '.')
        .replaceAll('،', '.')
        .replaceAll(',', '.');

    final parsed = double.tryParse(numericCandidate);
    if (parsed != null && parsed.isFinite) {
      final rounded = parsed.roundToDouble();
      if ((parsed - rounded).abs() < 0.000001) {
        return rounded.toStringAsFixed(0);
      }
    }

    final decimalSuffixMatch = RegExp(
      r'^[0-9]+\.0+$',
    ).firstMatch(numericCandidate);
    if (decimalSuffixMatch != null) {
      return numericCandidate.split('.').first;
    }

    return normalized;
  }

  String _normalizeLookupKey(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\u0600-\u06FF]+'), ' ')
        .replaceAll('/', ' ')
        .replaceAll('_', ' ')
        .replaceAll('-', ' ')
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  bool _looksLikeBarcodeHeader(String key) {
    return key.contains('barcode') ||
        key.contains('bar code') ||
        key.contains('باركود') ||
        key.contains('الباركود') ||
        key.contains('كود');
  }

  UnitType? _parseUnitType(String raw) {
    final key = _normalizeLookupKey(raw);
    if (key.isEmpty) {
      return UnitType.piece;
    }

    if (_pieceAliases.contains(key)) {
      return UnitType.piece;
    }
    if (_weightAliases.contains(key)) {
      return UnitType.weight;
    }
    return null;
  }

  double? _parseFlexibleNumber(String raw, {double? defaultValue}) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return defaultValue;

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

  static const Set<String> _nameAliases = {
    'name',
    'product',
    'product name',
    'item',
    'item name',
    'منتج',
    'المنتج',
    'اسم',
    'الاسم',
    'اسم المنتج',
    'اسم الصنف',
    'الصنف',
  };

  static const Set<String> _barcodeAliases = {
    'barcode',
    'barcode optional',
    'barcode opt',
    'bar code',
    'bar code optional',
    'code',
    'sku',
    'ean',
    'ean 13',
    'باركود',
    'الباركود',
    'باركود اختياري',
    'الباركود اختياري',
    'الباركود (اختياري)',
    'كود',
  };

  static const Set<String> _unitTypeAliases = {
    'unit',
    'unit type',
    'uom',
    'الوحدة',
    'نوع الوحدة',
    'نوع الوحدة قطعة وزن',
  };

  static const Set<String> _salePriceAliases = {
    'sale price',
    'retail price',
    'price',
    'سعر',
    'سعر البيع',
    'سعر التجزئة',
    'سعر البيع تجزئة',
  };

  static const Set<String> _salePriceHalfWholesaleAliases = {
    'half wholesale price',
    'half wholesale',
    'سعر نصف الجملة',
    'نصف جملة',
  };

  static const Set<String> _salePriceWholesaleAliases = {
    'wholesale price',
    'wholesale',
    'سعر الجملة',
    'جملة',
  };

  static const Set<String> _purchasePriceAliases = {
    'purchase price',
    'cost',
    'سعر الشراء',
    'التكلفة',
  };

  static const Set<String> _lowStockThresholdAliases = {
    'low stock threshold',
    'min stock',
    'reorder point',
    'حد المخزون الادنى',
    'حد المخزون الأدنى',
    'حد التنبيه',
  };

  static const Set<String> _openingQuantityAliases = {
    'quantity',
    'purchased quantity',
    'opening quantity',
    'opening qty',
    'initial quantity',
    'qty',
    'quantitiy',
    'الكمية',
    'الكمية المشتراة',
    'الكمية الافتتاحية',
    'كمية افتتاحية',
  };

  static const Set<String> _pieceAliases = {
    'piece',
    'pieces',
    'pcs',
    'unit',
    'count',
    'قطعة',
    'قطع',
    'عدد',
  };

  static const Set<String> _weightAliases = {
    'weight',
    'weighted',
    'kg',
    'كيلو',
    'وزن',
  };
}

class _HeaderColumns {
  const _HeaderColumns({
    required this.name,
    required this.barcode,
    required this.unitType,
    required this.salePrice,
    required this.salePriceHalfWholesale,
    required this.salePriceWholesale,
    required this.purchasePrice,
    required this.lowStockThreshold,
    required this.openingQuantity,
  });

  final int? name;
  final int? barcode;
  final int? unitType;
  final int? salePrice;
  final int? salePriceHalfWholesale;
  final int? salePriceWholesale;
  final int? purchasePrice;
  final int? lowStockThreshold;
  final int? openingQuantity;
}
