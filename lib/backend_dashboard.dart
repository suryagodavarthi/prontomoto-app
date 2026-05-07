import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:file_picker/file_picker.dart';
import 'services/api_service.dart';
import 'main.dart';
import 'avo_dashboard.dart';
import 'qc_dashboard.dart';
import 'finalreport_dashboard.dart';

class BackendDashboard extends StatefulWidget {
  final String userName;
  const BackendDashboard({super.key, required this.userName});

  @override
  State<BackendDashboard> createState() => _BackendDashboardState();
}

class _BackendDashboardState extends State<BackendDashboard> {
  final ApiService api = ApiService();
  List<dynamic> _allCases = [];
  List<dynamic> _cases = [];
  bool _isLoading = true;
  String _selectedSubTab = "All";

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  void _loadDashboardData() async {
    setState(() => _isLoading = true);
    try {
      final all = await api.getOpenValuations();
      all.sort((a, b) => (b['createdAt'] ?? "").compareTo(a['createdAt'] ?? ""));
      // Filter to Backend step only
      final filtered = all.where((c) {
        final wf = (c['workflow'] ?? "").toString().toLowerCase();
        return wf.contains("backend");
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, 
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("ProntoMoto Backend", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18)),
            Text("Hello, ${widget.userName}", style: const TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh, color: Colors.black), onPressed: _loadDashboardData),
          IconButton(
              icon: const Icon(Icons.logout, color: Colors.red),
              onPressed: () async {
                await FirebaseAuth.instance.signOut();
                if (context.mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginPage()));
              })
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
                _buildTabChip("All", _allCases.length),
                const SizedBox(width: 8),
                _buildTabChip("Pending", _allCases.where((c) => !(c['status'] ?? "").toString().toLowerCase().contains("return")).length),
                const SizedBox(width: 8),
                _buildTabChip("Returned", _allCases.where((c) => (c['status'] ?? "").toString().toLowerCase().contains("return")).length),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _cases.isEmpty
                    ? const Center(child: Text("No cases in this view.", style: TextStyle(color: Colors.grey)))
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _cases.length,
                        itemBuilder: (context, index) => _buildCard(_cases[index]),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabChip(String label, int count) {
    bool isSelected = _selectedSubTab == label;
    return GestureDetector(
      onTap: () => _onSubTabSelected(label),
      child: Chip(
        label: Text("$label ($count)", style: TextStyle(color: isSelected ? Colors.white : Colors.green, fontWeight: FontWeight.bold)),
        backgroundColor: isSelected ? Colors.green : Colors.green.withOpacity(0.1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: isSelected ? Colors.green : Colors.transparent)),
      ),
    );
  }

  Color _tatColor(int days) {
    if (days <= 1) return Colors.green;
    if (days == 2) return Colors.orange;
    return Colors.red;
  }

  Color _tatBgColor(int days) {
    if (days <= 1) return Colors.green.shade50;
    if (days == 2) return Colors.orange.shade50;
    return Colors.red.shade50;
  }

  Widget _buildCard(Map<String, dynamic> item) {
    String plate = item['vehicleNumber'] ?? "Unknown";
    String location = item['location'] ?? "Unknown";
    String applicant = item['applicantName'] ?? "Unknown";
    String status = item['workflow'] ?? "Backend";
    String itemStatus = item['status'] ?? "";
    bool redFlag = item['redFlag'] == true;
    String? assignedTo = item['assignedTo']?.toString();
    if (assignedTo != null && assignedTo.isEmpty) assignedTo = null;

    String? dateStr = item['createdAt'];
    int daysOld = 0;
    if (dateStr != null) {
      DateTime created = DateTime.tryParse(dateStr) ?? DateTime.now();
      daysOld = DateTime.now().difference(created).inDays;
    }

    Color ageColor = _tatColor(daysOld);
    Color bgAgeColor = _tatBgColor(daysOld);

    bool isReturned = itemStatus.toLowerCase().contains("return");

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
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.blueGrey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.blueGrey.shade200),
                        ),
                        child: Text(status, style: const TextStyle(fontSize: 10, color: Colors.blueGrey, fontWeight: FontWeight.bold)),
                      ),
                      if (redFlag) ...[
                        const SizedBox(width: 6),
                        const Text("⚑", style: TextStyle(color: Colors.red, fontSize: 14)),
                      ],
                      if (itemStatus.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Text(
                          itemStatus,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: isReturned ? Colors.red : Colors.blueGrey,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: bgAgeColor, borderRadius: BorderRadius.circular(4)),
                  child: Text("TAT: ${daysOld}d", style: TextStyle(color: ageColor, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 30,
                  child: OutlinedButton(
                    onPressed: () => navigateToCase(context, item, _loadDashboardData),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.deepPurple.shade200),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      foregroundColor: Colors.deepPurple,
                    ),
                    child: const Text("ENTER", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}

class BackendCaseDetailsPage extends StatefulWidget {
  final Map<String, dynamic> summaryData;
  const BackendCaseDetailsPage({super.key, required this.summaryData});

  @override
  State<BackendCaseDetailsPage> createState() => _BackendCaseDetailsPageState();
}

class _BackendCaseDetailsPageState extends State<BackendCaseDetailsPage> {
  final ApiService api = ApiService();
  
  bool _isLoading = true;
  bool _isEditing = false;
  bool _isSaving = false;
  bool _isSubmitting = false;
  bool _isRejecting = false; 

  Map<String, dynamic> _fullData = {};
  List<dynamic> _notes = [];

  final List<String> _fuelTypes = ["Petrol", "Diesel", "CNG", "Electric", "Hybrid", "LPG"];
  final List<String> _bodyTypes = ["Sedan", "SUV", "Hatchback", "MUV", "Coupe", "Convertible", "Pickup", "Truck", "Bus", "Van", "Three Wheeler", "Saloon", "Estate"];
  final List<String> _vehicleClasses = ["Private", "Commercial", "Transport", "Non-Transport"];
  final List<String> _normsTypes = ["Bharat Stage III", "Bharat Stage IV", "Bharat Stage VI", "Euro 3", "Euro 4"];
  final List<String> _ownersList = ["1", "2", "3", "4", "5+"];
  List<String> _assigneeList = ["SHEKHAR (AVO)", "Final Report Team", "Admin"];

  String? _selectedAssignee;

  final _regNoController = TextEditingController();
  final _makeController = TextEditingController();
  final _modelController = TextEditingController();
  final _colorController = TextEditingController();
  final _bodyTypeController = TextEditingController();
  final _classVehicleController = TextEditingController();
  final _normsTypeController = TextEditingController();
  final _ownerSerialController = TextEditingController();
  final _mfgYearController = TextEditingController();
  final _mfgMonthController = TextEditingController();
  final _engineNoController = TextEditingController();
  final _chassisNoController = TextEditingController();
  final _engineCcController = TextEditingController();
  final _grossWeightController = TextEditingController();
  final _seatingController = TextEditingController();
  final _regDateController = TextEditingController();
  final _rtoController = TextEditingController();
  final _categoryCodeController = TextEditingController();
  final _makerVariantController = TextEditingController();
  final _ownerNameController = TextEditingController();
  final _presentAddrController = TextEditingController();
  final _permAddrController = TextEditingController();
  final _lenderController = TextEditingController();
  final _insurerController = TextEditingController();
  final _policyNoController = TextEditingController();
  final _insuranceValidController = TextEditingController();
  final _idvController = TextEditingController();
  final _permitNoController = TextEditingController();
  final _permitValidController = TextEditingController();
  final _permitTypeController = TextEditingController();
  final _permitIssuedController = TextEditingController();
  final _permitFromController = TextEditingController();
  final _fitnessNoController = TextEditingController();
  final _fitnessValidController = TextEditingController();
  final _taxUpToController = TextEditingController();
  final _taxPaidController = TextEditingController();
  final _pollutionNoController = TextEditingController();
  final _pollutionValidController = TextEditingController();
  final _showroomPriceController = TextEditingController();
  final _remarksController = TextEditingController();
  final _mfgDateController = TextEditingController();
  final _stencilUrlController = TextEditingController();
  final _chassisUrlController = TextEditingController();

  String? _selectedFuel;
  bool _hypothecation = false;
  bool _rcStatus = false; 
  bool _blacklistStatus = false;

  String? _selectedRcPath;
  String? _selectedInsurancePath;
  String? _selectedOtherPath;

  @override
  void initState() {
    super.initState();
    _loadFullDetails();
  }

  // --- SAFE CONTEXT HELPER ---
  Map<String, String> _getSafeContext() {
    var d = {...widget.summaryData, ..._fullData};
    String id = widget.summaryData['valuationId']?.toString() ?? widget.summaryData['id']?.toString() ?? "";
    
    String vNo = _regNoController.text.trim();
    if (vNo.isEmpty) vNo = _val(d, ['VehicleNumber', 'vehicleNumber', 'RegistrationNumber']);
    if (vNo.isEmpty) vNo = "UNKNOWN";
    
    String contact = _val(d, ['ApplicantContact', 'applicantContact']);
    if (contact.isEmpty) contact = "0000000000";
    
    return {"id": id, "vNo": vNo, "contact": contact};
  }

  Future<void> _loadFullDetails() async {
    var ctx = _getSafeContext();
    if (ctx["id"]!.isEmpty) { setState(() => _isLoading = false); return; }

    var details = await api.getBackendVehicleDetails(ctx["id"]!, ctx["vNo"]!, ctx["contact"]!);
    var stakeholderDetails = await api.getValuationDetails(ctx["id"]!, ctx["vNo"]!, ctx["contact"]!);
    var fetchedNotes = await api.getNotes(ctx["id"]!);

    // Load assignee list from API (AVO role users), fall back to defaults on error
    try {
      final avoUsers = await api.getUsersByRole('avo');
      final frUsers = await api.getUsersByRole('finalreport');
      final allUsers = [...avoUsers, ...frUsers];
      if (allUsers.isNotEmpty) {
        final names = allUsers.map((u) {
          final name = u['name']?.toString() ?? u['userName']?.toString() ?? '';
          final role = u['role']?.toString() ?? '';
          return name.isNotEmpty ? '$name ($role)' : '';
        }).where((s) => s.isNotEmpty).toList();
        if (names.isNotEmpty && mounted) {
          setState(() => _assigneeList = names);
        }
      }
    } catch (_) {
      // Keep default list on failure
    }

    if (mounted) {
      setState(() {
        _fullData = {};
        _fullData.addAll(widget.summaryData);
        _fullData.addAll(stakeholderDetails);
        _fullData.addAll(details);

        _notes = fetchedNotes;
        _populateControllers();
        _isLoading = false;
      });
    }
  }

  void _populateControllers() {
    var d = _fullData;

    _regNoController.text = _val(d, ['RegistrationNumber', 'registrationNumber', 'vehicleNumber', 'VehicleNumber']);
    _makeController.text = _val(d, ['Make', 'make']);
    _modelController.text = _val(d, ['Model', 'model']);
    _colorController.text = _val(d, ['Colour', 'colour', 'color']);
    _bodyTypeController.text = _val(d, ['BodyType', 'bodyType']);
    _classVehicleController.text = _val(d, ['ClassOfVehicle', 'classOfVehicle']);
    _normsTypeController.text = _val(d, ['NormsType', 'normsType']);
    _ownerSerialController.text = _val(d, ['OwnerSerialNo', 'ownerSerialNo']);
    
    _mfgYearController.text = _val(d, ['YearOfMfg', 'yearOfMfg']);
    _mfgMonthController.text = _val(d, ['MonthOfMfg', 'monthOfMfg']);
    _engineNoController.text = _val(d, ['EngineNumber', 'engineNumber']);
    _chassisNoController.text = _val(d, ['ChassisNumber', 'chassisNumber']);
    _engineCcController.text = _val(d, ['EngineCC', 'engineCC']);
    _grossWeightController.text = _val(d, ['GrossVehicleWeight', 'grossVehicleWeight']);
    _seatingController.text = _val(d, ['SeatingCapacity', 'seatingCapacity']);
    
    _regDateController.text = _fmtDate(_val(d, ['DateOfRegistration', 'dateOfRegistration']));
    _rtoController.text = _val(d, ['Rto', 'rto']);
    _categoryCodeController.text = _val(d, ['CategoryCode', 'categoryCode']);
    _makerVariantController.text = _val(d, ['MakerVariant', 'makerVariant']);

    _ownerNameController.text = _val(d, ['OwnerName', 'ownerName']);
    _presentAddrController.text = _val(d, ['PresentAddress', 'presentAddress']);
    _permAddrController.text = _val(d, ['PermanentAddress', 'permanentAddress']);
    _lenderController.text = _val(d, ['Lender', 'lender']);

    _insurerController.text = _val(d, ['Insurer', 'insurer']);
    _policyNoController.text = _val(d, ['InsurancePolicyNo', 'insurancePolicyNo']);
    _insuranceValidController.text = _fmtDate(_val(d, ['InsuranceValidUpTo', 'insuranceValidUpTo']));
    _idvController.text = _val(d, ['IDV', 'idv']);

    _permitNoController.text = _val(d, ['PermitNo', 'permitNo']);
    _permitValidController.text = _fmtDate(_val(d, ['PermitValidUpTo', 'permitValidUpTo']));
    _permitTypeController.text = _val(d, ['PermitType', 'permitType']);
    _permitIssuedController.text = _fmtDate(_val(d, ['PermitIssuedDate', 'permitIssuedDate']));
    _permitFromController.text = _fmtDate(_val(d, ['PermitFrom', 'permitFrom']));
    _fitnessNoController.text = _val(d, ['FitnessNo', 'fitnessNo']);
    _fitnessValidController.text = _fmtDate(_val(d, ['FitnessValidTo', 'fitnessValidTo']));
    
    _taxUpToController.text = _fmtDate(_val(d, ['TaxUpto', 'taxUpto']));
    _taxPaidController.text = _val(d, ['TaxPaidUpto', 'taxPaidUpto']);
    _pollutionNoController.text = _val(d, ['PollutionCertificateNumber', 'pollutionCertificateNumber']);
    _pollutionValidController.text = _fmtDate(_val(d, ['PollutionCertificateUpto', 'pollutionCertificateUpto']));

    _showroomPriceController.text = _val(d, ['ExShowroomPrice', 'exShowroomPrice']);
    _mfgDateController.text = _fmtDate(_val(d, ['ManufacturedDate', 'manufacturedDate']));
    _stencilUrlController.text = _val(d, ['StencilTraceUrl', 'stencilTraceUrl']);
    _chassisUrlController.text = _val(d, ['ChassisNoPhotoUrl', 'chassisNoPhotoUrl']);
    _remarksController.text = _val(d, ['Remarks', 'remarks']);

    _setDropdown(_val(d, ['Fuel', 'fuel']), _fuelTypes, (v) => _selectedFuel = v);

    _hypothecation = d['hypothecation'].toString().toLowerCase() == 'true';
    String rc = d['rcStatus'].toString().toLowerCase();
    _rcStatus = (rc == 'true' || rc == 'active' || rc == 'valid');
    String bl = d['backlistStatus'].toString().toLowerCase();
    String bl2 = d['blacklistStatus'].toString().toLowerCase();
    _blacklistStatus = (bl == 'true' || bl2 == 'true');
  }

  void _setDropdown(String value, List<String> items, Function(String?) setter) {
    if (value.isEmpty) return;
    try {
      String match = items.firstWhere((e) => e.toLowerCase() == value.toLowerCase(), orElse: () => "");
      if (match.isNotEmpty) setter(match);
    } catch (e) {}
  }

  // ROBUST EXTRACTOR
  String _val(Map<String, dynamic> d, List<String> keys) {
    for (String key in keys) {
      // 1. Direct match
      if (d.containsKey(key) && d[key] != null && d[key].toString() != "null" && d[key].toString().isNotEmpty) {
        return d[key].toString();
      }
      
      // 2. Case-insensitive match
      for (var k in d.keys) {
        if (k.toLowerCase() == key.toLowerCase() && d[k] != null && d[k].toString() != "null" && d[k].toString().isNotEmpty) {
          return d[k].toString();
        }
      }
      
      // 3. Nested object match
      if (key.contains('.')) {
        var parts = key.split('.');
        dynamic current = d;
        bool found = true;
        for (var part in parts) {
          if (current is Map) {
             String? match;
             for (var k in current.keys) {
               if (k.toString().toLowerCase() == part.toLowerCase()) { match = k; break; }
             }
             if (match != null) current = current[match]; else { found = false; break; }
          } else { found = false; break; }
        }
        if (found && current != null && current.toString().isNotEmpty && current.toString() != "null") return current.toString();
      }
    }
    return "";
  }

  String _fmtDate(String s) {
    if (s.isEmpty || s == "null") return "";
    return (s.contains("T")) ? s.split("T")[0] : s;
  }

  Future<void> _handleSave() async {
    setState(() => _isSaving = true);
    await _performUpdate(isSubmit: false);
  }

  Future<void> _handleSubmit() async {
    if (_selectedAssignee == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please Select an Assignee"), backgroundColor: Colors.red));
      return;
    }
    setState(() => _isSubmitting = true);
    await _performUpdate(isSubmit: true);
  }

  Future<void> _performUpdate({required bool isSubmit}) async {
    // -------------------------------------------------------------
    // WRAPPED IN TRY-CATCH TO PREVENT INFINITE SPINNERS
    // -------------------------------------------------------------
    
    // FIX: Define stepOrder early so it's accessible throughout the function
    int stepOrder = 2; // Default to Backend step order
    if (widget.summaryData['workflowStepOrder'] != null) {
      stepOrder = int.tryParse(widget.summaryData['workflowStepOrder'].toString()) ?? 2;
    } else if (widget.summaryData['stepOrder'] != null) {
      stepOrder = int.tryParse(widget.summaryData['stepOrder'].toString()) ?? 2;
    }

    try {
      var ctx = _getSafeContext();

      Map<String, dynamic> vehicleData = {
        "RegistrationNumber": _regNoController.text,
        "Make": _makeController.text,
        "Model": _modelController.text,
        "Colour": _colorController.text,
        "Fuel": _selectedFuel,
        "BodyType": _bodyTypeController.text,
        "ClassOfVehicle": _classVehicleController.text,
        "NormsType": _normsTypeController.text,
        "OwnerSerialNo": _ownerSerialController.text,
        "YearOfMfg": int.tryParse(_mfgYearController.text) ?? 0,
        "MonthOfMfg": int.tryParse(_mfgMonthController.text) ?? 0,
        "EngineNumber": _engineNoController.text,
        "ChassisNumber": _chassisNoController.text,
        "EngineCC": int.tryParse(_engineCcController.text) ?? 0,
        "GrossVehicleWeight": double.tryParse(_grossWeightController.text) ?? 0.0,
        "SeatingCapacity": int.tryParse(_seatingController.text) ?? 0,
        "DateOfRegistration": _regDateController.text,
        "Rto": _rtoController.text,
        "MakerVariant": _makerVariantController.text,
        "CategoryCode": _categoryCodeController.text,
        "OwnerName": _ownerNameController.text,
        "PresentAddress": _presentAddrController.text,
        "PermanentAddress": _permAddrController.text,
        "Lender": _lenderController.text,
        "Hypothecation": _hypothecation,
        "RcStatus": _rcStatus,
        "BlacklistStatus": _blacklistStatus,
        "Insurer": _insurerController.text,
        "InsurancePolicyNo": _policyNoController.text,
        "InsuranceValidUpTo": _insuranceValidController.text,
        "IDV": double.tryParse(_idvController.text) ?? 0.0,
        "PermitNo": _permitNoController.text,
        "PermitValidUpTo": _permitValidController.text,
        "PermitType": _permitTypeController.text,
        "PermitIssuedDate": _permitIssuedController.text,
        "PermitFrom": _permitFromController.text,
        "FitnessNo": _fitnessNoController.text,
        "FitnessValidTo": _fitnessValidController.text,
        "TaxUpto": _taxUpToController.text,
        "TaxPaidUpto": _taxPaidController.text,
        "PollutionCertificateNumber": _pollutionNoController.text,
        "PollutionCertificateUpto": _pollutionValidController.text,
        "ExShowroomPrice": double.tryParse(_showroomPriceController.text) ?? 0.0,
        "ManufacturedDate": _mfgDateController.text,
        "StencilTraceUrl": _stencilUrlController.text,
        "ChassisNoPhotoUrl": _chassisUrlController.text,
        "Remarks": _remarksController.text,
      };

      var resText = await api.updateBackendVehicleDetails(ctx["id"]!, ctx["vNo"]!, ctx["contact"]!, vehicleData);
      
      if (!mounted) return;

      if (resText["success"] == false) {
        setState(() { _isSaving = false; _isSubmitting = false; });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Save Error: ${resText['message']}"), backgroundColor: Colors.red));
        return; 
      }

      if (_selectedRcPath != null || _selectedInsurancePath != null || _selectedOtherPath != null) {
        String s(List<String> keys, [String def = "-"]) { String val = _val(_fullData, keys); return val.isEmpty ? def : val; }
        String n(List<String> keys) { String val = _val(_fullData, keys); return (val.isEmpty || val.length < 10) ? "9999999999" : val; }

        Map<String, String> safeData = {
          "ValuationId": ctx["id"]!, "VehicleNumber": ctx["vNo"]!, "Name": s(['Name', 'stakeholderName']), "LocationName": s(['LocationName']),
          "Pincode": s(['Pincode'], "000000"), "ExecutiveName": s(['ExecutiveName']), "ExecutiveContact": n(['ExecutiveContact']),
          "ApplicantName": s(['ApplicantName']), "ApplicantContact": n(['ApplicantContact']), "VehicleSegment": s(['VehicleSegment']),
          "ValuationType": s(['ValuationType']), "Block": s(['Block']), "District": s(['District']), "State": s(['State']), "Country": s(['Country']),
        };
        
        var resFiles = await api.updateValuation(ctx["id"]!, safeData, rcPath: _selectedRcPath, insurancePath: _selectedInsurancePath, otherPath: _selectedOtherPath);
        if (resFiles["success"] == false && mounted) {
           ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("File Warning: ${resFiles['message']}"), backgroundColor: Colors.orange));
        }
      }

      if (!mounted) return;

      if (isSubmit) {
        await api.assignBackendTask(ctx["id"]!, ctx["vNo"]!, ctx["contact"]!, _selectedAssignee!); 
        
        // FIX: The stepOrder is pulled from outer scope and the invalid assignee param is removed
        var advanceResult = await api.advanceToNextStage(ctx["id"]!, stepOrder, ctx["vNo"]!, ctx["contact"]!);
        
        if (mounted) {
          setState(() { _isSaving = false; _isSubmitting = false; });
          if (advanceResult["success"] == true) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Submitted to AVO Successfully!"), backgroundColor: Colors.green));
            Navigator.pop(context);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed to advance: ${advanceResult['message']}"), backgroundColor: Colors.red));
          }
        }
      } else {
        await _loadFullDetails();
        
        if (mounted) {
          setState(() { _isSaving = false; _isSubmitting = false; _isEditing = false; });
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Saved Successfully!"), backgroundColor: Colors.green));
        }
      }

    } catch (e, stackTrace) {
      debugPrint("Submit Error: $e\n$stackTrace");
      if (mounted) {
        setState(() { _isSaving = false; _isSubmitting = false; });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("App Error: $e"), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _handleReject() async {
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Reject to Stakeholder"),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text("This case will be returned to Stakeholder stage.", style: TextStyle(color: Colors.grey, fontSize: 13)),
          const SizedBox(height: 12),
          TextField(
            controller: reasonController,
            autofocus: true,
            maxLines: 3,
            decoration: const InputDecoration(border: OutlineInputBorder(), hintText: "Enter reason for rejection..."),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Reject"),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _isRejecting = true);
    try {
      var ctx = _getSafeContext();

      int stepOrder = 2;
      if (widget.summaryData['workflowStepOrder'] != null) {
        stepOrder = int.tryParse(widget.summaryData['workflowStepOrder'].toString()) ?? 2;
      } else if (widget.summaryData['stepOrder'] != null) {
        stepOrder = int.tryParse(widget.summaryData['stepOrder'].toString()) ?? 2;
      }

      final reason = reasonController.text.trim();
      var rejectResult = await api.rejectToPreviousStage(ctx["id"]!, stepOrder, ctx["vNo"]!, ctx["contact"]!,
          reason: reason.isNotEmpty ? reason : "Rejected from Backend review");

      if (!mounted) return;
      setState(() => _isRejecting = false);

      if (rejectResult["success"] == true) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Rejected back to Stakeholder!"), backgroundColor: Colors.orange));
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Reject failed: ${rejectResult['message']}"), backgroundColor: Colors.red));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isRejecting = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("App Error: $e"), backgroundColor: Colors.red));
      }
    }
  }

  void _showAddNoteDialog() {
    TextEditingController noteController = TextEditingController();
    showDialog(context: context, builder: (ctx) => AlertDialog(
        title: const Text("Add Backend Note"),
        content: TextField(controller: noteController, decoration: const InputDecoration(hintText: "Enter note..."), maxLines: 3),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(onPressed: () async {
              Navigator.pop(ctx);
              String id = widget.summaryData['valuationId'] ?? widget.summaryData['id'];
              await api.addNote(id, noteController.text);
              _loadFullDetails(); 
            }, child: const Text("Save"))
        ],
      ));
  }

  Widget _buildHeaderCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text("Workflow Status", style: TextStyle(fontWeight: FontWeight.bold)),
          const Text("Backend View", style: TextStyle(color: Colors.grey)),
        ]),
        const SizedBox(height: 10),
        RichText(
          text: TextSpan(
            style: const TextStyle(color: Colors.black, fontSize: 13, height: 1.6),
            children: [
              const TextSpan(text: "Vehicle Number: ", style: TextStyle(fontWeight: FontWeight.bold)),
              TextSpan(text: "${widget.summaryData['vehicleNumber'] ?? _regNoController.text} | "),
              const TextSpan(text: "Status: ", style: TextStyle(fontWeight: FontWeight.bold)),
              TextSpan(text: "${widget.summaryData['status'] ?? widget.summaryData['workflow'] ?? 'Backend'}"),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            _buildWorkflowChip("Stake Holder", false, onTap: () {
              Navigator.push(context, MaterialPageRoute(
                  builder: (_) => InspectionFormPage(summaryData: widget.summaryData, initialTab: "Stakeholder")));
            }),
            const SizedBox(width: 8),
            _buildWorkflowChip("Backend", true),
            const SizedBox(width: 8),
            _buildWorkflowChip("AVO", false,
              locked: currentUserRoleLevel < 3,
              onTap: currentUserRoleLevel >= 3 ? () {
                Navigator.push(context, MaterialPageRoute(
                    builder: (_) => InspectionFormPage(summaryData: widget.summaryData, initialTab: "AVO")));
              } : null,
            ),
            const SizedBox(width: 8),
            _buildWorkflowChip("QC", false,
              locked: currentUserRoleLevel < 4,
              onTap: currentUserRoleLevel >= 4 ? () {
                Navigator.push(context, MaterialPageRoute(
                    builder: (_) => QcDetailPage(summaryData: widget.summaryData)));
              } : null,
            ),
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
      ]),
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

  Widget _buildSection({required String title, required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade300)),
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        initiallyExpanded: true,
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        children: [Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children))],
      ),
    );
  }

  Widget _buildStatusDropdown(String label, bool value, String trueText, String falseText, Function(bool) onChanged) {
    if (_isEditing) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(color: Colors.grey[700], fontSize: 12)),
            const SizedBox(height: 4),
            DropdownButtonFormField<bool>(
              value: value,
              isExpanded: true,
              decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true, contentPadding: EdgeInsets.all(12)),
              items: [
                DropdownMenuItem(value: true, child: Text(trueText)),
                DropdownMenuItem(value: false, child: Text(falseText)),
              ],
              onChanged: (val) { if(val != null) onChanged(val); },
            ),
          ],
        ),
      );
    } else {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 11)),
            const SizedBox(height: 2),
            Text(value ? trueText : falseText, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87)),
          ],
        ),
      );
    }
  }

  Widget _buildTextField(String label, TextEditingController controller, {int maxLines = 1, bool isDate = false}) {
    if (_isEditing) {
      return Padding(padding: const EdgeInsets.only(bottom: 12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: TextStyle(color: Colors.grey[700], fontSize: 12)), const SizedBox(height: 4), TextField(controller: controller, readOnly: isDate, maxLines: maxLines, onTap: isDate ? () => _selectDate(context, controller) : null, decoration: InputDecoration(border: const OutlineInputBorder(), isDense: true, contentPadding: const EdgeInsets.all(12), suffixIcon: isDate ? const Icon(Icons.calendar_today, size: 16) : null))]));
    } else {
      return Padding(padding: const EdgeInsets.only(bottom: 12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 11)), const SizedBox(height: 2), Text(controller.text.isEmpty ? "-" : controller.text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87))]));
    }
  }

  Widget _buildDropdown(String label, List<String> items, String? value, Function(String?) onChanged) {
    if (_isEditing) {
      return Padding(padding: const EdgeInsets.only(bottom: 12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: TextStyle(color: Colors.grey[700], fontSize: 12)), const SizedBox(height: 4), DropdownButtonFormField<String>(value: value, isExpanded: true, decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true, contentPadding: EdgeInsets.all(12)), items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: onChanged)]));
    } else {
      return Padding(padding: const EdgeInsets.only(bottom: 12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 11)), const SizedBox(height: 2), Text(value ?? "-", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87))]));
    }
  }

  Widget _buildDocRow(String label, String? url, String type) {
    var d = _fullData;
    String? foundUrl = url ?? _findFileUrl(d, type);
    bool hasFile = foundUrl != null && foundUrl.startsWith("http");
    String? newPath = (type == 'RC') ? _selectedRcPath : (type == 'Insurance') ? _selectedInsurancePath : _selectedOtherPath;

    return Padding(padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 8), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Expanded(flex: 2, child: Text(label, style: const TextStyle(fontWeight: FontWeight.w500))), Expanded(flex: 3, child: Row(children: [Expanded(child: Text(newPath != null ? "New: ${newPath.split('/').last}" : (hasFile ? "Existing File" : "No File"), style: TextStyle(color: newPath != null ? Colors.blue : (hasFile ? Colors.green : Colors.grey), fontSize: 12, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)), if (_isEditing) IconButton(icon: const Icon(Icons.upload_file, color: Colors.blue), onPressed: () => _pickFile(type)) else if (hasFile) InkWell(onTap: () => _openDoc(foundUrl!), child: const Text("Download", style: TextStyle(color: Colors.blue, decoration: TextDecoration.underline)))]))]));
  }

  String? _findFileUrl(Map<String, dynamic> d, String type) {
    String search = type.toLowerCase().replaceAll(" ", "");
    var docs = d['documents'] ?? d['Documents'];
    if (docs != null && docs is List) {
      for (var item in docs) {
        if (item is Map) {
           String docType = (item['type'] ?? "").toString().toLowerCase();
           if (docType.contains(search)) return item['filePath']?.toString() ?? item['fileUrl']?.toString();
        }
      }
    }
    for (var k in d.keys) {
      String cleanKey = k.toLowerCase().replaceAll(" ", "");
      if (cleanKey.contains(search) && (cleanKey.contains('file') || cleanKey.contains('doc'))) {
        var v = d[k];
        if (v != null && v.toString().isNotEmpty && v.toString() != "null") return v.toString();
      }
    }
    return null;
  }

  Future<void> _pickFile(String type) async {
    FilePickerResult? result = await FilePicker.pickFiles();
    if (result != null) {
      setState(() {
        if (type == 'RC') _selectedRcPath = result.files.single.path;
        if (type == 'Insurance') _selectedInsurancePath = result.files.single.path;
        if (type == 'Other') _selectedOtherPath = result.files.single.path;
      });
    }
  }

  Future<void> _selectDate(BuildContext context, TextEditingController controller) async {
    DateTime? picked = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(1990), lastDate: DateTime(2030));
    if (picked != null) controller.text = "${picked.year}-${picked.month.toString().padLeft(2,'0')}-${picked.day.toString().padLeft(2,'0')}";
  }

  Future<void> _openDoc(String url) async {
    if (await canLaunchUrl(Uri.parse(url))) await launchUrl(Uri.parse(url));
  }

  @override
  Widget build(BuildContext context) {
    bool _isProcessing = _isSaving || _isSubmitting || _isRejecting;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(title: const Text("Backend Verification", style: TextStyle(color: Colors.black)), backgroundColor: Colors.white, elevation: 0, iconTheme: const IconThemeData(color: Colors.black)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildHeaderCard(),
            const SizedBox(height: 15),
            if (!_isEditing) Row(children: [Expanded(child: ElevatedButton(onPressed: () => setState(() => _isEditing = true), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3F51B5), foregroundColor: Colors.white), child: const Text("Edit"))), const SizedBox(width: 10), Expanded(child: ElevatedButton(onPressed: () => Navigator.pop(context), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF4081), foregroundColor: Colors.white), child: const Text("Back")))]),
            const SizedBox(height: 20),

            _buildSection(title: "Vehicle Information", children: [
              _buildTextField("Registration Number", _regNoController),
              Row(children: [Expanded(child: _buildTextField("Make", _makeController)), const SizedBox(width: 10), Expanded(child: _buildTextField("Model", _modelController))]),
              Row(children: [Expanded(child: _buildTextField("Colour", _colorController)), const SizedBox(width: 10), Expanded(child: _buildDropdown("Fuel Type", _fuelTypes, _selectedFuel, (v) => setState(() => _selectedFuel = v)))]),
              _buildTextField("Body Type", _bodyTypeController),
            ]),

            _buildSection(title: "Manufacturing & Engine Details", children: [
              Row(children: [Expanded(child: _buildTextField("Year Mfg", _mfgYearController)), const SizedBox(width: 10), Expanded(child: _buildTextField("Month Mfg", _mfgMonthController))]),
              Row(children: [Expanded(child: _buildTextField("Engine Number", _engineNoController)), const SizedBox(width: 10), Expanded(child: _buildTextField("Chassis Number", _chassisNoController))]),
              Row(children: [Expanded(child: _buildTextField("Engine CC", _engineCcController)), const SizedBox(width: 10), Expanded(child: _buildTextField("Gross Vehicle Weight", _grossWeightController))]),
              _buildTextField("Seating Capacity", _seatingController),
            ]),

            _buildSection(title: "Registration & RTO", children: [
              Row(children: [Expanded(child: _buildTextField("Date of Registration", _regDateController, isDate: true)), const SizedBox(width: 10), Expanded(child: _buildTextField("RTO", _rtoController))]),
              Row(children: [Expanded(child: _buildTextField("Class of Vehicle", _classVehicleController)), const SizedBox(width: 10), Expanded(child: _buildTextField("Category Code", _categoryCodeController))]),
              Row(children: [Expanded(child: _buildTextField("Norms Type", _normsTypeController)), const SizedBox(width: 10), Expanded(child: _buildTextField("Maker Variant", _makerVariantController))]),
            ]),

            _buildSection(title: "Owner & Hypothecation", children: [
              Row(children: [Expanded(child: _buildTextField("Owner Name", _ownerNameController)), const SizedBox(width: 10), Expanded(child: _buildTextField("Owner Serial No", _ownerSerialController))]),
              _buildTextField("Present Address", _presentAddrController),
              _buildTextField("Permanent Address", _permAddrController),
              Row(children: [Expanded(child: _buildStatusDropdown("Hypothecation", _hypothecation, "YES", "NO", (v) => setState(() => _hypothecation = v))), const SizedBox(width: 10), Expanded(child: _buildTextField("Lender", _lenderController))]),
            ]),

            _buildSection(title: "Insurance Details", children: [
              Row(children: [Expanded(child: _buildTextField("Insurer", _insurerController)), const SizedBox(width: 10), Expanded(child: _buildTextField("Policy No", _policyNoController))]),
              _buildTextField("Valid Upto", _insuranceValidController, isDate: true),
            ]),

            _buildSection(title: "Permit & Fitness", children: [
              Row(children: [Expanded(child: _buildTextField("Permit No", _permitNoController)), const SizedBox(width: 10), Expanded(child: _buildTextField("Valid Upto", _permitValidController, isDate: true))]),
              Row(children: [Expanded(child: _buildTextField("Permit Type", _permitTypeController)), const SizedBox(width: 10), Expanded(child: _buildTextField("Issued Date", _permitIssuedController, isDate: true))]),
              _buildTextField("Permit From", _permitFromController, isDate: true),
              Row(children: [Expanded(child: _buildTextField("Fitness No", _fitnessNoController)), const SizedBox(width: 10), Expanded(child: _buildTextField("Fitness Valid To", _fitnessValidController, isDate: true))]),
            ]),

            _buildSection(title: "Pollution Certificate & Tax", children: [
              Row(children: [Expanded(child: _buildTextField("Pollution No", _pollutionNoController)), const SizedBox(width: 10), Expanded(child: _buildTextField("Valid Upto", _pollutionValidController, isDate: true))]),
              Row(children: [Expanded(child: _buildTextField("Tax Up To", _taxUpToController, isDate: true)), const SizedBox(width: 10), Expanded(child: _buildTextField("Tax Paid Up To", _taxPaidController))]),
            ]),

            _buildSection(title: "Additional Info", children: [
              Row(children: [Expanded(child: _buildTextField("IDV", _idvController)), const SizedBox(width: 10), Expanded(child: _buildTextField("Ex Showroom", _showroomPriceController))]),
              Row(children: [
                Expanded(child: _buildStatusDropdown("Backlist Status", _blacklistStatus, "YES", "NO", (v) => setState(() => _blacklistStatus = v))), 
                const SizedBox(width: 10), 
                Expanded(child: _buildStatusDropdown("RC Status", _rcStatus, "VALID", "INVALID", (v) => setState(() => _rcStatus = v)))
              ]),
              _buildTextField("Manufactured Date", _mfgDateController, isDate: true),
              Row(children: [Expanded(child: _buildTextField("Stencil URL", _stencilUrlController)), const SizedBox(width: 10), Expanded(child: _buildTextField("Chassis Photo URL", _chassisUrlController))]),
            ]),

            _buildSection(title: "Remarks", children: [_buildTextField("Remarks", _remarksController, maxLines: 3)]),

            _buildSection(title: "Documents", children: [
              _buildDocRow("RC", null, "RC"),
              _buildDocRow("Insurance", null, "Insurance"),
              _buildDocRow("Other", null, "Other"),
            ]),

            Container(
              margin: const EdgeInsets.only(bottom: 20),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade300)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text("Backend Notes (${_notes.length})", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), ElevatedButton.icon(onPressed: _showAddNoteDialog, icon: const Icon(Icons.add, size: 16, color: Colors.white), label: const Text("Add Note", style: TextStyle(color: Colors.white)), style: ElevatedButton.styleFrom(backgroundColor: Colors.green))]),
                const Divider(),
                if (_notes.isEmpty) const Center(child: Text("No notes yet.", style: TextStyle(color: Colors.grey))) else for (var n in _notes) ListTile(title: Text(n['note'].toString()), subtitle: Text(n['createdDate'].toString()), leading: const Icon(Icons.comment), dense: true),
              ]),
            ),

            if (_isEditing) Container(margin: const EdgeInsets.only(bottom: 20), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade300)), child: ExpansionTile(initiallyExpanded: true, title: const Text("Assign Inspection", style: TextStyle(fontWeight: FontWeight.bold)), children: [Padding(padding: const EdgeInsets.all(16), child: DropdownButtonFormField<String>(value: _selectedAssignee, decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.all(12), labelText: "Assign to"), items: _assigneeList.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (val) => setState(() => _selectedAssignee = val)))])),

            if (_isEditing) Column(
              children: [
                Row(
                  children: [
                    Expanded(child: ElevatedButton(onPressed: _isProcessing ? null : _handleSave, style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12)), child: _isSaving ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text("SAVE"))), 
                    const SizedBox(width: 8), 
                    Expanded(child: ElevatedButton(onPressed: _isProcessing ? null : _handleSubmit, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3F51B5), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12)), child: _isSubmitting ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text("SUBMIT"))), 
                  ]
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: ElevatedButton(onPressed: _isProcessing ? null : _handleReject, style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12)), child: _isRejecting ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text("REJECT"))), 
                    const SizedBox(width: 8), 
                    Expanded(child: ElevatedButton(onPressed: _isProcessing ? null : () => setState(() => _isEditing = false), style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12)), child: const Text("CANCEL"))),
                  ]
                )
              ]
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}