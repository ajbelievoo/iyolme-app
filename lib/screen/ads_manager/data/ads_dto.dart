class AdsManagerCampaignCreateRequestDto {
  const AdsManagerCampaignCreateRequestDto({
    required this.title,
    this.postId,
    this.goal,
    this.placement,
    this.audienceCountry,
    this.dailyBudget,
    this.totalBudget,
    this.mediaUrl,
    this.status,
    this.metadata,
  });

  final String title;
  final int? postId;
  final String? goal;
  final String? placement;
  final String? audienceCountry;
  final num? dailyBudget;
  final num? totalBudget;
  final String? mediaUrl;
  final String? status;
  final Map<String, dynamic>? metadata;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'title': title,
      if (postId != null) 'postId': postId,
      if ((goal ?? '').trim().isNotEmpty) 'goal': goal,
      if ((placement ?? '').trim().isNotEmpty) 'placement': placement,
      if ((audienceCountry ?? '').trim().isNotEmpty)
        'audienceCountry': audienceCountry,
      if (dailyBudget != null) 'dailyBudget': dailyBudget,
      if (totalBudget != null) 'totalBudget': totalBudget,
      if ((mediaUrl ?? '').trim().isNotEmpty) 'mediaUrl': mediaUrl,
      if ((status ?? '').trim().isNotEmpty) 'status': status,
      if (metadata != null) 'metadata': metadata,
    };
  }
}

class AdsManagerCampaignCreateResponseDto {
  const AdsManagerCampaignCreateResponseDto({
    required this.status,
    this.message,
    this.campaignId,
  });

  final bool status;
  final String? message;
  final int? campaignId;

  factory AdsManagerCampaignCreateResponseDto.fromJson(
    Map<String, dynamic> json,
  ) {
    final data = json['data'] is Map ? (json['data'] as Map) : null;
    final dynamic idRaw =
        data?['campaignId'] ?? data?['id'] ?? json['campaignId'] ?? json['id'];

    return AdsManagerCampaignCreateResponseDto(
      status: json['status'] == true,
      message: json['message']?.toString(),
      campaignId: idRaw is num ? idRaw.toInt() : int.tryParse('$idRaw'),
    );
  }
}

class AdsManagerCampaignListItemDto {
  const AdsManagerCampaignListItemDto({
    required this.id,
    required this.title,
    this.mediaUrl,
    this.status,
    this.statusCode,
    this.placement,
    this.spend,
    this.budget,
    this.dailyBudget,
    this.impressions,
    this.clicks,
    this.createdAt,
  });

  final int id;
  final String title;
  final String? mediaUrl;
  final String? status;
  final int? statusCode;
  final String? placement;
  final num? spend;
  final num? budget;
  final num? dailyBudget;
  final int? impressions;
  final int? clicks;
  final DateTime? createdAt;

  factory AdsManagerCampaignListItemDto.fromJson(Map<String, dynamic> json) {
    final dynamic idRaw = json['id'] ?? json['campaignId'];
    final dynamic createdRaw = json['createdAt'] ?? json['created_at'];
    final dynamic statusRaw = json['status'];

    DateTime? created;
    if (createdRaw is String && createdRaw.trim().isNotEmpty) {
      created = DateTime.tryParse(createdRaw);
    }

    int? statusCode;
    String? statusText;
    if (statusRaw is num) {
      statusCode = statusRaw.toInt();
    } else {
      statusCode = int.tryParse('$statusRaw');
    }
    if (statusCode == null) {
      statusText = statusRaw?.toString();
    }

    return AdsManagerCampaignListItemDto(
      id: idRaw is num ? idRaw.toInt() : int.tryParse('$idRaw') ?? -1,
      title: (json['title'] ?? json['name'] ?? 'Campaign').toString(),
      mediaUrl: json['mediaUrl']?.toString() ?? json['media_url']?.toString(),
      status: statusText,
      statusCode: statusCode,
      placement: json['placement']?.toString(),
      spend: json['spend'] is num ? json['spend'] as num : num.tryParse('${json['spend']}'),
      budget: json['budget'] is num ? json['budget'] as num : num.tryParse('${json['budget']}'),
      dailyBudget: json['dailyBudget'] is num
          ? json['dailyBudget'] as num
          : num.tryParse('${json['dailyBudget']}'),
      impressions: json['impressions'] is num
          ? (json['impressions'] as num).toInt()
          : int.tryParse('${json['impressions']}'),
      clicks: json['clicks'] is num
          ? (json['clicks'] as num).toInt()
          : int.tryParse('${json['clicks']}'),
      createdAt: created,
    );
  }
}

class AdsManagerCampaignListResponseDto {
  const AdsManagerCampaignListResponseDto({
    required this.items,
  });

  final List<AdsManagerCampaignListItemDto> items;

  factory AdsManagerCampaignListResponseDto.fromJson(
    Map<String, dynamic> json,
  ) {
    dynamic raw = json['data'] ??
        json['items'] ??
        json['list'] ??
        json['results'] ??
        json['rows'] ??
        json['campaigns'];

    if (raw is Map) {
      raw = raw['data'] ?? raw['items'] ?? raw['list'] ?? raw['results'];
    }

    final list = raw is List ? raw : <dynamic>[];
    return AdsManagerCampaignListResponseDto(
      items: list
          .whereType<Map>()
          .map((e) => AdsManagerCampaignListItemDto.fromJson(
                Map<String, dynamic>.from(e),
              ))
          .toList(),
    );
  }
}

class AdsManagerWalletTransactionDto {
  const AdsManagerWalletTransactionDto({
    required this.title,
    required this.amount,
    this.type,
    this.date,
  });

  final String title;
  final num amount;
  final String? type;
  final DateTime? date;

  factory AdsManagerWalletTransactionDto.fromJson(Map<String, dynamic> json) {
    final dynamic dateRaw = json['date'] ?? json['createdAt'] ?? json['created_at'];
    DateTime? parsed;
    if (dateRaw is String && dateRaw.trim().isNotEmpty) {
      parsed = DateTime.tryParse(dateRaw);
    }

    final dynamic amountRaw = json['amount'] ?? json['value'] ?? json['coins'];

    return AdsManagerWalletTransactionDto(
      title: (json['title'] ?? json['description'] ?? 'Transaction').toString(),
      amount: amountRaw is num ? amountRaw : (num.tryParse('$amountRaw') ?? 0),
      type: json['type']?.toString(),
      date: parsed,
    );
  }
}

class AdsManagerWalletDto {
  const AdsManagerWalletDto({
    required this.balance,
    required this.transactions,
  });

  final num balance;
  final List<AdsManagerWalletTransactionDto> transactions;

  factory AdsManagerWalletDto.fromJson(Map<String, dynamic> json) {
    final data = json['data'] is Map ? Map<String, dynamic>.from(json['data']) : json;

    final dynamic balanceRaw =
        data['balance'] ?? data['walletBalance'] ?? data['amount'] ?? 0;

    dynamic rawTx = data['transactions'] ??
        data['history'] ??
        data['ledger'] ??
        data['items'] ??
        <dynamic>[];

    if (rawTx is Map) {
      rawTx = rawTx['data'] ?? rawTx['items'] ?? rawTx['list'] ?? <dynamic>[];
    }

    final list = rawTx is List ? rawTx : <dynamic>[];

    return AdsManagerWalletDto(
      balance:
          balanceRaw is num ? balanceRaw : (num.tryParse('$balanceRaw') ?? 0),
      transactions: list
          .whereType<Map>()
          .map((e) => AdsManagerWalletTransactionDto.fromJson(
                Map<String, dynamic>.from(e),
              ))
          .toList(),
    );
  }
}

class AdsManagerBoostSuggestedBudgetDto {
  const AdsManagerBoostSuggestedBudgetDto({
    required this.suggestedBudget,
    this.min,
    this.max,
    this.currency,
  });

  final num suggestedBudget;
  final num? min;
  final num? max;
  final String? currency;

  factory AdsManagerBoostSuggestedBudgetDto.fromJson(Map<String, dynamic> json) {
    final data = json['data'] is Map ? Map<String, dynamic>.from(json['data']) : json;

    final suggestedRaw = data['suggestedBudget'] ?? data['suggested'] ?? data['budget'] ?? 0;
    final minRaw = data['min'] ?? data['minBudget'];
    final maxRaw = data['max'] ?? data['maxBudget'];

    return AdsManagerBoostSuggestedBudgetDto(
      suggestedBudget: suggestedRaw is num
          ? suggestedRaw
          : (num.tryParse('$suggestedRaw') ?? 0),
      min: minRaw is num ? minRaw : num.tryParse('$minRaw'),
      max: maxRaw is num ? maxRaw : num.tryParse('$maxRaw'),
      currency: data['currency']?.toString(),
    );
  }
}

class AdsManagerCampaignAnalyticsDto {
  const AdsManagerCampaignAnalyticsDto({
    required this.impressions,
    required this.clicks,
    required this.spend,
    this.ctr,
    this.cpc,
    this.cpa,
    this.countryStats,
    this.dailySeries,
    this.placementStats,
  });

  final int impressions;
  final int clicks;
  final num spend;
  final num? ctr;
  final num? cpc;
  final num? cpa;
  final List<Map<String, dynamic>>? countryStats;
  final List<Map<String, dynamic>>? dailySeries;
  final List<Map<String, dynamic>>? placementStats;

  factory AdsManagerCampaignAnalyticsDto.fromJson(Map<String, dynamic> json) {
    final data = json['data'] is Map ? Map<String, dynamic>.from(json['data']) : json;

    final impressionsRaw = data['impressions'] ?? 0;
    final clicksRaw = data['clicks'] ?? 0;
    final spendRaw = data['spend'] ?? 0;

    dynamic rawCountries = data['countryStats'] ?? data['countries'];
    if (rawCountries is Map) {
      rawCountries = rawCountries['data'] ?? rawCountries['items'] ?? rawCountries['list'];
    }

    final countries = rawCountries is List
        ? rawCountries
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList()
        : null;

    dynamic rawDaily = data['dailySeries'] ?? data['daily'] ?? data['series'];
    if (rawDaily is Map) {
      rawDaily = rawDaily['data'] ?? rawDaily['items'] ?? rawDaily['list'];
    }
    final daily = rawDaily is List
        ? rawDaily
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList()
        : null;

    dynamic rawPlacement =
        data['placementStats'] ?? data['placements'] ?? data['placement'];
    if (rawPlacement is Map) {
      rawPlacement = rawPlacement['data'] ?? rawPlacement['items'] ?? rawPlacement['list'];
    }
    final placements = rawPlacement is List
        ? rawPlacement
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList()
        : null;

    return AdsManagerCampaignAnalyticsDto(
      impressions: impressionsRaw is num
          ? impressionsRaw.toInt()
          : int.tryParse('$impressionsRaw') ?? 0,
      clicks:
          clicksRaw is num ? clicksRaw.toInt() : int.tryParse('$clicksRaw') ?? 0,
      spend: spendRaw is num ? spendRaw : (num.tryParse('$spendRaw') ?? 0),
      ctr: data['ctr'] is num ? data['ctr'] as num : num.tryParse('${data['ctr']}'),
      cpc: data['cpc'] is num ? data['cpc'] as num : num.tryParse('${data['cpc']}'),
      cpa: data['cpa'] is num ? data['cpa'] as num : num.tryParse('${data['cpa']}'),
      countryStats: countries,
      dailySeries: daily,
      placementStats: placements,
    );
  }
}

class AdsManagerActionResponseDto {
  const AdsManagerActionResponseDto({
    required this.status,
    this.message,
  });

  final bool status;
  final String? message;

  factory AdsManagerActionResponseDto.fromJson(Map<String, dynamic> json) {
    return AdsManagerActionResponseDto(
      status: json['status'] == true,
      message: json['message']?.toString(),
    );
  }
}

class AdsManagerOverallAnalyticsPointDto {
  const AdsManagerOverallAnalyticsPointDto({
    required this.date,
    required this.clicks,
    required this.impressions,
    required this.spend,
  });

  final String date;
  final int clicks;
  final int impressions;
  final num spend;

  factory AdsManagerOverallAnalyticsPointDto.fromJson(
    Map<String, dynamic> json,
  ) {
    int readInt(List<String> keys) {
      for (final k in keys) {
        final v = json[k];
        if (v == null) continue;
        if (v is num) return v.toInt();
        final n = int.tryParse(v.toString());
        if (n != null) return n;
      }
      return 0;
    }

    num readNum(List<String> keys) {
      for (final k in keys) {
        final v = json[k];
        if (v == null) continue;
        if (v is num) return v;
        final n = num.tryParse(v.toString());
        if (n != null) return n;
      }
      return 0;
    }

    final rawDate = (json['date'] ?? json['day'] ?? json['label'] ?? '').toString();

    return AdsManagerOverallAnalyticsPointDto(
      date: rawDate,
      clicks: readInt(['clicks', 'clk', 'taps']),
      impressions: readInt(['impressions', 'impr', 'views']),
      spend: readNum(['spend', 'spent', 'amount', 'cost']),
    );
  }
}

class AdsManagerOverallAnalyticsDto {
  const AdsManagerOverallAnalyticsDto({
    required this.range,
    required this.totalSpend,
    required this.totalImpressions,
    required this.totalClicks,
    required this.chartData,
  });

  final String range;
  final num totalSpend;
  final int totalImpressions;
  final int totalClicks;
  final List<AdsManagerOverallAnalyticsPointDto> chartData;

  factory AdsManagerOverallAnalyticsDto.fromJson(Map<String, dynamic> json) {
    final data = json['data'] is Map ? Map<String, dynamic>.from(json['data']) : json;

    final rangeRaw = (data['range'] ?? '').toString();

    final spendRaw = data['totalSpend'] ?? data['spend'] ?? 0;
    final imprRaw = data['totalImpressions'] ?? data['impressions'] ?? 0;
    final clickRaw = data['totalClicks'] ?? data['clicks'] ?? 0;

    final dynamic rawChart = data['chartData'] ?? data['daily'] ?? data['series'] ?? <dynamic>[];
    final list = rawChart is List ? rawChart : <dynamic>[];

    return AdsManagerOverallAnalyticsDto(
      range: rangeRaw,
      totalSpend: spendRaw is num ? spendRaw : (num.tryParse('$spendRaw') ?? 0),
      totalImpressions:
          imprRaw is num ? imprRaw.toInt() : int.tryParse('$imprRaw') ?? 0,
      totalClicks:
          clickRaw is num ? clickRaw.toInt() : int.tryParse('$clickRaw') ?? 0,
      chartData: list
          .whereType<Map>()
          .map((e) => AdsManagerOverallAnalyticsPointDto.fromJson(
                Map<String, dynamic>.from(e),
              ))
          .toList(),
    );
  }
}

class AdsManagerOverallAnalyticsResponseDto {
  const AdsManagerOverallAnalyticsResponseDto({
    required this.status,
    this.message,
    this.data,
  });

  final bool status;
  final String? message;
  final AdsManagerOverallAnalyticsDto? data;

  factory AdsManagerOverallAnalyticsResponseDto.fromJson(
    Map<String, dynamic> json,
  ) {
    return AdsManagerOverallAnalyticsResponseDto(
      status: json['status'] == true,
      message: json['message']?.toString(),
      data: json['data'] is Map
          ? AdsManagerOverallAnalyticsDto.fromJson(
              Map<String, dynamic>.from(json),
            )
          : null,
    );
  }
}
