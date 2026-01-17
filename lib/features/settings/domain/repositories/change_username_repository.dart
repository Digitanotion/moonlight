abstract class ChangeUsernameRepository {
  Future<Map<String, dynamic>> changeUsername({
    required String username,
    required String password,
  });

  Future<Map<String, dynamic>> checkUsername(String username);

  Future<Map<String, dynamic>> getUsernameHistory({int page, int perPage});
}
