import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'services/api_service.dart';
import 'services/brand.dart';
import 'main.dart';
import 'avo_dashboard.dart';
import 'finalreport_dashboard.dart';
import 'dashboard_common.dart';
import 'case_history_page.dart';
import 'case_search_page.dart';
import 'qc_photo_review.dart';
import 'qc_checklist.dart';
import 'inspection_score.dart';
import 'case_info_bar.dart';
import 'report_paper_view.dart';
import 'date_format.dart';

// =============================================================================
// QC DASHBOARD — list of cases currently in QualityControl step
// =============================================================================

class QcDashboard extends StatefulWidget {
  final String userName;
  const QcDashboard({super.key, required this.userName});

  @override
  State<QcDashboard> createState() => _QcDashboardState();
}

class _QcDashboardState extends State<QcDashboard> {
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
      final data = await loadDashboardData(stepMatcher: (c) {
        final wf = (c['workflow'] ?? "").toString().toLowerCase();
        return wf.contains("qc") || wf.contains("quality");
      });
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
    } else if (_selectedSubTab == "Returned") {
      filtered = _allCases.where((c) {
        final s = (c['status'] ?? "").toString().toLowerCase();
        return s.contains("return");
      }).toList();
    } else if (_selectedSubTab == "Pending") {
      filtered = _allCases.where((c) {
        final s = (c['status'] ?? "").toString().toLowerCase();
        return !s.contains("return");
      }).toList();
    } else {
      filtered = List.from(_allCases);
    }
    setState(() => _cases = filtered);
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
                color: isSelected ? Colors.white : Colors.blueGrey,
                fontWeight: FontWeight.bold,
                fontSize: 12)),
        backgroundColor: isSelected ? Colors.blueGrey : Colors.blueGrey.withOpacity(0.1),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: isSelected ? Colors.blueGrey : Colors.transparent)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final int allCount = _allCases.length;
    final int returnedCount = _allCases.where((c) => (c['status'] ?? "").toString().toLowerCase().contains("return")).length;
    final int pendingCount = allCount - returnedCount;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("${Brand.profile.name} QC",
                style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18)),
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
          if (_dashData != null) DashboardStatsHeader(data: _dashData!, color: Colors.blueGrey),
          Container(
            height: 50,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _buildSubTabChip("All", allCount),
                const SizedBox(width: 8),
                _buildSubTabChip("Pending", pendingCount),
                const SizedBox(width: 8),
                _buildSubTabChip("Returned", returnedCount),
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
    String plate = item['vehicleNumber'] ?? "Unknown";
    String location = item['location'] ?? "Unknown";
    String applicant = item['applicantName'] ?? "Unknown";
    String itemStatus = item['status'] ?? "";
    bool redFlag = item['redFlag'] == true;
    String? assignedTo = item['assignedTo']?.toString();
    if (assignedTo != null && assignedTo.isEmpty) assignedTo = null;
    bool isReturned = itemStatus.toLowerCase().contains("return");

    String? dateStr = item['createdAt'];
    int daysOld = 0;
    if (dateStr != null) {
      DateTime created = DateTime.tryParse(dateStr) ?? DateTime.now();
      daysOld = DateTime.now().difference(created).inDays;
    }
    Color ageColor = daysOld <= 1 ? Colors.green : daysOld == 2 ? Colors.orange : Colors.red;
    Color bgAge = daysOld <= 1 ? Colors.green.shade50 : daysOld == 2 ? Colors.orange.shade50 : Colors.red.shade50;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
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
                      decoration: BoxDecoration(color: Colors.blueGrey.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.blueGrey.shade200)),
                      child: const Text("QC", style: TextStyle(fontSize: 10, color: Colors.blueGrey, fontWeight: FontWeight.bold)),
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
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: bgAge, borderRadius: BorderRadius.circular(4)),
                  child: Text("TAT: ${daysOld}d",
                      style: TextStyle(color: ageColor, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 30,
                  child: OutlinedButton(
                    onPressed: () => navigateToCase(context, item, _load),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.deepPurple.shade200),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      foregroundColor: Colors.deepPurple,
                    ),
                    child: const Text("ENTER", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
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
// QC DETAIL PAGE — Final Report preview + QC form + payment + Save/Submit/Return
// =============================================================================

class QcDetailPage extends StatefulWidget {
  final Map<String, dynamic> summaryData;
  const QcDetailPage({super.key, required this.summaryData});

  @override
  State<QcDetailPage> createState() => _QcDetailPageState();
}

class _QcDetailPageState extends State<QcDetailPage> {
  final ApiService api = ApiService();

  bool _isLoading = true;
  bool _isEditing = false;
  bool _isSaving = false;
  bool _isSubmitting = false;
  bool _isReturning = false;

  // Loaded server data
  Map<String, dynamic> _qcData = {};
  Map<String, dynamic> _finalReport = {};
  Map<String, dynamic> _workflowTable = {};
  List<dynamic> _notes = [];

  String? _returnedBy;
  String? _returnMessage;

  // ── The QC form, as the portal's quality-control-update ──────────────────
  /// The derived overall score ("8.5"), locked when the AVO's sections give one.
  final _overallRatingController = TextEditingController();
  final _valuationAmountController = TextEditingController();
  final _qcRemarksController = TextEditingController();

  /// As stored on the QC record: Original / Re-Punched / Tampered.
  String? _chassisPunch;

  // Section scores carried over from the AVO inspection.
  List<SectionScore> _sectionScores = [];
  double? _overallScore;

  // Checklist: verdicts, the note behind each, and the four remarks boxes.
  Map<String, String?> _cl = {};
  Map<String, String> _clWhy = {};
  final Map<String, String> _clRemarks = {'doc': '', 'acc': '', 'val': '', 'rec': ''};
  Map? _qcChecklistSaved;

  /// Keys a person decided. Saved with the checklist, so the photo reader never
  /// overwrites a reviewer's verdict, however late it lands.
  final Set<String> _savedByReviewer = {};

  // The photo reader.
  bool _aiRunning = false;
  String? _aiError;
  final Set<String> _aiVerified = {};
  Map<String, dynamic>? _aiReadings;
  Map<String, String> _aiStatus = {};

  /// Submit waits for a successful Save, as on the portal.
  bool _saved = false;

  // The report view: the case's Unique ID and market range.
  String? _reference;
  num? _lowRange;
  num? _midRange;
  num? _highRange;
  bool _rangeLoading = false;

  // Note adder
  final _noteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // The report view's valuation follows what QC types.
    _valuationAmountController.addListener(() {
      if (mounted) setState(() {});
    });
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    final ctx = _ctx();
    setState(() => _isLoading = true);

    try {
      final qc = await api.getQualityControlDetails(ctx["id"]!, ctx["vNo"]!, ctx["contact"]!);
      final report = await api.getFinalReport(ctx["id"]!, ctx["vNo"]!, ctx["contact"]!);
      final table = await api.getWorkflowTable(ctx["id"]!, ctx["vNo"]!, ctx["contact"]!);
      final notes = await api.getNotes(ctx["id"]!);

      if (!mounted) return;
      setState(() {
        _qcData = qc;
        _finalReport = report;
        _workflowTable = table;
        _notes = notes;

        // Overall score is the mean of the AVO's section scores — the figure the
        // AVO page shows and the report's cover gauge prints.
        final scored = scoreInspection(
          _readStr(report, ['stakeholder.vehicleSegment']),
          report['inspectionDetails'] is Map ? Map<String, dynamic>.from(report['inspectionDetails']) : null,
          fallbackType: widget.summaryData['valuationType']?.toString(),
        );
        _sectionScores = scored.sections;
        _overallScore = scored.overall;

        _populateQcFields(qc);
        _populateChecklist(qc);
        _checkReturnStatus(table);

        _isLoading = false;
      });
      // Reads the photos without being asked, as the portal does. The backend
      // keeps the answer against this photo set, so only the first read costs.
      _runAiPhotoAudit();
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

  /// The Unique ID for the report header, and the market range for its valuation
  /// box. The range is read off the case; when there is none, it is asked for, as
  /// the portal's report page does.
  Future<void> _loadReportExtras() async {
    final ctx = _ctx();
    num? n(String path) => num.tryParse(_readStr(_finalReport, [path]));
    setState(() {
      _lowRange = n('valuationResponse.lowRange');
      _midRange = n('valuationResponse.midRange');
      _highRange = n('valuationResponse.highRange');
    });
    final reference = await api.getReferenceNumber(ctx["id"]!, ctx["vNo"]!, ctx["contact"]!);
    if (!mounted) return;
    setState(() => _reference = reference);

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

  Widget _buildReportView() {
    final ctx = _ctx();
    return ReportPaperView(
      report: _finalReport,
      valuationId: ctx["id"]!,
      referenceNumber: _reference,
      valuationAmount: num.tryParse(_valuationAmountController.text.trim()),
      rating: _overallRatingController.text.trim().isEmpty ? null : _overallRatingController.text.trim(),
      lowRange: _lowRange,
      midRange: _midRange,
      highRange: _highRange,
      rangeLoading: _rangeLoading,
      chassisPunch: _chassisPunch,
      onPhotoTap: _showFullScreenImage,
      // Gallery selection and annotation, the portal's QC photo review flow.
      photoAction: OutlinedButton.icon(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => QcPhotoReviewPage(
              valuationId: ctx["id"]!,
              vehicleNumber: ctx["vNo"]!,
              applicantContact: ctx["contact"]!,
            ),
          ),
        ),
        icon: const Icon(Icons.photo_library_outlined),
        label: const Text("Report Photos — Select for Report"),
      ),
    );
  }

  Map<String, String> _ctx() {
    final id = widget.summaryData['valuationId']?.toString() ??
        widget.summaryData['id']?.toString() ?? "";
    String vNo = (widget.summaryData['vehicleNumber'] ?? "").toString().trim();
    if (vNo.isEmpty) vNo = "UNKNOWN";
    String contact = (widget.summaryData['applicantContact'] ?? "").toString().trim();
    if (contact.isEmpty) contact = "0000000000";
    return {"id": id, "vNo": vNo, "contact": contact};
  }

  void _populateQcFields(Map<String, dynamic> data) {
    _overallRatingController.text = _readStr(data, ['overallRating']);
    _valuationAmountController.text = _readStr(data, ['valuationAmount']);
    _qcRemarksController.text = _readStr(data, ['remarks']);
    final punch = _readStr(data, ['chassisPunch']);
    _chassisPunch = punch.isEmpty ? null : punch;
    // Overall Rating is the derived score, written over whatever was saved and
    // locked so the checklist and the printed report can never disagree.
    if (_overallScore != null) _overallRatingController.text = _overallScore!.toStringAsFixed(1);
  }

  /// Photos actually on file, by key.
  List<String> get _photoKeys {
    final photos = _finalReport['photoUrls'] ?? _finalReport['PhotoUrls'];
    if (photos is! Map) return [];
    return [
      for (final e in photos.entries)
        if (e.value != null && e.value.toString().trim().isNotEmpty) e.key.toString(),
    ];
  }

  List<String> _stringList(Object? v) => v is List ? [for (final x in v) x.toString()] : <String>[];

  Map<String, String> _stringMap(Object? v) => v is Map
      ? {for (final e in v.entries) if (e.value != null) e.key.toString(): e.value.toString()}
      : <String, String>{};

  /// Every card's verdict and note, from the shared engine (qc_checklist.dart).
  void _prefillChecklist() {
    final readings = _aiReadings;
    final result = buildQcChecklist(
      report: _finalReport,
      overallRating: _overallRatingController.text,
      chassisPunch: _chassisPunch,
      photoKeys: _photoKeys,
      vehicleSegment: _readStr(_finalReport, ['stakeholder.vehicleSegment']),
      valuationType: widget.summaryData['valuationType']?.toString(),
      aiFindings: readings == null
          ? null
          : QcAiFindings(
              damage: _stringList(readings['damageFound']),
              missingParts: _stringList(readings['missingParts']),
              photosRead: true,
            ),
    );
    _cl = result.cl;
    _clWhy = result.why;
  }

  /// The automatic verdicts, then the reviewer's saved ones over them, as the
  /// portal's loadQualityControl() does.
  void _populateChecklist(Map<String, dynamic> qc) {
    final saved = qc['qcchecklist'];
    _qcChecklistSaved = saved is Map ? saved : null;
    final reviewerKeys = _stringList(qc['qcchecklistreviewerkeys']);
    _prefillChecklist();
    applySavedChecklist(QcChecklistResult(_cl, _clWhy), _qcChecklistSaved, reviewerKeys);
    final savedRemarks = qc['qcchecklistremarks'];
    if (savedRemarks is Map) {
      savedRemarks.forEach((k, v) {
        if (v != null && v.toString().isNotEmpty) _clRemarks[k.toString()] = v.toString();
      });
    }
    _savedByReviewer.addAll(reviewerKeys);
  }

  /// Reads the case photos and folds the findings into the checklist. A key the
  /// reader could not verify keeps its rule-based verdict, and a reviewer's own
  /// choice is never overwritten: a human verdict outranks a machine one.
  Future<void> _runAiPhotoAudit({bool force = false}) async {
    if (_aiRunning) return;
    setState(() {
      _aiRunning = true;
      _aiError = null;
    });
    final ctx = _ctx();
    final audit = await api.runAiPhotoAudit(ctx["id"]!, ctx["vNo"]!, ctx["contact"]!, force: force);
    if (!mounted) return;
    setState(() {
      _aiRunning = false;
      final readings = audit['readings'];
      _aiReadings = readings is Map ? Map<String, dynamic>.from(readings) : null;
      _aiStatus = _stringMap(audit['status']);

      // Damage and missing parts are derived here from the findings; anything
      // the reviewer decided is put back on top.
      _prefillChecklist();
      applySavedChecklist(QcChecklistResult(_cl, _clWhy), _qcChecklistSaved, _savedByReviewer);

      if (audit['error'] != null) {
        _aiError = audit['error'].toString();
        return;
      }
      _stringMap(audit['why']).forEach((k, v) {
        if (v.isNotEmpty && !_savedByReviewer.contains(k)) _clWhy[k] = v;
      });
      final auditCl = _stringMap(audit['cl']);
      // A card the reader looked at and could not settle must not keep a 'fail'
      // that reads as a proven mismatch.
      _aiStatus.forEach((k, st) {
        if (st == 'unresolved' && !_savedByReviewer.contains(k) && (auditCl[k] ?? '').isEmpty) _cl[k] = null;
      });
      auditCl.forEach((k, v) {
        if (v.isEmpty || _savedByReviewer.contains(k)) return;
        _cl[k] = v;
        _aiVerified.add(k);
        // The chassis punch has a field of its own, which the report reads first.
        if (k == 'docChassis' && (_chassisPunch ?? '').isEmpty) _chassisPunch = chassisPunchLabels[v];
      });
    });
  }

  /// True while the reader is still working on this card.
  bool _aiPending(String key) => _aiRunning && aiAnsweredKeys.contains(key) && !_savedByReviewer.contains(key);

  String get _reviewerName => currentUserName.isNotEmpty ? currentUserName : 'the reviewer';

  void _setCl(String key, String value) {
    setState(() {
      // A manual choice replaces the machine's.
      _aiVerified.remove(key);
      _cl[key] = _cl[key] == value ? null : value;
      _clWhy[key] = _cl[key] == null
          ? 'Cleared by $_reviewerName.'
          : 'Set manually by $_reviewerName — overrides the automatic check.';
      _savedByReviewer.add(key);
      // The chassis punch pills also write the chassis punch itself.
      if (key == 'docChassis') _chassisPunch = chassisPunchLabels[value];
    });
  }

  // Mirrors the web portal's checkReturnStatus parser for QC step.
  // QC view filters out stale "RETURNED BY QC" or "RETURNED BY QUALITYCONTROL"
  // since QC shouldn't see its own return banner.
  void _checkReturnStatus(Map<String, dynamic> table) {
    if (table.isEmpty) {
      _returnedBy = null;
      _returnMessage = null;
      return;
    }
    final isRedFlag = table['redFlag']?.toString().toLowerCase() == 'true' ||
        table['RedFlag']?.toString().toLowerCase() == 'true';
    final remark = (table['remarks'] ?? table['Remarks'] ?? '').toString();
    final currentStep = (table['workflow'] ?? table['Workflow'] ?? '').toString();
    final isQcStep = currentStep == 'QualityControl' || currentStep == 'QC';

    if (!isRedFlag || remark.isEmpty || !isQcStep) {
      _returnedBy = null;
      _returnMessage = null;
      return;
    }

    final remarkUpper = remark.toUpperCase();
    const prefix = "RETURNED BY ";

    if (remarkUpper.startsWith(prefix)) {
      final splitIndex = remark.indexOf(':');
      if (splitIndex != -1) {
        final returnerName = remark.substring(12, splitIndex).trim();
        const invalidReturners = ['QUALITYCONTROL', 'QC'];
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

  // Read a value from a map by trying multiple casings of each candidate key,
  // and walking dot-paths like "stakeholder.executiveName".
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
        if (found && current != null && current.toString().isNotEmpty && current.toString() != "null") {
          return current.toString();
        }
      } else {
        for (final k in data.keys) {
          if (k.toString().toLowerCase() == key.toLowerCase()) {
            final v = data[k];
            if (v != null && v.toString() != "null" && v.toString().isNotEmpty) return v.toString();
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
  // SAVE / SUBMIT / RETURN
  // ===========================================================================

  Map<String, dynamic> _buildQcPayload(String assigneeName, String assigneePhone, String assigneeEmail) {
    return {
      "overallRating": _overallRatingController.text.trim(),
      "valuationAmount": num.tryParse(_valuationAmountController.text.trim()) ?? 0,
      "chassisPunch": _chassisPunch ?? '',
      // An emptied box goes as "", not null: the API skips null as "not sent", so
      // deleted remarks used to come back. The report prints its standard remark for "".
      "remarks": _qcRemarksController.text.trim(),
      "assignedTo": assigneeName,
      "assignedToPhoneNumber": assigneePhone,
      "assignedToEmail": assigneeEmail,
      "assignedToWhatsapp": assigneePhone,
      "qcChecklist": _cl,
      "qcChecklistRemarks": _clRemarks,
      "qcChecklistReviewerKeys": _savedByReviewer.toList(),
    };
  }

  /// The portal's required fields, by name.
  bool _checkQcForm() {
    final missing = <String>[];
    if (_overallRatingController.text.trim().isEmpty) missing.add("Overall rating");
    final amount = num.tryParse(_valuationAmountController.text.trim());
    if (_valuationAmountController.text.trim().isEmpty) missing.add("Valuation amount");
    if ((_chassisPunch ?? '').isEmpty) missing.add("Chassis punch status");
    final problems = <String>[
      if (missing.isNotEmpty) "Required: ${missing.join(', ')}",
      if (_valuationAmountController.text.trim().isNotEmpty && (amount == null || amount < 0))
        "Valuation amount must be a number, 0 or more",
    ];
    if (problems.isEmpty) return true;
    _showError(problems.join("\n"));
    return false;
  }

  ({String name, String phone, String email}) _assignee() {
    final user = FirebaseAuth.instance.currentUser;
    final name = currentUserName.isNotEmpty
        ? currentUserName
        : (user?.displayName ?? user?.email?.split('@').first ?? user?.phoneNumber ?? 'User');
    return (name: name, phone: currentUserPhone.isNotEmpty ? currentUserPhone : (user?.phoneNumber ?? ''), email: user?.email ?? '');
  }

  Future<void> _onSave() async {
    if (!_checkQcForm()) return;
    setState(() => _isSaving = true);
    final ctx = _ctx();
    final a = _assignee();

    final qcRes = await api.updateQualityControlDetails(ctx["id"]!, ctx["vNo"]!, ctx["contact"]!, _buildQcPayload(a.name, a.phone, a.email));
    if (!mounted) return;
    if (qcRes['success'] != true) {
      setState(() => _isSaving = false);
      _showError("Save failed: ${qcRes['message']}");
      return;
    }

    await api.startWorkflow(ctx["id"]!, 4, ctx["vNo"]!, ctx["contact"]!);
    await api.updateWorkflowTable(ctx["id"]!, ctx["vNo"]!, ctx["contact"]!, {
      "workflow": "QC",
      "workflowStepOrder": 4,
      "assignedTo": a.name,
      "assignedToPhoneNumber": a.phone,
      "assignedToEmail": a.email,
      "assignedToWhatsapp": a.phone,
      "qualityControlAssignedTo": a.name,
      "qualityControlAssignedToPhoneNumber": a.phone,
      "qualityControlAssignedToEmail": a.email,
      "qualityControlAssignedToWhatsapp": a.phone,
    });
    await api.assignQualityControl(ctx["id"]!, ctx["vNo"]!, ctx["contact"]!, a.name, a.phone, a.email, a.phone);
    await api.assignValuation(ctx["id"]!, ctx["vNo"]!, ctx["contact"]!, a.name, a.phone, a.email, a.phone);
    await api.addWorkflowHistory(
      valuationId: ctx["id"]!,
      action: "Quality Control Details Saved",
      remarks: "Quality control saved",
      performedByUserId: currentUserId,
      performedByUserName: currentUserName,
      statusTo: "QC",
    );
    if (!mounted) return;
    setState(() {
      _isSaving = false;
      _saved = true;
    });
    _showSuccess("Quality control saved successfully");
  }

  Future<void> _onSubmit() async {
    if (!_saved) {
      _showError("Save the quality control first, then submit.");
      return;
    }
    if (!_checkQcForm()) return;
    setState(() => _isSubmitting = true);
    final ctx = _ctx();
    final a = _assignee();

    final qcRes = await api.updateQualityControlDetails(ctx["id"]!, ctx["vNo"]!, ctx["contact"]!, _buildQcPayload(a.name, a.phone, a.email));
    if (!mounted) return;
    if (qcRes['success'] != true) {
      setState(() => _isSubmitting = false);
      _showError("Submit failed: ${qcRes['message']}");
      return;
    }

    final completeRes = await api.completeWorkflow(ctx["id"]!, 4, ctx["vNo"]!, ctx["contact"]!);
    if (!mounted) return;
    if (completeRes['success'] != true) {
      setState(() => _isSubmitting = false);
      _showError("Submit failed: could not complete QC step. ${completeRes['message']}");
      return;
    }
    final startFr = await api.startWorkflow(ctx["id"]!, 5, ctx["vNo"]!, ctx["contact"]!);
    if (!mounted) return;
    if (startFr['success'] != true) {
      setState(() => _isSubmitting = false);
      _showError("Submit failed: could not start Final Report step. ${startFr['message']}");
      return;
    }

    await api.updateWorkflowTable(ctx["id"]!, ctx["vNo"]!, ctx["contact"]!, {
      "workflow": "FinalReport",
      "workflowStepOrder": 5,
      "qualityControlAssignedTo": a.name,
      "qualityControlAssignedToPhoneNumber": a.phone,
      "qualityControlAssignedToEmail": a.email,
      "qualityControlAssignedToWhatsapp": a.phone,
    });
    await api.assignQualityControl(ctx["id"]!, ctx["vNo"]!, ctx["contact"]!, a.name, a.phone, a.email, a.phone);
    await api.addWorkflowHistory(
      valuationId: ctx["id"]!,
      action: "Quality Control Submitted - Moving to Final Report",
      remarks: "Quality control completed. Overall Rating: ${_overallRatingController.text}, "
          "Valuation Amount: ₹${_valuationAmountController.text}. Status: QC Complete → Final Report In Progress",
      performedByUserId: currentUserId,
      performedByUserName: currentUserName,
      statusFrom: "QC",
      statusTo: "FinalReport",
    );
    if (!mounted) return;

    setState(() => _isSubmitting = false);
    _showSuccess("Submitted to Final Report successfully");
    Navigator.pop(context);
  }

  Future<void> _onReturnPressed() async {
    final result = await _showReturnReasonDialog();
    if (result == null) return;
    final reason = result['reason'] ?? '';
    final target = result['target'] ?? 'AVO';
    if (reason.trim().isEmpty) return;

    await _attemptReturn(reason: reason.trim(), target: target, overrideAssigneeId: "");
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
    final userName = user?.displayName ?? user?.email?.split('@').first ?? 'QC Reviewer';

    final res = await api.returnWorkflow(
      valuationId: ctx["id"]!,
      vehicleNumber: ctx["vNo"]!,
      applicantContact: ctx["contact"]!,
      currentStep: "QualityControl",
      returnReason: reason,
      currentUserId: userId,
      currentUserName: userName,
      targetReturnStep: target,
      overrideAssigneeId: overrideAssigneeId,
    );

    if (!mounted) return;

    if (res['success'] == true) {
      await api.addWorkflowHistory(
        valuationId: ctx["id"]!,
        action: "QC Returned to $target",
        remarks: reason,
        performedByUserId: currentUserId,
        performedByUserName: currentUserName,
        statusFrom: "QC",
        statusTo: target,
      );
      if (!mounted) return;
      setState(() => _isReturning = false);
      _showSuccess("Case returned to $target");
      Navigator.pop(context);
      return;
    }

    final statusCode = res['statusCode'];
    final message = (res['message'] ?? '').toString();
    final needsOverride = statusCode == 400 && message.toLowerCase().contains('overrideassigneeid');

    if (needsOverride) {
      setState(() => _isReturning = false);
      // Backend role name uses 'BackEnd' casing, AVO is 'AVO'
      final role = target == 'Backend' ? 'BackEnd' : target;
      final picked = await _showOverridePickerDialog(role, target);
      if (picked == null) return;
      await _attemptReturn(reason: reason, target: target, overrideAssigneeId: picked);
      return;
    }

    setState(() => _isReturning = false);
    _showError("Return failed: ${res['message']}");
  }

  Future<Map<String, String>?> _showReturnReasonDialog() async {
    final controller = TextEditingController();
    String selectedTarget = 'AVO';
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocalState) => AlertDialog(
          title: const Text("Return Quality Control"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Send back to:", style: TextStyle(color: Colors.grey, fontSize: 13)),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                value: selectedTarget,
                isExpanded: true,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                items: const [
                  DropdownMenuItem(value: 'AVO', child: Text('AVO (Inspection)')),
                  DropdownMenuItem(value: 'Backend', child: Text('Backend')),
                ],
                onChanged: (v) {
                  if (v != null) setLocalState(() => selectedTarget = v);
                },
              ),
              const SizedBox(height: 16),
              const Text("Reason for returning:", style: TextStyle(color: Colors.grey, fontSize: 13)),
              const SizedBox(height: 6),
              TextField(
                controller: controller,
                autofocus: true,
                maxLines: 3,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: "e.g. Valuation amount looks incorrect — please review",
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
                Navigator.pop(ctx, {"reason": controller.text.trim(), "target": selectedTarget});
              },
              child: const Text("Return"),
            ),
          ],
        ),
      ),
    );
    return result;
  }

  Future<String?> _showOverridePickerDialog(String role, String targetLabel) async {
    setState(() => _isReturning = true);
    final users = await api.getUsersByRole(role);
    if (!mounted) return null;
    setState(() => _isReturning = false);

    if (users.isEmpty) {
      _showError("No $targetLabel users available for override. Contact admin.");
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Pick a $targetLabel user to assign this case to:",
                  style: const TextStyle(color: Colors.grey, fontSize: 13)),
              const SizedBox(height: 12),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: users.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final u = users[i];
                    final name = (u['name'] ?? u['displayName'] ?? 'User').toString();
                    final phone = (u['phoneNumber'] ?? u['phone'] ?? '').toString();
                    final id = (u['userId'] ?? u['id'] ?? '').toString();
                    return ListTile(
                      dense: true,
                      title: Text(name),
                      subtitle: phone.isEmpty ? null : Text(phone, style: const TextStyle(fontSize: 11)),
                      onTap: () => Navigator.pop(ctx, id),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel"))],
      ),
    );
  }

  Future<void> _addNote() async {
    if (_noteController.text.isEmpty) return;
    await api.addNote(_ctx()["id"]!, _noteController.text);
    _noteController.clear();
    final notes = await api.getNotes(_ctx()["id"]!);
    if (mounted) setState(() => _notes = notes);
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  void _showSuccess(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.green));
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

  // ===========================================================================
  // BUILD
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text("Quality Control", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
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
                  const SizedBox(height: 20),
                  _buildActions(),
                  const SizedBox(height: 20),
                  // The case as the report lays it out, then QC's own work.
                  _buildReportView(),
                  _buildQualityControlSection(),
                  _buildQcChecklistSection(),
                  _buildAiResponseSection(),
                  _buildNotesSection(),
                  const SizedBox(height: 20),
                  _buildActions(),
                  const SizedBox(height: 50),
                ],
              ),
            ),
    );
  }

  Widget _buildHeaderCard() {
    final id = _ctx()["id"]!;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.grey.shade300)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: const [
            Text("Workflow Status", style: TextStyle(fontWeight: FontWeight.bold)),
            Text("QC Review", style: TextStyle(color: Colors.grey)),
          ]),
          const SizedBox(height: 10),
          RichText(
            text: TextSpan(
              style: const TextStyle(color: Colors.black, fontSize: 13, height: 1.6),
              children: [
                const TextSpan(text: "Vehicle Number: ", style: TextStyle(fontWeight: FontWeight.bold)),
                TextSpan(text: "${widget.summaryData['vehicleNumber']} | "),
                const TextSpan(text: "Status: ", style: TextStyle(fontWeight: FontWeight.bold)),
                TextSpan(text: "${widget.summaryData['status'] ?? widget.summaryData['workflow'] ?? 'QC'}"),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text("ID: $id", style: const TextStyle(fontSize: 11, color: Colors.grey)),
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
              _buildWorkflowChip("QC", true),
              const SizedBox(width: 8),
              _buildWorkflowChip("Final Report", false,
                locked: currentUserRoleLevel < 5,
                onTap: currentUserRoleLevel >= 5 ? () {
                  Navigator.push(context, MaterialPageRoute(
                      builder: (_) => FinalReportDetailPage(summaryData: widget.summaryData)));
                } : null,
              ),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkflowChip(String label, bool active,
      {VoidCallback? onTap, bool locked = false}) {
    if (locked) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.grey.shade300)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.lock_outline, size: 12, color: Colors.grey[400]),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 12,
                  fontWeight: FontWeight.w500)),
        ]),
      );
    }
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
                Text("CASE RETURNED${_returnedBy != null ? ' BY ${_returnedBy!.toUpperCase()}' : ''}",
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFB71C1C))),
                const SizedBox(height: 4),
                Text(_returnMessage ?? '', style: const TextStyle(color: Color(0xFFB71C1C))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions() {
    final isProcessing = _isSaving || _isSubmitting || _isReturning;

    if (!_isEditing) {
      return Row(children: [
        Expanded(
          child: ElevatedButton(
            onPressed: () => setState(() => _isEditing = true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3F51B5), foregroundColor: Colors.white),
            child: const Text("Edit"),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE53935), foregroundColor: Colors.white),
            child: const Text("Back"),
          ),
        ),
      ]);
    }

    return Column(children: [
      Row(children: [
        Expanded(
          child: ElevatedButton(
            onPressed: isProcessing ? null : _onSave,
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12)),
            child: _isSaving
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text("SAVE"),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ElevatedButton(
            onPressed: isProcessing || !_saved ? null : _onSubmit,
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3F51B5),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12)),
            child: _isSubmitting
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text("SUBMIT"),
          ),
        ),
      ]),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(
          child: ElevatedButton(
            onPressed: isProcessing ? null : _onReturnPressed,
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12)),
            child: _isReturning
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text("RETURN"),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ElevatedButton(
            onPressed: isProcessing ? null : () => setState(() => _isEditing = false),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12)),
            child: const Text("CANCEL"),
          ),
        ),
      ]),
    ]);
  }

  // ---------------------------------------------------------------------------
  // Final Report sections (read-only previews)
  // ---------------------------------------------------------------------------

  Color _bandColor(double? score) {
    switch (scoreBand(score)) {
      case ScoreBand.good:
        return Colors.green.shade700;
      case ScoreBand.average:
        return Colors.orange.shade800;
      case ScoreBand.poor:
        return Colors.red.shade700;
      case null:
        return Colors.grey;
    }
  }

  Widget _buildQualityControlSection() {
    final canEdit = _isEditing;
    final derived = _overallScore != null;
    return _buildSectionContainer("Quality Control", [
      // Derived from the AVO's section scores; not editable here.
      if (_sectionScores.isNotEmpty)
        Container(
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text("Overall Vehicle Score", style: TextStyle(fontWeight: FontWeight.bold)),
                  Text("Average of the ${_sectionScores.length} inspection section scores recorded by the AVO",
                      style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600)),
                ]),
              ),
              Text(_overallScore?.toStringAsFixed(1) ?? '—',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: _bandColor(_overallScore))),
              Text(" / 10", style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            ]),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 6, children: [
              for (final sc in _sectionScores)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Text.rich(TextSpan(children: [
                    TextSpan(text: "${sc.section}  ", style: const TextStyle(fontSize: 11)),
                    TextSpan(
                        text: sc.score?.toStringAsFixed(1) ?? '—',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _bandColor(sc.score))),
                  ])),
                ),
            ]),
          ]),
        ),
      _buildEditField(
        "Overall Rating",
        _overallRatingController,
        // Locked when derived, so the score and the printed report cannot disagree.
        // Typeable only when nothing is scored yet, so the case is not stuck.
        isEditable: canEdit && !derived,
        isRequired: true,
      ),
      if (derived)
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text("Derived from the section scores above", style: TextStyle(fontSize: 11.5, color: Colors.grey)),
        ),
      _buildEditField(
        "Valuation Amount (₹)",
        _valuationAmountController,
        isEditable: canEdit,
        isRequired: true,
        keyboardType: TextInputType.number,
      ),
      _buildReadOnly("Chassis Punch *", _chassisPunch ?? 'Not recorded — choose it under QC Recommendation'),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text("General Remarks", style: TextStyle(color: Colors.grey[600], fontSize: 14)),
          const SizedBox(height: 6),
          TextField(
            controller: _qcRemarksController,
            readOnly: !canEdit,
            maxLines: 3,
            decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.all(12)),
          ),
          const SizedBox(height: 4),
          const Text('Left empty, the report prints "Vehicle found in good road worthy condition."',
              style: TextStyle(fontSize: 11.5, color: Colors.grey)),
        ]),
      ),
    ], isOpen: true);
  }

  /// The odometer comparison on the accOdo card: what the AVO typed and what the
  /// photo reader took off the dial.
  Widget? _odometerEvidence(String key) {
    if (key != 'accOdo') return null;
    final avoRaw = num.tryParse(_readStr(_finalReport, ['inspectionDetails.odometer']));
    final avo = avoRaw != null && avoRaw > 0 ? avoRaw : null;
    final photoRaw = _aiReadings == null ? null : num.tryParse('${_aiReadings!['odometerKm'] ?? ''}');
    final photo = photoRaw != null && photoRaw > 0 ? photoRaw : null;
    if (avo == null && photo == null) return null;
    final fmt = NumberFormat.decimalPattern('en_IN');
    final delta = avo != null && photo != null ? photo - avo : null;
    Widget row(String l, String v, {bool bad = false}) => Row(children: [
          SizedBox(width: 100, child: Text(l, style: TextStyle(fontSize: 12, color: Colors.grey.shade600))),
          Text(v, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: bad ? Colors.red.shade700 : null)),
        ]);
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        row("AVO recorded", avo != null ? "${fmt.format(avo)} km" : "not recorded"),
        row("Photo reads",
            photo != null ? "${fmt.format(photo)} km" : (_aiStatus['accOdo'] == 'unresolved' ? "could not be read" : "not read yet")),
        if (delta != null)
          row("Difference", delta == 0 ? "none" : "${delta > 0 ? '+' : ''}${fmt.format(delta)} km", bad: delta != 0),
      ]),
    );
  }

  Widget _buildAiResponseSection() {
    final raw = _readStr(_finalReport, ['valuationResponse.rawResponse']);
    return _buildSectionContainer("AI Analysis", [
      Padding(
        padding: const EdgeInsets.all(16),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Text(raw.isEmpty ? "No AI analysis available." : raw,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
        ),
      ),
    ]);
  }

  Widget _buildQcChecklistSection() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: QcChecklistView(
        key: ValueKey('qc-checklist-$_isEditing'),
        cl: _cl,
        why: _clWhy,
        remarks: _clRemarks,
        enabled: _isEditing,
        aiVerified: _aiVerified,
        aiStatus: _aiStatus,
        aiPending: _aiPending,
        onSet: _setCl,
        cardExtra: _odometerEvidence,
        before: (id) {
          if (id != 'acc') return null;
          if (_aiError != null) {
            return _banner("⚠ $_aiError — every check below is still yours to decide by eye.", Colors.orange.shade800);
          }
          if (_aiRunning) {
            return _banner("Reading the inspection photos… the checks below will update when it finishes.", Colors.indigo);
          }
          return null;
        },
      ),
    );
  }

  Widget _banner(String text, Color color) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Text(text, style: TextStyle(fontSize: 12.5, color: color)),
      );

  Widget _buildNotesSection() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.grey.shade300)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text("QC Notes (${_notes.length})", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ElevatedButton(
              onPressed: _addNote,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
              child: const Text("+ Add Note"),
            ),
          ]),
          const SizedBox(height: 15),
          TextField(
            controller: _noteController,
            decoration: const InputDecoration(
                hintText: "Type a new note here...",
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
          ),
          const SizedBox(height: 15),
          _notes.isEmpty
              ? const Center(child: Text("No notes yet.", style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)))
              : ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _notes.length,
                  separatorBuilder: (_, __) => const Divider(),
                  itemBuilder: (_, i) {
                    final note = _notes[i];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(note['note'] ?? "", style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                      subtitle: Text("${note['createdBy']} • ${_fmtDate(note['createdDate'] ?? '')}",
                          style: const TextStyle(fontSize: 11, color: Colors.grey)),
                    );
                  },
                ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Generic helpers (mirrors AVO page patterns)
  // ---------------------------------------------------------------------------

  Widget _buildSectionContainer(String title, List<Widget> children, {bool isOpen = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade300)),
      child: ExpansionTile(
        initiallyExpanded: isOpen,
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        children: children,
      ),
    );
  }

  Widget _buildReadOnly(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(flex: 2, child: Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 14))),
        Expanded(
            flex: 3,
            child: Text(value.isEmpty ? "-" : value, style: const TextStyle(fontWeight: FontWeight.w500))),
      ]),
    );
  }

  Widget _buildEditField(
    String label,
    TextEditingController controller, {
    bool isEditable = false,
    bool isRequired = false,
    TextInputType? keyboardType,
  }) {
    Widget labelWidget = RichText(
      text: TextSpan(text: label, style: TextStyle(color: Colors.grey[600], fontSize: 14), children: [
        if (isRequired) const TextSpan(text: " *", style: TextStyle(color: Colors.red))
      ]),
    );

    if (!isEditable) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(flex: 2, child: labelWidget),
          Expanded(
              flex: 3,
              child: Text(controller.text.isEmpty ? "-" : controller.text,
                  style: const TextStyle(fontWeight: FontWeight.w500))),
        ]),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        labelWidget,
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          inputFormatters: keyboardType == TextInputType.number
              ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))]
              : null,
          validator: isRequired
              ? (v) => (v == null || v.trim().isEmpty) ? "Required" : null
              : null,
          decoration: const InputDecoration(
              border: OutlineInputBorder(),
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12)),
        ),
      ]),
    );
  }
}