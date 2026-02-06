import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'storage_service.dart';
import '../utils/constants.dart';

/// Handles AdMob integration
class AdService {
  static final AdService _instance = AdService._internal();
  factory AdService() => _instance;
  AdService._internal();

  InterstitialAd? _interstitialAd;
  RewardedAd? _rewardedAd;
  
  int _levelsSinceLastAd = 0;
  bool _initialized = false;

  // Test ad unit IDs (replace with real ones for production)
  static const String _interstitialAdUnitId = 
      'ca-app-pub-3940256099942544/1033173712'; // Test ID
  static const String _rewardedAdUnitId = 
      'ca-app-pub-3940256099942544/5224354917'; // Test ID

  /// Initialize the ad service
  Future<void> init() async {
    if (_initialized) return;
    
    await MobileAds.instance.initialize();
    _initialized = true;
    
    // Pre-load ads
    _loadInterstitialAd();
    _loadRewardedAd();
  }

  /// Check if ads should be shown (not removed via IAP)
  bool get shouldShowAds {
    return !StorageService().getAdsRemoved();
  }

  /// Load an interstitial ad
  void _loadInterstitialAd() {
    if (!shouldShowAds) return;
    
    InterstitialAd.load(
      adUnitId: _interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _loadInterstitialAd(); // Pre-load next
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();
              _loadInterstitialAd();
            },
          );
        },
        onAdFailedToLoad: (error) {
          debugPrint('Interstitial ad failed to load: $error');
        },
      ),
    );
  }

  /// Load a rewarded ad
  void _loadRewardedAd() {
    RewardedAd.load(
      adUnitId: _rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _loadRewardedAd(); // Pre-load next
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();
              _loadRewardedAd();
            },
          );
        },
        onAdFailedToLoad: (error) {
          debugPrint('Rewarded ad failed to load: $error');
        },
      ),
    );
  }

  /// Called when a level is completed
  void onLevelComplete() {
    _levelsSinceLastAd++;
  }

  /// Check if an interstitial should be shown
  bool shouldShowInterstitial() {
    if (!shouldShowAds) return false;
    return _levelsSinceLastAd >= GameConfig.adsEveryNLevels;
  }

  /// Show interstitial ad if ready
  Future<void> showInterstitialIfReady() async {
    if (!shouldShowInterstitial()) return;
    
    if (_interstitialAd != null) {
      await _interstitialAd!.show();
      _levelsSinceLastAd = 0;
    }
  }

  /// Check if rewarded ad is ready
  bool isRewardedAdReady() {
    return _rewardedAd != null;
  }

  /// Show rewarded ad and return true if reward earned
  Future<bool> showRewardedAd() async {
    if (_rewardedAd == null) {
      debugPrint('Rewarded ad not ready');
      return false;
    }

    bool rewardEarned = false;
    
    await _rewardedAd!.show(
      onUserEarnedReward: (ad, reward) {
        rewardEarned = true;
        debugPrint('User earned reward: ${reward.amount} ${reward.type}');
      },
    );

    return rewardEarned;
  }

  /// Dispose ads
  void dispose() {
    _interstitialAd?.dispose();
    _rewardedAd?.dispose();
  }
}
