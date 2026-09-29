import 'package:flutter_test/flutter_test.dart';
import 'package:shortzz/model/general/settings_model.dart';
import 'package:shortzz/model/user_model/user_model.dart';

void main() {
  group('User model tests', () {
    test('User referral_code parse + serialize', () {
      final user = User.fromJson({
        'id': 105,
        'username': 'JohnDoe123',
        'referral_code': 'XYZ98765',
        'coin_wallet': 50,
      });

      expect(user.referralCode, 'XYZ98765');
      expect(user.coinWallet, 50);

      final json = user.toJson();
      expect(json['referral_code'], 'XYZ98765');
    });

    test('User handles null optional fields', () {
      final user = User.fromJson({'id': 1, 'username': 'test'});
      expect(user.id, 1);
      expect(user.username, 'test');
      expect(user.referralCode, isNull);
    });
  });

  group('Settings model tests', () {
    test('Settings referral bonus parse', () {
      final s = Setting.fromJson({
        'registration_bonus_status': 1,
        'registration_bonus_amount': 10,
        'referral_bonus_status': 1,
        'referral_bonus_amount': 25,
      });

      expect(s.registrationBonusAmount, 10);
      expect(s.referralBonusAmount, 25);
      expect(s.referralBonusStatus, 1);
    });

    test('Settings defaults when fields are missing', () {
      final s = Setting.fromJson({});
      expect(s.registrationBonusAmount, isNull);
      expect(s.referralBonusAmount, isNull);
      expect(s.referralBonusStatus, isNull);
    });
  });
}
