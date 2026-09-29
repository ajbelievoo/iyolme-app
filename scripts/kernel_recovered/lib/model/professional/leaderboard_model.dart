class LeaderboardModel {
  LeaderboardModel({this.status, this.message, this.data});

  bool? status;
  String? message;
  List<LeaderboardEntry>? data;

  factory LeaderboardModel.fromJson(Map<String, dynamic> json) {
    return LeaderboardModel(
      status: json['status'] as bool?,
      message: json['message'] as String?,
      data: (json['data'] as List?)
          ?.map((e) => LeaderboardEntry.fromJson((e as Map).cast<String, dynamic>()))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'status': status,
        'message': message,
        if (data != null) 'data': data!.map((e) => e.toJson()).toList(),
      };
}

class LeaderboardEntry {
  LeaderboardEntry({
    this.id,
    this.userId,
    this.username,
    this.fullname,
    this.professionalName,
    this.profilePhoto,
    this.rank,
    this.score,
    this.likes,
    this.views,
    this.comments,
    this.engagementScore,
    this.points,
    this.weightedScore,
    this.pointsEarned,
  });

  int? id;
  int? userId;
  String? username;
  String? fullname;
  String? professionalName;
  String? profilePhoto;
  int? rank;
  int? score;
  int? likes;
  int? views;
  int? comments;
  int? engagementScore;
  int? points;
  int? weightedScore;
  int? pointsEarned;

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) {
    final score = _toInt(json['score']);
    final pointsEarned = _toInt(json['points_earned']);
    return LeaderboardEntry(
      id: _toInt(json['id']),
      userId: _toInt(json['user_id'] ?? json['userId']),
      username: json['username']?.toString(),
      fullname: json['professional_name']?.toString() ??
          json['professionalName']?.toString() ??
          json['fullname']?.toString() ??
          json['full_name']?.toString(),
      professionalName: json['professional_name']?.toString() ?? json['professionalName']?.toString(),
      profilePhoto: json['profile_photo']?.toString(),
      rank: _toInt(json['rank']),
      score: score > 0 ? score : (pointsEarned > 0 ? pointsEarned : _toInt(json['points'])),
      likes: _toInt(json['likes']),
      views: _toInt(json['views']),
      comments: _toInt(json['comments']),
      engagementScore: _toInt(json['engagement_score']),
      points: _toInt(json['points']),
      weightedScore: _toInt(json['weighted_score'] ?? json['mining_activity']),
      pointsEarned: pointsEarned,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'username': username,
        'fullname': fullname,
        if (professionalName != null) 'professional_name': professionalName,
        'profile_photo': profilePhoto,
        'rank': rank,
        if (score != null) 'score': score,
        'likes': likes,
        'views': views,
        'comments': comments,
        if (engagementScore != null) 'engagement_score': engagementScore,
        'points': points,
        if (weightedScore != null) 'weighted_score': weightedScore,
        if (pointsEarned != null) 'points_earned': pointsEarned,
      };
}

int _toInt(dynamic v) {
  if (v == null) return 0;
  if (v is int) return v;
  return int.tryParse('$v') ?? 0;
}
n