// main.dart
// "المحفظة الذكية" — نسخة مُدمجة في ملف واحد (كل الكود من كل الملفات الأصلية
// مجموع هنا بدون حذف أي وظيفة: models + storage + ad_manager + notifications
// + الشاشات الأربع + نقطة الدخول). قسّمها لاحقاً لملفات منفصلة إن أردت تنظيماً أفضل.
//
// المتطلبات (ضعها في pubspec.yaml):
//   google_mobile_ads, shared_preferences, fl_chart, connectivity_plus,
//   flutter_local_notifications, timezone, flutter_timezone, path_provider,
//   share_plus, file_picker, intl

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';

// ============================================================================
// MODELS (كان في models.dart)
// ============================================================================

enum TxType { income, expense }

class ExpenseCategory {
  String id;
  String name;
  int iconCodePoint;
  int colorValue;
  double monthlyBudget;

  ExpenseCategory({
    required this.id,
    required this.name,
    required this.iconCodePoint,
    required this.colorValue,
    this.monthlyBudget = 0,
  });

  IconData get icon => IconData(iconCodePoint, fontFamily: 'MaterialIcons');
  Color get color => Color(colorValue);

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'iconCodePoint': iconCodePoint,
        'colorValue': colorValue,
        'monthlyBudget': monthlyBudget,
      };

  factory ExpenseCategory.fromJson(Map<String, dynamic> j) => ExpenseCategory(
        id: j['id'],
        name: j['name'],
        iconCodePoint: j['iconCodePoint'],
        colorValue: j['colorValue'],
        monthlyBudget: (j['monthlyBudget'] as num).toDouble(),
      );
}

class MoneyTransaction {
  String id;
  String? categoryId; // null إذا كانت المعاملة دخل
  double amount;
  String note;
  DateTime date;
  TxType type;

  MoneyTransaction({
    required this.id,
    this.categoryId,
    required this.amount,
    this.note = '',
    required this.date,
    required this.type,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'categoryId': categoryId,
        'amount': amount,
        'note': note,
        'date': date.toIso8601String(),
        'type': type.name,
      };

  factory MoneyTransaction.fromJson(Map<String, dynamic> j) =>
      MoneyTransaction(
        id: j['id'],
        categoryId: j['categoryId'],
        amount: (j['amount'] as num).toDouble(),
        note: j['note'] ?? '',
        date: DateTime.parse(j['date']),
        type: (j['type'] == 'income') ? TxType.income : TxType.expense,
      );
}

class SavingsGoal {
  String id;
  String name;
  double targetAmount;
  double savedAmount;
  DateTime? deadline;

  SavingsGoal({
    required this.id,
    required this.name,
    required this.targetAmount,
    this.savedAmount = 0,
    this.deadline,
  });

  double get progress =>
      targetAmount <= 0 ? 0 : (savedAmount / targetAmount).clamp(0, 1);

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'targetAmount': targetAmount,
        'savedAmount': savedAmount,
        'deadline': deadline?.toIso8601String(),
      };

  factory SavingsGoal.fromJson(Map<String, dynamic> j) => SavingsGoal(
        id: j['id'],
        name: j['name'],
        targetAmount: (j['targetAmount'] as num).toDouble(),
        savedAmount: (j['savedAmount'] as num).toDouble(),
        deadline: j['deadline'] != null ? DateTime.parse(j['deadline']) : null,
      );
}

// ============================================================================
// STORAGE / STATE (كان في storage.dart)
// ============================================================================

List<ExpenseCategory> defaultCategories() => [
      ExpenseCategory(
          id: 'cat_food',
          name: 'طعام',
          iconCodePoint: Icons.restaurant.codePoint,
          colorValue: Colors.orange.value,
          monthlyBudget: 0),
      ExpenseCategory(
          id: 'cat_bills',
          name: 'فواتير',
          iconCodePoint: Icons.receipt_long.codePoint,
          colorValue: Colors.blue.value,
          monthlyBudget: 0),
      ExpenseCategory(
          id: 'cat_fun',
          name: 'ترفيه',
          iconCodePoint: Icons.movie.codePoint,
          colorValue: Colors.purple.value,
          monthlyBudget: 0),
      ExpenseCategory(
          id: 'cat_transport',
          name: 'مواصلات',
          iconCodePoint: Icons.directions_car.codePoint,
          colorValue: Colors.teal.value,
          monthlyBudget: 0),
      ExpenseCategory(
          id: 'cat_shopping',
          name: 'تسوق',
          iconCodePoint: Icons.shopping_bag.codePoint,
          colorValue: Colors.pink.value,
          monthlyBudget: 0),
    ];

const List<String> supportedCurrencies = [
  'ر.س',
  'ج.م',
  '\$',
  'د.إ',
  'د.ك',
  '€',
  'د.أ',
  'د.ت',
  'د.ع',
  'ل.س',
];

const List<IconData> pickableIcons = [
  Icons.restaurant,
  Icons.receipt_long,
  Icons.movie,
  Icons.directions_car,
  Icons.shopping_bag,
  Icons.health_and_safety,
  Icons.school,
  Icons.pets,
  Icons.home,
  Icons.card_giftcard,
  Icons.sports_soccer,
  Icons.flight,
  Icons.coffee,
  Icons.phone_android,
  Icons.local_gas_station,
  Icons.spa,
];

const List<Color> pickableColors = [
  Colors.orange,
  Colors.blue,
  Colors.purple,
  Colors.teal,
  Colors.pink,
  Colors.green,
  Colors.red,
  Colors.indigo,
  Colors.brown,
  Colors.cyan,
  Colors.amber,
  Colors.deepOrange,
];

class BudgetState extends ChangeNotifier {
  BudgetState._internal();
  static final BudgetState instance = BudgetState._internal();

  String currencySymbol = 'ر.س';
  bool darkMode = false;
  List<ExpenseCategory> categories = [];
  List<MoneyTransaction> transactions = [];
  List<SavingsGoal> goals = [];

  final Set<String> thirtyDayCheckins = {}; // yyyy-MM-dd
  double thirtyDayDailyAmount = 5;

  final Set<String> noSpendDays = {};
  double noSpendDailyAmount = 20;

  final Set<String> unlockedPerks = {};

  bool reminderEnabled = false;
  int reminderHour = 21;
  int reminderMinute = 0;

  static String _dayKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  double get totalIncome => transactions
      .where((t) => t.type == TxType.income)
      .fold(0.0, (s, t) => s + t.amount);

  double get totalExpense => transactions
      .where((t) => t.type == TxType.expense)
      .fold(0.0, (s, t) => s + t.amount);

  double get balance => totalIncome - totalExpense;

  double spentInCategory(String categoryId, {DateTime? month}) {
    final ref = month ?? DateTime.now();
    return transactions
        .where((t) =>
            t.type == TxType.expense &&
            t.categoryId == categoryId &&
            t.date.year == ref.year &&
            t.date.month == ref.month)
        .fold(0.0, (s, t) => s + t.amount);
  }

  List<MoneyTransaction> get recentTransactions {
    final list = [...transactions]..sort((a, b) => b.date.compareTo(a.date));
    return list.take(5).toList();
  }

  Map<String, double> categoryTotalsThisMonth() {
    final now = DateTime.now();
    final map = <String, double>{};
    for (final c in categories) {
      final v = spentInCategory(c.id, month: now);
      if (v > 0) map[c.id] = v;
    }
    return map;
  }

  List<double> monthlyExpenseTotals({int months = 6}) {
    final now = DateTime.now();
    return List.generate(months, (i) {
      final m = DateTime(now.year, now.month - (months - 1 - i));
      return transactions
          .where((t) =>
              t.type == TxType.expense &&
              t.date.year == m.year &&
              t.date.month == m.month)
          .fold(0.0, (s, t) => s + t.amount);
    });
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    currencySymbol = prefs.getString('currencySymbol') ?? 'ر.س';
    darkMode = prefs.getBool('darkMode') ?? false;
    reminderEnabled = prefs.getBool('reminderEnabled') ?? false;
    reminderHour = prefs.getInt('reminderHour') ?? 21;
    reminderMinute = prefs.getInt('reminderMinute') ?? 0;
    thirtyDayDailyAmount = prefs.getDouble('thirtyDayDailyAmount') ?? 5;
    noSpendDailyAmount = prefs.getDouble('noSpendDailyAmount') ?? 20;

    final catStr = prefs.getString('categories');
    if (catStr == null) {
      categories = defaultCategories();
    } else {
      final list = jsonDecode(catStr) as List;
      categories = list
          .map((e) => ExpenseCategory.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    final txStr = prefs.getString('transactions');
    if (txStr != null) {
      final list = jsonDecode(txStr) as List;
      transactions = list
          .map((e) => MoneyTransaction.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    final goalStr = prefs.getString('goals');
    if (goalStr != null) {
      final list = jsonDecode(goalStr) as List;
      goals = list
          .map((e) => SavingsGoal.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    thirtyDayCheckins.addAll(prefs.getStringList('thirtyDayCheckins') ?? []);
    noSpendDays.addAll(prefs.getStringList('noSpendDays') ?? []);
    unlockedPerks.addAll(prefs.getStringList('unlockedPerks') ?? []);

    notifyListeners();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('currencySymbol', currencySymbol);
    await prefs.setBool('darkMode', darkMode);
    await prefs.setBool('reminderEnabled', reminderEnabled);
    await prefs.setInt('reminderHour', reminderHour);
    await prefs.setInt('reminderMinute', reminderMinute);
    await prefs.setDouble('thirtyDayDailyAmount', thirtyDayDailyAmount);
    await prefs.setDouble('noSpendDailyAmount', noSpendDailyAmount);
    await prefs.setString(
        'categories', jsonEncode(categories.map((c) => c.toJson()).toList()));
    await prefs.setString('transactions',
        jsonEncode(transactions.map((t) => t.toJson()).toList()));
    await prefs.setString(
        'goals', jsonEncode(goals.map((g) => g.toJson()).toList()));
    await prefs.setStringList(
        'thirtyDayCheckins', thirtyDayCheckins.toList());
    await prefs.setStringList('noSpendDays', noSpendDays.toList());
    await prefs.setStringList('unlockedPerks', unlockedPerks.toList());
  }

  Future<void> addTransaction(MoneyTransaction t) async {
    transactions.add(t);
    await _save();
    notifyListeners();
  }

  Future<void> updateTransaction(MoneyTransaction t) async {
    final idx = transactions.indexWhere((x) => x.id == t.id);
    if (idx != -1) transactions[idx] = t;
    await _save();
    notifyListeners();
  }

  Future<void> deleteTransaction(String id) async {
    transactions.removeWhere((t) => t.id == id);
    await _save();
    notifyListeners();
  }

  Future<void> addCategory(ExpenseCategory c) async {
    categories.add(c);
    await _save();
    notifyListeners();
  }

  Future<void> updateCategory(ExpenseCategory c) async {
    final idx = categories.indexWhere((x) => x.id == c.id);
    if (idx != -1) categories[idx] = c;
    await _save();
    notifyListeners();
  }

  Future<void> deleteCategory(String id) async {
    categories.removeWhere((c) => c.id == id);
    transactions.removeWhere((t) => t.categoryId == id);
    await _save();
    notifyListeners();
  }

  Future<void> addGoal(SavingsGoal g) async {
    goals.add(g);
    await _save();
    notifyListeners();
  }

  Future<void> addToGoal(String id, double amount) async {
    if (id.isEmpty) return;
    final idx = goals.indexWhere((g) => g.id == id);
    if (idx != -1) {
      goals[idx].savedAmount = goals[idx].savedAmount + amount;
    }
    await _save();
    notifyListeners();
  }

  Future<void> deleteGoal(String id) async {
    goals.removeWhere((g) => g.id == id);
    await _save();
    notifyListeners();
  }

  bool get checkedInToday =>
      thirtyDayCheckins.contains(_dayKey(DateTime.now()));

  Future<bool> checkInThirtyDayChallenge() async {
    final key = _dayKey(DateTime.now());
    if (thirtyDayCheckins.contains(key)) return false;
    thirtyDayCheckins.add(key);
    await _save();
    notifyListeners();
    return true;
  }

  bool get markedNoSpendToday =>
      noSpendDays.contains(_dayKey(DateTime.now()));

  Future<bool> markNoSpendToday() async {
    final key = _dayKey(DateTime.now());
    if (noSpendDays.contains(key)) return false;
    noSpendDays.add(key);
    await _save();
    notifyListeners();
    return true;
  }

  Future<void> unlockPerk(String perkId) async {
    unlockedPerks.add(perkId);
    await _save();
    notifyListeners();
  }

  Future<void> setReminder(bool enabled, int hour, int minute) async {
    reminderEnabled = enabled;
    reminderHour = hour;
    reminderMinute = minute;
    await _save();
    notifyListeners();
  }

  Future<void> setCurrency(String symbol) async {
    currencySymbol = symbol;
    await _save();
    notifyListeners();
  }

  Future<void> setDarkMode(bool v) async {
    darkMode = v;
    await _save();
    notifyListeners();
  }

  String exportBackupJson() {
    return jsonEncode({
      'currencySymbol': currencySymbol,
      'darkMode': darkMode,
      'categories': categories.map((c) => c.toJson()).toList(),
      'transactions': transactions.map((t) => t.toJson()).toList(),
      'goals': goals.map((g) => g.toJson()).toList(),
      'thirtyDayCheckins': thirtyDayCheckins.toList(),
      'noSpendDays': noSpendDays.toList(),
    });
  }

  Future<void> importBackupJson(String data) async {
    final j = jsonDecode(data) as Map<String, dynamic>;
    currencySymbol = j['currencySymbol'] ?? currencySymbol;
    darkMode = j['darkMode'] ?? darkMode;
    categories = (j['categories'] as List)
        .map((e) => ExpenseCategory.fromJson(e as Map<String, dynamic>))
        .toList();
    transactions = (j['transactions'] as List)
        .map((e) => MoneyTransaction.fromJson(e as Map<String, dynamic>))
        .toList();
    goals = (j['goals'] as List)
        .map((e) => SavingsGoal.fromJson(e as Map<String, dynamic>))
        .toList();
    thirtyDayCheckins
      ..clear()
      ..addAll((j['thirtyDayCheckins'] as List).map((e) => e.toString()));
    noSpendDays
      ..clear()
      ..addAll((j['noSpendDays'] as List).map((e) => e.toString()));
    await _save();
    notifyListeners();
  }
}

// ============================================================================
// AD MANAGER (كان في ad_manager.dart)
// ============================================================================

const String bannerAdUnitId = 'ca-app-pub-3940256099942544/6300978111';
const String nativeAdUnitId = 'ca-app-pub-3940256099942544/2247696110';
const String rewardedAdUnitId = 'ca-app-pub-3940256099942544/5224354917';
const String interstitialAdUnitId = 'ca-app-pub-3940256099942544/1033173712';
const String appOpenAdUnitId = 'ca-app-pub-3940256099942544/9257395921';

const Duration interstitialMinGap = Duration(minutes: 3);
const Duration appOpenMinGap = Duration(hours: 2);

class AdManager extends ChangeNotifier {
  AdManager._internal();
  static final AdManager instance = AdManager._internal();

  bool isOnline = true;
  StreamSubscription<List<ConnectivityResult>>? _connSub;

  BannerAd? bannerAd;
  bool isBannerLoaded = false;

  NativeAd? nativeAd;
  bool isNativeLoaded = false;

  RewardedAd? rewardedAd;
  InterstitialAd? interstitialAd;
  AppOpenAd? appOpenAd;

  DateTime? _lastInterstitialShownAt;
  DateTime? _lastAppOpenShownAt;
  bool _isShowingAppOpenAd = false;

  Timer? _bannerRefreshTimer;

  Future<void> init() async {
    try {
      final result = await Connectivity().checkConnectivity();
      isOnline = !result.contains(ConnectivityResult.none);
    } catch (_) {
      isOnline = true;
    }
    _connSub = Connectivity().onConnectivityChanged.listen((results) {
      final nowOnline = !results.contains(ConnectivityResult.none);
      final wasOnline = isOnline;
      isOnline = nowOnline;
      if (!wasOnline && nowOnline) {
        preloadAll();
      }
      notifyListeners();
    });
    if (isOnline) preloadAll();
  }

  void preloadAll() {
    if (!isOnline) return;
    loadBanner();
    loadNative();
    loadRewarded();
    loadInterstitial();
    loadAppOpen();
    _bannerRefreshTimer?.cancel();
    _bannerRefreshTimer =
        Timer.periodic(const Duration(seconds: 45), (_) => loadBanner());
  }

  void loadBanner() {
    if (!isOnline) return;
    bannerAd?.dispose();
    isBannerLoaded = false;
    final banner = BannerAd(
      adUnitId: bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          bannerAd = ad as BannerAd;
          isBannerLoaded = true;
          notifyListeners();
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          isBannerLoaded = false;
        },
      ),
    );
    banner.load();
  }

  void loadNative() {
    if (!isOnline) return;
    nativeAd?.dispose();
    isNativeLoaded = false;
    final ad = NativeAd(
      adUnitId: nativeAdUnitId,
      request: const AdRequest(),
      listener: NativeAdListener(
        onAdLoaded: (ad) {
          nativeAd = ad as NativeAd;
          isNativeLoaded = true;
          notifyListeners();
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          isNativeLoaded = false;
        },
      ),
      nativeTemplateStyle:
          NativeTemplateStyle(templateType: TemplateType.small),
    );
    ad.load();
  }

  void loadRewarded() {
    if (!isOnline) return;
    RewardedAd.load(
      adUnitId: rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          rewardedAd = ad;
          rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              rewardedAd = null;
              loadRewarded();
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();
              rewardedAd = null;
              loadRewarded();
            },
          );
          notifyListeners();
        },
        onAdFailedToLoad: (error) {
          rewardedAd = null;
        },
      ),
    );
  }

  void loadInterstitial() {
    if (!isOnline) return;
    InterstitialAd.load(
      adUnitId: interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          interstitialAd = ad;
          interstitialAd!.fullScreenContentCallback =
              FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              interstitialAd = null;
              loadInterstitial();
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();
              interstitialAd = null;
              loadInterstitial();
            },
          );
        },
        onAdFailedToLoad: (error) {
          interstitialAd = null;
        },
      ),
    );
  }

  void loadAppOpen() {
    if (!isOnline) return;
    AppOpenAd.load(
      adUnitId: appOpenAdUnitId,
      request: const AdRequest(),
      adLoadCallback: AppOpenAdLoadCallback(
        onAdLoaded: (ad) {
          appOpenAd = ad;
          appOpenAd!.fullScreenContentCallback = FullScreenContentCallback(
            onAdShowedFullScreenContent: (ad) => _isShowingAppOpenAd = true,
            onAdDismissedFullScreenContent: (ad) {
              _isShowingAppOpenAd = false;
              ad.dispose();
              appOpenAd = null;
              loadAppOpen();
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              _isShowingAppOpenAd = false;
              ad.dispose();
              appOpenAd = null;
              loadAppOpen();
            },
          );
        },
        onAdFailedToLoad: (error) {
          appOpenAd = null;
        },
      ),
    );
  }

  void maybeShowInterstitialOnNavigation() {
    if (!isOnline || interstitialAd == null) return;
    final now = DateTime.now();
    if (_lastInterstitialShownAt != null &&
        now.difference(_lastInterstitialShownAt!) < interstitialMinGap) {
      return;
    }
    _lastInterstitialShownAt = now;
    final ad = interstitialAd!;
    interstitialAd = null;
    ad.show();
  }

  void showAppOpenAdIfAvailable() {
    if (!isOnline || _isShowingAppOpenAd || appOpenAd == null) return;
    final now = DateTime.now();
    if (_lastAppOpenShownAt != null &&
        now.difference(_lastAppOpenShownAt!) < appOpenMinGap) {
      return;
    }
    _lastAppOpenShownAt = now;
    final ad = appOpenAd!;
    appOpenAd = null;
    ad.show();
  }

  void showRewardedForPerk({
    required String perkId,
    required void Function() onEarned,
    required void Function() onNotReady,
  }) {
    final ad = rewardedAd;
    if (ad == null) {
      onNotReady();
      return;
    }
    rewardedAd = null;
    ad.show(onUserEarnedReward: (ad, reward) => onEarned());
  }

  @override
  void dispose() {
    _connSub?.cancel();
    _bannerRefreshTimer?.cancel();
    bannerAd?.dispose();
    nativeAd?.dispose();
    rewardedAd?.dispose();
    interstitialAd?.dispose();
    appOpenAd?.dispose();
    super.dispose();
  }
}

// ============================================================================
// NOTIFICATIONS (كان في notifications.dart)
// ============================================================================

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    tzdata.initializeTimeZones();
    try {
      final String tzName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(tzName));
    } catch (_) {}
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    await _plugin.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
    );
  }

  static Future<void> scheduleDailyReminder(int hour, int minute) async {
    await _plugin.cancel(100);
    final now = tz.TZDateTime.now(tz.local);
    var scheduled =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
  await _plugin.zonedSchedule(
      100,
      'تذكير يومي 💰',
      'لا تنسَ تسجيل مصاريف اليوم في التطبيق',
      scheduled,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_reminder',
          'تذكير يومي',
          channelDescription: 'تذكير لتسجيل المصاريف اليومية',
          importance: Importance.defaultImportance,
        ),
      ),
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  static Future<void> cancelReminder() async {
    await _plugin.cancel(100);
  }
}

// ============================================================================
// APP ENTRY POINT
// ============================================================================

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
    if (state == AppLifecycleState.resumed) {
      AdManager.instance.showAppOpenAdIfAvailable();
    }
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  void _onTabTap(int i) {
    if (i != _tabIndex) {
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

// ============================================================================
// DASHBOARD SCREEN (كان في dashboard_screen.dart)
// ============================================================================

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String? _selectedCategoryId;
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  TxType _quickType = TxType.expense;

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _openQuickAdd() {
    final state = BudgetState.instance;
    _amountController.clear();
    _noteController.clear();
    _selectedCategoryId =
        state.categories.isNotEmpty ? state.categories.first.id : null;
    _quickType = TxType.expense;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('إضافة سريعة',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              SegmentedButton<TxType>(
                segments: const [
                  ButtonSegment(value: TxType.expense, label: Text('مصروف')),
                  ButtonSegment(value: TxType.income, label: Text('دخل')),
                ],
                selected: {_quickType},
                onSelectionChanged: (s) =>
                    setSheetState(() => _quickType = s.first),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _amountController,
                autofocus: true,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'المبلغ (${state.currencySymbol})',
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              if (_quickType == TxType.expense)
                DropdownButtonFormField<String>(
                  value: _selectedCategoryId,
                  decoration: const InputDecoration(
                    labelText: 'الفئة',
                    border: OutlineInputBorder(),
                  ),
                  items: state.categories
                      .map((c) => DropdownMenuItem(
                          value: c.id,
                          child: Row(children: [
                            Icon(c.icon, color: c.color, size: 18),
                            const SizedBox(width: 8),
                            Text(c.name),
                          ])))
                      .toList(),
                  onChanged: (v) =>
                      setSheetState(() => _selectedCategoryId = v),
                ),
              const SizedBox(height: 12),
              TextField(
                controller: _noteController,
                decoration: const InputDecoration(
                  labelText: 'ملاحظة (اختياري)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () async {
                  final amount =
                      double.tryParse(_amountController.text.trim());
                  if (amount == null || amount <= 0) return;
                  final tx = MoneyTransaction(
                    id: DateTime.now().microsecondsSinceEpoch.toString(),
                    categoryId: _quickType == TxType.expense
                        ? _selectedCategoryId
                        : null,
                    amount: amount,
                    note: _noteController.text.trim(),
                    date: DateTime.now(),
                    type: _quickType,
                  );
                  await state.addTransaction(tx);
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (mounted) setState(() {});
                },
                child: const Text('حفظ'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _editOrDeleteTransaction(MoneyTransaction tx) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(children: [
          ListTile(
            leading: const Icon(Icons.delete, color: Colors.red),
            title: const Text('حذف المعاملة'),
            onTap: () async {
              await BudgetState.instance.deleteTransaction(tx.id);
              if (ctx.mounted) Navigator.pop(ctx);
              if (mounted) setState(() {});
            },
          ),
          ListTile(
            leading: const Icon(Icons.close),
            title: const Text('إلغاء'),
            onTap: () => Navigator.pop(ctx),
          ),
        ]),
      ),
    );
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final state = BudgetState.instance;
    final ads = AdManager.instance;

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openQuickAdd,
        icon: const Icon(Icons.add),
        label: const Text('إضافة سريعة'),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
              children: [
                _SummaryCard(state: state),
                const SizedBox(height: 20),
                const Text('الظروف الرقمية',
                    style:
                        TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.3,
                  children: state.categories
                      .map((c) => _EnvelopeCard(category: c, state: state))
                      .toList(),
                ),
                const SizedBox(height: 24),
                const Text('أحدث المعاملات',
                    style:
                        TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                if (state.recentTransactions.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: Text('لا توجد معاملات بعد')),
                  )
                else
                  ...state.recentTransactions.map((tx) {
                    ExpenseCategory? cat;
                    if (tx.categoryId != null) {
                      final matches = state.categories
                          .where((c) => c.id == tx.categoryId);
                      cat = matches.isNotEmpty ? matches.first : null;
                    }
                    final isIncome = tx.type == TxType.income;
                    return Card(
                      child: ListTile(
                        onLongPress: () => _editOrDeleteTransaction(tx),
                        leading: CircleAvatar(
                          backgroundColor:
                              (cat?.color ?? Colors.green).withOpacity(0.15),
                          child: Icon(
                              isIncome
                                  ? Icons.arrow_downward
                                  : (cat?.icon ?? Icons.category),
                              color: cat?.color ?? Colors.green,
                              size: 18),
                        ),
                        title:
                            Text(isIncome ? 'دخل' : (cat?.name ?? 'غير مصنف')),
                        subtitle: Text(tx.note.isEmpty
                            ? _formatDate(tx.date)
                            : '${tx.note} • ${_formatDate(tx.date)}'),
                        trailing: Text(
                          '${isIncome ? '+' : '-'}${tx.amount.toStringAsFixed(0)} ${state.currencySymbol}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isIncome ? Colors.green : Colors.red,
                          ),
                        ),
                      ),
                    );
                  }),
              ],
            ),
          ),
          if (ads.isOnline && ads.isBannerLoaded && ads.bannerAd != null)
            SizedBox(
              width: ads.bannerAd!.size.width.toDouble(),
              height: ads.bannerAd!.size.height.toDouble(),
              child: AdWidget(ad: ads.bannerAd!),
            ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final BudgetState state;
  const _SummaryCard({required this.state});
  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text('الرصيد المتبقي',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
            const SizedBox(height: 6),
            Text(
              '${state.balance.toStringAsFixed(0)} ${state.currencySymbol}',
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.bold,
                color:
                    state.balance >= 0 ? Colors.green.shade700 : Colors.red,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _MiniStat(
                    label: 'الدخل',
                    value: state.totalIncome,
                    color: Colors.green,
                    symbol: state.currencySymbol),
                _MiniStat(
                    label: 'المصاريف',
                    value: state.totalExpense,
                    color: Colors.red,
                    symbol: state.currencySymbol),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  final String symbol;
  const _MiniStat(
      {required this.label,
      required this.value,
      required this.color,
      required this.symbol});
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('${value.toStringAsFixed(0)} $symbol',
            style: TextStyle(fontWeight: FontWeight.bold, color: color)),
        Text(label,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
      ],
    );
  }
}

class _EnvelopeCard extends StatelessWidget {
  final ExpenseCategory category;
  final BudgetState state;
  const _EnvelopeCard({required this.category, required this.state});

  @override
  Widget build(BuildContext context) {
    final spent = state.spentInCategory(category.id);
    final budget = category.monthlyBudget;
    final ratio = budget > 0 ? (spent / budget) : 0.0;
    Color barColor;
    if (budget <= 0) {
      barColor = Colors.grey;
    } else if (ratio >= 1) {
      barColor = Colors.red;
    } else if (ratio >= 0.75) {
      barColor = Colors.amber;
    } else {
      barColor = Colors.green;
    }
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: category.color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: category.color.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(category.icon, color: category.color, size: 20),
              const SizedBox(width: 6),
              Expanded(
                child: Text(category.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const Spacer(),
          Text(
            '${spent.toStringAsFixed(0)} / ${budget > 0 ? budget.toStringAsFixed(0) : '∞'} ${state.currencySymbol}',
            style: const TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: budget > 0 ? ratio.clamp(0, 1) : 0,
              minHeight: 7,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation(barColor),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// ANALYTICS SCREEN (كان في analytics_screen.dart)
// ============================================================================

class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  List<String> _smartAlerts(BudgetState state) {
    final alerts = <String>[];
    final now = DateTime.now();
    final dayOfMonth = now.day;
    for (final c in state.categories) {
      if (c.monthlyBudget <= 0) continue;
      final spent = state.spentInCategory(c.id);
      final ratio = spent / c.monthlyBudget;
      if (ratio >= 1) {
        alerts.add('تجاوزت ميزانية ${c.name} هذا الشهر 🚨');
      } else if (ratio >= 0.8 && dayOfMonth <= 15) {
        alerts.add(
            'استهلكت ${(ratio * 100).toStringAsFixed(0)}% من ميزانية ${c.name} خلال أول $dayOfMonth أيام من الشهر ⚠️');
      }
    }
    if (alerts.isEmpty && state.totalExpense > 0) {
      alerts.add('إنفاقك ضمن السيطرة هذا الشهر، استمر! 👍');
    }
    return alerts;
  }

  @override
  Widget build(BuildContext context) {
    final state = BudgetState.instance;
    final ads = AdManager.instance;
    final totals = state.categoryTotalsThisMonth();
    final monthly = state.monthlyExpenseTotals();
    final alerts = _smartAlerts(state);
    const monthNames = [
      'ينا', 'فبر', 'مار', 'أبر', 'ماي', 'يون',
      'يول', 'أغس', 'سبت', 'أكت', 'نوف', 'ديس'
    ];

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
            children: [
              const Text('توزيع المصاريف هذا الشهر',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              if (totals.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child:
                      Center(child: Text('لا توجد مصاريف مسجلة هذا الشهر')),
                )
              else
                SizedBox(
                  height: 220,
                  child: Row(
                    children: [
                      Expanded(
                        child: PieChart(
                          PieChartData(
                            sectionsSpace: 2,
                            centerSpaceRadius: 40,
                            sections: totals.entries.map((e) {
                              final cat = state.categories
                                  .firstWhere((c) => c.id == e.key);
                              final pct = state.totalExpense > 0
                                  ? (e.value / state.totalExpense * 100)
                                  : 0;
                              return PieChartSectionData(
                                value: e.value,
                                color: cat.color,
                                title: '${pct.toStringAsFixed(0)}%',
                                radius: 55,
                                titleStyle: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: totals.entries.map((e) {
                            final cat = state.categories
                                .firstWhere((c) => c.id == e.key);
                            return Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 3),
                              child: Row(
                                children: [
                                  Container(
                                      width: 10, height: 10, color: cat.color),
                                  const SizedBox(width: 6),
                                  Expanded(
                                      child: Text(cat.name,
                                          style:
                                              const TextStyle(fontSize: 12),
                                          overflow: TextOverflow.ellipsis)),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 28),
              const Text('مقارنة آخر 6 أشهر',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              SizedBox(
                height: 180,
                child: BarChart(
                  BarChartData(
                    borderData: FlBorderData(show: false),
                    gridData: const FlGridData(show: false),
                    titlesData: FlTitlesData(
                      leftTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (v, meta) {
                            final now = DateTime.now();
                            final m =
                                DateTime(now.year, now.month - (5 - v.toInt()));
                            return Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(monthNames[m.month - 1],
                                  style: const TextStyle(fontSize: 10)),
                            );
                          },
                        ),
                      ),
                    ),
                    barGroups: List.generate(monthly.length, (i) {
                      return BarChartGroupData(x: i, barRods: [
                        BarChartRodData(
                          toY: monthly[i],
                          color: Theme.of(context).colorScheme.primary,
                          width: 18,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ]);
                    }),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              const Text('تنبيهات ذكية',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              ...alerts.map((a) => Card(
                    color: Colors.amber.withOpacity(0.12),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Text(a),
                    ),
                  )),
            ],
          ),
        ),
        if (ads.isOnline && ads.isBannerLoaded && ads.bannerAd != null)
          SizedBox(
            width: ads.bannerAd!.size.width.toDouble(),
            height: ads.bannerAd!.size.height.toDouble(),
            child: AdWidget(ad: ads.bannerAd!),
          ),
      ],
    );
  }
}

// ============================================================================
// CHALLENGES SCREEN (كان في challenges_screen.dart)
// ============================================================================

class ChallengesScreen extends StatefulWidget {
  const ChallengesScreen({super.key});
  @override
  State<ChallengesScreen> createState() => _ChallengesScreenState();
}

class _ChallengesScreenState extends State<ChallengesScreen> {
  void _addGoalDialog() {
    final nameCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    DateTime? deadline;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text('هدف توفير جديد'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'اسم الهدف'),
              ),
              TextField(
                controller: amountCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'المبلغ المطلوب'),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                icon: const Icon(Icons.calendar_month),
                label: Text(deadline == null
                    ? 'اختر تاريخاً نهائياً (اختياري)'
                    : '${deadline!.year}/${deadline!.month}/${deadline!.day}'),
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 3650)),
                    initialDate: DateTime.now().add(const Duration(days: 30)),
                  );
                  if (picked != null) setD(() => deadline = picked);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('إلغاء')),
            FilledButton(
              onPressed: () async {
                final amount = double.tryParse(amountCtrl.text.trim());
                if (nameCtrl.text.trim().isEmpty ||
                    amount == null ||
                    amount <= 0) {
                  return;
                }
                await BudgetState.instance.addGoal(SavingsGoal(
                  id: DateTime.now().microsecondsSinceEpoch.toString(),
                  name: nameCtrl.text.trim(),
                  targetAmount: amount,
                  deadline: deadline,
                ));
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) setState(() {});
              },
              child: const Text('إنشاء'),
            ),
          ],
        ),
      ),
    );
  }

  void _addToGoalDialog(SavingsGoal g) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('إضافة إلى: ${g.name}'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'المبلغ'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () async {
              final v = double.tryParse(ctrl.text.trim());
              if (v == null || v <= 0) return;
              await BudgetState.instance.addToGoal(g.id, v);
              if (ctx.mounted) Navigator.pop(ctx);
              if (mounted) setState(() {});
            },
            child: const Text('إضافة'),
          ),
        ],
      ),
    );
  }

  void _watchAdForPerk(String perkId, String successMessage) {
    AdManager.instance.showRewardedForPerk(
      perkId: perkId,
      onEarned: () async {
        await BudgetState.instance.unlockPerk(perkId);
        if (mounted) {
          setState(() {});
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(successMessage)));
        }
      },
      onNotReady: () {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('الإعلان لسه بيتحمّل، حاول بعد لحظة')));
      },
    );
  }

  Widget _perkChip(String id, String label, String successMsg) {
    final unlocked = BudgetState.instance.unlockedPerks.contains(id);
    return ActionChip(
      avatar:
          Icon(unlocked ? Icons.check : Icons.play_circle_fill, size: 18),
      label: Text(unlocked ? '$label (مفتوح)' : label),
      onPressed: unlocked ? null : () => _watchAdForPerk(id, successMsg),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = BudgetState.instance;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('حصالة الأهداف',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            IconButton(
                onPressed: _addGoalDialog,
                icon: const Icon(Icons.add_circle)),
          ],
        ),
        if (state.goals.isEmpty)
          const Padding(
            padding: EdgeInsets.all(20),
            child: Center(child: Text('لا توجد أهداف بعد، أنشئ أول هدف لك!')),
          )
        else
          ...state.goals.map((g) => Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(g.name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold)),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 20),
                            onPressed: () async {
                              await BudgetState.instance.deleteGoal(g.id);
                              setState(() {});
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: g.progress,
                          minHeight: 8,
                          backgroundColor: Colors.grey.shade200,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                              '${g.savedAmount.toStringAsFixed(0)} / ${g.targetAmount.toStringAsFixed(0)} ${state.currencySymbol}'),
                          Text('${(g.progress * 100).toStringAsFixed(0)}%'),
                        ],
                      ),
                      if (g.deadline != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                              'الموعد: ${g.deadline!.year}/${g.deadline!.month}/${g.deadline!.day}',
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.grey)),
                        ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: OutlinedButton(
                          onPressed: () => _addToGoalDialog(g),
                          child: const Text('إضافة مبلغ'),
                        ),
                      ),
                    ],
                  ),
                ),
              )),
        const SizedBox(height: 24),
        const Text('تحدي الـ 30 يوماً',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    'عدد أيام الالتزام: ${state.thirtyDayCheckins.length} / 30'),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: (state.thirtyDayCheckins.length / 30).clamp(0, 1),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: state.checkedInToday
                      ? null
                      : () async {
                          final ok =
                              await state.checkInThirtyDayChallenge();
                          if (ok && state.goals.isNotEmpty) {
                            await state.addToGoal(state.goals.first.id,
                                state.thirtyDayDailyAmount);
                          }
                          if (mounted) setState(() {});
                        },
                  icon: const Icon(Icons.check_circle_outline),
                  label: Text(state.checkedInToday
                      ? 'تم تسجيل اليوم ✅'
                      : 'تسجيل اليوم (+${state.thirtyDayDailyAmount.toStringAsFixed(0)} ${state.currencySymbol})'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        const Text('تتبع الامتناع عن الشراء',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('أيام الامتناع: ${state.noSpendDays.length} يوم'),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: state.markedNoSpendToday
                      ? null
                      : () async {
                          final ok = await state.markNoSpendToday();
                          if (ok && state.goals.isNotEmpty) {
                            await state.addToGoal(
                                state.goals.first.id, state.noSpendDailyAmount);
                          }
                          if (mounted) setState(() {});
                        },
                  icon: const Icon(Icons.block),
                  label: Text(state.markedNoSpendToday
                      ? 'تم تسجيل اليوم ✅'
                      : 'لم أصرف اليوم (+${state.noSpendDailyAmount.toStringAsFixed(0)} ${state.currencySymbol} للحصالة)'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        const Text('مكافآت عبر الفيديو 🎁',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Card(
          color: Colors.indigo.shade50,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('شاهد فيديو قصير مقابل:'),
                const SizedBox(height: 10),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  _perkChip('theme_gold', 'فتح ثيم ذهبي 👑',
                      'تم فتح الثيم الذهبي!'),
                  _perkChip('extra_categories', 'فئات مخصصة إضافية',
                      'تم فتح فئات إضافية!'),
                  _perkChip('badge_saver', 'وسام موفّر 🏅',
                      'حصلت على وسام الموفّر!'),
                ]),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// SETTINGS SCREEN (كان في settings_screen.dart)
// ============================================================================

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  void _addOrEditCategory({ExpenseCategory? existing}) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final budgetCtrl = TextEditingController(
        text: existing != null && existing.monthlyBudget > 0
            ? existing.monthlyBudget.toStringAsFixed(0)
            : '');
    IconData selectedIcon =
        existing != null ? existing.icon : pickableIcons.first;
    Color selectedColor =
        existing != null ? existing.color : pickableColors.first;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text(existing == null ? 'فئة جديدة' : 'تعديل الفئة'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'اسم الفئة'),
                ),
                TextField(
                  controller: budgetCtrl,
                  keyboardType: TextInputType.number,
                  decoration:
                      const InputDecoration(labelText: 'الميزانية الشهرية'),
                ),
                const SizedBox(height: 10),
                const Align(
                    alignment: Alignment.centerRight,
                    child: Text('الأيقونة')),
                Wrap(
                  spacing: 6,
                  children: pickableIcons
                      .map((i) => GestureDetector(
                            onTap: () => setD(() => selectedIcon = i),
                            child: CircleAvatar(
                              backgroundColor: i == selectedIcon
                                  ? selectedColor.withOpacity(0.3)
                                  : Colors.grey.shade200,
                              child: Icon(i, size: 18),
                            ),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 10),
                const Align(
                    alignment: Alignment.centerRight, child: Text('اللون')),
                Wrap(
                  spacing: 6,
                  children: pickableColors
                      .map((c) => GestureDetector(
                            onTap: () => setD(() => selectedColor = c),
                            child: CircleAvatar(
                              backgroundColor: c,
                              radius: 14,
                              child: c.value == selectedColor.value
                                  ? const Icon(Icons.check,
                                      color: Colors.white, size: 16)
                                  : null,
                            ),
                          ))
                      .toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('إلغاء')),
            FilledButton(
              onPressed: () async {
                if (nameCtrl.text.trim().isEmpty) return;
                final budget = double.tryParse(budgetCtrl.text.trim()) ?? 0;
                final cat = ExpenseCategory(
                  id: existing?.id ??
                      DateTime.now().microsecondsSinceEpoch.toString(),
                  name: nameCtrl.text.trim(),
                  iconCodePoint: selectedIcon.codePoint,
                  colorValue: selectedColor.value,
                  monthlyBudget: budget,
                );
                if (existing == null) {
                  await BudgetState.instance.addCategory(cat);
                } else {
                  await BudgetState.instance.updateCategory(cat);
                }
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) setState(() {});
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportBackup() async {
    final data = BudgetState.instance.exportBackupJson();
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/budget_backup.json');
    await file.writeAsString(data);
    await Share.shareXFiles([XFile(file.path)],
        text: 'نسخة احتياطية من بيانات التطبيق');
  }

  Future<void> _importBackup() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (result == null || result.files.single.path == null) return;
    final file = File(result.files.single.path!);
    final content = await file.readAsString();
    try {
      await BudgetState.instance.importBackupJson(content);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم استيراد النسخة الاحتياطية بنجاح')));
        setState(() {});
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('تعذّر قراءة الملف، تأكد أنه نسخة صحيحة')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = BudgetState.instance;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      children: [
        const Text('العملة',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        DropdownButton<String>(
          value: state.currencySymbol,
          isExpanded: true,
          items: supportedCurrencies
              .map((c) => DropdownMenuItem(value: c, child: Text(c)))
              .toList(),
          onChanged: (v) {
            if (v != null) state.setCurrency(v);
            setState(() {});
          },
        ),
        const Divider(height: 32),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('الوضع الداكن'),
          value: state.darkMode,
          onChanged: (v) {
            state.setDarkMode(v);
            setState(() {});
          },
        ),
        const Divider(height: 32),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('الفئات',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            IconButton(
                onPressed: () => _addOrEditCategory(),
                icon: const Icon(Icons.add_circle)),
          ],
        ),
        ...state.categories.map((c) => Card(
              child: ListTile(
                leading: CircleAvatar(
                    backgroundColor: c.color.withOpacity(0.2),
                    child: Icon(c.icon, color: c.color)),
                title: Text(c.name),
                subtitle: Text(c.monthlyBudget > 0
                    ? 'ميزانية: ${c.monthlyBudget.toStringAsFixed(0)} ${state.currencySymbol}'
                    : 'بدون ميزانية محددة'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                        icon: const Icon(Icons.edit, size: 20),
                        onPressed: () => _addOrEditCategory(existing: c)),
                    IconButton(
                        icon: const Icon(Icons.delete_outline, size: 20),
                        onPressed: () async {
                          await state.deleteCategory(c.id);
                          setState(() {});
                        }),
                  ],
                ),
              ),
            )),
        const Divider(height: 32),
        const Text('التذكير اليومي',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(
              'تذكير الساعة ${state.reminderHour.toString().padLeft(2, '0')}:${state.reminderMinute.toString().padLeft(2, '0')}'),
          value: state.reminderEnabled,
          onChanged: (v) async {
            await state.setReminder(
                v, state.reminderHour, state.reminderMinute);
            if (v) {
              await NotificationService.scheduleDailyReminder(
                  state.reminderHour, state.reminderMinute);
            } else {
              await NotificationService.cancelReminder();
            }
            setState(() {});
          },
        ),
        TextButton.icon(
          icon: const Icon(Icons.access_time),
          label: const Text('تغيير وقت التذكير'),
          onPressed: () async {
            final picked = await showTimePicker(
              context: context,
              initialTime: TimeOfDay(
                  hour: state.reminderHour, minute: state.reminderMinute),
            );
            if (picked != null) {
              await state.setReminder(
                  state.reminderEnabled, picked.hour, picked.minute);
              if (state.reminderEnabled) {
                await NotificationService.scheduleDailyReminder(
                    picked.hour, picked.minute);
              }
              setState(() {});
            }
          },
        ),
        const Divider(height: 32),
        const Text('النسخ الاحتياطي',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.upload_file),
                label: const Text('تصدير'),
                onPressed: _exportBackup,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.download),
                label: const Text('استيراد'),
                onPressed: _importBackup,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

