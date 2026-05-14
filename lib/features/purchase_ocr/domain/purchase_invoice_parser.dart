import 'package:clothes_inventory/core/utils/number_utils.dart';
import 'package:clothes_inventory/features/purchase_ocr/domain/purchase_ocr_models.dart';

class PurchaseInvoiceParser {
  const PurchaseInvoiceParser();

  static const List<String> suggestedItemAliases = <String>[
    'item',
    'item name',
    'product',
    'product name',
    'description',
    'name',
    'الصنف',
    'اسم الصنف',
    'اسم المنتج',
    'المنتج',
    'البيان',
    'الوصف',
  ];

  static const List<String> suggestedQuantityAliases = <String>[
    'qty',
    'quantity',
    'q',
    'count',
    'cnt',
    'pcs',
    'piece',
    'no.',
    'عدد',
    'العدد',
    'كمية',
    'الكمية',
    'كميه',
    'عدد القطع',
  ];

  static const List<String> suggestedUnitPriceAliases = <String>[
    'price',
    'unit price',
    'rate',
    'cost',
    'unit cost',
    'سعر',
    'سعر الوحدة',
    'سعر الوحده',
    'سعر القطعة',
    'ثمن',
    'قيمة الوحدة',
  ];

  static const List<String> suggestedInvoiceTotalAliases = <String>[
    'grand total',
    'invoice total',
    'total amount',
    'net total',
    'total due',
    'amount due',
    'payable amount',
    'الاجمالي',
    'الإجمالي',
    'اجمالي',
    'إجمالي',
    'الإجمالي النهائي',
    'الاجمالي النهائي',
    'الإجمالي الكلي',
    'الاجمالي الكلي',
    'الإجمالي المستحق',
    'الاجمالي المستحق',
    'المجموع',
    'الصافي',
  ];

  static const String _itemKeywordPattern =
      r'(?:item(?:\s*name)?|product(?:\s*name)?|description|name|الصنف|اسم\s*الصنف|اسم\s*المنتج|المنتج|البيان|الوصف)';
  static const String _quantityKeywordPattern =
      r'(?:qty|quantity|q|count|cnt|pcs|piece|no\.?|عدد|العدد|كمية|الكمية|كميه|عدد\s*القطع)';
  static const String _unitPriceKeywordPattern =
      r'(?:price|unit\s*price|rate|cost|unit\s*cost|سعر|سعر\s*الوحدة|سعر\s*الوحده|سعر\s*القطعة|ثمن|قيمة\s*الوحدة)';
  static const String _lineTotalKeywordPattern =
      r'(?:line\s*total|item\s*total|amount|total|إجمالي\s*السطر|اجمالي\s*السطر|الإجمالي\s*الجزئي|اجمالي\s*البند|المبلغ)';
  static const String _quantityUnitKeywordPattern =
      r'(?:carton|cartons|ctn|box|pack|pcs?|pieces?|bottle|jar|bag|roll|packet|unit|كرتون(?:ة|ه)?|قطعة|قطعه|زجاجة|زجاجه|كيس|فوطة|فوطه|رول|عبوة|عبوه|علبة|علبه|حبة|حبه)';
  static const String _invoiceTotalKeywordPattern =
      r'(?:grand\s*total|invoice\s*total|total\s*amount|net\s*total|total\s*due|amount\s*due|payable\s*amount|الاجمالي|الإجمالي|اجمالي|إجمالي|الإجمالي\s*النهائي|الاجمالي\s*النهائي|الإجمالي\s*الكلي|الاجمالي\s*الكلي|المجموع|الصافي|الإجمالي\s*المستحق|الاجمالي\s*المستحق)';

  static final RegExp _lineBreaks = RegExp(r'\r\n?|\n');
  static final RegExp _multiSpace = RegExp(r'[ \t]+');
  static final RegExp _supplierPrefix = RegExp(
    r'^(supplier|vendor|from|supplier name|المورد|اسم المورد|شركة)\s*[:\-]?\s*(.+)$',
    caseSensitive: false,
  );
  static final RegExp _totalPattern = RegExp(
    '($_invoiceTotalKeywordPattern)\\s*[:\\-]?\\s*([0-9٠-٩.,٫٬]+)',
    caseSensitive: false,
  );
  static final RegExp _totalKeywordPattern = RegExp(
    '($_invoiceTotalKeywordPattern|\\btotal\\b)',
    caseSensitive: false,
  );
  static final RegExp _numberPattern = RegExp(r'([0-9٠-٩][0-9٠-٩.,٫٬]*)');
  static final RegExp _alphaPattern = RegExp(r'[A-Za-z\u0600-\u06FF]');
  static final RegExp _dateHintPattern = RegExp(
    r'(date|invoice\s*date|التاريخ|تاريخ)',
    caseSensitive: false,
  );
  static final RegExp _nonItemMetadataPattern = RegExp(
    r'(\bmobile\b|\bphone\b|\btel\b|\bsupplier\b|\bvendor\b|\binvoice\b|\btax\b|\bvat\b|\bcommercial\b|\breg\b|'
    r'المحمول|موبايل|هاتف|تليفون|سجل\s*التجاري|السجل\s*التجاري|'
    r'بطاق(?:ه|ة)\s*الضريبي(?:ه|ة)|الضريبي(?:ه|ة)|اسم\s*العميل|العميل|'
    r'فاتور(?:ه|ة)|تاريخ|التاريخ|شركة)',
    caseSensitive: false,
  );
  static final RegExp _standaloneProductHintPattern = RegExp(
    r'(مسحوق|صابون|شامبو|منظف|ملمع|قشاط(?:ه|ة)|اكياس|أكياس|ديتول|لوكس|'
    r'تايد|فانيش|هاريبك|اوكسي|كاسات|ملي|لتر|جرام|اونص|سم|كرتون|'
    r'فونيك|جلي|اسفنج|إسفنج|مكنس(?:ه|ة)|بلباص|ستريس|داوني|مناديل|معطر|'
    r'عصا|حمامات|مطبخ|اسود|أسود|تقيل|ثقيل|'
    r'bag|bags|detergent|soap|shampoo|cleaner|glass|wipes|roll)',
    caseSensitive: false,
  );
  static final RegExp _nonItemFooterPattern = RegExp(
    r'(thank\s*you|thanks|best\s*regards|اسم\s*العميل|customer)',
    caseSensitive: false,
  );
  static const String _signedNumberPattern =
      r'-?(?:\d{1,3}(?:[.,]\d{3})+|\d+)(?:[.,]\d+)?';

  String normalizeText(String rawText) {
    final lines = rawText
        .replaceAll('\u00A0', ' ')
        .split(_lineBreaks)
        .map(_normalizeLine)
        .where((line) => line.isNotEmpty)
        .toList(growable: false);
    return lines.join('\n');
  }

  PurchaseOcrDraft parse({required String rawText, required String imagePath}) {
    final normalized = normalizeText(rawText);
    final lines = normalized.split('\n');

    String? supplier;
    OcrConfidence? supplierConfidence;
    DateTime? invoiceDate;
    double? totalAmount;
    OcrConfidence? totalAmountConfidence;
    List<PurchaseOcrLineItemDraft> items = const <PurchaseOcrLineItemDraft>[];

    try {
      final scoredSupplier = _extractSupplier(lines);
      supplier = scoredSupplier?.value;
      supplierConfidence = scoredSupplier?.confidence;
    } catch (_) {
      supplier = null;
      supplierConfidence = null;
    }

    try {
      invoiceDate = _extractDate(lines);
    } catch (_) {
      invoiceDate = null;
    }

    try {
      final scoredTotal = _extractTotal(lines, normalized);
      totalAmount = scoredTotal?.value;
      totalAmountConfidence = scoredTotal?.confidence;
    } catch (_) {
      totalAmount = null;
      totalAmountConfidence = null;
    }

    try {
      items = _extractItems(lines);
    } catch (_) {
      items = const <PurchaseOcrLineItemDraft>[];
    }

    return PurchaseOcrDraft(
      rawText: rawText,
      normalizedText: normalized,
      imagePath: imagePath,
      supplierName: supplier,
      supplierConfidence: supplierConfidence,
      invoiceDate: invoiceDate,
      totalAmount: totalAmount,
      totalAmountConfidence: totalAmountConfidence,
      items: items,
    );
  }

  String _normalizeLine(String input) {
    var line = input.trim();
    line = line.replaceAll(RegExp(r'[•·]'), ' ');
    line = line.replaceAll(RegExp(r'[_=]{2,}'), ' ');
    line = line.replaceAll(RegExp(r'\|'), ' ');
    line = line.replaceAll(_multiSpace, ' ');
    return line.trim();
  }

  _ScoredValue<String>? _extractSupplier(List<String> lines) {
    for (final line in lines) {
      final match = _supplierPrefix.firstMatch(line);
      if (match != null) {
        final value = (match.group(2) ?? '').trim();
        if (value.isNotEmpty) {
          return _ScoredValue(value: value, confidence: OcrConfidence.high);
        }
      }
    }

    return null;
  }

  DateTime? _extractDate(List<String> lines) {
    final datePatterns = <RegExp>[
      RegExp(r'\b(\d{4}[\/-][01]?\d[\/-][0-3]?\d)\b'),
      RegExp(r'\b([0-3]?\d[\/-][01]?\d[\/-](?:20)?\d{2})\b'),
      RegExp(r'\b([0-3]?\d\.[01]?\d\.(?:20)?\d{2})\b'),
    ];

    for (final line in lines) {
      if (!_dateHintPattern.hasMatch(line) &&
          !line.contains('/') &&
          !line.contains('-') &&
          !line.contains('.')) {
        continue;
      }

      for (final pattern in datePatterns) {
        final match = pattern.firstMatch(_normalizeDigits(line));
        if (match == null) continue;
        final parsed = _tryParseDate(match.group(1)!);
        if (parsed != null) {
          return parsed;
        }
      }
    }

    return null;
  }

  DateTime? _tryParseDate(String raw) {
    final value = raw.replaceAll('.', '/').replaceAll('-', '/');
    final parts = value.split('/');
    if (parts.length != 3) return null;

    int first = int.tryParse(parts[0]) ?? -1;
    int second = int.tryParse(parts[1]) ?? -1;
    int third = int.tryParse(parts[2]) ?? -1;
    if (first < 0 || second < 0 || third < 0) return null;

    if (parts[0].length == 4) {
      final candidate = DateTime.tryParse(
        '$first-${_twoDigits(second)}-${_twoDigits(third)}',
      );
      if (candidate != null) {
        return DateTime(candidate.year, candidate.month, candidate.day);
      }
      return null;
    }

    if (third < 100) {
      third += 2000;
    }

    DateTime? parsed;

    if (first > 12) {
      parsed = DateTime.tryParse(
        '$third-${_twoDigits(second)}-${_twoDigits(first)}',
      );
    } else if (second > 12) {
      parsed = DateTime.tryParse(
        '$third-${_twoDigits(first)}-${_twoDigits(second)}',
      );
    } else {
      parsed = DateTime.tryParse(
        '$third-${_twoDigits(second)}-${_twoDigits(first)}',
      );
      parsed ??= DateTime.tryParse(
        '$third-${_twoDigits(first)}-${_twoDigits(second)}',
      );
    }

    if (parsed == null) return null;
    return DateTime(parsed.year, parsed.month, parsed.day);
  }

  String _twoDigits(int value) => value.toString().padLeft(2, '0');

  _ScoredValue<double>? _extractTotal(
    List<String> lines,
    String normalizedText,
  ) {
    for (final line in lines.reversed) {
      final normalizedLine = _normalizeDigits(line);
      if (!_totalKeywordPattern.hasMatch(normalizedLine)) {
        continue;
      }

      final directMatch = _totalPattern.firstMatch(normalizedLine);
      if (directMatch != null) {
        final direct = _parseNumber(directMatch.group(2));
        if (direct != null && direct >= 0) {
          return _ScoredValue(value: direct, confidence: OcrConfidence.high);
        }
      }

      final matches = _numberPattern
          .allMatches(normalizedLine)
          .map((m) => _parseNumber(m.group(1)))
          .whereType<double>()
          .where((value) => value >= 0)
          .toList(growable: false);
      if (matches.isNotEmpty) {
        return _ScoredValue(
          value: matches.last,
          confidence: OcrConfidence.medium,
        );
      }
    }

    final match = _totalPattern.firstMatch(_normalizeDigits(normalizedText));
    if (match == null) return null;
    final value = _parseNumber(match.group(2));
    if (value == null || value < 0) return null;
    return _ScoredValue(value: value, confidence: OcrConfidence.low);
  }

  List<PurchaseOcrLineItemDraft> _extractItems(List<String> lines) {
    final items = <PurchaseOcrLineItemDraft>[];
    final consumedIndexes = <int>{};
    var inItemSection = false;

    for (var i = 0; i < lines.length; i++) {
      if (consumedIndexes.contains(i)) {
        continue;
      }

      final line = lines[i];
      if (_isItemSectionHeader(line)) {
        inItemSection = true;
        continue;
      }
      if (_isItemSectionTerminator(line)) {
        inItemSection = false;
        continue;
      }

      if (_isLikelyHeaderOrFooter(line)) {
        continue;
      }

      final parsed = _tryParseItemLine(line);
      if (parsed != null) {
        items.add(parsed);
        consumedIndexes.add(i);
        continue;
      }

      // Some OCR layouts split table rows into two lines:
      // line N: product name only, line N+1: quantity + price.
      final paired = _tryParseSplitRow(lines, i, consumedIndexes);
      if (paired != null) {
        items.add(paired);
        continue;
      }

      final standalone = _tryParseStandaloneItemLine(
        lines,
        i,
        inItemSection: inItemSection,
      );
      if (standalone != null) {
        items.add(standalone);
        consumedIndexes.add(i);
      }
    }

    return items;
  }

  bool _isItemSectionHeader(String line) {
    final normalized = _normalizeDigits(line).trim();
    return RegExp(
      r'^(?:الصنف|اسم\s*الصنف|item|items|product|description)$',
      caseSensitive: false,
    ).hasMatch(normalized);
  }

  bool _isItemSectionTerminator(String line) {
    final normalized = _normalizeDigits(line).trim();
    return RegExp(
      r'(?:اسم\s*العميل|customer\s*name)',
      caseSensitive: false,
    ).hasMatch(normalized);
  }

  PurchaseOcrLineItemDraft? _tryParseSplitRow(
    List<String> lines,
    int index,
    Set<int> consumedIndexes,
  ) {
    if (index < 0 || index >= lines.length - 1) {
      return null;
    }

    final current = _stripTrailingCurrencyTokens(
      _normalizeDigits(lines[index]),
    );
    final next = _stripTrailingCurrencyTokens(
      _normalizeDigits(lines[index + 1]),
    );

    if (_isLikelyHeaderOrFooter(current) || _isLikelyHeaderOrFooter(next)) {
      return null;
    }

    final currentHasAlpha = _alphaPattern.hasMatch(current);
    final currentHasNumber = _numberPattern.hasMatch(current);
    final nextHasAlpha = _alphaPattern.hasMatch(next);

    if (!currentHasAlpha || currentHasNumber || nextHasAlpha) {
      return null;
    }

    final numbers = RegExp(_signedNumberPattern)
        .allMatches(next)
        .map((m) => _parseNumber(m.group(0)))
        .whereType<double>()
        .toList(growable: false);

    if (numbers.length < 2) {
      return null;
    }

    final paired = _buildItem(
      name: current,
      quantity: numbers[0],
      unitPrice: numbers[1],
      confidence: OcrConfidence.low,
    );

    if (paired != null) {
      consumedIndexes.add(index);
      consumedIndexes.add(index + 1);
    }

    return paired;
  }

  bool _isLikelyHeaderOrFooter(String line) {
    if (line.length < 3) return true;
    final lower = line.toLowerCase();
    if (lower.contains('invoice') && !lower.contains('item')) return true;
    if (_totalKeywordPattern.hasMatch(lower)) return true;
    if (_totalPattern.hasMatch(lower)) return true;
    if (_supplierPrefix.hasMatch(lower)) return true;
    if (_dateHintPattern.hasMatch(lower)) return true;
    final keywordOnlyLine = RegExp(
      '$_quantityKeywordPattern|$_unitPriceKeywordPattern|$_itemKeywordPattern|$_lineTotalKeywordPattern',
      caseSensitive: false,
    ).hasMatch(lower);
    if (keywordOnlyLine &&
        !_numberPattern.hasMatch(lower) &&
        line.length <= 40) {
      return true;
    }

    final headerHits = RegExp(
      '$_itemKeywordPattern|$_quantityKeywordPattern|$_unitPriceKeywordPattern|$_lineTotalKeywordPattern',
      caseSensitive: false,
    ).allMatches(lower).length;
    if (headerHits >= 2 && !_numberPattern.hasMatch(lower)) {
      return true;
    }

    return false;
  }

  PurchaseOcrLineItemDraft? _tryParseItemLine(String rawLine) {
    final line = _stripTrailingCurrencyTokens(_normalizeDigits(rawLine));
    if (!_alphaPattern.hasMatch(line)) {
      return null;
    }
    if (_nonItemMetadataPattern.hasMatch(line)) {
      return null;
    }

    final indexedTable = _tryParseIndexedTableLine(line);
    if (indexedTable != null) {
      return indexedTable;
    }

    final leadingXPattern = RegExp(
      '^($_signedNumberPattern)\\s*[xX*×]\\s*($_signedNumberPattern)\\s+(.+?)'
      r'$',
      caseSensitive: false,
    );
    final leadingXMatch = leadingXPattern.firstMatch(line);
    if (leadingXMatch != null) {
      final quantity = _parseNumber(leadingXMatch.group(1));
      final price = _parseNumber(leadingXMatch.group(2));
      final name = (leadingXMatch.group(3) ?? '').trim();
      return _buildItem(
        name: name,
        quantity: quantity,
        unitPrice: price,
        confidence: OcrConfidence.medium,
      );
    }

    final xPattern = RegExp(
      '^(.+?)\\s+($_signedNumberPattern)\\s*[xX*×]\\s*($_signedNumberPattern)'
      r'$',
      caseSensitive: false,
    );
    final xMatch = xPattern.firstMatch(line);
    if (xMatch != null) {
      final name = (xMatch.group(1) ?? '').trim();
      final quantity = _parseNumber(xMatch.group(2));
      final price = _parseNumber(xMatch.group(3));
      return _buildItem(
        name: name,
        quantity: quantity,
        unitPrice: price,
        confidence: OcrConfidence.high,
      );
    }

    final explicitPattern = RegExp(
      '^(.+?)\\s+(?:$_quantityKeywordPattern)\\s*:?\\s*($_signedNumberPattern)\\s+(?:$_unitPriceKeywordPattern)\\s*:?\\s*($_signedNumberPattern)'
      r'$',
      caseSensitive: false,
    );
    final explicitMatch = explicitPattern.firstMatch(line);
    if (explicitMatch != null) {
      final name = (explicitMatch.group(1) ?? '').trim();
      final quantity = _parseNumber(explicitMatch.group(2));
      final price = _parseNumber(explicitMatch.group(3));
      return _buildItem(
        name: name,
        quantity: quantity,
        unitPrice: price,
        confidence: OcrConfidence.high,
      );
    }

    final labeledItemPattern = RegExp(
      '^(?:$_itemKeywordPattern)\\s*:?\\s*(.+?)\\s+(?:$_quantityKeywordPattern)\\s*:?\\s*($_signedNumberPattern)\\s+(?:$_unitPriceKeywordPattern)\\s*:?\\s*($_signedNumberPattern)(?:\\s+(?:$_lineTotalKeywordPattern)\\s*:?\\s*($_signedNumberPattern))?'
      r'$',
      caseSensitive: false,
    );
    final labeledItemMatch = labeledItemPattern.firstMatch(line);
    if (labeledItemMatch != null) {
      final name = (labeledItemMatch.group(1) ?? '').trim();
      final quantity = _parseNumber(labeledItemMatch.group(2));
      final price = _parseNumber(labeledItemMatch.group(3));
      return _buildItem(
        name: name,
        quantity: quantity,
        unitPrice: price,
        confidence: OcrConfidence.medium,
      );
    }

    final labeledQtyFirstPattern = RegExp(
      '^(?:$_quantityKeywordPattern)\\s*:?\\s*($_signedNumberPattern)\\s+(?:$_unitPriceKeywordPattern)\\s*:?\\s*($_signedNumberPattern)\\s+(?:$_itemKeywordPattern)\\s*:?\\s*(.+?)'
      r'$',
      caseSensitive: false,
    );
    final labeledQtyFirstMatch = labeledQtyFirstPattern.firstMatch(line);
    if (labeledQtyFirstMatch != null) {
      final quantity = _parseNumber(labeledQtyFirstMatch.group(1));
      final price = _parseNumber(labeledQtyFirstMatch.group(2));
      final name = (labeledQtyFirstMatch.group(3) ?? '').trim();
      return _buildItem(
        name: name,
        quantity: quantity,
        unitPrice: price,
        confidence: OcrConfidence.medium,
      );
    }

    final fallbackPattern = RegExp(
      '^(.+?)\\s+($_signedNumberPattern)\\s+($_signedNumberPattern)(?:\\s+($_signedNumberPattern))?'
      r'$',
      caseSensitive: false,
    );
    final fallbackMatch = fallbackPattern.firstMatch(line);
    if (fallbackMatch != null) {
      final name = (fallbackMatch.group(1) ?? '').trim();
      final first = _parseNumber(fallbackMatch.group(2));
      final second = _parseNumber(fallbackMatch.group(3));
      final third = _parseNumber(fallbackMatch.group(4));

      if (first == null || second == null) {
        return null;
      }

      final quantity = first;
      final price = third ?? second;

      return _buildItem(
        name: name,
        quantity: quantity,
        unitPrice: price,
        confidence: third == null ? OcrConfidence.medium : OcrConfidence.low,
      );
    }

    final leadingNumericPattern = RegExp(
      '^($_signedNumberPattern)\\s+($_signedNumberPattern)(?:\\s+($_signedNumberPattern))?\\s+(.+?)'
      r'$',
      caseSensitive: false,
    );
    final leadingNumericMatch = leadingNumericPattern.firstMatch(line);
    if (leadingNumericMatch != null) {
      final first = _parseNumber(leadingNumericMatch.group(1));
      final second = _parseNumber(leadingNumericMatch.group(2));
      final third = _parseNumber(leadingNumericMatch.group(3));
      final name = (leadingNumericMatch.group(4) ?? '').trim();

      if (first == null || second == null) {
        return null;
      }

      final quantity = first;
      final unitPrice = second > 0 ? second : (third ?? second);

      return _buildItem(
        name: name,
        quantity: quantity,
        unitPrice: unitPrice,
        confidence: third == null ? OcrConfidence.medium : OcrConfidence.low,
      );
    }

    final weakPattern = RegExp(
      '^(.+?)\\s+($_signedNumberPattern)'
      r'$',
      caseSensitive: false,
    );
    final weakMatch = weakPattern.firstMatch(line);
    if (weakMatch != null) {
      final name = (weakMatch.group(1) ?? '').trim();
      final number = _parseNumber(weakMatch.group(2));
      return _buildItem(
        name: name,
        quantity: 1,
        unitPrice: number,
        confidence: OcrConfidence.low,
      );
    }

    final numericTokens = RegExp(_signedNumberPattern)
        .allMatches(line)
        .map((m) => _parseNumber(m.group(0)))
        .whereType<double>()
        .toList(growable: false);
    if (numericTokens.length >= 2) {
      final cleanedName = line
          .replaceAll(RegExp(_signedNumberPattern), ' ')
          .replaceAll(RegExp(r'[xX*×]'), ' ')
          .replaceAll(RegExp(r'[-_/.,:;]+'), ' ')
          .replaceAll(_multiSpace, ' ')
          .trim();

      if (cleanedName.isNotEmpty && _alphaPattern.hasMatch(cleanedName)) {
        final quantity = numericTokens.first;
        final unitPrice = numericTokens[1];
        return _buildItem(
          name: cleanedName,
          quantity: quantity,
          unitPrice: unitPrice,
          confidence: OcrConfidence.low,
        );
      }
    }

    return null;
  }

  PurchaseOcrLineItemDraft? _tryParseStandaloneItemLine(
    List<String> lines,
    int index, {
    required bool inItemSection,
  }) {
    if (index < 0 || index >= lines.length) {
      return null;
    }

    final line = _stripTrailingCurrencyTokens(_normalizeDigits(lines[index]));
    if (_isLikelyHeaderOrFooter(line)) {
      return null;
    }

    if (index < lines.length - 1) {
      final next = _stripTrailingCurrencyTokens(
        _normalizeDigits(lines[index + 1]),
      );
      if (_looksLikeNumericOnlyLine(next)) {
        return null;
      }
    }

    if (!_looksLikeStandaloneProductName(
      line,
      allowNumbers: true,
      inItemSection: inItemSection,
    )) {
      return null;
    }

    return _buildItem(
      name: line,
      quantity: 1,
      unitPrice: 0,
      confidence: OcrConfidence.low,
    );
  }

  bool _looksLikeNumericOnlyLine(String line) {
    if (line.trim().isEmpty) return false;
    return _numberPattern.hasMatch(line) && !_alphaPattern.hasMatch(line);
  }

  bool _looksLikeStandaloneProductName(
    String line, {
    required bool allowNumbers,
    required bool inItemSection,
  }) {
    final normalized = _normalizeItemName(line);
    if (normalized.isEmpty) return false;
    if (_nonItemMetadataPattern.hasMatch(normalized)) return false;
    if (_nonItemFooterPattern.hasMatch(normalized)) return false;
    if (_totalKeywordPattern.hasMatch(normalized)) return false;
    if (_supplierPrefix.hasMatch(normalized)) return false;
    if (_dateHintPattern.hasMatch(normalized)) return false;
    if (normalized.length < 5) return false;
    if (!_alphaPattern.hasMatch(normalized)) return false;
    if (_hasHeavyNoise(normalized)) return false;

    final hasNumbers = _numberPattern.hasMatch(normalized);
    if (hasNumbers && !allowNumbers) return false;

    final hasHint = _standaloneProductHintPattern.hasMatch(normalized);
    if (!hasHint && !inItemSection) return false;
    if (!hasHint && inItemSection && normalized.split(' ').length < 2) {
      return false;
    }

    if (hasNumbers) {
      final numberCount = _numberPattern.allMatches(normalized).length;
      if (numberCount > 3) {
        return false;
      }
    }

    return true;
  }

  bool _hasHeavyNoise(String value) {
    final symbols = RegExp(
      r'[^A-Za-z\u0600-\u06FF0-9\s/().+\-]',
    ).allMatches(value).length;
    return symbols >= 4;
  }

  PurchaseOcrLineItemDraft? _tryParseIndexedTableLine(String line) {
    final tokens = line.split(' ').where((t) => t.trim().isNotEmpty).toList();
    if (tokens.length < 5) {
      return null;
    }

    final first = _parseNumber(tokens.first);
    final second = tokens.length > 1 ? _parseNumber(tokens[1]) : null;
    final preLast = tokens.length > 1
        ? _parseNumber(tokens[tokens.length - 2])
        : null;
    final last = _parseNumber(tokens.last);

    // Format A (RTL table OCR): total price quantity+name index
    // Example: 3300 1100 كرتونه3 كاسات كارتون 9 اوص 1
    if (_isLikelyRowIndex(last) && first != null && second != null) {
      final middleChunk = tokens.sublist(2, tokens.length - 1).join(' ');
      final parsedChunk = _extractQuantityAndItemName(middleChunk);
      if (parsedChunk != null) {
        return _buildItem(
          name: parsedChunk.itemName,
          quantity: parsedChunk.quantity,
          unitPrice: second,
          confidence: _confidenceFromLineTotal(
            quantity: parsedChunk.quantity,
            unitPrice: second,
            lineTotal: first,
          ),
        );
      }
    }

    // Format B: index name+quantity price total
    // Example: 23 مناديل رول مطبخ 80 120 9600
    if (_isLikelyRowIndex(first) && preLast != null && last != null) {
      final middleChunk = tokens.sublist(1, tokens.length - 2).join(' ');
      final parsedChunk = _extractQuantityAndItemName(middleChunk);
      if (parsedChunk != null) {
        return _buildItem(
          name: parsedChunk.itemName,
          quantity: parsedChunk.quantity,
          unitPrice: preLast,
          confidence: _confidenceFromLineTotal(
            quantity: parsedChunk.quantity,
            unitPrice: preLast,
            lineTotal: last,
          ),
        );
      }
    }

    return null;
  }

  _QuantityItemChunk? _extractQuantityAndItemName(String? chunk) {
    final raw = (chunk ?? '').trim();
    if (raw.isEmpty) {
      return null;
    }

    final numberMatch = RegExp(_signedNumberPattern).firstMatch(raw);
    if (numberMatch == null) {
      return null;
    }

    final quantity = _parseNumber(numberMatch.group(0));
    if (quantity == null) {
      return null;
    }

    var name = raw
        .replaceRange(numberMatch.start, numberMatch.end, ' ')
        .replaceAll(_multiSpace, ' ')
        .trim();

    name = name
        .replaceFirst(
          RegExp('^$_quantityUnitKeywordPattern\\b\\s*', caseSensitive: false),
          '',
        )
        .replaceFirst(RegExp(r'^[\-:;/]+\s*'), '')
        .trim();

    if (name.isEmpty || !_alphaPattern.hasMatch(name)) {
      return null;
    }

    return _QuantityItemChunk(itemName: name, quantity: quantity);
  }

  bool _isLikelyRowIndex(double? value) {
    if (value == null) return false;
    if (!isIntegerLike(value)) return false;
    return value >= 1 && value <= 300;
  }

  OcrConfidence _confidenceFromLineTotal({
    required double quantity,
    required double unitPrice,
    required double? lineTotal,
  }) {
    if (lineTotal == null || quantity <= 0 || unitPrice < 0) {
      return OcrConfidence.medium;
    }
    final expected = quantity * unitPrice;
    if (expected == 0) {
      return OcrConfidence.medium;
    }
    final diffRatio = (expected - lineTotal).abs() / expected;
    if (diffRatio <= 0.03) {
      return OcrConfidence.high;
    }
    if (diffRatio <= 0.12) {
      return OcrConfidence.medium;
    }
    return OcrConfidence.low;
  }

  PurchaseOcrLineItemDraft? _buildItem({
    required String name,
    required double? quantity,
    required double? unitPrice,
    required OcrConfidence confidence,
  }) {
    final cleanName = _normalizeItemName(name);
    if (cleanName.isEmpty) return null;

    var resolvedConfidence = confidence;

    var resolvedQuantity = quantity;
    if (resolvedQuantity == null || resolvedQuantity <= 0) {
      resolvedQuantity = 1;
      resolvedConfidence = _downgradeConfidence(resolvedConfidence);
    }

    var resolvedUnitPrice = unitPrice;
    if (resolvedUnitPrice == null || resolvedUnitPrice < 0) {
      resolvedUnitPrice = 0;
      resolvedConfidence = _downgradeConfidence(resolvedConfidence);
    }

    if (_isSuspiciousLine(cleanName)) {
      resolvedConfidence = OcrConfidence.low;
    }

    return PurchaseOcrLineItemDraft(
      productName: cleanName,
      quantity: roundQuantity(resolvedQuantity),
      unitPrice: roundCurrency(resolvedUnitPrice),
      confidence: resolvedConfidence,
    );
  }

  String _normalizeItemName(String input) {
    final stripped = input
        .replaceFirst(
          RegExp('^(?:$_itemKeywordPattern)\\s*:?\\s*', caseSensitive: false),
          '',
        )
        .replaceAll(_multiSpace, ' ')
        .trim();
    return stripped;
  }

  OcrConfidence _downgradeConfidence(OcrConfidence current) {
    switch (current) {
      case OcrConfidence.high:
        return OcrConfidence.medium;
      case OcrConfidence.medium:
        return OcrConfidence.low;
      case OcrConfidence.low:
        return OcrConfidence.low;
    }
  }

  bool _isSuspiciousLine(String line) {
    final symbols = RegExp(
      r'[^A-Za-z\u0600-\u06FF0-9\s._\-()]',
    ).allMatches(line).length;
    return symbols >= 3;
  }

  String _normalizeDigits(String input) {
    var value = input;
    const arabicIndic = {
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
    arabicIndic.forEach((key, replacement) {
      value = value.replaceAll(key, replacement);
    });

    value = value
        .replaceAll('٫', '.')
        .replaceAll('،', '.')
        .replaceAll('٬', '')
        .replaceAll(',', '.');

    return value;
  }

  String _stripTrailingCurrencyTokens(String input) {
    return input
        .replaceAll(
          RegExp(
            r'\s*(?:egp|usd|eur|sar|aed|qar|kwd|omr|jod|د\.?(?:م|ا)|جنيه|ريال|دولار)\s*$',
            caseSensitive: false,
          ),
          '',
        )
        .replaceAll(RegExp(r'\s*[\$€£]\s*$'), '')
        .trim();
  }

  double? _parseNumber(String? value) {
    if (value == null) return null;
    final normalized = _normalizeDigits(value).trim();
    if (normalized.isEmpty) return null;

    final numeric = normalized.replaceAll(RegExp(r'[^0-9,.-]'), '');
    if (numeric.isEmpty) return null;

    final dotLast = numeric.lastIndexOf('.');
    final commaLast = numeric.lastIndexOf(',');
    final decimalIndex = dotLast > commaLast ? dotLast : commaLast;

    late final String canonical;
    if (decimalIndex >= 0) {
      final intPart = numeric
          .substring(0, decimalIndex)
          .replaceAll(RegExp(r'[.,]'), '');
      final fracPart = numeric
          .substring(decimalIndex + 1)
          .replaceAll(RegExp(r'[.,]'), '');
      canonical = fracPart.isEmpty ? intPart : '$intPart.$fracPart';
    } else {
      canonical = numeric.replaceAll(RegExp(r'[.,]'), '');
    }

    if (canonical.isEmpty || canonical == '-' || canonical == '.') {
      return null;
    }
    return double.tryParse(canonical);
  }
}

class _ScoredValue<T> {
  const _ScoredValue({required this.value, required this.confidence});

  final T value;
  final OcrConfidence confidence;
}

class _QuantityItemChunk {
  const _QuantityItemChunk({required this.itemName, required this.quantity});

  final String itemName;
  final double quantity;
}
