import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shortzz/common/service/api/boost_service.dart';
import 'package:shortzz/model/boost/boost_estimate.dart';
import 'package:shortzz/model/general/location_place_model.dart';
import 'package:shortzz/screen/create_feed_screen/widget/location_sheet.dart';
import 'package:shortzz/model/general/status_model.dart';
import 'package:shortzz/utilities/theme_res.dart';

import 'package:shortzz/screen/ads_manager/widget/ads_line_chart_placeholder.dart';

class BoostPostSheet extends StatefulWidget {
  final int postId;
  final String placement;

  const BoostPostSheet({
    super.key,
    required this.postId,
    this.placement = 'feed',
  });

  @override
  State<BoostPostSheet> createState() => _BoostPostSheetState();
}

class _BoostPostSheetState extends State<BoostPostSheet> {
  final PageController _pageController = PageController();
  int _currentStep = 0;
  final int _totalSteps = 3;

  final TextEditingController _budgetController = TextEditingController();
  final TextEditingController _daysController = TextEditingController(text: '3');
  final TextEditingController _keywordsController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  String _audience = 'auto';
  bool _isLoading = false;
  Places? _selectedPlace;
  
  // Estimate logic
  Timer? _debounce;
  bool _fetchingEstimate = false;
  BoostEstimateData? _estimateData;

  @override
  void initState() {
    super.initState();
    _budgetController.addListener(_onInputChanged);
    _daysController.addListener(_onInputChanged);
  }

  void _onInputChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), _fetchEstimate);
  }

  Future<void> _fetchEstimate() async {
    final budget = int.tryParse(_budgetController.text.trim());
    final days = int.tryParse(_daysController.text.trim());
    
    if (budget == null || days == null || budget <= 0 || days <= 0) {
      setState(() => _estimateData = null);
      return;
    }

    setState(() => _fetchingEstimate = true);
    
    try {
      final res = await BoostService.instance.getEstimate(
        budgetCoins: budget,
        durationHours: days * 24,
        placement: widget.placement,
      );
      if (mounted) {
        setState(() => _estimateData = res.data);
      }
    } catch (_) {
      // ignore errors silently for preview
    } finally {
      if (mounted) {
        setState(() => _fetchingEstimate = false);
      }
    }
  }

  void _closeSheet() {
    final ctx = Get.overlayContext ?? context;
    Navigator.of(ctx).maybePop();
  }

  void _showMessage(String message) {
    final messengerContext = Get.key.currentContext ?? context;
    final messenger = ScaffoldMessenger.maybeOf(messengerContext);
    if (messenger == null) {
      return;
    }
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
        ),
      );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _pageController.dispose();
    _budgetController.dispose();
    _daysController.dispose();
    _keywordsController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isLoading) return;

    final budget = num.tryParse(_budgetController.text.trim());
    final days = int.tryParse(_daysController.text.trim());

    if (budget == null || budget <= 0) {
      _showMessage('Budget sahi daalo');
      return;
    }
    if (days == null || days <= 0) {
      _showMessage('Days sahi daalo');
      return;
    }

    setState(() {
      _isLoading = true;
    });
    final durationHours = days * 24;

    StatusModel res;
    try {
      res = await BoostService.instance.createBoostRequest(
        postId: widget.postId,
        budgetCoins: budget.round(),
        durationHours: durationHours,
        placement: widget.placement,
        title: 'Boosted post',
        metadataJson: jsonEncode({
          'days': days,
          'source': 'client',
          'targeting': {
            'audience': _audience,
            'keywords': _keywordsController.text.trim(),
            'location': _selectedPlace?.placeTitle ?? _locationController.text.trim(),
            if (_selectedPlace != null) 'place_title': _selectedPlace?.placeTitle,
            if ((_selectedPlace?.location?.latitude ?? 0) != 0)
              'place_lat': _selectedPlace?.location?.latitude,
            if ((_selectedPlace?.location?.longitude ?? 0) != 0)
              'place_lon': _selectedPlace?.location?.longitude,
          },
        }),
      );
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showMessage('Boost request fail: $e');
      return;
    }

    setState(() {
      _isLoading = false;
    });

    if (res.status == true) {
      _closeSheet();
      _showMessage(res.message ?? 'Boost request sent');
    } else {
      _showMessage(res.message ?? 'Boost request failed');
    }
  }

  Widget _buildEstimateRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey)),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  void _nextStep() {
    if (_currentStep < _totalSteps - 1) {
      _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
      setState(() => _currentStep++);
    } else {
      _submit();
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
      setState(() => _currentStep--);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        height: MediaQuery.of(context).size.height * 0.85, // Taller sheet
        decoration: BoxDecoration(
          color: scaffoldBackgroundColor(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  if (_currentStep > 0)
                    InkWell(
                      onTap: _prevStep,
                      child: Icon(Icons.arrow_back, color: textDarkGrey(context)),
                    )
                  else
                    const SizedBox(width: 24),
                  Expanded(
                    child: Center(
                      child: Text(
                        _getStepTitle(),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: textDarkGrey(context),
                        ),
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: _closeSheet,
                    child: Icon(Icons.close, color: textDarkGrey(context)),
                  ),
                ],
              ),
            ),
            // Progress Bar
            LinearProgressIndicator(
              value: (_currentStep + 1) / _totalSteps,
              backgroundColor: Colors.grey.withValues(alpha: 0.2),
              valueColor: AlwaysStoppedAnimation<Color>(themeAccentSolid(context)),
            ),
            
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildStep1Audience(),
                  _buildStep2Budget(),
                  _buildStep3Review(),
                ],
              ),
            ),
            
            // Bottom Action
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _nextStep,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: _isLoading
                      ? SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: whitePure(context)),
                        )
                      : Text(_currentStep == _totalSteps - 1 ? 'Pay & Boost' : 'Next'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getStepTitle() {
    switch (_currentStep) {
      case 0: return 'Target Audience';
      case 1: return 'Budget & Duration';
      case 2: return 'Review';
      default: return 'Boost Post';
    }
  }

  Widget _buildStep1Audience() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        DropdownButtonFormField<String>(
          key: ValueKey('audience_$_audience'),
          initialValue: _audience,
          decoration: const InputDecoration(labelText: 'Audience Type'),
          items: const [
            DropdownMenuItem(value: 'auto', child: Text('Automatic (Recommended)')),
            DropdownMenuItem(value: 'local', child: Text('Local / Nearby')),
            DropdownMenuItem(value: 'global', child: Text('Global')),
          ],
          onChanged: (v) => setState(() => _audience = v ?? 'auto'),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _keywordsController,
          decoration: const InputDecoration(
            labelText: 'Interests / Keywords',
            hintText: 'e.g. food, travel, fashion',
            helperText: 'Leave empty for automatic targeting based on post content.',
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _locationController,
          readOnly: true,
          onTap: () async {
            await Get.bottomSheet(
              LocationSheet(
                onLocationTap: (place) {
                  setState(() {
                    _selectedPlace = place;
                    _locationController.text = place.placeTitle;
                  });
                },
              ),
              isScrollControlled: true,
            );
          },
          decoration: const InputDecoration(
            labelText: 'Target Location',
            hintText: 'Select city or region',
            suffixIcon: Icon(Icons.location_on),
          ),
        ),
      ],
    );
  }

  Widget _buildStep2Budget() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          controller: _budgetController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Total Budget (Coins)',
            suffixText: 'Coins',
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _daysController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Duration (Days)',
            suffixText: 'Days',
          ),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.amber.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline, color: Colors.amber),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Higher budget helps reach more people. Coins will be deducted from your wallet immediately.',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStep3Review() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const AdsLineChartPlaceholder(height: 180),
        const SizedBox(height: 16),
        
        if (_fetchingEstimate)
           const Center(child: Padding(
             padding: EdgeInsets.all(16.0),
             child: Text('Calculating reach...', style: TextStyle(color: Colors.grey)),
           ))
        else if (_estimateData != null)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Estimated Results', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textDarkGrey(context))),
                const SizedBox(height: 8),
                _buildEstimateRow('Impressions', '${_estimateData?.estimatedImpressionsMin} - ${_estimateData?.estimatedImpressionsMax}'),
                _buildEstimateRow('Reach', '${_estimateData?.estimatedReachMin} - ${_estimateData?.estimatedReachMax}'),
                _buildEstimateRow('Clicks', '${_estimateData?.estimatedClicksMin} - ${_estimateData?.estimatedClicksMax}'),
              ],
            ),
          )
        else
           const Center(child: Text('Enter a valid budget to see estimates', style: TextStyle(color: Colors.grey))),

        const SizedBox(height: 24),
        const Divider(),
        const SizedBox(height: 8),
        Text('Summary', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textDarkGrey(context))),
        const SizedBox(height: 12),
        _buildSummaryRow('Budget', '${_budgetController.text} Coins'),
        _buildSummaryRow('Duration', '${_daysController.text} Days'),
        _buildSummaryRow('Targeting', _audience == 'auto' ? 'Automatic' : 'Custom'),
      ],
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
