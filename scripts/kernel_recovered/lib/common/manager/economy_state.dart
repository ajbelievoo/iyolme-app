import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

class EconomyState {
  EconomyState._() {
    _load();
  }
  static final EconomyState instance = EconomyState._();

  final _box = GetStorage('shortzz');

  final coins = 0.obs; // int
  final points = 0.obs; // int
  final minerPoints = 0.obs; // int
  final earnings = 0.0.obs; // double
  final monetizationStatus = ''.obs; // pending | approved | rejected | ''

  void _load() {
    coins.value = _box.read('eco_coins') ?? 0;
    points.value = _box.read('eco_points') ?? 0;
    minerPoints.value = _box.read('eco_miner_points') ?? 0;
    earnings.value = (_box.read('eco_earnings') ?? 0).toDouble();
    monetizationStatus.value = _box.read('eco_monetization_status') ?? '';
  }

  void _save() {
    _box.write('eco_coins', coins.value);
    _box.write('eco_points', points.value);
    _box.write('eco_miner_points', minerPoints.value);
    _box.write('eco_earnings', earnings.value);
    _box.write('eco_monetization_status', monetizationStatus.value);
  }

  void set(
      {int? coins,
      int? points,
      int? minerPoints,
      num? earnings,
      String? monetizationStatus}) {
    if (coins != null) this.coins.value = coins;
    if (points != null) this.points.value = points;
    if (minerPoints != null) this.minerPoints.value = minerPoints;
    if (earnings != null) this.earnings.value = earnings.toDouble();
    if (monetizationStatus != null) this.monetizationStatus.value = monetizationStatus;
    _save();
  }

  // Ingest any API response and update if keys are present
  void ingestApi(Map<String, dynamic> json) {
    void readMap(Map<String, dynamic> m) {
      if (m.containsKey('coins')) {
        final v = m['coins'];
        coins.value = _toInt(v);
      }
      // Backend may return credits directly.
      if (m.containsKey('credits')) {
        final v = m['credits'];
        points.value = _toInt(v);
      }
      if (m.containsKey('points')) {
        final v = m['points'];
        points.value = _toInt(v);
      }
      if (m.containsKey('miner_points')) {
        final v = m['miner_points'];
        minerPoints.value = _toInt(v);
      }
      if (m.containsKey('earnings')) {
        final v = m['earnings'];
        earnings.value = _toDouble(v);
      }
      if (m.containsKey('monetization_status')) {
        monetizationStatus.value = '${m['monetization_status'] ?? ''}';
      }
    }

    readMap(json);
    final data = json['data'];
    if (data is Map<String, dynamic>) {
      readMap(data);
    }
    // persist
    _save();
  }
}

int _toInt(dynamic v) {
  if (v == null) return 0;
  if (v is int) return v;
  return int.tryParse('$v') ?? 0;
}

double _toDouble(dynamic v) {
  if (v == null) return 0.0;
  if (v is num) return v.toDouble();
  return double.tryParse('$v') ?? 0.0;
}
c