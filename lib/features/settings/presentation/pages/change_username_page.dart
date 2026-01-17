import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moonlight/core/injection_container.dart' as di;
import 'package:moonlight/features/settings/presentation/cubit/change_username_cubit.dart';
import 'package:moonlight/widgets/top_snack.dart';

class ChangeUsernamePage extends StatefulWidget {
  const ChangeUsernamePage({super.key});

  @override
  State<ChangeUsernamePage> createState() => _ChangeUsernamePageState();
}

class _ChangeUsernamePageState extends State<ChangeUsernamePage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordFocusNode = FocusNode();
  Timer? _debounceTimer;
  bool _isPasswordVisible = false;

  @override
  void initState() {
    super.initState();
    // Don't load here - wait for BlocConsumer to be built
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _passwordFocusNode.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onUsernameChanged(String value, ChangeUsernameCubit cubit) {
    // Cancel previous timer
    _debounceTimer?.cancel();

    if (value.length >= 3 && RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(value)) {
      // Set up debounce timer
      _debounceTimer = Timer(const Duration(milliseconds: 500), () {
        if (_usernameController.text == value && mounted) {
          cubit.checkUsername(value);
        }
      });
    } else if (value.isEmpty || value.length < 3) {
      // Clear availability status if text is too short or empty
      cubit.clearUsernameAvailability();
    }
  }

  void _togglePasswordVisibility() {
    setState(() {
      _isPasswordVisible = !_isPasswordVisible;
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      // Add BlocProvider here
      create: (_) => di.sl<ChangeUsernameCubit>()..loadCurrentUsername(),
      child: Scaffold(
        backgroundColor: const Color(0xFF060522),
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.transparent,
          leading: IconButton(
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Colors.white,
            ),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text(
            'Change Username',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: Colors.white,
              fontSize: 20,
            ),
          ),
          centerTitle: true,
        ),
        body: BlocConsumer<ChangeUsernameCubit, ChangeUsernameState>(
          listener: (context, state) {
            if (state.status == ChangeUsernameStatus.success) {
              TopSnack.success(
                context,
                state.message ?? 'Username updated successfully!',
              );
              Navigator.pop(context);
            } else if (state.status == ChangeUsernameStatus.error) {
              if (state.error != null && state.error!.isNotEmpty) {
                TopSnack.error(context, state.error!);
              }
            }
          },
          builder: (context, state) {
            final cubit = context.read<ChangeUsernameCubit>();
            final loading = state.status == ChangeUsernameStatus.loading;
            final checking = state.status == ChangeUsernameStatus.checking;
            final isValid = state.isUsernameAvailable == true;
            final isInvalid = state.isUsernameAvailable == false;
            final hasCooldown = state.cooldownMessage != null;

            return Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF0F0B2E), Color(0xFF060522)],
                ),
              ),
              child: Stack(
                children: [
                  SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    padding: const EdgeInsets.all(20),
                    child: Form(
                      key: _formKey,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Info Card
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.purpleAccent.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.purpleAccent.withOpacity(0.3),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.info_outline_rounded,
                                      color: Colors.purpleAccent,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'Username Guidelines',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                _buildGuidelineItem(
                                  'Must be 3-20 characters long',
                                  Icons.format_size_rounded,
                                ),
                                _buildGuidelineItem(
                                  'Can contain letters, numbers, and underscores',
                                  Icons.text_fields_rounded,
                                ),
                                _buildGuidelineItem(
                                  'No spaces or special characters',
                                  Icons.block_rounded,
                                ),
                                _buildGuidelineItem(
                                  'Cannot be changed again for 30 days',
                                  Icons.timer_rounded,
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 32),

                          // Cooldown Warning
                          if (hasCooldown)
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.orangeAccent.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.orangeAccent.withOpacity(0.3),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.timer_rounded,
                                    color: Colors.orangeAccent,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      state.cooldownMessage!,
                                      style: const TextStyle(
                                        color: Colors.orangeAccent,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          if (hasCooldown) const SizedBox(height: 16),

                          // Current Username (if available)
                          if (state.currentUsername != null &&
                              state.currentUsername!.isNotEmpty) ...[
                            _buildSectionTitle('Current Username'),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.1),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.person_rounded,
                                    color: Colors.deepOrangeAccent,
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    '@${state.currentUsername}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),
                          ],

                          // New Username
                          _buildSectionTitle('New Username'),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _usernameController,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Username is required';
                              }
                              final trimmedValue = value.trim();
                              if (trimmedValue.length < 3) {
                                return 'Must be at least 3 characters';
                              }
                              if (trimmedValue.length > 20) {
                                return 'Must be less than 20 characters';
                              }
                              if (!RegExp(
                                r'^[a-zA-Z0-9_]+$',
                              ).hasMatch(trimmedValue)) {
                                return 'Only letters, numbers, and underscores';
                              }
                              if (state.isUsernameAvailable == false) {
                                return 'Username is already taken';
                              }
                              return null;
                            },
                            onChanged: (value) =>
                                _onUsernameChanged(value, cubit),
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              hintText: 'Enter new username',
                              hintStyle: TextStyle(
                                color: Colors.white.withOpacity(0.5),
                              ),
                              prefixText: '@',
                              prefixStyle: const TextStyle(
                                color: Colors.deepOrangeAccent,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                              prefixIcon: const Icon(
                                Icons.alternate_email_rounded,
                                color: Colors.deepOrangeAccent,
                              ),
                              suffixIcon: checking
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : isValid
                                  ? const Icon(
                                      Icons.check_circle_rounded,
                                      color: Colors.greenAccent,
                                    )
                                  : isInvalid
                                  ? const Icon(
                                      Icons.cancel_rounded,
                                      color: Colors.redAccent,
                                    )
                                  : null,
                              filled: true,
                              fillColor: Colors.white.withOpacity(0.07),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.white.withOpacity(0.1),
                                  width: 1,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: Colors.deepOrangeAccent,
                                  width: 2,
                                ),
                              ),
                              errorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: Colors.redAccent,
                                  width: 1,
                                ),
                              ),
                              errorStyle: const TextStyle(
                                color: Colors.redAccent,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 16,
                              ),
                            ),
                            textInputAction: TextInputAction.next,
                            onFieldSubmitted: (_) {
                              FocusScope.of(
                                context,
                              ).requestFocus(_passwordFocusNode);
                            },
                          ),

                          const SizedBox(height: 8),

                          // Availability indicator
                          if (state.isUsernameAvailable == true)
                            Row(
                              children: [
                                const Icon(
                                  Icons.check_circle_rounded,
                                  color: Colors.greenAccent,
                                  size: 16,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Username is available',
                                  style: TextStyle(
                                    color: Colors.greenAccent,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            )
                          else if (state.isUsernameAvailable == false)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.cancel_rounded,
                                      color: Colors.redAccent,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Username is already taken',
                                      style: TextStyle(
                                        color: Colors.redAccent,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                                if (state.suggestions.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    'Suggestions:',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.7),
                                      fontSize: 13,
                                    ),
                                  ),
                                  Wrap(
                                    spacing: 8,
                                    children: state.suggestions.take(3).map((
                                      suggestion,
                                    ) {
                                      return InkWell(
                                        onTap: () {
                                          _usernameController.text = suggestion;
                                          cubit.checkUsername(suggestion);
                                        },
                                        child: Container(
                                          margin: const EdgeInsets.only(
                                            top: 4,
                                            right: 8,
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.deepOrangeAccent
                                                .withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
                                            border: Border.all(
                                              color: Colors.deepOrangeAccent
                                                  .withOpacity(0.3),
                                            ),
                                          ),
                                          child: Text(
                                            '@$suggestion',
                                            style: const TextStyle(
                                              color: Colors.deepOrangeAccent,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ],
                              ],
                            ),

                          const SizedBox(height: 32),

                          // Password Verification
                          _buildSectionTitle('Verify Your Identity'),
                          const SizedBox(height: 12),
                          Text(
                            'Enter your password to confirm this change',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _passwordController,
                            focusNode: _passwordFocusNode,
                            obscureText: !_isPasswordVisible,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Password is required';
                              }
                              if (value.length < 6) {
                                return 'Password must be at least 6 characters';
                              }
                              return null;
                            },
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              hintText: 'Enter your password',
                              hintStyle: TextStyle(
                                color: Colors.white.withOpacity(0.5),
                              ),
                              prefixIcon: const Icon(
                                Icons.lock_rounded,
                                color: Colors.deepOrangeAccent,
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _isPasswordVisible
                                      ? Icons.visibility_off_rounded
                                      : Icons.visibility_rounded,
                                  color: Colors.white54,
                                ),
                                onPressed: _togglePasswordVisibility,
                              ),
                              filled: true,
                              fillColor: Colors.white.withOpacity(0.07),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.white.withOpacity(0.1),
                                  width: 1,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: Colors.deepOrangeAccent,
                                  width: 2,
                                ),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 16,
                              ),
                            ),
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) {
                              if (!loading && isValid) {
                                _submitForm(cubit);
                              }
                            },
                          ),

                          const SizedBox(height: 40),

                          // Update Button
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: (loading || !isValid || hasCooldown)
                                  ? null
                                  : () => _submitForm(cubit),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.deepOrangeAccent,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                  horizontal: 32,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                elevation: 2,
                                shadowColor: Colors.deepOrangeAccent
                                    .withOpacity(0.4),
                                disabledBackgroundColor: Colors.deepOrangeAccent
                                    .withOpacity(0.5),
                              ),
                              child: loading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text(
                                      'Update Username',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                            ),
                          ),

                          const SizedBox(height: 24),

                          // Cancel Button
                          SizedBox(
                            width: double.infinity,
                            child: TextButton(
                              onPressed: loading
                                  ? null
                                  : () => Navigator.pop(context),
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.white.withOpacity(0.8),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                              ),
                              child: const Text(
                                'Cancel',
                                style: TextStyle(fontSize: 15),
                              ),
                            ),
                          ),

                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
                  ),

                  // Loading Overlay
                  if (loading)
                    Container(
                      color: Colors.black.withOpacity(0.4),
                      child: const Center(
                        child: CircularProgressIndicator(
                          color: Colors.deepOrangeAccent,
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  void _submitForm(ChangeUsernameCubit cubit) {
    if (_formKey.currentState!.validate()) {
      FocusScope.of(context).unfocus(); // Close keyboard
      cubit.changeUsername(
        newUsername: _usernameController.text.trim(),
        password: _passwordController.text,
      );
    }
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w700,
        fontSize: 16,
      ),
    );
  }

  Widget _buildGuidelineItem(String text, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Colors.purpleAccent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
