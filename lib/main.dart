import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'core/hive/hive_service.dart';
import 'core/hive/category_seeder.dart';
import 'core/router/app_router.dart';
import 'core/services/api_service.dart';
import 'core/theme/app_theme.dart';
import 'features/security/providers/security_provider.dart';
import 'features/security/widgets/lock_screen.dart';

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

class MomaApp extends ConsumerStatefulWidget {
  const MomaApp({super.key});

  @override
  ConsumerState<MomaApp> createState() => _MomaAppState();
}

class _MomaAppState extends ConsumerState<MomaApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Kunci app saat masuk background
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      ref.read(securityProvider.notifier).lock();
    }
  }

  @override
  Widget build(BuildContext context) {
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
      builder: (context, child) {
        return Consumer(
          builder: (context, ref, _) {
            final security = ref.watch(securityProvider);
            if (security.isLocked) return const LockScreen();
            return child!;
          },
        );
      },
    );
  }
}
