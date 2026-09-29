import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shortzz/common/manager/ads_manager.dart';
import 'package:shortzz/common/manager/session_manager.dart';

class BannerAdsCustom extends StatefulWidget {
  final double? size;

  const BannerAdsCustom({super.key, this.size});

  @override
  State<BannerAdsCustom> createState() => _BannerAdsCustomState();
}

class _BannerAdsCustomState extends State<BannerAdsCustom> {
  BannerAd? bannerAd;

  @override
  void initState() {
    getBannerAds();
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
    bannerAd?.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Obx(
        () {
          final isPlus = SessionManager.instance.isPlusActive.value == 1;
          return !isPlus && bannerAd != null
              ? SafeArea(
                  top: false,
                  child: SizedBox(
                    width: bannerAd?.size.width.toDouble(),
                    height: bannerAd?.size.height.toDouble(),
                    child: AdWidget(ad: bannerAd!),
                  ),
                )
              : const SizedBox();
        },
      ),
    );
  }

  void getBannerAds() {
    if (SessionManager.instance.isPlusActive.value == 1) return;
    AdsManager.instance.loadBannerAd(onAdLoaded: (p0) {
      bannerAd = p0 as BannerAd;
      setState(() {});
    });
  }
}
