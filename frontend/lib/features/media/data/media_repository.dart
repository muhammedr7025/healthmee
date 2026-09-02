import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';

class PresignedUpload {
  const PresignedUpload({required this.uploadUrl, required this.storageKey, required this.mediaAssetId});

  final String uploadUrl;
  final String storageKey;
  final String mediaAssetId;

  factory PresignedUpload.fromJson(Map<String, dynamic> json) => PresignedUpload(
        uploadUrl: json['upload_url'] as String,
        storageKey: json['storage_key'] as String,
        mediaAssetId: json['media_asset_id'] as String,
      );
}

class MediaRepository {
  MediaRepository(this._dio);

  final Dio _dio;

  /// Uploads `bytes` straight to object storage and returns the resulting
  /// media asset id, ready to attach to a chat message or a lab scan.
  Future<String> uploadPhoto(List<int> bytes, {String contentType = 'image/jpeg'}) async {
    final presignResp = await _dio.post('/media/presign', data: {'content_type': contentType, 'kind': 'photo'});
    final presigned = PresignedUpload.fromJson(presignResp.data as Map<String, dynamic>);

    // Presigned PUT goes straight to the storage host, not through the API
    // (and carries its own signature, not a user JWT) — a bare Dio instance
    // avoids the Authorization interceptor on the shared client.
    await Dio().put(
      presigned.uploadUrl,
      data: bytes,
      options: Options(headers: {'Content-Type': contentType}),
    );

    return presigned.mediaAssetId;
  }
}

final mediaRepositoryProvider = Provider<MediaRepository>((ref) => MediaRepository(ref.watch(dioProvider)));
