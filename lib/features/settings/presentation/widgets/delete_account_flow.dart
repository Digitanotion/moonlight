// lib/features/settings/presentation/widgets/delete_account_flow.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moonlight/core/injection_container.dart';
import 'package:moonlight/core/theme/app_colors.dart';
import 'package:moonlight/core/theme/app_text_styles.dart';
import 'package:moonlight/features/settings/presentation/cubit/account_settings_cubit.dart';
import 'package:moonlight/widgets/ml_confirm_dialog.dart';
import 'package:intl/intl.dart';

class DeleteAccountFlow extends StatefulWidget {
  const DeleteAccountFlow({super.key});

  @override
  State<DeleteAccountFlow> createState() => _DeleteAccountFlowState();
}

class _DeleteAccountFlowState extends State<DeleteAccountFlow> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();
  final _feedbackController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _showPassword = false;
  bool _hasLocalPassword = true;

  // ✅ Store cubit reference
  late final AccountSettingsCubit _cubit;

  @override
  void initState() {
    super.initState();
    _cubit = sl<AccountSettingsCubit>(); // ✅ Get cubit ONCE
    _loadDeletionStatus();
  }

  Future<void> _loadDeletionStatus() async {
    await _cubit.fetchDeletionStatus(); // ✅ Use stored cubit
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AccountSettingsCubit, AccountSettingsState>(
      bloc: _cubit, // ✅ Use stored cubit
      listener: (context, state) {
        if (state.deletionRequested) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Deletion requested successfully!'),
              backgroundColor: Colors.green,
            ),
          );

          Future.delayed(const Duration(seconds: 2), () {
            Navigator.pop(context);
          });
        }

        if (state.deletionCancelled) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Deletion cancelled successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }

        if (state.deletionError != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.deletionError!),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
      builder: (context, state) {
        // ✅ Use state from cubit, not local variable
        final isPendingDeletion = state.hasPendingDeletion;

        return Scaffold(
          backgroundColor: const Color(0xFF060522),
          appBar: AppBar(
            title: Text(
              isPendingDeletion ? 'Deletion Scheduled' : 'Delete Account',
              style: AppTextStyles.heading2.copyWith(color: Colors.white),
            ),
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primary, Color(0xFF0A0A0F)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: isPendingDeletion
                  ? _buildPendingDeletionView(state) // Pass state
                  : _buildDeletionRequestView(state), // ✅ Pass state here too
            ),
          ),
        );
      },
    );
  }

  Widget _buildPendingDeletionView(AccountSettingsState state) {
    final scheduledDate = state.scheduledDeletionDate != null
        ? DateTime.tryParse(state.scheduledDeletionDate!)
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Status Card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.orange),
                  const SizedBox(width: 8),
                  Text(
                    'Account Deletion Scheduled',
                    style: AppTextStyles.heading3.copyWith(color: Colors.white),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (scheduledDate != null)
                _buildInfoRow(
                  'Scheduled for:',
                  DateFormat.yMMMMd().add_jm().format(scheduledDate),
                ),
              _buildInfoRow('Days remaining:', '${state.daysRemaining} days'),
              _buildInfoRow('Grace period:', '${state.gracePeriodDays} days'),
              const SizedBox(height: 8),
              if (state.daysRemaining < 2)
                Text(
                  '⚠️ Final reminder sent. Account will be deleted soon.',
                  style: AppTextStyles.body.copyWith(color: Colors.orange),
                ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // What happens next
        Text(
          'What happens next:',
          style: AppTextStyles.heading3.copyWith(color: Colors.white),
        ),
        const SizedBox(height: 8),
        _buildBulletPoint('You will receive email reminders'),
        _buildBulletPoint('All your data will be permanently deleted'),
        _buildBulletPoint('This action cannot be undone'),

        const SizedBox(height: 32),

        // Cancel button (if still in grace period)
        if (state.canCancelDeletion)
          ElevatedButton(
            onPressed: _showCancelConfirmation,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Cancel Deletion Request'),
          ),

        // Loading indicator
        if (state.isDeletionLoading)
          const Padding(
            padding: EdgeInsets.only(top: 16),
            child: Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }

  Widget _buildDeletionRequestView(AccountSettingsState state) {
    final isLoading = state.status == SettingsStatus.loading;

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Warning message
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red),
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.orange,
                  size: 40,
                ),
                const SizedBox(height: 8),
                Text(
                  '⚠️ This action cannot be undone',
                  style: AppTextStyles.heading3.copyWith(color: Colors.white),
                ),
                const SizedBox(height: 8),
                Text(
                  'You have 30 days to cancel the deletion request. '
                  'After this period, all your data will be permanently deleted.',
                  style: AppTextStyles.body.copyWith(color: Colors.white70),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Reason field
          Text(
            'Why are you deleting your account? (Required)',
            style: AppTextStyles.body.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 8),
          _DeletionTextField(
            controller: _reasonController,
            hintText: 'Please tell us why you\'re leaving...',
            maxLines: 3,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please provide a reason';
              }
              if (value.length < 10) {
                return 'Please provide more details (min 10 characters)';
              }
              return null;
            },
          ),

          const SizedBox(height: 16),

          // Feedback field (optional)
          Text(
            'Feedback (Optional)',
            style: AppTextStyles.body.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 8),
          _DeletionTextField(
            controller: _feedbackController,
            hintText: 'How can we improve? (Optional)',
            maxLines: 3,
          ),

          const SizedBox(height: 16),

          // Password confirmation (for local users)
          if (_hasLocalPassword)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Confirm Password',
                  style: AppTextStyles.body.copyWith(color: Colors.white),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _passwordController,
                  obscureText: !_showPassword,
                  decoration: InputDecoration(
                    hintText: 'Enter your password',
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.1),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 0,
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _showPassword ? Icons.visibility_off : Icons.visibility,
                        color: Colors.white70,
                      ),
                      onPressed: () {
                        setState(() => _showPassword = !_showPassword);
                      },
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: AppColors.primary.withOpacity(0.8),
                        width: 2,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Colors.white.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                  ),
                  style: const TextStyle(color: Colors.white),
                  validator: _hasLocalPassword
                      ? (value) {
                          if (value == null || value.isEmpty) {
                            return 'Password is required';
                          }
                          if (value.length < 6) {
                            return 'Password must be at least 6 characters';
                          }
                          return null;
                        }
                      : null,
                ),
              ],
            ),

          const SizedBox(height: 32),

          // Submit button
          ElevatedButton(
            onPressed: isLoading ? null : _submitDeletionRequest,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: isLoading
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text('Request Account Deletion'),
          ),

          // Loading indicator for deletion status
          if (state.isDeletionLoading)
            const Padding(
              padding: EdgeInsets.only(top: 16),
              child: Center(child: CircularProgressIndicator()),
            ),

          const SizedBox(height: 16),

          // Alternative: Immediate delete
          // TextButton(
          //   onPressed: () {
          //     showDialog(
          //       context: context,
          //       builder: (_) => MLConfirmDialog(
          //         icon: Icons.delete_forever_rounded,
          //         title: 'Immediate Deletion',
          //         message:
          //             'This will delete your account immediately '
          //             'without grace period. Are you sure?',
          //         confirmText: 'Delete Now',
          //         confirmColor: Colors.red,
          //         onConfirm: () {
          //           // ✅ Use stored cubit
          //           _cubit.performDelete(
          //             password: _passwordController.text.isNotEmpty
          //                 ? _passwordController.text
          //                 : null,
          //           );
          //         },
          //       ),
          //     );
          //   },
          //   child: Text(
          //     'Delete immediately (without grace period)',
          //     style: AppTextStyles.body.copyWith(
          //       color: Colors.red,
          //       decoration: TextDecoration.underline,
          //     ),
          //   ),
          // ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: AppTextStyles.body.copyWith(color: Colors.white70),
            ),
          ),
          const SizedBox(width: 16),
          Text(
            value,
            style: AppTextStyles.body.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBulletPoint(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 6, right: 8),
            child: Icon(Icons.circle, size: 6, color: Colors.white70),
          ),
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.body.copyWith(color: Colors.white70),
            ),
          ),
        ],
      ),
    );
  }

  void _submitDeletionRequest() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // ✅ Use stored cubit
      await _cubit.requestAccountDeletion(
        password: _passwordController.text,
        reason: _reasonController.text,
        feedback: _feedbackController.text.isNotEmpty
            ? _feedbackController.text
            : null,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showCancelConfirmation() {
    showDialog(
      context: context,
      builder: (_) => MLConfirmDialog(
        icon: Icons.cancel_rounded,
        title: 'Cancel Deletion?',
        message:
            'Your account deletion will be cancelled and your '
            'account will remain active.',
        confirmText: 'Yes, Cancel Deletion',
        confirmColor: Colors.green,
        onConfirm: () async {
          try {
            // ✅ Use stored cubit
            await _cubit.cancelAccountDeletion();
          } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
            );
          }
        },
      ),
    );
  }

  @override
  void dispose() {
    _cubit.close(); // ✅ Important: Close the cubit
    _reasonController.dispose();
    _feedbackController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}

// Keep your _DeletionTextField class as is
// Simple text field replacement
class _DeletionTextField extends StatelessWidget {
  final TextEditingController? controller;
  final String hintText;
  final int? maxLines;
  final bool obscureText;
  final String? Function(String?)? validator;
  final Widget? suffixIcon;

  const _DeletionTextField({
    this.controller,
    required this.hintText,
    this.maxLines = 1,
    this.obscureText = false,
    this.validator,
    this.suffixIcon,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      obscureText: obscureText,
      validator: validator,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
        filled: true,
        fillColor: Colors.white.withOpacity(0.1),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: EdgeInsets.symmetric(
          horizontal: 16,
          vertical: maxLines == 1 ? 0 : 16,
        ),
        suffixIcon: suffixIcon,
        errorStyle: const TextStyle(color: Colors.orangeAccent),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.orangeAccent, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.orangeAccent, width: 2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: AppColors.primary.withOpacity(0.8),
            width: 2,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: Colors.white.withOpacity(0.2),
            width: 1,
          ),
        ),
      ),
    );
  }
}
