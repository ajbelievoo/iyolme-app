import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shortzz/common/service/api/user_ads_service.dart';
import 'package:shortzz/model/ads/ad_estimate.dart';
import 'package:shortzz/model/general/location_place_model.dart';
import 'package:shortzz/screen/create_feed_screen/widget/location_sheet.dart';
import 'package:shortzz/model/general/status_model.dart';
import 'package:shortzz/utilities/theme_res.dart';

import 'package:shortzz/screen/ads_manager/widget/ads_line_chart_placeholder.dart';

class CreateAdRequestScreen extends StatefulWidget {
  const CreateAdRequestScreen({super.key});

  @override
  State<CreateAdRequestScreen> createState() => _CreateAdRequestScreenState();
}

class _CreateAdRequestScreenState extends State<CreateAdRequestScreen> {
  final _title = TextEditingController();
  final _subtitle = TextEditingController();
  final _destinationUrl = TextEditingController();
  final _cta = TextEditingController(text: 'Learn More');
  final _mediaUrl = TextEditingController();
  final _budget = TextEditingController();
  final _days = TextEditingController(text: '7');
  final _keywords = TextEditingController();
  final _location = TextEditingController();
  Places? _selectedPlace;

  String _placement = 'feed';
  String _billing = 'cpc';
  String _mediaType = 'image';
  bool _loading = false;
  
  // Stepper state
  int _currentStep = 0;
  
  // Estimate state
  Timer? _debounce;
  bool _fetchingEstimate = false;
  AdEstimateData? _estimateData;

  @override
  void initState() {
    super.initState();
    _budget.addListener(_onInputChanged);
    _days.addListener(_onInputChanged);
  }

  void _onInputChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), _fetchEstimate);
  }

  Future<void> _fetchEstimate() async {
    final budget = double.tryParse(_budget.text.trim());
    final days = int.tryParse(_days.text.trim());
    
    if (budget == null || days == null || budget <= 0 || days <= 0) {
      setState(() => _estimateData = null);
      return;
    }

    setState(() => _fetchingEstimate = true);
    
    try {
      final res = await UserAdsService.instance.getEstimate(
        budget: budget,
        durationHours: days * 24,
        placement: _placement,
        billing: _billing,
      );
      if (mounted) {
        setState(() => _estimateData = res.data);
      }
    } catch (_) {
    } finally {
      if (mounted) {
        setState(() => _fetchingEstimate = false);
      }
    }
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

  void _closeScreen() {
    final ctx = Get.overlayContext ?? context;
    Navigator.of(ctx).maybePop();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _title.dispose();
    _subtitle.dispose();
    _destinationUrl.dispose();
    _cta.dispose();
    _mediaUrl.dispose();
    _budget.dispose();
    _days.dispose();
    _keywords.dispose();
    _location.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_loading) return;

    final title = _title.text.trim();
    final destinationUrl = _destinationUrl.text.trim();
    final cta = _cta.text.trim();
    final mediaPath = _mediaUrl.text.trim();

    final budget = num.tryParse(_budget.text.trim());
    final days = int.tryParse(_days.text.trim());

    if (title.isEmpty) {
      _showMessage('Title required');
      return;
    }
    if (mediaPath.isEmpty) {
      _showMessage('Media path required');
      return;
    }
    if (budget == null || budget <= 0) {
      _showMessage('Budget sahi daalo');
      return;
    }
    if (days == null || days <= 0) {
      _showMessage('Days sahi daalo');
      return;
    }

    setState(() {
      _loading = true;
    });
    final durationHours = days * 24;

    StatusModel res;
    try {
      res = await UserAdsService.instance.createUserAdRequest(
        placement: _placement,
        title: title,
        description: _subtitle.text.trim(),
        mediaPath: mediaPath,
        mediaType: _mediaType,
        billing: _billing,
        budget: budget.toDouble(),
        durationHours: durationHours,
        ctaUrl: destinationUrl.isEmpty ? null : destinationUrl,
        keywords: _keywords.text.trim(),
        metadataJson: jsonEncode({
          'source': 'client',
          'targeting': {
            'keywords': _keywords.text.trim(),
            'location': _selectedPlace?.placeTitle ?? _location.text.trim(),
            if (_selectedPlace != null) 'place_title': _selectedPlace?.placeTitle,
            if ((_selectedPlace?.location?.latitude ?? 0) != 0)
              'place_lat': _selectedPlace?.location?.latitude,
            if ((_selectedPlace?.location?.longitude ?? 0) != 0)
              'place_lon': _selectedPlace?.location?.longitude,
          },
          'cta': cta,
        }),
      );
    } catch (e) {
      setState(() {
        _loading = false;
      });
      _showMessage('Create ad request fail: $e');
      return;
    }

    setState(() {
      _loading = false;
    });

    if (res.status == true) {
      _closeScreen();
      _showMessage(res.message ?? 'Ad request sent');
    } else {
      _showMessage(res.message ?? 'Ad request failed');
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: scaffoldBackgroundColor(context),
      appBar: AppBar(
        backgroundColor: scaffoldBackgroundColor(context),
        foregroundColor: textDarkGrey(context),
        title: const Text('Create Campaign'),
      ),
      body: Stepper(
        type: StepperType.vertical,
        currentStep: _currentStep,
        onStepContinue: () {
          if (_currentStep < 5) {
            setState(() => _currentStep += 1);
          } else {
            _submit();
          }
        },
        onStepCancel: () {
          if (_currentStep > 0) {
            setState(() => _currentStep -= 1);
          }
        },
        onStepTapped: (step) {
          setState(() => _currentStep = step);
        },
        controlsBuilder: (context, details) {
          return Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _loading ? null : details.onStepContinue,
                    child: _loading && _currentStep == 5
                        ? SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: whitePure(context)),
                          )
                        : Text(_currentStep == 5 ? 'Pay & Submit' : 'Continue'),
                  ),
                ),
                if (_currentStep > 0) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: details.onStepCancel,
                      child: const Text('Back'),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
        steps: [
          // Step 1: Details
          Step(
            title: const Text('Details'),
            isActive: _currentStep >= 0,
            state: _currentStep > 0 ? StepState.complete : StepState.indexed,
            content: Column(
              children: [
                TextField(
                  controller: _title,
                  decoration: const InputDecoration(labelText: 'Campaign Title'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _subtitle,
                  decoration: const InputDecoration(labelText: 'Description (optional)'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _cta,
                  decoration: const InputDecoration(labelText: 'Button Text (CTA)'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _destinationUrl,
                  decoration: const InputDecoration(labelText: 'Destination URL (optional)'),
                ),
              ],
            ),
          ),
          
          // Step 2: Media
          Step(
            title: const Text('Media'),
            isActive: _currentStep >= 1,
            state: _currentStep > 1 ? StepState.complete : StepState.indexed,
            content: Column(
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _mediaType,
                  decoration: const InputDecoration(labelText: 'Media Type'),
                  items: const [
                    DropdownMenuItem(value: 'image', child: Text('Image')),
                    DropdownMenuItem(value: 'video', child: Text('Video')),
                    DropdownMenuItem(value: 'reel', child: Text('Reel')),
                  ],
                  onChanged: (v) => setState(() => _mediaType = v ?? 'image'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _mediaUrl,
                  decoration: const InputDecoration(
                    labelText: 'Media Path / URL',
                    hintText: 'uploaded media path',
                  ),
                ),
              ],
            ),
          ),

          // Step 3: Placement
          Step(
            title: const Text('Placement'),
            isActive: _currentStep >= 2,
            state: _currentStep > 2 ? StepState.complete : StepState.indexed,
            content: DropdownButtonFormField<String>(
              initialValue: _placement,
              decoration: const InputDecoration(labelText: 'Ad Placement'),
              items: const [
                DropdownMenuItem(value: 'feed', child: Text('Feed')),
                DropdownMenuItem(value: 'reel', child: Text('Reel')),
                DropdownMenuItem(value: 'story', child: Text('Story')),
              ],
              onChanged: (v) => setState(() => _placement = v ?? 'feed'),
            ),
          ),

          // Step 4: Audience
          Step(
            title: const Text('Audience'),
            isActive: _currentStep >= 3,
            state: _currentStep > 3 ? StepState.complete : StepState.indexed,
            content: Column(
              children: [
                TextField(
                  controller: _keywords,
                  decoration: const InputDecoration(
                    labelText: 'Keywords (optional)',
                    hintText: 'e.g. food, travel, fashion',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _location,
                  readOnly: true,
                  onTap: () async {
                    await Get.bottomSheet(
                      LocationSheet(
                        onLocationTap: (place) {
                          setState(() {
                            _selectedPlace = place;
                            _location.text = place.placeTitle;
                          });
                        },
                      ),
                      isScrollControlled: true,
                    );
                  },
                  decoration: const InputDecoration(
                    labelText: 'Location (optional)',
                    hintText: 'Select target location',
                  ),
                ),
              ],
            ),
          ),

          // Step 5: Budget
          Step(
            title: const Text('Budget'),
            isActive: _currentStep >= 4,
            state: _currentStep > 4 ? StepState.complete : StepState.indexed,
            content: Column(
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _billing,
                  decoration: const InputDecoration(labelText: 'Billing Strategy'),
                  items: const [
                    DropdownMenuItem(value: 'cpc', child: Text('CPC (Cost Per Click)')),
                    DropdownMenuItem(value: 'cpm', child: Text('CPM (Cost Per Mille)')),
                  ],
                  onChanged: (v) => setState(() => _billing = v ?? 'cpc'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _budget,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Total Budget (Money)'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _days,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Duration (Days)'),
                ),
              ],
            ),
          ),

          // Step 6: Preview
          Step(
            title: const Text('Preview'),
            isActive: _currentStep >= 5,
            state: StepState.indexed,
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AdsLineChartPlaceholder(height: 180),
                const SizedBox(height: 16),
                if (_fetchingEstimate)
                  const Center(child: Text('Updating estimates...', style: TextStyle(color: Colors.grey)))
                else if (_estimateData != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.withValues(alpha: 0.2)),
                    ),
                    child: Column(
                      children: [
                        _buildEstimateRow('Est. Impressions', '${_estimateData?.estimatedImpressionsMin} - ${_estimateData?.estimatedImpressionsMax}'),
                        if (_estimateData?.estimatedCostEfficiency != null)
                          _buildEstimateRow('Cost Efficiency', '${_estimateData?.estimatedCostEfficiency}'),
                      ],
                    ),
                  )
                else
                   const Text('Enter valid budget to see estimates.', style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 16),
                const Divider(),
                _buildSummaryRow('Title', _title.text),
                _buildSummaryRow('Budget', '\$${_budget.text}'),
                _buildSummaryRow('Duration', '${_days.text} Days'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
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
