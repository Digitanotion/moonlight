import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moonlight/core/theme/app_colors.dart';
import 'package:moonlight/core/utils/asset_paths.dart';
import 'package:moonlight/core/routing/route_names.dart';
import 'package:moonlight/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:moonlight/features/auth/presentation/widgets/auth_button.dart';
import 'package:moonlight/features/auth/presentation/widgets/custom_status_dialog.dart';

class EmailVerificationScreen extends StatefulWidget {
  final String email;
  const EmailVerificationScreen({super.key, required this.email});

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  final List<TextEditingController> _controllers = List.generate(
    6,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  bool isButtonEnabled = false;
  int resendSeconds = 45;

  @override
  void initState() {
    super.initState();
    for (int i = 0; i < 6; i++) {
      _controllers[i].addListener(_onCodeChanged);
    }
    _startResendTimer();
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _onCodeChanged() {
    setState(() {
      isButtonEnabled = _controllers.every((c) => c.text.isNotEmpty);
    });
    for (int i = 0; i < 5; i++) {
      if (_controllers[i].text.isNotEmpty) {
        _focusNodes[i + 1].requestFocus();
      }
    }
  }

  void _startResendTimer() {
    Future.delayed(const Duration(seconds: 1), () {
      if (resendSeconds > 0) {
        setState(() {
          resendSeconds--;
        });
        _startResendTimer();
      }
    });
  }

  void _onResend() {
    if (resendSeconds == 0) {
      // Trigger resend email via AuthBloc
      // context.read<AuthBloc>().add(ResendEmailVerification(widget.email));
      setState(() {
        resendSeconds = 45;
      });
      _startResendTimer();
    }
  }

  void _onVerify() {
    final code = _controllers.map((c) => c.text).join();
    // context.read<AuthBloc>().add(VerifyEmailRequested(widget.email, code));
  }

  Widget _buildCodeField(int index) {
    return SizedBox(
      width: 45,
      height: 55,
      child: TextField(
        controller: _controllers[index],
        focusNode: _focusNodes[index],
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white, fontSize: 20),
        maxLength: 1,
        decoration: InputDecoration(
          counterText: '',
          filled: true,
          fillColor: AppColors.dotInactive,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(
              color: index == 0 ? AppColors.primary : Colors.grey.shade700,
              width: 2,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.primary, width: 2),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.primary, AppColors.dark],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          children: [
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 10,
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 10,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Animated email icon
                    const Icon(
                      Icons.email_outlined,
                      size: 48,
                      color: AppColors.primary_2,
                    ),

                    const SizedBox(height: 24),

                    // Title
                    Text(
                      'Verify Your Email',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 24,
                          ),
                    ),

                    const SizedBox(height: 16),

                    // Instruction text
                    RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textWhite.withOpacity(0.9),
                          height: 1.5,
                        ),
                        children: [
                          const TextSpan(
                            text:
                                'We sent a verification link to your email address from\n',
                          ),
                          TextSpan(
                            text: 'api_smtp@moonlightstream.app',
                            style: TextStyle(
                              color: AppColors.secondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const TextSpan(text: ' with subject '),
                          TextSpan(
                            text: '"Verify Your Moonlight Account"',
                            style: TextStyle(
                              fontStyle: FontStyle.italic,
                              color: AppColors.secondary,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Email address with copy option
                    // Container(
                    //   padding: const EdgeInsets.symmetric(
                    //     horizontal: 16,
                    //     vertical: 12,
                    //   ),
                    //   decoration: BoxDecoration(
                    //     color: Colors.white.withOpacity(0.1),
                    //     borderRadius: BorderRadius.circular(12),
                    //     border: Border.all(
                    //       color: Colors.white.withOpacity(0.2),
                    //     ),
                    //   ),
                    //   child: Row(
                    //     mainAxisSize: MainAxisSize.min,
                    //     children: [
                    //       Text(
                    //         widget.email,
                    //         style: Theme.of(context).textTheme.bodyMedium
                    //             ?.copyWith(
                    //               color: Colors.white,
                    //               fontWeight: FontWeight.w500,
                    //             ),
                    //       ),
                    //       const SizedBox(width: 8),
                    //       GestureDetector(
                    //         onTap: () {
                    //           Clipboard.setData(
                    //             ClipboardData(text: widget.email),
                    //           );
                    //           ScaffoldMessenger.of(context).showSnackBar(
                    //             SnackBar(
                    //               content: Text(
                    //                 'Email address copied to clipboard',
                    //               ),
                    //               backgroundColor: AppColors.green,
                    //             ),
                    //           );
                    //         },
                    //         child: Icon(
                    //           Icons.content_copy,
                    //           size: 18,
                    //           color: AppColors.primary_2,
                    //         ),
                    //       ),
                    //     ],
                    //   ),
                    // ),
                    const SizedBox(height: 24),

                    // Important notes section
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.orange.withOpacity(0.3),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: Colors.orange,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Important:',
                                style: TextStyle(
                                  color: Colors.orange,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '• Check both your inbox and spam folder\n'
                            '• Link expires in 60 minutes\n'
                            '• Click the link to complete verification\n'
                            '• Didn\'t receive it? Try signing in, a new link will be sent to you',
                            style: TextStyle(
                              color: Colors.orange.withOpacity(0.9),
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 40),

                    // Action buttons
                    AuthButton(
                      text: "Sign In",
                      onPressed: () {
                        Navigator.pushNamed(context, RouteNames.login);
                      },
                    ),
                    // const SizedBox(height: 16),

                    // Support text
                    // TextButton(
                    //   onPressed: () {
                    //     // Open support email or help center
                    //     // _openSupport();
                    //   },
                    //   child: Text(
                    //     'Need help? Contact Support',
                    //     style: TextStyle(
                    //       color: Colors.white.withOpacity(0.7),
                    //       decoration: TextDecoration.underline,
                    //     ),
                    //   ),
                    // ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
