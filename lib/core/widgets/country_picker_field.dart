// lib/core/widgets/country_picker_field.dart
//
// Shared country selection UI, backed by lib/core/utils/countries.dart
// (kIso2ToName / isoToFlagEmoji / allCountriesSorted) — the same source
// LiveFeedRemoteDataSource already uses for ISO2 codes/flags, and the
// same source your backend already stores against (`country: "AD"`
// etc. — confirmed directly from /profile/me responses).
//
// Any screen with a country field should use CountrySelectField +
// showCountryPickerSheet instead of building its own dropdown against a
// list of bare country names — that mismatch (names list vs. ISO2 value)
// is exactly what caused:
//   "There should be exactly one item with [DropdownButton]'s value: AD."
// in EditProfileScreen.

import 'package:flutter/material.dart';
import 'package:moonlight/core/utils/countries.dart';

class _PickerColors {
  final Color bg;
  final Color surface;
  final Color border;
  final Color accent;
  final Color textSecondary;
  const _PickerColors({
    required this.bg,
    required this.surface,
    required this.border,
    required this.accent,
    required this.textSecondary,
  });
}

/// Tappable field showing the currently selected country (flag + name)
/// or a placeholder, matching whichever surrounding screen's palette via
/// the optional color params. Tapping opens [showCountryPickerSheet].
class CountrySelectField extends StatelessWidget {
  final String? iso2;
  final VoidCallback onTap;
  final Color background;
  final Color border;
  final Color textSecondary;
  final String placeholder;

  const CountrySelectField({
    super.key,
    required this.iso2,
    required this.onTap,
    this.background = const Color(0xFF0E1024),
    this.border = const Color(0xFF1A1D3D),
    this.textSecondary = const Color(0xFF8B8FB8),
    this.placeholder = 'Select your country',
  });

  @override
  Widget build(BuildContext context) {
    final hasValue = (iso2 ?? '').isNotEmpty;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border),
        ),
        child: Row(
          children: [
            if (hasValue) ...[
              Text(isoToFlagEmoji(iso2!), style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 10),
            ] else ...[
              Icon(Icons.public_rounded, color: textSecondary, size: 20),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Text(
                hasValue ? countryDisplayName(iso2) : placeholder,
                style: TextStyle(
                  color: hasValue ? Colors.white : textSecondary.withOpacity(0.7),
                  fontSize: 14.5,
                ),
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: textSecondary),
          ],
        ),
      ),
    );
  }
}

/// Opens the searchable, flag-labeled country picker sheet. Returns the
/// selected ISO2 code, or null if dismissed without a selection.
Future<String?> showCountryPickerSheet(
  BuildContext context, {
  Color bg = const Color(0xFF05060F),
  Color surface = const Color(0xFF0E1024),
  Color border = const Color(0xFF1A1D3D),
  Color accent = const Color(0xFFFF6A00),
  Color textSecondary = const Color(0xFF8B8FB8),
}) {
  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _CountryPickerSheet(
      colors: _PickerColors(
        bg: bg,
        surface: surface,
        border: border,
        accent: accent,
        textSecondary: textSecondary,
      ),
    ),
  );
}

class _CountryPickerSheet extends StatefulWidget {
  final _PickerColors colors;
  const _CountryPickerSheet({required this.colors});

  @override
  State<_CountryPickerSheet> createState() => _CountryPickerSheetState();
}

class _CountryPickerSheetState extends State<_CountryPickerSheet> {
  late final List<MapEntry<String, String>> _all;
  List<MapEntry<String, String>> _filtered = [];
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _all = allCountriesSorted();
    _filtered = _all;
    _searchCtrl.addListener(_onSearch);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearch() {
    final q = _searchCtrl.text.trim().toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? _all
          : _all
              .where((e) =>
                  e.value.toLowerCase().contains(q) ||
                  e.key.toLowerCase().contains(q))
              .toList();
    });
  }

  void _clearSearch() {
    _searchCtrl.clear();
    _onSearch();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.colors;
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.only(top: 60),
        decoration: BoxDecoration(
          color: c.bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag handle
              Center(
                child: Container(
                  height: 4,
                  width: 44,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Select Country',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white70),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // Search bar — with clear (×) button, matching the
              // livestream country filter's proven design.
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.search, color: Colors.white54, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _searchCtrl,
                          style: const TextStyle(color: Colors.white, fontSize: 15),
                          decoration: InputDecoration(
                            hintText: 'Search country or code…',
                            hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(vertical: 12),
                            isDense: true,
                          ),
                          cursorColor: c.accent,
                        ),
                      ),
                      if (_searchCtrl.text.isNotEmpty)
                        GestureDetector(
                          onTap: _clearSearch,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.close,
                              size: 16,
                              color: Colors.white.withOpacity(0.7),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // List — bounded height since this sheet is sized to
              // content (mainAxisSize.min) rather than full-screen.
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.55,
                child: _filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.location_off_outlined,
                              size: 48,
                              color: Colors.white.withOpacity(0.3),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No countries found',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.5),
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Try a different search term',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.3),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        physics: const BouncingScrollPhysics(),
                        itemCount: _filtered.length,
                        itemBuilder: (context, i) {
                          final entry = _filtered[i];
                          return Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(10),
                              onTap: () => Navigator.pop(context, entry.key),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 10),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: Colors.white.withOpacity(0.1),
                                        ),
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        isoToFlagEmoji(entry.key),
                                        style: const TextStyle(fontSize: 18),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            entry.value,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 15,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            entry.key,
                                            style: TextStyle(
                                              color: Colors.white.withOpacity(0.5),
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}