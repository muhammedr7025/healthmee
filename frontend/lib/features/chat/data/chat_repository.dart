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

class ChatRepository {
  ChatRepository(this._dio);

  final Dio _dio;

  Future<ChatExtractionResult> sendMessage(String text) async {
    final resp = await _dio.post('/chat/messages', data: {'text': text});
    return ChatExtractionResult.fromJson(resp.data as Map<String, dynamic>);
  }
}

final chatRepositoryProvider = Provider<ChatRepository>((ref) => ChatRepository(ref.watch(dioProvider)));
