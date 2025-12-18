import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moonlight/core/injection_container.dart';
import 'package:moonlight/features/clubs/domain/repositories/clubs_repository.dart';

void showAddMemberSheet(BuildContext context, String club) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF0A0A0F),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) {
      return RepositoryProvider<ClubsRepository>.value(
        value: sl<ClubsRepository>(),
        child: _AddMemberForm(club),
      );
    },
  );
}

class _AddMemberForm extends StatefulWidget {
  final String club;
  const _AddMemberForm(this.club);

  @override
  State<_AddMemberForm> createState() => _AddMemberFormState();
}

class _AddMemberFormState extends State<_AddMemberForm> {
  final ctrl = TextEditingController();
  String role = 'member';
  bool loading = false;

  @override
  Widget build(BuildContext context) {
    final repo = context.read<ClubsRepository>();

    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Add Member',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: ctrl,
            decoration: const InputDecoration(hintText: 'User slug or email'),
          ),
          const SizedBox(height: 12),
          DropdownButton<String>(
            value: role,
            items: const [
              DropdownMenuItem(value: 'member', child: Text('Member')),
              DropdownMenuItem(value: 'admin', child: Text('Admin')),
            ],
            onChanged: (v) => setState(() => role = v!),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            // Update the onPressed callback in add_member_sheet.dart
            onPressed: loading
                ? null
                : () async {
                    setState(() => loading = true);
                    try {
                      await repo.addMember(
                        club: widget.club,
                        identifier: ctrl.text.trim(),
                        role: role,
                      );
                      Navigator.pop(context);
                      // Optionally show success message
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Successfully added ${ctrl.text.trim()}',
                          ),
                        ),
                      );
                    } catch (e) {
                      // Show error message
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    } finally {
                      if (mounted) {
                        setState(() => loading = false);
                      }
                    }
                  },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}
