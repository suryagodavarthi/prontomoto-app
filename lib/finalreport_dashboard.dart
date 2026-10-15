import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'services/api_service.dart';
import 'services/brand.dart';
import 'main.dart';
import 'avo_dashboard.dart';
import 'qc_dashboard.dart';
import 'dashboard_common.dart';
import 'case_history_page.dart';
import 'case_search_page.dart';
import 'case_info_bar.dart';
import 'report_preview_page.dart';
import 'report_paper_view.dart';
import 'qc_review_page.dart';
import 'qc_checklist.dart' show buildQcChecklist, applySavedChecklist;
import 'inspection_score.dart' show scoreInspection;
import 'date_format.dart';

// =============================================================================
// FINAL REPORT DASHBOARD — list of cases in FinalReport step (step 5)
// =============================================================================

class FinalReportDashboard extends StatefulWidget {
  final String userName;
  const FinalReportDashboard({super.key, required this.userName});

  @override
  State<FinalReportDashboard> createState() => _FinalReportDashboardState();
}

class _FinalReportDashboardState extends State<FinalReportDashboard> {
  bool _isLoading = true;
  List<dynamic> _allCases = [];
  List<dynamic> _completedCases = [];
  List<dynamic> _cases = [];
  DashboardData? _dashData;
  String _selectedSubTab = "All";

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      // FinalReport/admin view spans every stage — no step matcher.
      final data = await loadDashboardData();
      if (mounted) {
        setState(() {
          _dashData = data;
          _allCases = data.openCases;
          _completedCases = data.completedCases;
          _isLoading = false;
        });
        _applySubTab();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to load cases: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _applySubTab() {
    List<dynamic> filtered;
    if (_selectedSubTab == "Completed") {
      filtered = List.from(_completedCases);
    } else if (_selectedSubTab == "All") {
      filtered = List.from(_allCases);
    } else {
      filtered = _allCases.where((c) {
        final wf = (c['workflow'] ?? "").toString().toLowerCase();
        if (_selectedSubTab == "Stakeholder") return wf.contains("stakeholder");
        if (_selectedSubTab == "Backend") return wf.contains("backend");
        if (_selectedSubTab == "AVO") return wf.contains("avo") || wf.contains("inspection");
        if (_selectedSubTab == "QC") return wf.contains("qc") || wf.contains("quality");
        if (_selectedSubTab == "FinalReport") return wf.contains("final") || wf.contains("finalreport");
        return true;
      }).toList();
    }
    setState(() => _cases = filtered);
  }

  int _stageCount(String stage) {
    return _allCases.where((c) {
      final wf = (c['workflow'] ?? "").toString().toLowerCase();
      if (stage == "Stakeholder") return wf.contains("stakeholder");
      if (stage == "Backend") return wf.contains("backend");
      if (stage == "AVO") return wf.contains("avo") || wf.contains("inspection");
      if (stage == "QC") return wf.contains("qc") || wf.contains("quality");
      if (stage == "FinalReport") return wf.contains("final") || wf.contains("finalreport");
      return true;
    }).length;
  }

  void _onSubTabSelected(String tab) {
    setState(() => _selectedSubTab = tab);
    _applySubTab();
  }

  Widget _buildSubTabChip(String label, int count) {
    final bool isSelected = _selectedSubTab == label;
    return GestureDetector(
      onTap: () => _onSubTabSelected(label),
      child: Chip(
        label: Text("$label ($count)",
            style: TextStyle(
                color: isSelected ? Colors.white : Colors.teal,
                fontWeight: FontWeight.bold,
                fontSize: 12)),
        backgroundColor: isSelected ? Colors.teal : Colors.teal.withOpacity(0.1),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: isSelected ? Colors.teal : Colors.transparent)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final int allCount = _allCases.length;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "${Brand.profile.name} — ${const {'admin', 'superadmin', 'stateadmin'}.contains(currentUserRole) ? 'All Cases' : 'Final Report'}",
              style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 17),
            ),
            Text("Hello, ${widget.userName}", style: const TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.search, color: Colors.black), tooltip: "Search cases",
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CaseSearchPage()))),
          IconButton(icon: const Icon(Icons.refresh, color: Colors.black), onPressed: _load),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.red),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (context.mounted) {
                Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginPage()));
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          if (_dashData != null) DashboardStatsHeader(data: _dashData!, color: Colors.teal),
          Container(
            height: 50,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _buildSubTabChip("All", allCount),
                const SizedBox(width: 8),
                _buildSubTabChip("Stakeholder", _stageCount("Stakeholder")),
                const SizedBox(width: 8),
                _buildSubTabChip("Backend", _stageCount("Backend")),
                const SizedBox(width: 8),
                _buildSubTabChip("AVO", _stageCount("AVO")),
                const SizedBox(width: 8),
                _buildSubTabChip("QC", _stageCount("QC")),
                const SizedBox(width: 8),
                _buildSubTabChip("FinalReport", _stageCount("FinalReport")),
                const SizedBox(width: 8),
                _buildSubTabChip("Completed", _completedCases.length),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _cases.isEmpty
                    ? const Center(child: Text("No cases in this view.", style: TextStyle(color: Colors.grey)))
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _cases.length,
                          itemBuilder: (context, i) => _buildCard(_cases[i]),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(Map<String, dynamic> item) {
    final plate = item['vehicleNumber'] ?? "Unknown";
    final location = item['location'] ?? "Unknown";
    final applicant = item['applicantName'] ?? "Unknown";
    final itemStatus = (item['status'] ?? "").toString();
    final bool redFlag = item['redFlag'] == true;
    String? assignedTo = item['assignedTo']?.toString();
    if (assignedTo != null && assignedTo.isEmpty) assignedTo = null;
    final bool isReturned = itemStatus.toLowerCase().contains("return");

    String? dateStr = item['createdAt'];
    int daysOld = 0;
    if (dateStr != null) {
      final created = DateTime.tryParse(dateStr) ?? DateTime.now();
      daysOld = DateTime.now().difference(created).inDays;
    }
    final ageColor = daysOld <= 1 ? Colors.green : daysOld == 2 ? Colors.orange : Colors.red;
    final bgAge = daysOld <= 1 ? Colors.green.shade50 : daysOld == 2 ? Colors.orange.shade50 : Colors.red.shade50;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(plate, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text("$location • $applicant", style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                  if (assignedTo != null) ...[
                    const SizedBox(height: 2),
                    Text("Assigned: $assignedTo", style: const TextStyle(fontSize: 11, color: Colors.blueGrey)),
                  ],
                  const SizedBox(height: 6),
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: Colors.teal.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.teal.shade200)),
                      child: Text(item['workflow'] ?? "Unknown", style: const TextStyle(fontSize: 10, color: Colors.teal, fontWeight: FontWeight.bold)),
                    ),
                    if (redFlag) ...[const SizedBox(width: 6), const Text("⚑", style: TextStyle(color: Colors.red, fontSize: 14))],
                    if (itemStatus.isNotEmpty) ...[const SizedBox(width: 6), Text(itemStatus, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isReturned ? Colors.red : Colors.blueGrey))],
                  ]),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                      color: bgAge,
                      borderRadius: BorderRadius.circular(4)),
                  child: Text("TAT: ${daysOld}d",
                      style: TextStyle(
                          color: ageColor,
                          fontSize: 10,
                          fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 30,
                  child: OutlinedButton(
                    onPressed: () => navigateToCase(context, item, _load),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.teal.shade300),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                      foregroundColor: Colors.teal,
                    ),
                    child: const Text("ENTER",
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// FINAL REPORT DETAIL PAGE
// =============================================================================

class FinalReportDetailPage extends StatefulWidget {
  final Map<String, dynamic> summaryData;
  const FinalReportDetailPage({super.key, required this.summaryData});

  @override
  State<FinalReportDetailPage> createState() => _FinalReportDetailPageState();
}

class _FinalReportDetailPageState extends State<FinalReportDetailPage> {
  final ApiService api = ApiService();
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = true;
  bool _isCompleting = false;
  bool _isReturning = false;
  bool _downloadingPdf = false;

  // Server data
  Map<String, dynamic> _finalReport = {};
  Map<String, dynamic> _workflowTable = {};
  List<dynamic> _notes = [];

  // Return banner
  String? _returnedBy;
  String? _returnMessage;

  // The report, as the portal's Final Report page lays it out.
  String? _reference;
  num? _lowRange;
  num? _midRange;
  num? _highRange;
  bool _rangeLoading = false;
  List<String> _selectedPhotoKeys = [];
  Map<String, String?> _cl = {};
  Map<String, String> _clRemarks = {};
  double? _overallScore;
  double? _brakesScore;

  /// Approved once the workflow row reads Completed: Approve completes step 5,
  /// which sets it. The download stays locked until then, as in the portal,
  /// because an unapproved report is indistinguishable from a final one.
  bool get _caseApproved =>
      (_workflowTable['status'] ?? _workflowTable['Status'] ?? '').toString().trim().toLowerCase() == 'completed';

  /// Approve, return or reject: final report staff and every admin.
  bool get _canDecide {
    const perms = ['CanCreateFinalReport', 'CanEditFinalReport', 'Admin', 'StateAdmin', 'SuperAdmin'];
    final held = {...currentUserRoles.map((r) => r.toLowerCase()), currentUserRole.toLowerCase()};
    return perms.any((p) => held.contains(p.toLowerCase()));
  }

  // Note adder
  final _noteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // CONTEXT HELPER
  // ---------------------------------------------------------------------------
  Map<String, String> _ctx() {
    final id = widget.summaryData['valuationId']?.toString() ??
        widget.summaryData['id']?.toString() ??
        "";
    String vNo =
        (widget.summaryData['vehicleNumber'] ?? "").toString().trim();
    if (vNo.isEmpty) vNo = "UNKNOWN";
    String contact =
        (widget.summaryData['applicantContact'] ?? "").toString().trim();
    if (contact.isEmpty) contact = "0000000000";
    return {"id": id, "vNo": vNo, "contact": contact};
  }

  // ---------------------------------------------------------------------------
  // DATA LOADING
  // ---------------------------------------------------------------------------
  Future<void> _loadAllData() async {
    final ctx = _ctx();
    setState(() => _isLoading = true);

    try {
      final results = await Future.wait([
        api.getFinalReport(ctx["id"]!, ctx["vNo"]!, ctx["contact"]!),
        api.getWorkflowTable(ctx["id"]!, ctx["vNo"]!, ctx["contact"]!),
        api.getNotes(ctx["id"]!),
      ]);

      if (!mounted) return;
      final report = results[0] as Map<String, dynamic>;
      final table = results[1] as Map<String, dynamic>;
      final notes = results[2] as List<dynamic>;

      setState(() {
        _finalReport = report;
        _workflowTable = table;
        _notes = notes;
        _checkReturnStatus(table);
        _deriveReport();
        _isLoading = false;
      });
      _loadReportExtras();
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to load case details: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  /// The checklist, scores and remarks the report prints, from the same engine the
  /// QC page uses, with QC's saved verdicts on top — the portal's prefillChecklist
  /// followed by applySavedChecklist.
  void _deriveReport() {
    final qc = _finalReport['qualityControl'] is Map ? Map<String, dynamic>.from(_finalReport['qualityControl']) : <String, dynamic>{};
    final segment = _readStr(_finalReport, ['stakeholder.vehicleSegment']);
    final type = widget.summaryData['valuationType']?.toString();

    final scored = scoreInspection(
      segment,
      _finalReport['inspectionDetails'] is Map ? Map<String, dynamic>.from(_finalReport['inspectionDetails']) : null,
      fallbackType: type,
    );
    _overallScore = scored.overall;
    _brakesScore = scored.sections.where((x) => x.section == 'BRAKES').map((x) => x.score).firstOrNull;

    final photos = _finalReport['photoUrls'];
    final photoKeys = photos is Map
        ? [for (final e in photos.entries) if (e.value != null && e.value.toString().isNotEmpty) e.key.toString()]
        : <String>[];
    final result = buildQcChecklist(
      report: _finalReport,
      overallRating: (qc['overallRating'] ?? '').toString(),
      chassisPunch: (qc['chassisPunch'] ?? '').toString(),
      photoKeys: photoKeys,
      vehicleSegment: segment,
      valuationType: type,
    );
    applySavedChecklist(result, qc['qcChecklist'] is Map ? qc['qcChecklist'] as Map : null, null);
    _cl = result.cl;
    final remarks = qc['qcChecklistRemarks'];
    _clRemarks = remarks is Map
        ? {for (final e in remarks.entries) if (e.value != null) e.key.toString(): e.value.toString()}
        : {};
  }

  /// "8.2", as the portal's getRatingDisplay: the derived score, else the saved rating.
  String? get _ratingDisplay {
    if (_overallScore != null) return _overallScore!.toStringAsFixed(1);
    final raw = _readStr(_finalReport, ['qualityControl.overallRating']).trim();
    if (raw.isEmpty) return null;
    final n = double.tryParse(raw);
    if (n != null) return n.toStringAsFixed(1);
    const words = {'EXCELLENT': '9.5', 'VERY GOOD': '8.5', 'GOOD': '7.5', 'AVERAGE': '5.0', 'BELOW AVERAGE': '3.5', 'POOR': '2.5', 'VERY POOR': '1.5'};
    return words[raw.toUpperCase()] ?? raw;
  }

  /// The Unique ID, QC's photo selection, and the market range (asked for when
  /// the case has none, as the portal's ensureRange does).
  Future<void> _loadReportExtras() async {
    final ctx = _ctx();
    num? n(String path) => num.tryParse(_readStr(_finalReport, [path]));
    setState(() {
      _lowRange = n('valuationResponse.lowRange');
      _midRange = n('valuationResponse.midRange');
      _highRange = n('valuationResponse.highRange');
    });
    final results = await Future.wait([
      api.getReferenceNumber(ctx["id"]!, ctx["vNo"]!, ctx["contact"]!),
      api.getGallerySelection(ctx["id"]!, ctx["vNo"]!, ctx["contact"]!),
    ]);
    if (!mounted) return;
    setState(() {
      _reference = results[0] as String?;
      _selectedPhotoKeys = results[1] as List<String>;
    });

    if ((_lowRange ?? 0) > 0 && (_highRange ?? 0) > 0) return;
    setState(() => _rangeLoading = true);
    final range = await api.getMarketRange(ctx["id"]!, ctx["vNo"]!, ctx["contact"]!);
    if (!mounted) return;
    setState(() {
      _rangeLoading = false;
      if (range != null) {
        _lowRange = range['lowRange'];
        _midRange = range['midRange'];
        _highRange = range['highRange'];
      }
    });
  }

  /// Mirrors the web portal's return status check for FinalReport step.
  void _checkReturnStatus(Map<String, dynamic> table) {
    if (table.isEmpty) {
      _returnedBy = null;
      _returnMessage = null;
      return;
    }
    final isRedFlag =
        table['redFlag']?.toString().toLowerCase() == 'true' ||
            table['RedFlag']?.toString().toLowerCase() == 'true';
    final remark = (table['remarks'] ?? table['Remarks'] ?? '').toString();
    final currentStep =
        (table['workflow'] ?? table['Workflow'] ?? '').toString();
    final isFrStep = currentStep == 'FinalReport' || currentStep == '5';

    if (!isRedFlag || remark.isEmpty || !isFrStep) {
      _returnedBy = null;
      _returnMessage = null;
      return;
    }

    const prefix = "RETURNED BY ";
    final remarkUpper = remark.toUpperCase();

    if (remarkUpper.startsWith(prefix)) {
      final splitIndex = remark.indexOf(':');
      if (splitIndex != -1) {
        final returnerName = remark.substring(12, splitIndex).trim();
        // FinalReport shouldn't show its own return banner
        const invalidReturners = ['FINALREPORT', 'FINAL'];
        if (invalidReturners.contains(returnerName.toUpperCase())) {
          _returnedBy = null;
          _returnMessage = null;
          return;
        }
        _returnedBy = returnerName;
        _returnMessage = remark.substring(splitIndex + 1).trim();
      } else {
        _returnedBy = "Previous Stage";
        _returnMessage = remark;
      }
    } else {
      _returnedBy = null;
      _returnMessage = remark;
    }
  }

  // ---------------------------------------------------------------------------
  // KEY ACTIONS
  // ---------------------------------------------------------------------------

  /// The portal's Approve Case: completing step 5 with the approver's name. The
  /// backend closes the workflow row and dispatches the report; payment is no
  /// longer written here (it has its own page).
  Future<void> _onApprove() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Approve Case"),
        content: const Text("Once approved, the final report will be marked complete and dispatched."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Approve"),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _isCompleting = true);
    final ctx = _ctx();
    final approvedBy = currentUserName.isNotEmpty ? currentUserName : (currentUserPhone.isNotEmpty ? currentUserPhone : 'Unknown');
    final res = await api.completeWorkflow(ctx["id"]!, 5, ctx["vNo"]!, ctx["contact"]!, approvedBy: approvedBy);
    if (!mounted) return;
    if (res['success'] != true) {
      setState(() => _isCompleting = false);
      _showError("Approval failed: ${res['message']}");
      return;
    }
    await api.addWorkflowHistory(
      valuationId: ctx["id"]!,
      action: "Valuation Completed",
      remarks: "Final report approved by $approvedBy",
      performedByUserId: currentUserId,
      performedByUserName: currentUserName,
      statusFrom: "FinalReport",
      statusTo: "Completed",
    );
    // Stay on the page: approving is what unlocks the download, so leaving for
    // the case list would send the approver straight back here.
    final table = await api.getWorkflowTable(ctx["id"]!, ctx["vNo"]!, ctx["contact"]!);
    if (!mounted) return;
    setState(() {
      _isCompleting = false;
      _workflowTable = table.isNotEmpty ? table : {..._workflowTable, "status": "Completed"};
    });
    _showSuccess("Case approved. Final report has been dispatched — you can now download the PDF.");
  }

  /// The portal's Reject Case. Records the reason in the case history.
  Future<void> _onReject() async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Reject Case"),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          decoration: const InputDecoration(border: OutlineInputBorder(), hintText: "Reason for rejection"),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              if (controller.text.trim().isEmpty) return;
              Navigator.pop(ctx, controller.text.trim());
            },
            child: const Text("Reject"),
          ),
        ],
      ),
    );
    if (reason == null || reason.isEmpty) return;
    await api.addWorkflowHistory(
      valuationId: _ctx()["id"]!,
      action: "Final Report Rejected",
      remarks: reason,
      performedByUserId: currentUserId,
      performedByUserName: currentUserName,
      statusFrom: "FinalReport",
    );
    if (!mounted) return;
    _showSuccess("Case rejected. Reason has been recorded.");
    Navigator.pop(context);
  }

  Future<void> _onReturnPressed() async {
    final result = await _showReturnReasonDialog();
    if (result == null) return;
    final reason = result['reason'] ?? '';
    if (reason.trim().isEmpty) return;
    await _attemptReturn(reason: reason.trim(), target: result['target'] ?? 'QualityControl', overrideAssigneeId: "");
  }

  Future<void> _attemptReturn({
    required String reason,
    required String target,
    required String overrideAssigneeId,
  }) async {
    setState(() => _isReturning = true);
    final ctx = _ctx();
    final user = FirebaseAuth.instance.currentUser;
    final userId = user?.uid ?? user?.phoneNumber ?? 'unknown';
    final userName = user?.displayName ??
        user?.email?.split('@').first ??
        'FinalReport Reviewer';

    final res = await api.returnWorkflow(
      valuationId: ctx["id"]!,
      vehicleNumber: ctx["vNo"]!,
      applicantContact: ctx["contact"]!,
      currentStep: "FinalReport",
      returnReason: reason,
      currentUserId: userId,
      currentUserName: userName,
      targetReturnStep: target,
      overrideAssigneeId: overrideAssigneeId,
    );
    final targetLabel = target == 'AVO' ? 'AVO' : 'QC';

    if (!mounted) return;

    if (res['success'] == true) {
      await api.addWorkflowHistory(
        valuationId: ctx["id"]!,
        action: "FinalReport Returned to $targetLabel",
        remarks: reason,
        performedByUserId: currentUserId,
        performedByUserName: currentUserName,
        statusFrom: "FinalReport",
        statusTo: targetLabel,
      );
      if (!mounted) return;
      setState(() => _isReturning = false);
      _showSuccess(target == 'AVO' ? "Case returned to the inspector" : "Case returned to Quality Control");
      Navigator.pop(context);
      return;
    }

    final statusCode = res['statusCode'];
    final message = (res['message'] ?? '').toString();
    final needsOverride =
        statusCode == 400 && message.toLowerCase().contains('overrideassigneeid');

    if (needsOverride) {
      setState(() => _isReturning = false);
      final picked = target == 'AVO'
          ? await _showOverridePickerDialog('CanEditInspection', 'AVO')
          : await _showOverridePickerDialog('QualityControl', 'QC');
      if (picked == null) return;
      await _attemptReturn(reason: reason, target: target, overrideAssigneeId: picked);
      return;
    }

    setState(() => _isReturning = false);
    _showError("Return failed: ${res['message']}");
  }

  // ---------------------------------------------------------------------------
  // PDF: preview always, download only once approved (as the portal)
  // ---------------------------------------------------------------------------

  /// The report, fetched once: Preview and Download share it rather than
  /// generating it twice, as the portal does.
  Uint8List? _pdfBytes;

  /// Fetches the report from the report service the portal uses. Built on
  /// demand, so it takes a while; null when it could not be had.
  Future<Uint8List?> _fetchPdf() async {
    if (_pdfBytes != null) return _pdfBytes;
    final ctx = _ctx();
    final valuationId = ctx["id"] ?? "";
    if (valuationId.isEmpty) {
      _showError("Valuation ID not available for PDF generation.");
      return null;
    }
    // _ctx() fills in placeholders when these are missing, and the report
    // service cannot find a case from those, so stop instead of asking for one.
    final vehicleNumber = ctx["vNo"]!;
    final applicantContact = ctx["contact"]!;
    if (vehicleNumber == "UNKNOWN" || applicantContact == "0000000000") {
      _showError("Vehicle number or applicant contact missing for this case.");
      return null;
    }

    final url = Uri.parse("${ApiService.pdfBaseUrl}/api/Valuation/FinalReport/pdf").replace(queryParameters: {
      "id": valuationId,
      "vehicleNumber": vehicleNumber,
      "applicantContact": applicantContact,
    });

    if (_downloadingPdf) return null;
    setState(() => _downloadingPdf = true);
    try {
      final res = await apiHttp.get(url).timeout(const Duration(minutes: 3));
      if (res.statusCode != 200) {
        _showError("Report service returned ${res.statusCode}. Try again.");
        return null;
      }
      if (res.bodyBytes.length < 5 || String.fromCharCodes(res.bodyBytes.take(4)) != "%PDF") {
        _showError("The report came back empty. Try again.");
        return null;
      }
      _pdfBytes = res.bodyBytes;
      return _pdfBytes;
    } on TimeoutException {
      _showError("The report is taking too long to build. Try again.");
      return null;
    } catch (e) {
      _showError("PDF error: $e");
      return null;
    } finally {
      if (mounted) setState(() => _downloadingPdf = false);
    }
  }

  /// Shows the report inside the app, with nothing to save it from until the
  /// case is approved. Approving can be done from the preview, as on the portal.
  Future<void> _onPreview() async {
    final bytes = await _fetchPdf();
    if (bytes == null || !mounted) return;
    final action = await Navigator.push<ReportPreviewAction>(
      context,
      MaterialPageRoute(
        builder: (_) => ReportPreviewPage(
          pdfBytes: bytes,
          vehicleNumber: _ctx()["vNo"]!,
          caseApproved: _caseApproved,
          canApprove: _canDecide,
        ),
      ),
    );
    if (!mounted) return;
    if (action == ReportPreviewAction.approve) await _onApprove();
    if (action == ReportPreviewAction.download) await _onDownload();
  }

  /// Saves the report and opens it, once the case is approved.
  Future<void> _onDownload() async {
    if (!_caseApproved) return;
    final bytes = await _fetchPdf();
    if (bytes == null || !mounted) return;
    try {
      // Same file name as the portal's download.
      final dir = await getApplicationDocumentsDirectory();
      final file = File("${dir.path}/${_ctx()["vNo"]}_report.pdf");
      await file.writeAsBytes(bytes, flush: true);
      final opened = await OpenFilex.open(file.path, type: "application/pdf");
      if (opened.type != ResultType.done) {
        _showError("Report saved, but no PDF app could open it: ${opened.message}");
      }
    } catch (e) {
      _showError("PDF error: $e");
    }
  }

  // ---------------------------------------------------------------------------
  // NOTES
  // ---------------------------------------------------------------------------
  Future<void> _addNote() async {
    if (_noteController.text.isEmpty) return;
    await api.addNote(_ctx()["id"]!, _noteController.text);
    _noteController.clear();
    final notes = await api.getNotes(_ctx()["id"]!);
    if (mounted) setState(() => _notes = notes);
  }

  // ---------------------------------------------------------------------------
  // DIALOGS
  // ---------------------------------------------------------------------------
  Future<Map<String, String>?> _showReturnReasonDialog() {
    final controller = TextEditingController();
    String target = 'QualityControl';
    return showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text("Return with Recommendations"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<String>(
                value: target,
                decoration: const InputDecoration(labelText: "Send back to", border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'QualityControl', child: Text("Quality Control")),
                  DropdownMenuItem(value: 'AVO', child: Text("Inspector (AVO)")),
                ],
                onChanged: (v) => setDialogState(() => target = v ?? 'QualityControl'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                autofocus: true,
                maxLines: 3,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: "Recommendations / reason for returning",
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
              onPressed: () {
                if (controller.text.trim().isEmpty) return;
                Navigator.pop(ctx, {"reason": controller.text.trim(), "target": target});
              },
              child: const Text("Return"),
            ),
          ],
        ),
      ),
    );
  }

  Future<String?> _showOverridePickerDialog(
      String role, String targetLabel) async {
    setState(() => _isReturning = true);
    final users = await api.getUsersByRole(role);
    if (!mounted) return null;
    setState(() => _isReturning = false);

    if (users.isEmpty) {
      _showError("No $targetLabel users available. Contact admin.");
      return null;
    }

    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Original $targetLabel user unavailable"),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Pick a $targetLabel user to assign to:",
                  style: const TextStyle(color: Colors.grey, fontSize: 13)),
              const SizedBox(height: 12),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: users.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final u = users[i];
                    final name =
                        (u['name'] ?? u['displayName'] ?? 'User').toString();
                    final phone =
                        (u['phoneNumber'] ?? u['phone'] ?? '').toString();
                    final id = (u['userId'] ?? u['id'] ?? '').toString();
                    return ListTile(
                      dense: true,
                      title: Text(name),
                      subtitle: phone.isEmpty
                          ? null
                          : Text(phone,
                              style: const TextStyle(fontSize: 11)),
                      onTap: () => Navigator.pop(ctx, id),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancel"))
        ],
      ),
    );
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  void _showSuccess(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.green));
  }

  void _showFullScreenImage(String url, String label) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                child: Image.network(
                  url,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Center(
                    child: Icon(Icons.broken_image, color: Colors.white, size: 64),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 16,
              left: 16,
              right: 48,
              child: Text(label,
                  style: const TextStyle(color: Colors.white, fontSize: 14,
                      shadows: [Shadow(blurRadius: 4, color: Colors.black)])),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // UTILITY
  // ---------------------------------------------------------------------------
  String _readStr(Map? data, List<String> keys) {
    if (data == null) return "";
    for (final key in keys) {
      if (key.contains('.')) {
        dynamic current = data;
        bool found = true;
        for (final part in key.split('.')) {
          if (current is Map) {
            String? matchedKey;
            for (final k in current.keys) {
              if (k.toString().toLowerCase() == part.toLowerCase()) {
                matchedKey = k.toString();
                break;
              }
            }
            if (matchedKey == null) {
              found = false;
              break;
            }
            current = current[matchedKey];
          } else {
            found = false;
            break;
          }
        }
        if (found &&
            current != null &&
            current.toString().isNotEmpty &&
            current.toString() != "null") {
          return current.toString();
        }
      } else {
        for (final k in data.keys) {
          if (k.toString().toLowerCase() == key.toLowerCase()) {
            final v = data[k];
            if (v != null &&
                v.toString() != "null" &&
                v.toString().isNotEmpty) return v.toString();
          }
        }
      }
    }
    return "";
  }

  /// Day-first, as the portal shows every date. These are read-only displays.
  String _fmtDate(String s) {
    if (s.isEmpty || s == "null") return "";
    final shown = formatDdMmYyyy(s);
    return shown.isEmpty ? s.split("T").first : shown;
  }

  // ===========================================================================
  // BUILD
  // ===========================================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text("Final Report",
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          IconButton(
            icon: const Icon(Icons.history, color: Colors.teal),
            tooltip: "Case History",
            onPressed: () => showCaseHistory(context, _ctx()["id"]!),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    _buildHeaderCard(),
                    const SizedBox(height: 12),
                    CaseInfoBar(
                      valuationId: _ctx()["id"]!,
                      vehicleNumber: _ctx()["vNo"]!,
                      applicantContact: _ctx()["contact"]!,
                    ),
                    if (_returnedBy != null) ...[
                      const SizedBox(height: 12),
                      _buildReturnBanner(),
                    ],
                    const SizedBox(height: 16),
                    ReportPaperView(
                      report: _finalReport,
                      valuationId: _ctx()["id"]!,
                      referenceNumber: _reference,
                      valuationAmount: num.tryParse(_readStr(_finalReport, ['qualityControl.valuationAmount'])),
                      rating: _ratingDisplay,
                      lowRange: _lowRange,
                      midRange: _midRange,
                      highRange: _highRange,
                      rangeLoading: _rangeLoading,
                      checklist: _cl,
                      checklistRemarks: _clRemarks,
                      brakesScore: _brakesScore,
                      selectedPhotoKeys: _selectedPhotoKeys,
                      onPhotoTap: _showFullScreenImage,
                    ),
                    _buildActions(),
                    _buildNotesSection(),
                    const SizedBox(height: 50),
                  ],
                ),
              ),
            ),
    );
  }

  // ---------------------------------------------------------------------------
  // HEADER
  // ---------------------------------------------------------------------------
  Widget _buildHeaderCard() {
    final id = _ctx()["id"]!;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Workflow Status",
                  style: TextStyle(fontWeight: FontWeight.bold)),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                    color: Colors.teal.shade50,
                    borderRadius: BorderRadius.circular(4)),
                child: const Text("Final Report",
                    style: TextStyle(
                        color: Colors.teal, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          RichText(
            text: TextSpan(
              style: const TextStyle(color: Colors.black, fontSize: 13, height: 1.6),
              children: [
                const TextSpan(
                    text: "Vehicle: ",
                    style: TextStyle(fontWeight: FontWeight.bold)),
                TextSpan(
                    text: "${widget.summaryData['vehicleNumber'] ?? '-'}  "),
                const TextSpan(
                    text: "Applicant: ",
                    style: TextStyle(fontWeight: FontWeight.bold)),
                TextSpan(
                    text: "${widget.summaryData['applicantName'] ?? '-'}"),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text("ID: $id",
              style: const TextStyle(fontSize: 11, color: Colors.grey)),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              _buildWorkflowChip("Stake Holder", false, onTap: () {
                Navigator.push(context, MaterialPageRoute(
                    builder: (_) => InspectionFormPage(summaryData: widget.summaryData, initialTab: "Stakeholder")));
              }),
              const SizedBox(width: 8),
              _buildWorkflowChip("Backend", false, onTap: () {
                Navigator.push(context, MaterialPageRoute(
                    builder: (_) => InspectionFormPage(summaryData: widget.summaryData, initialTab: "Backend")));
              }),
              const SizedBox(width: 8),
              _buildWorkflowChip("AVO", false, onTap: () {
                Navigator.push(context, MaterialPageRoute(
                    builder: (_) => InspectionFormPage(summaryData: widget.summaryData, initialTab: "AVO")));
              }),
              const SizedBox(width: 8),
              _buildWorkflowChip("QC", false, onTap: () {
                Navigator.push(context, MaterialPageRoute(
                    builder: (_) => QcDetailPage(summaryData: widget.summaryData)));
              }),
              const SizedBox(width: 8),
              _buildWorkflowChip("Final Report", true),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkflowChip(String label, bool active, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
            color: active ? Colors.green : Colors.grey[200],
            borderRadius: BorderRadius.circular(4)),
        child: Text(label,
            style: TextStyle(
                color: active ? Colors.white : Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 12)),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // RETURN BANNER
  // ---------------------------------------------------------------------------
  Widget _buildReturnBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEBEE),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFEF9A9A)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("⚠️", style: TextStyle(fontSize: 20)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "CASE RETURNED${_returnedBy != null ? ' BY ${_returnedBy!.toUpperCase()}' : ''}",
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFB71C1C)),
                ),
                const SizedBox(height: 4),
                Text(_returnMessage ?? '',
                    style: const TextStyle(color: Color(0xFFB71C1C))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // ACTIONS
  // ---------------------------------------------------------------------------
  Widget _buildActions() {
    final busy = _isCompleting || _isReturning;
    Widget spinner() => const SizedBox(
        height: 18, width: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2));

    return Column(children: [
      // Approver decision, for final report staff and every admin, until approved.
      if (_canDecide && !_caseApproved) ...[
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: busy ? null : _onApprove,
            icon: _isCompleting ? spinner() : const Icon(Icons.check_circle, size: 18),
            label: const Text("APPROVE CASE", style: TextStyle(fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12)),
          ),
        ),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            child: ElevatedButton(
              onPressed: busy ? null : _onReturnPressed,
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12)),
              child: _isReturning ? spinner() : const Text("RETURN"),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ElevatedButton(
              onPressed: busy ? null : _onReject,
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12)),
              child: const Text("REJECT"),
            ),
          ),
        ]),
        const SizedBox(height: 8),
      ],
      // The QC review with the AI's own values beside the QC officer's.
      SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: busy
              ? null
              : () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => QcReviewPage(
                        report: _finalReport,
                        valuationId: _ctx()["id"]!,
                        vehicleNumber: _ctx()["vNo"]!,
                        applicantContact: _ctx()["contact"]!,
                        valuationType: widget.summaryData['valuationType']?.toString(),
                        referenceNumber: _reference,
                        lowRange: _lowRange,
                        midRange: _midRange,
                        highRange: _highRange,
                      ),
                    ),
                  ),
          icon: const Icon(Icons.fact_check_outlined, size: 16),
          label: const Text("Preview QC (AI vs QC officer)"),
          style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
        ),
      ),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: busy || _downloadingPdf ? null : _onPreview,
            icon: const Icon(Icons.visibility, size: 16),
            label: Text(_downloadingPdf ? "Preparing…" : "Preview PDF"),
            style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: busy || _downloadingPdf || !_caseApproved ? null : _onDownload,
            icon: Icon(_caseApproved ? Icons.download : Icons.lock, size: 16),
            label: const Text("Download PDF"),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo.shade600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12)),
          ),
        ),
      ]),
      if (!_caseApproved)
        const Padding(
          padding: EdgeInsets.only(top: 6),
          child: Text("Preview the report and approve the case to unlock the download.",
              style: TextStyle(fontSize: 12, color: Colors.grey)),
        ),
      const SizedBox(height: 8),
      SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back, size: 16),
          label: const Text("Back"),
          style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12), side: const BorderSide(color: Colors.grey)),
        ),
      ),
    ]);
  }

  // ---------------------------------------------------------------------------
  // REPORT SECTIONS (read-only previews — same as QC)
  // ---------------------------------------------------------------------------

  Widget _buildNotesSection() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.grey.shade300)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Notes (${_notes.length})",
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16)),
              ElevatedButton(
                onPressed: _addNote,
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white),
                child: const Text("+ Add Note"),
              ),
            ],
          ),
          const SizedBox(height: 15),
          TextField(
            controller: _noteController,
            decoration: const InputDecoration(
                hintText: "Type a new note here...",
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
          ),
          const SizedBox(height: 15),
          _notes.isEmpty
              ? const Center(
                  child: Text("No notes yet.",
                      style: TextStyle(
                          color: Colors.grey,
                          fontStyle: FontStyle.italic)))
              : ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _notes.length,
                  separatorBuilder: (_, __) => const Divider(),
                  itemBuilder: (_, i) {
                    final note = _notes[i];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(note['note'] ?? "",
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500)),
                      subtitle: Text(
                          "${note['createdBy']} • ${_fmtDate(note['createdDate'] ?? '')}",
                          style: const TextStyle(
                              fontSize: 11, color: Colors.grey)),
                    );
                  },
                ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // GENERIC WIDGET HELPERS
  // ---------------------------------------------------------------------------

}
