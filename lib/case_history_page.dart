// case_history_page.dart
// Case history timeline — mirrors the web portal's case-history component,
// backed by GET /valuations/{id}/workflow/gethistory.

import 'package:flutter/material.dart';
import 'services/api_service.dart';

/// Pushes the history page. Call from any case detail page's app bar.
void showCaseHistory(BuildContext context, String valuationId, {String? title}) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => CaseHistoryPage(valuationId: valuationId, title: title),
    ),
  );
}

class CaseHistoryPage extends StatefulWidget {
  final String valuationId;
  final String? title;
  const CaseHistoryPage({super.key, required this.valuationId, this.title});

  @override
  State<CaseHistoryPage> createState() => _CaseHistoryPageState();
}

class _CaseHistoryPageState extends State<CaseHistoryPage> {
  final ApiService _api = ApiService();
  bool _isLoading = true;
  List<dynamic> _entries = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final entries = await _api.getWorkflowHistory(widget.valuationId);
    // Newest first.
    entries.sort((a, b) {
      final da = (a is Map ? (a['dateTime'] ?? a['DateTime'] ?? '') : '').toString();
      final db = (b is Map ? (b['dateTime'] ?? b['DateTime'] ?? '') : '').toString();
      return db.compareTo(da);
    });
    if (mounted) {
      setState(() {
        _entries = entries;
        _isLoading = false;
      });
    }
  }

  String _str(dynamic e, List<String> keys) {
    if (e is! Map) return '';
    for (final k in keys) {
      final v = e[k];
      if (v != null && v.toString() != 'null' && v.toString().isNotEmpty) {
        return v.toString();
      }
    }
    return '';
  }

  String _formatDate(String iso) {
    if (iso.isEmpty) return '';
    final dt = DateTime.tryParse(iso)?.toLocal();
    if (dt == null) return iso;
    String two(int n) => n.toString().padLeft(2, '0');
    return "${two(dt.day)}-${two(dt.month)}-${dt.year} ${two(dt.hour)}:${two(dt.minute)}";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(widget.title ?? "Case History",
            style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          IconButton(icon: const Icon(Icons.refresh, color: Colors.black), onPressed: _load),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _entries.isEmpty
              ? const Center(child: Text("No history recorded for this case yet.",
                  style: TextStyle(color: Colors.grey)))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _entries.length,
                  itemBuilder: (context, i) => _buildEntry(_entries[i], i == _entries.length - 1),
                ),
    );
  }

  Widget _buildEntry(dynamic e, bool isLast) {
    final action = _str(e, ['action', 'Action']);
    final remarks = _str(e, ['remarks', 'Remarks']);
    final byName = _str(e, ['performedByUserName', 'PerformedByUserName']);
    final from = _str(e, ['statusFrom', 'StatusFrom', 'previousStatus', 'PreviousStatus']);
    final to = _str(e, ['statusTo', 'StatusTo', 'currentStatus', 'CurrentStatus']);
    final date = _formatDate(_str(e, ['dateTime', 'DateTime']));

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(children: [
            Container(
              width: 12, height: 12,
              margin: const EdgeInsets.only(top: 4),
              decoration: const BoxDecoration(color: Color(0xFF007B7B), shape: BoxShape.circle),
            ),
            if (!isLast)
              Expanded(child: Container(width: 2, color: Colors.teal.shade100)),
          ]),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(
                      child: Text(action.isEmpty ? "Update" : action,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    ),
                    Text(date, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  ]),
                  if (from.isNotEmpty || to.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        from.isNotEmpty && to.isNotEmpty ? "$from → $to" : (to.isNotEmpty ? to : from),
                        style: const TextStyle(fontSize: 12, color: Colors.teal, fontWeight: FontWeight.w600),
                      ),
                    ),
                  if (remarks.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(remarks, style: const TextStyle(fontSize: 12, color: Colors.black87)),
                    ),
                  if (byName.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text("by $byName", style: const TextStyle(fontSize: 11, color: Colors.blueGrey)),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
