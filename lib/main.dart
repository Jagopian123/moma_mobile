import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'core/hive/hive_service.dart';
import 'core/hive/category_seeder.dart';
import 'core/router/app_router.dart';
import 'core/services/api_service.dart';
import 'core/theme/app_theme.dart';

// Global key untuk ScaffoldMessenger
// Dipakai supaya snackbar bisa muncul dari mana saja termasuk dalam bottom sheet
final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Init locale data untuk intl (DateFormat, dsb)
  await initializeDateFormatting('id', null);

  // Paksa portrait
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Status bar transparan
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: AppColors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  // Init Hive
  await HiveService.init();

  // Seed kategori default
  await CategorySeeder.seed();

  // Init API service (Dio + interceptor)
  ApiService().init();

  runApp(
    const ProviderScope(
      child: MomaApp(),
    ),
  );
}

class MomaApp extends ConsumerWidget {
  const MomaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Moma',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      scaffoldMessengerKey: scaffoldMessengerKey,
      locale: const Locale('id', 'ID'),
      localizationsDelegates: const [
        DefaultMaterialLocalizations.delegate,
        DefaultWidgetsLocalizations.delegate,
      ],
      routerConfig: router,
    );
  }
}
