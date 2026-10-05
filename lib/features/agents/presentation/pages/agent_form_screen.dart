// Create (or edit) the signed-in user's agency. Anyone can create one — no
// approval — but a photo is compulsory. Shows the programme message first.

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:moonlight/core/constants/flutterwave_countries.dart';
import 'package:moonlight/core/injection_container.dart';
import 'package:moonlight/features/agents/data/agent_remote_data_source.dart';
import 'package:moonlight/features/agents/presentation/pages/agent_ui.dart';
import 'package:moonlight/widgets/top_snack.dart';

class AgentFormScreen extends StatefulWidget {
  /// Existing agent map (from /agents/me) when editing; null to create.
  final Map<String, dynamic>? existing;

  /// The user's profile data (from /agents/me) used to pre-fill a NEW agency.
  final Map<String, dynamic>? prefill;
  const AgentFormScreen({super.key, this.existing, this.prefill});

  @override
  State<AgentFormScreen> createState() => _AgentFormScreenState();
}

class _AgentFormScreenState extends State<AgentFormScreen> {
  final _name = TextEditingController();
  final _desc = TextEditingController();
  final _phone = TextEditingController();
  String? _country;
  String _gender = 'male';
  String _visibility = 'public';
  File? _photo;
  bool _busy = false;

  bool get _editing => widget.existing != null;

  String? get _profilePhoto {
    final u = (widget.prefill?['photo_url'] ?? '').toString();
    return u.isEmpty ? null : u;
  }

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _name.text = (e['name'] ?? '').toString();
      _desc.text = (e['description'] ?? '').toString();
      _phone.text = (e['phone'] ?? '').toString();
      _country = e['country']?.toString();
      _gender = (e['gender'] ?? 'male').toString();
      _visibility = (e['members_visibility'] ?? 'public').toString();
    } else {
      final p = widget.prefill;
      if (p != null) {
        _name.text = (p['name'] ?? '').toString();
        _desc.text = (p['description'] ?? '').toString();
        _phone.text = (p['phone'] ?? '').toString();
        final c = (p['country'] ?? '').toString();
        _country = kFlutterwaveCountries.any((x) => x.name == c) ? c : null;
        final g = (p['gender'] ?? '').toString();
        if (const ['male', 'female', 'other'].contains(g)) _gender = g;
      }
      // The programme message is shown first, before the form.
      WidgetsBinding.instance.addPostFrameCallback((_) => _showIntro());
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _desc.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _showIntro() async {
    if (!mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C1533),
        title: const Text(
          'Moonlight Agency',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
        ),
        content: const SingleChildScrollView(
          child: Text(
            kAgentInviteMessage,
            style: TextStyle(color: Colors.white70, height: 1.4),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    if (ok != true && mounted) Navigator.pop(context);
  }

  Future<void> _pickPhoto() async {
    final x = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1080,
      imageQuality: 85,
    );
    if (x != null && mounted) setState(() => _photo = File(x.path));
  }

  Future<void> _submit() async {
    if (!_editing && _photo == null && _profilePhoto == null) {
      TopSnack.error(context, 'A profile photo is required.');
      return;
    }
    if (_name.text.trim().length < 2 ||
        _phone.text.trim().length < 6 ||
        _country == null) {
      TopSnack.error(context, 'Fill in the agent name, country and phone.');
      return;
    }

    setState(() => _busy = true);
    try {
      final form = FormData.fromMap({
        'name': _name.text.trim(),
        'description': _desc.text.trim(),
        'country': _country,
        'phone': _phone.text.trim(),
        'gender': _gender,
        if (_editing) 'members_visibility': _visibility,
        if (_photo != null)
          'photo': await MultipartFile.fromFile(_photo!.path)
        else if (!_editing)
          'use_profile_photo': 1,
      });
      final ds = sl<AgentRemoteDataSource>();
      if (_editing) {
        await ds.update(form);
      } else {
        await ds.create(form);
      }
      if (!mounted) return;
      TopSnack.success(
        context,
        _editing ? 'Agency updated.' : 'Your agency is ready!',
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) TopSnack.error(context, agentErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AgentScaffold(
      title: _editing ? 'Edit agency' : 'Create agency',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: GestureDetector(
              onTap: _pickPhoto,
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  _photo != null
                      ? ClipOval(
                          child: Image.file(
                            _photo!,
                            width: 96,
                            height: 96,
                            fit: BoxFit.cover,
                          ),
                        )
                      : AgentAvatar(
                          url:
                              widget.existing?['photo_url']?.toString() ??
                              _profilePhoto,
                          size: 96,
                        ),
                  const CircleAvatar(
                    radius: 14,
                    backgroundColor: Colors.white,
                    child: Icon(Icons.camera_alt, size: 16),
                  ),
                ],
              ),
            ),
          ),
          if (!_editing)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Center(
                child: Text(
                  'Photo (from your profile — tap to change)',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ),
            ),
          const SizedBox(height: 18),
          TextField(
            controller: _name,
            maxLength: 80,
            style: const TextStyle(color: Colors.white),
            decoration: agentInput('Agent name'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _desc,
            maxLength: 500,
            maxLines: 3,
            style: const TextStyle(color: Colors.white),
            decoration: agentInput('Description'),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _country,
            isExpanded: true,
            dropdownColor: const Color(0xFF1C1533),
            style: const TextStyle(color: Colors.white),
            decoration: agentInput('Country'),
            items: kFlutterwaveCountries
                .map(
                  (c) => DropdownMenuItem(value: c.name, child: Text(c.name)),
                )
                .toList(),
            onChanged: (v) => setState(() => _country = v),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            style: const TextStyle(color: Colors.white),
            decoration: agentInput('Phone number', hint: '+234…'),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: _gender,
            dropdownColor: const Color(0xFF1C1533),
            style: const TextStyle(color: Colors.white),
            decoration: agentInput('Gender'),
            items: const [
              DropdownMenuItem(value: 'male', child: Text('Male')),
              DropdownMenuItem(value: 'female', child: Text('Female')),
              DropdownMenuItem(value: 'other', child: Text('Other')),
            ],
            onChanged: (v) => setState(() => _gender = v ?? 'male'),
          ),
          if (_editing) ...[
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: _visibility,
              dropdownColor: const Color(0xFF1C1533),
              style: const TextStyle(color: Colors.white),
              decoration: agentInput('Recruited members are'),
              items: const [
                DropdownMenuItem(
                  value: 'public',
                  child: Text('Public — listed on my agent page'),
                ),
                DropdownMenuItem(
                  value: 'private',
                  child: Text('Private — only the count is shown'),
                ),
              ],
              onChanged: (v) => setState(() => _visibility = v ?? 'public'),
            ),
          ],
          const SizedBox(height: 22),
          AgentPrimaryButton(
            label: _editing ? 'Save changes' : 'Create agency',
            busy: _busy,
            onTap: _submit,
          ),
        ],
      ),
    );
  }
}
