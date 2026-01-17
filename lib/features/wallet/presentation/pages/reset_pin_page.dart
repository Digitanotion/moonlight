import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moonlight/core/theme/app_colors.dart';
import 'package:moonlight/features/wallet/presentation/cubit/reset_pin_cubit.dart';
import 'package:moonlight/core/injection_container.dart' show sl;
import 'package:moonlight/widgets/top_snack.dart';

enum _ResetPinStage { current, newPin, confirm }

class ResetPinPage extends StatefulWidget {
  final VoidCallback? onSuccess;

  const ResetPinPage({Key? key, this.onSuccess}) : super(key: key);

  @override
  State<ResetPinPage> createState() => _ResetPinPageState();
}

class _ResetPinPageState extends State<ResetPinPage>
    with SingleTickerProviderStateMixin {
  final List<String> _enteredPin = [];
  final int _pinLength = 4;

  late final ResetPinCubit _cubit;

  _ResetPinStage _stage = _ResetPinStage.current;
  String? _newPin; // stores new PIN for confirmation
  String? _currentPin; // stores current PIN

  late final AnimationController _shakeController;
  late final Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _cubit = sl<ResetPinCubit>();

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

  void _verifyCurrentPin() {
    if (_enteredPin.length == _pinLength) {
      final currentPin = _enteredPin.join();
      _cubit.verifyCurrentPin(currentPin);
    }
  }

  void _submitReset() {
    if (_enteredPin.length == _pinLength && _newPin != null) {
      final confirmPin = _enteredPin.join();

      if (_newPin == confirmPin) {
        if (_currentPin != null) {
          _cubit.resetPin(
            currentPin: _currentPin!,
            newPin: _newPin!,
            confirmNewPin: confirmPin,
          );
        } else {
          // This shouldn't happen if UI logic is correct
          TopSnack.error(
            context,
            'Current PIN not verified. Please start over.',
          );
          _resetToInitial();
        }
      } else {
        _showPinMismatchError();
      }
    } else {
      // Not enough digits entered
      TopSnack.error(context, 'Please enter all 4 digits');
      _shakeController.forward();
    }
  }

  void _resetToInitial() {
    setState(() {
      _stage = _ResetPinStage.current;
      _enteredPin.clear();
      _currentPin = null;
      _newPin = null;
    });
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
      Future.delayed(const Duration(milliseconds: 150), () {
        switch (_stage) {
          case _ResetPinStage.current:
            _verifyCurrentPin();
            break;
          case _ResetPinStage.newPin:
            _advanceToNewPinStage();
            break;
          case _ResetPinStage.confirm:
            // _submitReset();
            break;
        }
      });
    }
  }

  void _advanceToNewPinStage() {
    if (_stage == _ResetPinStage.current) {
      // Verify we have a PIN before advancing
      if (_enteredPin.length == _pinLength) {
        _currentPin = _enteredPin.join();
        setState(() {
          _stage = _ResetPinStage.newPin;
          _enteredPin.clear();
        });
      }
    } else if (_stage == _ResetPinStage.newPin) {
      // Verify we have a new PIN before advancing to confirm
      if (_enteredPin.length == _pinLength) {
        _newPin = _enteredPin.join();
        setState(() {
          _stage = _ResetPinStage.confirm;
          _enteredPin.clear();
        });
      }
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
      case _ResetPinStage.current:
        return Colors.orangeAccent;
      case _ResetPinStage.newPin:
        return Colors.blueAccent;
      case _ResetPinStage.confirm:
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
            if (_enteredPin.isEmpty) {
              switch (_stage) {
                case _ResetPinStage.newPin:
                  setState(() {
                    _stage = _ResetPinStage.current;
                    _enteredPin.clear();
                    _currentPin = null;
                  });
                  break;
                case _ResetPinStage.confirm:
                  setState(() {
                    _stage = _ResetPinStage.newPin;
                    _enteredPin.clear();
                    _newPin = null;
                  });
                  break;
                default:
                  _clearAll();
              }
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

  Widget _buildStageIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _StageDot(
          active: _stage == _ResetPinStage.current,
          completed: _stage.index > 0,
          label: 'Current',
          color: Colors.orangeAccent,
        ),
        Container(
          width: 30,
          height: 2,
          color: _stage.index >= 1 ? Colors.blueAccent : Colors.white24,
        ),
        _StageDot(
          active: _stage == _ResetPinStage.newPin,
          completed: _stage.index > 1,
          label: 'New',
          color: Colors.blueAccent,
        ),
        Container(
          width: 30,
          height: 2,
          color: _stage.index >= 2 ? Colors.greenAccent : Colors.white24,
        ),
        _StageDot(
          active: _stage == _ResetPinStage.confirm,
          completed: false,
          label: 'Confirm',
          color: Colors.greenAccent,
        ),
      ],
    );
  }

  String _getTitle() {
    switch (_stage) {
      case _ResetPinStage.current:
        return 'Enter Current PIN';
      case _ResetPinStage.newPin:
        return 'Create New PIN';
      case _ResetPinStage.confirm:
        return 'Confirm New PIN';
    }
  }

  String _getSubtitle() {
    switch (_stage) {
      case _ResetPinStage.current:
        return 'First, verify your current 4-digit PIN to continue.';
      case _ResetPinStage.newPin:
        return 'Enter a new 4-digit PIN that will secure your wallet.';
      case _ResetPinStage.confirm:
        return 'Re-enter the new PIN to confirm.';
    }
  }

  Widget _getStageIcon() {
    switch (_stage) {
      case _ResetPinStage.current:
        return Icon(
          Icons.lock_clock_rounded,
          size: 72,
          color: _getStageColor(),
        );
      case _ResetPinStage.newPin:
        return Icon(
          Icons.lock_reset_rounded,
          size: 72,
          color: _getStageColor(),
        );
      case _ResetPinStage.confirm:
        return Icon(Icons.lock_open_rounded, size: 72, color: _getStageColor());
    }
  }

  bool _canProceed() {
    if (_enteredPin.length != _pinLength) return false;

    switch (_stage) {
      case _ResetPinStage.current:
        return true;
      case _ResetPinStage.newPin:
        return true;
      case _ResetPinStage.confirm:
        // Make sure we have both newPin and currentPin
        return _newPin != null &&
            _currentPin != null &&
            _newPin == _enteredPin.join();
    }
  }

  String _getButtonText() {
    switch (_stage) {
      case _ResetPinStage.current:
        return 'Verify';
      case _ResetPinStage.newPin:
        return 'Continue';
      case _ResetPinStage.confirm:
        return 'Reset PIN';
    }
  }

  void _handleBackButton() {
    if (_stage == _ResetPinStage.confirm && _enteredPin.isEmpty) {
      setState(() {
        _stage = _ResetPinStage.newPin;
        _newPin = null;
      });
    } else if (_stage == _ResetPinStage.newPin && _enteredPin.isEmpty) {
      setState(() {
        _stage = _ResetPinStage.current;
        _currentPin = null;
      });
    } else {
      Navigator.pop(context);
    }
  }

  void _handleApiError() {
    setState(() {
      _enteredPin.clear();
      // Only reset current PIN if we're still on the current stage
      // or if we haven't successfully verified it yet
      if (_stage == _ResetPinStage.current) {
        _currentPin = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<ResetPinCubit>.value(
      value: _cubit,
      child: BlocConsumer<ResetPinCubit, ResetPinState>(
        listener: (context, state) {
          print(
            'ResetPinState: $state, _currentPin: $_currentPin, _stage: $_stage',
          );

          if (state is ResetPinSuccess) {
            TopSnack.success(context, state.message);
            widget.onSuccess?.call();
            Navigator.of(context).pop(true);
          } else if (state is ResetPinCurrentError) {
            TopSnack.error(context, state.message);
            // Don't clear _currentPin here - it should already be null if verification failed
            setState(() {
              _enteredPin.clear();
            });
            _shakeController.forward();
          } else if (state is ResetPinError) {
            TopSnack.error(context, state.message);
            // Only handle API errors that occur during reset
            setState(() {
              _enteredPin.clear();
            });
            _shakeController.forward();
          } else if (state is ResetPinCurrentVerified) {
            // This should set _currentPin
            if (_enteredPin.length == _pinLength) {
              _currentPin = _enteredPin.join();
            }
            setState(() {
              _stage = _ResetPinStage.newPin;
              _enteredPin.clear();
            });
          }
        },
        builder: (context, state) {
          final loading = state is ResetPinLoading;
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
                  title: const Text(
                    'Reset Wallet PIN',
                    style: TextStyle(color: Colors.white),
                  ),
                  centerTitle: true,
                ),
                body: Column(
                  children: [
                    const Spacer(flex: 1),
                    Column(
                      children: [
                        _getStageIcon(),
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
                        const SizedBox(height: 24),
                        _buildStageIndicator(),
                        const SizedBox(height: 24),
                        _buildPinDots(),
                        const SizedBox(height: 10),
                        if (_stage == _ResetPinStage.confirm &&
                            _currentPin == null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              '⚠️ Current PIN verification needed',
                              style: TextStyle(
                                color: Colors.orangeAccent,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        if (_stage == _ResetPinStage.confirm && _newPin != null)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 36.0,
                            ),
                            child: Text(
                              'New PIN: ${_newPin!.replaceAll(RegExp(r'.'), '•')}',
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
                                  : () {
                                      switch (_stage) {
                                        case _ResetPinStage.current:
                                          _verifyCurrentPin();
                                          break;
                                        case _ResetPinStage.newPin:
                                          _advanceToNewPinStage();
                                          break;
                                        case _ResetPinStage.confirm:
                                          _submitReset();
                                          break;
                                      }
                                    },
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
                    if (_stage == _ResetPinStage.current)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 18.0),
                        child: TextButton(
                          onPressed: disabled
                              ? null
                              : () {
                                  showDialog(
                                    context: context,
                                    builder: (c) => AlertDialog(
                                      backgroundColor: AppColors.bluePrimary,
                                      title: const Text('Forgot PIN?'),
                                      content: const Text(
                                        'If you\'ve forgotten your current PIN, please contact support to reset it securely.',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(c),
                                          child: const Text(
                                            'Contact Support',
                                            style: TextStyle(
                                              color: Colors.deepOrangeAccent,
                                            ),
                                          ),
                                        ),
                                        TextButton(
                                          onPressed: () => Navigator.pop(c),
                                          child: const Text(
                                            'OK',
                                            style: TextStyle(
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                          child: const Text(
                            'Forgot PIN?',
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
}

class _StageDot extends StatelessWidget {
  final bool active;
  final bool completed;
  final String label;
  final Color color;

  const _StageDot({
    required this.active,
    required this.completed,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active || completed ? color : Colors.white24,
            border: active ? Border.all(color: Colors.white, width: 2) : null,
          ),
          child: completed
              ? const Icon(Icons.check, size: 14, color: Colors.white)
              : null,
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: active || completed ? color : Colors.white38,
            fontSize: 12,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
