import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shortzz/common/service/api/user_service.dart';
import 'package:shortzz/common/manager/session_manager.dart';
import 'package:shortzz/screen/verification_screen/verification_in_review_screen.dart';
import 'package:shortzz/utilities/text_style_custom.dart';
import 'package:shortzz/utilities/theme_res.dart';

class VerificationDetailsFormScreen extends StatefulWidget {
  final String? planName;
  final int? subscriptionId;
  final String? paymentId;

  const VerificationDetailsFormScreen({
    super.key,
    this.planName,
    this.subscriptionId,
    this.paymentId,
  });

  @override
  State<VerificationDetailsFormScreen> createState() => _VerificationDetailsFormScreenState();
}

class _VerificationDetailsFormScreenState extends State<VerificationDetailsFormScreen> {
  final _fullNameCtrl = TextEditingController();
  final _docNumberCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  String _documentType = 'aadhaar';

  XFile? _front;
  XFile? _back;
  XFile? _selfie;

  bool _submitting = false;

  void _showSubmitError(String message) {
    if (!mounted) return;
    final msg = message.trim().isEmpty ? 'Submit failed. Please try again.' : message.trim();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  void dispose() {
    _fullNameCtrl.dispose();
    _docNumberCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage(Function(XFile?) setter, {required ImageSource source}) async {
    try {
      final picker = ImagePicker();
      final x = await picker.pickImage(source: source, imageQuality: 75);
      if (!mounted) return;
      setState(() {
        setter(x);
      });
    } catch (_) {
      if (!mounted) return;
      _showSubmitError('Image picker failed. Please try again.');
    }
  }

  Future<void> _submit() async {
    if (_submitting) return;

    final fullName = _fullNameCtrl.text.trim();
    final docNumber = _docNumberCtrl.text.trim();
    final address = _addressCtrl.text.trim();

    if (fullName.isEmpty || docNumber.isEmpty || address.isEmpty) {
      _showSubmitError('Please fill all required fields.');
      return;
    }

    final dt = _documentType.trim().toLowerCase();
    if (dt == 'aadhaar' || dt == 'aadhar') {
      if (_front == null || _back == null) {
        _showSubmitError('Please upload Aadhaar front and back images.');
        return;
      }
    } else if (dt == 'pan') {
      if (_front == null) {
        _showSubmitError('Please upload PAN card image.');
        return;
      }
    } else if (dt == 'passport') {
      if (_front == null) {
        _showSubmitError('Please upload Passport image.');
        return;
      }
    } else {
      if (_front == null) {
        _showSubmitError('Please upload document front image.');
        return;
      }
    }

    // Backend requires selfie_with_id.
    if (_selfie == null) {
      _showSubmitError('Please capture selfie with ID.');
      return;
    }

    setState(() {
      _submitting = true;
    });

    try {
      final res = await UserService.instance
          .submitVerificationRequestMultipart(
            fullName: fullName,
            documentType: _documentType,
            documentNumber: docNumber,
            address: address,
            reasonForVerification: 'subscription',
            accountCategory: 'individual',
            subscriptionId: widget.subscriptionId,
            subscriptionName: widget.planName,
            paymentId: widget.paymentId,
            documentFront: _front,
            documentBack: _back,
            selfie: _selfie,
          )
          .timeout(const Duration(seconds: 40));

      if (res.status != true) {
        throw Exception(res.message ?? 'submit failed');
      }

      final requestId = res.data?.requestId ?? 0;
      SessionManager.instance.setVerificationState(status: 0, requestId: requestId);
      Get.off(
        () => VerificationInReviewScreen(
          requestId: requestId > 0 ? requestId : null,
          planName: widget.planName,
        ),
      );
    } catch (e) {
      final msg = e.toString().replaceFirst('Exception: ', '').trim();
      _showSubmitError(msg);
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  Widget _fileTile({required String title, required XFile? file, required VoidCallback onPick}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: bgLightGrey(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: textLightGrey(context).withValues(alpha: .2)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyleCustom.outFitMedium500(color: textDarkGrey(context)),
                ),
                const SizedBox(height: 4),
                Text(
                  file?.name ?? 'Not selected',
                  style: TextStyleCustom.outFitRegular400(
                    fontSize: 12,
                    color: textLightGrey(context),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          TextButton(
            onPressed: _submitting ? null : onPick,
            child: Text(
              'Upload',
              style: TextStyleCustom.outFitMedium500(color: themeAccentSolid(context)),
            ),
          ),
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
        elevation: 0,
        title: Text(
          'Verification',
          style: TextStyleCustom.unboundedMedium500(color: textDarkGrey(context)),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if ((widget.planName ?? '').trim().isNotEmpty) ...[
                Text(
                  'Plan: ${widget.planName}',
                  style: TextStyleCustom.outFitRegular400(color: textLightGrey(context)),
                ),
                const SizedBox(height: 14),
              ],
              Text(
                'Enter details',
                style: TextStyleCustom.unboundedMedium500(
                  fontSize: 16,
                  color: textDarkGrey(context),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _fullNameCtrl,
                decoration: InputDecoration(
                  labelText: 'Full name',
                  filled: true,
                  fillColor: bgLightGrey(context),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: bgLightGrey(context),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: textLightGrey(context).withValues(alpha: .2)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _documentType,
                    isExpanded: true,
                    items: const [
                      DropdownMenuItem(value: 'aadhaar', child: Text('Aadhaar')),
                      DropdownMenuItem(value: 'pan', child: Text('PAN')),
                      DropdownMenuItem(value: 'passport', child: Text('Passport')),
                      DropdownMenuItem(value: 'driving_license', child: Text('Driving license')),
                    ],
                    onChanged: _submitting
                        ? null
                        : (v) {
                            if (v == null) return;
                            setState(() {
                              _documentType = v;
                            });
                          },
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _docNumberCtrl,
                decoration: InputDecoration(
                  labelText: 'Document number',
                  filled: true,
                  fillColor: bgLightGrey(context),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _addressCtrl,
                minLines: 2,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: 'Address',
                  filled: true,
                  fillColor: bgLightGrey(context),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Upload documents',
                style: TextStyleCustom.unboundedMedium500(
                  fontSize: 16,
                  color: textDarkGrey(context),
                ),
              ),
              const SizedBox(height: 10),
              _fileTile(
                title: 'Document front (required)',
                file: _front,
                onPick: () => _pickImage((x) => _front = x, source: ImageSource.gallery),
              ),
              const SizedBox(height: 10),
              _fileTile(
                title: 'Document back (optional)',
                file: _back,
                onPick: () => _pickImage((x) => _back = x, source: ImageSource.gallery),
              ),
              const SizedBox(height: 10),
              _fileTile(
                title: 'Selfie (optional)',
                file: _selfie,
                onPick: () => _pickImage((x) => _selfie = x, source: ImageSource.camera),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: themeAccentSolid(context),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _submitting
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(whitePure(context)),
                          ),
                        )
                      : Text(
                          'Submit',
                          style: TextStyleCustom.outFitMedium500(color: whitePure(context)),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
