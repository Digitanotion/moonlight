// import 'package:bloc/bloc.dart';
// import 'package:equatable/equatable.dart';
// import 'package:moonlight/features/wallet/domain/usecases/set_pin.dart';

// part 'set_pin_state.dart';

// class SetPinCubit extends Cubit<SetPinState> {
//   final SetPin _setPinUsecase;

//   SetPinCubit({required SetPin setPinUsecase})
//     : _setPinUsecase = setPinUsecase,
//       super(const SetPinInitial());

//   Future<void> submitPin(String pin) async {
//     try {
//       emit(const SetPinLoading());

//       final result = await _setPinUsecase.execute(pin: pin);

//       emit(SetPinSuccess(result));
//     } catch (e) {
//       emit(SetPinFailure(e.toString()));
//     }
//   }
// }
