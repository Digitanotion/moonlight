// lib/features/interests/data/repositories/interest_api_repository.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../models/interest_model.dart';
import 'interest_repository.dart';

class InterestApiRepository implements InterestRepository {
  final String baseUrl;

  InterestApiRepository({required this.baseUrl});

  @override
  Future<List<Interest>> fetchInterests() async {
    final response = await http.get(Uri.parse('$baseUrl/interests'));
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as List;
      return data.map((e) => Interest.fromJson(e)).toList();
    } else {
      throw Exception("Failed to load interests");
    }
  }

  @override
  Future<void> saveInterests(List<Interest> interests) async {
    final selected = interests.where((i) => i.isSelected).toList();
    await http.post(
      Uri.parse('$baseUrl/interests/save'),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(selected.map((e) => e.toJson()).toList()),
    );
  }
}
