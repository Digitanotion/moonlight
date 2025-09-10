// lib/features/livestream/data/models/gift_dto.dart
class GiftResponseDto {
  final int balance;
  final String? notice;
  GiftResponseDto({required this.balance, this.notice});
  factory GiftResponseDto.fromJson(Map<String, dynamic> j) =>
      GiftResponseDto(balance: j['balance'] ?? 0, notice: j['notice']);
}
