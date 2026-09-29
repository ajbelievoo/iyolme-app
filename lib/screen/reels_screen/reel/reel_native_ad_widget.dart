import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shortzz/common/service/admob_native_service.dart';
import 'package:shortzz/utilities/theme_res.dart';

/// Instagram-style AdMob Native Ad widget for reels feed
class ReelNativeAdWidget extends StatefulWidget {
  final int adIndex;
  final double height;

  const ReelNativeAdWidget({
    super.key,
    required this.adIndex,
    this.height = 600.0,
  });

  @override
  State<ReelNativeAdWidget> createState() => _ReelNativeAdWidgetState();
}

class _ReelNativeAdWidgetState extends State<ReelNativeAdWidget> {
  NativeAd? _nativeAd;
  bool _isLoading = true;
  bool _hasError = false;
  final AdMobNativeService _adService = AdMobNativeService.instance;

  @override
  void initState() {
    super.initState();
    _loadAd();
  }

  // Retry loading ad with delay
  void _retryLoadAdWithDelay() {
    log('[ReelNativeAdWidget] Scheduling retry for index ${widget.adIndex} in 2 seconds');
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _hasError = false;
          _isLoading = true;
        });
        _loadAd();
      }
    });
  }

  Future<void> _loadAd() async {
    log('[ReelNativeAdWidget] Starting _loadAd for index ${widget.adIndex}');
    try {
      // Check if already cached
      final cachedAd = _adService.getCachedAd(widget.adIndex);
      log('[ReelNativeAdWidget] Cached ad check: ${cachedAd != null ? "FOUND" : "NOT FOUND"}');
      if (cachedAd != null) {
        setState(() {
          _nativeAd = cachedAd;
          _isLoading = false;
        });
        return;
      }

      log('[ReelNativeAdWidget] Calling loadNativeAd for index ${widget.adIndex}');
      // Load new ad
      final ad = await _adService.loadNativeAd(
        widget.adIndex,
        onLoaded: (loadedAd) {
          log('[ReelNativeAdWidget] onLoaded callback for index ${widget.adIndex}');
          if (mounted) {
            setState(() {
              _nativeAd = loadedAd;
              _isLoading = false;
            });
          }
        },
        onFailed: () {
          log('[ReelNativeAdWidget] onFailed callback for index ${widget.adIndex}');
          if (mounted) {
            setState(() {
              _hasError = true;
              _isLoading = false;
            });
            // Auto-retry after 2 seconds
            _retryLoadAdWithDelay();
          }
        },
      );

      log('[ReelNativeAdWidget] loadNativeAd returned: ${ad != null ? "ad object" : "null"}');
      if (ad == null && mounted) {
        log('[ReelNativeAdWidget] Ad is null, setting error state');
        setState(() {
          _hasError = true;
          _isLoading = false;
        });
      }
    } catch (e, stackTrace) {
      log('[ReelNativeAdWidget] Error loading ad: $e');
      log('[ReelNativeAdWidget] Stack trace: $stackTrace');
      if (mounted) {
        setState(() {
          _hasError = true;
          _isLoading = false;
        });
        // Auto-retry after error
        _retryLoadAdWithDelay();
      }
    }
  }

  @override
  void dispose() {
    // Don't dispose the ad here as it might be cached and reused
    // The service will handle disposal when appropriate
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: widget.height,
      width: double.infinity,
      color: blackPure(context),
      child: _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    if (_isLoading) {
      return _buildLoadingState(context);
    }

    if (_hasError || _nativeAd == null) {
      return _buildErrorState(context);
    }

    return _buildAdContent(context);
  }

  Widget _buildLoadingState(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: 40,
          height: 40,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(
              whitePure(context).withValues(alpha: 0.6),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Loading...',
          style: TextStyle(
            color: whitePure(context).withValues(alpha: 0.6),
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildErrorState(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.hide_image_outlined,
          color: whitePure(context).withValues(alpha: 0.4),
          size: 48,
        ),
        const SizedBox(height: 12),
        Text(
          'Content unavailable',
          style: TextStyle(
            color: whitePure(context).withValues(alpha: 0.5),
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildAdContent(BuildContext context) {
    // FIXED: Properly constrained layout to prevent assets outside ad view
    return Column(
      children: [
        // Sponsored label at top
        Padding(
          padding: const EdgeInsets.only(left: 16, right: 16, top: 80, bottom: 8),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.verified,
                      size: 12,
                      color: whitePure(context),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Sponsored',
                      style: TextStyle(
                        color: whitePure(context),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        
        // Ad content - FIXED: Bounded container to keep assets within view
        Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            constraints: BoxConstraints(
              maxHeight: widget.height * 0.6,
              maxWidth: MediaQuery.of(context).size.width - 32,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: _nativeAd != null ? AdWidget(ad: _nativeAd!) : const SizedBox.shrink(),
            ),
          ),
        ),
        
        // Bottom spacing
        const SizedBox(height: 100),
      ],
    );
  }
}

/// Simplified inline native ad for feed items
class InlineNativeAd extends StatefulWidget {
  final int adIndex;
  final double? height;

  const InlineNativeAd({
    super.key,
    required this.adIndex,
    this.height,
  });

  @override
  State<InlineNativeAd> createState() => _InlineNativeAdState();
}

class _InlineNativeAdState extends State<InlineNativeAd> {
  NativeAd? _nativeAd;
  bool _isLoading = true;
  bool _hasError = false;
  final AdMobNativeService _adService = AdMobNativeService.instance;

  @override
  void initState() {
    super.initState();
    _loadAd();
  }

  Future<void> _loadAd() async {
    try {
      final cachedAd = _adService.getCachedAd(widget.adIndex);
      if (cachedAd != null) {
        setState(() {
          _nativeAd = cachedAd;
          _isLoading = false;
        });
        return;
      }

      final ad = await _adService.loadNativeAd(
        widget.adIndex,
        onLoaded: (loadedAd) {
          if (mounted) {
            setState(() {
              _nativeAd = loadedAd;
              _isLoading = false;
            });
          }
        },
        onFailed: () {
          if (mounted) {
            setState(() {
              _hasError = true;
              _isLoading = false;
            });
          }
        },
      );

      if (ad == null && mounted) {
        setState(() {
          _hasError = true;
          _isLoading = false;
        });
      }
    } catch (e) {
      log('[InlineNativeAd] Error loading ad: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: widget.height ?? 350,
      width: double.infinity,
      color: Theme.of(context).scaffoldBackgroundColor,
      child: _buildContent(),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    if (_hasError || _nativeAd == null) {
      return const SizedBox.shrink();
    }

    return Stack(
      children: [
        AdWidget(ad: _nativeAd!),
        Positioned(
          top: 8,
          right: 8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.grey[800],
              borderRadius: BorderRadius.circular(3),
            ),
            child: const Text(
              'Ad',
              style: TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
