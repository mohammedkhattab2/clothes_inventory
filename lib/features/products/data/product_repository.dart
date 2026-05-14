import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import 'package:clothes_inventory/features/products/data/products_import_service.dart';
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
  }) async {
    final db = await _appDatabase.database;

    final where = <String>[];
    final args = <Object?>[];

    if (nameQuery != null && nameQuery.trim().isNotEmpty) {
      where.add('name LIKE ?');
      args.add('%${nameQuery.trim()}%');
    }

    if (barcode != null && barcode.trim().isNotEmpty) {
      where.add('barcode = ?');
      args.add(barcode.trim());
    }

    final whereClause = where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}';
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

  Future<Product> createProduct(Product product) async {
    _ensureWriteAllowed();
    final db = await _appDatabase.database;

    final id = await db.insert('products', {
      ...product.toMap(),
      'created_at': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.abort);

    final created = product.copyWith(id: id);
    _cache[id] = created;
    _notifyProductsChanged();
    return created;
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
            where: 'barcode = ?',
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
            where: 'barcode = ?',
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

    await db.transaction((txn) async {
      final id = await txn.insert('products', {
        ...product.toMap(),
        'created_at': now,
        'updated_at': now,
      }, conflictAlgorithm: ConflictAlgorithm.abort);

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

      created = product.copyWith(id: id);
    });

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

  Future<void> updateProduct(Product product) async {
    _ensureWriteAllowed();
    final id = product.id;
    if (id == null) {
      throw ArgumentError('Product id is required for update.');
    }

    final db = await _appDatabase.database;
    await db.update(
      'products',
      product.toMap()..remove('id'),
      where: 'id = ?',
      whereArgs: [id],
      conflictAlgorithm: ConflictAlgorithm.abort,
    );

    _cache[id] = product;
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
