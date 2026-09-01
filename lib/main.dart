// main.dart
// تطبيق "فوكس بومو" — مؤقّت بومودورو احترافي مع إحصائيات وتلعيب
// ============================================================
//
// الفكرة:
// - أداة إنتاجية حقيقية (Pomodoro Timer) تساعد المستخدم فعلاً على التركيز
//   وتتبّع وقته اليومي، مش مجرد واجهة لعرض إعلانات.
// - نظام تلعيب فوقها: عملات + مستويات + سلسلة أيام (Streak) + متجر ثيمات،
//   لكن كل مكافأة مربوطة بإنجاز حقيقي (إكمال جلسة تركيز فعلية).
// - إعلانات مدمجة بثلاث طرق غير مزعجة:
//     1) Banner ثابت أسفل الشاشة الرئيسية.
//     2) Native Ad مدمج داخل قائمة السجل/الإحصائيات (يبدو كعنصر من القائمة).
//     3) Rewarded Ad اختياري لمضاعفة عملات اليوم (مرة واحدة يومياً كحد أقصى
//        حتى لا يتحول لإلحاح على المستخدم).
// - تحميل مسبق لكل الإعلانات + إعادة تحميل تلقائية بعد كل استخدام لرفع
//   نسبة الـ Fill Rate.
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
// 5) استبدل معرفات الإعلانات أدناه بمعرفاتك الحقيقية قبل النشر.
//
// ملاحظة: المعرفات أدناه هي معرفات اختبار رسمية من جوجل — آمنة للتجربة فقط.

import 'dart:async';
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

// معرفات اختبار AdMob الرسمية — استبدلها بمعرفاتك الحقيقية عند النشر
const String bannerAdUnitId = 'ca-app-pub-3940256099942544/6300978111';
const String nativeAdUnitId = 'ca-app-pub-3940256099942544/2247696110';
const String rewardedAdUnitId = 'ca-app-pub-3940256099942544/5224354917';

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
  const ThemeOption(
      {required this.id,
      required this.name,
      required this.color,
      required this.cost});
}

const List<ThemeOption> themeOptions = [
  ThemeOption(id: 'indigo', name: 'نيلي هادئ', color: Colors.indigo, cost: 0),
  ThemeOption(id: 'teal', name: 'أخضر مركّز', color: Colors.teal, cost: themeCostLow),
  ThemeOption(id: 'deepOrange', name: 'برتقالي حيوي', color: Colors.deepOrange, cost: themeCostLow),
  ThemeOption(id: 'purple', name: 'بنفسجي إبداعي', color: Colors.deepPurple, cost: themeCostMid),
  ThemeOption(id: 'blueGrey', name: 'كحلي احترافي', color: Colors.blueGrey, cost: themeCostMid),
  ThemeOption(id: 'pink', name: 'وردي طاقة', color: Colors.pinkAccent, cost: themeCostHigh),
];

// =============================================================================
// سجل جلسة تركيز واحدة
// =============================================================================
class FocusSession {
  final DateTime date;
  final int minutes;
  FocusSession({required this.date, required this.minutes});

  Map<String, dynamic> toJson() =>
      {'date': date.toIso8601String(), 'minutes': minutes};
  factory FocusSession.fromJson(Map<String, dynamic> j) => FocusSession(
        date: DateTime.parse(j['date'] as String),
        minutes: j['minutes'] as int,
      );
}

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

  final List<FocusSession> history = [];

  int get level => 1 + (totalSessions ~/ 5);
  int get todaysSessions => history
      .where((s) => _isSameDay(s.date, DateTime.now()))
      .length;
  int get todaysMinutes => history
      .where((s) => _isSameDay(s.date, DateTime.now()))
      .fold(0, (sum, s) => sum + s.minutes);

  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    coins = prefs.getInt('coins') ?? 0;
    totalSessions = prefs.getInt('totalSessions') ?? 0;
    streakDays = prefs.getInt('streakDays') ?? 0;
    selectedThemeId = prefs.getString('selectedThemeId') ?? 'indigo';
    ownedThemeIds.addAll(prefs.getStringList('ownedThemeIds') ?? ['indigo']);
    final lastDayStr = prefs.getString('lastCompletedDay');
    if (lastDayStr != null) lastCompletedDay = DateTime.tryParse(lastDayStr);
    final lastRewardDayStr = prefs.getString('lastRewardDay');
    rewardedUsedToday = lastRewardDayStr != null &&
        _isSameDay(DateTime.parse(lastRewardDayStr), DateTime.now());
    notifyListeners();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('coins', coins);
    await prefs.setInt('totalSessions', totalSessions);
    await prefs.setInt('streakDays', streakDays);
    await prefs.setString('selectedThemeId', selectedThemeId);
    await prefs.setStringList('ownedThemeIds', ownedThemeIds.toList());
    if (lastCompletedDay != null) {
      await prefs.setString(
          'lastCompletedDay', lastCompletedDay!.toIso8601String());
    }
  }

  // يُستدعى عند إكمال جلسة تركيز (وقت عمل كامل بدون إلغاء)
  Future<void> completeFocusSession(int minutes) async {
    totalSessions += 1;
    coins += coinsPerSession;
    history.insert(0, FocusSession(date: DateTime.now(), minutes: minutes));

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

  void selectTheme(String id) {
    selectedThemeId = id;
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

  RewardedAd? rewardedAd;

  Timer? _bannerRefreshTimer;

  void preloadAll() {
    loadBanner();
    loadNative();
    loadRewarded();
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

  void disposeAll() {
    _bannerRefreshTimer?.cancel();
    bannerAd?.dispose();
    nativeAd?.dispose();
    rewardedAd?.dispose();
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

class _HomeScreenState extends State<HomeScreen> {
  int _tabIndex = 0;

  @override
  void initState() {
    super.initState();
    AdManager.instance.addListener(_refresh);
    AppState.instance.addListener(_refresh);
  }

  @override
  void dispose() {
    AdManager.instance.removeListener(_refresh);
    AppState.instance.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Color get _themeColor => themeOptions
      .firstWhere((t) => t.id == AppState.instance.selectedThemeId)
      .color;

  @override
  Widget build(BuildContext context) {
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                const Icon(Icons.monetization_on, color: Colors.amber),
                const SizedBox(width: 4),
                Text('${AppState.instance.coins}',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(child: pages[_tabIndex]),
          if (AdManager.instance.isBannerLoaded &&
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
  int _remainingSeconds = workMinutesDefault * 60;
  bool _isRunning = false;
  Timer? _ticker;

  int get _phaseTotalSeconds {
    switch (_phase) {
      case PomodoroPhase.work:
        return workMinutesDefault * 60;
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
      await AppState.instance.completeFocusSession(workMinutesDefault);
      _completedInCycle += 1;
      final nextPhase = _completedInCycle % sessionsBeforeLongBreak == 0
          ? PomodoroPhase.longBreak
          : PomodoroPhase.shortBreak;
      setState(() {
        _phase = nextPhase;
        _remainingSeconds = _phaseTotalSeconds;
        _isRunning = false;
      });
      if (mounted) _showSessionCompleteSheet();
    } else {
      setState(() {
        _phase = PomodoroPhase.work;
        _remainingSeconds = _phaseTotalSeconds;
        _isRunning = false;
      });
    }
  }

  void _showSessionCompleteSheet() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🎉 أحسنت! أكملت جلسة تركيز',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('+$coinsPerSession عملة  •  سلسلة ${AppState.instance.streakDays} يوم',
                style: const TextStyle(fontSize: 15, color: Colors.grey)),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('متابعة'),
            ),
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
    final themeColor = themeOptions
        .firstWhere((t) => t.id == AppState.instance.selectedThemeId)
        .color;
    final progress = 1 - (_remainingSeconds / _phaseTotalSeconds);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Text(_phaseLabel, style: const TextStyle(fontSize: 20)),
          const SizedBox(height: 24),
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
          const SizedBox(height: 32),
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
                  label: 'سلسلة ${AppState.instance.streakDays} يوم'),
              _StatChip(
                  icon: Icons.check_circle,
                  label: 'اليوم: ${AppState.instance.todaysSessions} جلسات'),
              _StatChip(
                  icon: Icons.military_tech,
                  label: 'المستوى ${AppState.instance.level}'),
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
// =============================================================================
class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppState.instance;
    final history = state.history;

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
              child: Center(child: Text('لا توجد جلسات بعد، ابدأ أول تركيز لك!')),
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
                      title: Text('${session.minutes} دقيقة تركيز'),
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
// شاشة المتجر: ثيمات ألوان + مضاعفة عملات اليوم عبر إعلان مكافأة
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

  void _onBuyTheme(BuildContext context, ThemeOption option) {
    final state = AppState.instance;
    if (state.ownedThemeIds.contains(option.id)) {
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
        const SizedBox(height: 24),
        const Text('🎨 ثيمات الألوان',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ...themeOptions.map((t) {
          final owned = state.ownedThemeIds.contains(t.id);
          final selected = state.selectedThemeId == t.id;
          return Card(
            child: ListTile(
              leading: CircleAvatar(backgroundColor: t.color),
              title: Text(t.name),
              subtitle: Text(owned
                  ? (selected ? 'مُفعّل حالياً' : 'مملوك')
                  : 'السعر: ${t.cost} 🪙'),
              trailing: ElevatedButton(
                onPressed: selected ? null : () => _onBuyTheme(context, t),
                child: Text(owned ? (selected ? 'مفعّل' : 'تفعيل') : 'شراء'),
              ),
            ),
          );
        }),
      ],
    );
  }
}


