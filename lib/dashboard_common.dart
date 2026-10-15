// dashboard_common.dart
// Server-driven dashboard data, shared by all role dashboards.
// Mirrors the web portal dashboard component:
//  - Admin/StateAdmin/SuperAdmin: open cases (scoped to assignedStates/Districts
//    via the filter endpoints) + all completed cases.
//  - Everyone else: GET /workflows/open/user-dashboard?phone&role which returns
//    OPEN/AGED/COMPLETED counts, avg TAT, openCases and completedCases.
// Falls back to the legacy /workflows/open + client-side step filter when the
// stats endpoint is unavailable.

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

void _sortByCreatedAtDesc(List<dynamic> list) {
  list.sort((a, b) {
    final da = (a is Map ? (a['createdAt'] ?? '') : '').toString();
    final db = (b is Map ? (b['createdAt'] ?? '') : '').toString();
    return db.compareTo(da);
  });
}

/// How long a completed case stays on the dashboard after approval, as the
/// portal's COMPLETED_VISIBLE_DAYS. A display rule only: search still finds it.
const int completedVisibleDays = 30;

List<dynamic> _withinCompletedWindow(List<dynamic> rows) {
  final cutoff = DateTime.now().subtract(const Duration(days: completedVisibleDays));
  return rows.where((v) {
    if (v is! Map) return true;
    final t = (v['completedAt'] ?? v['updatedAt'] ?? v['createdAt'])?.toString();
    if (t == null || t.isEmpty) return true; // no date: keep rather than hide
    final d = DateTime.tryParse(t);
    return d == null || !d.isBefore(cutoff);
  }).toList();
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
  // As the portal does: Admin, StateAdmin and SuperAdmin are exempt from
  // assignment, so they see every open case, at every stage, whatever states or
  // districts their user record lists. Filtering them by area, and by the
  // calling dashboard's stage, hid most cases from admins.
  if (_isAdminRole(role)) {
    final open = await api.getOpenValuations();
    final completed = _withinCompletedWindow(await api.getCompletedCases());
    final scopedOpen = List<dynamic>.from(open);
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
      final completed = _withinCompletedWindow(
          (stats['completedCases'] is List) ? List<dynamic>.from(stats['completedCases']) : <dynamic>[]);
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
