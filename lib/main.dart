import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/widgets.dart';
import 'package:clothes_inventory/app/app.dart';
import 'package:clothes_inventory/services/di/service_locator.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();
  await setupServiceLocator();
  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('en'), Locale('ar')],
      path: 'assets/translations',
      fallbackLocale: const Locale('en'),
      startLocale: const Locale('ar'),
      child: const InventoryPosApp(),
    ),
  );
}
