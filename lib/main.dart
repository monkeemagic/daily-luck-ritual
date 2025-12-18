import 'dart:math';
import 'dart:async';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'sound_manager.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:daily_luck_ritual/iap/iap_service.dart';
import '../iap/iap_constants.dart';

/// ========================================
/// APP VERSION
/// ========================================
const String kAppVersion = '3.10.4';
const String kThemeOcean = 'ocean';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await IapService.instance.initialize();
  await MobileAds.instance.initialize();
  runApp(const DailyRitualApp());
}

class DailyRitualApp extends StatelessWidget {
  const DailyRitualApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF3EADB), // Creamier, warmer off-white
        textTheme: GoogleFonts.dmSansTextTheme(
          Theme.of(context).textTheme,
        ),
      ),
      home: const AtmosphereScreen(),
    );
  }
}

// ========================================
// Theme palette mapping for button and tideline (Ocean reference, Forest, Autumn)
final _themePalettes = {
  kThemeOcean: {
    'primaryButton': Color(0xFFA3D5D3), // Aqua blue-green
    'primaryButtonText': Color(0xFF4A4A48),
    'ctaButton': Color(0xB8A3D5D3), // increase to 72% opacity for Ocean
    'ctaBorder': Color(0xFF8FAFB3), // Muted mist blue. Harmonizes with ocean variance field and avoids green
    'tidelineTop': Color(0x3E23C0E8), // 24% of Ocean's theme hue
    'tidelineBottom': Color(0x1B23C0E8), // 11% of Ocean's hue
    'tidelineText': Color(0xFF4A4A48),
  },
  kThemeForest: {
    'primaryButton': Color(0x454CB866), // 27% opacity, softer visual weight
    'primaryButtonText': Color(0xFF4A4A48),
    'ctaButton': Color(0xCC4CB866), // increase to 80% opacity for Forest
    'ctaBorder': Color(0xFFA8B6A6),    // muted olive edge
    'tidelineTop': Color(0x3E4CB866), // 24% of Forest hue
    'tidelineBottom': Color(0x1B4CB866), // 11% of Forest hue
    'tidelineText': Color(0xFF4A4A48),
  },
  kThemeAutumn: {
    'primaryButton': Color(0xFFF6E3CB), // Soft muted cream/amber
    'primaryButtonText': Color(0xFF4A4A48),
    'ctaButton': Color(0xCCFFD34D), // increase to 80% opacity for Autumn
    'ctaBorder': Color(0xFFC3B5A3),    // Beige-tan edge
    'tidelineTop': Color(0x3EFFD34D), // 24% of Autumn hue
    'tidelineBottom': Color(0x1BFFD34D), // 11% of Autumn hue
    'tidelineText': Color(0xFF4A4A48),
  },
};

class AtmosphereScreen extends StatefulWidget {
  const AtmosphereScreen({super.key});

  @override
  State<AtmosphereScreen> createState() => _AtmosphereScreenState();
}

class _AtmosphereScreenState extends State<AtmosphereScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  // Expose IAP ownership for Forest and Autumn theme unlocking
  bool get _forestUnlocked => IapService.instance.owns(kThemeForest);
  bool get _autumnUnlocked => IapService.instance.owns(kThemeAutumn);
  bool get _isSupporter => IapService.instance.owns(kSupportProject);
  // Ocean theme is always unlocked

  // ========================================
  // 🔊 SOUND CONTROL STATE
  // ========================================
  bool _soundMasterEnabled = true;
  bool _ambienceEnabled = true;
  bool _sfxEnabled = true;
  double _ambienceVolume = 0.3;
  double _sfxVolume = 0.4;

  // ========================================
  // 🔊 SETTINGS MODAL (with SOUND CONTROLS)
  // ========================================
  Widget buildSettingsModal(BuildContext context) {
    final palette = _themePalettes[(kDebugMode ? _devThemeValue : _userThemeValue)] ?? _themePalettes[kThemeOcean]!;
    return Padding(
      padding: const EdgeInsets.only(
        top: 18,
        left: 16,
        right: 16,
        bottom: 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Settings',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: palette['primaryButtonText'] ?? const Color(0xFF4A4A48),
              ),
            ),
            const SizedBox(height: 16),
            StatefulBuilder(
              builder: (context, setModalState) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SwitchListTile(
                      value: _soundMasterEnabled,
                      title: const Text('Sound (Master switch)', style: TextStyle(fontSize: 16)),
                      activeColor: palette['primaryButton'] ?? const Color(0xFFA3D5D3),
                      onChanged: (val) {
                        setState(() {
                          _soundMasterEnabled = val;
                          if (!val) {
                            SoundManager.instance.stopAll();
                          } else if (_ambienceEnabled) {
                            SoundManager.instance.startAmbient();
                          }
                        });
                        setModalState(() {});
                      },
                    ),
                    SwitchListTile(
                      value: _ambienceEnabled,
                      title: const Text('Ambient sound', style: TextStyle(fontSize: 16)),
                      activeColor: palette['primaryButton'] ?? const Color(0xFFA3D5D3),
                      onChanged: _soundMasterEnabled
                          ? (val) {
                              setState(() {
                                _ambienceEnabled = val;
                                if (val && _soundMasterEnabled) {
                                  SoundManager.instance.startAmbient();
                                } else {
                                  SoundManager.instance.stopAmbient();
                                }
                              });
                              setModalState(() {});
                            }
                          : null,
                    ),
                    SwitchListTile(
                      value: _sfxEnabled,
                      title: const Text('Button tap sound', style: TextStyle(fontSize: 16)),
                      activeColor: palette['primaryButton'] ?? const Color(0xFFA3D5D3),
                      onChanged: _soundMasterEnabled
                          ? (val) {
                              setState(() {
                                _sfxEnabled = val;
                              });
                              setModalState(() {});
                            }
                          : null,
                    ),
                    ListTile(
                      title: const Text('Ambient volume', style: TextStyle(fontSize: 15)),
                      subtitle: Slider(
                        value: _ambienceVolume,
                        min: 0,
                        max: 1,
                        onChanged: _soundMasterEnabled && _ambienceEnabled
                            ? (v) {
                                setModalState(() {
                                  _ambienceVolume = v;
                                });
                              }
                            : null,
                        onChangeEnd: _soundMasterEnabled && _ambienceEnabled
                            ? (v) {
                                setState(() {
                                  _ambienceVolume = v;
                                  SoundManager.instance.setAmbientVolume(v);
                                });
                              }
                            : null,
                      ),
                    ),
                    ListTile(
                      title: const Text('Button tap volume', style: TextStyle(fontSize: 15)),
                      subtitle: Slider(
                        value: _sfxVolume,
                        min: 0,
                        max: 1,
                        onChanged: _soundMasterEnabled && _sfxEnabled
                            ? (v) {
                                setModalState(() {
                                  _sfxVolume = v;
                                });
                              }
                            : null,
                        onChangeEnd: _soundMasterEnabled && _sfxEnabled
                            ? (v) {
                                setState(() {
                                  _sfxVolume = v;
                                  SoundManager.instance.setSfxVolume(v);
                                });
                              }
                            : null,
                      ),
                    ),
                    const SizedBox(height: 26),
                    Text('themes', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: palette['primaryButtonText'] ?? Color(0xFF4A4A48))),
                    const SizedBox(height: 12),
                    ListTile(
                      title: Text('ocean'),
                      subtitle: Text('applied', style: TextStyle(fontSize: 15, color: Color(0xFF4A4A48))),
                      onTap: () { setState(() { _userThemeValue = kThemeOcean; }); },
                    ),
                    GestureDetector(
                      onTap: () async {
                        if (_forestUnlocked) {
                          setState(() { _userThemeValue = kThemeForest; });
                        } else {
                          await IapService.instance.buy(kThemeForest);
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('forest'),
                                  Text(_forestUnlocked && _userThemeValue == kThemeForest ? 'applied' : 'available', style: TextStyle(fontSize: 15, color: Color(0xFF4A4A48))),
                                ],
                              ),
                            ),
                            Icon(Icons.chevron_right, size: 16, color: Color(0xFF222222).withOpacity(0.62)),
                          ],
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () async {
                        if (_autumnUnlocked) {
                          setState(() { _userThemeValue = kThemeAutumn; });
                        } else {
                          await IapService.instance.buy(kThemeAutumn);
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('autumn'),
                                  Text(_autumnUnlocked && _userThemeValue == kThemeAutumn ? 'applied' : 'available', style: TextStyle(fontSize: 15, color: Color(0xFF4A4A48))),
                                ],
                              ),
                            ),
                            Icon(Icons.chevron_right, size: 16, color: Color(0xFF222222).withOpacity(0.62)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    const Text(
                      'about',
                      style: TextStyle(
                        fontSize: 17,
                        color: Color(0xFF4A4A48),
                        height: 1.55,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0,
                      ),
                      textAlign: TextAlign.left,
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'daily luck ritual was made as a quiet space to pause\n\n'
                      'it doesn’t predict outcomes or tell you who to be\n'
                      'it simply reflects a brief moment, once per day\n\n'
                      'there are no streaks, no pressure, and nothing to keep up with\n\n'
                      'if it helps you slow down, that’s enough\n\n'
                      'this app is made independently and kept intentionally simple',
                      textAlign: TextAlign.left,
                      style: TextStyle(
                        fontSize: 15,
                        color: Color(0xFF4A4A48),
                        height: 1.55,
                        fontWeight: FontWeight.w400,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'thank you',
                      style: TextStyle(
                        fontSize: 17,
                        color: Color(0xFF4A4A48),
                        height: 1.55,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0,
                      ),
                      textAlign: TextAlign.left,
                    ),
                    const SizedBox(height: 4),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: const Text(
                        'this project is maintained and nurtured over time\n'
                        'your contributions enable development,\n'
                        'infrastructure, and future improvements\n'
                        'your daily ritual will always be free\n',
                        textAlign: TextAlign.left,
                        style: TextStyle(
                          fontSize: 15,
                          color: Color(0xFF4A4A48),
                          height: 1.55,
                          fontWeight: FontWeight.w400,
                          letterSpacing: 0,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: _isSupporter ? null : () async {
                        await IapService.instance.buy(kSupportProject);
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 2),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Text(
                                _isSupporter ? 'much appreciated' : 'show appreciation',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Color(0xFF4A4A48),
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: 0.05,
                                ),
                              ),
                            ),
                            if (!_isSupporter) Icon(Icons.chevron_right, size: 16, color: Color(0xFF222222).withOpacity(0.62)),
                          ],
                        ),
                      ),
                    ),



                  ],
                );
              }
            ),
          ],
        ),
      ),
    );
  }

  // ========================================
  // 🍀 CORE STATE
  // ========================================
  double luckIndex = 50.0;

  // Atmospheric field phased variance logic
  // int _atmosphericHazePersistEpoch = 0; // removed: unused
  // DEV-only theme override (session-only; never persisted)
  int _devThemeIndex = 0; // 0=ocean, 1=forest, 2=autumn
  // User-selected theme for release/non-debug (persisted, replace with prefs if needed)
  String _userThemeValue = kThemeOcean;

  // ... keep only one set of sound state variables: remove this duplicate block ...
  // (REMOVED: duplicate sound state variables here)

  String get _devThemeValue {
    final themes = [
      kThemeOcean,
      kThemeForest,
      kThemeAutumn,
    ];
    return themes[_devThemeIndex % themes.length];
  }

  String get _devThemeLabel {
    switch (_devThemeValue) {
      case kThemeForest:
        return 'Forest';
      case kThemeAutumn:
        return 'Autumn';
      case kThemeOcean:
      default:
        return 'Ocean';
    }
  }

  void _cycleDevTheme() {
    if (!kDebugMode) return;
    setState(() {
      _devThemeIndex = (_devThemeIndex + 1) % 3;
      // Nudge a repaint for any painters that rely on theme-derived colors.
    });
  }

  // Canonical model:
  // The Luck Index is an atmospheric reading (not a score, not improvable).
  // User interactions are observation (non-performative).
  bool primaryReadingTakenToday = false;
  bool primaryReadingRevealed = false;
  double? pendingPrimaryReadingLuck;
  double? primaryReadingLuckBaseline;

  // Continued observation count after the primary reading (mechanics unchanged).
  int observationInteractionsToday = 0;

  bool daySettled = false;

  // Legacy storage key is unchanged in SharedPreferences; mechanics unchanged.
  int observationCredits = 1;
  bool isSampling = false;
  bool _readingWasRevealedAtSamplingStart = false;

  String? meaningArchetype; // Step 4: The core meaning of the day
  int? reflectionVariantId; // Step 4C addendum: which reflection variant (0..2)
  String? dailyReflection; // Step 4: Optional reflection text
  int? holdTheDayVariantId; // Step 4D: chosen once when day becomes complete (0..9)
  // Minimal audio controls (ambient + tap SFX). No theme switching.
  bool _holdSfxPlayed = false;

  // Cached measurement to reserve stable space for reflection/hold-the-day text
  double? _cachedMeaningBlockHeight;
  double? _cachedMeaningBlockWidth;
  double? _cachedTextScaleFactor;

  // Visual is an atmospheric system (non-evaluative; not a performance mechanic).
  // Sampling visuals are state-driven (declarative), not "played" as a start/end beat.
  int _samplingEpoch = 0; // increments per sampling to restart the visual tween
  int _samplingDurationMs = 0; // set when sampling begins
  // Curve _samplingMotionCurve = Curves.linear; // removed: unused
  double _samplingMotionCycles = 0.0; // preserves legacy motion-cycle math for visual texture only

  // ========================================
  // 📺 ADS
  // ========================================
  RewardedAd? rewardedAd;
  bool isAdLoading = false;

  int rewardedAdsToday = 0;
  static const int kMaxRewardedAdsPerDay = 3;
  bool adsDeclinedToday = false;

  // Safety (non-verbal): require a deliberate gesture (long-press) to decline ads.
  Timer? _declineHoldTimer;
  Timer? _ctaRevealTimer;
  bool _ctaReady = true;

  // Step 4E: Tideline (ambient settling visual)
  late final AnimationController tidelineController;
  late final AnimationController tidelineGateController;
  late final Animation<double> tidelineGate;
  bool _reduceMotion = false;
  double _tidelineTime = 0.0; // continuous time accumulator (prevents loop snaps)
  double _tidelineWaveTime = 0.0; // wave phase time (continuous; avoids phase snapping on value changes)
  double _lastTidelinePhase = 0.0;

  // ========================================
  // 🧘 HOLD THE DAY
  // ========================================
  late AnimationController holdController;
  late Animation<double> holdIntensity;

  // ========================================
  // 🔢 NORMALIZED INTERACTION PROGRESS
  // ========================================
  double get interactionProgress {
    if (!primaryReadingTakenToday) return 0.0;
    const double maxPostPrimaryObservationInteractions = 7.0;
    final double progress =
        observationInteractionsToday / maxPostPrimaryObservationInteractions;
    return progress.clamp(0.0, 1.0);
  }

  // ========================================
  // 🧠 FRONT-LOADED SETTLING (DISTANCE)
  // ========================================
  double _frontLoadedSettling(double p) {
    final s = p.clamp(0.0, 1.0);
    const double k = 2.2;
    return 1.0 - pow(1.0 - s, k).toDouble();
  }

  // ========================================
  // 🌫️ ATMOSPHERIC MOTION DISTANCE FACTOR
  // ========================================
  double get atmosphericMotionDistanceFactor {
    if (!primaryReadingTakenToday) return 1.0;

    final settled =
    _frontLoadedSettling(interactionProgress);
    final factor = 1.0 - (settled * 0.82);

    return factor.clamp(0.18, 1.0);
  }

  int get nextObservationCost =>
      primaryReadingTakenToday ? 1 : 0;

  bool get adsExhausted =>
      rewardedAdsToday >= kMaxRewardedAdsPerDay;

  bool get canShowAd =>
      primaryReadingRevealed &&
          !isSampling &&
          observationCredits < nextObservationCost &&
          !adsExhausted &&
          !adsDeclinedToday;

  // CTA remains visible after ads exhausted
  bool get showCta =>
      primaryReadingRevealed &&
          !isSampling &&
          observationCredits < nextObservationCost &&
          _ctaReady;

  // Step 4D: Day is complete (no further observation, ads exhausted OR declined, settling finished)
  bool get isDayComplete =>
      primaryReadingRevealed &&
          observationCredits < nextObservationCost &&
          (adsExhausted || adsDeclinedToday) &&
          daySettled;

  // Visual affordance for exhaustion
  double get ctaOpacity =>
      (adsExhausted || adsDeclinedToday) ? 0.6 : 1.0;

  Future<void> _declineAdsAndCompleteDay() async {
    // No new UI copy; this is an implicit “decline” via existing primary button
    // when the user has no observation credit and does not take an ad.
    if (adsDeclinedToday || adsExhausted) return;
    if (!showCta) return;

    setState(() {
      adsDeclinedToday = true;
      // Option A: complete settling immediately and persist via interaction progress.
      observationInteractionsToday = 7;
      daySettled = true;
    });

    await _persistState();
    await _ensureHoldTheDayVariantAssigned();
  }

  // ========================================
  // 🌅 LIFECYCLE
  // ========================================
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ctaReady = true;
    // Start audio after first frame; safe even before files are present (errors are swallowed).
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await SoundManager.instance.ensureVolumesLoaded();
      setState(() {
        _ambienceVolume = SoundManager.instance.ambientVolume;
        _sfxVolume = SoundManager.instance.sfxVolume;
      });
      if (_soundMasterEnabled && _ambienceEnabled) {
        unawaited(SoundManager.instance.startAmbient());
      }
    });

    tidelineController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 22),
    );
    tidelineController.addListener(() {
      final v = tidelineController.value;
      var delta = v - _lastTidelinePhase;
      if (delta < 0) delta += 1.0; // handle repeat wrap
      _tidelineTime += delta;

      // Keep wave phase continuous even as "settled" changes.
      // IMPORTANT: Do NOT scale phase as `time * speed` in the painter, since changing `speed`
      // changes the absolute phase and reads as a “shove”. Instead, integrate speed into time.
      final double settledNow =
          primaryReadingRevealed ? _frontLoadedSettling(interactionProgress) : 0.0;
      final bool canMove =
          (primaryReadingRevealed || isSampling) && !_reduceMotion;
      final double speed = canMove ? (lerpDouble(1.0, 0.08, settledNow) ?? 1.0) : 0.0;
      _tidelineWaveTime += delta * speed;

      _lastTidelinePhase = v;
    });
    tidelineGateController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    tidelineGate = CurvedAnimation(
      parent: tidelineGateController,
      curve: Curves.easeOutCubic,
    );

    holdController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 24500),
    );

    holdIntensity = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 500,
      ),
      TweenSequenceItem(
        tween: ConstantTween(1.0),
        weight: 21000,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 0.0)
            .chain(CurveTween(curve: Curves.easeInOutCubic)),
        weight: 3000,
      ),
    ]).animate(holdController);

    _loadDailyState();
    
    // Preload ad on app start if primary reading already revealed
    Future.delayed(const Duration(milliseconds: 500), () {
      if (primaryReadingRevealed && !adsExhausted) {
        loadRewardedAd();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(SoundManager.instance.stopAmbient());
    tidelineController.dispose();
    tidelineGateController.dispose();
    holdController.dispose();
    rewardedAd?.dispose();
    _declineHoldTimer?.cancel();
    _ctaRevealTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final mq = MediaQuery.of(context);
    final newReduceMotion = mq.disableAnimations || mq.accessibleNavigation;
    if (newReduceMotion != _reduceMotion) {
      _reduceMotion = newReduceMotion;
      _updateTidelineMotion();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      SoundManager.instance.stopAll();
    }
    if (state == AppLifecycleState.resumed) {
      SoundManager.instance.ensureVolumesLoaded().then((_) {
        setState(() {
          _ambienceVolume = SoundManager.instance.ambientVolume;
          _sfxVolume = SoundManager.instance.sfxVolume;
        });
      });
      if (_soundMasterEnabled && _ambienceEnabled) {
        SoundManager.instance.startAmbient().catchError((_) {
          // Single safe retry on Source error (real device audio init race)
          if (_soundMasterEnabled && _ambienceEnabled) {
            return SoundManager.instance.startAmbient();
          }
          return Future<void>.value();
        }).then((_) {
          setState(() {
            _ambienceVolume = SoundManager.instance.ambientVolume;
          });
        });
      }
      // (SFX are always event-triggered, so they are not resumed blindly)
    }
  }

  void _updateTidelineMotion() {
    // Step 4E gating:
    // - Before primary reading: fully static
    // - After primary reading: eligible to move (unless Reduce Motion)
    // - During sampling: eligible to move (unless Reduce Motion)
    final shouldAnimate = (primaryReadingRevealed || isSampling) && !_reduceMotion;
    if (shouldAnimate) {
      if (!tidelineController.isAnimating) {
        // Start from a stable phase/time to avoid any visible “jump” in shape.
        _tidelineTime = 0.0;
        _tidelineWaveTime = 0.0;
        _lastTidelinePhase = 0.0;
        // Animate to 0.0 before repeating, if not already there.
        if ((tidelineController.value - 0.0).abs() > 1e-4) {
          tidelineController.animateTo(0.0, duration: const Duration(milliseconds: 440), curve: Curves.easeOut)
              .whenComplete(() => tidelineController.repeat());
        } else {
          tidelineController.repeat();
        }
      }
      // Avoid a visible “start”: gently ramp motion in once the primary reading completes.
      if (tidelineGateController.value == 0.0) {
        tidelineGateController.forward(from: 0);
      }
    } else {
      if (tidelineController.isAnimating) {
        tidelineController.stop();
      }
      // Animate smoothly to 0.0 instead of snapping instantly.
      if ((tidelineController.value - 0.0).abs() > 1e-4) {
        tidelineController.animateTo(0.0, duration: const Duration(milliseconds: 440), curve: Curves.easeOut);
      }
      if ((tidelineGateController.value - 0.0).abs() > 1e-4) {
        tidelineGateController.animateTo(0.0, duration: const Duration(milliseconds: 360), curve: Curves.easeOut);
      }
      _tidelineTime = 0.0;
      _tidelineWaveTime = 0.0;
      _lastTidelinePhase = 0.0;
    }
  }

  // ========================================
  // 🌅 DAILY LOAD / RESET
  // ========================================
  Future<void> _loadDailyState() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final todayKey =
        '${now.year}-${now.month}-${now.day}';

    if (prefs.getString('app_version') != kAppVersion) {
      await prefs.clear();
      await prefs.setString('app_version', kAppVersion);
    }

    if (prefs.getString('last_day') != todayKey) {
      tidelineController.value = 0.0;
      tidelineGateController.value = 0.0;
      await _resetDay();
    } else {
      setState(() {
        luckIndex = prefs.getDouble('luck') ?? 50.0;
        primaryReadingTakenToday = prefs.getBool('anchor') ?? false;
        primaryReadingRevealed =
            prefs.getBool('anchor_revealed') ?? false;
        observationInteractionsToday =
            prefs.getInt('volatility') ?? 0;
        observationCredits = prefs.getInt('chances') ?? 1;
        meaningArchetype = prefs.getString('meaning_archetype');
        reflectionVariantId = prefs.getInt('reflection_variant');
        dailyReflection = prefs.getString('reflection');
        holdTheDayVariantId = prefs.getInt('hold_variant');
        primaryReadingLuckBaseline =
            prefs.getDouble('anchor_luck');
        rewardedAdsToday =
            prefs.getInt('ads_today') ?? 0;
        adsDeclinedToday =
            prefs.getBool('ads_declined') ?? false;
      });

      daySettled = interactionProgress >= 1.0;

      // Preload ad if primary reading already revealed today
      if (primaryReadingRevealed && !adsExhausted) {
        loadRewardedAd();
      }

      // If the day is already complete on load, ensure hold-the-day variant is assigned (silent).
      await _ensureHoldTheDayVariantAssigned(playSfx: false);
      _updateTidelineMotion();
    }
  }

  Future<void> _persistState() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setDouble('luck', luckIndex);
    await prefs.setBool('anchor', primaryReadingTakenToday);
    await prefs.setBool(
        'anchor_revealed', primaryReadingRevealed);
    await prefs.setInt(
        'volatility', observationInteractionsToday);
    await prefs.setInt('chances', observationCredits);
    await prefs.setInt('ads_today', rewardedAdsToday);
    await prefs.setBool('ads_declined', adsDeclinedToday);

    if (meaningArchetype != null) {
      await prefs.setString(
          'meaning_archetype', meaningArchetype!);
    }
    if (reflectionVariantId != null) {
      await prefs.setInt(
          'reflection_variant', reflectionVariantId!);
    }
    if (holdTheDayVariantId != null) {
      await prefs.setInt('hold_variant', holdTheDayVariantId!);
    }
    if (dailyReflection != null) {
      await prefs.setString(
          'reflection', dailyReflection!);
    }
    if (primaryReadingLuckBaseline != null) {
      await prefs.setDouble(
          'anchor_luck', primaryReadingLuckBaseline!);
    }

    await prefs.setString(
        'app_version', kAppVersion);
  }

  Future<void> _resetDay() async {
    final prefs = await SharedPreferences.getInstance();

    setState(() {
      luckIndex = 50.0;
      primaryReadingTakenToday = false;
      primaryReadingRevealed = false;
      pendingPrimaryReadingLuck = null;
      primaryReadingLuckBaseline = null;
      observationInteractionsToday = 0;
      observationCredits = 1;
      rewardedAdsToday = 0;
      adsDeclinedToday = false;
      meaningArchetype = null;
      reflectionVariantId = null;
      dailyReflection = null;
      holdTheDayVariantId = null;
      _holdSfxPlayed = false;
      _readingWasRevealedAtSamplingStart = false;
      daySettled = false;
    });

    _ctaReady = true;
    _ctaRevealTimer?.cancel();
    _updateTidelineMotion();

    await prefs.setString(
      'last_day',
      '${DateTime.now().year}-${DateTime.now().month}-${DateTime.now().day}',
    );

    await _persistState();
  }

  // ========================================
  // 🍀 ATMOSPHERIC READING LOGIC (MECHANICS UNCHANGED)
  // ========================================
  double _anchorLuck() {
    final r = Random().nextInt(1000);
    if (r < 650) return _rand(40, 70);
    if (r < 830) return _rand(70, 82);
    if (r < 930) return _rand(25, 40);
    if (r < 990) return _rand(82, 95);
    return _rand(95, 98.5);
  }

  double _rand(double a, double b) =>
      a + Random().nextDouble() * (b - a);

  double _volatilityDelta() {
    double range;

    if (observationInteractionsToday <= 2) {
      range = 7.0;
    } else if (observationInteractionsToday <= 5) {
      range = 4.5;
    } else {
      if (luckIndex >= 98) {
        range = 0.05;
      } else if (luckIndex >= 95) {
        range = 0.2;
      } else if (luckIndex >= 90) {
        range = 0.4;
      } else {
        range = 1.3;
      }
    }

    double delta = _rand(-range, range);

    if (primaryReadingLuckBaseline != null &&
        primaryReadingLuckBaseline! < 40 &&
        observationInteractionsToday <= 2) {
      delta += 2.5;
    }

    if (luckIndex >= 90 && delta > 0) {
      final t =
      ((luckIndex - 90) / 8.5).clamp(0.0, 1.0);
      delta *= (1 - t).clamp(0.02, 1.0);
    }

    if (luckIndex >= 98.5 && delta > 0) {
      delta = 0.0;
    }

    return delta;
  }

  // ========================================
  // 🧘 STEP 4: MEANING & REFLECTION (LOCKED)
  // ========================================
  
  // Step 4A: The 12 locked meaning archetypes
  static const List<String> _meaningArchetypes = [
    'Grounded',
    'Steady',
    'Quiet',
    'Gentle',
    'Restful',
    'Unhurried',
    'Clear',
    'Open',
    'Warm',
    'Light',
    'Reflective',
    'Holding',
  ];

  // Step 4C: Canonical reflection variants (revised for neutrality & empowerment)
  // Exactly 3 variants per archetype. Choose one at anchor and persist it.
  static const Map<String, List<String>> _reflectionVariants = {
    'Grounded': [
      'you are here with the day as it is',
      'this moment has something solid to stand on',
      'the day is present beneath you',
    ],
    'Steady': [
      'the day is holding its shape',
      'things are continuing in their own way',
      'there is a steadiness available here',
    ],
    'Quiet': [
      'the day is not loud right now',
      'there is space for quiet to exist',
      'this moment does not require noise',
    ],
    'Gentle': [
      'there’s room to move softly',
      'there is room for a gentle pace',
      'nothing here needs pressure',
    ],
    'Restful': [
      'the day allows for rest to be present',
      'this moment doesn’t require energy',
      'the day makes space for rest',
    ],
    'Unhurried': [
      'the day is not in a rush',
      'time is moving without urgency',
      'the pace can stay loose',
    ],
    'Clear': [
      'what’s here is enough to see',
      'the day is not asking to be sorted',
      'there’s little standing in the way',
    ],
    'Open': [
      'there’s space without expectation',
      'nothing needs to be decided in this moment',
      'there is space without direction',
    ],
    'Warm': [
      'there is a quiet warmth present today',
      'the day carries a gentle human tone',
      'there’s something kind in the air',
    ],
    'Light': [
      'the day is not weighted with meaning',
      'this moment does not carry extra burden',
      'there’s less weight to carry',
    ],
    'Reflective': [
      'you can notice without deciding',
      'the day allows for observation',
      'there’s room to observe quietly',
    ],
    'Holding': [
      'the day is being held as it unfolds',
      'you don’t have to hold everything yourself',
      'support exists around this moment',
    ],
  };

  // Step 4B: Assign meaning archetype (called once at anchor)
  String _assignMeaningArchetype() {
    final rnd = Random();
    return _meaningArchetypes[rnd.nextInt(_meaningArchetypes.length)];
  }

  // Step 4C: Assign reflection variant id (0..2), called once at anchor
  int _assignReflectionVariantId() => Random().nextInt(3);

  // Step 4C: Get reflection text for archetype + variant id
  String _getReflectionText(String archetype, int variantId) {
    final variants = _reflectionVariants[archetype];
    if (variants == null || variants.isEmpty) return '';
    final safeIndex = variantId.clamp(0, variants.length - 1);
    return variants[safeIndex];
  }

  // Step 4D: Hold-the-day variants (FINAL · CANONICAL)
  static const List<String> _holdTheDayVariants = [
    'you don’t need to carry this forward',
    'nothing here requires anything from you now',
    'you can let this stand on its own',
    'this can be left exactly where it is',
    'your attention is free to move on',
    'there’s nothing here you need to resolve',
    'this does not ask anything further of you',
    'this can exist without needing anything from you',
    'your attention can rest elsewhere now',
    'you can leave this here',
  ];

  int _assignHoldTheDayVariantId() => Random().nextInt(_holdTheDayVariants.length);

  String _getHoldTheDayText(int variantId) {
    final safeIndex = variantId.clamp(0, _holdTheDayVariants.length - 1);
    return _holdTheDayVariants[safeIndex];
  }

  Future<void> _ensureHoldTheDayVariantAssigned({bool playSfx = true}) async {
    // Assign once when the day becomes complete; immutable thereafter.
    if (!isDayComplete || holdTheDayVariantId != null) return;
    setState(() {
      holdTheDayVariantId = _assignHoldTheDayVariantId();
    });
    await _persistState();
    if (playSfx && !_holdSfxPlayed) {
      _holdSfxPlayed = true;
      // Minimal audio scope: keep silent (no extra SFX beyond tap).
    }
  }

  double _meaningBlockHeight(BuildContext context) {
    // Reserve enough space for the *worst-case* wrap across:
    // - Pre-anchor access copy (1 line, smaller style)
    // - Any reflection variant (all archetypes)
    // - Hold-the-day text (1 line)
    // This prevents snapping/shifting on small screens while staying as tight as possible.
    final media = MediaQuery.of(context);
    final width = (media.size.width - 48).clamp(200.0, 600.0);
    final textScale = media.textScaleFactor;

    if (_cachedMeaningBlockHeight != null &&
        _cachedMeaningBlockWidth == width &&
        _cachedTextScaleFactor == textScale) {
      return _cachedMeaningBlockHeight!;
    }

    const meaningStyle = TextStyle(
      fontSize: 18,
      color: Color(0xFF4A4A48),
      height: 1.6,
      letterSpacing: 0.3,
    );

    final List<String> meaningTexts = [
      ..._holdTheDayVariants,
      for (final variants in _reflectionVariants.values) ...variants,
    ];

    double maxH = 0;
    for (final t in meaningTexts) {
      final tp = TextPainter(
        text: TextSpan(text: t, style: meaningStyle),
        textDirection: TextDirection.ltr,
        textScaleFactor: textScale,
      )..layout(maxWidth: width);
      if (tp.height > maxH) maxH = tp.height;
    }


    // Small cushion for font metrics differences and to keep the block breathable.
    final result = (maxH + 10).clamp(44.0, 130.0); // Increased padding for larger font/line height
    _cachedMeaningBlockHeight = result;
    _cachedMeaningBlockWidth = width;
    _cachedTextScaleFactor = textScale;
    return result;
  }

  bool _showReflection = false; // Reflects canonical display pause

  void _onLuckIndexRevealed() {
    setState(() => _showReflection = false);
    Future.delayed(const Duration(milliseconds: 700), () {
      // Only display if number is still visible and settling is over (double check)
      if (mounted && primaryReadingRevealed && !isSampling) {
        setState(() => _showReflection = true);
      }
    });
  }

  // AtmosphericField is a persistent baseline environment layer.
  // Variance energy is temporary during sampling; afterwards, it returns to baseline (never unmounted).

  // ========================================
  // 📺 ADS
  // ========================================
  void loadRewardedAd() {
    if (isAdLoading || adsExhausted || rewardedAd != null) return;

    isAdLoading = true;

    RewardedAd.load(
      adUnitId:
      'ca-app-pub-3940256099942544/5224354917',
      request: const AdRequest(),
      rewardedAdLoadCallback:
      RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          rewardedAd = ad;
          isAdLoading = false;
        },
        onAdFailedToLoad: (_) {
          rewardedAd = null;
          isAdLoading = false;
        },
      ),
    );
  }


  void showRewardedAd() {
    if (!canShowAd || rewardedAd == null) return;

    rewardedAd!.show(onUserEarnedReward: (_, __) async {
      setState(() {
        observationCredits += 2;
        rewardedAdsToday++;
      });

      await _persistState();
      await _ensureHoldTheDayVariantAssigned();
    });

    rewardedAd = null;

    // PRELOAD NEXT AD (PIPELINE WARM)
    loadRewardedAd();
  }


  // ========================================
  // 🌫️ ATMOSPHERE SAMPLING FLOW (MECHANICS UNCHANGED)
  // ========================================
  Future<void> sampleAtmosphere() async {
    if (isSampling || observationCredits < nextObservationCost) return;

    final bool isPrimaryReading = !primaryReadingTakenToday;

    // Remove pre-sampling haze hold logic (variance phasing now via build).

    final int samplingDurationMs = isPrimaryReading ? 3400 : 2600;
    setState(() {
      isSampling = true;
      _readingWasRevealedAtSamplingStart = primaryReadingRevealed;
      // Keep secondary UI from “arriving” while the atmosphere system is active.
      _ctaReady = false;
      _ctaRevealTimer?.cancel();
      observationCredits -= nextObservationCost;
      if (isPrimaryReading) {
        pendingPrimaryReadingLuck = _anchorLuck();
        primaryReadingTakenToday = true;
      }
      // State-driven sampling visuals (no imperative "play" semantics).
      _samplingEpoch++;
      _samplingDurationMs = samplingDurationMs;
    });
    _updateTidelineMotion();

    await _persistState();

    _samplingMotionCycles =
        Random().nextDouble() * 3 + (isPrimaryReading ? 5 : 4);

    await Future.delayed(Duration(milliseconds: samplingDurationMs));

    if (isPrimaryReading) {
      final anchorLuck = pendingPrimaryReadingLuck!;
      setState(() {
        luckIndex = anchorLuck;
        primaryReadingLuckBaseline = anchorLuck;
        primaryReadingRevealed = true;
        // Step 4: Assign meaning archetype once
        meaningArchetype = _assignMeaningArchetype();
        // Step 4C addendum: pick exactly one reflection variant (0..2) at anchor
        reflectionVariantId = _assignReflectionVariantId();
        dailyReflection =
            _getReflectionText(meaningArchetype!, reflectionVariantId!);
        loadRewardedAd(); // PRELOAD AD AFTER PRIMARY READING
      });
      _updateTidelineMotion();

      await Future.delayed(
          const Duration(milliseconds: 450));
    } else {
      setState(() {
        luckIndex =
            (luckIndex + _volatilityDelta())
                .clamp(0, 98.5);
        observationInteractionsToday++;
        daySettled = interactionProgress >= 1.0;
      });
    }

    await _persistState();
    await _ensureHoldTheDayVariantAssigned();
    setState(() => isSampling = false);


    // Reveal CTA only after the settle moment, giving time to process what's on screen.
    _ctaRevealTimer = Timer(const Duration(milliseconds: 1500), () {
      if (!mounted) return;
      setState(() => _ctaReady = true);
    });

    // Atmospheric field phase now handled via build and showAtmosphere.
  }

  // ========================================
  // 🖼️ UI
  // ========================================
  @override
  Widget build(BuildContext context) {
    final canAffordObservation = observationCredits >= nextObservationCost;

    // Canonical semantics:
    // - Variance is perceptible during sampling
    // - Calm emerges as variance decays
    final bool isReadingActive = isSampling;

    if (canShowAd &&
        rewardedAd == null &&
        !isAdLoading) {
      loadRewardedAd();
    }

    final primaryLabel = isSampling
        ? 'settling…'
        : !primaryReadingTakenToday
        ? 'receive today’s reading'
        : canAffordObservation
        ? 'settle a little longer'
        : 'this is enough for today';
    final bool isEnoughLabel = primaryReadingTakenToday && !canAffordObservation;
    final String holdTheDayTextForToday =
        _getHoldTheDayText(holdTheDayVariantId ?? 0);

    final tidelineHeight =
        MediaQuery.of(context).size.height * 0.185; // larger presence
    final tidelineSettled =
        primaryReadingRevealed ? _frontLoadedSettling(interactionProgress) : 0.0;


    return Scaffold(
      body: Builder(
        builder: (context) {
          // 🔥 Remove anchor/day gating from tideline palette selection
          final Map<String, Color> palette = _themePalettes[(kDebugMode ? _devThemeValue : _userThemeValue)] ?? _themePalettes[kThemeOcean]!;

          return Stack(
            children: [
              // AtmosphericField: baseline environment layer with temporary variance energy.
              // No masks/feathering here (single-axis softening is handled in the painter).
              Positioned.fill(
                child: IgnorePointer(
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: FractionallySizedBox(
                      heightFactor: 0.55,
                      widthFactor: 1.0,
                      child: TweenAnimationBuilder<double>(
                        // Drives variance phase only; baseline is always present.
                        key: ValueKey<int>(_samplingEpoch),
                        duration: Duration(
                          milliseconds: (_samplingDurationMs > 0) ? _samplingDurationMs : 2600,
                        ),
                        curve: Curves.linear,
                        tween: Tween<double>(begin: 0.0, end: isSampling ? 1.0 : 0.0),
                        builder: (context, t, _) {
                          final Color baselineColor;
                          final Color varianceColor;
                          if ((kDebugMode ? _devThemeValue : _userThemeValue) == kThemeForest) {
                            baselineColor = const Color(0xFFD2DAD4); // muted grey-green
                            varianceColor = const Color(0xFF93ABA0); // low-chroma green-grey
                          } else if ((kDebugMode ? _devThemeValue : _userThemeValue) == kThemeAutumn) {
                            baselineColor = const Color(0xFFDED7CF); // muted warm grey
                            varianceColor = const Color(0xFFA8A094); // low-chroma warm-grey
                          } else {
                            // Ocean (default)
                            baselineColor = const Color(0xFFD6DFE3); // cool-grey
                            varianceColor = const Color(0xFF8FAFB3); // low-chroma mist
                          }

                          // Baseline visibility: calm but clearly perceptible in a static screenshot.
                          const double settledOpacity = 0.09;
                          const double peakOpacity = 0.11;

                          final bool animatedVariance = isSampling;
                          final double phaseT = t.clamp(0.0, 1.0);
                          final double variance = animatedVariance
                              ? _reduceMotion
                                  ? 0.0
                                  : () {
                                      if (phaseT < 0.18) {
                                        final double appearT = (phaseT / 0.18).clamp(0.0, 1.0);
                                        return Curves.easeOut.transform(appearT).clamp(0.0, 1.0);
                                      }
                                      final double decayT = ((phaseT - 0.18) / 0.82).clamp(0.0, 1.0);
                                      // Gentle decay shape preserved; only affects variance energy, never baseline.
                                      final double base = 1.0 - decayT;
                                      return (pow(base, 0.65) as double).clamp(0.0, 1.0);
                                    }()
                              : 0.0;

                          final double opacity = animatedVariance
                              ? (lerpDouble(settledOpacity, peakOpacity, variance) ?? settledOpacity)
                              : settledOpacity;

                          return CustomPaint(
                            painter: _AtmosphericFieldPainter(
                              time: _tidelineTime,
                              variance: variance,
                              opacity: opacity,
                              reduceMotion: _reduceMotion,
                              cyclesHint: _samplingMotionCycles,
                              baselineColor: baselineColor,
                              varianceColor: varianceColor,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
              // Step 4E — Tideline (behind UI, bottom anchored)
              Positioned(
                left: 0,
                right: 0,
                bottom: -(tidelineHeight * 0.18), // slight crop (horizon effect)
                height: tidelineHeight,
                child: IgnorePointer(
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 320),
                    curve: Curves.easeOut,
                    // Ensure atmosphere remains legible during sampling; restore after.
                    opacity: isReadingActive ? 0.82 : 1.0,
                    child: AnimatedBuilder(
                      animation: Listenable.merge([tidelineController, tidelineGate]),
                      builder: (_, __) {
                        // Smooth discrete `tidelineSettled` steps to avoid any visible snapping
                        // when observation/settling state changes.
                        return TweenAnimationBuilder<double>(
                      // Slower, softer convergence so “new settled value” arrives gently.
                      duration: const Duration(milliseconds: 3000),
                      curve: Curves.easeInOut,
                      // IMPORTANT: do not reset `begin` to 0 on rebuild; that creates a visible “jump”
                      // when settling progresses. With `begin` omitted, Flutter animates from the
                      // current animated value to the new `end` smoothly.
                      tween: Tween<double>(end: tidelineSettled),
                          builder: (context, settledVisual, _) {
                            return CustomPaint(
                              painter: _TidelinePainter(
                                palette: palette,
                                time: _tidelineWaveTime,
                                enabled: (primaryReadingRevealed || isSampling) && !_reduceMotion,
                                gate: tidelineGate.value,
                                settled: settledVisual,
                                reduceMotion: _reduceMotion,
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ),
              ),
              // Settings button (top-right)
              Positioned(
                top: 40,
                right: 16,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: IconButton(
                    visualDensity: VisualDensity.compact,
                    iconSize: 18,
                    onPressed: () {
                      // Directly open the settings modal (now contains sound controls)
                      showModalBottomSheet(
                        context: context,
                        backgroundColor: const Color(0xFFFAF8F0),
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
                        ),
                        builder: (_) => this.buildSettingsModal(context),
                      );
                    },
                    icon: Icon(
                      Icons.settings,
                      color: const Color(0xFF4A4A48).withOpacity(0.72),
                    ),
                  ),
                ),
              ),
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Opacity(
                      opacity: 0.9,
                      child: Text(
                        '🍀 Today’s Luck Index',
                        style: TextStyle(
                          fontWeight: FontWeight.w400,
                          fontSize: 20, // Micro bump for balance if needed
                          color: Color(0xFF4A4A48),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Keep layout stable: reserve space always, only opacity changes.
                    SizedBox(
                      height: 72, // Increased from 68 to match new lineHeight
                      child: Center(
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 260),
                          curve: Curves.easeOut,
                          // Prevent the *first* reveal from appearing while the primary action
                          // is still in its "Settling…" state.
                          opacity: primaryReadingRevealed
                              ? ((_readingWasRevealedAtSamplingStart || !isSampling) ? 1.0 : 0.0)
                              : 0.0,
                          onEnd: _onLuckIndexRevealed,
                          child: Text(
                            '${luckIndex.toStringAsFixed(2)}%',
                            style: TextStyle(
                              fontSize: 56,
                              fontWeight: FontWeight.w400, // back to regular
                              color: Color(0xCC3C362E),   // Warm, muted dark (80% opacity)
                              letterSpacing: 0.6,         // Gentle tracking
                              height: 1.22, // Increased line height for better glyph seating
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Move reflection lower away from the Luck Index readout.
                    const SizedBox(height: 32),
                    SizedBox(
                      height: _meaningBlockHeight(context),
                      child: AnimatedOpacity(
                        opacity: _showReflection ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 260),
                        curve: Curves.easeOut,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 250),
                            switchInCurve: Curves.easeOut,
                            switchOutCurve: Curves.easeOut,
                            transitionBuilder: (child, anim) =>
                                FadeTransition(opacity: anim, child: child),
                            child: (primaryReadingRevealed && (dailyReflection != null || isDayComplete))
                                ? Text(
                              isDayComplete ? holdTheDayTextForToday : dailyReflection!,
                              key: ValueKey<String>(
                                isDayComplete ? 'hold_${holdTheDayVariantId ?? 0}' : 'reflection',
                              ),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 18,
                                color: Color(0xFF474442),
                                height: 1.6,
                                letterSpacing: 0.4,
                                fontWeight: FontWeight.w500,
                              ),
                            )
                                : const SizedBox.shrink(key: ValueKey<String>('secondary_empty')),

                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                    // Keep the primary button visually steady; the atmospheric system is the star.
                    // When the label becomes "This is enough for today.", fade to the same opacity
                    // as the exhausted CTA pill (closure tone without a color shift).
                    AnimatedOpacity(
                      duration: const Duration(milliseconds: 450),
                      curve: Curves.easeOut,
                      // Only dim once sampling has resolved, so the change lands with the number update.
                      opacity: (!isSampling && isEnoughLabel) ? 0.50 : 1.0,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth: 280, // Constrain width (not full screen)
                        ),
                        child: GestureDetector(
                          // Deliberate decline (no extra copy): press-and-hold only (slightly longer than default).
                          onTapDown: (!isSampling &&
                                  !canAffordObservation &&
                                  showCta &&
                                  !adsExhausted &&
                                  !adsDeclinedToday)
                              ? (_) {
                                  _declineHoldTimer?.cancel();
                                  _declineHoldTimer = Timer(const Duration(milliseconds: 800), () {
                                    if (!mounted) return;
                                    _declineAdsAndCompleteDay();
                                  });
                                }
                              : null,
                          onTapUp: (_) {
                            _declineHoldTimer?.cancel();
                          },
                          onTapCancel: () {
                            _declineHoldTimer?.cancel();
                          },
                          child: ElevatedButton(
                            onPressed: isSampling || !canAffordObservation
                                ? null
                                : () {
                                    if (_soundMasterEnabled && _sfxEnabled) {
                                      unawaited(SoundManager.instance.playTap());
                                    }
                                    sampleAtmosphere();
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: palette['primaryButton'] ?? Color(0xFFA3D5D3),
                              foregroundColor: palette['primaryButtonText'] ?? Color(0xFF4A4A48),
                              disabledBackgroundColor: palette['primaryButton'] ?? Color(0xFFA3D5D3), // muted, no "pop"
                              disabledForegroundColor: const Color(0xCC4A4A48), // slightly muted text only
                              minimumSize: const Size(220, 48),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24),
                              ),
                              elevation: 1,
                              textStyle: const TextStyle(
                                fontSize: 16, // Increased from 15 for button text clarity
                                fontWeight: FontWeight.w400,
                                letterSpacing: 0.5,
                              ),
                            ),
                            child: Text(primaryLabel),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 32,
                      child: showCta
                          ? Opacity(
                              opacity: isDayComplete
                                  ? 0.43 // visually softer than disabled primary button
                                  : ctaOpacity,
                              child: TextButton(
                                onPressed: canShowAd && rewardedAd != null
                                    ? () {
                                        if (_soundMasterEnabled && _sfxEnabled) {
                                          unawaited(SoundManager.instance.playTap());
                                        }
                                        showRewardedAd();
                                      }
                                    : null,
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                ),
                                // Keep CTA visually steady; only opacity changes via `ctaOpacity`.
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    // Lighten CTA pill background for Forest and Autumn by alpha blending with atmosphere baseline
                                    color: () {
                                      final cta = (palette['ctaButton'] ?? Color(0xFFA3D5D3)).withOpacity(0.92);
                                      if ((kDebugMode ? _devThemeValue : _userThemeValue) == kThemeForest) {
                                        final base = Color(0xFFD2DAD4); // atmospheric baseline for Forest
                                        return Color.alphaBlend(base.withOpacity(0.45), cta);
                                      } else if ((kDebugMode ? _devThemeValue : _userThemeValue) == kThemeAutumn) {
                                        final base = Color(0xFFDED7CF); // atmospheric baseline for Autumn
                                        return Color.alphaBlend(base.withOpacity(0.45), cta);
                                      } else {
                                        return cta; // Ocean = reference
                                      }
                                    }(),
                                    borderRadius: BorderRadius.circular(20),
                                    // No border: monetization CTA should not have outline
                                  ),
                                  child: Text(
                                    'pause briefly',
                                    style: TextStyle(
                                      fontSize: 15,
                                      color: palette['primaryButtonText'] ?? Color(0xFF4A4A48),
                                      letterSpacing: 0.3,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                ),
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TidelinePainter extends CustomPainter {
  _TidelinePainter({
    required this.palette,
    required this.time,
    required this.enabled,
    required this.gate,
    required this.settled,
    required this.reduceMotion,
  });

  final Map<String, Color> palette;
  final double time; // continuous time accumulator (no snaps at repeat wrap)
  final bool enabled;
  final double gate; // 0..1, ramps motion in after anchor
  final bool reduceMotion;
  final double settled; // 0..1, higher = calmer

  @override
  void paint(Canvas canvas, Size size) {
    final topColor = this.palette['tidelineTop'] ?? Color(0x2E6FAFB3);
    final bottomColor = this.palette['tidelineBottom'] ?? Color(0x0F6FAFB3);
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [topColor, bottomColor],
      ).createShader(Offset.zero & size);

    // Before anchor or with reduced motion: static, no movement.
    final bool canMove = enabled && !reduceMotion;

    final double s = settled.clamp(0.0, 1.0);
    // Keep amplitude very small; this should never read as “waves”.
    // Increased initial amplitude for clearer lively waves early in the day
    final double ampBase = size.height * 0.18; // was 0.075; now visibly higher
    // Adjusted 'settled' decay curve: blend amplitude from lively to very calm, with a slower drop-off, noticeable for each additional settling step
    final double ampRaw = canMove
        ? lerpDouble(ampBase.toDouble(), (ampBase * 0.04).toDouble(), pow(s.toDouble(), 1.35).toDouble())! // decay slower, but finish soft
        : 0.0;
    // Gate ramps motion in gently at anchor completion (no visible “start”).
    final double g = gate.clamp(0.0, 1.0);
    final double gateEase = pow(g, 2.6).toDouble(); // stays near 0 longer (no “pop”)
    final double amp = ampRaw * gateEase;

    // Use a multi-frequency blend to avoid a “single looping wave” feel.
    final double t = (time * 2 * pi);
    final double y0 = size.height * 0.35;

    final path = Path()..moveTo(0, size.height);
    final int steps = 36;
    for (int i = 0; i <= steps; i++) {
      final double x = (i / steps) * size.width;
      final double xn = x / size.width;
      final double w1 = sin((xn * 2.0 * pi * 1.4) + t);
      final double w2 = sin((xn * 2.0 * pi * 2.3) + (t * 1.7) + 1.3);
      final double w3 = sin((xn * 2.0 * pi * 3.1) + (t * 2.2) + 2.1);
      // Normalize blend so peaks can't spike simply due to stacking.
      final double mix = (w1 + 0.55 * w2 + 0.25 * w3) / 1.8;
      final double y = y0 + amp * mix;
      path.lineTo(x, y);
    }
    path
      ..lineTo(size.width, size.height)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _TidelinePainter oldDelegate) {
    // Gate removed: tideline color must be a pure function of the active theme (palette),
    // so a theme change must trigger repaint even if animation/time hasn't advanced yet.
    return oldDelegate.palette != palette ||
        oldDelegate.time != time ||
        oldDelegate.enabled != enabled ||
        oldDelegate.gate != gate ||
        oldDelegate.reduceMotion != reduceMotion ||
        oldDelegate.settled != settled;
  }
}

class _AtmosphericFieldPainter extends CustomPainter {
  _AtmosphericFieldPainter({
    required this.time,
    required this.variance,
    required this.opacity,
    required this.reduceMotion,
    required this.cyclesHint,
    required this.baselineColor,
    required this.varianceColor,
  });

  final double time;
  final double variance; // 0..1, higher = more variance
  final double opacity; // 0..1
  final bool reduceMotion;
  final double cyclesHint; // preserves legacy motion-cycle math as a texture hint only
  final Color baselineColor;
  final Color varianceColor;

  // Deterministic, non-periodic noise helpers (no sine waves).
  static int _xorshift32(int x) {
    var v = x;
    v ^= (v << 13);
    v ^= (v >> 17);
    v ^= (v << 5);
    return v & 0x7fffffff;
  }

  static double _rand01(int seed) => _xorshift32(seed) / 0x7fffffff;

  static double _smoothStep(double t) => t * t * (3 - 2 * t);

  static Offset _randUnit2(int seed) {
    final x = _rand01(seed * 1103515245 + 12345) * 2 - 1;
    final y = _rand01(seed * 214013 + 2531011) * 2 - 1;
    return Offset(x, y);
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final double v = variance.clamp(0.0, 1.0);
    final double a = opacity.clamp(0.0, 1.0);

    // Irregular, non-cyclical drift/shimmer. No waves. No periodic beats.
    // We "step" a low-frequency noise field forward and interpolate between steps.
    // Calm presence phase should read as a persistent condition (near-static).
    final bool calmPresence = v <= 0.001;
    final double t = (reduceMotion || calmPresence) ? 0.0 : time;
    final double hint = cyclesHint.isFinite ? cyclesHint : 0.0; // only as a seed salt

    final paint = Paint()
      ..blendMode = BlendMode.srcOver
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16);

    // Use a small set of fixed "cells" across the canvas; jitter amplitude decays with calm.
    final List<Offset> anchors = [
      Offset(size.width * 0.18, size.height * 0.22),
      Offset(size.width * 0.72, size.height * 0.18),
      Offset(size.width * 0.36, size.height * 0.52),
      Offset(size.width * 0.82, size.height * 0.58),
      Offset(size.width * 0.22, size.height * 0.78),
      Offset(size.width * 0.62, size.height * 0.82),
      Offset(size.width * 0.48, size.height * 0.30),
      Offset(size.width * 0.12, size.height * 0.60),
      Offset(size.width * 0.88, size.height * 0.36),
    ];

    // Slightly larger structures so the field doesn't average to flat on light backgrounds.
    final double jitter = lerpDouble(0.0, 14.0, v)!;
    final double radiusBase = lerpDouble(175.0, 250.0, v)!;

    // Noise "clock" (irregular but smooth): about 0.6–0.9s per segment.
    final double rate = 1.25 + (hint * 0.0); // hint intentionally not used as frequency
    final double clock = t * rate;
    final int k0 = (reduceMotion || calmPresence) ? 0 : clock.floor();
    final double kf = (reduceMotion || calmPresence)
        ? 0.0
        : _smoothStep((clock - k0).clamp(0.0, 1.0));

    for (int i = 0; i < anchors.length; i++) {
      final int seedBase = (hint * 1000).round() ^ (i * 10007);
      final Offset d0 = _randUnit2(seedBase ^ (k0 * 7907));
      final Offset d1 = _randUnit2(seedBase ^ ((k0 + 1) * 7907));
      final Offset drift = Offset(
        lerpDouble(d0.dx, d1.dx, kf)!,
        lerpDouble(d0.dy, d1.dy, kf)!,
      );

      final double o0 = _rand01(seedBase ^ (k0 * 15485863));
      final double o1 = _rand01(seedBase ^ ((k0 + 1) * 15485863));
      final double turb = lerpDouble(o0, o1, kf)!; // 0..1

      final center = anchors[i] + drift * jitter;
      final r = radiusBase * (0.78 + 0.10 * turb);

      // Very subtle downward energy bias (more visual 'weight' at bottom).
      // Compute vertical position of anchor normalized from 0 (top) to 1 (bottom).
      final double normalizedY = (center.dy / (size.height != 0 ? size.height : 1)).clamp(0.0, 1.0);
      final double downwardBias = 0.93 + 0.07 * pow(normalizedY, 2); // 1.0 at bottom, ~0.93 at top, continuous/quadratic

      // Baseline → variance blend based on variance amplitude (no saturation spikes).
      paint.color = Color.lerp(this.baselineColor, this.varianceColor, v.clamp(0.0, 1.0))!
          .withOpacity(a * downwardBias * (0.58 + 0.30 * turb));
      canvas.drawCircle(center, r, paint);
    }

    // Grain shimmer: tiny, soft specks whose opacity gently turbulates during sampling variance.
    // Deterministic positions, interpolated alpha (no flicker, no rhythm).
    if (!reduceMotion && v > 0.0) {
      final speckPaint = Paint()..blendMode = BlendMode.srcOver;
      const int specks = 22;
      for (int s = 0; s < specks; s++) {
        final int seed = (hint * 1000).round() ^ (s * 31337);
        final double x = _rand01(seed ^ 0xA53A) * size.width;
        final double y = _rand01(seed ^ 0xC0FFEE) * size.height;

        final double a0 = _rand01(seed ^ (k0 * 2654435761));
        final double a1 = _rand01(seed ^ ((k0 + 1) * 2654435761));
        final double shimmer = lerpDouble(a0, a1, kf)!;

        // Keep specks extremely subtle; only perceptible during sampling.
        final double alpha = (a * 0.10) * v * (0.35 + 0.45 * shimmer);
        final double r = 0.7 + 1.1 * shimmer;

        speckPaint.color = const Color(0xFF4A4A48).withOpacity(alpha);
        canvas.drawCircle(Offset(x, y), r, speckPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _AtmosphericFieldPainter oldDelegate) {
    return oldDelegate.time != time ||
        oldDelegate.variance != variance ||
        oldDelegate.opacity != opacity ||
        oldDelegate.reduceMotion != reduceMotion ||
        oldDelegate.cyclesHint != cyclesHint ||
        oldDelegate.baselineColor != baselineColor ||
        oldDelegate.varianceColor != varianceColor;
  }
}

/*
========================================
File: lib/main.dart
Version: v3.10.4
Status: STEP 2 — PROGRESSIVE SETTLING + TRANSPARENT CTA AFTER ADS

- First post-primary observation is noticeably calmer
- Velocity settles progressively across the day
- Distance settling retained
- CTA remains visible after ads are exhausted
- CTA becomes transparent (opacity 0.6) and disabled
- Copy unchanged
- No truncation
- No silent drops
- No new state
- No refactors
========================================
*/
