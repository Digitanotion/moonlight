// lib/features/interests/data/models/interest_model.dart
class Interest {
  final String id;
  final String name;
  bool isSelected;

  Interest({required this.id, required this.name, this.isSelected = false});

  factory Interest.fromJson(Map<String, dynamic> json) {
    return Interest(
      id: json['id'].toString(),
      name: json['name'],
      isSelected: json['isSelected'] ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    "id": id,
    "name": name,
    "isSelected": isSelected,
  };
}
