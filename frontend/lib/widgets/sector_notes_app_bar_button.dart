import 'package:flutter/material.dart';
import '../screens/sector_notes_screen.dart';

/// Opens [SectorNotesScreen] for the given sector. Use only when [sectorCode] is non-null (single-sector context).
class SectorNotesAppBarButton extends StatelessWidget {
  final String? sectorCode;

  const SectorNotesAppBarButton({
    super.key,
    required this.sectorCode,
  });

  @override
  Widget build(BuildContext context) {
    final code = sectorCode;
    if (code == null || code.isEmpty) {
      return const SizedBox.shrink();
    }
    return IconButton(
      icon: const Icon(Icons.note_alt_outlined),
      tooltip: 'Sector notes',
      onPressed: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (context) => SectorNotesScreen(sectorCode: code),
          ),
        );
      },
    );
  }
}
