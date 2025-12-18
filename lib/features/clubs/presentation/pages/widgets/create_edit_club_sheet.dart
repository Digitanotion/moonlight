import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moonlight/core/injection_container.dart';
import 'package:moonlight/features/clubs/domain/entities/club.dart';
import 'package:moonlight/features/clubs/domain/repositories/clubs_repository.dart';

Future<void> showCreateEditClubSheet(BuildContext context, {Club? club}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF0A0A0F),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) {
      return RepositoryProvider<ClubsRepository>.value(
        value: sl<ClubsRepository>(),
        child: const _CreateEditClubForm(),
      );
    },
  );
}

class _CreateEditClubForm extends StatefulWidget {
  final Club? club;
  const _CreateEditClubForm({this.club});

  @override
  State<_CreateEditClubForm> createState() => _CreateEditClubFormState();
}

class _CreateEditClubFormState extends State<_CreateEditClubForm> {
  late final TextEditingController nameCtrl;
  late final TextEditingController descCtrl;
  bool isPrivate = false;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    nameCtrl = TextEditingController(text: widget.club?.name);
    descCtrl = TextEditingController(text: widget.club?.description);
    isPrivate = widget.club?.isPrivate ?? false;
  }

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
          _header(widget.club == null ? 'Create Club' : 'Edit Club'),
          const SizedBox(height: 16),
          _input(nameCtrl, 'Club name'),
          const SizedBox(height: 12),
          _input(descCtrl, 'Description', maxLines: 3),
          const SizedBox(height: 12),
          SwitchListTile(
            value: isPrivate,
            onChanged: (v) => setState(() => isPrivate = v),
            title: const Text(
              'Private club',
              style: TextStyle(color: Colors.white),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: saving
                ? null
                : () async {
                    setState(() => saving = true);
                    try {
                      if (widget.club == null) {
                        await repo.createClub(
                          name: nameCtrl.text,
                          description: descCtrl.text,
                          isPrivate: isPrivate,
                        );
                      } else {
                        await repo.updateClub(
                          club: widget.club!.slug,
                          name: nameCtrl.text,
                          description: descCtrl.text,
                          isPrivate: isPrivate,
                        );
                      }
                      Navigator.pop(context);
                    } finally {
                      setState(() => saving = false);
                    }
                  },
            child: Text(widget.club == null ? 'Create' : 'Save'),
          ),
        ],
      ),
    );
  }

  Widget _header(String t) => Text(
    t,
    style: const TextStyle(
      color: Colors.white,
      fontSize: 18,
      fontWeight: FontWeight.w700,
    ),
  );

  Widget _input(TextEditingController c, String hint, {int maxLines = 1}) =>
      TextField(
        controller: c,
        maxLines: maxLines,
        decoration: InputDecoration(
          hintText: hint,
          filled: true,
          fillColor: Colors.white10,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
        style: const TextStyle(color: Colors.white),
      );
}
