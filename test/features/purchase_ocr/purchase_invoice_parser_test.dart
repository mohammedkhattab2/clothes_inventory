import 'package:flutter_test/flutter_test.dart';
import 'package:delta_erp/features/purchase_ocr/domain/purchase_invoice_parser.dart';
import 'package:delta_erp/features/purchase_ocr/domain/purchase_ocr_models.dart';

void main() {
  const parser = PurchaseInvoiceParser();

  test('parses english invoice fields and items', () {
    const text = '''
Supplier: Delta Supplies
Invoice Date: 2026-04-09
Steel Wire 2 x 150
PVC Pipe 3 40
Grand Total: 420
''';

    final draft = parser.parse(rawText: text, imagePath: 'invoice.png');

    expect(draft.supplierName, 'Delta Supplies');
    expect(draft.supplierConfidence, OcrConfidence.high);
    expect(draft.invoiceDate, DateTime(2026, 4, 9));
    expect(draft.totalAmount, 420);
    expect(draft.totalAmountConfidence, OcrConfidence.high);
    expect(draft.items, hasLength(2));
    expect(draft.items.first.productName, 'Steel Wire');
    expect(draft.items.first.quantity, 2);
    expect(draft.items.first.unitPrice, 150);
    expect(draft.items.first.confidence, OcrConfidence.high);
  });

  test('parses arabic-like numeric content and total', () {
    const text = '''
اسم المورد: مؤسسة النور
التاريخ: 10/04/2026
مسمار ١٠ ٥٫٥
اجمالي: ٥٥
''';

    final draft = parser.parse(rawText: text, imagePath: 'invoice2.png');

    expect(draft.supplierName, 'مؤسسة النور');
    expect(draft.supplierConfidence, OcrConfidence.high);
    expect(draft.invoiceDate, DateTime(2026, 4, 10));
    expect(draft.totalAmount, 55);
    expect(draft.totalAmountConfidence, OcrConfidence.high);
    expect(draft.items, hasLength(1));
    expect(draft.items.first.quantity, 10);
    expect(draft.items.first.unitPrice, 5.5);
    expect(draft.items.first.confidence, OcrConfidence.medium);
  });

  test('parses noisy OCR and keeps partial structured data safely', () {
    const text = '''
*** INVOICE ***
Vendor: Bright Tools Co
Date : 09-04-2026
----
item qty price
Hammer 2 x 35
Wrench 3 20
line with random symbols @@ ##
TOTAL ........ 130
thank you
''';

    final draft = parser.parse(rawText: text, imagePath: 'invoice3.png');

    expect(draft.supplierName, 'Bright Tools Co');
    expect(draft.supplierConfidence, OcrConfidence.high);
    expect(draft.invoiceDate, DateTime(2026, 4, 9));
    expect(draft.totalAmount, 130);
    expect(draft.totalAmountConfidence, OcrConfidence.medium);
    expect(draft.items, hasLength(2));
    expect(draft.items[0].productName, 'Hammer');
    expect(draft.items[0].quantity, 2);
    expect(draft.items[0].unitPrice, 35);
    expect(draft.items[0].confidence, OcrConfidence.high);
    expect(draft.items[1].productName, 'Wrench');
    expect(draft.items[1].quantity, 3);
    expect(draft.items[1].unitPrice, 20);
    expect(draft.items[1].confidence, OcrConfidence.medium);
  });

  test('ignores invalid item values and returns partial result', () {
    const text = '''
Supplier: Partial Supplier
Pipe A 0 15
Pipe B 2 -10
Pipe C 4 12
الإجمالي: 48
''';

    final draft = parser.parse(rawText: text, imagePath: 'invoice4.png');

    expect(draft.supplierName, 'Partial Supplier');
    expect(draft.totalAmount, 48);
    expect(draft.totalAmountConfidence, OcrConfidence.high);
    expect(draft.items, hasLength(3));
    expect(draft.items[0].productName, 'Pipe A');
    expect(draft.items[0].quantity, 1);
    expect(draft.items[0].unitPrice, 15);
    expect(draft.items[0].confidence, OcrConfidence.low);
    expect(draft.items[1].productName, 'Pipe B');
    expect(draft.items[1].quantity, 2);
    expect(draft.items[1].unitPrice, 0);
    expect(draft.items[1].confidence, OcrConfidence.low);
    expect(draft.items[2].productName, 'Pipe C');
    expect(draft.items[2].quantity, 4);
    expect(draft.items[2].unitPrice, 12);
    expect(draft.items[2].confidence, OcrConfidence.medium);
  });

  test('does not crash when OCR text has no parseable fields', () {
    const text = '''
@@@ ###
random noisy stream
####
''';

    final draft = parser.parse(rawText: text, imagePath: 'invoice5.png');

    expect(draft.supplierName, isNull);
    expect(draft.supplierConfidence, isNull);
    expect(draft.invoiceDate, isNull);
    expect(draft.totalAmount, isNull);
    expect(draft.totalAmountConfidence, isNull);
    expect(draft.items, isEmpty);
  });

  test('assigns low confidence to weak noisy line with inferred values', () {
    const text = '''
منتج-غامض @@ 19
''';

    final draft = parser.parse(rawText: text, imagePath: 'invoice6.png');

    expect(draft.items, hasLength(1));
    expect(draft.items.first.productName, 'منتج-غامض @@');
    expect(draft.items.first.quantity, 1);
    expect(draft.items.first.unitPrice, 19);
    expect(draft.items.first.confidence, OcrConfidence.low);
  });

  test(
    'parses item lines when quantity and price appear before product name',
    () {
      const text = '''
Supplier: Delta Supplies
Date: 2026-04-10
2 x 150 Steel Wire
3 40 PVC Pipe
Grand Total: 420
''';

      final draft = parser.parse(rawText: text, imagePath: 'invoice7.png');

      expect(draft.items, hasLength(2));
      expect(draft.items[0].productName, 'Steel Wire');
      expect(draft.items[0].quantity, 2);
      expect(draft.items[0].unitPrice, 150);
      expect(draft.items[1].productName, 'PVC Pipe');
      expect(draft.items[1].quantity, 3);
      expect(draft.items[1].unitPrice, 40);
    },
  );

  test('parses thousand-separated numbers and currency markers', () {
    const text = '''
Supplier: Global Trade
Date: 2026-04-11
Steel Rod 2 x 1,200.50
Cable Roll 1 x 350.00 EGP
Grand Total: 2,751.00
''';

    final draft = parser.parse(rawText: text, imagePath: 'invoice8.png');

    expect(draft.items, hasLength(2));
    expect(draft.items[0].productName, 'Steel Rod');
    expect(draft.items[0].quantity, 2);
    expect(draft.items[0].unitPrice, 1200.5);
    expect(draft.items[1].productName, 'Cable Roll');
    expect(draft.items[1].quantity, 1);
    expect(draft.items[1].unitPrice, 350);
    expect(draft.totalAmount, 2751);
  });

  test('parses noisy table-like line via heuristic fallback', () {
    const text = '''
Supplier: Table Supplier
Date: 2026-04-12
Steel-Wire / 2 , 150 ;
Grand Total: 300
''';

    final draft = parser.parse(rawText: text, imagePath: 'invoice9.png');

    expect(draft.items, hasLength(1));
    expect(draft.items.first.productName, 'Steel Wire');
    expect(draft.items.first.quantity, 2);
    expect(draft.items.first.unitPrice, 150);
  });

  test('parses alias labels for item quantity and price in Arabic', () {
    const text = '''
اسم المورد: شركة الأمل
التاريخ: 12/04/2026
اسم الصنف: كابل نحاس العدد: 3 سعر الوحدة: 25
الإجمالي الكلي: 75
''';

    final draft = parser.parse(rawText: text, imagePath: 'invoice10.png');

    expect(draft.supplierName, 'شركة الأمل');
    expect(draft.items, hasLength(1));
    expect(draft.items.first.productName, 'كابل نحاس');
    expect(draft.items.first.quantity, 3);
    expect(draft.items.first.unitPrice, 25);
    expect(draft.totalAmount, 75);
  });

  test('parses alias labels for count and rate in English', () {
    const text = '''
Supplier: Prime Source
Date: 2026-04-12
count: 4 rate: 12.5 product: Rubber Seal
Amount Due: 50
''';

    final draft = parser.parse(rawText: text, imagePath: 'invoice11.png');

    expect(draft.items, hasLength(1));
    expect(draft.items.first.productName, 'Rubber Seal');
    expect(draft.items.first.quantity, 4);
    expect(draft.items.first.unitPrice, 12.5);
    expect(draft.totalAmount, 50);
  });

  test('parses split rows when name and numbers are on separate lines', () {
    const text = '''
Supplier: Split Supplier
Date: 2026-04-12
Steel Cable
3 40
Copper Pipe
2 55
Grand Total: 230
''';

    final draft = parser.parse(rawText: text, imagePath: 'invoice12.png');

    expect(draft.items, hasLength(2));
    expect(draft.items[0].productName, 'Steel Cable');
    expect(draft.items[0].quantity, 3);
    expect(draft.items[0].unitPrice, 40);
    expect(draft.items[1].productName, 'Copper Pipe');
    expect(draft.items[1].quantity, 2);
    expect(draft.items[1].unitPrice, 55);
    expect(draft.totalAmount, 230);
  });

  test('parses indexed table row where index is at end', () {
    const text = '''
3300 1100 كرتونه3 كاسات كارتون 9 اوص 1
''';

    final draft = parser.parse(rawText: text, imagePath: 'invoice13.png');

    expect(draft.items, hasLength(1));
    expect(draft.items.first.productName, contains('كاسات كارتون 9 اوص'));
    expect(draft.items.first.quantity, 3);
    expect(draft.items.first.unitPrice, 1100);
  });

  test('parses indexed table row where index is at start', () {
    const text = '''
23 مناديل رول مطبخ 80 120 9600
''';

    final draft = parser.parse(rawText: text, imagePath: 'invoice14.png');

    expect(draft.items, hasLength(1));
    expect(draft.items.first.productName, 'مناديل رول مطبخ');
    expect(draft.items.first.quantity, 80);
    expect(draft.items.first.unitPrice, 120);
  });

  test('parses standalone product names and ignores header metadata lines', () {
    const text = '''
المحمول / 01006007258
سجل التجاري /5026
بطاقه الضريبيه/537559442
تاريخ
مسحوق غسيل اتوماتيك تايد
شامبو سجاد /موكيت 1 لتر (فلاش )
اكياس نفايات 120+90 اسود تقيل
''';

    final draft = parser.parse(rawText: text, imagePath: 'invoice15.png');

    expect(draft.items.length, greaterThanOrEqualTo(2));
    expect(
      draft.items.any(
        (item) => item.productName.contains('مسحوق غسيل اتوماتيك تايد'),
      ),
      isTrue,
    );
    expect(
      draft.items.any((item) => item.productName.contains('شامبو سجاد /موكيت')),
      isTrue,
    );
    expect(
      draft.items.any((item) => item.productName.contains('اكياس نفايات')),
      isTrue,
    );
    expect(
      draft.items.any((item) => item.productName.contains('المحمول')),
      isFalse,
    );
  });

  test('parses provided OCR item section and skips noisy non-item lines', () {
    const text = '''
المحمول / 01006007258
سجل التجاري /5026
بطاقه الضريبيه/537559442
الصنف
مسحوق غسيل اتوماتيك تايد 2.5
فونيك حمامات
Gules alogs للمطبخ
شامبو سجاد /موكيت 1 لتر (فلاش )
قشاطه ارضيات 45 سم
داوني غسيل
عصا wus
اسم العميل : منظفات للقارب كوين نفرتيتي
ذا Ny] إن Ua} أ أت أ }©
اكياس نفايات 120+90 اسود تقيل
مناديل رول مطبخ
''';

    final draft = parser.parse(rawText: text, imagePath: 'invoice16.png');

    expect(
      draft.items.any(
        (item) => item.productName.contains('مسحوق غسيل اتوماتيك تايد'),
      ),
      isTrue,
    );
    expect(
      draft.items.any((item) => item.productName.contains('فونيك حمامات')),
      isTrue,
    );
    expect(
      draft.items.any(
        (item) => item.productName.contains('اكياس نفايات 120+90 اسود تقيل'),
      ),
      isTrue,
    );
    expect(
      draft.items.any((item) => item.productName.contains('مناديل رول مطبخ')),
      isTrue,
    );
    expect(
      draft.items.any((item) => item.productName.contains('المحمول')),
      isFalse,
    );
    expect(
      draft.items.any((item) => item.productName.contains('بطاقه الضريبيه')),
      isFalse,
    );
    expect(
      draft.items.any((item) => item.productName.contains('ذا Ny]')),
      isFalse,
    );
  });
}
