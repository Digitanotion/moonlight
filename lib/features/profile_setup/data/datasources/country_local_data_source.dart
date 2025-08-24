import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

abstract class CountryLocalDataSource {
  Future<List<String>> loadCountries();
}

class CountryLocalDataSourceImpl implements CountryLocalDataSource {
  @override
  Future<List<String>> loadCountries() async {
    final jsonStr = await rootBundle.loadString('assets/countries.json');
    final List<dynamic> list = json.decode(jsonStr);
    return list.cast<String>();
  }
}
