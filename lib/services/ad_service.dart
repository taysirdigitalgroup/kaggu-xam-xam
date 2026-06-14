// lib/services/ad_service.dart
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';

class AdService {
  InterstitialAd? _interstitialAd;
  bool _isInterstitialReady = false;

  void initialize() {
    MobileAds.instance.initialize();
    _loadInterstitial();
  }

  void _loadInterstitial() {
    InterstitialAd.load(
      adUnitId: AppConstants.interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _isInterstitialReady = true;
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _isInterstitialReady = false;
              _loadInterstitial(); // Précharger le suivant
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();
              _isInterstitialReady = false;
              _loadInterstitial();
            },
          );
        },
        onAdFailedToLoad: (_) {
          _isInterstitialReady = false;
        },
      ),
    );
  }

  /// Affiche l'interstitiel si prêt ET si le cooldown de 3min est passé
  Future<void> showInterstitialIfReady() async {
    final prefs = await SharedPreferences.getInstance();
    final lastMs = prefs.getInt(AppConstants.prefLastAdTime) ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    final elapsedSeconds = (now - lastMs) / 1000;

    if (lastMs == 0 || elapsedSeconds >= AppConstants.interstitialCooldownSeconds) {
      if (_isInterstitialReady && _interstitialAd != null) {
        await prefs.setInt(AppConstants.prefLastAdTime, now);
        await _interstitialAd!.show();
      }
    }
  }

  BannerAd createBannerAd() {
    return BannerAd(
      adUnitId: AppConstants.bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: const BannerAdListener(),
    )..load();
  }

  void dispose() {
    _interstitialAd?.dispose();
  }
}
