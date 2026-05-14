import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'services/api_service.dart';
import 'main.dart';
import 'avo_dashboard.dart';
import 'qc_dashboard.dart';

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
  final ApiService _api = ApiService();
  bool _isLoading = true;
  List<dynamic> _allCases = [];
  List<dynamic> _cases = [];
  String _selectedSubTab = "All";

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final all = await _api.getOpenValuations();
      all.sort((a, b) => (b['createdAt'] ?? "").compareTo(a['createdAt'] ?? ""));

      // Admin sees ALL cases across every stage
      if (mounted) {
        setState(() {
          _allCases = all;
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
    if (_selectedSubTab == "All") {
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
            const Text(
              "Vehga — Final Report",
              style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 17),
            ),
            Text("Hello, ${widget.userName}", style: const TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
        actions: [
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
  bool _isEditing = false;
  bool _isCompleting = false;
  bool _isReturning = false;
  bool _isReturningReport = false;

  // Server data
  Map<String, dynamic> _finalReport = {};
  Map<String, dynamic> _workflowTable = {};
  Map<String, dynamic> _paymentData = {};
  List<dynamic> _notes = [];

  // Return banner
  String? _returnedBy;
  String? _returnMessage;

  // Payment / completion fields
  final List<String> _paymentStatuses = ["Pending", "Completed", "Failed"];
  final List<String> _paymentMethods = ["Online", "Cash", "Card", "UPI"];
  String _selectedPaymentStatus = "Completed";
  String _selectedPaymentMethod = "Online";
  final _paymentReferenceController = TextEditingController();
  final _paymentDateController = TextEditingController();
  final _paymentAmountController = TextEditingController(text: '800');
  final _remarksController = TextEditingController();

  // Note adder
  final _noteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  @override
  void dispose() {
    _paymentReferenceController.dispose();
    _paymentDateController.dispose();
    _paymentAmountController.dispose();
    _remarksController.dispose();
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
        api.getPayment(ctx["id"]!),
      ]);

      if (!mounted) return;
      final report = results[0] as Map<String, dynamic>;
      final table = results[1] as Map<String, dynamic>;
      final notes = results[2] as List<dynamic>;
      final payment = results[3] as Map<String, dynamic>;

      setState(() {
        _finalReport = report;
        _workflowTable = table;
        _notes = notes;
        _paymentData = payment;

        _populatePaymentFields(payment);
        _checkReturnStatus(table);

        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to load case details: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _populatePaymentFields(Map<String, dynamic> data) {
    final pStatus = _readStr(data, ['paymentStatus']);
    _selectedPaymentStatus =
        _paymentStatuses.contains(pStatus) ? pStatus : 'Completed';
    final pMethod = _readStr(data, ['paymentMethod']);
    _selectedPaymentMethod =
        _paymentMethods.contains(pMethod) ? pMethod : 'Online';
    _paymentReferenceController.text = _readStr(data, ['paymentReference']);
    _paymentDateController.text =
        _fmtDate(_readStr(data, ['paymentDate']));
    final amt = _readStr(data, ['paymentAmount']);
    _paymentAmountController.text = amt.isNotEmpty ? amt : '800';
    _remarksController.text = _readStr(data, ['remarks']);
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

  Future<void> _onComplete() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      _showError("Please fill all required fields (*)");
      return;
    }
    setState(() => _isCompleting = true);
    final ctx = _ctx();
    final user = FirebaseAuth.instance.currentUser;
    final completedBy = user?.displayName ??
        user?.email?.split('@').first ??
        user?.phoneNumber ??
        'FinalReport Reviewer';
    final phone = user?.phoneNumber ?? '';
    final email = user?.email ?? '';

    final paymentDateIso = _paymentDateController.text.isEmpty
        ? DateTime.now().toUtc().toIso8601String()
        : (DateTime.tryParse(_paymentDateController.text) ?? DateTime.now())
            .toUtc()
            .toIso8601String();

    // 1. POST /valuationresponse/complete — marks the Cosmos document as completed
    //    Matches Angular ValuationResponseService.completeValuationResponse()
    final completeRes = await api.completeValuationResponse(
      valuationId: ctx["id"]!,
      vehicleNumber: ctx["vNo"]!,
      applicantContact: ctx["contact"]!,
      completedBy: completedBy,
      completedByPhone: phone,
      completedByEmail: email,
      paymentStatus: _selectedPaymentStatus,
      paymentReference: _paymentReferenceController.text,
      paymentDate: paymentDateIso,
      paymentMethod: _selectedPaymentMethod,
      paymentAmount: _paymentAmountController.text.trim(),
      remarks: _remarksController.text,
    );
    if (!mounted) return;
    if (completeRes['success'] != true) {
      setState(() => _isCompleting = false);
      _showError("Complete failed: ${completeRes['message']}");
      return;
    }

    // 2. Also save to dedicated /payments endpoint (belt-and-suspenders)
    final payRes = await api.savePayment(
      valuationId: ctx["id"]!,
      vehicleNumber: ctx["vNo"]!,
      applicantContact: ctx["contact"]!,
      paymentStatus: _selectedPaymentStatus,
      paymentReference: _paymentReferenceController.text,
      paymentDate: paymentDateIso,
      paymentMethod: _selectedPaymentMethod,
      paymentAmount:
          num.tryParse(_paymentAmountController.text.trim()) ?? 0,
    );
    if (!mounted) return;
    if (payRes['success'] != true) {
      debugPrint("WARN: Payment endpoint save failed (non-fatal): ${payRes['message']}");
    }

    // 3. completeWorkflow(5) — closes the FinalReport workflow step in Cosmos
    final wfRes =
        await api.completeWorkflow(ctx["id"]!, 5, ctx["vNo"]!, ctx["contact"]!);
    if (!mounted) return;
    if (wfRes['success'] != true) {
      debugPrint("WARN: completeWorkflow(5) failed (non-fatal): ${wfRes['message']}");
    }

    // 4. Update workflow table to Completed
    await api.updateWorkflowTable(
      ctx["id"]!, ctx["vNo"]!, ctx["contact"]!,
      {
        "workflow": "FinalReport",
        "workflowStepOrder": 5,
        "status": "Completed",
        "assignedTo": completedBy,
        "assignedToPhoneNumber": phone,
        "assignedToEmail": email,
        "assignedToWhatsapp": phone,
        "finalReportAssignedTo": completedBy,
        "finalReportAssignedToPhoneNumber": phone,
        "finalReportAssignedToEmail": email,
        "finalReportAssignedToWhatsapp": phone,
      },
    );
    if (!mounted) return;

    // 5. Assign FinalReport role (web portal does this on complete)
    await api.assignValuation(
        ctx["id"]!, ctx["vNo"]!, ctx["contact"]!, completedBy, phone, email, phone);
    if (!mounted) return;

    setState(() => _isCompleting = false);
    _showSuccess("Valuation completed successfully! ✓");
    Navigator.pop(context);
  }

  Future<void> _onReturnPressed() async {
    final result = await _showReturnReasonDialog();
    if (result == null) return;
    final reason = result['reason'] ?? '';
    if (reason.trim().isEmpty) return;
    await _attemptReturn(reason: reason.trim(), overrideAssigneeId: "");
  }

  Future<void> _attemptReturn({
    required String reason,
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
      targetReturnStep: "QualityControl",
      overrideAssigneeId: overrideAssigneeId,
    );

    if (!mounted) return;

    if (res['success'] == true) {
      setState(() => _isReturning = false);
      _showSuccess("Case returned to Quality Control");
      Navigator.pop(context);
      return;
    }

    final statusCode = res['statusCode'];
    final message = (res['message'] ?? '').toString();
    final needsOverride =
        statusCode == 400 && message.toLowerCase().contains('overrideassigneeid');

    if (needsOverride) {
      setState(() => _isReturning = false);
      final picked =
          await _showOverridePickerDialog('QualityControl', 'QC');
      if (picked == null) return;
      await _attemptReturn(reason: reason, overrideAssigneeId: picked);
      return;
    }

    setState(() => _isReturning = false);
    _showError("Return failed: ${res['message']}");
  }

  // ---------------------------------------------------------------------------
  // PDF DOWNLOAD
  // ---------------------------------------------------------------------------
  Future<void> _downloadPdf() async {
    final valuationId = widget.summaryData['valuationId']?.toString() ?? "";
    if (valuationId.isEmpty) {
      _showError("Valuation ID not available for PDF generation.");
      return;
    }
    final url =
        "https://prontomotopdf.azurewebsites.net/api/GenerateReport?valuationId=$valuationId";

    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        _showError("Could not open PDF. Check your browser settings.");
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
  // RETURN REPORT DIALOG
  // ---------------------------------------------------------------------------
  Future<void> _onReturnReportPressed() async {
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Return Final Report"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "This case will be returned to Quality Control.",
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 16),
            const Text("Reason", style: TextStyle(color: Colors.grey, fontSize: 13)),
            const SizedBox(height: 6),
            TextField(
              controller: reasonController,
              autofocus: true,
              maxLines: 3,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: "Enter reason for returning...",
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Confirm Return"),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    final reason = reasonController.text.trim();

    setState(() => _isReturningReport = true);
    final ctx = _ctx();
    final id = ctx["id"]!;
    final vNo = ctx["vNo"]!;
    final contact = ctx["contact"]!;
    final stepOrder = widget.summaryData['workflowStepOrder'] != null
        ? int.tryParse(widget.summaryData['workflowStepOrder'].toString()) ?? 5
        : widget.summaryData['stepOrder'] != null
            ? int.tryParse(widget.summaryData['stepOrder'].toString()) ?? 5
            : 5;

    final result = await api.rejectToPreviousStage(id, stepOrder, vNo, contact, reason: reason.isNotEmpty ? reason : "Rejected from Mobile App");
    if (!mounted) return;
    setState(() => _isReturningReport = false);

    if (result['success'] == true) {
      _showSuccess("Report returned to Quality Control.");
      Navigator.pop(context);
    } else {
      _showError("Return failed: ${result['message']}");
    }
  }

  // ---------------------------------------------------------------------------
  // DIALOGS
  // ---------------------------------------------------------------------------
  Future<Map<String, String>?> _showReturnReasonDialog() {
    final controller = TextEditingController();
    return showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Return to Quality Control"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "This case will be sent back to Quality Control for revision.",
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 16),
            const Text("Reason for returning:",
                style: TextStyle(color: Colors.grey, fontSize: 13)),
            const SizedBox(height: 6),
            TextField(
              controller: controller,
              autofocus: true,
              maxLines: 3,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: "e.g. Valuation amount needs correction",
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white),
            onPressed: () {
              if (controller.text.trim().isEmpty) return;
              Navigator.pop(ctx,
                  {"reason": controller.text.trim(), "target": "QualityControl"});
            },
            child: const Text("Return"),
          ),
        ],
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

  Future<void> _selectDate(TextEditingController c) async {
    final initial = DateTime.tryParse(c.text) ?? DateTime.now();
    final picked = await showDatePicker(
        context: context,
        initialDate: initial,
        firstDate: DateTime(1990),
        lastDate: DateTime(2040));
    if (picked != null) {
      setState(() => c.text = DateFormat('yyyy-MM-dd').format(picked));
    }
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

  String _fmtDate(String s) {
    if (s.isEmpty || s == "null") return "";
    try {
      return DateFormat('yyyy-MM-dd').format(DateTime.parse(s));
    } catch (_) {
      return s.split("T").first;
    }
  }

  String _displayBool(String s) {
    final l = s.toLowerCase();
    if (l == "true" || l == "yes" || l == "1") return "Yes";
    if (l == "false" || l == "no" || l == "0") return "No";
    return s.isEmpty ? "-" : s;
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
            icon: const Icon(Icons.picture_as_pdf, color: Colors.teal),
            tooltip: "Download PDF",
            onPressed: _downloadPdf,
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
                    // Download PDF button at the top
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _downloadPdf,
                        icon: const Icon(Icons.picture_as_pdf, size: 18),
                        label: const Text("Download PDF",
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.indigo.shade600,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildHeaderCard(),
                    if (_returnedBy != null) ...[
                      const SizedBox(height: 12),
                      _buildReturnBanner(),
                    ],
                    const SizedBox(height: 20),
                    _buildActions(),
                    const SizedBox(height: 20),
                    _buildStakeholderSection(),
                    _buildVehicleDetailsSection(),
                    _buildInspectionDetailsSection(),
                    _buildQcSection(),
                    _buildPaymentSection(),
                    _buildValuationRangesSection(),
                    _buildAiResponseSection(),
                    _buildPhotosSection(),
                    _buildNotesSection(),
                    const SizedBox(height: 20),
                    _buildActions(),
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

    if (!_isEditing) {
      return Column(children: [
        Row(children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => setState(() => _isEditing = true),
              icon: const Icon(Icons.edit, size: 16),
              label: const Text("Review & Complete"),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _downloadPdf,
              icon: const Icon(Icons.picture_as_pdf, size: 16),
              label: const Text("PDF"),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo.shade600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12)),
            ),
          ),
        ]),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back, size: 16),
            label: const Text("Back"),
            style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                side: const BorderSide(color: Colors.grey)),
          ),
        ),
      ]);
    }

    return Column(children: [
      // Complete + Return row
      Row(children: [
        Expanded(
          child: ElevatedButton(
            onPressed: busy ? null : _onComplete,
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12)),
            child: _isCompleting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : const Text("COMPLETE",
                    style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ElevatedButton(
            onPressed: busy ? null : _downloadPdf,
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo.shade600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12)),
            child: const Text("DOWNLOAD PDF"),
          ),
        ),
      ]),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(
          child: ElevatedButton(
            onPressed: busy ? null : _onReturnPressed,
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12)),
            child: _isReturning
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : const Text("RETURN TO QC"),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ElevatedButton(
            onPressed: busy ? null : () => setState(() => _isEditing = false),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12)),
            child: const Text("CANCEL"),
          ),
        ),
      ]),
      const SizedBox(height: 8),
      SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: (busy || _isReturningReport) ? null : _onReturnReportPressed,
          style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12)),
          child: _isReturningReport
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2))
              : const Text("RETURN REPORT",
                  style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ),
    ]);
  }

  // ---------------------------------------------------------------------------
  // REPORT SECTIONS (read-only previews — same as QC)
  // ---------------------------------------------------------------------------

  Widget _buildStakeholderSection() {
    return _buildSectionContainer("Stakeholder", [
      _buildRO("Stakeholder Name",
          _readStr(_finalReport, ['stakeholder.name', 'stakeholderName'])),
      _buildRO("Executive Name",
          _readStr(_finalReport, ['stakeholder.executiveName'])),
      _buildRO("Contact Number",
          _readStr(_finalReport, ['stakeholder.executiveContact'])),
      _buildRO("WhatsApp",
          _readStr(_finalReport, ['stakeholder.executiveWhatsapp'])),
      _buildRO("Email",
          _readStr(_finalReport, ['stakeholder.executiveEmail'])),
      _buildRO("Applicant Name",
          _readStr(_finalReport, ['stakeholder.applicant.name'])),
      _buildRO("Applicant Contact",
          _readStr(_finalReport, [
            'stakeholder.applicant.contact',
            'applicantContact'
          ])),
    ]);
  }

  Widget _buildVehicleDetailsSection() {
    return _buildSectionContainer("Vehicle Details", [
      _buildRO("Registration Number",
          _readStr(_finalReport, ['vehicleDetails.registrationNumber'])),
      _buildRO("Make",
          _readStr(_finalReport, ['vehicleDetails.make'])),
      _buildRO("Model",
          _readStr(_finalReport, ['vehicleDetails.model'])),
      _buildRO("Year of Mfg",
          _readStr(_finalReport, ['vehicleDetails.yearOfMfg'])),
      _buildRO("Body Type",
          _readStr(_finalReport, ['vehicleDetails.bodyType'])),
      _buildRO("Chassis Number",
          _readStr(_finalReport, ['vehicleDetails.chassisNumber'])),
      _buildRO("Engine Number",
          _readStr(_finalReport, ['vehicleDetails.engineNumber'])),
      _buildRO("Color",
          _readStr(_finalReport, [
            'vehicleDetails.colour',
            'vehicleDetails.color'
          ])),
      _buildRO("Fuel Type",
          _readStr(_finalReport, ['vehicleDetails.fuel'])),
      _buildRO("Owner Name",
          _readStr(_finalReport, ['vehicleDetails.ownerName'])),
      _buildRO("RTO",
          _readStr(_finalReport, ['vehicleDetails.rto'])),
      _buildRO("Remarks",
          _readStr(_finalReport, ['vehicleDetails.remarks'])),
    ]);
  }

  Widget _buildInspectionDetailsSection() {
    return _buildSectionContainer("Inspection Details", [
      _buildRO("Inspected By",
          _readStr(_finalReport, ['inspectionDetails.vehicleInspectedBy'])),
      _buildRO("Date of Inspection",
          _fmtDate(_readStr(
              _finalReport, ['inspectionDetails.dateOfInspection']))),
      _buildRO("Location",
          _readStr(_finalReport, ['inspectionDetails.inspectionLocation'])),
      _buildRO("Odometer",
          _readStr(_finalReport, ['inspectionDetails.odometer'])),
      _buildRO(
          "Engine Started",
          _displayBool(
              _readStr(_finalReport, ['inspectionDetails.engineStarted']))),
      _buildRO(
          "Road Worthy",
          _displayBool(
              _readStr(_finalReport, ['inspectionDetails.roadWorthyCondition']))),
      _buildRO(
          "Tyre Condition",
          _displayBool(
              _readStr(_finalReport, ['inspectionDetails.overallTyreCondition']))),
      _buildRO(
          "Engine Condition",
          _displayBool(
              _readStr(_finalReport, ['inspectionDetails.engineCondition']))),
      _buildRO(
          "Brake Condition",
          _displayBool(
              _readStr(_finalReport, ['inspectionDetails.brakeSystem']))),
      _buildRO("Remarks",
          _readStr(_finalReport, ['inspectionDetails.remarks'])),
    ]);
  }

  Widget _buildQcSection() {
    return _buildSectionContainer("Quality Control Review", [
      _buildRO("Overall Condition",
          _readStr(_finalReport, ['qualityControl.overallCondition', 'qualityControl.overallRating'])),
      _buildRO("Valuation Amount (₹)",
          _readStr(_finalReport, ['qualityControl.valuationAmount'])),
      _buildRO("Chassis Punch",
          _readStr(_finalReport, ['qualityControl.chassisPunch'])),
      _buildRO("Final Recommendation",
          _readStr(_finalReport, ['qualityControl.finalRecommendation'])),
      _buildRO("QC Remarks",
          _readStr(_finalReport, ['qualityControl.remarks'])),
      _buildRO("QC Reviewer",
          _readStr(_finalReport, ['qualityControl.assignedTo'])),
    ]);
  }

  Widget _buildPaymentSection() {
    // The payment section is EDITABLE — it's part of the Complete payload.
    return _buildSectionContainer("Payment Collection", [
      if (_isEditing) ...[
        _buildDropdown("Payment Status *", _paymentStatuses,
            _selectedPaymentStatus, (v) {
          if (v != null) setState(() => _selectedPaymentStatus = v);
        }),
        _buildField(
          "Payment Reference",
          _paymentReferenceController,
          isRequired: false,
        ),
        _buildDateField(
            "Payment Date *", _paymentDateController, true,
            required: true),
        _buildDropdown("Payment Method *", _paymentMethods,
            _selectedPaymentMethod, (v) {
          if (v != null) setState(() => _selectedPaymentMethod = v);
        }),
        _buildField(
          "Payment Amount (₹) *",
          _paymentAmountController,
          isRequired: true,
          keyboardType: TextInputType.number,
        ),
        _buildField(
          "Remarks",
          _remarksController,
          isRequired: false,
          maxLines: 3,
        ),
      ] else ...[
        _buildRO("Payment Status", _selectedPaymentStatus),
        _buildRO("Payment Reference", _paymentReferenceController.text),
        _buildRO("Payment Date", _paymentDateController.text),
        _buildRO("Payment Method", _selectedPaymentMethod),
        _buildRO("Payment Amount (₹)", _paymentAmountController.text),
        _buildRO("Remarks", _remarksController.text),
      ],
    ], isOpen: true);
  }

  Widget _buildValuationRangesSection() {
    return _buildSectionContainer("Valuation Ranges (AI Estimate)", [
      _buildRO("Low Range (₹ Lacs)",
          _readStr(_finalReport, ['valuationResponse.lowRange'])),
      _buildRO("Mid Range (₹ Lacs)",
          _readStr(_finalReport, ['valuationResponse.midRange'])),
      _buildRO("High Range (₹ Lacs)",
          _readStr(_finalReport, ['valuationResponse.highRange'])),
    ]);
  }

  Widget _buildAiResponseSection() {
    final raw =
        _readStr(_finalReport, ['valuationResponse.rawResponse']);
    return _buildSectionContainer("AI Analysis", [
      Padding(
        padding: const EdgeInsets.all(16),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.grey.shade300)),
          child: Text(
            raw.isEmpty ? "No AI analysis available." : raw,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
        ),
      ),
    ]);
  }

  Widget _buildPhotosSection() {
    final photos = _finalReport['photoUrls'];
    final List<MapEntry<String, dynamic>> entries = [];
    if (photos is Map) {
      photos.forEach((k, v) {
        if (v != null &&
            v.toString().isNotEmpty &&
            v.toString().toLowerCase().startsWith('http')) {
          entries.add(MapEntry(k.toString(), v));
        }
      });
    }

    return _buildSectionContainer("Photos", [
      Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (entries.isEmpty)
              const Text("No photos available.",
                  style: TextStyle(
                      color: Colors.grey, fontStyle: FontStyle.italic))
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 1.0,
                ),
                itemCount: entries.length,
                itemBuilder: (_, i) {
                  final e = entries[i];
                  return Card(
                    elevation: 1,
                    child: Column(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => _showFullScreenImage(e.value.toString(), e.key),
                            child: ClipRRect(
                              borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(4)),
                              child: Image.network(
                                e.value.toString(),
                                fit: BoxFit.cover,
                                width: double.infinity,
                                errorBuilder: (_, __, ___) => Container(
                                  color: Colors.grey.shade200,
                                  child: const Center(
                                      child: Icon(Icons.broken_image,
                                          color: Colors.grey, size: 40)),
                                ),
                                loadingBuilder: (ctx, child, prog) =>
                                    prog == null
                                        ? child
                                        : Container(
                                            color: Colors.grey.shade100,
                                            child: const Center(
                                                child: SizedBox(
                                                    height: 24,
                                                    width: 24,
                                                    child:
                                                        CircularProgressIndicator(
                                                            strokeWidth: 2))),
                                          ),
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(6),
                          child: Text(
                            e.key,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                fontSize: 10, fontWeight: FontWeight.w500),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    ]);
  }

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

  Widget _buildSectionContainer(String title, List<Widget> children,
      {bool isOpen = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300)),
      child: ExpansionTile(
        initiallyExpanded: isOpen,
        title: Text(title,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        children: children,
      ),
    );
  }

  Widget _buildRO(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
            flex: 2,
            child: Text(label,
                style:
                    TextStyle(color: Colors.grey[600], fontSize: 14))),
        Expanded(
            flex: 3,
            child: Text(value.isEmpty ? "-" : value,
                style: const TextStyle(fontWeight: FontWeight.w500))),
      ]),
    );
  }

  Widget _buildField(
    String label,
    TextEditingController controller, {
    bool isRequired = false,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    final labelWidget = RichText(
      text: TextSpan(
          text: label,
          style: TextStyle(color: Colors.grey[600], fontSize: 14),
          children: [
            if (isRequired)
              const TextSpan(
                  text: " *", style: TextStyle(color: Colors.red))
          ]),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          labelWidget,
          const SizedBox(height: 6),
          TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            maxLines: maxLines,
            inputFormatters: keyboardType == TextInputType.number
                ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))]
                : null,
            validator: isRequired
                ? (v) => (v == null || v.trim().isEmpty) ? "Required" : null
                : null,
            decoration: const InputDecoration(
                border: OutlineInputBorder(),
                isDense: true,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown(
    String label,
    List<String> items,
    String value,
    Function(String?) onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(color: Colors.grey[600], fontSize: 14)),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            value: value,
            isExpanded: true,
            decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 10, vertical: 12)),
            items: items
                .map((it) => DropdownMenuItem(
                    value: it,
                    child: Text(it,
                        style: const TextStyle(fontSize: 13))))
                .toList(),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildDateField(
    String label,
    TextEditingController controller,
    bool isEditable, {
    bool required = false,
  }) {
    return GestureDetector(
      onTap: isEditable ? () => _selectDate(controller) : null,
      child: AbsorbPointer(
        child: _buildField(label, controller, isRequired: required),
      ),
    );
  }
}
