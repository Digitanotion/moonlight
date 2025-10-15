import 'dart:io';
import 'package:dio/dio.dart';
import 'package:mime/mime.dart';
import 'package:moonlight/core/network/dio_client.dart';
import '../../domain/entities/create_post_payload.dart';

class CreatePostRemoteDataSource {
  final DioClient http;
  CreatePostRemoteDataSource(this.http);

  /// POST /api/v1/posts (multipart)
  Future<Map<String, dynamic>> createPost(CreatePostPayload p) async {
    final file = File(p.mediaPath);
    final mime = lookupMimeType(file.path) ?? 'application/octet-stream';

    // Build multipart the safe way so arrays are encoded as tags[]
    final form = FormData();

    form.fields
      ..add(MapEntry('caption', p.caption))
      ..add(MapEntry('visibility', p.visibility.apiValue));

    // 👇 Encode array exactly as API expects: tags[]
    for (final t in p.tags) {
      if (t.trim().isEmpty) continue;
      form.fields.add(MapEntry('tags[]', t));
    }

    form.files.add(
      MapEntry(
        'media',
        await MultipartFile.fromFile(
          file.path,
          filename: file.uri.pathSegments.last,
          // contentType optional; dio infers from file. If your dio ==5 and you want explicit:
          // contentType: MediaType.parse(mime),
        ),
      ),
    );

    final res = await http.dio.post('/api/v1/posts', data: form);

    // Accept {data:{...}} or plain {...}
    final raw = res.data;
    if (raw is Map && raw['data'] is Map) {
      return (raw['data'] as Map).cast<String, dynamic>();
    }
    return (raw as Map).cast<String, dynamic>();
  }
}
