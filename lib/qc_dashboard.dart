import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'services/api_service.dart';
import 'main.dart';
import 'avo_dashboard.dart';
import 'finalreport_dashboard.dart';

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
      // Filter to QC step only
      final filtered = all.where((c) {
        final wf = (c['workflow'] ?? "").toString().toLowerCase();
        return wf.contains("qc") || wf.contains("quality");
      }).toList();
      if (mounted) {
        setState(() {
          _allCases = filtered;
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
    if (_selectedSubTab == "Returned") {
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
            const Text("ProntoMoto QC",
                style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18)),
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
                _buildSubTabChip("Pending", pendingCount),
                const SizedBox(width: 8),
                _buildSubTabChip("Returned", returnedCount),
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
  final _qcFormKey = GlobalKey<FormState>();

  bool _isLoading = true;
  bool _isEditing = false;
  bool _isSaving = false;
  bool _isSubmitting = false;
  bool _isReturning = false;

  // Loaded server data
  Map<String, dynamic> _qcData = {};
  Map<String, dynamic> _finalReport = {};
  Map<String, dynamic> _workflowTable = {};
  Map<String, dynamic> _paymentData = {};
  List<dynamic> _notes = [];

  String? _returnedBy;
  String? _returnMessage;

  // QC form — button-picker state (matches web portal selectors)
  static const _chassisPunchOptions = ['Original', 'Re-Punched', 'Tampered'];
  static const _overallConditionOptions = ['Good', 'Average', 'Poor'];
  static const _finalRecommendationOptions = [
    'Recommended',
    'Recommended with Conditions',
    'Not Recommended',
  ];

  String? _selectedChassisPunch;
  String? _selectedOverallCondition;
  String? _selectedFinalRecommendation;

  // QC form controllers (text fields that remain)
  final _valuationAmountController = TextEditingController();
  final _qcRemarksController = TextEditingController();

  // Payment controllers
  final List<String> _paymentStatuses = ["Pending", "Completed", "Failed"];
  final List<String> _paymentMethods = ["Online", "Cash", "Card", "UPI"];
  String? _selectedPaymentStatus;
  String? _selectedPaymentMethod;
  final _paymentReferenceController = TextEditingController();
  final _paymentDateController = TextEditingController();
  final _paymentAmountController = TextEditingController(text: '800');

  // Note adder
  final _noteController = TextEditingController();

  @override
  void initState() {
    super.initState();
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
      final payment = await api.getPayment(ctx["id"]!);

      if (!mounted) return;
      setState(() {
        _qcData = qc;
        _finalReport = report;
        _workflowTable = table;
        _notes = notes;
        _paymentData = payment;

        _populateQcFields(qc);
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
    // overallCondition takes precedence; fall back to overallRating (web portal parity)
    final cond = _readStr(data, ['overallCondition', 'overallRating']);
    _selectedOverallCondition =
        _overallConditionOptions.contains(cond) ? cond : null;

    final chassis = _readStr(data, ['chassisPunch']);
    _selectedChassisPunch =
        _chassisPunchOptions.contains(chassis) ? chassis : null;

    final rec = _readStr(data, ['finalRecommendation']);
    _selectedFinalRecommendation =
        _finalRecommendationOptions.contains(rec) ? rec : null;

    _valuationAmountController.text = _readStr(data, ['valuationAmount']);
    _qcRemarksController.text = _readStr(data, ['remarks']);
  }

  void _populatePaymentFields(Map<String, dynamic> data) {
    final pStatus = _readStr(data, ['paymentStatus']);
    _selectedPaymentStatus = _paymentStatuses.contains(pStatus) ? pStatus : 'Pending';
    final pMethod = _readStr(data, ['paymentMethod']);
    _selectedPaymentMethod = _paymentMethods.contains(pMethod) ? pMethod : 'Online';
    _paymentReferenceController.text = _readStr(data, ['paymentReference']);
    _paymentDateController.text = _fmtDate(_readStr(data, ['paymentDate']));
    final amt = _readStr(data, ['paymentAmount']);
    _paymentAmountController.text = amt.isNotEmpty ? amt : '800';
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

  String _fmtDate(String s) {
    if (s.isEmpty || s == "null") return "";
    try {
      return DateFormat('yyyy-MM-dd').format(DateTime.parse(s));
    } catch (_) {
      return s.split("T").first;
    }
  }

  String _displayBool(String s) {
    final lower = s.toLowerCase();
    if (lower == "true" || lower == "yes" || lower == "1") return "Yes";
    if (lower == "false" || lower == "no" || lower == "0") return "No";
    return s.isEmpty ? "-" : s;
  }

  // ===========================================================================
  // SAVE / SUBMIT / RETURN
  // ===========================================================================

  Map<String, dynamic> _buildQcPayload(String assigneeName, String assigneePhone, String assigneeEmail) {
    final num? amount = num.tryParse(_valuationAmountController.text.trim());

    final paymentDateText = _paymentDateController.text;
    final paymentDateIso = paymentDateText.isEmpty
        ? DateTime.now().toUtc().toIso8601String()
        : (DateTime.tryParse(paymentDateText) ?? DateTime.now()).toUtc().toIso8601String();
    final num paymentAmount = num.tryParse(_paymentAmountController.text) ?? 0;

    return {
      // Web portal saves both overallRating + overallCondition with same value
      "overallRating": _selectedOverallCondition ?? '',
      "overallCondition": _selectedOverallCondition ?? '',
      "finalRecommendation": _selectedFinalRecommendation ?? '',
      "valuationAmount": amount ?? 0,
      "chassisPunch": _selectedChassisPunch ?? '',
      "remarks": _qcRemarksController.text.isEmpty ? null : _qcRemarksController.text,
      "assignedTo": assigneeName,
      "assignedToPhoneNumber": assigneePhone,
      "assignedToEmail": assigneeEmail,
      "assignedToWhatsapp": assigneePhone,
      // Payment in same body — web portal does this in buildPayload.
      "paymentStatus": _selectedPaymentStatus ?? 'Pending',
      "paymentReference": _paymentReferenceController.text,
      "paymentDate": paymentDateIso,
      "paymentMethod": _selectedPaymentMethod ?? 'Online',
      "paymentAmount": paymentAmount,
    };
  }

  Future<void> _onSave() async {
    if (!(_qcFormKey.currentState?.validate() ?? false)) {
      _showError("Please fill all required fields (*)");
      return;
    }
    if (_selectedChassisPunch == null) {
      _showError("Please select Chassis Punch status");
      return;
    }
    if (_selectedOverallCondition == null) {
      _showError("Please select Overall Vehicle Condition");
      return;
    }
    if (_selectedFinalRecommendation == null) {
      _showError("Please select Final QC Recommendation");
      return;
    }

    setState(() => _isSaving = true);
    final ctx = _ctx();
    final user = FirebaseAuth.instance.currentUser;
    final assignee = user?.displayName ?? user?.email?.split('@').first ?? user?.phoneNumber ?? 'QC Reviewer';
    final phone = user?.phoneNumber ?? '';
    final email = user?.email ?? '';

    // 1. PUT QC details (includes payment fields per web portal pattern)
    final qcRes = await api.updateQualityControlDetails(
      ctx["id"]!, ctx["vNo"]!, ctx["contact"]!,
      _buildQcPayload(assignee, phone, email),
    );
    if (!mounted) return;
    if (qcRes['success'] != true) {
      setState(() => _isSaving = false);
      _showError("QC save failed: ${qcRes['message']}");
      return;
    }

    // 2. Also save payment to the dedicated /payments endpoint — AVO pattern.
    // Web portal embeds payment in QC body; backend may handle it from either
    // place but the dedicated endpoint is the canonical one used elsewhere.
    final payRes = await api.savePayment(
      valuationId: ctx["id"]!,
      vehicleNumber: ctx["vNo"]!,
      applicantContact: ctx["contact"]!,
      paymentStatus: _selectedPaymentStatus ?? 'Pending',
      paymentReference: _paymentReferenceController.text,
      paymentDate: _paymentDateController.text.isEmpty
          ? DateTime.now().toUtc().toIso8601String()
          : (DateTime.tryParse(_paymentDateController.text) ?? DateTime.now()).toUtc().toIso8601String(),
      paymentMethod: _selectedPaymentMethod ?? 'Online',
      paymentAmount: num.tryParse(_paymentAmountController.text) ?? 0,
    );
    if (!mounted) return;
    if (payRes['success'] != true) {
      // Log but continue — QC payload already includes payment fields.
      debugPrint("WARN: separate payment save failed (non-fatal): ${payRes['message']}");
    }

    // 3. startWorkflow(4) — ensure QC step is in InProgress
    final startRes = await api.startWorkflow(ctx["id"]!, 4, ctx["vNo"]!, ctx["contact"]!);
    if (!mounted) return;
    if (startRes['success'] != true) {
      debugPrint("DEBUG: startWorkflow(4) on save failed (likely already started): ${startRes['message']}");
    }

    // 4. updateWorkflowTable for QC
    final tableRes = await api.updateWorkflowTable(
      ctx["id"]!, ctx["vNo"]!, ctx["contact"]!,
      {
        "workflow": "QC",
        "workflowStepOrder": 4,
        "assignedTo": assignee,
        "assignedToPhoneNumber": phone,
        "assignedToEmail": email,
        "assignedToWhatsapp": phone,
        "qualityControlAssignedTo": assignee,
        "qualityControlAssignedToPhoneNumber": phone,
        "qualityControlAssignedToEmail": email,
        "qualityControlAssignedToWhatsapp": phone,
      },
    );
    if (!mounted) return;
    if (tableRes['success'] != true) {
      debugPrint("DEBUG: updateWorkflowTable on save failed: ${tableRes['message']}");
    }

    // 5. Assign QC + Valuation (web portal does both)
    await api.assignQualityControl(ctx["id"]!, ctx["vNo"]!, ctx["contact"]!, assignee, phone, email, phone);
    await api.assignValuation(ctx["id"]!, ctx["vNo"]!, ctx["contact"]!, assignee, phone, email, phone);

    await _loadAllData();
    if (!mounted) return;
    setState(() {
      _isSaving = false;
      _isEditing = false;
    });
    _showSuccess("Saved successfully");
  }

  Future<void> _onSubmit() async {
    if (!(_qcFormKey.currentState?.validate() ?? false)) {
      _showError("Please fill all required fields (*)");
      return;
    }
    if (_selectedChassisPunch == null) {
      _showError("Please select Chassis Punch status");
      return;
    }
    if (_selectedOverallCondition == null) {
      _showError("Please select Overall Vehicle Condition");
      return;
    }
    if (_selectedFinalRecommendation == null) {
      _showError("Please select Final QC Recommendation");
      return;
    }

    setState(() => _isSubmitting = true);
    final ctx = _ctx();
    final user = FirebaseAuth.instance.currentUser;
    final assignee = user?.displayName ?? user?.email?.split('@').first ?? user?.phoneNumber ?? 'QC Reviewer';
    final phone = user?.phoneNumber ?? '';
    final email = user?.email ?? '';

    // 1. PUT QC details
    final qcRes = await api.updateQualityControlDetails(
      ctx["id"]!, ctx["vNo"]!, ctx["contact"]!,
      _buildQcPayload(assignee, phone, email),
    );
    if (!mounted) return;
    if (qcRes['success'] != true) {
      setState(() => _isSubmitting = false);
      _showError("Submit failed at QC save: ${qcRes['message']}");
      return;
    }

    // 2. Payment
    final payRes = await api.savePayment(
      valuationId: ctx["id"]!,
      vehicleNumber: ctx["vNo"]!,
      applicantContact: ctx["contact"]!,
      paymentStatus: _selectedPaymentStatus ?? 'Pending',
      paymentReference: _paymentReferenceController.text,
      paymentDate: _paymentDateController.text.isEmpty
          ? DateTime.now().toUtc().toIso8601String()
          : (DateTime.tryParse(_paymentDateController.text) ?? DateTime.now()).toUtc().toIso8601String(),
      paymentMethod: _selectedPaymentMethod ?? 'Online',
      paymentAmount: num.tryParse(_paymentAmountController.text) ?? 0,
    );
    if (!mounted) return;
    if (payRes['success'] != true) {
      debugPrint("WARN: separate payment save failed: ${payRes['message']}");
    }

    // 3. completeWorkflow(4) — close QC step
    final completeRes = await api.completeWorkflow(ctx["id"]!, 4, ctx["vNo"]!, ctx["contact"]!);
    if (!mounted) return;
    if (completeRes['success'] != true) {
      setState(() => _isSubmitting = false);
      _showError("Submit failed: could not complete QC step. ${completeRes['message']}");
      return;
    }

    // 4. startWorkflow(5) — open Final Report step
    final startFr = await api.startWorkflow(ctx["id"]!, 5, ctx["vNo"]!, ctx["contact"]!);
    if (!mounted) return;
    if (startFr['success'] != true) {
      setState(() => _isSubmitting = false);
      _showError("Submit failed: could not start Final Report step. ${startFr['message']}");
      return;
    }

    // 5. updateWorkflowTable to FinalReport
    final tableRes = await api.updateWorkflowTable(
      ctx["id"]!, ctx["vNo"]!, ctx["contact"]!,
      {
        "workflow": "FinalReport",
        "workflowStepOrder": 5,
        "assignedTo": assignee,
        "assignedToPhoneNumber": phone,
        "assignedToEmail": email,
        "assignedToWhatsapp": phone,
        "qualityControlAssignedTo": assignee,
        "qualityControlAssignedToPhoneNumber": phone,
        "qualityControlAssignedToEmail": email,
        "qualityControlAssignedToWhatsapp": phone,
      },
    );
    if (!mounted) return;
    if (tableRes['success'] != true) {
      debugPrint("WARN: updateWorkflowTable failed after QC Submit: ${tableRes['message']}");
    }

    // 6. Assign QC + Valuation again (web portal does on submit)
    await api.assignQualityControl(ctx["id"]!, ctx["vNo"]!, ctx["contact"]!, assignee, phone, email, phone);
    await api.assignValuation(ctx["id"]!, ctx["vNo"]!, ctx["contact"]!, assignee, phone, email, phone);

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

  Future<void> _selectDate(TextEditingController c) async {
    final initial = DateTime.tryParse(c.text) ?? DateTime.now();
    final picked = await showDatePicker(
        context: context, initialDate: initial, firstDate: DateTime(1990), lastDate: DateTime(2040));
    if (picked != null) setState(() => c.text = DateFormat('yyyy-MM-dd').format(picked));
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
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
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
                  _buildQualityControlSection(),
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
            onPressed: isProcessing ? null : _onSubmit,
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

  Widget _buildStakeholderSection() {
    return _buildSectionContainer("Stakeholder", [
      _buildReadOnly("Stakeholder Name", _readStr(_finalReport, ['stakeholder.name', 'stakeholderName'])),
      _buildReadOnly("Executive Name", _readStr(_finalReport, ['stakeholder.executiveName'])),
      _buildReadOnly("Contact Number", _readStr(_finalReport, ['stakeholder.executiveContact'])),
      _buildReadOnly("WhatsApp Number", _readStr(_finalReport, ['stakeholder.executiveWhatsapp'])),
      _buildReadOnly("Email ID", _readStr(_finalReport, ['stakeholder.executiveEmail'])),
      _buildReadOnly("Applicant Name", _readStr(_finalReport, ['stakeholder.applicant.name'])),
      _buildReadOnly("Applicant Contact",
          _readStr(_finalReport, ['stakeholder.applicant.contact', 'applicantContact'])),
    ]);
  }

  Widget _buildVehicleDetailsSection() {
    return _buildSectionContainer("Vehicle Details", [
      _buildReadOnly("Registration Number", _readStr(_finalReport, ['vehicleDetails.registrationNumber'])),
      _buildReadOnly("Make", _readStr(_finalReport, ['vehicleDetails.make'])),
      _buildReadOnly("Model", _readStr(_finalReport, ['vehicleDetails.model'])),
      _buildReadOnly("Year of Mfg", _readStr(_finalReport, ['vehicleDetails.yearOfMfg'])),
      _buildReadOnly("Body Type", _readStr(_finalReport, ['vehicleDetails.bodyType'])),
      _buildReadOnly("Chassis Number", _readStr(_finalReport, ['vehicleDetails.chassisNumber'])),
      _buildReadOnly("Engine Number", _readStr(_finalReport, ['vehicleDetails.engineNumber'])),
      _buildReadOnly("Color", _readStr(_finalReport, ['vehicleDetails.colour', 'vehicleDetails.color'])),
      _buildReadOnly("Fuel Type", _readStr(_finalReport, ['vehicleDetails.fuel'])),
      _buildReadOnly("Owner Name", _readStr(_finalReport, ['vehicleDetails.ownerName'])),
      _buildReadOnly("RTO", _readStr(_finalReport, ['vehicleDetails.rto'])),
    ]);
  }

  Widget _buildInspectionDetailsSection() {
    final engineStarted = _readStr(_finalReport, ['inspectionDetails.engineStarted']);
    final roadWorthy = _readStr(_finalReport, ['inspectionDetails.roadWorthyCondition']);

    return _buildSectionContainer("Inspection Details", [
      _buildReadOnly("Inspected By", _readStr(_finalReport, ['inspectionDetails.vehicleInspectedBy'])),
      _buildReadOnly("Date of Inspection", _fmtDate(_readStr(_finalReport, ['inspectionDetails.dateOfInspection']))),
      _buildReadOnly("Location", _readStr(_finalReport, ['inspectionDetails.inspectionLocation'])),
      _buildReadOnly("Odometer Reading", _readStr(_finalReport, ['inspectionDetails.odometer'])),
      _buildReadOnly("Engine Started", _displayBool(engineStarted)),
      _buildReadOnly("Road Worthy Condition", _displayBool(roadWorthy)),
      _buildReadOnly("Overall Tyre Condition",
          _displayBool(_readStr(_finalReport, ['inspectionDetails.overallTyreCondition']))),
      _buildReadOnly("Engine Condition",
          _displayBool(_readStr(_finalReport, ['inspectionDetails.engineCondition']))),
      _buildReadOnly("Brake System Condition",
          _displayBool(_readStr(_finalReport, ['inspectionDetails.brakeSystem']))),
    ]);
  }

  Widget _buildQualityControlSection() {
    final canEdit = _isEditing;
    return Form(
      key: _qcFormKey,
      child: _buildSectionContainer("Quality Control", [
        // ── Valuation Amount ──
        _buildEditField(
          "Valuation Amount (₹)",
          _valuationAmountController,
          isEditable: canEdit,
          isRequired: true,
          keyboardType: TextInputType.number,
        ),

        // ── Chassis Punch — button picker ──
        _buildButtonPicker(
          label: "Chassis Punch",
          options: _chassisPunchOptions,
          selected: _selectedChassisPunch,
          isEditable: canEdit,
          isRequired: true,
          onChanged: (v) => setState(() => _selectedChassisPunch = v),
          optionColors: const {
            'Original': Colors.green,
            'Re-Punched': Colors.orange,
            'Tampered': Colors.red,
          },
        ),

        // ── Overall Vehicle Condition — button picker ──
        _buildButtonPicker(
          label: "Overall Vehicle Condition",
          options: _overallConditionOptions,
          selected: _selectedOverallCondition,
          isEditable: canEdit,
          isRequired: true,
          onChanged: (v) => setState(() => _selectedOverallCondition = v),
          optionColors: const {
            'Good': Colors.green,
            'Average': Colors.orange,
            'Poor': Colors.red,
          },
        ),

        // ── Final QC Recommendation — button picker ──
        _buildButtonPicker(
          label: "Final QC Recommendation",
          options: _finalRecommendationOptions,
          selected: _selectedFinalRecommendation,
          isEditable: canEdit,
          isRequired: true,
          onChanged: (v) => setState(() => _selectedFinalRecommendation = v),
          optionColors: const {
            'Recommended': Colors.green,
            'Recommended with Conditions': Colors.orange,
            'Not Recommended': Colors.red,
          },
        ),

        // ── QC Officer (read-only) ──
        _buildReadOnly(
          "QC Officer",
          FirebaseAuth.instance.currentUser?.displayName ??
              (widget.summaryData['assignedTo']?.toString().isNotEmpty == true
                  ? widget.summaryData['assignedTo'].toString()
                  : 'QC Officer'),
        ),

        // ── QC Review Date (read-only, today) ──
        _buildReadOnly(
          "QC Review Date",
          DateFormat('d MMM yyyy').format(DateTime.now()),
        ),

        // ── Remarks ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("QC Summary Remarks",
                  style: TextStyle(color: Colors.grey[600], fontSize: 14)),
              const SizedBox(height: 6),
              TextField(
                controller: _qcRemarksController,
                readOnly: !canEdit,
                maxLines: 3,
                decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.all(12)),
              ),
            ],
          ),
        ),
      ], isOpen: true),
    );
  }

  /// Visual button-group picker (mirrors web portal rec-card style).
  Widget _buildButtonPicker({
    required String label,
    required List<String> options,
    required String? selected,
    required bool isEditable,
    bool isRequired = false,
    required Function(String) onChanged,
    Map<String, Color> optionColors = const {},
  }) {
    if (!isEditable) {
      // Read-only view — show value as plain text
      return _buildReadOnly(label, selected ?? '-');
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            text: TextSpan(
              text: label,
              style: TextStyle(color: Colors.grey[700], fontSize: 14),
              children: [
                if (isRequired)
                  const TextSpan(
                      text: " *", style: TextStyle(color: Colors.red))
              ],
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: options.map((opt) {
              final isSelected = selected == opt;
              final color = optionColors[opt] ?? Colors.blueGrey;
              return GestureDetector(
                onTap: () => onChanged(opt),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                    color: isSelected ? color : Colors.grey[100],
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isSelected ? color : Colors.grey.shade300,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Text(
                    opt,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.grey[700],
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                      fontSize: 13,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          if (isRequired && selected == null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text("Please select an option",
                  style: TextStyle(color: Colors.red[700], fontSize: 12)),
            ),
        ],
      ),
    );
  }

  Widget _buildPaymentSection() {
    final canEdit = _isEditing;
    return _buildSectionContainer("Payment Collection", [
      if (canEdit)
        _buildDropdown("Payment Status", _paymentStatuses, _selectedPaymentStatus,
            (v) => setState(() => _selectedPaymentStatus = v),
            isMandatory: true)
      else
        _buildReadOnly("Payment Status", _selectedPaymentStatus ?? '-'),
      _buildEditField("Payment Reference", _paymentReferenceController, isEditable: canEdit),
      _buildDateField("Payment Date", _paymentDateController, canEdit, required: true),
      if (canEdit)
        _buildDropdown("Payment Method", _paymentMethods, _selectedPaymentMethod,
            (v) => setState(() => _selectedPaymentMethod = v),
            isMandatory: true)
      else
        _buildReadOnly("Payment Method", _selectedPaymentMethod ?? '-'),
      _buildEditField("Payment Amount", _paymentAmountController,
          isEditable: canEdit, isRequired: true, keyboardType: TextInputType.number),
    ]);
  }

  Widget _buildValuationRangesSection() {
    return _buildSectionContainer("Valuation Ranges (AI Estimate)", [
      _buildReadOnly("Low Range (₹ Lacs)", _readStr(_finalReport, ['valuationResponse.lowRange'])),
      _buildReadOnly("Mid Range (₹ Lacs)", _readStr(_finalReport, ['valuationResponse.midRange'])),
      _buildReadOnly("High Range (₹ Lacs)", _readStr(_finalReport, ['valuationResponse.highRange'])),
    ]);
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

  Widget _buildPhotosSection() {
    final photos = _finalReport['photoUrls'];
    final List<MapEntry<String, dynamic>> entries = [];
    if (photos is Map) {
      photos.forEach((k, v) {
        if (v != null && v.toString().isNotEmpty && v.toString().toLowerCase().startsWith('http')) {
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
              const Text("No photos available.", style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic))
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
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
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                              child: Image.network(
                                e.value.toString(),
                                fit: BoxFit.cover,
                                width: double.infinity,
                                errorBuilder: (_, __, ___) => Container(
                                  color: Colors.grey.shade200,
                                  child: const Center(
                                    child: Icon(Icons.broken_image, color: Colors.grey, size: 40),
                                  ),
                                ),
                                loadingBuilder: (ctx, child, prog) => prog == null
                                    ? child
                                    : Container(
                                        color: Colors.grey.shade100,
                                        child: const Center(
                                            child: SizedBox(
                                                height: 24,
                                                width: 24,
                                                child: CircularProgressIndicator(strokeWidth: 2))),
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
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500),
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

  Widget _buildDropdown(String label, List<String> items, String? value, Function(String?) onChanged,
      {bool isMandatory = false}) {
    Widget labelWidget = RichText(
      text: TextSpan(text: label, style: TextStyle(color: Colors.grey[600], fontSize: 14), children: [
        if (isMandatory) const TextSpan(text: " *", style: TextStyle(color: Colors.red))
      ]),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        labelWidget,
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          value: value,
          isExpanded: true,
          decoration: const InputDecoration(
              border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12)),
          items: items
              .map((it) => DropdownMenuItem(value: it, child: Text(it, style: const TextStyle(fontSize: 13))))
              .toList(),
          onChanged: onChanged,
        ),
      ]),
    );
  }

  Widget _buildDateField(String label, TextEditingController controller, bool isEditable, {bool required = false}) {
    return GestureDetector(
      onTap: isEditable ? () => _selectDate(controller) : null,
      child: AbsorbPointer(
        child: _buildEditField(label, controller, isEditable: isEditable, isRequired: required),
      ),
    );
  }
}