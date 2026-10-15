// case_search_page.dart
// Finds any case by Unique ID, vehicle, chassis or engine number, open, completed
// or archived, as the portal dashboard's search box does (GET /valuations/search).
// Terms of three characters or more go to the server, as on the portal.

import 'dart:async';

import 'package:flutter/material.dart';

import 'main.dart';
import 'date_format.dart';
import 'services/api_service.dart';

class CaseSearchPage extends StatefulWidget {
  const CaseSearchPage({super.key});

  @override
  State<CaseSearchPage> createState() => _CaseSearchPageState();
}

class _CaseSearchPageState extends State<CaseSearchPage> {
  static const _minServerSearch = 3;

  final _api = ApiService();
  final _controller = TextEditingController();
  Timer? _debounce;
  List<dynamic> _results = [];
  bool _searching = false;
  String _lastQuery = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  // Debounced so a search does not fire a query per keystroke.
  void _onChanged(String term) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => _run(term));
  }

  Future<void> _run(String term) async {
    final q = term.trim();
    if (q.length < _minServerSearch) {
      setState(() {
        _results = [];
        _lastQuery = '';
        _searching = false;
      });
      return;
    }
    setState(() => _searching = true);
    final rows = await _api.searchCases(q);
    if (!mounted || _controller.text.trim() != q) return;
    setState(() {
      _results = rows;
      _lastQuery = q;
      _searching = false;
    });
  }

  String _s(Map m, String k) => (m[k] ?? '').toString();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(
            hintText: 'Unique ID, vehicle, chassis or engine no.',
            border: InputBorder.none,
          ),
          onChanged: _onChanged,
          onSubmitted: _run,
        ),
      ),
      body: _searching
          ? const Center(child: CircularProgressIndicator())
          : _controller.text.trim().length < _minServerSearch
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('Type at least 3 characters.', style: TextStyle(color: Colors.grey)),
                  ),
                )
              : _results.isEmpty && _lastQuery.isNotEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text('No case matches "$_lastQuery" by reference, vehicle, chassis or engine number.',
                            textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
                      ),
                    )
                  : ListView.separated(
                      itemCount: _results.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final r = Map<String, dynamic>.from(_results[i] as Map);
                        final ref = _s(r, 'referenceNumber');
                        final status = _s(r, 'status');
                        final created = formatDdMmYyyy(_s(r, 'createdAt'));
                        return ListTile(
                          title: Text(_s(r, 'vehicleNumber'), style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text([
                            if (ref.isNotEmpty) ref,
                            if (_s(r, 'applicantName').isNotEmpty) _s(r, 'applicantName'),
                            if (_s(r, 'workflow').isNotEmpty) _s(r, 'workflow'),
                            if (status.isNotEmpty) status,
                            if (created.isNotEmpty) created,
                          ].join(' • ')),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => navigateToCase(context, r, () {}),
                        );
                      },
                    ),
    );
  }
}
