class VoiceIntent {
  final String action;
  final String target;
  final int? index;
  final String? value;
  final double confidence;

  const VoiceIntent({
    required this.action,
    required this.target,
    this.index,
    this.value,
    this.confidence = 1.0,
  });

  Map<String, dynamic> toJson() => {
        'action': action,
        'target': target,
        'index': index,
        'value': value,
        'confidence': confidence,
      };
}
