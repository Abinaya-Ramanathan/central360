import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../services/sector_service.dart';
import '../models/sector.dart';

/// Persistent notes for a single sector code (saved on server; no delete).
class SectorNotesScreen extends StatefulWidget {
  final String sectorCode;

  const SectorNotesScreen({
    super.key,
    required this.sectorCode,
  });

  @override
  State<SectorNotesScreen> createState() => _SectorNotesScreenState();
}

class _SectorNotesScreenState extends State<SectorNotesScreen> {
  final TextEditingController _controller = TextEditingController();
  List<Sector> _sectors = [];
  bool _loading = true;
  bool _saving = false;
  String? _lastSavedBody;
  DateTime? _updatedAt;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      final sectors = await SectorService().loadSectorsForScreen();
      if (mounted) setState(() => _sectors = sectors);
    } catch (_) {}
    await _loadNote();
  }

  String _sectorTitle() {
    final s = _sectors.where((e) => e.code == widget.sectorCode);
    if (s.isNotEmpty) return '${s.first.code} — ${s.first.name}';
    return widget.sectorCode;
  }

  Future<void> _loadNote() async {
    setState(() => _loading = true);
    try {
      final data = await ApiService.getSectorNote(widget.sectorCode);
      final body = data['body']?.toString() ?? '';
      _controller.text = body;
      _lastSavedBody = body;
      final raw = data['updated_at'];
      if (raw != null) {
        try {
          _updatedAt = DateTime.tryParse(raw.toString());
        } catch (_) {
          _updatedAt = null;
        }
      } else {
        _updatedAt = null;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load notes: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final data = await ApiService.saveSectorNote(widget.sectorCode, _controller.text);
      final body = data['body']?.toString() ?? '';
      _lastSavedBody = body;
      final raw = data['updated_at'];
      if (raw != null) {
        _updatedAt = DateTime.tryParse(raw.toString());
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Notes saved'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  bool get _dirty => _controller.text != (_lastSavedBody ?? '');

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final updatedStr = _updatedAt != null
        ? DateFormat.yMMMd().add_jm().format(_updatedAt!.toLocal())
        : null;

    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final go = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Unsaved changes'),
            content: const Text('You have unsaved notes. Leave without saving?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Stay')),
              TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Leave')),
            ],
          ),
        );
        if (go == true && context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('Notes — ${_sectorTitle()}'),
          backgroundColor: Colors.blue.shade700,
          foregroundColor: Colors.white,
          actions: [
            if (_loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  ),
                ),
              )
            else
              TextButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.save, color: Colors.white),
                label: const Text('Save', style: TextStyle(color: Colors.white)),
              ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Notes are stored for this sector only. Saving updates the server copy; notes cannot be deleted from the app.',
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                    ),
                    if (updatedStr != null) ...[
                      const SizedBox(height: 8),
                      Text('Last saved: $updatedStr', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                    ],
                    const SizedBox(height: 12),
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        maxLines: null,
                        expands: true,
                        textAlignVertical: TextAlignVertical.top,
                        decoration: InputDecoration(
                          hintText: 'Enter notes for ${_sectorTitle()}…',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
