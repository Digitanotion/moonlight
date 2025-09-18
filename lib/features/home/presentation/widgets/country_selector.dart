import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moonlight/core/utils/countries.dart';
import '../bloc/live_feed/live_feed_bloc.dart';
import '../bloc/live_feed/live_feed_event.dart';
import '../bloc/live_feed/live_feed_state.dart';

class CountrySelector extends StatelessWidget {
  const CountrySelector({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LiveFeedBloc, LiveFeedState>(
      buildWhen: (p, n) => p.selectedCountryIso != n.selectedCountryIso,
      builder: (context, state) {
        final selectedIso = state.selectedCountryIso; // null => All
        final items = allCountriesSorted();

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: DropdownButtonFormField<String?>(
            value: selectedIso,
            isExpanded: true,
            dropdownColor: const Color(0xFF1E1E1E),
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0x1AFFFFFF),
              labelText: 'All Countries',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
            ),
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text(
                  'All Countries',
                  style: TextStyle(color: Colors.white),
                ),
              ),
              ...items.map((e) {
                final iso = e.key;
                final name = e.value;
                return DropdownMenuItem<String?>(
                  value: iso,
                  child: Row(
                    children: [
                      Text(
                        isoToFlagEmoji(iso),
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(width: 8),
                      Text(name, style: const TextStyle(color: Colors.white)),
                    ],
                  ),
                );
              }),
            ],
            onChanged: (iso) {
              // null => All
              context.read<LiveFeedBloc>().add(LiveFeedCountryChanged(iso));
            },
          ),
        );
      },
    );
  }
}
