// main.dart
// لعبة بسيطة بلغة Flutter/Dart مع دمج Google Mobile Ads
// ==========================================================
//
// الميزات:
// - نقاط تزيد بالضغط على زر
// - إعلان بيني (Interstitial) يظهر بعد كل مرحلة
// - إعلان مكافأة (Rewarded) يعطي نقاط إضافية
// - بانر ثابت أسفل الشاشة يتحدث كل 40 ثانية
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
const int rewardBonusPoints = 10; // النقاط الإضافية من إعلان المكافأة
const int bannerRefreshSeconds = 40; // كل كم ثانية يتحدث البانر

// معرفات اختبار AdMod الرسمية (استبدلها بمعرفاتك الحقيقية عند النشر)
const String bannerAdUnitId = 'ca-app-pub-3940256099942544/6300978111';
const String interstitialAdUnitId = 'ca-app-pub-3940256099942544/1033173712';
const String rewardedAdUnitId = 'ca-app-pub-3940256099942544/5224354917';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await MobileAds.instance.initialize();
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

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  int score = 0;
  int level = 1;
  String statusText = 'اضغط على الزر لجمع النقاط!';

  BannerAd? _bannerAd;
  bool _isBannerLoaded = false;

  InterstitialAd? _interstitialAd;
  RewardedAd? _rewardedAd;

  Timer? _bannerRefreshTimer;

  @override
  void initState() {
    super.initState();
    _loadBannerAd();
    _loadInterstitialAd();
    _loadRewardedAd();

    // إعادة تحميل/تحديث البانر كل 40 ثانية
    _bannerRefreshTimer = Timer.periodic(
      const Duration(seconds: bannerRefreshSeconds),
      (timer) => _loadBannerAd(),
    );
  }

  @override
  void dispose() {
    _bannerRefreshTimer?.cancel();
    _bannerAd?.dispose();
    _interstitialAd?.dispose();
    _rewardedAd?.dispose();
    super.dispose();
  }

  // -------------------------------------------------------------------
  // تحميل الإعلانات
  // -------------------------------------------------------------------
  void _loadBannerAd() {
    // تخلص من البانر القديم قبل تحميل واحد جديد
    _bannerAd?.dispose();
    setState(() => _isBannerLoaded = false);

    final banner = BannerAd(
      adUnitId: bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          setState(() {
            _bannerAd = ad as BannerAd;
            _isBannerLoaded = true;
          });
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          debugPrint('فشل تحميل البانر: $error');
        },
      ),
    );
    banner.load();
  }

  void _loadInterstitialAd() {
    InterstitialAd.load(
      adUnitId: interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _interstitialAd!.fullScreenContentCallback =
              FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _loadInterstitialAd(); // تجهيز إعلان جديد للمرحلة القادمة
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();
              _loadInterstitialAd();
            },
          );
        },
        onAdFailedToLoad: (error) {
          debugPrint('فشل تحميل الإعلان البيني: $error');
        },
      ),
    );
  }

  void _loadRewardedAd() {
    RewardedAd.load(
      adUnitId: rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _loadRewardedAd(); // تجهيز إعلان جديد للمرة القادمة
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();
              _loadRewardedAd();
            },
          );
        },
        onAdFailedToLoad: (error) {
          debugPrint('فشل تحميل إعلان المكافأة: $error');
        },
      ),
    );
  }

  // -------------------------------------------------------------------
  // منطق اللعبة
  // -------------------------------------------------------------------
  void _onTap() {
    setState(() {
      score += 1;
    });

    if (score % pointsPerLevel == 0) {
      _completeLevel();
    }
  }

  void _completeLevel() {
    setState(() {
      level += 1;
      statusText = 'أحسنت! مرحلة جديدة 🎉';
    });

    _showLevelDialog();

    // عرض الإعلان البيني بين المراحل إن كان جاهزًا
    if (_interstitialAd != null) {
      _interstitialAd!.show();
      _interstitialAd = null;
    }
  }

  void _showLevelDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        title: const Text('مرحلة جديدة!'),
        content: Text('وصلت إلى المرحلة $level\nنقاطك الحالية: $score'),
      ),
    );
    // إغلاق النافذة تلقائيًا بعد ثانيتين
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
    });
  }

  void _onWatchRewardedAd() {
    if (_rewardedAd == null) {
      setState(() => statusText = 'الإعلان لسه بيتحمّل، حاول تاني بعد لحظة');
      return;
    }

    _rewardedAd!.show(
      onUserEarnedReward: (ad, reward) {
        // تُمنح النقاط فقط عند نجاح المشاهدة الكاملة
        setState(() {
          score += rewardBonusPoints;
          statusText = 'حصلت على $rewardBonusPoints نقطة إضافية!';
        });
      },
    );
    _rewardedAd = null;
  }

  // -------------------------------------------------------------------
  // الواجهة
  // -------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('لعبة النقاط البسيطة'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('المرحلة: $level',
                        style: const TextStyle(fontSize: 22)),
                    const SizedBox(height: 12),
                    Text('نقاطك: $score',
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
                        padding: const EdgeInsets.symmetric(
                            horizontal: 40, vertical: 18),
                        textStyle: const TextStyle(fontSize: 20),
                      ),
                      child: const Text('اضغط هنا (+1 نقطة)'),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton(
                      onPressed: _onWatchRewardedAd,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 30, vertical: 14),
                        textStyle: const TextStyle(fontSize: 16),
                      ),
                      child: Text('شاهد إعلان واحصل على +$rewardBonusPoints نقطة'),
                    ),
                  ],
                ),
              ),
            ),
            // البانر الثابت أسفل الشاشة
            if (_isBannerLoaded && _bannerAd != null)
              SizedBox(
                width: _bannerAd!.size.width.toDouble(),
                height: _bannerAd!.size.height.toDouble(),
                child: AdWidget(ad: _bannerAd!),
              ),
          ],
        ),
      ),
    );
  }
}



