// // lib/features/wallet/presentation/pages/set_pin_page.dart
// import 'package:flutter/material.dart';
// import 'package:flutter_bloc/flutter_bloc.dart';
// import 'package:moonlight/core/theme/app_colors.dart';
// import 'package:moonlight/features/wallet/presentation/cubit/set_pin_cubit.dart';
// import 'package:moonlight/core/injection_container.dart' show sl;
// import 'package:moonlight/widgets/top_snack.dart';

// enum _PinStage { enter, confirm }

// class SetPinPage extends StatefulWidget {
//   /// Optional callback when pin is set
//   final VoidCallback? onSuccess;

//   const SetPinPage({Key? key, this.onSuccess}) : super(key: key);

//   @override
//   State<SetPinPage> createState() => _SetPinPageState();
// }

// class _SetPinPageState extends State<SetPinPage>
//     with SingleTickerProviderStateMixin {
//   final List<String> _enteredPin = [];
//   final int _pinLength = 4;

//   // Keep a reference to the cubit — create in initState to avoid context scoping issues.
//   late final SetPinCubit _cubit;

//   _PinStage _stage = _PinStage.enter;
//   String? _firstPin; // stores first entry for confirmation

//   // For shake animation on mismatch
//   late final AnimationController _shakeController;
//   late final Animation<double> _shakeAnimation;

//   @override
//   void initState() {
//     super.initState();
//     // create cubit instance from GetIt
//     _cubit = sl<SetPinCubit>();

//     _shakeController = AnimationController(
//       vsync: this,
//       duration: const Duration(milliseconds: 450),
//     );
//     _shakeAnimation =
//         Tween<double>(
//             begin: 0,
//             end: 8,
//           ).chain(CurveTween(curve: Curves.elasticIn)).animate(_shakeController)
//           ..addStatusListener((status) {
//             if (status == AnimationStatus.completed) {
//               _shakeController.reset();
//             }
//           });
//   }

//   @override
//   void dispose() {
//     // close cubit we created
//     try {
//       _cubit.close();
//     } catch (_) {}
//     _shakeController.dispose();
//     super.dispose();
//   }

//   void _onNumberPressed(String number) {
//     if (_enteredPin.length < _pinLength) {
//       setState(() => _enteredPin.add(number));
//     }
//   }

//   void _onBackspacePressed() {
//     if (_enteredPin.isNotEmpty) {
//       setState(() => _enteredPin.removeLast());
//     }
//   }

//   void _clearAll() {
//     setState(() {
//       _enteredPin.clear();
//     });
//   }

//   /// Called when user presses the Set PIN button (only on confirm stage)
//   void _onSetPinPressed() {
//     final pin = _enteredPin.join();
//     // call cubit directly — we own the instance so no context lookup required
//     _cubit.submitPin(pin);
//   }

//   /// Pressed when user completes entering 4 digits while in "enter" stage:
//   /// move to confirm stage automatically so user re-enters to confirm.
//   void _advanceIfNeeded() {
//     if (_enteredPin.length == _pinLength) {
//       if (_stage == _PinStage.enter) {
//         _firstPin = _enteredPin.join();
//         // switch to confirm stage and clear current entry to accept confirmation
//         setState(() {
//           _stage = _PinStage.confirm;
//           _enteredPin.clear();
//         });
//       }
//     }
//   }

//   /// Called to evaluate confirmation when user has entered 4 digits in confirm stage.
//   void _checkConfirmation() {
//     if (_stage == _PinStage.confirm && _enteredPin.length == _pinLength) {
//       final confirm = _enteredPin.join();
//       if (_firstPin == confirm) {
//         // enable Set button — we don't auto submit, user taps button
//         TopSnack.info(context, 'PINs match — tap "Set PIN" to proceed');
//       } else {
//         // mismatch: notify, shake, clear confirm input
//         TopSnack.error(context, 'PINs do not match. Try again.');
//         _shakeController.forward();
//         setState(() => _enteredPin.clear());
//       }
//     }
//   }

//   Widget _buildPinDots() {
//     return AnimatedBuilder(
//       animation: _shakeController,
//       builder: (context, child) {
//         final dx =
//             _shakeAnimation.value *
//             (_shakeController.isAnimating
//                 ? (_shakeController.value.isFinite
//                       ? (_shakeController.value % 2 == 0 ? 1 : -1)
//                       : 1)
//                 : 0);
//         return Transform.translate(offset: Offset(dx, 0), child: child);
//       },
//       child: Row(
//         mainAxisAlignment: MainAxisAlignment.center,
//         children: List.generate(_pinLength, (index) {
//           final filled = index < _enteredPin.length;
//           return AnimatedContainer(
//             duration: const Duration(milliseconds: 180),
//             margin: const EdgeInsets.symmetric(horizontal: 10),
//             width: filled ? 18 : 14,
//             height: filled ? 18 : 14,
//             decoration: BoxDecoration(
//               shape: BoxShape.circle,
//               color: filled ? Colors.deepOrangeAccent : Colors.white24,
//               boxShadow: filled
//                   ? [
//                       BoxShadow(
//                         color: Colors.deepOrangeAccent.withOpacity(0.36),
//                         blurRadius: 6,
//                         spreadRadius: 1,
//                       ),
//                     ]
//                   : null,
//             ),
//           );
//         }),
//       ),
//     );
//   }

//   Widget _buildNumpad({required bool disabled}) {
//     Widget button({
//       String? text,
//       IconData? icon,
//       required VoidCallback onPressed,
//     }) {
//       return Opacity(
//         opacity: disabled ? 0.5 : 1.0,
//         child: Padding(
//           padding: const EdgeInsets.all(10.0),
//           child: Material(
//             color: Colors.transparent,
//             child: InkWell(
//               onTap: disabled ? null : onPressed,
//               borderRadius: BorderRadius.circular(14),
//               child: Container(
//                 decoration: BoxDecoration(
//                   color: Colors.white.withOpacity(0.06),
//                   borderRadius: BorderRadius.circular(14),
//                 ),
//                 child: Center(
//                   child: icon != null
//                       ? Icon(icon, color: Colors.white, size: 22)
//                       : Text(
//                           text!,
//                           style: const TextStyle(
//                             color: Colors.white,
//                             fontSize: 22,
//                             fontWeight: FontWeight.w600,
//                           ),
//                         ),
//                 ),
//               ),
//             ),
//           ),
//         ),
//       );
//     }

//     return GridView.count(
//       shrinkWrap: true,
//       crossAxisCount: 3,
//       childAspectRatio: 1.25,
//       padding: const EdgeInsets.symmetric(horizontal: 28),
//       physics: const NeverScrollableScrollPhysics(),
//       children: [
//         for (int i = 1; i <= 9; i++)
//           button(
//             text: i.toString(),
//             onPressed: () {
//               _onNumberPressed(i.toString());
//               WidgetsBinding.instance.addPostFrameCallback((_) {
//                 _advanceIfNeeded();
//                 _checkConfirmation();
//               });
//             },
//           ),
//         // clear/back action
//         button(
//           icon: Icons.clear,
//           onPressed: () {
//             if (_enteredPin.isEmpty && _stage == _PinStage.confirm) {
//               setState(() {
//                 _stage = _PinStage.enter;
//                 _enteredPin.clear();
//                 _firstPin = null;
//               });
//             } else {
//               _clearAll();
//             }
//           },
//         ),
//         button(
//           text: '0',
//           onPressed: () {
//             _onNumberPressed('0');
//             WidgetsBinding.instance.addPostFrameCallback((_) {
//               _advanceIfNeeded();
//               _checkConfirmation();
//             });
//           },
//         ),
//         button(icon: Icons.backspace, onPressed: _onBackspacePressed),
//       ],
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     // Provide the cubit instance we created via BlocProvider.value to guarantee scoping.
//     return BlocProvider<SetPinCubit>.value(
//       value: _cubit,
//       child: BlocConsumer<SetPinCubit, SetPinState>(
//         listener: (context, state) {
//           if (state is SetPinSuccess) {
//             TopSnack.success(context, state.message);
//             widget.onSuccess?.call();
//             Navigator.of(context).maybePop(true);
//           } else if (state is SetPinFailure) {
//             TopSnack.error(context, state.message);
//             setState(() {
//               _enteredPin.clear();
//             });
//           }
//         },
//         builder: (context, state) {
//           final loading = state is SetPinLoading;
//           final disabled = loading;
//           final inConfirm = _stage == _PinStage.confirm;
//           final canSet =
//               inConfirm &&
//               _enteredPin.length == _pinLength &&
//               _firstPin == _enteredPin.join();

//           final title = _stage == _PinStage.enter
//               ? 'Create a 4-digit PIN'
//               : 'Confirm your PIN';
//           final subtitle = _stage == _PinStage.enter
//               ? 'Enter a new 4-digit PIN that will secure withdrawals.'
//               : 'Re-enter the PIN to confirm.';

//           return Stack(
//             children: [
//               Scaffold(
//                 backgroundColor: const Color(0xFF060522),
//                 appBar: AppBar(
//                   backgroundColor: Colors.transparent,
//                   elevation: 0,
//                   leading: IconButton(
//                     icon: const Icon(
//                       Icons.arrow_back_ios_new,
//                       color: Colors.white,
//                     ),
//                     onPressed: () {
//                       if (_stage == _PinStage.confirm && _enteredPin.isEmpty) {
//                         setState(() {
//                           _stage = _PinStage.enter;
//                           _firstPin = null;
//                         });
//                       } else {
//                         Navigator.pop(context);
//                       }
//                     },
//                   ),
//                   title: const Text(
//                     'Set Withdrawal PIN',
//                     style: TextStyle(color: Colors.white),
//                   ),
//                   centerTitle: true,
//                 ),
//                 body: Column(
//                   children: [
//                     const Spacer(flex: 2),
//                     Column(
//                       children: [
//                         const Icon(
//                           Icons.lock,
//                           size: 72,
//                           color: Colors.deepOrangeAccent,
//                         ),
//                         const SizedBox(height: 18),
//                         Text(
//                           title,
//                           style: const TextStyle(
//                             fontSize: 20,
//                             fontWeight: FontWeight.bold,
//                             color: Colors.white,
//                           ),
//                         ),
//                         const SizedBox(height: 8),
//                         Padding(
//                           padding: const EdgeInsets.symmetric(horizontal: 36.0),
//                           child: Text(
//                             subtitle,
//                             style: const TextStyle(color: Colors.white70),
//                             textAlign: TextAlign.center,
//                           ),
//                         ),
//                         const SizedBox(height: 22),
//                         _buildPinDots(),
//                         const SizedBox(height: 10),
//                         if (_stage == _PinStage.confirm && _firstPin != null)
//                           Padding(
//                             padding: const EdgeInsets.symmetric(
//                               horizontal: 36.0,
//                             ),
//                             child: Text(
//                               'First PIN: ${_firstPin!.replaceAll(RegExp(r'.'), '•')}',
//                               style: const TextStyle(
//                                 color: Colors.white38,
//                                 fontSize: 12,
//                               ),
//                             ),
//                           ),
//                       ],
//                     ),
//                     const Spacer(flex: 2),
//                     _buildNumpad(disabled: disabled),
//                     const SizedBox(height: 8),
//                     Padding(
//                       padding: const EdgeInsets.symmetric(
//                         horizontal: 28.0,
//                         vertical: 10,
//                       ),
//                       child: Row(
//                         children: [
//                           Expanded(
//                             child: ElevatedButton(
//                               onPressed: (!canSet || disabled)
//                                   ? null
//                                   : _onSetPinPressed,
//                               style: ElevatedButton.styleFrom(
//                                 padding: const EdgeInsets.symmetric(
//                                   vertical: 14,
//                                 ),
//                                 backgroundColor: canSet
//                                     ? Colors.deepOrangeAccent
//                                     : Colors.white12,
//                                 shape: RoundedRectangleBorder(
//                                   borderRadius: BorderRadius.circular(12),
//                                 ),
//                                 elevation: 0,
//                               ),
//                               child: Text(
//                                 inConfirm ? 'Set PIN' : 'Continue',
//                                 style: const TextStyle(
//                                   fontSize: 16,
//                                   fontWeight: FontWeight.w600,
//                                 ),
//                               ),
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),
//                     const SizedBox(height: 12),
//                     Padding(
//                       padding: const EdgeInsets.only(bottom: 18.0),
//                       child: TextButton(
//                         onPressed: disabled
//                             ? null
//                             : () {
//                                 showDialog(
//                                   context: context,
//                                   builder: (c) => AlertDialog(
//                                     title: const Text('Why a PIN?'),
//                                     backgroundColor: AppColors.bluePrimary,
//                                     content: const Text(
//                                       'Your PIN secures withdrawals — keep it secret.',
//                                     ),
//                                     actions: [
//                                       TextButton(
//                                         onPressed: () => Navigator.pop(c),
//                                         child: const Text(
//                                           'OK',
//                                           style: TextStyle(
//                                             color: Colors.deepOrangeAccent,
//                                           ),
//                                         ),
//                                       ),
//                                     ],
//                                   ),
//                                 );
//                               },
//                         child: const Text(
//                           'Why do I need a PIN?',
//                           style: TextStyle(color: Colors.white70),
//                         ),
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//               if (loading)
//                 Container(
//                   color: Colors.black.withOpacity(0.45),
//                   child: const Center(child: CircularProgressIndicator()),
//                 ),
//             ],
//           );
//         },
//       ),
//     );
//   }

//   // Keep checks in a post-frame callback so state updates settle first
//   @override
//   void didChangeDependencies() {
//     super.didChangeDependencies();
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       _advanceIfNeeded();
//       _checkConfirmation();
//     });
//   }
// }
