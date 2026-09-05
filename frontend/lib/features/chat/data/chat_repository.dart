import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';

class ChatExtractionResult {
  const ChatExtractionResult({required this.entries, required this.alerts, required this.reply});

  final List<Map<String, dynamic>> entries;
  final List<Map<String, dynamic>> alerts;
  final String reply;

  factory ChatExtractionResult.fromJson(Map<String, dynamic> json) => ChatExtractionResult(
        entries: List<Map<String, dynamic>>.from(json['entries'] as List? ?? []),
        alerts: List<Map<String, dynamic>>.from(json['alerts'] as List? ?? []),
        reply: json['reply'] as String? ?? '',
      );
}

class ChatHistoryResult {
  const ChatHistoryResult({required this.items, required this.welcomeBackMessage});

  final List<Map<String, dynamic>> items;
  final String? welcomeBackMessage;

  factory ChatHistoryResult.fromJson(Map<String, dynamic> json) => ChatHistoryResult(
        items: List<Map<String, dynamic>>.from(json['items'] as List? ?? []),
        welcomeBackMessage: json['welcome_back_message'] as String?,
      );
}

class ChatRepository {
  ChatRepository(this._dio);

  final Dio _dio;

  Future<ChatHistoryResult> fetchHistory() async {
    final resp = await _dio.get('/chat/messages');
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
