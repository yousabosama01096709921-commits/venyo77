// main.dart
// لعبة بسيطة بلغة Flutter/Dart مع دمج Google Mobile Ads
// ==========================================================
//
// التحديثات في هذه النسخة:
// - شاشة "متجر" منفصلة تماماً (In-App Shop): ألوان، خلفيات، وفرصة إضافية
//   تُشترى بعملات ذهبية تُكسب عبر مشاهدة إعلان مكافأة داخل المتجر فقط.
// - تحميل مسبق (Preload) لكل أنواع الإعلانات (بانر + إعلان مكافأة المتجر
//   + إعلان مكافأة المرحلة) فور فتح التطبيق، وقبل احتياج المستخدم لها.
//   بمجرد مشاهدة أي إعلان وإغلاقه، يُطلب إعلان جديد فوراً في الخلفية
//   ليكون جاهزاً للمرة القادمة (يرفع نسبة الـ Fill Rate ويمنع ضياع الأرباح).
// - تم إلغاء الإعلان البيني (Interstitial) المفاجئ نهائياً. بدلاً منه:
//     1) عند وصول اللاعب لنهاية المرحلة تظهر نافذة تخيير:
//        "هل تريد مضاعفة نقاطك والانتقال للمرحلة التالية؟"
//     2) إذا وافق، يُعرض عليه إعلان مكافأة مخصص لهذه اللحظة.
//     3) بعد إتمام مشاهدة الإعلان بنجاح، ينتقل تلقائياً للمرحلة التالية
//        مع مضاعفة نقاط تلك المرحلة.
//     - يمكن للاعب أيضاً استخدام "فرصة إضافية" (مشتراة من المتجر) للحصول
//       على نفس المضاعفة دون مشاهدة إعلان.
//
// خطوات التشغيل:
// 1) أنشئ مشروع Flutter جديد:
//      flutter create simple_game
// 2) استبدل ملف pubspec.yaml بالملف المرفق، ثم:
//      flutter pub get
// 3) استبدل محتوى lib/main.dart بمحتوى هذا الملف.
// 4) أضف معرف AdMob الخاص بتطبيقك في:
//      android/app/src/main/AndroidManifest.xml
//    داخل <application> أضف:
//      <meta-data
//          android:name="com.google.android.gms.ads.APPLICATION_ID"
//          android:value="ca-app-pub-3940256099942544~3347511713"/>
//    (المعرف هنا معرف اختبار رسمي من جوجل - استبدله بمعرفك الحقيقي عند النشر)
// 5) شغّل:
//      flutter run
//
// ملاحظة: معرفات الإعلانات أدناه هي معرفات اختبار (Test Ads) الرسمية
// من جوجل، آمنة للتجربة ولا تدر أرباح حقيقية. استبدلها بمعرفاتك عند النشر.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

// ---------------------------------------------------------------------------
// إعدادات عامة
// ---------------------------------------------------------------------------
const int pointsPerLevel = 20; // كل كم نقطة تنتهي المرحلة
const int rewardCoinsAmount = 50; // العملات الممنوحة من إعلان مكافأة المتجر
const int pointsRewardAmount = 15; // النقاط الممنوحة من زر "شاهد إعلان" في شاشة اللعب
const int extraLifeCost = 40; // سعر "الفرصة الإضافية" بالعملات
const int bannerRefreshSeconds = 40; // كل كم ثانية يتحدث البانر

// معرفات اختبار AdMob الرسمية (استبدلها بمعرفاتك الحقيقية عند النشر)
const String bannerAdUnitId = 'ca-app-pub-9360667271539236/1088346181';
const String shopRewardedAdUnitId = 'ca-app-pub-9360667271539236/9249653649';
const String levelRewardedAdUnitId = 'ca-app-pub-9360667271539236/2788909857';
const String pointsRewardedAdUnitId = 'ca-app-pub-9360667271539236/9249653649';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await MobileAds.instance.initialize();

  // تحميل كل الإعلانات مسبقاً فور فتح التطبيق، قبل أن يحتاجها المستخدم بوقت طويل
  AdManager.instance.preloadAll();

  runApp(const SimpleGameApp());
}

class SimpleGameApp extends StatelessWidget {
  const SimpleGameApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'لعبة النقاط البسيطة',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      home: const GameScreen(),
    );
  }
}

// =============================================================================
// نموذج بيانات المتجر
// =============================================================================
class ShopColorOption {
  final String id;
  final String name;
  final Color color;
  final int cost;

  const ShopColorOption({
    required this.id,
    required this.name,
    required this.color,
    required this.cost,
  });
}

class ShopBackgroundOption {
  final String id;
  final String name;
  final List<Color> gradient;
  final int cost;

  const ShopBackgroundOption({
    required this.id,
    required this.name,
    required this.gradient,
    required this.cost,
  });
}

const List<ShopColorOption> shopColors = [
  ShopColorOption(id: 'blue', name: 'أزرق كلاسيكي', color: Colors.blue, cost: 0),
  ShopColorOption(id: 'purple', name: 'بنفسجي ملكي', color: Colors.deepPurple, cost: 30),
  ShopColorOption(id: 'teal', name: 'أخضر زمردي', color: Colors.teal, cost: 30),
  ShopColorOption(id: 'orange', name: 'برتقالي ناري', color: Colors.deepOrange, cost: 50),
  ShopColorOption(id: 'pink', name: 'وردي فاتن', color: Colors.pinkAccent, cost: 50),
];

const List<ShopBackgroundOption> shopBackgrounds = [
  ShopBackgroundOption(
    id: 'default',
    name: 'خلفية افتراضية',
    gradient: [Colors.white, Color(0xFFF2F2F2)],
    cost: 0,
  ),
  ShopBackgroundOption(
    id: 'sunset',
    name: 'غروب',
    gradient: [Color(0xFFFF9A8B), Color(0xFFFF6A88)],
    cost: 40,
  ),
  ShopBackgroundOption(
    id: 'ocean',
    name: 'محيط',
    gradient: [Color(0xFF2E3192), Color(0xFF1BFFFF)],
    cost: 40,
  ),
  ShopBackgroundOption(
    id: 'night',
    name: 'ليل نجمي',
    gradient: [Color(0xFF0F2027), Color(0xFF2C5364)],
    cost: 60,
  ),
];

// =============================================================================
// حالة اللعبة العامة (نقاط، مستوى، عملات، مقتنيات المتجر)
// =============================================================================
class AppState extends ChangeNotifier {
  int score = 0;
  int level = 1;
  int coins = 0;
  int extraLives = 0;

  String selectedColorId = 'blue';
  final Set<String> ownedColorIds = {'blue'};

  String selectedBackgroundId = 'default';
  final Set<String> ownedBackgroundIds = {'default'};

  void addScore(int amount) {
    score += amount;
    notifyListeners();
  }

  void addCoins(int amount) {
    coins += amount;
    notifyListeners();
  }

  bool buyColor(ShopColorOption option) {
    if (ownedColorIds.contains(option.id)) return false;
    if (coins < option.cost) return false;
    coins -= option.cost;
    ownedColorIds.add(option.id);
    notifyListeners();
    return true;
  }

  void selectColor(String id) {
    selectedColorId = id;
    notifyListeners();
  }

  bool buyBackground(ShopBackgroundOption option) {
    if (ownedBackgroundIds.contains(option.id)) return false;
    if (coins < option.cost) return false;
    coins -= option.cost;
    ownedBackgroundIds.add(option.id);
    notifyListeners();
    return true;
  }

  void selectBackground(String id) {
    selectedBackgroundId = id;
    notifyListeners();
  }

  bool buyExtraLife(int cost) {
    if (coins < cost) return false;
    coins -= cost;
    extraLives += 1;
    notifyListeners();
    return true;
  }

  // ينقل اللاعب للمرحلة التالية. عند "doubled" يتم مضاعفة نقاط هذه المرحلة.
  void advanceLevel({required bool doubled}) {
    if (doubled) {
      score += pointsPerLevel;
    }
    level += 1;
    notifyListeners();
  }

  bool useExtraLifeForDouble() {
    if (extraLives <= 0) return false;
    extraLives -= 1;
    advanceLevel(doubled: true);
    return true;
  }
}

final AppState appState = AppState();

// =============================================================================
// مدير الإعلانات المركزي: يحمّل كل الإعلانات مسبقاً ويعيد تحميلها فوراً
// بعد كل استخدام لضمان أعلى نسبة تعبئة (Fill Rate) ممكنة.
// =============================================================================
class AdManager extends ChangeNotifier {
  AdManager._internal();
  static final AdManager instance = AdManager._internal();

  BannerAd? bannerAd;
  bool isBannerLoaded = false;

  RewardedAd? shopRewardedAd;
  RewardedInterstitialAd? levelRewardedAd;
  RewardedAd? pointsRewardedAd;

  Timer? _bannerRefreshTimer;

  void preloadAll() {
    loadBanner();
    loadShopRewarded();
    loadLevelRewarded();
    loadPointsRewarded();

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

  void loadShopRewarded() {
    RewardedAd.load(
      adUnitId: shopRewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          shopRewardedAd = ad;
          shopRewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              shopRewardedAd = null;
              loadShopRewarded(); // طلب إعلان جديد فوراً للمرة القادمة
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();
              shopRewardedAd = null;
              loadShopRewarded();
            },
          );
          notifyListeners();
        },
        onAdFailedToLoad: (error) {
          debugPrint('فشل تحميل إعلان المتجر: $error');
          shopRewardedAd = null;
        },
      ),
    );
  }

  // إعلان تضعيف نقاط المرحلة: "Rewarded Interstitial" — إعلان بيني
  // (بيظهر بشكل أقرب للإعلان البيني) لكنه في النهاية يمنح مكافأة
  // فقط بعد إكمال المشاهدة، تماماً مثل إعلان المكافأة العادي.
  void loadLevelRewarded() {
    RewardedInterstitialAd.load(
      adUnitId: levelRewardedAdUnitId,
      request: const AdRequest(),
      rewardedInterstitialAdLoadCallback: RewardedInterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          levelRewardedAd = ad;
          levelRewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              levelRewardedAd = null;
              loadLevelRewarded(); // طلب إعلان جديد فوراً للمرحلة القادمة
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();
              levelRewardedAd = null;
              loadLevelRewarded();
            },
          );
          notifyListeners();
        },
        onAdFailedToLoad: (error) {
          debugPrint('فشل تحميل إعلان المرحلة: $error');
          levelRewardedAd = null;
        },
      ),
    );
  }

  void loadPointsRewarded() {
    RewardedAd.load(
      adUnitId: pointsRewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          pointsRewardedAd = ad;
          pointsRewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              pointsRewardedAd = null;
              loadPointsRewarded(); // طلب إعلان جديد فوراً للمرة القادمة
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();
              pointsRewardedAd = null;
              loadPointsRewarded();
            },
          );
          notifyListeners();
        },
        onAdFailedToLoad: (error) {
          debugPrint('فشل تحميل إعلان النقاط: $error');
          pointsRewardedAd = null;
        },
      ),
    );
  }

  void disposeAll() {
    _bannerRefreshTimer?.cancel();
    bannerAd?.dispose();
    shopRewardedAd?.dispose();
    levelRewardedAd?.dispose();
    pointsRewardedAd?.dispose();
  }
}

// =============================================================================
// شاشة اللعب الرئيسية
// =============================================================================
class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  String statusText = 'اضغط على الزر لجمع النقاط!';
  bool _levelUpDialogOpen = false;

  @override
  void initState() {
    super.initState();
    AdManager.instance.addListener(_onAdManagerUpdate);
  }

  @override
  void dispose() {
    AdManager.instance.removeListener(_onAdManagerUpdate);
    super.dispose();
  }

  void _onAdManagerUpdate() {
    if (mounted) setState(() {});
  }

  // -------------------------------------------------------------------
  // منطق اللعبة
  // -------------------------------------------------------------------
  void _onTap() {
    _addPoints(1);
  }

  // يضيف نقاط ويتحقق مما إذا كانت الإضافة قد تخطّت عتبة مرحلة جديدة
  // (وليس فقط إذا كانت النتيجة مضاعفاً تماماً)، حتى تعمل بشكل صحيح
  // سواء كانت الإضافة نقطة واحدة من الضغط أو 15 نقطة من الإعلان.
  void _addPoints(int amount) {
    final oldScore = appState.score;
    appState.addScore(amount);
    final leveledUp =
        (appState.score ~/ pointsPerLevel) > (oldScore ~/ pointsPerLevel);
    if (leveledUp && !_levelUpDialogOpen) {
      _showLevelUpDialog();
    }
  }

  void _watchPointsAd() {
    final rewardedAd = AdManager.instance.pointsRewardedAd;
    if (rewardedAd == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الإعلان لسه بيتحمّل، حاول بعد لحظة 🙏')),
      );
      return;
    }

    AdManager.instance.pointsRewardedAd = null; // منع الاستخدام المزدوج قبل التحميل الجديد

    rewardedAd.show(
      onUserEarnedReward: (ad, reward) {
        _addPoints(pointsRewardAmount);
        setState(() =>
            statusText = 'حصلت على $pointsRewardAmount نقطة إضافية! 🎉');
      },
    );
  }

  Future<void> _showLevelUpDialog() async {
    _levelUpDialogOpen = true;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('🎉 مرحلة جديدة!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('هل تريد مضاعفة نقاطك والانتقال للمرحلة التالية؟'),
            if (appState.extraLives > 0) ...[
              const SizedBox(height: 10),
              Text(
                'لديك ${appState.extraLives} فرصة إضافية — يمكنك استخدامها للمضاعفة دون مشاهدة إعلان.',
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              ),
            ],
          ],
        ),
        actionsOverflowDirection: VerticalDirection.down,
        actions: [
          if (appState.extraLives > 0)
            TextButton(
              onPressed: () {
                appState.useExtraLifeForDouble();
                Navigator.pop(dialogContext);
                setState(() => statusText = 'استخدمت فرصة إضافية وضاعفت نقاطك! ⭐');
              },
              child: const Text('استخدم فرصة إضافية ⭐'),
            ),
          TextButton(
            onPressed: () {
              appState.advanceLevel(doubled: false);
              Navigator.pop(dialogContext);
              setState(() => statusText = 'وصلت لمرحلة جديدة، واصل! 🚀');
            },
            child: const Text('لا شكراً، تابع عادي'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _watchLevelAd();
            },
            child: const Text('شاهد الإعلان وضاعف نقاطك ✨'),
          ),
        ],
      ),
    );
    _levelUpDialogOpen = false;
  }

  void _watchLevelAd() {
    final rewardedAd = AdManager.instance.levelRewardedAd;
    if (rewardedAd == null) {
      // الإعلان لسه ما وصل، ننقل اللاعب بدون مضاعفة حتى لا يتوقف تقدمه
      appState.advanceLevel(doubled: false);
      setState(() => statusText = 'الإعلان لسه بيتحمّل، انتقلت للمرحلة بدون مضاعفة هالمرة.');
      return;
    }

    AdManager.instance.levelRewardedAd = null; // منع استخدامه مرتين قبل التحميل الجديد

    rewardedAd.show(
      onUserEarnedReward: (ad, reward) {
        appState.advanceLevel(doubled: true);
        setState(() => statusText = 'تمت مضاعفة نقاطك! 🎉 المرحلة ${appState.level}');
      },
    );
  }

  // -------------------------------------------------------------------
  // الواجهة
  // -------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: appState,
      builder: (context, _) {
        final currentColor =
            shopColors.firstWhere((c) => c.id == appState.selectedColorId).color;
        final currentBg = shopBackgrounds
            .firstWhere((b) => b.id == appState.selectedBackgroundId)
            .gradient;

        return Scaffold(
          appBar: AppBar(
            title: const Text('لعبة النقاط البسيطة'),
            centerTitle: true,
            backgroundColor: currentColor,
            actions: [
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.monetization_on, color: Colors.amber),
                      const SizedBox(width: 4),
                      Text(
                        '${appState.coins}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.storefront),
                tooltip: 'المتجر',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ShopScreen()),
                ),
              ),
            ],
          ),
          body: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: currentBg,
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('المرحلة: ${appState.level}',
                              style: const TextStyle(fontSize: 22)),
                          const SizedBox(height: 12),
                          Text('نقاطك: ${appState.score}',
                              style: const TextStyle(
                                  fontSize: 28, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 12),
                          Text(statusText,
                              style: const TextStyle(fontSize: 16),
                              textAlign: TextAlign.center),
                          const SizedBox(height: 40),
                          ElevatedButton(
                            onPressed: _onTap,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: currentColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 40, vertical: 18),
                              textStyle: const TextStyle(fontSize: 20),
                            ),
                            child: const Text('اضغط هنا (+1 نقطة)'),
                          ),
                          const SizedBox(height: 14),
                          ElevatedButton.icon(
                            onPressed: _watchPointsAd,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.amber.shade700,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 14),
                            ),
                            icon: const Icon(Icons.play_circle_fill),
                            label: Text(
                                'شاهد إعلان للحصول على $pointsRewardAmount نقطة'),
                          ),
                          const SizedBox(height: 20),
                          TextButton.icon(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const ShopScreen()),
                            ),
                            icon: const Icon(Icons.storefront),
                            label: const Text('زيارة المتجر'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // البانر الثابت أسفل الشاشة
                  if (AdManager.instance.isBannerLoaded &&
                      AdManager.instance.bannerAd != null)
                    SizedBox(
                      width: AdManager.instance.bannerAd!.size.width.toDouble(),
                      height: AdManager.instance.bannerAd!.size.height.toDouble(),
                      child: AdWidget(ad: AdManager.instance.bannerAd!),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// =============================================================================
// شاشة المتجر (In-App Shop) — منفصلة تماماً عن شاشة اللعب
// =============================================================================
class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  @override
  void initState() {
    super.initState();
    AdManager.instance.addListener(_onAdManagerUpdate);
  }

  @override
  void dispose() {
    AdManager.instance.removeListener(_onAdManagerUpdate);
    super.dispose();
  }

  void _onAdManagerUpdate() {
    if (mounted) setState(() {});
  }

  void _watchAdForCoins() {
    final rewardedAd = AdManager.instance.shopRewardedAd;
    if (rewardedAd == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الإعلان لسه بيتحمّل، حاول بعد لحظة 🙏')),
      );
      return;
    }

    AdManager.instance.shopRewardedAd = null; // منع الاستخدام المزدوج قبل التحميل الجديد

    rewardedAd.show(
      onUserEarnedReward: (ad, reward) {
        appState.addCoins(rewardCoinsAmount);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حصلت على $rewardCoinsAmount عملة ذهبية! 🎉')),
        );
      },
    );
  }

  void _onBuyColor(ShopColorOption option) {
    final owned = appState.ownedColorIds.contains(option.id);
    if (owned) {
      appState.selectColor(option.id);
      return;
    }
    final ok = appState.buyColor(option);
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('عملاتك غير كافية 😅')),
      );
    }
  }

  void _onBuyBackground(ShopBackgroundOption option) {
    final owned = appState.ownedBackgroundIds.contains(option.id);
    if (owned) {
      appState.selectBackground(option.id);
      return;
    }
    final ok = appState.buyBackground(option);
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('عملاتك غير كافية 😅')),
      );
    }
  }

  void _onBuyExtraLife() {
    final ok = appState.buyExtraLife(extraLifeCost);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'حصلت على فرصة إضافية! ⭐' : 'عملاتك غير كافية 😅'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: appState,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('🛒 المتجر'),
            centerTitle: true,
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // -------- رصيد العملات + إعلان المكافأة --------
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
                          Text(
                            '${appState.coins}',
                            style: const TextStyle(
                                fontSize: 26, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: _watchAdForCoins,
                        icon: const Icon(Icons.play_circle_fill),
                        label: Text('شاهد إعلان واحصل على $rewardCoinsAmount عملة ذهبية'),
                        style: ElevatedButton.styleFrom(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),
              const Text('🎨 الألوان', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ...shopColors.map(_buildColorTile),

              const SizedBox(height: 24),
              const Text('🖼️ الخلفيات', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ...shopBackgrounds.map(_buildBackgroundTile),

              const SizedBox(height: 24),
              const Text('❤️ مساعدات', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.favorite, color: Colors.red),
                  title: const Text('فرصة إضافية'),
                  subtitle: Text(
                    'لديك: ${appState.extraLives} — تُستخدم لمضاعفة نقاطك عند الترقية دون مشاهدة إعلان',
                  ),
                  trailing: ElevatedButton(
                    onPressed: _onBuyExtraLife,
                    child: Text('$extraLifeCost 🪙'),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildColorTile(ShopColorOption c) {
    final owned = appState.ownedColorIds.contains(c.id);
    final selected = appState.selectedColorId == c.id;
    return Card(
      child: ListTile(
        leading: CircleAvatar(backgroundColor: c.color),
        title: Text(c.name),
        subtitle: Text(owned
            ? (selected ? 'مُفعّل حالياً' : 'مملوك')
            : 'السعر: ${c.cost} 🪙'),
        trailing: ElevatedButton(
          onPressed: selected ? null : () => _onBuyColor(c),
          child: Text(owned ? (selected ? 'مفعّل' : 'تفعيل') : 'شراء'),
        ),
      ),
    );
  }

  Widget _buildBackgroundTile(ShopBackgroundOption b) {
    final owned = appState.ownedBackgroundIds.contains(b.id);
    final selected = appState.selectedBackgroundId == b.id;
    return Card(
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: b.gradient),
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        title: Text(b.name),
        subtitle: Text(owned
            ? (selected ? 'مُفعّلة حالياً' : 'مملوكة')
            : 'السعر: ${b.cost} 🪙'),
        trailing: ElevatedButton(
          onPressed: selected ? null : () => _onBuyBackground(b),
          child: Text(owned ? (selected ? 'مفعّلة' : 'تفعيل') : 'شراء'),
        ),
      ),
    );
  }
}
