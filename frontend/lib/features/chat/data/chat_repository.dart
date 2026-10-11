import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';

class ChatExtractionResult {
  const ChatExtractionResult({required this.entries, required this.alerts, required this.reply, this.degraded = false});

  final List<Map<String, dynamic>> entries;
  final List<Map<String, dynamic>> alerts;
  final String reply;

  /// The real model failed and the offline extractor stood in — the cards
  /// deserve a glance.
  final bool degraded;

  factory ChatExtractionResult.fromJson(Map<String, dynamic> json) => ChatExtractionResult(
        entries: List<Map<String, dynamic>>.from(json['entries'] as List? ?? []),
        alerts: List<Map<String, dynamic>>.from(json['alerts'] as List? ?? []),
        reply: json['reply'] as String? ?? '',
        degraded: json['degraded'] as bool? ?? false,
      );
}

class ChatHistoryResult {
  const ChatHistoryResult({required this.items, required this.welcomeBackMessage, this.hasMore = false});

  final List<Map<String, dynamic>> items;
  final String? welcomeBackMessage;

  /// Older rows exist beyond this page — "load earlier" passes the oldest
  /// row's created_at as the cursor.
  final bool hasMore;

  factory ChatHistoryResult.fromJson(Map<String, dynamic> json) => ChatHistoryResult(
        items: List<Map<String, dynamic>>.from(json['items'] as List? ?? []),
        welcomeBackMessage: json['welcome_back_message'] as String?,
        hasMore: json['has_more'] as bool? ?? false,
      );
}

class ChatRepository {
  ChatRepository(this._dio);

  final Dio _dio;

  Future<ChatHistoryResult> fetchHistory({DateTime? before, int limit = 100}) async {
    final resp = await _dio.get('/chat/messages', queryParameters: {
      'limit': limit,
      'before': ?before?.toUtc().toIso8601String(),
    });
    return ChatHistoryResult.fromJson(resp.data as Map<String, dynamic>);
  }

  Future<ChatExtractionResult> sendMessage(String text, {String? mediaAssetId}) async {
    final resp = await _dio.post('/chat/messages', data: {'text': text, 'media_asset_id': ?mediaAssetId});
    return ChatExtractionResult.fromJson(resp.data as Map<String, dynamic>);
  }

  Future<void> editEntrySummary(String entryId, String summary) async {
    await _dio.patch('/log-entries/$entryId', data: {'summary': summary});
  }

  Future<void> deleteEntry(String entryId) async {
    await _dio.delete('/log-entries/$entryId');
  }
}

final chatRepositoryProvider = Provider<ChatRepository>((ref) => ChatRepository(ref.watch(dioProvider)));
