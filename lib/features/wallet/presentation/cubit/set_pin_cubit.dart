import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:dio/dio.dart';
import 'package:moonlight/features/wallet/domain/usecases/set_pin.dart';

part 'set_pin_state.dart';

class SetPinCubit extends Cubit<SetPinState> {
  final SetPin setPinUsecase;
  SetPinCubit({required this.setPinUsecase}) : super(const SetPinInitial());

  Future<void> submitPin(String pin) async {
    emit(const SetPinLoading());
    try {
      await setPinUsecase(pin);
      emit(const SetPinSuccess(message: 'PIN set successfully'));
    } on DioError catch (e) {
      // Normalize to friendly message
      final msg = e.response?.data is Map && e.response?.data['message'] != null
          ? e.response?.data['message'].toString()
          : (e.message ?? 'Network error');
      emit(SetPinFailure(message: msg as String));
    } catch (e) {
      emit(SetPinFailure(message: e.toString()));
    }
  }
}
