import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import 'package:clothes_inventory/features/products/data/products_import_service.dart';
import 'package:clothes_inventory/features/products/domain/duplicate_product_barcode_exception.dart';
import 'package:clothes_inventory/features/products/domain/product.dart';
import 'package:clothes_inventory/services/database/app_database.dart';
import 'package:clothes_inventory/services/database/maintenance_coordinator.dart';

class ProductsImportApplyResult {
  const ProductsImportApplyResult({
    required this.createdCount,
    required this.updatedCount,
  });

  final int createdCount;
  final int updatedCount;
}

class ProductRepository {
  ProductRepository(this._appDatabase, this._maintenanceCoordinator);

  final AppDatabase _appDatabase;
  final MaintenanceCoordinator _maintenanceCoordinator;
  final Map<int, Product> _cache = <int, Product>{};
  final ValueNotifier<int> _productsRevision = ValueNotifier<int>(0);

  ValueListenable<int> get productsRevisionListenable => _productsRevision;

  void _notifyProductsChanged() {
    _productsRevision.value = _productsRevision.value + 1;
  }

  void clearCache() {
    _cache.clear();
  }

  Future<List<Product>> listProducts({
    String? nameQuery,
    String? barcode,
    int? limit,
  }) async {
    final db = await _appDatabase.database;

    final where = <String>[];
    final args = <Object?>[];

    if (nameQuery != null && nameQuery.trim().isNotEmpty) {
      where.add('name LIKE ?');
      args.add('%${nameQuery.trim()}%');
    }

    if (barcode != null && barcode.trim().isNotEmpty) {
      where.add(
        '(p.barcode IS NOT NULL AND LOWER(TRIM(p.barcode)) = LOWER(?))',
      );
      args.add(barcode.trim());
    }

    final whereClause = where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}';
    final limitClause =
        limit != null && limit > 0 ? 'LIMIT ${limit.clamp(1, 10000)}' : '';
    final rows = await db.rawQuery('''
      SELECT
        p.*, 
        MAX(
          0,
          COALESCE(
            SUM(CASE WHEN sm.movement_type = 'in' THEN sm.quantity ELSE 0 END),
            0
          ) - COALESCE(
            SUM(CASE WHEN sm.movement_type = 'out' THEN sm.quantity ELSE 0 END),
            0
          )
        ) AS current_stock
      FROM products p
      LEFT JOIN stock_movements sm ON sm.product_id = p.id
      $whereClause
      GROUP BY p.id
      ORDER BY p.name ASC
      $limitClause
      ''', args);

    final products = rows.map(Product.fromMap).toList();
    for (final product in products) {
      final id = product.id;
      if (id != null) {
        _cache[id] = product;
      }
    }

    return products;
  }

  Future<List<Product>> listProductsByIds(List<int> productIds) async {
    if (productIds.isEmpty) return const <Product>[];

    final db = await _appDatabase.database;
    final placeholders = List.filled(productIds.length, '?').join(',');
    final rows = await db.rawQuery('''
      SELECT
        p.*,
        MAX(
          0,
          COALESCE(
            SUM(CASE WHEN sm.movement_type = 'in' THEN sm.quantity ELSE 0 END),
            0
          ) - COALESCE(
            SUM(CASE WHEN sm.movement_type = 'out' THEN sm.quantity ELSE 0 END),
            0
          )
        ) AS current_stock
      FROM products p
      LEFT JOIN stock_movements sm ON sm.product_id = p.id
      WHERE p.id IN ($placeholders)
      GROUP BY p.id
      ORDER BY p.name ASC
      ''', productIds);

    final products = rows.map(Product.fromMap).toList(growable: false);
    for (final product in products) {
      final id = product.id;
      if (id != null) {
        _cache[id] = product;
      }
    }
    return products;
  }

  static String? _normalizedBarcodeColumn(String? barcode) {
    if (barcode == null) return null;
    final t = barcode.trim();
    return t.isEmpty ? null : t;
  }

  /// Rows for INSERT: omit auto-increment `id` and null columns so sqflite/SQLite
  /// never receive an explicit NULL primary key or stray keys.
  /// Empty barcode is omitted so the DB stores NULL (SQLite allows many NULLs on UNIQUE).
  Map<String, Object?> _insertRowForProduct(Product product) {
    final row = Map<String, Object?>.from(product.toMap())..remove('id');
    final bc = _normalizedBarcodeColumn(product.barcode);
    if (bc == null) {
      row.remove('barcode');
    } else {
      row['barcode'] = bc;
    }
    row.removeWhere((_, v) => v == null);
    return row;
  }

  Map<String, Object?> _updateRowForProduct(Product product) {
    final row = Map<String, Object?>.from(product.toMap())..remove('id');
    row['barcode'] = _normalizedBarcodeColumn(product.barcode);
    return row;
  }

  static bool _isBarcodeUniqueViolation(DatabaseException e) {
    final m = e.toString().toUpperCase();
    return m.contains('UNIQUE') &&
        (m.contains('BARCODE') || m.contains('PRODUCTS.BARCODE'));
  }

  Future<Product> createProduct(Product product) async {
    _ensureWriteAllowed();
    final db = await _appDatabase.database;
    final now = DateTime.now().toIso8601String();
    final row = _insertRowForProduct(product);
    row['created_at'] = now;

    try {
      final id = await db.insert(
        'products',
        row,
        conflictAlgorithm: ConflictAlgorithm.abort,
      );

      final created = product.copyWith(
        id: id,
        barcode: _normalizedBarcodeColumn(product.barcode),
      );
      _cache[id] = created;
      _notifyProductsChanged();
      return created;
    } on DatabaseException catch (e) {
      if (_isBarcodeUniqueViolation(e)) {
        throw const DuplicateProductBarcodeException();
      }
      rethrow;
    }
  }

  Future<ProductsImportApplyResult> upsertImportedProducts({
    required List<ProductsImportRow> rows,
  }) async {
    _ensureWriteAllowed();
    if (rows.isEmpty) {
      return const ProductsImportApplyResult(createdCount: 0, updatedCount: 0);
    }

    final db = await _appDatabase.database;
    var createdCount = 0;
    var updatedCount = 0;

    await db.transaction((txn) async {
      for (final row in rows) {
        final name = row.name.trim();
        if (name.isEmpty) continue;

        final barcode = row.barcode?.trim();
        final normalizedBarcode = (barcode == null || barcode.isEmpty)
            ? null
            : barcode;
        final now = DateTime.now().toIso8601String();

        if (normalizedBarcode != null) {
          final existingByBarcode = await txn.query(
            'products',
            columns: const ['id'],
            where:
                'barcode IS NOT NULL AND LOWER(TRIM(barcode)) = LOWER(?)',
            whereArgs: [normalizedBarcode],
            limit: 1,
          );

          if (createdCount > 0 || updatedCount > 0) {
            _notifyProductsChanged();
          }
          if (existingByBarcode.isNotEmpty) {
            await txn.update(
              'products',
              {
                'name': name,
                'unit_type': row.unitType.name,
                'sale_price': row.salePrice,
                'sale_price_half_wholesale': row.salePriceHalfWholesale,
                'sale_price_wholesale': row.salePriceWholesale,
                'purchase_price': row.purchasePrice,
                'low_stock_threshold': row.lowStockThreshold,
                'updated_at': now,
              },
              where: 'id = ?',
              whereArgs: [existingByBarcode.first['id']],
              conflictAlgorithm: ConflictAlgorithm.abort,
            );
            updatedCount++;
            continue;
          }
        }

        try {
          await txn.insert('products', {
            'name': name,
            'barcode': normalizedBarcode,
            'category_id': null,
            'unit_type': row.unitType.name,
            'sale_price': row.salePrice,
            'sale_price_half_wholesale': row.salePriceHalfWholesale,
            'sale_price_wholesale': row.salePriceWholesale,
            'purchase_price': row.purchasePrice,
            'low_stock_threshold': row.lowStockThreshold,
            'created_at': now,
            'updated_at': now,
          }, conflictAlgorithm: ConflictAlgorithm.abort);
          createdCount++;
        } on DatabaseException catch (_) {
          if (normalizedBarcode == null) rethrow;

          final conflictByBarcode = await txn.query(
            'products',
            columns: const ['id'],
            where:
                'barcode IS NOT NULL AND LOWER(TRIM(barcode)) = LOWER(?)',
            whereArgs: [normalizedBarcode],
            limit: 1,
          );

          if (conflictByBarcode.isEmpty) rethrow;

          await txn.update(
            'products',
            {
              'name': name,
              'unit_type': row.unitType.name,
              'sale_price': row.salePrice,
              'sale_price_half_wholesale': row.salePriceHalfWholesale,
              'sale_price_wholesale': row.salePriceWholesale,
              'purchase_price': row.purchasePrice,
              'low_stock_threshold': row.lowStockThreshold,
              'updated_at': now,
            },
            where: 'id = ?',
            whereArgs: [conflictByBarcode.first['id']],
            conflictAlgorithm: ConflictAlgorithm.abort,
          );
          updatedCount++;
        }
      }
    });

    clearCache();
    return ProductsImportApplyResult(
      createdCount: createdCount,
      updatedCount: updatedCount,
    );
  }

  Future<Product> createProductWithInitialStock(
    Product product, {
    required double initialQuantity,
  }) async {
    _ensureWriteAllowed();
    if (initialQuantity < 0) {
      throw ArgumentError('Quantity must be zero or greater.');
    }

    final isPiece = product.unitType == UnitType.piece;
    final roundedQty = initialQuantity.roundToDouble();
    if (isPiece && (initialQuantity - roundedQty).abs() > 0.000001) {
      throw ArgumentError('Piece products require integer quantity.');
    }

    final db = await _appDatabase.database;
    final now = DateTime.now().toIso8601String();
    final quantity = isPiece ? roundedQty : initialQuantity;
    late final Product created;

    try {
      await db.transaction((txn) async {
        final row = _insertRowForProduct(product);
        row['created_at'] = now;
        row['updated_at'] = now;
        final id = await txn.insert(
          'products',
          row,
          conflictAlgorithm: ConflictAlgorithm.abort,
        );

        if (quantity > 0) {
          // Use purchase/in movement with null invoice to represent opening stock.
          await txn.insert('stock_movements', {
            'product_id': id,
            'invoice_type': 'purchase',
            'invoice_id': null,
            'movement_type': 'in',
            'quantity': quantity,
            'unit_type': product.unitType.name,
            'created_at': now,
          }, conflictAlgorithm: ConflictAlgorithm.abort);
        }

        created = product.copyWith(
          id: id,
          barcode: _normalizedBarcodeColumn(product.barcode),
        );
      });
    } on DatabaseException catch (e) {
      if (_isBarcodeUniqueViolation(e)) {
        throw const DuplicateProductBarcodeException();
      }
      rethrow;
    }

    _cache[created.id!] = created;
    _notifyProductsChanged();
    return created;
  }

  Future<void> addOpeningStockMovement({
    required int productId,
    required UnitType unitType,
    required double quantity,
  }) async {
    _ensureWriteAllowed();
    if (quantity <= 0) {
      throw ArgumentError('Quantity must be greater than zero');
    }

    final roundedQty = quantity.roundToDouble();
    if (unitType == UnitType.piece &&
        (quantity - roundedQty).abs() > 0.000001) {
      throw ArgumentError('Piece products require integer quantity.');
    }

    final db = await _appDatabase.database;
    final now = DateTime.now().toIso8601String();
    await db.insert('stock_movements', {
      'product_id': productId,
      'invoice_type': 'purchase',
      'invoice_id': null,
      'movement_type': 'in',
      'quantity': unitType == UnitType.piece ? roundedQty : quantity,
      'unit_type': unitType.name,
      'created_at': now,
    }, conflictAlgorithm: ConflictAlgorithm.abort);
  }

  Future<String> generateNextBarcodeFromPrefix({
    required String prefix,
    int targetLength = 13,
  }) async {
    final normalized = prefix.trim();
    if (!RegExp(r'^\d{4}$').hasMatch(normalized)) {
      throw ArgumentError('Prefix must be exactly 4 digits.');
    }

    if (targetLength <= normalized.length) {
      throw ArgumentError('Target length must be greater than prefix length.');
    }

    final suffixLength = targetLength - normalized.length;
    final maxSuffix = (pow10(suffixLength) - 1);

    final db = await _appDatabase.database;
    final rows = await db.query(
      'products',
      columns: const ['barcode'],
      where: 'barcode LIKE ?',
      whereArgs: ['$normalized%'],
      orderBy: 'barcode DESC',
    );

    var highest = -1;
    for (final row in rows) {
      final raw = (row['barcode'] as String?)?.trim();
      if (raw == null || raw.length != targetLength) {
        continue;
      }
      if (!raw.startsWith(normalized) || !RegExp(r'^\d+$').hasMatch(raw)) {
        continue;
      }
      final suffix = int.tryParse(raw.substring(normalized.length));
      if (suffix != null && suffix > highest) {
        highest = suffix;
      }
    }

    final next = highest + 1;
    if (next > maxSuffix) {
      throw StateError('Barcode range exhausted for prefix $normalized.');
    }

    return '$normalized${next.toString().padLeft(suffixLength, '0')}';
  }

  /// Short retail barcode: one ASCII letter + exactly 4 digits (e.g. P2000).
  /// Sequence continues from the highest existing code with the same letter, min 2000.
  static const String shortBarcodeLetter = 'P';
  static const int shortBarcodeMinNumeric = 2000;
  static const int shortBarcodeMaxNumeric = 9999;

  Future<String> generateNextShortBarcode({String? letter}) async {
    final raw = (letter ?? shortBarcodeLetter).trim();
    if (raw.length != 1 || !RegExp(r'[A-Za-z]').hasMatch(raw)) {
      throw ArgumentError('Barcode letter must be a single A–Z character.');
    }
    final L = raw.toUpperCase();
    final db = await _appDatabase.database;
    final rows = await db.query('products', columns: const ['barcode']);

    // Highest numeric suffix among L#### (any 4 digits), not capped at min floor,
    // so the next code follows the last matching barcode in the DB.
    var maxNum = -1;
    final pattern = RegExp(
      '^${RegExp.escape(L)}(\\d{4})\$',
      caseSensitive: false,
    );
    for (final row in rows) {
      final rawBarcode = (row['barcode'] as String?)?.trim();
      if (rawBarcode == null || rawBarcode.isEmpty) continue;
      final m = pattern.firstMatch(rawBarcode);
      if (m == null) continue;
      final n = int.tryParse(m.group(1)!);
      if (n != null && n > maxNum) maxNum = n;
    }

    var candidateNum = maxNum + 1;
    if (candidateNum < shortBarcodeMinNumeric) {
      candidateNum = shortBarcodeMinNumeric;
    }
    while (candidateNum <= shortBarcodeMaxNumeric) {
      final candidate = '$L${candidateNum.toString().padLeft(4, '0')}';
      final clash = await db.query(
        'products',
        columns: const ['id'],
        where: 'barcode IS NOT NULL AND LOWER(TRIM(barcode)) = LOWER(?)',
        whereArgs: [candidate],
        limit: 1,
      );
      if (clash.isEmpty) return candidate;
      candidateNum++;
    }
    throw StateError(
      'Short barcode numeric range exhausted ($L$shortBarcodeMinNumeric–$L$shortBarcodeMaxNumeric).',
    );
  }

  int pow10(int exponent) {
    var value = 1;
    for (var i = 0; i < exponent; i++) {
      value *= 10;
    }
    return value;
  }

  Future<void> updateProduct(Product product) async {
    _ensureWriteAllowed();
    final id = product.id;
    if (id == null) {
      throw ArgumentError('Product id is required for update.');
    }

    final db = await _appDatabase.database;
    final row = _updateRowForProduct(product);
    try {
      await db.update(
        'products',
        row,
        where: 'id = ?',
        whereArgs: [id],
        conflictAlgorithm: ConflictAlgorithm.abort,
      );
    } on DatabaseException catch (e) {
      if (_isBarcodeUniqueViolation(e)) {
        throw const DuplicateProductBarcodeException();
      }
      rethrow;
    }

    _cache[id] = product.copyWith(
      barcode: _normalizedBarcodeColumn(product.barcode),
    );
    _notifyProductsChanged();
  }

  Future<void> deleteProduct(int id) async {
    _ensureWriteAllowed();
    final db = await _appDatabase.database;
    final saleItemRefs = Sqflite.firstIntValue(
      await db.rawQuery(
        'SELECT COUNT(1) AS c FROM sale_items WHERE product_id = ?',
        [id],
      ),
    );
    final purchaseItemRefs = Sqflite.firstIntValue(
      await db.rawQuery(
        'SELECT COUNT(1) AS c FROM purchase_items WHERE product_id = ?',
        [id],
      ),
    );
    final stockMovementRefs = Sqflite.firstIntValue(
      await db.rawQuery(
        '''
        SELECT COUNT(1) AS c
        FROM stock_movements
        WHERE product_id = ? AND invoice_id IS NOT NULL
        ''',
        [id],
      ),
    );

    if ((saleItemRefs ?? 0) > 0 ||
        (purchaseItemRefs ?? 0) > 0 ||
        (stockMovementRefs ?? 0) > 0) {
      final reasons = <String>[];
      if ((saleItemRefs ?? 0) > 0) {
        reasons.add('sales (${saleItemRefs ?? 0})');
      }
      if ((purchaseItemRefs ?? 0) > 0) {
        reasons.add('purchases (${purchaseItemRefs ?? 0})');
      }
      if ((stockMovementRefs ?? 0) > 0) {
        reasons.add('stock movements (${stockMovementRefs ?? 0})');
      }
      throw StateError(
        'Cannot delete product because it is linked to ${reasons.join(', ')}.',
      );
    }

    try {
      await db.transaction((txn) async {
        // Cleanup auxiliary references so delete doesn't fail for unused products.
        await txn.delete(
          'user_correction_patterns',
          where: 'suggested_product_id = ? OR selected_product_id = ?',
          whereArgs: [id, id],
        );
        await txn.delete(
          'ocr_product_mappings',
          where: 'product_id = ?',
          whereArgs: [id],
        );
        await txn.delete(
          'product_price_history',
          where: 'product_id = ?',
          whereArgs: [id],
        );
        await txn.delete(
          'stock_movements',
          where: 'product_id = ? AND invoice_id IS NULL',
          whereArgs: [id],
        );
        await txn.delete('products', where: 'id = ?', whereArgs: [id]);
      });
      _cache.remove(id);
      _notifyProductsChanged();
    } on DatabaseException catch (e) {
      if (e.toString().contains('FOREIGN KEY constraint failed')) {
        throw StateError(
          'Cannot delete product because it is linked to sales/purchases history.',
        );
      }
      rethrow;
    }
  }

  void _ensureWriteAllowed() {
    if (_maintenanceCoordinator.isMaintenanceMode) {
      throw StateError('Database write is blocked during maintenance mode.');
    }
  }

  Future<double> getCurrentStock(int productId) async {
    final db = await _appDatabase.database;
    final rows = await db.rawQuery(
      '''
      SELECT
        MAX(
          0,
          COALESCE(SUM(CASE WHEN movement_type = 'in' THEN quantity ELSE 0 END), 0) -
          COALESCE(SUM(CASE WHEN movement_type = 'out' THEN quantity ELSE 0 END), 0)
        ) AS stock
      FROM stock_movements
      WHERE product_id = ?
      ''',
      [productId],
    );

    if (rows.isEmpty) return 0;
    return ((rows.first['stock'] ?? 0) as num).toDouble();
  }
}
