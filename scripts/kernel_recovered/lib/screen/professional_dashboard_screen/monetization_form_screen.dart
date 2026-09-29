import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shortzz/common/controller/base_controller.dart';
import 'package:shortzz/common/controller/professional_controller.dart';
import 'package:shortzz/utilities/theme_res.dart';

class MonetizationFormScreen extends StatefulWidget {
  const MonetizationFormScreen({super.key, required this.controller});
  final ProfessionalController controller;

  @override
  State<MonetizationFormScreen> createState() => _MonetizationFormScreenState();
}

class _MonetizationFormScreenState extends State<MonetizationFormScreen> {
  final _formKey = GlobalKey<FormState>();

  final fullName = TextEditingController();
  final email = TextEditingController();
  final mobile = TextEditingController();
  final country = TextEditingController();
  DateTime? dob;
  final channelName = TextEditingController();
  final channelCategory = TextEditingController();
  final contentType = TextEditingController();
  final avgMonthlyViews = TextEditingController();
  final contentLanguage = TextEditingController();

  // Compliance checkboxes
  bool ownsContent = false;
  bool noCopyrightViolation = false;
  bool followsGuidelines = false;
  bool noFakeEngagement = false;

  // Payment
  String paymentMethod = 'upi';
  final upiId = TextEditingController();
  final bankAccountName = TextEditingController();
  final bankAccountNumber = TextEditingController();
  final bankIfsc = TextEditingController();
  final paypalEmail = TextEditingController();

  // Optional
  final panTaxId = TextEditingController();
  final addressForTax = TextEditingController();

  // Files
  XFile? idProof;
  XFile? addressProof;
  final _picker = ImagePicker();

  @override
  void dispose() {
    fullName.dispose();
    email.dispose();
    mobile.dispose();
    country.dispose();
    channelName.dispose();
    channelCategory.dispose();
    contentType.dispose();
    avgMonthlyViews.dispose();
    contentLanguage.dispose();
    upiId.dispose();
    bankAccountName.dispose();
    bankAccountNumber.dispose();
    bankIfsc.dispose();
    paypalEmail.dispose();
    panTaxId.dispose();
    addressForTax.dispose();
    super.dispose();
  }

  bool get isAdult {
    if (dob == null) return false;
    final now = DateTime.now();
    final eighteen = DateTime(now.year - 18, now.month, now.day);
    return dob!.isBefore(eighteen) || dob!.isAtSameMomentAs(eighteen);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (dob == null || !isAdult) {
      BaseController.share.showSnackBar('Please select a valid DOB (18+)');
      return;
    }
    if (!ownsContent || !noCopyrightViolation || !followsGuidelines || !noFakeEngagement) {
      BaseController.share.showSnackBar('Please accept all compliance checkboxes');
      return;
    }
    // Validate files
    if (idProof == null || addressProof == null) {
      BaseController.share.showSnackBar('Please upload ID and Address proof');
      return;
    }

    final avgViewsRaw = avgMonthlyViews.text.trim();
    final avgViewsInt = int.tryParse(avgViewsRaw);
    final data = <String, dynamic>{
      'full_name': fullName.text.trim(),
      'email': email.text.trim(),
      'mobile': mobile.text.trim(),
      'country': country.text.trim(),
      'date_of_birth': dob == null
          ? null
          : '${dob!.year.toString().padLeft(4, '0')}-${dob!.month.toString().padLeft(2, '0')}-${dob!.day.toString().padLeft(2, '0')}',
      'channel_name': channelName.text.trim(),
      'channel_category': channelCategory.text.trim(),
      'content_type': contentType.text.trim(),
      'avg_monthly_views': avgViewsInt ?? avgViewsRaw,
      'content_language': contentLanguage.text.trim(),
      'owns_content': 1,
      'no_copyright_violation': 1,
      'follows_guidelines': 1,
      'no_fake_engagement': 1,
      'payment_method': paymentMethod,
      if (paymentMethod == 'upi') 'upi_id': upiId.text.trim(),
      if (paymentMethod == 'bank') 'bank_account_name': bankAccountName.text.trim(),
      if (paymentMethod == 'bank') 'bank_account_number': bankAccountNumber.text.trim(),
      if (paymentMethod == 'bank') 'bank_ifsc': bankIfsc.text.trim(),
      if (paymentMethod == 'paypal') 'paypal_email': paypalEmail.text.trim(),
      if (panTaxId.text.isNotEmpty) 'pan_tax_id': panTaxId.text.trim(),
      if (addressForTax.text.isNotEmpty) 'address_for_tax': addressForTax.text.trim(),
    };
    BaseController.share.showLoader(barrierDismissible: false);
    try {
      final files = <String, List<XFile?>>{
        'id_proof': [idProof],
        'address_proof': [addressProof],
      };
      final res2 = await widget.controller.submitMonetizationMultipart(
        data,
        files,
      );
      BaseController.share.stopLoader();
      final pendingAfterSubmit = widget.controller.stats.value?.monetizationStatus == 'pending';
      if (res2.status == true || pendingAfterSubmit) {
        BaseController.share.showSnackBar('Submitted. Under Review');
        Get.back();
      } else {
        BaseController.share.showSnackBar(res2.message ?? 'Submission failed');
      }
    } catch (e) {
      BaseController.share.stopLoader();
      BaseController.share.showSnackBar(e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: scaffoldBackgroundColor(context),
        foregroundColor: textDarkGrey(context),
        title: Text(
          'Monetization Request',
          style: TextStyle(color: textDarkGrey(context)),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _field('Full Name', fullName, required: true),
            _field('Email', email, required: true, emailType: true),
            _field('Mobile', mobile, required: true, keyboard: TextInputType.phone),
            _field('Country', country, required: true),
            _dobPicker(context),
            _field('Channel Name', channelName, required: true),
            _field('Channel Category', channelCategory, required: true),
            _field('Content Type', contentType, required: true),
            _field('Avg Monthly Views', avgMonthlyViews, required: true, keyboard: TextInputType.number),
            _field('Content Language', contentLanguage, required: true),
            const SizedBox(height: 8),
            Text(
              'Compliance',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: textDarkGrey(context),
              ),
            ),
            CheckboxListTile(
              value: ownsContent,
              onChanged: (v) => setState(() => ownsContent = v ?? false),
              title: const Text('I own the content I submit'),
            ),
            CheckboxListTile(
              value: noCopyrightViolation,
              onChanged: (v) => setState(() => noCopyrightViolation = v ?? false),
              title: const Text('No copyright violations'),
            ),
            CheckboxListTile(
              value: followsGuidelines,
              onChanged: (v) => setState(() => followsGuidelines = v ?? false),
              title: const Text('I follow community guidelines'),
            ),
            CheckboxListTile(
              value: noFakeEngagement,
              onChanged: (v) => setState(() => noFakeEngagement = v ?? false),
              title: const Text('No fake engagement'),
            ),
            const Divider(),
            Text(
              'Payment Method',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: textDarkGrey(context),
              ),
            ),
            RadioGroup<String>(
              groupValue: paymentMethod,
              onChanged: (v) => setState(() => paymentMethod = v ?? 'upi'),
              child: Row(
                children: [
                  _pm('upi'),
                  _pm('bank'),
                  _pm('paypal'),
                ],
              ),
            ),
            if (paymentMethod == 'upi') _field('UPI ID', upiId, required: true),
            if (paymentMethod == 'bank') _field('Account Holder Name', bankAccountName, required: true),
            if (paymentMethod == 'bank') _field('Account Number', bankAccountNumber, required: true, keyboard: TextInputType.number),
            if (paymentMethod == 'bank') _field('IFSC', bankIfsc, required: true),
            if (paymentMethod == 'paypal') _field('PayPal Email', paypalEmail, required: true, emailType: true),
            const Divider(),
            Text(
              'KYC Documents',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: textDarkGrey(context),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final x = await _picker.pickImage(source: ImageSource.gallery);
                      if (x != null) setState(() => idProof = x);
                    },
                    icon: const Icon(Icons.badge_outlined),
                    label: Text(idProof == null ? 'Upload ID Proof' : 'ID Selected'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final x = await _picker.pickImage(source: ImageSource.gallery);
                      if (x != null) setState(() => addressProof = x);
                    },
                    icon: const Icon(Icons.home_outlined),
                    label: Text(addressProof == null ? 'Upload Address Proof' : 'Address Selected'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _field('PAN / Tax ID (optional)', panTaxId),
            _field('Address for Tax (optional)', addressForTax),
            const SizedBox(height: 16),
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: _submit,
                child: const Text('Submit'),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _pm(String key) {
    return Expanded(
      child: RadioListTile<String>(
        dense: true,
        contentPadding: EdgeInsets.zero,
        value: key,
        title: Text(key.toUpperCase()),
      ),
    );
  }

  Widget _dobPicker(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: const Text('Date of Birth'),
      subtitle: Text(dob == null ? 'Select DOB (must be 18+)' : '${dob!.toLocal()}'.split(' ')[0]),
      trailing: Icon(isAdult ? Icons.check_circle : Icons.error, color: isAdult ? Colors.green : Colors.orange),
      onTap: () async {
        final now = DateTime.now();
        final picked = await showDatePicker(
          context: context,
          initialDate: DateTime(now.year - 18, now.month, now.day),
          firstDate: DateTime(1900),
          lastDate: now,
        );
        if (picked != null) setState(() => dob = picked);
      },
    );
  }

  Widget _field(String label, TextEditingController c,
      {bool required = false, bool emailType = false, TextInputType? keyboard}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: TextFormField(
        controller: c,
        keyboardType: keyboard,
        decoration: InputDecoration(labelText: label),
        validator: (v) {
          if (required && (v == null || v.trim().isEmpty)) return 'Required';
          if (label == 'Date of Birth' && !isAdult) return 'Must be 18+';
          if (emailType && v != null && v.isNotEmpty && !v.contains('@')) return 'Invalid email';
          return null;
        },
      ),
    );
  }
}
