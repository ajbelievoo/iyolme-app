import 'package:flutter/material.dart';
import 'package:shortzz/common/controller/base_controller.dart';
import 'package:shortzz/screen/ads_manager/data/ads_repository.dart';
import 'package:shortzz/utilities/theme_res.dart';

class BoostPostBottomSheet extends StatefulWidget {
  const BoostPostBottomSheet({
    super.key,
    this.postId,
    required this.initialDailyBudget,
    required this.initialTotalBudget,
    required this.onBoostNow,
  });

  final int? postId;
  final num initialDailyBudget;
  final num initialTotalBudget;
  final void Function(num dailyBudget, num totalBudget) onBoostNow;

  @override
  State<BoostPostBottomSheet> createState() => _BoostPostBottomSheetState();
}

class _BoostPostBottomSheetState extends State<BoostPostBottomSheet> {
  late final TextEditingController _dailyController;
  late final TextEditingController _totalController;

  final AdsManagerRepository _repo = AdsManagerRepository();
  bool _loadingSuggestion = false;

  @override
  void initState() {
    super.initState();
    _dailyController =
        TextEditingController(text: widget.initialDailyBudget.toString());
    _totalController =
        TextEditingController(text: widget.initialTotalBudget.toString());

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _fetchSuggestedBudgetIfNeeded();
    });
  }

  Future<void> _fetchSuggestedBudgetIfNeeded() async {
    final postId = widget.postId;
    if (postId == null || postId <= 0) return;
    if (_loadingSuggestion) return;

    setState(() {
      _loadingSuggestion = true;
    });

    try {
      final suggested = await _repo.fetchBoostSuggestedBudget(postId: postId);
      if (!mounted) return;
      final value = suggested.suggestedBudget;
      if (value > 0) {
        final currentDaily = num.tryParse(_dailyController.text.trim()) ?? 0;
        final currentTotal = num.tryParse(_totalController.text.trim()) ?? 0;
        if (currentDaily <= 0) {
          _dailyController.text = value.toString();
        }
        if (currentTotal <= 0) {
          _totalController.text = value.toString();
        }
      }
    } catch (_) {
      // Keep initial values if suggestion fails.
    } finally {
      if (mounted) {
        setState(() {
          _loadingSuggestion = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _dailyController.dispose();
    _totalController.dispose();
    super.dispose();
  }

  void _submit() {
    final daily = num.tryParse(_dailyController.text.trim()) ?? 0;
    final total = num.tryParse(_totalController.text.trim()) ?? 0;

    if (daily <= 0 || total <= 0) {
      BaseController.share.showSnackBar('Please enter valid budgets');
      return;
    }

    Navigator.of(context).maybePop();
    widget.onBoostNow(daily, total);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 12,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Quick budget',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: textDarkGrey(context),
                      fontSize: 16,
                    ),
                  ),
                ),
                if (_loadingSuggestion)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: textLightGrey(context),
                      ),
                    ),
                  ),
                IconButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: Icon(Icons.close, color: textDarkGrey(context)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _dailyController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Daily budget',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _totalController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Total budget',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 52,
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _submit,
                icon: const Icon(Icons.bolt_outlined),
                label: const Text(
                  'Boost Now',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
