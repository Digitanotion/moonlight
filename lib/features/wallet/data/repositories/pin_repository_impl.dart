import 'package:moonlight/features/wallet/data/datasources/pin_remote_datasource.dart';
import 'package:moonlight/features/wallet/domain/repositories/pin_repository.dart';

class PinRepositoryImpl implements PinRepository {
  final PinRemoteDataSource remote;
  PinRepositoryImpl({required this.remote});

  @override
  Future<void> setPin({required String pin}) async {
    await remote.setPin(pin: pin);
  }
}
