import 'package:moonlight/features/wallet/domain/repositories/pin_repository.dart';

class SetPin {
  final PinRepository repository;
  SetPin(this.repository);

  Future<void> call(String pin) async {
    // You can add validation here if needed (length, digits)
    if (pin.length < 4) {
      throw Exception('PIN must be 4 digits');
    }
    return repository.setPin(pin: pin);
  }
}
