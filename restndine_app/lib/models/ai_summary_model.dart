class SentimentStats {
  final int positive;
  final int neutral;
  final int negative;
  final int total;

  SentimentStats({
    required this.positive,
    required this.neutral,
    required this.negative,
    required this.total,
  });

  factory SentimentStats.fromJson(Map<String, dynamic> json) {
    return SentimentStats(
      positive: json['positive'] is int ? json['positive'] : 0,
      neutral: json['neutral'] is int ? json['neutral'] : 0,
      negative: json['negative'] is int ? json['negative'] : 0,
      total: json['total'] is int ? json['total'] : 0,
    );
  }

  double get positivePercentage => total > 0 ? (positive / total) * 100 : 0;
  double get neutralPercentage => total > 0 ? (neutral / total) * 100 : 0;
  double get negativePercentage => total > 0 ? (negative / total) * 100 : 0;
}

class AiSummaryModel {
  final bool success;
  final String summary;
  final bool isCached;
  final DateTime? updatedAt;
  final SentimentStats? sentimentStats;

  AiSummaryModel({
    required this.success,
    required this.summary,
    required this.isCached,
    this.updatedAt,
    this.sentimentStats,
  });

  factory AiSummaryModel.fromJson(Map<String, dynamic> json) {
    return AiSummaryModel(
      success: json['success'] ?? false,
      summary: json['summary'] ?? '',
      isCached: json['isCached'] ?? false,
      updatedAt: json['updatedAt'] != null ? DateTime.tryParse(json['updatedAt'].toString()) : null,
      sentimentStats: json['sentimentStats'] != null
          ? SentimentStats.fromJson(json['sentimentStats'] as Map<String, dynamic>)
          : null,
    );
  }
}
