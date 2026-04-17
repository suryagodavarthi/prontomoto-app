import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart'; 
import 'services/api_service.dart';
import 'vehicle_media_page.dart'; 
import 'package:file_picker/file_picker.dart'; 
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart'; 
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'main.dart'; 
import 'backend_dashboard.dart';

class AvoDashboard extends StatefulWidget {
  final String userName;
  const AvoDashboard({super.key, required this.userName});

  @override
  State<AvoDashboard> createState() => _AvoDashboardState();
}

class _AvoDashboardState extends State<AvoDashboard> {
  final ApiService _api = ApiService();
  bool _isLoading = true;
  List<dynamic> _allCases = []; 
  List<dynamic> _visibleCases = [];
  
  Map<String, int> _counts = {"All": 0, "Stakeholder": 0, "Backend": 0, "AVO": 0, "QC": 0, "FinalReport": 0};
  String _selectedTab = "AVO";

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);
    try {
      _allCases = await _api.getOpenValuations();
      _allCases.sort((a, b) => (b['createdAt'] ?? "").compareTo(a['createdAt'] ?? ""));

      _counts = {"All": _allCases.length, "Stakeholder": 0, "Backend": 0, "AVO": 0, "QC": 0, "FinalReport": 0};
      for (var item in _allCases) {
        String wf = (item['workflow'] ?? "").toString().toLowerCase();
        if (wf.contains("stakeholder")) _counts["Stakeholder"] = _counts["Stakeholder"]! + 1;
        else if (wf.contains("backend")) _counts["Backend"] = _counts["Backend"]! + 1;
        else if (wf.contains("avo") || wf.contains("inspection")) _counts["AVO"] = _counts["AVO"]! + 1;
        else if (wf.contains("qc") || wf.contains("quality")) _counts["QC"] = _counts["QC"]! + 1;
        else _counts["FinalReport"] = _counts["FinalReport"]! + 1;
      }

      if (mounted) {
        _applyFilter();
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _applyFilter() {
    List<dynamic> filtered = [];
    for (var item in _allCases) {
      String wf = (item['workflow'] ?? "").toString().toLowerCase();
      if (_selectedTab == "All") filtered.add(item);
      else if (_selectedTab == "Stakeholder" && wf.contains("stakeholder")) filtered.add(item);
      else if (_selectedTab == "Backend" && wf.contains("backend")) filtered.add(item);
      else if (_selectedTab == "AVO" && (wf.contains("avo") || wf.contains("inspection"))) filtered.add(item);
      else if (_selectedTab == "QC" && (wf.contains("qc") || wf.contains("quality"))) filtered.add(item);
      else if (_selectedTab == "FinalReport" && wf.contains("final")) filtered.add(item);
    }
    setState(() {
      _visibleCases = filtered;
      _isLoading = false;
    });
  }

  void _onTabSelected(String tab) {
    setState(() {
      _selectedTab = tab;
      _applyFilter();
    });
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
            const Text("ProntoMoto AVO", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18)),
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
                _buildTabChip("All", _counts["All"]!),
                const SizedBox(width: 8),
                _buildTabChip("Stakeholder", _counts["Stakeholder"]!),
                const SizedBox(width: 8),
                _buildTabChip("Backend", _counts["Backend"]!),
                const SizedBox(width: 8),
                _buildTabChip("AVO", _counts["AVO"]!),
                const SizedBox(width: 8),
                _buildTabChip("QC", _counts["QC"]!),
                const SizedBox(width: 8),
                _buildTabChip("FinalReport", _counts["FinalReport"]!),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator()) 
              : _visibleCases.isEmpty 
                  ? const Center(child: Text("No pending cases in this tab.", style: TextStyle(color: Colors.grey)))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _visibleCases.length,
                      itemBuilder: (context, index) => _buildCard(_visibleCases[index]),
                    ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabChip(String label, int count) {
    bool isSelected = _selectedTab == label;
    return GestureDetector(
      onTap: () => _onTabSelected(label),
      child: Chip(
        label: Text("$label ($count)", style: TextStyle(color: isSelected ? Colors.white : Colors.green, fontWeight: FontWeight.bold)),
        backgroundColor: isSelected ? Colors.green : Colors.green.withOpacity(0.1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: isSelected ? Colors.green : Colors.transparent)),
      ),
    );
  }

  Widget _buildCard(Map<String, dynamic> item) {
    String plate = item['vehicleNumber'] ?? "Unknown";
    String location = item['location'] ?? "Unknown";
    String applicant = item['applicantName'] ?? "Unknown";
    String status = item['workflow'] ?? "AVO";
    
    String? dateStr = item['createdAt']; 
    int daysOld = 0;
    if (dateStr != null) {
      DateTime created = DateTime.tryParse(dateStr) ?? DateTime.now();
      daysOld = DateTime.now().difference(created).inDays;
    }

    Color ageColor = daysOld > 30 ? Colors.red : Colors.green;
    Color bgAgeColor = daysOld > 30 ? Colors.red.shade50 : Colors.green.shade50;

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
                  const SizedBox(height: 4),
                  Text("Step: $status", style: const TextStyle(fontSize: 10, color: Colors.blueGrey, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: bgAgeColor, borderRadius: BorderRadius.circular(4)),
                  child: Text("$daysOld Days Old", style: TextStyle(color: ageColor, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 30,
                  child: OutlinedButton(
                    onPressed: () {
                      String wf = status.toLowerCase();
                      if (wf.contains("backend")) {
                        Navigator.push(context, MaterialPageRoute(builder: (context) => BackendCaseDetailsPage(summaryData: item))).then((_) => _loadDashboardData());
                      } else if (wf.contains("avo") || wf.contains("inspection")) {
                        Navigator.push(context, MaterialPageRoute(builder: (context) => InspectionFormPage(summaryData: item))).then((_) => _loadDashboardData());
                      } else {
                        Navigator.push(context, MaterialPageRoute(builder: (context) => VehicleDetailsPage(summaryData: item))).then((_) => _loadDashboardData());
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.deepPurple.shade200),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      foregroundColor: Colors.deepPurple,
                    ),
                    child: const Text("ENTER", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                )
              ],
            )
          ],
        ),
      ),
    );
  }
}

class InspectionFormPage extends StatefulWidget {
  final Map<String, dynamic> summaryData;
  const InspectionFormPage({super.key, required this.summaryData});

  @override
  State<InspectionFormPage> createState() => _InspectionFormPageState();
}

class _InspectionFormPageState extends State<InspectionFormPage> {
  final ApiService api = ApiService();
  final _backendFormKey = GlobalKey<FormState>();
  bool _isLoading = true;
  
  bool _isAvoEditing = false;
  bool _isBackendEditing = false;
  bool _isStakeholderEditing = false;
  
  bool _isSaving = false;
  bool _isSubmitting = false;
  bool _isRejecting = false;

  bool _sameAsContact = false;
  
  String _currentTab = "AVO"; 

  Map<String, dynamic> _avoData = {};
  Map<String, dynamic> _stakeholderData = {};
  Map<String, dynamic> _backendData = {};
  
  List<dynamic> _notes = []; 

  String? _selectedAssignee;
  final List<String> _assigneeOptions = ["SHEKHAR — +919885255567", "FinalReport — +9199885855567"];
  
  final List<String> _stakeholderList = [
    "State Bank of India (SBI)", "HDFC Bank", "ICICI Bank", "Axis Bank", "IndusInd Bank", 
    "Punjab National Bank (PNB)", "Federal Bank", "Union Bank of India", "Bank of Baroda", 
    "IDFC FIRST Bank", "Karur Vysya Bank", "Kotak Mahindra Bank", "Mahindra Finance", 
    "Bajaj Finserv", "Hero FinCorp", "TVS Credit Services", "Shriram Finance", 
    "Muthoot Capital Services", "Cholamandalam Investment and Finance Company", 
    "Sundaram Finance", "Manappuram Finance", "L&T Finance"
  ];
  final List<String> _valuationTypes = ["Four Wheeler", "Commercial Vehicle", "Two Wheeler", "Three Wheeler", "Tractor", "Construction Equipment"];
  final List<String> _fuelTypes = ["Petrol", "Diesel", "CNG", "Electric", "Hybrid", "LPG"];
  
  List<dynamic> _pincodeLocations = []; 
  List<String> _locationNames = []; 
  String? _selectedLocationName;
  String? _selectedStakeholderName;
  String? _selectedValuationType;
  String? _selectedFuel;

  String? _rcPath;
  String? _insPath;
  String? _otherPath;

  bool _isHypothecated = false;
  bool _isBlacklisted = false;
  bool _isRcActive = false;

  final _stkNameController = TextEditingController();
  final _stkExecController = TextEditingController();
  final _stkContactController = TextEditingController();
  final _stkWhatsappController = TextEditingController();
  final _stkEmailController = TextEditingController();
  final _stkValTypeController = TextEditingController();
  final _stkPinController = TextEditingController();
  final _stkLocationController = TextEditingController();
  final _stkBlockController = TextEditingController();
  final _stkDistrictController = TextEditingController();
  final _stkDivisionController = TextEditingController();
  final _stkStateController = TextEditingController();
  final _stkCountryController = TextEditingController();
  final _appNameController = TextEditingController();
  final _appContactController = TextEditingController();
  final _vehNoController = TextEditingController();
  final _vehSegController = TextEditingController();
  final _stkRemarksController = TextEditingController();

  final _inspectedByController = TextEditingController();
  final _inspectionDateController = TextEditingController();
  final _locationController = TextEditingController();
  final _vehicleMovedController = TextEditingController();
  final _engineStartedController = TextEditingController();
  final _odometerController = TextEditingController();
  final _vinPlateController = TextEditingController();
  final _accessoryFitmentController = TextEditingController();
  final _roadWorthyController = TextEditingController();
  final _engineCondController = TextEditingController();
  final _suspensionController = TextEditingController();
  final _steeringWheelController = TextEditingController();
  final _steeringColController = TextEditingController();
  final _steeringBoxController = TextEditingController();
  final _steeringLinkController = TextEditingController();
  final _fuelSystemController = TextEditingController();
  final _brakeSystemController = TextEditingController();
  final _chassisCondController = TextEditingController();
  final _extCondController = TextEditingController();
  final _intCondController = TextEditingController();
  final _bodyCondController = TextEditingController();
  final _paintWorkController = TextEditingController();
  final _audioController = TextEditingController();
  final _clutchController = TextEditingController();
  final _gearboxController = TextEditingController();
  final _propellerController = TextEditingController();
  final _mudguardsController = TextEditingController();
  final _allGlassesController = TextEditingController();
  final _diffController = TextEditingController();
  final _seatsController = TextEditingController();
  final _upholsteryController = TextEditingController();
  final _intTrimsController = TextEditingController();
  final _frontViewController = TextEditingController(); 
  final _rearViewController = TextEditingController(); 
  final _axlesController = TextEditingController(); 
  final _acController = TextEditingController();
  final _radiatorController = TextEditingController();
  final _hoseController = TextEditingController();
  final _remarksController = TextEditingController();
  final _noteController = TextEditingController(); 

  final _regNoController = TextEditingController();
  final _makeController = TextEditingController();
  final _modelController = TextEditingController();
  final _bodyTypeController = TextEditingController();
  final _colorController = TextEditingController();
  final _fuelTypeController = TextEditingController(); 
  final _mfgYearController = TextEditingController();
  final _mfgMonthController = TextEditingController();
  final _engineNoController = TextEditingController();
  final _chassisNoController = TextEditingController();
  final _engineCcController = TextEditingController();
  final _grossWeightController = TextEditingController();
  final _seatingController = TextEditingController();
  final _regDateController = TextEditingController();
  final _rtoController = TextEditingController();
  final _classVehicleController = TextEditingController();
  final _categoryCodeController = TextEditingController();
  final _normsTypeController = TextEditingController();
  final _makerVariantController = TextEditingController();
  final _ownerNameController = TextEditingController();
  final _ownerSerialController = TextEditingController();
  final _presentAddrController = TextEditingController();
  final _permAddrController = TextEditingController();
  final _lenderController = TextEditingController();
  final _insurerController = TextEditingController();
  final _policyNoController = TextEditingController();
  final _insuranceValidController = TextEditingController();
  final _permitNoController = TextEditingController();
  final _permitValidController = TextEditingController();
  final _permitTypeController = TextEditingController();
  final _permitIssuedOnController = TextEditingController();
  final _permitFromController = TextEditingController();
  final _fitnessNoController = TextEditingController();
  final _fitnessValidController = TextEditingController();
  final _pollutionNoController = TextEditingController();
  final _pollutionValidController = TextEditingController();
  final _taxValidController = TextEditingController();
  final _taxPaidController = TextEditingController();
  final _idvController = TextEditingController();
  final _showroomPriceController = TextEditingController();
  final _manufacturedDateController = TextEditingController();
  final _stencilUrlController = TextEditingController();
  final _chassisUrlController = TextEditingController();
  final _backendRemarksController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _stkContactController.addListener(() {
      if (_sameAsContact) {
        _stkWhatsappController.text = _stkContactController.text;
      }
    });
    _stkPinController.addListener(() {
      if (_stkPinController.text.length == 6) {
        _fetchLocationsForPincode(_stkPinController.text);
      }
    });
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    String id = widget.summaryData['valuationId'] ?? widget.summaryData['id'] ?? "";
    String vNo = widget.summaryData['vehicleNumber'] ?? "";
    String contact = widget.summaryData['applicantContact'] ?? "";

    setState(() => _isLoading = true);

    try {
      var avo = await api.getInspectionDetails(id, vNo, contact);
      var stk = await api.getValuationDetails(id, vNo, contact);
      var bck = await api.getBackendVehicleDetails(id, vNo, contact);
      var notes = await api.getNotes(id);

      if (mounted) {
        setState(() {
          _avoData = avo;
          _stakeholderData = stk;
          _backendData = bck;
          _notes = notes;

          Map<String, dynamic> merged = {};
          merged.addAll(widget.summaryData);
          merged.addAll(_stakeholderData);
          merged.addAll(_backendData);
          
          _populateStakeholderFields(merged);
          _populateAVOFields(_avoData.isNotEmpty ? _avoData : merged);
          _populateBackendFields(_backendData);

          if (_stkPinController.text.length == 6) {
            _fetchLocationsForPincode(_stkPinController.text);
          }

          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _getUniversalValue(Map<String, dynamic> data, List<String> keys) {
    for (String key in keys) {
      if (key.contains('.')) {
        var parts = key.split('.');
        dynamic current = data;
        bool found = true;
        for (var part in parts) {
          if (current is Map) {
             String? match;
             for (var k in current.keys) {
               if (k.toString().toLowerCase() == part.toLowerCase()) { match = k; break; }
             }
             if (match != null) {
               current = current[match]; 
             } else { 
               found = false; 
               break; 
             }
          } else { 
            found = false; 
            break; 
          }
        }
        if (found && current != null && current.toString().isNotEmpty && current.toString() != "null") {
          return current.toString();
        }
      }
      for(var k in data.keys) {
        if(k.toLowerCase() == key.toLowerCase()) {
           var val = data[k];
           if(val != null && val.toString() != "null" && val.toString().isNotEmpty) return val.toString();
        }
      }
    }
    return ""; 
  }

  String _valBool(Map<String, dynamic> data, List<String> keys) {
    String raw = _getUniversalValue(data, keys).toLowerCase();
    if (raw == "true" || raw == "1" || raw == "yes") return "YES";
    return "NO";
  }
  
  String _fmtDate(String s) {
    if (s.isEmpty || s == "null") return "";
    try { return DateFormat('yyyy-MM-dd').format(DateTime.parse(s)); } catch (e) { return s.split("T")[0]; }
  }

  Future<void> _fetchLocationsForPincode(String val) async {
    try {
      final url = Uri.parse("https://prontobackend-bhdnbec2fvd3ecfk.eastus2-01.azurewebsites.net/api/Pincodes/$val");
      final response = await http.get(url);
      if (response.statusCode == 200) {
        List<dynamic> data = jsonDecode(response.body);
        if (data.isNotEmpty && mounted) {
          setState(() {
            _pincodeLocations = data;
            _locationNames = data.map((e) => e['name'].toString()).toSet().toList();
            if (_selectedLocationName != null && !_locationNames.contains(_selectedLocationName)) {
              _selectedLocationName = null;
            }
          });
        }
      }
    } catch (e) {}
  }

  void _onLocationSelected(String? locName) {
    if (locName == null) return;
    setState(() {
      _selectedLocationName = locName;
      _stkLocationController.text = locName; 
      var locData = _pincodeLocations.firstWhere((e) => e['name'] == locName, orElse: () => null);
      if (locData != null) {
        _stkBlockController.text = locData['block'] ?? "";
        _stkDistrictController.text = locData['district'] ?? "";
        _stkDivisionController.text = locData['division'] ?? "";
        _stkStateController.text = locData['state'] ?? "";
        _stkCountryController.text = locData['country'] ?? "";
      }
    });
  }

  void _populateStakeholderFields(Map<String, dynamic> data) {
    String stkName = _getUniversalValue(data, ['stakeholderName', 'name', 'BankName', 'Name']);
    if (_stakeholderList.contains(stkName)) _selectedStakeholderName = stkName;
    _stkNameController.text = stkName;

    _stkExecController.text = _getUniversalValue(data, ['executiveName', 'Executive', 'ExecutiveName']);
    _stkContactController.text = _getUniversalValue(data, ['executiveContact', 'contactNumber', 'Mobile', 'ExecutiveContact']);
    _stkWhatsappController.text = _getUniversalValue(data, ['executiveWhatsapp', 'whatsappNumber', 'ExecutiveWhatsapp']);
    _stkEmailController.text = _getUniversalValue(data, ['executiveEmail', 'email', 'ExecutiveEmail']);
    
    if (_stkContactController.text.isNotEmpty && _stkContactController.text == _stkWhatsappController.text) {
      _sameAsContact = true;
    }

    String valType = _getUniversalValue(data, ['valuationType', 'Type', 'ValuationType']);
    if (_valuationTypes.contains(valType)) _selectedValuationType = valType;
    _stkValTypeController.text = valType;
    
    _stkPinController.text = _getUniversalValue(data, ['vehicleLocation.pincode', 'pincode', 'Pin', 'Pincode']);
    String locName = _getUniversalValue(data, ['vehicleLocation.name', 'locationName', 'location', 'LocationName']); 
    _stkLocationController.text = locName;
    _selectedLocationName = locName.isNotEmpty ? locName : null;

    _stkBlockController.text = _getUniversalValue(data, ['vehicleLocation.block', 'block', 'city', 'City', 'Block']); 
    _stkDistrictController.text = _getUniversalValue(data, ['vehicleLocation.district', 'district', 'District']);
    _stkDivisionController.text = _getUniversalValue(data, ['vehicleLocation.division', 'division', 'Division']);
    _stkStateController.text = _getUniversalValue(data, ['vehicleLocation.state', 'state', 'State']);
    _stkCountryController.text = _getUniversalValue(data, ['vehicleLocation.country', 'country', 'Country']);

    _appNameController.text = _getUniversalValue(data, ['applicant.name', 'applicantName', 'ApplicantName']);
    _appContactController.text = _getUniversalValue(data, ['applicant.contact', 'applicantContact', 'ApplicantContact']);
    
    _vehNoController.text = _getUniversalValue(data, ['vehicleNumber', 'VehicleNumber']);
    _vehSegController.text = _getUniversalValue(data, ['vehicleSegment', 'VehicleSegment']);
    
    _stkRemarksController.text = _getUniversalValue(data, ['remarks', 'Remarks']);
  }

  void _populateAVOFields(Map<String, dynamic> data) {
    _inspectedByController.text = _getUniversalValue(data, ['vehicleInspectedBy', 'InspectedBy', 'executiveName']);
    _inspectionDateController.text = _fmtDate(_getUniversalValue(data, ['dateOfInspection', 'createdAt']));
    _locationController.text = _getUniversalValue(data, ['inspectionLocation', 'location']);
    
    _vehicleMovedController.text = _valBool(data, ['vehicleMoved']);
    _engineStartedController.text = _valBool(data, ['engineStarted']);
    _odometerController.text = _getUniversalValue(data, ['odometer']);
    _vinPlateController.text = _valBool(data, ['vinPlate']);
    _accessoryFitmentController.text = _valBool(data, ['otherAccessoryFitment']);
    _roadWorthyController.text = _valBool(data, ['roadWorthyCondition']);
    _engineCondController.text = _getUniversalValue(data, ['engineCondition']);
    _suspensionController.text = _getUniversalValue(data, ['suspensionSystem']);
    _steeringWheelController.text = _getUniversalValue(data, ['steeringWheel']);
    _steeringColController.text = _getUniversalValue(data, ['steeringColumn']);
    _steeringBoxController.text = _getUniversalValue(data, ['steeringBox']);
    _steeringLinkController.text = _getUniversalValue(data, ['steeringLinkages']);
    _fuelSystemController.text = _getUniversalValue(data, ['fuelSystem']);
    _brakeSystemController.text = _getUniversalValue(data, ['brakeSystem']);
    _chassisCondController.text = _getUniversalValue(data, ['chassisCondition']);
    _extCondController.text = _getUniversalValue(data, ['exteriorCondition']);
    _intCondController.text = _getUniversalValue(data, ['interiorCondition']);
    _bodyCondController.text = _getUniversalValue(data, ['bodyCondition']);
    _paintWorkController.text = _getUniversalValue(data, ['paintWork']);
    _audioController.text = _getUniversalValue(data, ['audio']);
    _clutchController.text = _getUniversalValue(data, ['clutchSystem']);
    _gearboxController.text = _getUniversalValue(data, ['gearBoxAssy']);
    _propellerController.text = _getUniversalValue(data, ['propellerShaft']);
    _mudguardsController.text = _getUniversalValue(data, ['mudguards']);
    _allGlassesController.text = _getUniversalValue(data, ['allGlasses']);
    _diffController.text = _getUniversalValue(data, ['differentialAssembly']);
    _seatsController.text = _getUniversalValue(data, ['seats']);
    _upholsteryController.text = _getUniversalValue(data, ['upholstery']);
    _intTrimsController.text = _getUniversalValue(data, ['interiorTrims']);
    _frontViewController.text = _getUniversalValue(data, ['frontFairing']);
    _rearViewController.text = _getUniversalValue(data, ['rearCowls']);
    _axlesController.text = _getUniversalValue(data, ['frontAxles']);
    _acController.text = _getUniversalValue(data, ['airConditioner']);
    _radiatorController.text = _getUniversalValue(data, ['radiator']);
    _hoseController.text = _getUniversalValue(data, ['allHosePipes']);
    
    _remarksController.text = _getUniversalValue(data, ['remarks']);
  }

  void _populateBackendFields(Map<String, dynamic> data) {
    _regNoController.text = _getUniversalValue(data, ['registrationNumber']);
    _makeController.text = _getUniversalValue(data, ['make']);
    _modelController.text = _getUniversalValue(data, ['model']);
    _bodyTypeController.text = _getUniversalValue(data, ['bodyType']);
    _colorController.text = _getUniversalValue(data, ['colour', 'color']);
    
    String fType = _getUniversalValue(data, ['fuel']);
    if (_fuelTypes.contains(fType)) _selectedFuel = fType;
    _fuelTypeController.text = fType;

    _mfgYearController.text = _getUniversalValue(data, ['yearOfMfg']);
    _mfgMonthController.text = _getUniversalValue(data, ['monthOfMfg']);
    _engineNoController.text = _getUniversalValue(data, ['engineNumber']);
    _chassisNoController.text = _getUniversalValue(data, ['chassisNumber']);
    _engineCcController.text = _getUniversalValue(data, ['engineCC']);
    _grossWeightController.text = _getUniversalValue(data, ['grossVehicleWeight']);
    _seatingController.text = _getUniversalValue(data, ['seatingCapacity']);
    _regDateController.text = _fmtDate(_getUniversalValue(data, ['dateOfRegistration']));
    _rtoController.text = _getUniversalValue(data, ['rto']);
    _classVehicleController.text = _getUniversalValue(data, ['classOfVehicle']);
    _categoryCodeController.text = _getUniversalValue(data, ['categoryCode']);
    _normsTypeController.text = _getUniversalValue(data, ['normsType']);
    _makerVariantController.text = _getUniversalValue(data, ['makerVariant']);
    _ownerNameController.text = _getUniversalValue(data, ['ownerName']);
    _ownerSerialController.text = _getUniversalValue(data, ['ownerSerialNo']);
    _presentAddrController.text = _getUniversalValue(data, ['presentAddress']);
    _permAddrController.text = _getUniversalValue(data, ['permanentAddress']);
    _lenderController.text = _getUniversalValue(data, ['lender']);
    
    _isHypothecated = _valBool(data, ['hypothecation']) == "YES";
    _isRcActive = _valBool(data, ['rcStatus']) == "YES";
    _isBlacklisted = _valBool(data, ['backlistStatus']) == "YES";

    _insurerController.text = _getUniversalValue(data, ['insurer']);
    _policyNoController.text = _getUniversalValue(data, ['insurancePolicyNo']);
    _insuranceValidController.text = _fmtDate(_getUniversalValue(data, ['insuranceValidUpTo']));
    _permitNoController.text = _getUniversalValue(data, ['permitNo']);
    _permitValidController.text = _fmtDate(_getUniversalValue(data, ['permitValidUpTo']));
    _permitTypeController.text = _getUniversalValue(data, ['permitType']);
    _permitIssuedOnController.text = _fmtDate(_getUniversalValue(data, ['permitIssuedOn']));
    _permitFromController.text = _fmtDate(_getUniversalValue(data, ['permitFrom']));
    _fitnessNoController.text = _getUniversalValue(data, ['fitnessNo']);
    _fitnessValidController.text = _fmtDate(_getUniversalValue(data, ['fitnessValidTo']));
    _idvController.text = _getUniversalValue(data, ['idv']);
    _showroomPriceController.text = _getUniversalValue(data, ['exShowroomPrice']);
    _pollutionNoController.text = _getUniversalValue(data, ['pollutionCertificateNo']);
    _pollutionValidController.text = _fmtDate(_getUniversalValue(data, ['pollutionCertificateValidUpTo']));
    _taxValidController.text = _fmtDate(_getUniversalValue(data, ['taxUpTo']));
    _taxPaidController.text = _fmtDate(_getUniversalValue(data, ['taxPaidUpTo']));
    _manufacturedDateController.text = _fmtDate(_getUniversalValue(data, ['manufacturedDate']));
    _stencilUrlController.text = _getUniversalValue(data, ['stencilTraceUrl']);
    _chassisUrlController.text = _getUniversalValue(data, ['chassisNoPhotoUrl']);
    _backendRemarksController.text = _getUniversalValue(data, ['remarks']);
  }

  Future<void> _addNote() async {
    if (_noteController.text.isEmpty) return;
    await api.addNote(widget.summaryData['valuationId'] ?? "", _noteController.text);
    _noteController.clear();
    var notes = await api.getNotes(widget.summaryData['valuationId'] ?? "");
    setState(() => _notes = notes);
  }

  // --- SAFE CONTEXT HELPER ---
  Map<String, String> _getSafeContext() {
    Map<String, dynamic> d = <String, dynamic>{
      ...widget.summaryData,
      ..._stakeholderData,
      ..._backendData,
      ..._avoData
    };
    
    String id = widget.summaryData['valuationId']?.toString() ?? widget.summaryData['id']?.toString() ?? "";
    
    String vNo = _vehNoController.text.trim();
    if (vNo.isEmpty) vNo = _getUniversalValue(d, ['VehicleNumber', 'vehicleNumber', 'registrationNumber']);
    if (vNo.isEmpty) vNo = "UNKNOWN";
    
    String contact = _appContactController.text.trim();
    if (contact.isEmpty) contact = _getUniversalValue(d, ['ApplicantContact', 'applicantContact']);
    if (contact.isEmpty) contact = "0000000000";
    
    return {"id": id, "vNo": vNo, "contact": contact};
  }

  // --- WORKFLOW ACTIONS ---
  Future<void> _performAvoUpdate({required bool isSubmit}) async {
    if (isSubmit) setState(() => _isSubmitting = true);
    else setState(() => _isSaving = true);

    var ctx = _getSafeContext();

    Map<String, dynamic> body = { 
      "VehicleMoved": _vehicleMovedController.text, 
      "Odometer": _odometerController.text, 
      "Remarks": _remarksController.text,
      "EngineStarted": _engineStartedController.text,
      "VinPlate": _vinPlateController.text,
      "OtherAccessoryFitment": _accessoryFitmentController.text,
      "RoadWorthyCondition": _roadWorthyController.text,
      "EngineCondition": _engineCondController.text,
      "SuspensionSystem": _suspensionController.text,
      "SteeringWheel": _steeringWheelController.text,
      "SteeringColumn": _steeringColController.text,
      "SteeringBox": _steeringBoxController.text,
      "SteeringLinkages": _steeringLinkController.text,
      "FuelSystem": _fuelSystemController.text,
      "BrakeSystem": _brakeSystemController.text,
      "ChassisCondition": _chassisCondController.text,
      "ExteriorCondition": _extCondController.text,
      "InteriorCondition": _intCondController.text,
      "BodyCondition": _bodyCondController.text,
      "PaintWork": _paintWorkController.text,
      "Audio": _audioController.text,
      "ClutchSystem": _clutchController.text,
      "GearBoxAssy": _gearboxController.text,
      "PropellerShaft": _propellerController.text,
      "Mudguards": _mudguardsController.text,
      "AllGlasses": _allGlassesController.text,
      "DifferentialAssembly": _diffController.text,
      "Seats": _seatsController.text,
      "Upholstery": _upholsteryController.text,
      "InteriorTrims": _intTrimsController.text,
      "FrontFairing": _frontViewController.text,
      "RearCowls": _rearViewController.text,
      "FrontAxles": _axlesController.text,
      "AirConditioner": _acController.text,
      "Radiator": _radiatorController.text,
      "AllHosePipes": _hoseController.text
    };
    
    var res = await api.updateInspectionDetails(ctx["id"]!, ctx["vNo"]!, ctx["contact"]!, body);
    
    if (!mounted) return;

    if (res['success'] != true) {
      setState(() { _isSaving = false; _isSubmitting = false; });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Save Error: ${res['message']}"), backgroundColor: Colors.red));
      return;
    }

    if (isSubmit) {
      int stepOrder = widget.summaryData['workflowStepOrder'] ?? widget.summaryData['stepOrder'] ?? 3;
      var advanceResult = await api.advanceToNextStage(ctx["id"]!, stepOrder, ctx["vNo"]!, ctx["contact"]!);
      
      if (!mounted) return;
      setState(() { _isSaving = false; _isSubmitting = false; });

      if (advanceResult["success"] == true) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Submitted to QC Successfully!"), backgroundColor: Colors.green));
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed to advance: ${advanceResult['message']}"), backgroundColor: Colors.red));
      }
    } else {
      // THE FIX: Fetch fresh data to ensure the UI updates
      await _loadAllData();

      setState(() { _isSaving = false; _isAvoEditing = false; });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Saved Successfully!"), backgroundColor: Colors.green));
    }
  }

  Future<void> _handleReject() async {
    setState(() => _isRejecting = true);
    var ctx = _getSafeContext();
    int stepOrder = widget.summaryData['workflowStepOrder'] ?? widget.summaryData['stepOrder'] ?? 3;

    var rejectResult = await api.rejectToPreviousStage(ctx["id"]!, stepOrder, ctx["vNo"]!, ctx["contact"]!);
    
    if (!mounted) return;
    setState(() => _isRejecting = false);

    if (rejectResult["success"] == true) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Rejected back to Backend!"), backgroundColor: Colors.orange));
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Reject failed: ${rejectResult['message']}"), backgroundColor: Colors.red));
    }
  }

  Future<void> _saveBackend({bool submitAnyway = false}) async {
    if (!submitAnyway && !_backendFormKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please fill all mandatory fields (*)!"), backgroundColor: Colors.red));
      return;
    }
    setState(() => _isSaving = true);
    
    var ctx = _getSafeContext();

    Map<String, dynamic> body = {
      "ValuationId": ctx["id"]!, 
      "RegistrationNumber": _regNoController.text,
      "Make": _makeController.text,
      "Model": _modelController.text,
      "BodyType": _bodyTypeController.text,
      "Colour": _colorController.text,
      "Fuel": _selectedFuel ?? _fuelTypeController.text,
      "YearOfMfg": _mfgYearController.text,
      "MonthOfMfg": _mfgMonthController.text,
      "EngineNumber": _engineNoController.text,
      "ChassisNumber": _chassisNoController.text,
      "EngineCC": _engineCcController.text,
      "GrossVehicleWeight": _grossWeightController.text,
      "SeatingCapacity": _seatingController.text,
      "DateOfRegistration": _regDateController.text,
      "Rto": _rtoController.text,
      "ClassOfVehicle": _classVehicleController.text,
      "CategoryCode": _categoryCodeController.text,
      "NormsType": _normsTypeController.text,
      "MakerVariant": _makerVariantController.text,
      "OwnerName": _ownerNameController.text,
      "OwnerSerialNo": _ownerSerialController.text,
      "PresentAddress": _presentAddrController.text,
      "PermanentAddress": _permAddrController.text,
      "Lender": _lenderController.text,
      "Hypothecation": _isHypothecated,
      "Insurer": _insurerController.text,
      "InsurancePolicyNo": _policyNoController.text,
      "InsuranceValidUpTo": _insuranceValidController.text,
      "PermitNo": _permitNoController.text,
      "PermitValidUpTo": _permitValidController.text,
      "PermitType": _permitTypeController.text,
      "PermitIssuedOn": _permitIssuedOnController.text,
      "PermitFrom": _permitFromController.text,
      "FitnessNo": _fitnessNoController.text,
      "FitnessValidTo": _fitnessValidController.text,
      "PollutionCertificateNo": _pollutionNoController.text,
      "PollutionCertificateValidUpTo": _pollutionValidController.text,
      "TaxUpTo": _taxValidController.text,
      "TaxPaidUpTo": _taxPaidController.text,
      "IDV": _idvController.text,
      "ExShowroomPrice": _showroomPriceController.text,
      "RcStatus": _isRcActive,
      "BacklistStatus": _isBlacklisted,
      "ManufacturedDate": _manufacturedDateController.text,
      "StencilTraceUrl": _stencilUrlController.text,
      "ChassisNoPhotoUrl": _chassisUrlController.text,
      "Remarks": _backendRemarksController.text,
    };
    var res = await api.updateBackendVehicleDetails(ctx["id"]!, ctx["vNo"]!, ctx["contact"]!, body);
    
    if(!mounted) return;

    if (res["success"] == false) {
      setState(() { _isSaving = false; _isBackendEditing = false; });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Save Error: ${res['message']}"), backgroundColor: Colors.red));
      return; 
    }

    // THE FIX: Fetch fresh data to ensure the UI updates
    await _loadAllData();
    setState(() { _isSaving = false; _isBackendEditing = false; });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['success'] ? "Saved Successfully!" : res['message'])));
  }

  Future<void> _saveStakeholder() async {
    setState(() => _isSaving = true);
    
    var ctx = _getSafeContext();
    String currentStakeholderName = _selectedStakeholderName ?? _stkNameController.text;

    Map<String, String> formData = {
      "ValuationId": ctx["id"]!, 
      "Name": currentStakeholderName, 
      "ExecutiveName": _stkExecController.text,
      "ExecutiveContact": _stkContactController.text, 
      "ExecutiveWhatsapp": _stkWhatsappController.text,
      "ExecutiveEmail": _stkEmailController.text,
      "ValuationType": _selectedValuationType ?? _stkValTypeController.text,
      "VehicleSegment": _vehSegController.text,
      "LocationName": _stkLocationController.text, 
      "Block": _stkBlockController.text,
      "District": _stkDistrictController.text,
      "Division": _stkDivisionController.text,
      "State": _stkStateController.text,
      "Country": _stkCountryController.text,
      "ApplicantName": _appNameController.text,
      "ApplicantContact": _appContactController.text,
      "Remarks": _stkRemarksController.text,
      "VehicleNumber": _vehNoController.text,
      "Pincode": _stkPinController.text,
    };

    var result = await api.updateValuation(ctx["id"]!, formData);

    if(!mounted) return;

    // THE FIX: Fetch fresh data to ensure the UI updates
    await _loadAllData();
    setState(() { _isSaving = false; _isStakeholderEditing = false; });
    
    if(result["success"] == true) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Stakeholder details saved successfully!"), backgroundColor: Colors.green));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: ${result['message']}"), backgroundColor: Colors.red));
    }
  }

  Future<void> _pickFile(String type) async {
    FilePickerResult? result = await FilePicker.pickFiles();
    if (result != null) {
      setState(() {
        if (type == 'RC') { _rcPath = result.files.single.path!; } 
        else if (type == 'INS') { _insPath = result.files.single.path!; }
        else { _otherPath = result.files.single.path!; }
      });
    }
  }

  Future<void> _selectDate(TextEditingController controller) async {
    DateTime? picked = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(1990), lastDate: DateTime(2040));
    if (picked != null) setState(() => controller.text = DateFormat('yyyy-MM-dd').format(picked));
  }

  void _launchDownload(String? url) async {
    if (url != null && url.isNotEmpty && await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No document URL found")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA), 
      appBar: AppBar(title: const Text("Valuation Details", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)), backgroundColor: Colors.white, elevation: 1, iconTheme: const IconThemeData(color: Colors.black)),
      body: _isLoading ? const Center(child: CircularProgressIndicator()) : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildHeaderCard(),
            const SizedBox(height: 20),
            
            if (_currentTab == "AVO") 
              _buildTopActions(_isAvoEditing, () => setState(() => _isAvoEditing = true), () => _performAvoUpdate(isSubmit: false), onSubmit: () => _performAvoUpdate(isSubmit: true), onReject: _handleReject)
            else if (_currentTab == "Backend") 
              _buildTopActions(_isBackendEditing, () => setState(() => _isBackendEditing = true), () => _saveBackend(submitAnyway: false))
            else 
              _buildTopActions(_isStakeholderEditing, () => setState(() => _isStakeholderEditing = true), _saveStakeholder),
              
            const SizedBox(height: 20),
            
            if (_currentTab == "AVO") _buildAVOInspectionForm()
            else if (_currentTab == "Backend") _buildBackendForm()
            else _buildStakeholderForm()
          ],
        ),
      ),
    );
  }

  Widget _buildTopActions(bool isEditing, VoidCallback onEdit, VoidCallback onSave, {VoidCallback? onSubmit, VoidCallback? onReject}) {
    bool isProcessing = _isSaving || _isSubmitting || _isRejecting;
    
    if (!isEditing) {
      return Row(children: [
        Expanded(child: ElevatedButton(onPressed: onEdit, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3F51B5), foregroundColor: Colors.white), child: const Text("Edit"))),
        const SizedBox(width: 10),
        Expanded(child: ElevatedButton(onPressed: () => Navigator.pop(context), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE53935), foregroundColor: Colors.white), child: const Text("Back"))),
      ]);
    } else {
      return Column(
        children: [
          Row(children: [
            Expanded(child: ElevatedButton(onPressed: isProcessing ? null : onSave, style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12)), child: _isSaving ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text("SAVE"))),
            if (onSubmit != null) const SizedBox(width: 8),
            if (onSubmit != null) Expanded(child: ElevatedButton(onPressed: isProcessing ? null : onSubmit, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3F51B5), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12)), child: _isSubmitting ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text("SUBMIT"))),
          ]),
          const SizedBox(height: 8),
          Row(children: [
             if (onReject != null) Expanded(child: ElevatedButton(onPressed: isProcessing ? null : onReject, style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12)), child: _isRejecting ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text("REJECT"))),
             if (onReject != null) const SizedBox(width: 8),
             Expanded(child: ElevatedButton(onPressed: isProcessing ? null : () {
               setState(() {
                 _isAvoEditing = false;
                 _isBackendEditing = false;
                 _isStakeholderEditing = false;
               });
             }, style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12)), child: const Text("CANCEL"))),
          ])
        ]
      );
    }
  }

  Widget _buildStakeholderForm() {
    bool canEdit = _isStakeholderEditing;
    return Column(children: [
      Container(
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.only(bottom: 15),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade300)),
        child: _buildField("Pincode", _stkPinController.text, _stkPinController, isEditable: canEdit, isRequired: true),
      ),

      _buildSectionContainer("Stakeholder", [
        if (canEdit) 
          _buildDropdown("Name of Stakeholder", _stakeholderList, _selectedStakeholderName, (val) => setState(() => _selectedStakeholderName = val), isMandatory: true) 
        else 
          _buildField("Name of Stakeholder", _stkNameController.text, _stkNameController, isEditable: false, isRequired: true),
        
        _buildField("Executive Name", _stkExecController.text, _stkExecController, isEditable: canEdit, isRequired: true),
        _buildField("Contact Number", _stkContactController.text, _stkContactController, isEditable: canEdit, isRequired: true),
        
        if (canEdit) Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Row(children: [Checkbox(value: _sameAsContact, activeColor: Colors.blue, onChanged: (v) { setState(() { _sameAsContact = v!; if(_sameAsContact) _stkWhatsappController.text = _stkContactController.text; }); }), const Text("Same as Contact Number", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold))])),
        
        _buildField("WhatsApp Number", _stkWhatsappController.text, _stkWhatsappController, isEditable: canEdit && !_sameAsContact),
        _buildField("Email ID", _stkEmailController.text, _stkEmailController, isEditable: canEdit),
        
        if (canEdit) 
          _buildDropdown("Valuation Type", _valuationTypes, _selectedValuationType, (val) => setState(() => _selectedValuationType = val)) 
        else 
          _buildField("Valuation Type", _stkValTypeController.text, _stkValTypeController, isEditable: false),
        
        const SizedBox(height: 15),
        const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Divider()),
        const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text("Address Details", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))),
        const SizedBox(height: 10),

        if (canEdit) ...[
           if (_locationNames.isNotEmpty) 
             _buildDropdown("Location", _locationNames, _selectedLocationName, _onLocationSelected, isMandatory: true)
           else 
             _buildField("Location", _stkLocationController.text, _stkLocationController, isEditable: canEdit, isRequired: true),
        ] else ...[
           _buildField("Location", _stkLocationController.text, _stkLocationController, isEditable: false),
        ],

        _buildField("Block / City", _stkBlockController.text, _stkBlockController, isEditable: canEdit),
        _buildField("District", _stkDistrictController.text, _stkDistrictController, isEditable: canEdit),
        _buildField("Division", _stkDivisionController.text, _stkDivisionController, isEditable: canEdit),
        _buildField("State", _stkStateController.text, _stkStateController, isEditable: canEdit),
        _buildField("Country", _stkCountryController.text, _stkCountryController, isEditable: canEdit),
      ], isOpen: true),

      const SizedBox(height: 10),

      _buildSectionContainer("Applicant", [
        _buildField("Applicant Name", _appNameController.text, _appNameController, isEditable: canEdit, isRequired: true),
        _buildField("Applicant Contact", _appContactController.text, _appContactController, isEditable: canEdit, isRequired: true),
      ]),

      const SizedBox(height: 10),

      _buildSectionContainer("Vehicle Details", [
        _buildField("Vehicle Number", _vehNoController.text, _vehNoController, isEditable: canEdit, isRequired: true),
        _buildField("Vehicle Segment", _vehSegController.text, _vehSegController, isEditable: canEdit, isRequired: true),
      ]),

      const SizedBox(height: 10),

      _buildSectionContainer("Remarks", [
        TextField(controller: _stkRemarksController, readOnly: !canEdit, maxLines: 3, decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.all(12))),
      ]),

      const SizedBox(height: 10),

      _buildSectionContainer("Documents", [
        _buildViewDocRow("RC", _getUniversalValue(_stakeholderData, ['rcfile']), 'RC', canEdit),
        _buildViewDocRow("Insurance", _getUniversalValue(_stakeholderData, ['insurancefile']), 'INS', canEdit),
        _buildViewDocRow("Others", _getUniversalValue(_stakeholderData, ['otherfile']), 'OTHER', canEdit),
      ], isOpen: true),

      _buildNotesSection(),
      const SizedBox(height: 20),
      _buildTopActions(canEdit, () => setState(() => _isStakeholderEditing = true), _saveStakeholder),
    ]);
  }

  Widget _buildField(String label, String value, TextEditingController? controller, {bool isEditable = false, Function(String)? onChanged, bool isRequired = false}) {
    Widget labelWidget = RichText(text: TextSpan(text: label, style: TextStyle(color: Colors.grey[600], fontSize: 14), children: [if(isRequired) const TextSpan(text: " *", style: TextStyle(color: Colors.red))]));
    if (isEditable && controller != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), 
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          labelWidget, 
          const SizedBox(height: 6), 
          TextField(controller: controller, onChanged: onChanged, decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12)))
        ])
      );
    } else {
      String displayTxt = controller?.text.isNotEmpty == true ? controller!.text : value;
      return Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(flex: 2, child: labelWidget), Expanded(flex: 3, child: Text(displayTxt.isEmpty ? "-" : displayTxt, style: const TextStyle(fontWeight: FontWeight.w500)))]));
    }
  }

  Widget _buildDropdown(String label, List<String> items, String? value, Function(String?) onChanged, {bool isMandatory = false}) {
    Widget labelWidget = RichText(text: TextSpan(text: label, style: TextStyle(color: Colors.grey[600], fontSize: 14), children: [if(isMandatory) const TextSpan(text: " *", style: TextStyle(color: Colors.red))]));
    return Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [labelWidget, const SizedBox(height: 6), DropdownButtonFormField<String>(value: value, isExpanded: true, decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12)), items: items.map((item) => DropdownMenuItem(value: item, child: Text(item, style: const TextStyle(fontSize: 13)))).toList(), onChanged: onChanged)]));
  }

  Widget _buildSectionContainer(String title, List<Widget> children, {bool isOpen = false}) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade300)),
      child: ExpansionTile(
        initiallyExpanded: isOpen,
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        children: children,
      ),
    );
  }

  Widget _buildViewDocRow(String label, String? url, String type, bool canEdit) { 
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), 
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween, 
        children: [
          Expanded(flex: 2, child: Text(label, style: const TextStyle(fontWeight: FontWeight.w500))), 
          Expanded(
            flex: 3, 
            child: Row(
              children: [
                if (canEdit) ...[
                  ElevatedButton(onPressed: () => _pickFile(type), style: ElevatedButton.styleFrom(minimumSize: const Size(80, 30)), child: const Text("Choose File", style: TextStyle(fontSize: 11))), 
                  const SizedBox(width: 8), 
                  const Text("NO FILE", style: TextStyle(fontSize: 11))
                ] else 
                  GestureDetector(
                    onTap: () => _launchDownload(url), 
                    child: Text(
                      (url != null && url.isNotEmpty && url != "null") ? "Download" : "No Document", 
                      style: TextStyle(
                        color: (url != null && url.isNotEmpty && url != "null") ? Colors.blue : Colors.grey, 
                        fontWeight: FontWeight.bold, 
                        decoration: TextDecoration.underline
                      )
                    )
                  )
              ]
            )
          )
        ]
      )
    ); 
  }

  Widget _buildBackendForm() {
    bool canEdit = _isBackendEditing;
    return Form(key: _backendFormKey, child: Column(children: [
          _buildSectionContainer("Vehicle Information", [
            _buildField("Registration Number*", _regNoController.text, _regNoController, isEditable: canEdit),
            _buildField("Make*", _makeController.text, _makeController, isEditable: canEdit),
            _buildField("Model*", _modelController.text, _modelController, isEditable: canEdit),
            _buildField("Body Type", _bodyTypeController.text, _bodyTypeController, isEditable: canEdit),
            _buildField("Colour", _colorController.text, _colorController, isEditable: canEdit),
            if (canEdit) _buildDropdown("Fuel Type", _fuelTypes, _selectedFuel, (val)=>setState(()=>_selectedFuel=val)) else _buildField("Fuel", _fuelTypeController.text, _fuelTypeController, isEditable: canEdit),
          ], isOpen: true),
          
          _buildSectionContainer("Manufacturing & Engine Details", [
            _buildRow(_buildField("Year of Mfg", _mfgYearController.text, _mfgYearController, isEditable: canEdit), _buildField("Month of Mfg", _mfgMonthController.text, _mfgMonthController, isEditable: canEdit)),
            _buildRow(_buildField("Engine No*", _engineNoController.text, _engineNoController, isEditable: canEdit), _buildField("Chassis No*", _chassisNoController.text, _chassisNoController, isEditable: canEdit)),
            _buildRow(_buildField("Engine CC", _engineCcController.text, _engineCcController, isEditable: canEdit), _buildField("Gross Wt", _grossWeightController.text, _grossWeightController, isEditable: canEdit)),
            _buildField("Seating Capacity", _seatingController.text, _seatingController, isEditable: canEdit)
          ]),

          _buildSectionContainer("Registration & RTO", [
            _buildDateField("Date of Registration", _regDateController, canEdit),
            _buildField("RTO", _rtoController.text, _rtoController, isEditable: canEdit),
            _buildField("Class of Vehicle", _classVehicleController.text, _classVehicleController, isEditable: canEdit),
            _buildField("Category Code", _categoryCodeController.text, _categoryCodeController, isEditable: canEdit),
            _buildField("Norms Type", _normsTypeController.text, _normsTypeController, isEditable: canEdit),
            _buildField("Maker Variant", _makerVariantController.text, _makerVariantController, isEditable: canEdit),
          ]),

          _buildSectionContainer("Owner & Address", [
            _buildRow(_buildField("Owner Name*", _ownerNameController.text, _ownerNameController, isEditable: canEdit), _buildField("Owner Serial No", _ownerSerialController.text, _ownerSerialController, isEditable: canEdit)),
            _buildField("Present Address", _presentAddrController.text, _presentAddrController, isEditable: canEdit),
            _buildField("Permanent Address", _permAddrController.text, _permAddrController, isEditable: canEdit),
            _buildRow(_buildCheckbox("Hypothecation", _isHypothecated, (v)=>setState(()=>_isHypothecated=v!), canEdit), _buildField("Lender", _lenderController.text, _lenderController, isEditable: canEdit))
          ]),

          _buildSectionContainer("Insurance Details", [
            _buildRow(_buildField("Insurer", _insurerController.text, _insurerController, isEditable: canEdit), _buildField("Policy No", _policyNoController.text, _policyNoController, isEditable: canEdit)),
            _buildDateField("Valid Up To", _insuranceValidController, canEdit)
          ]),

          _buildSectionContainer("Permit & Fitness", [
            _buildRow(_buildField("Permit No", _permitNoController.text, _permitNoController, isEditable: canEdit), _buildDateField("Valid Up To", _permitValidController, canEdit)),
            _buildRow(_buildField("Permit Type", _permitTypeController.text, _permitTypeController, isEditable: canEdit), _buildDateField("Issued On", _permitIssuedOnController, canEdit)),
            _buildRow(_buildDateField("Permit From", _permitFromController, canEdit), _buildField("Fitness No", _fitnessNoController.text, _fitnessNoController, isEditable: canEdit)),
            _buildDateField("Fitness Valid To", _fitnessValidController, canEdit)
          ]),

          _buildSectionContainer("Pollution & Tax", [
            _buildRow(_buildField("Pollution No", _pollutionNoController.text, _pollutionNoController, isEditable: canEdit), _buildDateField("Pollution Valid", _pollutionValidController, canEdit)),
            _buildRow(_buildDateField("Tax Up To", _taxValidController, canEdit), _buildDateField("Tax Paid", _taxPaidController, canEdit))
          ]),

          _buildSectionContainer("Additional Info", [
            _buildRow(_buildField("IDV", _idvController.text, _idvController, isEditable: canEdit), _buildField("Ex Showroom", _showroomPriceController.text, _showroomPriceController, isEditable: canEdit)),
            _buildRow(_buildCheckbox("Blacklist Status", _isBlacklisted, (v)=>setState(()=>_isBlacklisted=v!), canEdit), _buildCheckbox("RC Status", _isRcActive, (v)=>setState(()=>_isRcActive=v!), canEdit)),
            _buildDateField("Manufactured Date", _manufacturedDateController, canEdit),
            _buildField("Stencil URL", _stencilUrlController.text, _stencilUrlController, isEditable: canEdit),
            _buildField("Chassis URL", _chassisUrlController.text, _chassisUrlController, isEditable: canEdit),
          ]),

          _buildSectionContainer("Remarks", [
            TextField(controller: _backendRemarksController, readOnly: !canEdit, maxLines: 3, decoration: const InputDecoration(border: OutlineInputBorder(), hintText: "Remarks..."))
          ]),

          _buildSectionContainer("Documents", [
            _buildDocButton("RC", _rcPath, () => _pickFile('RC'), canEdit),
            _buildDocButton("Insurance", _insPath, () => _pickFile('INS'), canEdit),
            _buildDocButton("Other", _otherPath, () => _pickFile('OTHER'), canEdit),
          ]),

          _buildSectionContainer("Assign", [
            if (canEdit) _buildDropdown("Assign To", _assigneeOptions, _selectedAssignee, (v)=>setState(()=>_selectedAssignee=v)) else const Text("Assignment disabled in view mode")
          ]),

          const SizedBox(height: 20),
          _buildTopActions(canEdit, () => setState(() => _isBackendEditing = true), () => _saveBackend(submitAnyway: false)),
    ]));
  }

  Widget _buildAVOInspectionForm() {
    bool canEdit = _isAvoEditing;
    return Column(children: [
      _buildSectionContainer("Inspection Info", [
        _buildRow(_buildField("Inspected By", _inspectedByController.text, _inspectedByController, isEditable: canEdit), _buildDateField("Date", _inspectionDateController, canEdit)),
        _buildField("Location", _locationController.text, _locationController, isEditable: canEdit)
      ], isOpen: true),

      _buildSectionContainer("Basic Checks", [
        _buildRow(_buildField("Veh Moved", _vehicleMovedController.text, _vehicleMovedController, isEditable: canEdit), _buildField("Engine Started", _engineStartedController.text, _engineStartedController, isEditable: canEdit)),
        _buildRow(_buildField("Odometer", _odometerController.text, _odometerController, isEditable: canEdit), _buildField("VIN Plate", _vinPlateController.text, _vinPlateController, isEditable: canEdit)),
        _buildField("Accessories", _accessoryFitmentController.text, _accessoryFitmentController, isEditable: canEdit)
      ]),

      _buildSectionContainer("External Checks", [
        _buildRow(_buildField("Road Worthy", _roadWorthyController.text, _roadWorthyController, isEditable: canEdit), _buildField("Engine Cond", _engineCondController.text, _engineCondController, isEditable: canEdit)),
        _buildRow(_buildField("Suspension", _suspensionController.text, _suspensionController, isEditable: canEdit), _buildField("Steering Wheel", _steeringWheelController.text, _steeringWheelController, isEditable: canEdit)),
        _buildRow(_buildField("Steering Col", _steeringColController.text, _steeringColController, isEditable: canEdit), _buildField("Steering Box", _steeringBoxController.text, _steeringBoxController, isEditable: canEdit)),
        _buildRow(_buildField("Steering Link", _steeringLinkController.text, _steeringLinkController, isEditable: canEdit), _buildField("Fuel System", _fuelSystemController.text, _fuelSystemController, isEditable: canEdit)),
        _buildField("Brake System", _brakeSystemController.text, _brakeSystemController, isEditable: canEdit)
      ]),

      _buildSectionContainer("Structural & Body", [
        _buildRow(_buildField("Chassis Cond", _chassisCondController.text, _chassisCondController, isEditable: canEdit), _buildField("Ext Cond", _extCondController.text, _extCondController, isEditable: canEdit)),
        _buildRow(_buildField("Int Cond", _intCondController.text, _intCondController, isEditable: canEdit), _buildField("Body Cond", _bodyCondController.text, _bodyCondController, isEditable: canEdit)),
        _buildRow(_buildField("Paint", _paintWorkController.text, _paintWorkController, isEditable: canEdit), _buildField("Audio", _audioController.text, _audioController, isEditable: canEdit)),
        _buildRow(_buildField("Clutch", _clutchController.text, _clutchController, isEditable: canEdit), _buildField("Gearbox", _gearboxController.text, _gearboxController, isEditable: canEdit)),
        _buildRow(_buildField("Propeller", _propellerController.text, _propellerController, isEditable: canEdit), _buildField("Mudguards", _mudguardsController.text, _mudguardsController, isEditable: canEdit)),
        _buildRow(_buildField("Glasses", _allGlassesController.text, _allGlassesController, isEditable: canEdit), _buildField("Differential", _diffController.text, _diffController, isEditable: canEdit))
      ]),

      _buildSectionContainer("Interior & Electrical", [
        _buildRow(_buildField("Seats", _seatsController.text, _seatsController, isEditable: canEdit), _buildField("Upholstery", _upholsteryController.text, _upholsteryController, isEditable: canEdit)),
        _buildRow(_buildField("Trims", _intTrimsController.text, _intTrimsController, isEditable: canEdit), _buildField("Front View", _frontViewController.text, _frontViewController, isEditable: canEdit)),
        _buildRow(_buildField("Rear View", _rearViewController.text, _rearViewController, isEditable: canEdit), _buildField("Axles", _axlesController.text, _axlesController, isEditable: canEdit)),
        _buildRow(_buildField("AC", _acController.text, _acController, isEditable: canEdit), _buildField("Radiator", _radiatorController.text, _radiatorController, isEditable: canEdit)),
        _buildField("Hoses", _hoseController.text, _hoseController, isEditable: canEdit)
      ]),

      _buildRemarksSection(canEdit),
      _buildPhotoSection(),
      _buildNotesSection(),
      const SizedBox(height: 20),
      _buildTopActions(canEdit, () => setState(() => _isAvoEditing = true), () => _performAvoUpdate(isSubmit: false), onSubmit: () => _performAvoUpdate(isSubmit: true), onReject: _handleReject),
    ]);
  }

  // Helper for Rows in Forms
  Widget _buildRow(Widget left, Widget right) { return Padding(padding: const EdgeInsets.only(bottom: 0), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: left), Expanded(child: right)])); }
  Widget _buildCheckbox(String label, bool value, Function(bool?) onChanged, bool isEditable) { return Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 14)), Row(children: [Checkbox(value: value, onChanged: isEditable ? onChanged : null, activeColor: Colors.green), Text(value ? "YES" : "NO", style: const TextStyle(fontWeight: FontWeight.bold))])])); }
  Widget _buildDateField(String label, TextEditingController controller, bool isEditable) { return _buildField(label, controller.text, controller, isEditable: isEditable); } 
  Widget _buildDocButton(String label, String? path, VoidCallback onTap, bool canEdit) { return _buildViewDocRow(label, null, 'RC', canEdit); } 
  
  Widget _buildHeaderCard() { 
    return Container(
      padding: const EdgeInsets.all(16), 
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.grey.shade300)), 
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, 
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween, 
            children: [
              const Text("Workflow Status", style: TextStyle(fontWeight: FontWeight.bold)), 
              Text("$_currentTab View", style: const TextStyle(color: Colors.grey))
            ]
          ), 
          const SizedBox(height: 10), 
          RichText(
            text: TextSpan(
              style: const TextStyle(color: Colors.black, fontSize: 13, height: 1.6), 
              children: [
                const TextSpan(text: "Vehicle Number: ", style: TextStyle(fontWeight: FontWeight.bold)), 
                TextSpan(text: "${widget.summaryData['vehicleNumber']} | "), 
                const TextSpan(text: "Status: ", style: TextStyle(fontWeight: FontWeight.bold)), 
                TextSpan(text: "${widget.summaryData['status']}")
              ] 
            )
          ), 
          const SizedBox(height: 12), 
          Row(
            children: [
              _buildTabChip("Stake Holder", _currentTab == "Stakeholder"), 
              const SizedBox(width: 8), 
              _buildTabChip("Backend", _currentTab == "Backend"), 
              const SizedBox(width: 8), 
              _buildTabChip("AVO", _currentTab == "AVO")
            ]
          )
        ]
      )
    ); 
  }
  Widget _buildTabChip(String label, bool active) { return InkWell(onTap: () { setState(() { _currentTab = label; if(label=="Backend") _isBackendEditing=false; if(label=="AVO") _isAvoEditing=false; if(label=="Stakeholder") _isStakeholderEditing=false; }); }, child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: active ? Colors.green : Colors.grey[200], borderRadius: BorderRadius.circular(4)), child: Text(label, style: TextStyle(color: active ? Colors.white : Colors.black, fontWeight: FontWeight.bold, fontSize: 12)))); }
  Widget _buildRemarksSection(bool isEditable) { return _buildSectionContainer("Remarks", [TextField(controller: _remarksController, readOnly: !isEditable, maxLines: 3, decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.all(12)))]); }
  Widget _buildPhotoSection() { return Container(margin: const EdgeInsets.symmetric(vertical: 20), child: ElevatedButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => VehicleMediaPage(valuationId: widget.summaryData['valuationId'] ?? ""))), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3F51B5), foregroundColor: Colors.white), child: const Text("View / Upload Images"))); }
  Widget _buildNotesSection() { return Container(margin: const EdgeInsets.only(bottom: 50), padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.grey.shade300)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text("Inspection Notes (${_notes.length})", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), ElevatedButton(onPressed: _addNote, style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white), child: const Text("+ Add Note"))]), const SizedBox(height: 15), TextField(controller: _noteController, decoration: const InputDecoration(hintText: "Type a new note here...", border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8))), const SizedBox(height: 15), _notes.isEmpty ? const Center(child: Text("No notes yet.", style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic))) : ListView.separated(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: _notes.length, separatorBuilder: (c, i) => const Divider(), itemBuilder: (context, index) { var note = _notes[index]; return ListTile(contentPadding: EdgeInsets.zero, title: Text(note['note'] ?? "", style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)), subtitle: Text("${note['createdBy']} • ${_fmtDate(note['createdDate'])}", style: const TextStyle(fontSize: 11, color: Colors.grey))); })])); }
}