// lib/features/profile_setup/data/datasources/profile_remote_data_source.dart
import 'package:dio/dio.dart';

abstract class ProfileRemoteDataSource {
  Future<void> setupProfile({
    required String fullname,
    String? gender,
    String? country,
    String? bio,
    List<String>? interests,
    String? phone,
    String? avatarPath,
  });

  Future<void> updateInterests(List<String> interests);
  // NEW: returns updated user map from API response
  Future<Map<String, dynamic>> updateProfile({
    String? fullname,
    String? gender,
    String? country,
    String? bio,
    List<String>? interests,
    String? phone,
    String? avatarPath,
    bool removeAvatar = false,
  });
}

class ProfileRemoteDataSourceImpl implements ProfileRemoteDataSource {
  final Dio dio; // baseUrl must be https://svc.moonlightstream.app/api/
  ProfileRemoteDataSourceImpl(this.dio);

  @override
  Future<void> setupProfile({
    required String fullname,
    String? gender,
    String? country,
    String? bio,
    List<String>? interests,
    String? phone,
    String? avatarPath,
  }) async {
    // sanitize + enforce requireds
    final payload = <String, dynamic>{
      'fullname': fullname.trim(),
      if (gender != null && gender.isNotEmpty) 'gender': gender,
      if (country != null && country.isNotEmpty) 'country': country,
      if (bio != null && bio.trim().isNotEmpty) 'bio': bio.trim(),
      if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
      if (interests != null && interests.isNotEmpty)
        'user_interests': interests,
    };

    try {
      if (avatarPath != null && avatarPath.isNotEmpty) {
        // Multipart only when uploading a file
        final form = FormData.fromMap(payload);
        form.files.add(
          MapEntry(
            'avatar',
            await MultipartFile.fromFile(
              avatarPath,
              filename: avatarPath.split('/').last,
            ),
          ),
        );

        await dio.post(
          '/v1/profile/setup',
          data: form,
          // Ensure arrays are sent compatibly: user_interests[]=a&user_interests[]=b
          options: Options(
            contentType: 'multipart/form-data',
            listFormat: ListFormat.multiCompatible,
          ),
        );
      } else {
        // JSON is safest when not sending files
        await dio.post(
          '/v1/profile/setup',
          data: payload,
          options: Options(contentType: Headers.jsonContentType),
        );
      }
    } on DioException catch (e) {
      // Bubble up clean messages for 400/422 validation errors
      final status = e.response?.statusCode;
      final data = e.response?.data;
      // Laravel typical shape: { message: "...", errors: { field: ["msg"] } }
      if (status == 400 || status == 422) {
        final msg =
            _extractValidationMessage(data) ?? 'Validation failed (${status}).';
        throw DioException(
          requestOptions: e.requestOptions,
          response: e.response,
          type: e.type,
          error: msg,
        );
      }
      rethrow;
    }
  }

  @override
  Future<void> updateInterests(List<String> interests) async {
    try {
      await dio.put(
        '/v1/profile/update',
        data: {'user_interests': interests},
        options: Options(
          contentType: Headers.jsonContentType,
          listFormat: ListFormat.multiCompatible,
        ),
      );
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 400 || status == 422) {
        final msg =
            _extractValidationMessage(e.response?.data) ??
            'Validation failed (${status}).';
        throw DioException(
          requestOptions: e.requestOptions,
          response: e.response,
          type: e.type,
          error: msg,
        );
      }
      rethrow;
    }
  }

  @override
  Future<Map<String, dynamic>> updateProfile({
    String? fullname,
    String? gender,
    String? country,
    String? bio,
    List<String>? interests,
    String? phone,
    String? avatarPath,
    bool removeAvatar = false,
  }) async {
    final payload = <String, dynamic>{
      if (fullname?.trim().isNotEmpty == true) 'fullname': fullname!.trim(),
      if (gender?.isNotEmpty == true) 'gender': gender,
      if (country?.isNotEmpty == true) 'country': country,
      if (bio?.trim().isNotEmpty == true) 'bio': bio!.trim(),
      if (phone?.trim().isNotEmpty == true) 'phone': phone!.trim(),
      if (interests != null && interests.isNotEmpty)
        'user_interests': interests,
      if (removeAvatar) 'remove_avatar': true,
    };

    Response res;
    if (avatarPath != null && avatarPath.isNotEmpty) {
      final form = FormData.fromMap(payload);
      form.files.add(
        MapEntry(
          'avatar',
          await MultipartFile.fromFile(
            avatarPath,
            filename: avatarPath.split('/').last,
          ),
        ),
      );
      res = await dio.put(
        '/v1/profile/update',
        data: form,
        options: Options(
          contentType: 'multipart/form-data',
          listFormat: ListFormat.multiCompatible,
        ),
      );
    } else {
      res = await dio.put(
        '/v1/profile/update',
        data: payload,
        options: Options(
          contentType: Headers.jsonContentType,
          listFormat: ListFormat.multiCompatible,
        ),
      );
    }

    // expected: { message: "...", user: { ... } }
    final data = (res.data is Map<String, dynamic>)
        ? res.data as Map<String, dynamic>
        : <String, dynamic>{};
    final user = (data['user'] is Map<String, dynamic>)
        ? data['user'] as Map<String, dynamic>
        : <String, dynamic>{};
    return user;
  }

  String? _extractValidationMessage(dynamic data) {
    try {
      if (data is Map<String, dynamic>) {
        final base = data['message']?.toString();
        if (data['errors'] is Map<String, dynamic>) {
          final errs = (data['errors'] as Map<String, dynamic>).entries
              .map((e) => '${e.key}: ${(e.value as List).join(", ")}')
              .join(' • ');
          return [
            base,
            errs,
          ].where((s) => s != null && s.isNotEmpty).join(' — ');
        }
        return base;
      }
    } catch (_) {}
    return null;
  }
}
