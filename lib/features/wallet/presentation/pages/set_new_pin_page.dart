import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moonlight/core/theme/app_colors.dart';
import 'package:moonlight/features/wallet/presentation/cubit/set_new_pin_cubit.dart';
import 'package:moonlight/core/injection_container.dart' show sl;
import 'package:moonlight/widgets/top_snack.dart';

enum _NewPinStage { enter, confirm }

class SetNewPinPage extends StatefulWidget {
  final VoidCallback? onSuccess;
  final bool isInitialSetup;

  const SetNewPinPage({Key? key, this.onSuccess, this.isInitialSetup = false})
    : super(key: key);

  @override
  State<SetNewPinPage> createState() => _SetNewPinPageState();
}

class _SetNewPinPageState extends State<SetNewPinPage>
    with SingleTickerProviderStateMixin {
  final List<String> _enteredPin = [];
  final int _pinLength = 4;

  late final SetNewPinCubit _cubit;

  _NewPinStage _stage = _NewPinStage.enter;
  String? _firstPin; // stores first entry for confirmation

  late final AnimationController _shakeController;
  late final Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _cubit = sl<SetNewPinCubit>();

    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _shakeAnimation =
        Tween<double>(
            begin: 0,
            end: 8,
          ).chain(CurveTween(curve: Curves.elasticIn)).animate(_shakeController)
          ..addStatusListener((status) {
            if (status == AnimationStatus.completed) {
              _shakeController.reset();
            }
          });
  }

  @override
  void dispose() {
    _cubit.close();
    _shakeController.dispose();
    super.dispose();
  }

  void _onNumberPressed(String number) {
    if (_enteredPin.length < _pinLength) {
      setState(() => _enteredPin.add(number));
    }
  }

  void _onBackspacePressed() {
    if (_enteredPin.isNotEmpty) {
      setState(() => _enteredPin.removeLast());
    }
  }

  void _clearAll() {
    setState(() => _enteredPin.clear());
  }

  void _submitPin() {
    if (_enteredPin.length == _pinLength) {
      final pin = _enteredPin.join();
      if (_stage == _NewPinStage.enter) {
        _firstPin = pin;
        setState(() {
          _stage = _NewPinStage.confirm;
          _enteredPin.clear();
        });
      } else if (_stage == _NewPinStage.confirm) {
        if (_firstPin == pin) {
          // Call API to set PIN
          _cubit.setNewPin(pin: pin, confirmPin: pin);
        } else {
          _showPinMismatchError();
        }
      }
    }
  }

  void _showPinMismatchError() {
    TopSnack.error(context, 'PINs do not match. Please try again.');
    _shakeController.forward();
    setState(() {
      _enteredPin.clear();
    });
  }

  void _handleAutoAdvance() {
    if (_enteredPin.length == _pinLength) {
      Future.delayed(const Duration(milliseconds: 150), _submitPin);
    }
  }

  Widget _buildPinDots() {
    return AnimatedBuilder(
      animation: _shakeController,
      builder: (context, child) {
        final dx =
            _shakeAnimation.value *
            (_shakeController.isAnimating
                ? (_shakeController.value % 2 == 0 ? 1 : -1)
                : 0);
        return Transform.translate(offset: Offset(dx, 0), child: child);
      },
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(_pinLength, (index) {
          final filled = index < _enteredPin.length;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            margin: const EdgeInsets.symmetric(horizontal: 10),
            width: filled ? 18 : 14,
            height: filled ? 18 : 14,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: filled ? _getStageColor() : Colors.white24,
              boxShadow: filled
                  ? [
                      BoxShadow(
                        color: _getStageColor().withOpacity(0.36),
                        blurRadius: 6,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
          );
        }),
      ),
    );
  }

  Color _getStageColor() {
    switch (_stage) {
      case _NewPinStage.enter:
        return Colors.blueAccent;
      case _NewPinStage.confirm:
        return Colors.greenAccent;
    }
  }

  Widget _buildNumpad({required bool disabled}) {
    Widget button({
      String? text,
      IconData? icon,
      required VoidCallback onPressed,
    }) {
      return Opacity(
        opacity: disabled ? 0.5 : 1.0,
        child: Padding(
          padding: const EdgeInsets.all(10.0),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: disabled ? null : onPressed,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: icon != null
                      ? Icon(icon, color: Colors.white, size: 22)
                      : Text(
                          text!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return GridView.count(
      shrinkWrap: true,
      crossAxisCount: 3,
      childAspectRatio: 1.25,
      padding: const EdgeInsets.symmetric(horizontal: 28),
      physics: const NeverScrollableScrollPhysics(),
      children: [
        for (int i = 1; i <= 9; i++)
          button(
            text: i.toString(),
            onPressed: () {
              if (disabled) return;
              _onNumberPressed(i.toString());
              _handleAutoAdvance();
            },
          ),
        // Clear button
        button(
          icon: Icons.clear,
          onPressed: () {
            if (disabled) return;
            if (_enteredPin.isEmpty && _stage == _NewPinStage.confirm) {
              setState(() {
                _stage = _NewPinStage.enter;
                _enteredPin.clear();
                _firstPin = null;
              });
            } else {
              _clearAll();
            }
          },
        ),
        button(
          text: '0',
          onPressed: () {
            if (disabled) return;
            _onNumberPressed('0');
            _handleAutoAdvance();
          },
        ),
        button(
          icon: Icons.backspace,
          onPressed: disabled ? () {} : _onBackspacePressed,
        ),
      ],
    );
  }

  String _getTitle() {
    return widget.isInitialSetup
        ? 'Set Your PIN'
        : _stage == _NewPinStage.enter
        ? 'Create New PIN'
        : 'Confirm New PIN';
  }

  String _getSubtitle() {
    return widget.isInitialSetup
        ? 'Create a 4-digit PIN to secure your wallet withdrawals'
        : _stage == _NewPinStage.enter
        ? 'Enter a new 4-digit PIN to secure withdrawals.'
        : 'Re-enter the PIN to confirm.';
  }

  bool _canProceed() {
    if (_stage == _NewPinStage.enter) {
      return _enteredPin.length == _pinLength;
    } else {
      return _enteredPin.length == _pinLength &&
          _firstPin == _enteredPin.join();
    }
  }

  String _getButtonText() {
    if (_stage == _NewPinStage.enter) {
      return 'Continue';
    } else {
      return widget.isInitialSetup ? 'Set PIN' : 'Confirm & Set';
    }
  }

  void _handleBackButton() {
    if (_stage == _NewPinStage.confirm && _enteredPin.isEmpty) {
      setState(() {
        _stage = _NewPinStage.enter;
        _firstPin = null;
      });
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<SetNewPinCubit>.value(
      value: _cubit,
      child: BlocConsumer<SetNewPinCubit, SetNewPinState>(
        listener: (context, state) {
          if (state is SetNewPinSuccess) {
            TopSnack.success(context, state.message);
            widget.onSuccess?.call();
            Navigator.of(context).pop(true);
          } else if (state is SetNewPinError) {
            TopSnack.error(context, state.message);
            _handleApiError(state);
          }
        },
        builder: (context, state) {
          final loading = state is SetNewPinLoading;
          final disabled = loading;

          return Stack(
            children: [
              Scaffold(
                backgroundColor: const Color(0xFF060522),
                appBar: AppBar(
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  leading: IconButton(
                    icon: const Icon(
                      Icons.arrow_back_ios_new,
                      color: Colors.white,
                    ),
                    onPressed: loading ? null : _handleBackButton,
                  ),
                  title: Text(
                    widget.isInitialSetup ? 'Set PIN' : 'Set New PIN',
                    style: const TextStyle(color: Colors.white),
                  ),
                  centerTitle: true,
                ),
                body: Column(
                  children: [
                    const Spacer(flex: 2),
                    Column(
                      children: [
                        Icon(
                          _stage == _NewPinStage.enter
                              ? Icons.lock_outline_rounded
                              : Icons.lock_rounded,
                          size: 72,
                          color: _getStageColor(),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          _getTitle(),
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 36.0),
                          child: Text(
                            _getSubtitle(),
                            style: const TextStyle(color: Colors.white70),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 22),
                        _buildPinDots(),
                        const SizedBox(height: 10),
                        if (_stage == _NewPinStage.confirm && _firstPin != null)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 36.0,
                            ),
                            child: Text(
                              'First PIN: ${_firstPin!.replaceAll(RegExp(r'.'), '•')}',
                              style: const TextStyle(
                                color: Colors.white38,
                                fontSize: 12,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const Spacer(flex: 2),
                    _buildNumpad(disabled: disabled),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 28.0,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: (!_canProceed() || disabled)
                                  ? null
                                  : _submitPin,
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                backgroundColor: _canProceed()
                                    ? _getStageColor()
                                    : Colors.white12,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 0,
                              ),
                              child: Text(
                                _getButtonText(),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 18.0),
                      child: TextButton(
                        onPressed: disabled
                            ? null
                            : () {
                                showDialog(
                                  context: context,
                                  builder: (c) => AlertDialog(
                                    title: const Text('PIN Security'),
                                    backgroundColor: AppColors.bluePrimary,
                                    content: const Text(
                                      'Your PIN secures all wallet withdrawals. '
                                      'Never share it with anyone. '
                                      'If you forget your PIN, you can reset it using the "Reset PIN" option.',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(c),
                                        child: const Text(
                                          'OK',
                                          style: TextStyle(
                                            color: Colors.deepOrangeAccent,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                        child: const Text(
                          'Why do I need a PIN?',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (loading)
                Container(
                  color: Colors.black.withOpacity(0.45),
                  child: const Center(
                    child: CircularProgressIndicator(
                      color: Colors.deepOrangeAccent,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  void _handleApiError(SetNewPinError state) {
    setState(() {
      _enteredPin.clear();
      if (state.errorType == SetNewPinErrorType.pinAlreadySet) {
        // Go back to previous screen if PIN is already set
        Future.delayed(const Duration(milliseconds: 500), () {
          Navigator.pop(context);
        });
      }
    });
  }
}
