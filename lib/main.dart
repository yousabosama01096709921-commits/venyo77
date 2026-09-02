// main.dart
// "المحفظة الذكية" — تطبيق تتبع مصاريف وميزانية عائلية بنظام الظروف الرقمية
// ============================================================================
// المميزات:
//  • لوحة رئيسية: الرصيد (دخل - مصاريف)، ظروف رقمية ملونة بشريط تقدم ذكي،
//    زر إضافة سريعة (<3 ثواني)، وأحدث 5 معاملات قابلة للحذف.
//  • تقارير: مخطط دائري لتوزيع الفئات + مخطط شريطي لآخر 6 أشهر + تنبيهات ذكية.
//  • تحديات: حصالة أهداف، تحدي 30 يوماً، تتبع الامتناع عن الشراء، ومكافآت
//    تُفتح بمشاهدة إعلان فيديو (ثيمات/فئات إضافية/أوسمة).
//  • إعدادات: العملة، الوضع الداكن، إدارة الفئات (أيقونة/لون/ميزانية)،
//    تذكير يومي محلي، تصدير/استيراد نسخة احتياطية JSON.
//
// Offline-First بالكامل: كل البيانات تُخزَّن محلياً عبر SharedPreferences،
// ولا يحتاج التطبيق إنترنت لأي من وظائفه الأساسية. الإعلانات فقط تحتاج
// اتصالاً، وتُخفى تلقائياً وبأناقة عند انعدامه (راجع ad_manager.dart).
//
// خطوات التشغيل:
// 1) flutter create budget_wallet ثم استبدل pubspec.yaml و lib/ بهذه الملفات.
// 2) أضف معرف AdMob في android/app/src/main/AndroidManifest.xml داخل <application>:
//      <meta-data
//          android:name="com.google.android.gms.ads.APPLICATION_ID"
//          android:value="ca-app-pub-3940256099942544~3347511713"/>
//    (هذا معرف اختبار — استبدله بمعرف تطبيقك الحقيقي من حساب AdMob).
// 3) استبدل كل معرفات الإعلانات في ad_manager.dart بمعرفاتك الحقيقية قبل
//    النشر على المتجر (استخدام معرفات اختبار في نسخة منشورة يخالف سياسات AdMob).
// 4) شغّل: flutter pub get ثم flutter run
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'storage.dart';
import 'ad_manager.dart';
import 'notifications.dart';
import 'screens/dashboard_screen.dart';
import 'screens/analytics_screen.dart';
import 'screens/challenges_screen.dart';
import 'screens/settings_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await MobileAds.instance.initialize();
  await BudgetState.instance.load();
  await AdManager.instance.init();
  await NotificationService.init();
  if (BudgetState.instance.reminderEnabled) {
    await NotificationService.scheduleDailyReminder(
        BudgetState.instance.reminderHour,
        BudgetState.instance.reminderMinute);
  }
  runApp(const BudgetWalletApp());
}

class BudgetWalletApp extends StatefulWidget {
  const BudgetWalletApp({super.key});
  @override
  State<BudgetWalletApp> createState() => _BudgetWalletAppState();
}

class _BudgetWalletAppState extends State<BudgetWalletApp> {
  @override
  void initState() {
    super.initState();
    BudgetState.instance.addListener(_refresh);
  }

  @override
  void dispose() {
    BudgetState.instance.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final darkMode = BudgetState.instance.darkMode;
    return MaterialApp(
      title: 'المحفظة الذكية',
      debugShowCheckedModeBanner: false,
      themeMode: darkMode ? ThemeMode.dark : ThemeMode.light,
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.teal),
      darkTheme: ThemeData(
          useMaterial3: true,
          colorSchemeSeed: Colors.teal,
          brightness: Brightness.dark),
      builder: (context, child) =>
          Directionality(textDirection: TextDirection.rtl, child: child!),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  int _tabIndex = 0;
  final _titles = ['المحفظة الذكية', 'التقارير', 'التحديات', 'الإعدادات'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AdManager.instance.addListener(_refresh);
    // إعلان فتح التطبيق عند أول تشغيل (بعد استقرار أول إطار للواجهة)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AdManager.instance.showAppOpenAdIfAvailable();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    AdManager.instance.removeListener(_refresh);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // إعلان فتح التطبيق عند العودة من الخلفية — نمط شائع لرفع الأرباح
    if (state == AppLifecycleState.resumed) {
      AdManager.instance.showAppOpenAdIfAvailable();
    }
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  void _onTabTap(int i) {
    if (i != _tabIndex) {
      // إعلان بيني عند التنقل بين الشاشات الرئيسية (بحد أقصى كل 3 دقائق)
      AdManager.instance.maybeShowInterstitialOnNavigation();
    }
    setState(() => _tabIndex = i);
  }

  @override
  Widget build(BuildContext context) {
    final pages = const [
      DashboardScreen(),
      AnalyticsScreen(),
      ChallengesScreen(),
      SettingsScreen(),
    ];
    final ads = AdManager.instance;
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_tabIndex]),
        centerTitle: true,
        actions: [
          if (!ads.isOnline)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Tooltip(
                message: 'وضع عدم الاتصال — الإعلانات مخفية مؤقتاً',
                child: Icon(Icons.cloud_off, size: 20),
              ),
            ),
        ],
      ),
      body: IndexedStack(index: _tabIndex, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: _onTabTap,
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.dashboard), label: 'الرئيسية'),
          NavigationDestination(
              icon: Icon(Icons.bar_chart), label: 'التقارير'),
          NavigationDestination(
              icon: Icon(Icons.emoji_events), label: 'التحديات'),
          NavigationDestination(
              icon: Icon(Icons.settings), label: 'الإعدادات'),
        ],
      ),
    );
  }
}
