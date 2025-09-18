import 'package:flutter/material.dart';
import 'package:moonlight/core/utils/countries.dart';

class CountryPickerSheet extends StatelessWidget {
  const CountryPickerSheet();

  @override
  Widget build(BuildContext context) {
    final items = allCountriesSorted();

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 4,
              width: 44,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 12),

            // All Countries sentinel
            ListTile(
              leading: Text(
                isoToFlagEmoji(''),
                style: const TextStyle(fontSize: 18),
              ),
              title: const Text(
                'All Countries',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () => Navigator.pop<String>(context, '__ALL__'),
            ),
            const Divider(color: Colors.white10),

            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: items.length,
                itemBuilder: (_, i) {
                  final iso = items[i].key; // ISO2
                  final name = items[i].value; // Human name
                  return ListTile(
                    leading: Text(
                      isoToFlagEmoji(iso),
                      style: const TextStyle(fontSize: 18),
                    ),
                    title: Text(
                      name,
                      style: const TextStyle(color: Colors.white),
                    ),
                    onTap: () => Navigator.pop<String>(context, iso),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
