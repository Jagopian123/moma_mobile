import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'core/hive/hive_service.dart';
import 'core/hive/category_seeder.dart';
import 'core/services/ad_eligibility_service.dart';
import 'core/router/app_router.dart';
import 'core/services/api_service.dart';
import 'core/services/admob_service.dart';
import 'core/services/notification_service.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/notifications/providers/notification_provider.dart';
import 'features/security/providers/security_provider.dart';
import 'features/security/widgets/lock_screen.dart';
import 'features/settings/providers/backup_provider.dart';

// Global key untuk ScaffoldMessenger
// Dipakai supaya snackbar bisa muncul dari mana saja termasuk dalam bottom sheet
final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const env = String.fromEnvironment('ENV', defaultValue: 'production');

  // Jalankan init yang tidak saling bergantung secara paralel
  await Future.wait([
    dotenv.load(fileName: 'env/.env.$env'),
    initializeDateFormatting('id', null),
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]),
  ]);

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: AppColors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  // Hive harus selesai sebelum CategorySeeder
  await HiveService.init();
  await CategorySeeder.seed();
  await CategorySeeder.ensureSubscriptionCategory();
  AdEligibilityService.recordInstallIfNeeded();

  // Init API service (Dio + interceptor)
  ApiService().init();

  // Init notification plugin — tanpa timezone DB agar tidak memblokir runApp
  await NotificationService.initPlugin();

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
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Buka box debt & investment di background setelah frame pertama
      await HiveService.initLazy();
      // Load timezone DB setelah runApp — hemat ~200-500ms di startup
      NotificationService.initTimezones();
      ref.read(notificationProvider.notifier).generateAll();
      _scheduleNotifications();
      // Init AdMob di background — tidak perlu await
      AdmobService.init();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      ref.read(securityProvider.notifier).lock();
    } else if (state == AppLifecycleState.resumed) {
      _tryAutoBackup();
    }
  }

  void _scheduleNotifications() {
    NotificationService.scheduleDailyReminder();
    NotificationService.scheduleSubscriptionReminders();
    NotificationService.scheduleDebtReminders();
  }

  void _tryAutoBackup() {
    final user = ref.read(authProvider).user;
    if (user == null) return;
    ref.read(backupProvider.notifier).autoBackupIfNeeded(
      isPremium: user.isPremium,
    );
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
