import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:moonlight/core/theme/app_text_styles.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../core/theme/app_colors.dart';

Future<void> showViewerMenuSheet(
  BuildContext context, {
  required VoidCallback onReport,
  required VoidCallback onCopy,
}) async {
  await showModalBottomSheet(
    context: context,
    backgroundColor: const Color(0xFF0A0C12),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => _MenuSheet(
      items: [
        _MenuItem(
          icon: Icons.report_gmailerrorred_outlined,
          label: 'Report Post',
          color: Colors.redAccent,
          onTap: onReport,
        ),
        _MenuItem(
          icon: Icons.link_outlined,
          label: 'Copy post link',
          color: AppColors.onSurface,
          onTap: onCopy,
        ),
      ],
    ),
  );
}

Future<void> showOwnerMenuSheet(
  BuildContext context, {
  required VoidCallback onDelete,
  required ValueChanged<String> onEdit,
}) async {
  await showModalBottomSheet(
    context: context,
    backgroundColor: const Color(0xFF0A0C12),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => _OwnerMenu(onDelete: onDelete, onEdit: onEdit),
  );
}

class _MenuItem {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  _MenuItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
}

class _MenuSheet extends StatelessWidget {
  final List<_MenuItem> items;
  const _MenuSheet({required this.items});
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 4,
              margin: const EdgeInsets.only(bottom: 18),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            ...items.map(
              (e) => ListTile(
                onTap: () {
                  Navigator.pop(context);
                  e.onTap();
                },
                leading: Icon(e.icon, color: e.color),
                title: Text(e.label, style: AppTextStyles.body),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OwnerMenu extends StatelessWidget {
  final VoidCallback onDelete;
  final ValueChanged<String> onEdit;
  const _OwnerMenu({required this.onDelete, required this.onEdit});
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 4,
              margin: const EdgeInsets.only(bottom: 18),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            ListTile(
              onTap: () {
                Navigator.pop(context);
                onDelete();
              },
              leading: const Icon(Icons.delete_outline, color: Colors.white),
              title: Text('Delete Post', style: AppTextStyles.body),
            ),
            ListTile(
              onTap: () async {
                final ctrl = TextEditingController();
                await showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    backgroundColor: AppColors.navyDark,
                    title: Text(
                      'Edit Caption',
                      style: AppTextStyles.titleMedium,
                    ),
                    content: TextField(
                      controller: ctrl,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        hintText: 'New caption',
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          onEdit(ctrl.text);
                        },
                        child: const Text('Save'),
                      ),
                    ],
                  ),
                );
              },
              leading: const Icon(Icons.edit_outlined, color: Colors.white),
              title: Text('Edit Caption', style: AppTextStyles.body),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> showShareSheet(BuildContext context, {required String url}) async {
  await showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _ShareCard(url: url),
  );
}

/// Bottom-sheet reason picker used by the Report action.
/// Returns a normalized reason string or null if cancelled.
Future<String?> pickReason(BuildContext context) async {
  const reasons = <String>['spam', 'nudity', 'violence', 'harassment', 'other'];
  String selected = reasons.first;
  final otherCtrl = TextEditingController();

  final result = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.navyDark,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setState) {
          final bottomInset = MediaQuery.of(ctx).viewInsets.bottom;
          return Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + bottomInset),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Report reason',
                    style: AppTextStyles.titleMedium,
                  ),
                ),
                const SizedBox(height: 8),
                ...reasons.map((r) {
                  final isOther = r == 'other';
                  final selectedThis = selected == r;
                  return Column(
                    children: [
                      RadioListTile<String>(
                        value: r,
                        groupValue: selected,
                        onChanged: (v) =>
                            setState(() => selected = v ?? reasons.first),
                        title: Text(
                          isOther
                              ? 'Other'
                              : r[0].toUpperCase() + r.substring(1),
                          style: AppTextStyles.body,
                        ),
                        activeColor: AppColors.hashtag,
                        tileColor: Colors.transparent,
                        contentPadding: EdgeInsets.zero,
                      ),
                      if (isOther && selectedThis) ...[
                        const SizedBox(height: 6),
                        TextField(
                          controller: otherCtrl,
                          autofocus: true,
                          maxLength: 140,
                          style: AppTextStyles.body,
                          decoration: const InputDecoration(
                            hintText: 'Describe the issue',
                            filled: true,
                            fillColor: Color(0xFF131B34),
                            border: OutlineInputBorder(
                              borderSide: BorderSide.none,
                              borderRadius: BorderRadius.all(
                                Radius.circular(12),
                              ),
                            ),
                            counterText: '',
                          ),
                        ),
                      ],
                      const SizedBox(height: 4),
                    ],
                  );
                }).toList(),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          String value = selected;
                          if (selected == 'other') {
                            final t = otherCtrl.text.trim();
                            if (t.isEmpty) {
                              // simple guard: keep user on sheet until they type
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                const SnackBar(
                                  content: Text('Please describe the issue'),
                                ),
                              );
                              return;
                            }
                            // normalize: limit to 140 chars, strip control chars
                            value = t
                                .replaceAll(RegExp(r'[\x00-\x1F]'), '')
                                .substring(0, t.length.clamp(0, 140));
                          }
                          Navigator.pop(ctx, value);
                        },
                        child: const Text('Submit'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
            ),
          );
        },
      );
    },
  );

  otherCtrl.dispose();
  // Normalize common variants (server expects simple tokens like “spam” OR a free-text string)
  if (result == null) return null;
  final v = result.trim();
  if (v.isEmpty) return null;
  // For preset reasons, send lowercase tokens; for “other” we already pass the text.
  switch (v.toLowerCase()) {
    case 'spam':
    case 'nudity':
    case 'violence':
    case 'harassment':
      return v.toLowerCase();
    default:
      return v; // custom text
  }
}

class _ShareCard extends StatelessWidget {
  final String url;
  const _ShareCard({required this.url});
  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF0B1E6B),
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Text('Share Post', style: AppTextStyles.titleMedium),
              ),
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.network(
                  'https://images.unsplash.com/photo-1500530855697-b586d89ba3ee?q=80&w=1000&auto=format&fit=crop',
                  height: 120,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 24,
                runSpacing: 14,
                children: [
                  _ShareAction(
                    label: 'WhatsApp',
                    icon: Icons.message,
                    onTap: () => Share.share(url),
                  ),
                  _ShareAction(
                    label: 'Instagram',
                    icon: Icons.camera_alt_outlined,
                    onTap: () => Share.share(url),
                  ),
                  _ShareAction(
                    label: 'X (Twitter)',
                    icon: Icons.alternate_email,
                    onTap: () => Share.share(url),
                  ),
                  _ShareAction(
                    label: 'Copy Link',
                    icon: Icons.link,
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: url));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Link copied')),
                      );
                    },
                  ),
                  _ShareAction(
                    label: 'Save on Device',
                    icon: Icons.download_outlined,
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Saved to device (mock)')),
                      );
                    },
                  ),
                  _ShareAction(
                    label: 'Report',
                    icon: Icons.report_gmailerrorred_outlined,
                    onTap: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(const SnackBar(content: Text('Reported')));
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShareAction extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _ShareAction({
    required this.label,
    required this.icon,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white24,
            ),
            child: Icon(icon),
          ),
          const SizedBox(height: 6),
          Text(label, style: AppTextStyles.small),
        ],
      ),
    );
  }
}
