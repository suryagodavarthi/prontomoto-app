// dashboard_common.dart
// Server-driven dashboard data, shared by all role dashboards.
// Mirrors the web portal dashboard component:
//  - Admin/StateAdmin/SuperAdmin: open cases (scoped to assignedStates/Districts
//    via the filter endpoints) + all completed cases.
//  - Everyone else: GET /workflows/open/user-dashboard?phone&role which returns
//    OPEN/AGED/COMPLETED counts, avg TAT, openCases and completedCases.
// Falls back to the legacy /workflows/open + client-side step filter when the
// stats endpoint is unavailable.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'services/api_service.dart';
import 'main.dart';

class DashboardData {
  final List<dynamic> openCases;
  final List<dynamic> completedCases;
  final int openCount;
  final int agedCount;
  final int completedCount;
  final double avgTatHours;

  /// True when counts came from the server stats endpoint (includes AGED/TAT).
  final bool serverStats;

  const DashboardData({
    required this.openCases,
    required this.completedCases,
    required this.openCount,
    required this.agedCount,
    required this.completedCount,
    required this.avgTatHours,
    required this.serverStats,
  });
}

bool _isAdminRole(String role) {
  final r = role.toLowerCase();
  return r == 'admin' || r == 'stateadmin' || r == 'superadmin';
}

/// assignedStates/assignedDistricts are stored either as a JSON array string
/// or a real list — same tolerant parsing as the portal's parseJsonArray().
List<String> _parseJsonArray(dynamic value) {
  if (value == null) return [];
  if (value is List) return value.map((e) => e.toString()).toList();
  if (value is String && value.trim().isNotEmpty) {
    try {
      final decoded = jsonDecode(value);
      if (decoded is List) return decoded.map((e) => e.toString()).toList();
    } catch (_) {}
  }
  return [];
}

void _sortByCreatedAtDesc(List<dynamic> list) {
  list.sort((a, b) {
    final da = (a is Map ? (a['createdAt'] ?? '') : '').toString();
    final db = (b is Map ? (b['createdAt'] ?? '') : '').toString();
    return db.compareTo(da);
  });
}

/// Loads dashboard data for the current user.
/// [stepMatcher] keeps only cases relevant to the calling dashboard; it is only
/// applied to lists that are NOT already scoped by the server (admin + fallback
/// paths). Pass null to keep everything.
Future<DashboardData> loadDashboardData({bool Function(Map c)? stepMatcher}) async {
  final api = ApiService();
  final role = currentUserRole;
  final phone = currentUserPhone;

  List<dynamic> applyMatcher(List<dynamic> list) {
    if (stepMatcher == null) return list;
    return list.where((c) => c is Map && stepMatcher(Map<String, dynamic>.from(c))).toList();
  }

  // ── Admin path ──────────────────────────────────────────────────────────
  if (_isAdminRole(role)) {
    List<dynamic> open = [];
    try {
      final userDoc = phone.isNotEmpty ? await api.getUserById(phone) : <String, dynamic>{};
      final districts = _parseJsonArray(userDoc['assignedDistricts']);
      final states = _parseJsonArray(userDoc['assignedStates']);
      if (districts.isNotEmpty) {
        open = await api.getWorkflowsByDistricts(districts);
      } else if (states.isNotEmpty) {
        open = await api.getWorkflowsByStates(states);
      } else {
        open = await api.getOpenValuations();
      }
    } catch (_) {
      open = await api.getOpenValuations();
    }
    final completed = await api.getCompletedCases();
    final scopedOpen = applyMatcher(open);
    _sortByCreatedAtDesc(scopedOpen);
    _sortByCreatedAtDesc(completed);
    return DashboardData(
      openCases: scopedOpen,
      completedCases: completed,
      openCount: scopedOpen.length,
      agedCount: 0,
      completedCount: completed.length,
      avgTatHours: 0,
      serverStats: false,
    );
  }

  // ── User path: server stats ─────────────────────────────────────────────
  if (phone.isNotEmpty && role.isNotEmpty) {
    final stats = await api.getUserDashboardStats(phone, role);
    if (stats != null) {
      final open = (stats['openCases'] is List) ? List<dynamic>.from(stats['openCases']) : <dynamic>[];
      final completed =
          (stats['completedCases'] is List) ? List<dynamic>.from(stats['completedCases']) : <dynamic>[];
      _sortByCreatedAtDesc(open);
      _sortByCreatedAtDesc(completed);
      return DashboardData(
        // Server already scopes openCases to this user's step + assignments.
        openCases: open,
        completedCases: completed,
        openCount: (stats['openCount'] as num?)?.toInt() ?? open.length,
        agedCount: (stats['agedCount'] as num?)?.toInt() ?? 0,
        completedCount: (stats['completedCount'] as num?)?.toInt() ?? completed.length,
        avgTatHours: (stats['avgTatHours'] as num?)?.toDouble() ?? 0,
        serverStats: true,
      );
    }
  }

  // ── Fallback: legacy open list + client-side step filter ────────────────
  final all = await api.getOpenValuations();
  final scoped = applyMatcher(all);
  _sortByCreatedAtDesc(scoped);
  return DashboardData(
    openCases: scoped,
    completedCases: const [],
    openCount: scoped.length,
    agedCount: 0,
    completedCount: 0,
    avgTatHours: 0,
    serverStats: false,
  );
}

/// OPEN / AGED / COMPLETED / AVG TAT stat tiles shown at the top of dashboards.
class DashboardStatsHeader extends StatelessWidget {
  final DashboardData data;
  final Color color;
  const DashboardStatsHeader({super.key, required this.data, this.color = const Color(0xFF007B7B)});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(children: [
        _tile("OPEN", data.openCount.toString(), color),
        const SizedBox(width: 8),
        _tile("AGED", data.serverStats ? data.agedCount.toString() : "—", Colors.orange),
        const SizedBox(width: 8),
        _tile("DONE", data.completedCount.toString(), Colors.green),
        const SizedBox(width: 8),
        _tile("TAT", data.serverStats ? "${data.avgTatHours.toStringAsFixed(0)}h" : "—", Colors.blueGrey),
      ]),
    );
  }

  Widget _tile(String label, String value, Color c) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: c.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: c.withOpacity(0.35)),
        ),
        child: Column(children: [
          Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: c)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: c)),
        ]),
      ),
    );
  }
}
