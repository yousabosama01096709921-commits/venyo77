// main.dart
// تطبيق "فوكس بومو" — مؤقّت بومودورو احترافي مع إحصائيات وتلعيب
// ============================================================
//
// التحديثات في هذه النسخة (بناءً على طلبك):
// 1) إعلانات إضافية لزيادة الربح:
//      - إعلان App Open (يظهر عند فتح التطبيق / العودة إليه من الخلفية).
//      - إعلان Interstitial (بيني) يظهر كل عدد محدد من جلسات التركيز المكتملة.
//      - إعلان Rewarded مستقل خاص بفتح "الوضع المميز" 24 ساعة (بالإضافة إلى
//        رواردد مضاعفة العملات الموجود أصلاً) — أي مصدرين رواردد منفصلين.
// 2) تحميل مسبق لكل الإعلانات فور فتح التطبيق (Banner / Native / Rewarded x2
//    / Interstitial / App Open) + إعادة تحميل تلقائية بعد كل استخدام.
// 3) ميزات جديدة لتمييز التطبيق:
//      - "وسم الجلسة" (Task Tag): يقدر المستخدم يكتب على أي مهمة بيركّز قبل
//        ما يبدأ، ويظهر الوسم في سجل الجلسات.
//      - رسائل تحفيزية عشوائية تتغيّر مع كل جلسة/شاشة.
//      - نظام أوسمة إنجاز (Achievements) يُفتح تلقائياً حسب عدد الجلسات
//        والسلسلة اليومية — يظهر في شاشة الإحصائيات.
//      - رسم بياني أسبوعي بسيط لعدد دقائق التركيز آخر 7 أيام.
// 4) "الوضع المميز" (Premium) لمدة 24 ساعة عبر مشاهدة إعلان مكافأة:
//      - أثناء التفعيل: تختفي إعلانات البانر والـ Native (تجربة بلا إعلانات
//        مزعجة)، ويُسمح باختيار مدة تركيز مخصّصة، وتُفتح ثيمتان حصريتان.
//      - عدّاد تنازلي واضح في الأعلى والمتجر يوضح الوقت المتبقي.
// 5) رسائل تشجيعية عربية قصيرة تظهر في المؤقّت وبعد إكمال كل جلسة.
//
// خطوات التشغيل:
// 1) flutter create focus_pomo
// 2) استبدل pubspec.yaml بالنسخة المرفقة (أو أضف التبعيات المذكورة أسفل)
//      dependencies:
//        google_mobile_ads: ^5.1.0
//        shared_preferences: ^2.2.3
// 3) استبدل lib/main.dart بهذا الملف.
// 4) أضف معرف AdMob في AndroidManifest.xml داخل <application>:
//      <meta-data
//          android:name="com.google.android.gms.ads.APPLICATION_ID"
//          android:value="ca-app-pub-3940256099942544~3347511713"/>
// 5) استبدل كل معرفات الإعلانات أدناه بمعرفاتك الحقيقية قبل النشر على المتجر
//    (استخدام معرفات الاختبار في نسخة منشورة يخالف سياسات AdMob).
//
// ملاحظة: المعرفات أدناه هي معرفات اختبار رسمية من جوجل — آمنة للتجربة فقط.
// ملاحظة أخرى: لا تُكثر من الإعلانات البينية (Interstitial) بشكل مبالغ فيه؛
// سياسات AdMob تمنع عرضها بشكل مزعج جداً أو عند كل نقرة، لذلك تم ضبط عدّاد
// تكرار معقول (كل 3 جلسات تركيز مكتملة) وفاصل زمني أدنى لإعلان App Open.

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------------------
// إعدادات عامة
// ---------------------------------------------------------------------------
const int workMinutesDefault = 25;
const int shortBreakMinutesDefault = 5;
const int longBreakMinutesDefault = 15;
const int sessionsBeforeLongBreak = 4;

const int coinsPerSession = 10; // عملات مقابل كل جلسة تركيز مكتملة
const int coinsStreakBonus = 20; // مكافأة إضافية عند الحفاظ على السلسلة يومياً
const int themeCostLow = 30;
const int themeCostMid = 60;
const int themeCostHigh = 100;

const int nativeAdEveryNItems = 4; // إعلان Native كل كم عنصر في قائمة السجل
const int bannerRefreshSeconds = 45;

// كل كم جلسة عمل مكتملة يظهر إعلان بيني (Interstitial)
const int interstitialEverySessions = 3;
// أقل فاصل زمني بين ظهورين لإعلان App Open حتى لا يكون مزعجاً
const Duration appOpenMinGap = Duration(hours: 4);

// مدة تفعيل "الوضع المميز" بعد مشاهدة إعلان المكافأة
const Duration premiumUnlockDuration = Duration(hours: 24);

// مدد تركيز مخصّصة متاحة فقط في الوضع المميز
const List<int> premiumWorkMinuteOptions = [15, 20, 25, 30, 45, 60];

// معرفات اختبار AdMob الرسمية — استبدلها بمعرفاتك الحقيقية عند النشر
const String bannerAdUnitId = 'ca-app-pub-3940256099942544/6300978111';
const String nativeAdUnitId = 'ca-app-pub-3940256099942544/2247696110';
const String rewardedAdUnitId = 'ca-app-pub-3940256099942544/5224354917';
const String rewardedPremiumAdUnitId =
    'ca-app-pub-3940256099942544/5224354917';
const String interstitialAdUnitId = 'ca-app-pub-3940256099942544/1033173712';
const String appOpenAdUnitId = 'ca-app-pub-3940256099942544/9257395921';

// رسائل تحفيزية قصيرة تظهر عشوائياً لتشجيع المستخدم
const List<String> motivationalQuotes = [
  'خطوة صغيرة الآن تساوي إنجازاً كبيراً لاحقاً 🌱',
  'التركيز 25 دقيقة يهزم التسويف ساعات ⏳',
  'أنت أقرب لهدفك من أمس، كمّل 💪',
  'دقيقة تركيز حقيقية أفضل من ساعة تشتت 🎯',
  'ابدأ الآن، الكمال يأتي بعد التكرار ✨',
  'سلسلتك اليومية دليل انضباطك، حافظ عليها 🔥',
  'كل بومودورو تُكمله هو استثمار في نفسك 📈',
  'لا تنتظر الحافز، ابدأ ويأتيك الحافز لاحقاً 🚀',
  'الراحة القصيرة تشحنك، لا تتجاوزها 🌿',
  'إنجاز اليوم هو ثقة الغد، استمر 🏆',
];

String randomMotivationalQuote() =>
    motivationalQuotes[Random().nextInt(motivationalQuotes.length)];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await MobileAds.instance.initialize();
  await AppState.instance.load();
  AdManager.instance.preloadAll();
  runApp(const FocusPomoApp());
}

class FocusPomoApp extends StatelessWidget {
  const FocusPomoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'فوكس بومو',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.indigo,
      ),
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: child!,
      ),
      home: const HomeScreen(),
    );
  }
}

// =============================================================================
// نماذج المتجر (ثيمات ألوان)
// =============================================================================
class ThemeOption {
  final String id;
  final String name;
  final Color color;
  final int cost;
  final bool premiumOnly; // ثيم حصري: يتطلب شراء أو تفعيل الوضع المميز
  const ThemeOption({
    required this.id,
    required this.name,
    required this.color,
    required this.cost,
    this.premiumOnly = false,
  });
}

const List<ThemeOption> themeOptions = [
  ThemeOption(id: 'indigo', name: 'نيلي هادئ', color: Colors.indigo, cost: 0),
  ThemeOption(
      id: 'teal', name: 'أخضر مركّز', color: Colors.teal, cost: themeCostLow),
  ThemeOption(
      id: 'deepOrange',
      name: 'برتقالي حيوي',
      color: Colors.deepOrange,
      cost: themeCostLow),
  ThemeOption(
      id: 'purple',
      name: 'بنفسجي إبداعي',
      color: Colors.deepPurple,
      cost: themeCostMid),
  ThemeOption(
      id: 'blueGrey',
      name: 'كحلي احترافي',
      color: Colors.blueGrey,
      cost: themeCostMid),
  ThemeOption(
      id: 'pink',
      name: 'وردي طاقة',
      color: Colors.pinkAccent,
      cost: themeCostHigh),
  // ثيمات حصرية: تُفتح مجاناً أثناء الوضع المميز، أو تُشترى بعملات دائمة
  ThemeOption(
      id: 'gold',
      name: 'ذهبي حصري 👑',
      color: Color(0xFFC9A227),
      cost: 150,
      premiumOnly: true),
  ThemeOption(
      id: 'emerald',
      name: 'زمردي حصري 👑',
      color: Color(0xFF0F9D58),
      cost: 150,
      premiumOnly: true),
];

// =============================================================================
// سجل جلسة تركيز واحدة
// =============================================================================
class FocusSession {
  final DateTime date;
  final int minutes;
  final String? label; // وسم اختياري: على أي مهمة كان التركيز
  FocusSession({required this.date, required this.minutes, this.label});

  Map<String, dynamic> toJson() =>
      {'date': date.toIso8601String(), 'minutes': minutes, 'label': label};
  factory FocusSession.fromJson(Map<String, dynamic> j) => FocusSession(
        date: DateTime.parse(j['date'] as String),
        minutes: j['minutes'] as int,
        label: j['label'] as String?,
      );
}

// =============================================================================
// نموذج وسام إنجاز (Achievement)
// =============================================================================
class Achievement {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final bool Function(AppState state) isUnlocked;
  const Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.isUnlocked,
  });
}

final List<Achievement> achievements = [
  Achievement(
    id: 'first_session',
    title: 'أول خطوة',
    description: 'أكملت أول جلسة تركيز',
    icon: Icons.flag,
    isUnlocked: (s) => s.totalSessions >= 1,
  ),
  Achievement(
    id: 'ten_sessions',
    title: 'منضبط',
    description: 'أكملت 10 جلسات تركيز',
    icon: Icons.star,
    isUnlocked: (s) => s.totalSessions >= 10,
  ),
  Achievement(
    id: 'fifty_sessions',
    title: 'محترف تركيز',
    description: 'أكملت 50 جلسة تركيز',
    icon: Icons.workspace_premium,
    isUnlocked: (s) => s.totalSessions >= 50,
  ),
  Achievement(
    id: 'streak_3',
    title: 'ثابت',
    description: 'حافظت على سلسلة 3 أيام متتالية',
    icon: Icons.local_fire_department,
    isUnlocked: (s) => s.streakDays >= 3,
  ),
  Achievement(
    id: 'streak_7',
    title: 'أسبوع كامل',
    description: 'حافظت على سلسلة 7 أيام متتالية',
    icon: Icons.whatshot,
    isUnlocked: (s) => s.streakDays >= 7,
  ),
  Achievement(
    id: 'level_5',
    title: 'صاعد بقوة',
    description: 'وصلت للمستوى 5',
    icon: Icons.trending_up,
    isUnlocked: (s) => s.level >= 5,
  ),
];

// =============================================================================
// حالة التطبيق العامة: إحصائيات، عملات، مستوى، سلسلة أيام، ثيم، تخزين محلي
// =============================================================================
class AppState extends ChangeNotifier {
  AppState._internal();
  static final AppState instance = AppState._internal();

  int coins = 0;
  int totalSessions = 0;
  int streakDays = 0;
  DateTime? lastCompletedDay;
  bool rewardedUsedToday = false;

  String selectedThemeId = 'indigo';
  final Set<String> ownedThemeIds = {'indigo'};

  // الوضع المميز (24 ساعة عبر إعلان مكافأة)
  DateTime? premiumUntil;
  int? customWorkMinutes; // مدة تركيز مخصّصة (متاحة فقط أثناء الوضع المميز)

  final List<FocusSession> history = [];

  bool get isPremiumActive =>
      premiumUntil != null && DateTime.now().isBefore(premiumUntil!);

  Duration get premiumRemaining => isPremiumActive
      ? premiumUntil!.difference(DateTime.now())
      : Duration.zero;

  int get effectiveWorkMinutes =>
      (isPremiumActive && customWorkMinutes != null)
          ? customWorkMinutes!
          : workMinutesDefault;

  int get level => 1 + (totalSessions ~/ 5);
  int get todaysSessions =>
      history.where((s) => _isSameDay(s.date, DateTime.now())).length;
  int get todaysMinutes => history
      .where((s) => _isSameDay(s.date, DateTime.now()))
      .fold(0, (sum, s) => sum + s.minutes);

  // دقائق التركيز لكل يوم من آخر 7 أيام (للرسم البياني الأسبوعي)
  List<int> get last7DaysMinutes {
    final now = DateTime.now();
    return List.generate(7, (i) {
      final day = now.subtract(Duration(days: 6 - i));
      return history
          .where((s) => _isSameDay(s.date, day))
          .fold(0, (sum, s) => sum + s.minutes);
    });
  }

  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    coins = prefs.getInt('coins') ?? 0;
    totalSessions = prefs.getInt('totalSessions') ?? 0;
    streakDays = prefs.getInt('streakDays') ?? 0;
    selectedThemeId = prefs.getString('selectedThemeId') ?? 'indigo';
    ownedThemeIds.addAll(prefs.getStringList('ownedThemeIds') ?? ['indigo']);
    customWorkMinutes = prefs.getInt('customWorkMinutes');
    final lastDayStr = prefs.getString('lastCompletedDay');
    if (lastDayStr != null) lastCompletedDay = DateTime.tryParse(lastDayStr);
    final lastRewardDayStr = prefs.getString('lastRewardDay');
    rewardedUsedToday = lastRewardDayStr != null &&
        _isSameDay(DateTime.parse(lastRewardDayStr), DateTime.now());
    final premiumUntilStr = prefs.getString('premiumUntil');
    if (premiumUntilStr != null) {
      premiumUntil = DateTime.tryParse(premiumUntilStr);
    }
    notifyListeners();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('coins', coins);
    await prefs.setInt('totalSessions', totalSessions);
    await prefs.setInt('streakDays', streakDays);
    await prefs.setString('selectedThemeId', selectedThemeId);
    await prefs.setStringList('ownedThemeIds', ownedThemeIds.toList());
    if (customWorkMinutes != null) {
      await prefs.setInt('customWorkMinutes', customWorkMinutes!);
    }
    if (lastCompletedDay != null) {
      await prefs.setString(
          'lastCompletedDay', lastCompletedDay!.toIso8601String());
    }
    if (premiumUntil != null) {
      await prefs.setString('premiumUntil', premiumUntil!.toIso8601String());
    }
  }

  // يُستدعى عند إكمال جلسة تركيز (وقت عمل كامل بدون إلغاء)
  Future<void> completeFocusSession(int minutes, {String? label}) async {
    totalSessions += 1;
    coins += coinsPerSession;
    history.insert(
        0, FocusSession(date: DateTime.now(), minutes: minutes, label: label));

    final today = DateTime.now();
    if (lastCompletedDay == null) {
      streakDays = 1;
    } else if (_isSameDay(lastCompletedDay!, today)) {
      // نفس اليوم، لا تغيير على السلسلة
    } else if (today.difference(lastCompletedDay!).inDays == 1 ||
        (_isSameDay(
            lastCompletedDay!, today.subtract(const Duration(days: 1))))) {
      streakDays += 1;
      coins += coinsStreakBonus;
    } else {
      streakDays = 1;
    }
    lastCompletedDay = today;
    await _save();
    notifyListeners();
  }

  bool buyTheme(ThemeOption option) {
    if (ownedThemeIds.contains(option.id)) return false;
    if (coins < option.cost) return false;
    coins -= option.cost;
    ownedThemeIds.add(option.id);
    _save();
    notifyListeners();
    return true;
  }

  // هل يمكن استخدام هذا الثيم الآن؟ (مملوك دائماً، أو حصري ومفعّل عليه الوضع المميز)
  bool canUseTheme(ThemeOption option) {
    if (ownedThemeIds.contains(option.id)) return true;
    if (option.premiumOnly && isPremiumActive) return true;
    return false;
  }

  void selectTheme(String id) {
    selectedThemeId = id;
    _save();
    notifyListeners();
  }

  void setCustomWorkMinutes(int minutes) {
    customWorkMinutes = minutes;
    _save();
    notifyListeners();
  }

  Future<void> doubleTodaysCoinsViaAd() async {
    if (rewardedUsedToday) return;
    final bonus = coinsPerSession * todaysSessions;
    coins += bonus > 0 ? bonus : coinsStreakBonus;
    rewardedUsedToday = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('lastRewardDay', DateTime.now().toIso8601String());
    await _save();
    notifyListeners();
  }

  // تفعيل الوضع المميز 24 ساعة بعد مشاهدة إعلان مكافأة كامل
  Future<void> unlockPremiumFor24h() async {
    final base =
        isPremiumActive ? premiumUntil! : DateTime.now(); // تمديد إن كان مفعّلاً
    premiumUntil = base.add(premiumUnlockDuration);
    await _save();
    notifyListeners();
  }
}

// =============================================================================
// مدير الإعلانات المركزي
// =============================================================================
class AdManager extends ChangeNotifier {
  AdManager._internal();
  static final AdManager instance = AdManager._internal();

  BannerAd? bannerAd;
  bool isBannerLoaded = false;

  NativeAd? nativeAd;
  bool isNativeLoaded = false;

  RewardedAd? rewardedAd; // لمضاعفة عملات اليوم
  RewardedAd? rewardedPremiumAd; // لفتح الوضع المميز 24 ساعة

  InterstitialAd? interstitialAd;
  int _sessionsSinceLastInterstitial = 0;

  AppOpenAd? appOpenAd;
  bool _isShowingAppOpenAd = false;
  DateTime? _lastAppOpenShownAt;

  Timer? _bannerRefreshTimer;

  void preloadAll() {
    loadBanner();
    loadNative();
    loadRewarded();
    loadRewardedPremium();
    loadInterstitial();
    loadAppOpen();
    _bannerRefreshTimer?.cancel();
    _bannerRefreshTimer = Timer.periodic(
      const Duration(seconds: bannerRefreshSeconds),
      (_) => loadBanner(),
    );
  }

  void loadBanner() {
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
          debugPrint('فشل تحميل البانر: $error');
        },
      ),
    );
    banner.load();
  }

  void loadNative() {
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
          debugPrint('فشل تحميل الإعلان المدمج: $error');
        },
      ),
      nativeTemplateStyle: NativeTemplateStyle(
        templateType: TemplateType.small,
      ),
    );
    ad.load();
  }

  void loadRewarded() {
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
          debugPrint('فشل تحميل إعلان المكافأة: $error');
          rewardedAd = null;
        },
      ),
    );
  }

  // إعلان مكافأة منفصل مخصّص لفتح الوضع المميز (مصدر ربح إضافي مستقل)
  void loadRewardedPremium() {
    RewardedAd.load(
      adUnitId: rewardedPremiumAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          rewardedPremiumAd = ad;
          rewardedPremiumAd!.fullScreenContentCallback =
              FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              rewardedPremiumAd = null;
              loadRewardedPremium();
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();
              rewardedPremiumAd = null;
              loadRewardedPremium();
            },
          );
          notifyListeners();
        },
        onAdFailedToLoad: (error) {
          debugPrint('فشل تحميل إعلان مكافأة المميز: $error');
          rewardedPremiumAd = null;
        },
      ),
    );
  }

  void loadInterstitial() {
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
          debugPrint('فشل تحميل الإعلان البيني: $error');
          interstitialAd = null;
        },
      ),
    );
  }

  // يُستدعى بعد كل جلسة عمل مكتملة؛ يعرض الإعلان البيني كل N جلسات فقط
  void maybeShowInterstitialAfterSession() {
    _sessionsSinceLastInterstitial += 1;
    if (_sessionsSinceLastInterstitial < interstitialEverySessions) return;
    if (interstitialAd == null) return; // لسه محمّلش، تجاهل بهدوء
    _sessionsSinceLastInterstitial = 0;
    final ad = interstitialAd!;
    interstitialAd = null;
    ad.show();
  }

  void loadAppOpen() {
    AppOpenAd.load(
      adUnitId: appOpenAdUnitId,
      request: const AdRequest(),
      adLoadCallback: AppOpenAdLoadCallback(
        onAdLoaded: (ad) {
          appOpenAd = ad;
          appOpenAd!.fullScreenContentCallback = FullScreenContentCallback(
            onAdShowedFullScreenContent: (ad) {
              _isShowingAppOpenAd = true;
            },
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
          debugPrint('فشل تحميل إعلان فتح التطبيق: $error');
          appOpenAd = null;
        },
      ),
    );
  }

  // يُستدعى عند أول فتح للتطبيق وعند العودة من الخلفية (Resumed)
  void showAppOpenAdIfAvailable() {
    if (_isShowingAppOpenAd) return;
    if (appOpenAd == null) return;
    final now = DateTime.now();
    if (_lastAppOpenShownAt != null &&
        now.difference(_lastAppOpenShownAt!) < appOpenMinGap) {
      return; // احترام الحد الأدنى الزمني بين إعلانين حتى لا يكون مزعجاً
    }
    _lastAppOpenShownAt = now;
    final ad = appOpenAd!;
    appOpenAd = null;
    ad.show();
  }

  void disposeAll() {
    _bannerRefreshTimer?.cancel();
    bannerAd?.dispose();
    nativeAd?.dispose();
    rewardedAd?.dispose();
    rewardedPremiumAd?.dispose();
    interstitialAd?.dispose();
    appOpenAd?.dispose();
  }
}

// =============================================================================
// الشاشة الرئيسية: تحتوي على تبويبات (المؤقّت / الإحصائيات / المتجر)
// =============================================================================
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  int _tabIndex = 0;

  @override
  void initState() {
    super.initState();
    AdManager.instance.addListener(_refresh);
    AppState.instance.addListener(_refresh);
    WidgetsBinding.instance.addObserver(this);
    // إعلان فتح التطبيق عند أول تشغيل (بعد أن يستقر أول إطار للواجهة)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AdManager.instance.showAppOpenAdIfAvailable();
    });
  }

  @override
  void dispose() {
    AdManager.instance.removeListener(_refresh);
    AppState.instance.removeListener(_refresh);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // إظهار إعلان فتح التطبيق عند العودة من الخلفية (نمط شائع لرفع الأرباح)
    if (state == AppLifecycleState.resumed) {
      AdManager.instance.showAppOpenAdIfAvailable();
    }
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Color get _themeColor => themeOptions
      .firstWhere((t) => t.id == AppState.instance.selectedThemeId)
      .color;

  String _formatRemaining(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    return '$h س $m د';
  }

  @override
  Widget build(BuildContext context) {
    final state = AppState.instance;
    final pages = [
      const TimerScreen(),
      const StatsScreen(),
      const ShopScreen(),
    ];
    return Scaffold(
      appBar: AppBar(
        title: const Text('فوكس بومو'),
        centerTitle: true,
        backgroundColor: _themeColor,
        actions: [
          if (state.isPremiumActive)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Chip(
                avatar: const Icon(Icons.workspace_premium,
                    color: Colors.amber, size: 18),
                label: Text('مميز ${_formatRemaining(state.premiumRemaining)}',
                    style: const TextStyle(fontSize: 12)),
                visualDensity: VisualDensity.compact,
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                const Icon(Icons.monetization_on, color: Colors.amber),
                const SizedBox(width: 4),
                Text('${state.coins}',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(child: pages[_tabIndex]),
          // ميزة "بلا إعلانات" أثناء الوضع المميز: نخفي البانر
          if (!state.isPremiumActive &&
              AdManager.instance.isBannerLoaded &&
              AdManager.instance.bannerAd != null)
            SizedBox(
              width: AdManager.instance.bannerAd!.size.width.toDouble(),
              height: AdManager.instance.bannerAd!.size.height.toDouble(),
              child: AdWidget(ad: AdManager.instance.bannerAd!),
            ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: (i) => setState(() => _tabIndex = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.timer), label: 'المؤقّت'),
          NavigationDestination(
              icon: Icon(Icons.bar_chart), label: 'الإحصائيات'),
          NavigationDestination(icon: Icon(Icons.storefront), label: 'المتجر'),
        ],
      ),
    );
  }
}

// =============================================================================
// شاشة المؤقّت (Pomodoro Engine)
// =============================================================================
enum PomodoroPhase { work, shortBreak, longBreak }

class TimerScreen extends StatefulWidget {
  const TimerScreen({super.key});
  @override
  State<TimerScreen> createState() => _TimerScreenState();
}

class _TimerScreenState extends State<TimerScreen> {
  PomodoroPhase _phase = PomodoroPhase.work;
  int _completedInCycle = 0;
  late int _remainingSeconds = AppState.instance.effectiveWorkMinutes * 60;
  bool _isRunning = false;
  Timer? _ticker;
  String _currentQuote = randomMotivationalQuote();
  String? _taskLabel;
  final TextEditingController _labelController = TextEditingController();

  int get _phaseTotalSeconds {
    switch (_phase) {
      case PomodoroPhase.work:
        return AppState.instance.effectiveWorkMinutes * 60;
      case PomodoroPhase.shortBreak:
        return shortBreakMinutesDefault * 60;
      case PomodoroPhase.longBreak:
        return longBreakMinutesDefault * 60;
    }
  }

  String get _phaseLabel {
    switch (_phase) {
      case PomodoroPhase.work:
        return 'وقت التركيز 🎯';
      case PomodoroPhase.shortBreak:
        return 'استراحة قصيرة ☕';
      case PomodoroPhase.longBreak:
        return 'استراحة طويلة 🌿';
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _labelController.dispose();
    super.dispose();
  }

  void _toggleTimer() {
    if (_isRunning) {
      _pause();
    } else {
      _start();
    }
  }

  void _start() {
    setState(() => _isRunning = true);
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_remainingSeconds <= 1) {
        _onPhaseComplete();
      } else {
        setState(() => _remainingSeconds -= 1);
      }
    });
  }

  void _pause() {
    _ticker?.cancel();
    setState(() => _isRunning = false);
  }

  void _resetPhase() {
    _ticker?.cancel();
    setState(() {
      _isRunning = false;
      _remainingSeconds = _phaseTotalSeconds;
    });
  }

  Future<void> _onPhaseComplete() async {
    _ticker?.cancel();
    HapticFeedback.mediumImpact();

    if (_phase == PomodoroPhase.work) {
      await AppState.instance
          .completeFocusSession(AppState.instance.effectiveWorkMinutes,
              label: _taskLabel);
      _completedInCycle += 1;
      final nextPhase = _completedInCycle % sessionsBeforeLongBreak == 0
          ? PomodoroPhase.longBreak
          : PomodoroPhase.shortBreak;
      setState(() {
        _phase = nextPhase;
        _remainingSeconds = _phaseTotalSeconds;
        _isRunning = false;
        _currentQuote = randomMotivationalQuote();
      });
      // إعلان بيني كل عدد محدد من الجلسات (يظهر بعد إغلاق شاشة الإنجاز)
      if (mounted) await _showSessionCompleteSheet();
      AdManager.instance.maybeShowInterstitialAfterSession();
    } else {
      setState(() {
        _phase = PomodoroPhase.work;
        _remainingSeconds = _phaseTotalSeconds;
        _isRunning = false;
        _currentQuote = randomMotivationalQuote();
      });
    }
  }

  Future<void> _showSessionCompleteSheet() {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🎉 أحسنت! أكملت جلسة تركيز',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
                '+$coinsPerSession عملة  •  سلسلة ${AppState.instance.streakDays} يوم',
                style: const TextStyle(fontSize: 15, color: Colors.grey)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.indigo.withOpacity(0.06),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _currentQuote,
                textAlign: TextAlign.center,
                style: const TextStyle(fontStyle: FontStyle.italic),
              ),
            ),
            const SizedBox(height: 16),
            if (!AppState.instance.isPremiumActive)
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  _watchAdForPremium(context);
                },
                icon: const Icon(Icons.workspace_premium),
                label: const Text('افتح الوضع المميز 24 ساعة بمشاهدة إعلان'),
              ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('متابعة'),
            ),
          ],
        ),
      ),
    );
  }

  void _watchAdForPremium(BuildContext context) {
    final ad = AdManager.instance.rewardedPremiumAd;
    if (ad == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الإعلان لسه بيتحمّل، حاول بعد لحظة')),
      );
      return;
    }
    AdManager.instance.rewardedPremiumAd = null;
    ad.show(
      onUserEarnedReward: (ad, reward) async {
        await AppState.instance.unlockPremiumFor24h();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('تم تفعيل الوضع المميز لمدة 24 ساعة! 👑')),
          );
        }
      },
    );
  }

  void _editTaskLabel() {
    _labelController.text = _taskLabel ?? '';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('على أي مهمة ستركّز؟'),
        content: TextField(
          controller: _labelController,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'مثال: كتابة تقرير'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () {
              setState(() {
                _taskLabel = _labelController.text.trim().isEmpty
                    ? null
                    : _labelController.text.trim();
              });
              Navigator.pop(ctx);
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  void _pickCustomDuration() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('اختر مدة التركيز (ميزة مميزة 👑)',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              children: premiumWorkMinuteOptions
                  .map((m) => ChoiceChip(
                        label: Text('$m د'),
                        selected: AppState.instance.effectiveWorkMinutes == m,
                        onSelected: (_) {
                          AppState.instance.setCustomWorkMinutes(m);
                          if (!_isRunning) {
                            setState(() {
                              _remainingSeconds = _phaseTotalSeconds;
                            });
                          }
                          Navigator.pop(ctx);
                        },
                      ))
                  .toList(),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  String _formatTime(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final state = AppState.instance;
    final themeColor =
        themeOptions.firstWhere((t) => t.id == state.selectedThemeId).color;
    final progress = 1 - (_remainingSeconds / _phaseTotalSeconds);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 4),
          // رسالة تحفيزية عشوائية
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: themeColor.withOpacity(0.08),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _currentQuote,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13),
            ),
          ),
          const SizedBox(height: 16),
          Text(_phaseLabel, style: const TextStyle(fontSize: 20)),
          const SizedBox(height: 8),
          // وسم المهمة الحالية
          GestureDetector(
            onTap: _editTaskLabel,
            child: Chip(
              avatar: const Icon(Icons.edit_note, size: 18),
              label: Text(_taskLabel ?? 'اضغط لإضافة وسم للمهمة (اختياري)'),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: 240,
            height: 240,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 240,
                  height: 240,
                  child: CircularProgressIndicator(
                    value: progress.clamp(0, 1),
                    strokeWidth: 10,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation(themeColor),
                  ),
                ),
                Text(_formatTime(_remainingSeconds),
                    style: const TextStyle(
                        fontSize: 44, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (_phase == PomodoroPhase.work)
            TextButton.icon(
              onPressed: state.isPremiumActive ? _pickCustomDuration : null,
              icon: const Icon(Icons.workspace_premium, size: 18),
              label: Text(state.isPremiumActive
                  ? 'مدة مخصّصة: ${state.effectiveWorkMinutes} د'
                  : 'المدة المخصّصة متاحة في الوضع المميز'),
            ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton(
                onPressed: _resetPhase,
                child: const Icon(Icons.refresh),
              ),
              const SizedBox(width: 20),
              FilledButton(
                onPressed: _toggleTimer,
                style: FilledButton.styleFrom(
                  backgroundColor: themeColor,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 36, vertical: 20),
                ),
                child: Icon(_isRunning ? Icons.pause : Icons.play_arrow,
                    size: 28),
              ),
            ],
          ),
          const SizedBox(height: 28),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              _StatChip(
                  icon: Icons.local_fire_department,
                  label: 'سلسلة ${state.streakDays} يوم'),
              _StatChip(
                  icon: Icons.check_circle,
                  label: 'اليوم: ${state.todaysSessions} جلسات'),
              _StatChip(
                  icon: Icons.military_tech, label: 'المستوى ${state.level}'),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _StatChip({required this.icon, required this.label});
  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
    );
  }
}

// =============================================================================
// شاشة الإحصائيات + سجل الجلسات (مع إعلان Native مدمج داخل القائمة)
// + أوسمة الإنجاز + رسم بياني أسبوعي بسيط
// =============================================================================
class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppState.instance;
    final history = state.history;
    final weekMinutes = state.last7DaysMinutes;
    final maxWeekMinutes =
        weekMinutes.fold<int>(1, (m, v) => v > m ? v : m);
    final weekDayLabels = ['ح', 'ن', 'ث', 'ر', 'خ', 'ج', 'س'];
    final todayWeekday = DateTime.now().weekday % 7; // 0..6 حيث 0 = الأحد

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: _SummaryCard(
                    icon: Icons.today,
                    title: 'دقائق اليوم',
                    value: '${state.todaysMinutes}',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _SummaryCard(
                    icon: Icons.emoji_events,
                    title: 'إجمالي الجلسات',
                    value: '${state.totalSessions}',
                  ),
                ),
              ],
            ),
          ),
        ),
        // رسم بياني بسيط لآخر 7 أيام
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverToBoxAdapter(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('آخر 7 أيام',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 90,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: List.generate(7, (i) {
                          final minutes = weekMinutes[i];
                          final barHeight =
                              60 * (minutes / maxWeekMinutes).clamp(0.05, 1.0);
                          final dayIndex = (todayWeekday - 6 + i + 7) % 7;
                          return Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text('$minutes',
                                  style: const TextStyle(fontSize: 10)),
                              const SizedBox(height: 4),
                              Container(
                                width: 18,
                                height: barHeight.toDouble(),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primary,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(weekDayLabels[dayIndex],
                                  style: const TextStyle(fontSize: 11)),
                            ],
                          );
                        }),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        // أوسمة الإنجاز
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
          sliver: SliverToBoxAdapter(
            child: Text('🏅 أوسمة الإنجاز',
                style: Theme.of(context).textTheme.titleMedium),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverToBoxAdapter(
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: achievements.map((a) {
                final unlocked = a.isUnlocked(state);
                return Container(
                  width: 100,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: unlocked
                        ? Colors.amber.withOpacity(0.15)
                        : Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: unlocked ? Colors.amber : Colors.grey.shade300,
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(a.icon,
                          color: unlocked ? Colors.amber.shade800 : Colors.grey,
                          size: 26),
                      const SizedBox(height: 6),
                      Text(a.title,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: unlocked ? null : Colors.grey)),
                      Text(a.description,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 9,
                              color: unlocked
                                  ? Colors.grey.shade700
                                  : Colors.grey.shade400)),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverToBoxAdapter(
            child: Text('سجل الجلسات',
                style: Theme.of(context).textTheme.titleMedium),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 8)),
        if (history.isEmpty)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(32),
              child:
                  Center(child: Text('لا توجد جلسات بعد، ابدأ أول تركيز لك!')),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  // كل nativeAdEveryNItems عنصر، نُدرج إعلان Native كعنصر إضافي
                  final adSlotsBefore = index ~/ (nativeAdEveryNItems + 1);
                  final isAdSlot =
                      (index + 1) % (nativeAdEveryNItems + 1) == 0;
                  if (isAdSlot) {
                    if (AdManager.instance.isNativeLoaded &&
                        AdManager.instance.nativeAd != null) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: SizedBox(
                          height: 100,
                          child: AdWidget(ad: AdManager.instance.nativeAd!),
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  }
                  final realIndex = index - adSlotsBefore;
                  if (realIndex >= history.length) return null;
                  final session = history[realIndex];
                  return Card(
                    child: ListTile(
                      leading: const Icon(Icons.check_circle_outline),
                      title: Text('${session.minutes} دقيقة تركيز' +
                          (session.label != null ? ' — ${session.label}' : '')),
                      subtitle: Text(_formatDate(session.date)),
                    ),
                  );
                },
                childCount: history.length +
                    (history.length ~/ nativeAdEveryNItems),
              ),
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }

  String _formatDate(DateTime d) {
    return '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}  ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }
}

class _SummaryCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  const _SummaryCard(
      {required this.icon, required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, size: 26),
            const SizedBox(height: 6),
            Text(value,
                style:
                    const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            Text(title, style: const TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// شاشة المتجر: ثيمات ألوان + مضاعفة عملات اليوم + فتح الوضع المميز 24 ساعة
// =============================================================================
class ShopScreen extends StatelessWidget {
  const ShopScreen({super.key});

  void _watchAdToDoubleCoins(BuildContext context) {
    final state = AppState.instance;
    if (state.rewardedUsedToday) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('استخدمت هذه الميزة اليوم، عاود غداً 🙏')),
      );
      return;
    }
    final ad = AdManager.instance.rewardedAd;
    if (ad == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الإعلان لسه بيتحمّل، حاول بعد لحظة')),
      );
      return;
    }
    AdManager.instance.rewardedAd = null;
    ad.show(
      onUserEarnedReward: (ad, reward) async {
        await state.doubleTodaysCoinsViaAd();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تمت مضاعفة عملات اليوم! 🎉')),
          );
        }
      },
    );
  }

  void _watchAdForPremium(BuildContext context) {
    final ad = AdManager.instance.rewardedPremiumAd;
    if (ad == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الإعلان لسه بيتحمّل، حاول بعد لحظة')),
      );
      return;
    }
    AdManager.instance.rewardedPremiumAd = null;
    ad.show(
      onUserEarnedReward: (ad, reward) async {
        await AppState.instance.unlockPremiumFor24h();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('تم تفعيل الوضع المميز لمدة 24 ساعة! 👑')),
          );
        }
      },
    );
  }

  void _onBuyTheme(BuildContext context, ThemeOption option) {
    final state = AppState.instance;
    if (state.canUseTheme(option)) {
      state.selectTheme(option.id);
      return;
    }
    final ok = state.buyTheme(option);
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('عملاتك غير كافية 😅')),
      );
    }
  }

  String _formatRemaining(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    return '$h ساعة و $m دقيقة';
  }

  @override
  Widget build(BuildContext context) {
    final state = AppState.instance;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          color: Colors.amber.shade50,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.monetization_on,
                        color: Colors.amber, size: 32),
                    const SizedBox(width: 8),
                    Text('${state.coins}',
                        style: const TextStyle(
                            fontSize: 26, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () => _watchAdToDoubleCoins(context),
                  icon: const Icon(Icons.play_circle_fill),
                  label: Text(state.rewardedUsedToday
                      ? 'تمت المضاعفة اليوم ✅'
                      : 'شاهد إعلان لمضاعفة عملات اليوم'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        // بطاقة الوضع المميز 24 ساعة عبر إعلان مكافأة
        Card(
          color: Colors.indigo.shade50,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.workspace_premium, color: Colors.indigo),
                    SizedBox(width: 8),
                    Text('الوضع المميز',
                        style: TextStyle(
                            fontSize: 17, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  '👑 بدون إعلانات بانر/مدمجة\n👑 مدة تركيز مخصّصة بدل 25 دقيقة الثابتة\n👑 ثيمتان حصريتان (ذهبي وزمردي)',
                  style: TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 12),
                if (state.isPremiumActive)
                  Text(
                    'مفعّل حالياً — متبقٍ ${_formatRemaining(state.premiumRemaining)}',
                    style: const TextStyle(
                        color: Colors.green, fontWeight: FontWeight.bold),
                  ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: () => _watchAdForPremium(context),
                  icon: const Icon(Icons.play_circle_fill),
                  label: Text(state.isPremiumActive
                      ? 'شاهد إعلاناً آخر لتمديد 24 ساعة إضافية'
                      : 'شاهد إعلان لفتح الوضع المميز 24 ساعة'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        const Text('🎨 ثيمات الألوان',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ...themeOptions.map((t) {
          final owned = state.ownedThemeIds.contains(t.id);
          final usable = state.canUseTheme(t);
          final selected = state.selectedThemeId == t.id;
          String subtitle;
          if (owned) {
            subtitle = selected ? 'مُفعّل حالياً' : 'مملوك';
          } else if (t.premiumOnly && state.isPremiumActive) {
            subtitle = 'متاح الآن ضمن الوضع المميز';
          } else if (t.premiumOnly) {
            subtitle = 'حصري 👑 — فعّل الوضع المميز أو اشترِ بـ ${t.cost} 🪙';
          } else {
            subtitle = 'السعر: ${t.cost} 🪙';
          }
          return Card(
            child: ListTile(
              leading: CircleAvatar(backgroundColor: t.color),
              title: Text(t.name),
              subtitle: Text(subtitle),
              trailing: ElevatedButton(
                onPressed: selected ? null : () => _onBuyTheme(context, t),
                child: Text(
                    selected ? 'مفعّل' : (usable ? 'تفعيل' : 'شراء')),
              ),
            ),
          );
        }),
      ],
    );
  }
}


