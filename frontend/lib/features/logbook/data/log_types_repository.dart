import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';

/// One field of a log type, as the extractor's catalog defines it.
class LogTypeField {
  const LogTypeField({required this.name, required this.type, required this.required, this.enumValues});

  final String name;

  /// str | number | bool | list[str] | list[number] | dict
  final String type;
  final bool required;
  final List<String>? enumValues;

  factory LogTypeField.fromJson(Map<String, dynamic> json) => LogTypeField(
        name: json['name'] as String,
        type: json['type'] as String,
        required: json['required'] as bool? ?? false,
        enumValues: (json['enum'] as List?)?.map((e) => e.toString()).toList(),
      );

  /// "estimated_calories" → "Estimated calories"
  String get label {
    final words = name.replaceAll('_', ' ');
    return words.isEmpty ? name : words[0].toUpperCase() + words.substring(1);
  }
}

class LogType {
  const LogType({required this.name, required this.description, required this.fields});
  final String name;
  final String description;
  final List<LogTypeField> fields;

  factory LogType.fromJson(Map<String, dynamic> json) => LogType(
        name: json['name'] as String,
        description: json['description'] as String? ?? '',
        fields: (json['fields'] as List? ?? []).map((f) => LogTypeField.fromJson(f as Map<String, dynamic>)).toList(),
      );
}

class LogTypesRepository {
  LogTypesRepository(this._dio);
  final Dio _dio;

  Future<Map<String, LogType>> fetch() async {
    final resp = await _dio.get('/log-types');
    return {for (final t in resp.data as List) (t as Map<String, dynamic>)['name'] as String: LogType.fromJson(t)};
  }
}

final logTypesRepositoryProvider = Provider<LogTypesRepository>((ref) => LogTypesRepository(ref.watch(dioProvider)));

/// Cached for the session: the catalog only changes with a deploy.
final logTypesProvider = FutureProvider<Map<String, LogType>>((ref) => ref.watch(logTypesRepositoryProvider).fetch());
