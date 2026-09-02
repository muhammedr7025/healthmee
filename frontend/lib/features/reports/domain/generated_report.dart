class GeneratedReport {
  const GeneratedReport({
    required this.id,
    required this.rangeStart,
    required this.rangeEnd,
    required this.pageCount,
    required this.createdAt,
    this.downloadUrl,
  });

  final String id;
  final String rangeStart;
  final String rangeEnd;
  final int pageCount;
  final String createdAt;
  final String? downloadUrl;

  factory GeneratedReport.fromJson(Map<String, dynamic> json) => GeneratedReport(
        id: json['id'] as String,
        rangeStart: json['range_start'] as String,
        rangeEnd: json['range_end'] as String,
        pageCount: json['page_count'] as int,
        createdAt: json['created_at'] as String,
        downloadUrl: json['download_url'] as String?,
      );
}
