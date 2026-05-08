import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'services/api_service.dart';
import 'vehicle_media_page.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'main.dart';
import 'backend_dashboard.dart';
import 'qc_dashboard.dart';
import 'finalreport_dashboard.dart';

// =============================================================================
// VALUATION-TYPE FIELD VISIBILITY MAP (ported from inspection-update.component.ts)
// =============================================================================
//
// Keys are internal type ids ('four-wheeler', 'cv', ...). Values are field
// names that should be shown for that vehicle type. Anything not in the list
// is hidden. Field names match the WEB PORTAL HTML formControlNames so they
// align with what the backend expects.

const Map<String, List<String>> _avoVisibilityMap = {
  'four-wheeler': [
    'vehicleInspectedBy', 'inspectionDate', 'inspectionLocation', 'frontPhoto', 'odometer',
    'engineCondition', 'chassisCondition', 'steeringSystem', 'brakeSystem', 'suspensionSystem',
    'fuelSystem', 'tyreCondition', 'bodyCondition', 'cabinCondition', 'exteriorCondition',
    'interiorCondition', 'gearboxAssembly', 'clutchSystem', 'driveShafts', 'propellerShaft',
    'differentialAssy', 'radiator', 'interCooler', 'allHosePipes', 'paintWork', 'vinPlate',
    'vehicleMoved', 'engineStarted', 'roadWorthyCondition', 'otherAccessoryFitment',
    'parkingBrake', 'abs', 'tailLightsIndicators', 'wiringAssy',
    'frontCrashGuard', 'rearCrashGuard',
    'airBags', 'sunRoof', 'sideFenders',
  ],
  'cv': [
    'vehicleInspectedBy', 'inspectionDate', 'inspectionLocation', 'frontPhoto', 'odometer',
    'engineCondition', 'chassisCondition', 'steeringSystem', 'brakeSystem', 'electricalSystem',
    'suspensionSystem', 'fuelSystem', 'tyreCondition', 'bodyCondition', 'cabinCondition',
    'exteriorCondition', 'interiorCondition', 'gearboxAssembly', 'clutchSystem', 'propellerShaft',
    'differentialAssy', 'radiator', 'interCooler', 'allHosePipes', 'steeringWheel', 'steeringColumn',
    'steeringBox', 'steeringLinkages', 'bumpers', 'doors', 'mudguards', 'allGlasses', 'dashBoard',
    'seats', 'upholestry', 'interiorTrims', 'front', 'rear', 'axles', 'airConditioner', 'audio',
    'paintWork', 'rightSideWing', 'leftSideWing', 'tailGate', 'loadFloor', 'vinPlate',
    'vehicleMoved', 'engineStarted', 'roadWorthyCondition', 'otherAccessoryFitment',
    'parkingBrake', 'abs', 'tailLightsIndicators', 'wiringAssy',
    'frontCrashGuard', 'rearCrashGuard',
    'hydraulicLift', 'sideUnderRunProtection',
  ],
  'two-wheeler': [
    'vehicleInspectedBy', 'inspectionDate', 'inspectionLocation', 'frontPhoto', 'odometer',
    'engineCondition', 'chassisCondition', 'steeringSystem', 'brakeSystem', 'electricalSystem',
    'suspensionSystem', 'fuelSystem', 'tyreCondition', 'bodyCondition', 'exteriorCondition',
    'gearboxAssembly', 'clutchSystem', 'steeringHandle', 'frontForkAssy', 'mudguards',
    'frontFairing', 'rearCowls', 'seats', 'speedoMeter', 'front', 'rear', 'paintWork',
    'vinPlate', 'vehicleMoved', 'engineStarted', 'roadWorthyCondition', 'otherAccessoryFitment',
    'mainStand', 'sideStand', 'frontMudGuard', 'rearMudGuard', 'fuelTankCondition',
    'chainSprocket', 'frontBrakeCondition', 'rearBrakeCondition', 'headLight', 'tailLight',
    'indicators', 'hornCondition', 'mirrorCondition', 'seatCondition', 'handleBarGrips',
    'footRest', 'alloyWheelRim',
  ],
  'three-wheeler': [
    'vehicleInspectedBy', 'inspectionDate', 'inspectionLocation', 'frontPhoto', 'odometer',
    'engineCondition', 'chassisCondition', 'steeringSystem', 'brakeSystem', 'electricalSystem',
    'suspensionSystem', 'fuelSystem', 'tyreCondition', 'bodyCondition', 'cabinCondition',
    'exteriorCondition', 'interiorCondition', 'gearboxAssembly', 'clutchSystem', 'driveShafts',
    'radiator', 'interCooler', 'allHosePipes', 'steeringColumn', 'steeringBox', 'steeringLinkages',
    'steeringHandle', 'frontForkAssy', 'mudguards', 'allGlasses', 'dashBoard', 'seats',
    'upholestry', 'interiorTrims', 'front', 'rear', 'axles', 'airConditioner', 'audio',
    'paintWork', 'vinPlate', 'vehicleMoved', 'engineStarted', 'roadWorthyCondition',
    'otherAccessoryFitment',
    'parkingBrake', 'abs', 'tailLightsIndicators', 'wiringAssy',
    'frontCrashGuard', 'rearCrashGuard',
  ],
  'tractor': [
    'vehicleInspectedBy', 'inspectionDate', 'inspectionLocation', 'frontPhoto', 'odometer',
    'engineCondition', 'chassisCondition', 'steeringSystem', 'brakeSystem', 'electricalSystem',
    'suspensionSystem', 'fuelSystem', 'tyreCondition', 'bodyCondition', 'exteriorCondition',
    'gearboxAssembly', 'clutchSystem', 'differentialAssy', 'radiator', 'interCooler',
    'allHosePipes', 'steeringWheel', 'steeringColumn', 'steeringBox', 'steeringLinkages',
    'bonnet', 'bumpers', 'mudguards', 'seats', 'front', 'rear', 'axles', 'paintWork',
    'vinPlate', 'vehicleMoved', 'engineStarted', 'roadWorthyCondition', 'otherAccessoryFitment',
    'rightIndividualBrakes', 'leftIndividualBrakes', 'threePointLinkage', 'powerTakeOff',
    'hitchSystem', 'hydraulicLiftFe', 'frontWeights', 'rearWeights', 'ropsCanopy',
    'frontTyreCondition', 'rearTyreCondition', 'implementAttachments', 'fuelTankFe',
    'frontAxleFe', 'rearDrawbar',
  ],
  'ce': [
    'vehicleInspectedBy', 'inspectionDate', 'inspectionLocation', 'frontPhoto', 'odometer',
    'engineCondition', 'chassisCondition', 'steeringSystem', 'brakeSystem', 'electricalSystem',
    'suspensionSystem', 'fuelSystem', 'tyreCondition', 'bodyCondition', 'cabinCondition',
    'exteriorCondition', 'interiorCondition', 'gearboxAssembly', 'clutchSystem', 'radiator',
    'interCooler', 'allHosePipes', 'steeringWheel', 'steeringColumn', 'steeringBox',
    'steeringLinkages', 'bonnet', 'mudguards', 'allGlasses', 'boom', 'bucket', 'chainTrack',
    'hydraulicCylinders', 'swingUnit', 'dashBoard', 'seats', 'upholestry', 'interiorTrims',
    'front', 'rear', 'axles', 'airConditioner', 'paintWork', 'vinPlate', 'vehicleMoved',
    'engineStarted', 'roadWorthyCondition', 'otherAccessoryFitment',
    'retarder', 'differentialLock', 'pto', 'hydraulicSystem', 'boomArm', 'bucketCondition',
    'bladeCondition', 'liftingCapacity', 'tyreConditionCe', 'underCarriage', 'crawlerTracks',
    'steelRims', 'attachmentCondition', 'cabCondition', 'counterWeight', 'rockBreaker',
  ],
  'bus': [
    'vehicleInspectedBy', 'inspectionDate', 'inspectionLocation', 'frontPhoto', 'odometer',
    'engineCondition', 'chassisCondition', 'steeringSystem', 'brakeSystem', 'electricalSystem',
    'suspensionSystem', 'fuelSystem', 'tyreCondition', 'bodyCondition', 'cabinCondition',
    'exteriorCondition', 'interiorCondition', 'gearboxAssembly', 'clutchSystem', 'propellerShaft',
    'differentialAssy', 'radiator', 'interCooler', 'allHosePipes', 'steeringWheel', 'steeringColumn',
    'steeringBox', 'steeringLinkages', 'bumpers', 'doors', 'mudguards', 'allGlasses', 'dashBoard',
    'seats', 'upholestry', 'interiorTrims', 'front', 'rear', 'axles', 'airConditioner', 'audio',
    'paintWork', 'vinPlate', 'vehicleMoved', 'engineStarted', 'roadWorthyCondition',
    'otherAccessoryFitment',
    'parkingBrake', 'abs', 'tailLightsIndicators', 'wiringAssy',
    'frontCrashGuard', 'rearCrashGuard',
    'coachCondition', 'passengerSeats', 'emergencyExits', 'luggageCompartment',
    'acSystem', 'destinationBoard', 'sideMirrors',
  ],
};

// Maps user-friendly display names to internal valuationType keys.
String? _normalizeValuationType(String raw) {
  final lower = raw.trim().toLowerCase();
  if (lower.isEmpty) return null;
  // Already in internal form
  if (_avoVisibilityMap.containsKey(lower)) return lower;
  // Display-name mappings
  if (lower.contains('four') || lower.contains('4-wheel') || lower.contains('4 wheel')) return 'four-wheeler';
  if (lower.contains('commercial')) return 'cv';
  if (lower == 'cv') return 'cv';
  if (lower.contains('two') || lower.contains('2-wheel') || lower.contains('2 wheel')) return 'two-wheeler';
  if (lower.contains('three') || lower.contains('3-wheel') || lower.contains('3 wheel')) return 'three-wheeler';
  if (lower.contains('tractor') || lower == 'fe' || lower.contains('farm')) return 'tractor';
  if (lower.contains('construction') || lower == 'ce') return 'ce';
  if (lower.contains('bus') || lower.contains('coach')) return 'bus';
  return null;
}

// =============================================================================
// AVO DASHBOARD (top-level list)
// =============================================================================

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
  List<dynamic> _cases = [];
  String _selectedSubTab = "All";

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);
    try {
      final all = await _api.getOpenValuations();
      all.sort((a, b) => (b['createdAt'] ?? "").compareTo(a['createdAt'] ?? ""));
      // Filter to AVO/Inspection step only
      final filtered = all.where((c) {
        final wf = (c['workflow'] ?? "").toString().toLowerCase();
        return wf.contains("avo") || wf.contains("inspection");
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
            const Text("ProntoMoto AVO",
                style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18)),
            Text("Hello, ${widget.userName}", style: const TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh, color: Colors.black), onPressed: _loadDashboardData),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.red),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (context.mounted) {
                Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginPage()));
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
        label: Text("$label ($count)",
            style: TextStyle(color: isSelected ? Colors.white : Colors.green, fontWeight: FontWeight.bold)),
        backgroundColor: isSelected ? Colors.green : Colors.green.withOpacity(0.1),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: isSelected ? Colors.green : Colors.transparent)),
      ),
    );
  }

  Widget _buildCard(Map<String, dynamic> item) {
    String plate = item['vehicleNumber'] ?? "Unknown";
    String location = item['location'] ?? "Unknown";
    String applicant = item['applicantName'] ?? "Unknown";
    String workflow = item['workflow'] ?? "AVO";
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
    Color bgAgeColor = daysOld <= 1 ? Colors.green.shade50 : daysOld == 2 ? Colors.orange.shade50 : Colors.red.shade50;

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
                      decoration: BoxDecoration(
                          color: Colors.blueGrey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.blueGrey.shade200)),
                      child: Text(workflow,
                          style: const TextStyle(fontSize: 10, color: Colors.blueGrey, fontWeight: FontWeight.bold)),
                    ),
                    if (redFlag) ...[const SizedBox(width: 6), const Text("⚑", style: TextStyle(color: Colors.red, fontSize: 14))],
                    if (itemStatus.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Text(itemStatus,
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isReturned ? Colors.red : Colors.blueGrey))
                    ],
                  ]),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: bgAgeColor, borderRadius: BorderRadius.circular(4)),
                  child: Text("TAT: ${daysOld}d",
                      style: TextStyle(color: ageColor, fontSize: 10, fontWeight: FontWeight.bold)),
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

// =============================================================================
// INSPECTION FORM PAGE — AVO detail screen
// =============================================================================

class InspectionFormPage extends StatefulWidget {
  final Map<String, dynamic> summaryData;
  final String initialTab;
  const InspectionFormPage({super.key, required this.summaryData, this.initialTab = "AVO"});

  @override
  State<InspectionFormPage> createState() => _InspectionFormPageState();
}

class _InspectionFormPageState extends State<InspectionFormPage> {
  final ApiService api = ApiService();
  final _backendFormKey = GlobalKey<FormState>();
  final _avoFormKey = GlobalKey<FormState>();
  bool _isLoading = true;

  bool _isAvoEditing = false;
  bool _isBackendEditing = false;
  bool _isStakeholderEditing = false;

  bool _isSaving = false;
  bool _isSubmitting = false;
  bool _isReturning = false;

  bool _sameAsContact = false;

  String _currentTab = "AVO";

  Map<String, dynamic> _avoData = {};
  Map<String, dynamic> _stakeholderData = {};
  Map<String, dynamic> _backendData = {};
  Map<String, dynamic> _paymentData = {};
  Map<String, dynamic> _workflowTable = {};

  List<dynamic> _notes = [];

  String? _returnedBy;
  String? _returnMessage;

  // valuationType — used for showField visibility map
  String? _valuationTypeKey; // 'four-wheeler' / 'cv' / 'two-wheeler' / 'three-wheeler' / 'tractor' / 'ce'

  String? _selectedAssignee;
  final List<String> _assigneeOptions = [
    "SHEKHAR — +919885255567",
    "FinalReport — +919885855567"
  ];

  final List<String> _stakeholderList = [
    "State Bank of India (SBI)", "HDFC Bank", "ICICI Bank", "Axis Bank", "IndusInd Bank",
    "Punjab National Bank (PNB)", "Federal Bank", "Union Bank of India", "Bank of Baroda",
    "IDFC FIRST Bank", "Karur Vysya Bank", "Kotak Mahindra Bank", "Mahindra Finance",
    "Bajaj Finserv", "Hero FinCorp", "TVS Credit Services", "Shriram Finance",
    "Muthoot Capital Services", "Cholamandalam Investment and Finance Company",
    "Sundaram Finance", "Manappuram Finance", "L&T Finance"
  ];
  final List<String> _valuationTypes = [
    "Four Wheeler", "Commercial Vehicle", "Two Wheeler", "Three Wheeler", "Tractor", "Construction Equipment"
  ];
  final List<String> _fuelTypes = ["Petrol", "Diesel", "CNG", "Electric", "Hybrid", "LPG"];

  // Payment dropdown options
  final List<String> _paymentStatuses = ["Pending", "Completed", "Failed"];
  final List<String> _paymentMethods = ["Online", "Cash", "Card", "UPI"];

  List<dynamic> _pincodeLocations = [];
  List<String> _locationNames = [];
  String? _selectedLocationName;
  String? _selectedStakeholderName;
  String? _selectedValuationType;
  String? _selectedFuel;

  String? _selectedPaymentStatus;
  String? _selectedPaymentMethod;

  String? _rcPath;
  String? _insPath;
  String? _otherPath;

  bool _isHypothecated = false;
  bool _isBlacklisted = false;
  bool _isRcActive = false;

  // Stakeholder controllers
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

  // ===========================================================================
  // AVO INSPECTION CONTROLLERS — keys match web portal HTML formControlName
  // ===========================================================================

  // Inspection Info
  final _vehicleInspectedByController = TextEditingController();
  final _dateOfInspectionController = TextEditingController();
  final _inspectionLocationController = TextEditingController();

  // Basic Vehicle Checks (mostly bool dropdowns, plus a couple text)
  final _vehicleMovedController = TextEditingController();         // bool: Yes/No
  final _engineStartedController = TextEditingController();        // bool: Yes/No
  final _odometerController = TextEditingController();             // number
  final _vinPlateController = TextEditingController();             // bool: Yes/No
  final _bodyTypeController = TextEditingController();             // free text
  final _overallTyreConditionController = TextEditingController(); // dropdown: Good/Not Good (but stores as bool string)
  final _otherAccessoryFitmentController = TextEditingController();// bool: Yes/No

  // External Visual Checks
  final _windshieldGlassController = TextEditingController();      // free text
  final _roadWorthyConditionController = TextEditingController();  // bool: OK/Not OK
  final _engineConditionController = TextEditingController();      // dropdown: Good/Not Good
  final _suspensionSystemController = TextEditingController();     // dropdown: Good/Not Good
  final _steeringSystemController = TextEditingController();       // dropdown: Good/Not Good
  final _steeringWheelController = TextEditingController();        // free text
  final _steeringColumnController = TextEditingController();       // free text
  final _steeringBoxController = TextEditingController();          // free text
  final _steeringLinkagesController = TextEditingController();     // free text
  final _fuelSystemController = TextEditingController();           // free text
  final _brakeSystemController = TextEditingController();          // dropdown: Good/Not Good

  // Structural & Body
  final _chassisConditionController = TextEditingController();     // dropdown: Good/Not Good
  final _exteriorConditionController = TextEditingController();    // free text
  final _interiorConditionController = TextEditingController();    // free text
  final _bonnetController = TextEditingController();               // free text
  final _bodyConditionController = TextEditingController();        // free text
  final _batteryConditionController = TextEditingController();     // free text
  final _paintWorkController = TextEditingController();            // dropdown: Good/Not Good
  final _audioController = TextEditingController();                // free text
  final _clutchSystemController = TextEditingController();         // dropdown: Good/Not Good
  final _gearboxAssemblyController = TextEditingController();      // dropdown: Good/Not Good (was gearBoxAssy)
  final _propellerShaftController = TextEditingController();       // dropdown: Good/Not Good
  final _mudguardsController = TextEditingController();            // free text
  final _allGlassesController = TextEditingController();           // free text
  final _boomController = TextEditingController();                 // CE only
  final _bucketController = TextEditingController();               // CE only
  final _chainTrackController = TextEditingController();           // CE only
  final _hydraulicCylindersController = TextEditingController();   // CE only
  final _swingUnitController = TextEditingController();            // CE only
  final _differentialAssyController = TextEditingController();     // dropdown: Good/Not Good

  // Interior & Electrical
  final _cabinController = TextEditingController();
  final _dashboardController = TextEditingController();
  final _seatsController = TextEditingController();
  final _upholestryController = TextEditingController();
  final _interiorTrimsController = TextEditingController();
  final _headLampsController = TextEditingController();
  final _frontController = TextEditingController();                // "Front View"
  final _rearController = TextEditingController();                 // "Rear View"
  final _axlesController = TextEditingController();
  final _airConditionerController = TextEditingController();
  final _electricAssemblyController = TextEditingController();
  final _radiatorController = TextEditingController();
  final _intercoolerController = TextEditingController();
  final _allHosePipesController = TextEditingController();

  // Additional fields from Excel spec
  final _speedoMeterController = TextEditingController();
  final _frontAxlesController = TextEditingController();
  final _rearAxlesController = TextEditingController();
  final _driveShaftsController = TextEditingController();
  final _steeringHandleController = TextEditingController();
  final _frontForkAssyController = TextEditingController();
  final _frontFairingController = TextEditingController();
  final _rearCowlsController = TextEditingController();
  final _bumpersController = TextEditingController();
  final _doorsController = TextEditingController();
  final _fendersController = TextEditingController();
  final _rightSideWingController = TextEditingController();
  final _leftSideWingController = TextEditingController();
  final _tailGateController = TextEditingController();
  final _loadFloorController = TextEditingController();

  // Brakes Additional
  final _parkingBrakeController = TextEditingController();
  final _absController = TextEditingController();

  // Electrical Additional
  final _tailLightsIndicatorsController = TextEditingController();
  final _wiringAssyController = TextEditingController();

  // Crash Guards
  final _frontCrashGuardController = TextEditingController();
  final _rearCrashGuardController = TextEditingController();

  // 4W Specific
  final _airBagsController = TextEditingController();
  final _sunRoofController = TextEditingController();
  final _sideFendersController = TextEditingController();

  // CV Specific
  final _hydraulicLiftController = TextEditingController();
  final _sideUnderRunProtectionController = TextEditingController();

  // 2W Specific
  final _mainStandController = TextEditingController();
  final _sideStandController = TextEditingController();
  final _frontMudGuardController = TextEditingController();
  final _rearMudGuardController = TextEditingController();
  final _fuelTankConditionController = TextEditingController();
  final _chainSprocketController = TextEditingController();
  final _frontBrakeConditionController = TextEditingController();
  final _rearBrakeConditionController = TextEditingController();
  final _headLightController = TextEditingController();
  final _tailLightController = TextEditingController();
  final _indicatorsController = TextEditingController();
  final _hornConditionController = TextEditingController();
  final _mirrorConditionController = TextEditingController();
  final _seatConditionController = TextEditingController();
  final _handleBarGripsController = TextEditingController();
  final _footRestController = TextEditingController();
  final _alloyWheelRimController = TextEditingController();

  // CE Specific
  final _retarderController = TextEditingController();
  final _differentialLockController = TextEditingController();
  final _ptoController = TextEditingController();
  final _hydraulicSystemController = TextEditingController();
  final _boomArmController = TextEditingController();
  final _bucketConditionController = TextEditingController();
  final _bladeConditionController = TextEditingController();
  final _liftingCapacityController = TextEditingController();
  final _tyreConditionCeController = TextEditingController();
  final _underCarriageController = TextEditingController();
  final _crawlerTracksController = TextEditingController();
  final _steelRimsController = TextEditingController();
  final _attachmentConditionController = TextEditingController();
  final _cabConditionController = TextEditingController();
  final _counterWeightController = TextEditingController();
  final _rockBreakerController = TextEditingController();

  // BUS Specific
  final _coachConditionController = TextEditingController();
  final _passengerSeatsController = TextEditingController();
  final _emergencyExitsController = TextEditingController();
  final _luggageCompartmentController = TextEditingController();
  final _acSystemController = TextEditingController();
  final _destinationBoardController = TextEditingController();
  final _sideMirrorsController = TextEditingController();

  // FE Specific
  final _rightIndividualBrakesController = TextEditingController();
  final _leftIndividualBrakesController = TextEditingController();
  final _threePointLinkageController = TextEditingController();
  final _powerTakeOffController = TextEditingController();
  final _hitchSystemController = TextEditingController();
  final _hydraulicLiftFeController = TextEditingController();
  final _frontWeightsController = TextEditingController();
  final _rearWeightsController = TextEditingController();
  final _ropsCanopyController = TextEditingController();
  final _frontTyreConditionController = TextEditingController();
  final _rearTyreConditionController = TextEditingController();
  final _implementAttachmentsController = TextEditingController();
  final _fuelTankFeController = TextEditingController();
  final _frontAxleFeController = TextEditingController();
  final _rearDrawbarController = TextEditingController();

  final _remarksController = TextEditingController();
  final _noteController = TextEditingController();

  // Payment controllers
  final _paymentReferenceController = TextEditingController();
  final _paymentDateController = TextEditingController();
  final _paymentAmountController = TextEditingController(text: '800');

  // Backend vehicle controllers (unchanged)
  final _regNoController = TextEditingController();
  final _makeController = TextEditingController();
  final _modelController = TextEditingController();
  final _bodyTypeBkController = TextEditingController();
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
    _currentTab = widget.initialTab;
    _stkContactController.addListener(() {
      if (_sameAsContact) _stkWhatsappController.text = _stkContactController.text;
    });
    _stkPinController.addListener(() {
      if (_stkPinController.text.length == 6) _fetchLocationsForPincode(_stkPinController.text);
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
      var payment = await api.getPayment(id);
      var workflowTable = await api.getWorkflowTable(id, vNo, contact);

      if (mounted) {
        setState(() {
          _avoData = avo;
          _stakeholderData = stk;
          _backendData = bck;
          _notes = notes;
          _paymentData = payment;
          _workflowTable = workflowTable;

          Map<String, dynamic> merged = {};
          merged.addAll(widget.summaryData);
          merged.addAll(_stakeholderData);
          merged.addAll(_backendData);

          // Derive valuationType from data — used by showField.
          // Could come from many sources; check stakeholder + summary first.
          final rawType = _getUniversalValue(merged, ['valuationType', 'ValuationType', 'Type']);
          _valuationTypeKey = _normalizeValuationType(rawType);

          _populateStakeholderFields(merged);
          _populateAVOFields(_avoData.isNotEmpty ? _avoData : merged);
          _populateBackendFields(_backendData);
          _populatePaymentFields(_paymentData);
          _checkReturnStatus(_workflowTable);

          if (_stkPinController.text.length == 6) _fetchLocationsForPincode(_stkPinController.text);

          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Visibility check — gates AVO inspection fields only.
  bool _showField(String key) {
    if (_valuationTypeKey == null) return true; // unknown type → show everything
    return _avoVisibilityMap[_valuationTypeKey]?.contains(key) ?? false;
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
              if (k.toString().toLowerCase() == part.toLowerCase()) {
                match = k;
                break;
              }
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
      for (var k in data.keys) {
        if (k.toLowerCase() == key.toLowerCase()) {
          var val = data[k];
          if (val != null && val.toString() != "null" && val.toString().isNotEmpty) return val.toString();
        }
      }
    }
    return "";
  }

  // Bool-as-string normalizer. Reads any input ("true"/"YES"/"1"/"Good"/"OK"/etc.)
  // and returns canonical "true" / "false" strings (or empty for unset).
  String _toBoolStr(dynamic v) {
    if (v == null) return "";
    final s = v.toString().trim().toLowerCase();
    if (s.isEmpty || s == "null") return "";
    if (s == "true" || s == "yes" || s == "1" || s == "good" || s == "ok") return "true";
    if (s == "false" || s == "no" || s == "0" || s == "not good" || s == "not ok") return "false";
    return "";
  }

  String _fmtDate(String s) {
    if (s.isEmpty || s == "null") return "";
    try {
      return DateFormat('yyyy-MM-dd').format(DateTime.parse(s));
    } catch (e) {
      return s.split("T")[0];
    }
  }

  Future<void> _fetchLocationsForPincode(String val) async {
    try {
      final data = await api.lookupPincode(val);
      if (data.isNotEmpty && mounted) {
        setState(() {
          _pincodeLocations = data;
          _locationNames = data.map((e) => e['name'].toString()).toSet().toList();
          if (_selectedLocationName != null && !_locationNames.contains(_selectedLocationName)) {
            _selectedLocationName = null;
          }
        });
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
    _stkContactController.text =
        _getUniversalValue(data, ['executiveContact', 'contactNumber', 'Mobile', 'ExecutiveContact']);
    _stkWhatsappController.text =
        _getUniversalValue(data, ['executiveWhatsapp', 'whatsappNumber', 'ExecutiveWhatsapp']);
    _stkEmailController.text = _getUniversalValue(data, ['executiveEmail', 'email', 'ExecutiveEmail']);

    if (_stkContactController.text.isNotEmpty && _stkContactController.text == _stkWhatsappController.text) {
      _sameAsContact = true;
    }

    String valType = _getUniversalValue(data, ['valuationType', 'Type', 'ValuationType']);
    if (_valuationTypes.contains(valType)) _selectedValuationType = valType;
    _stkValTypeController.text = valType;

    _stkPinController.text =
        _getUniversalValue(data, ['vehicleLocation.pincode', 'pincode', 'Pin', 'Pincode']);
    String locName =
        _getUniversalValue(data, ['vehicleLocation.name', 'locationName', 'location', 'LocationName']);
    _stkLocationController.text = locName;
    _selectedLocationName = locName.isNotEmpty ? locName : null;

    _stkBlockController.text =
        _getUniversalValue(data, ['vehicleLocation.block', 'block', 'city', 'City', 'Block']);
    _stkDistrictController.text = _getUniversalValue(data, ['vehicleLocation.district', 'district', 'District']);
    _stkDivisionController.text = _getUniversalValue(data, ['vehicleLocation.division', 'division', 'Division']);
    _stkStateController.text = _getUniversalValue(data, ['vehicleLocation.state', 'state', 'State']);
    _stkCountryController.text = _getUniversalValue(data, ['vehicleLocation.country', 'country', 'Country']);

    _appNameController.text = _getUniversalValue(data, ['applicant.name', 'applicantName', 'ApplicantName']);
    _appContactController.text =
        _getUniversalValue(data, ['applicant.contact', 'applicantContact', 'ApplicantContact']);

    _vehNoController.text = _getUniversalValue(data, ['vehicleNumber', 'VehicleNumber']);
    _vehSegController.text = _getUniversalValue(data, ['vehicleSegment', 'VehicleSegment']);

    _stkRemarksController.text = _getUniversalValue(data, ['remarks', 'Remarks']);
  }

  // Populate AVO controllers — keys match web portal HTML formControlName.
  // For bool fields stores "true"/"false" so the dropdown can directly bind.
  void _populateAVOFields(Map<String, dynamic> data) {
    _vehicleInspectedByController.text =
        _getUniversalValue(data, ['vehicleInspectedBy', 'VehicleInspectedBy', 'executiveName']);
    _dateOfInspectionController.text = _fmtDate(_getUniversalValue(data, ['dateOfInspection', 'createdAt']));
    _inspectionLocationController.text = _getUniversalValue(data, ['inspectionLocation', 'location']);

    // Bool fields
    _vehicleMovedController.text = _toBoolStr(_getUniversalValue(data, ['vehicleMoved']));
    _engineStartedController.text = _toBoolStr(_getUniversalValue(data, ['engineStarted']));
    _vinPlateController.text = _toBoolStr(_getUniversalValue(data, ['vinPlate']));
    _otherAccessoryFitmentController.text = _toBoolStr(_getUniversalValue(data, ['otherAccessoryFitment']));
    _roadWorthyConditionController.text = _toBoolStr(_getUniversalValue(data, ['roadWorthyCondition']));

    // "Pseudo-bool" fields — UI is dropdown but model is string.
    // Stored as "true"/"false" in controllers; sent to server as-is.
    _overallTyreConditionController.text = _toBoolStr(_getUniversalValue(data, ['overallTyreCondition', 'tyreCondition']));
    _engineConditionController.text = _toBoolStr(_getUniversalValue(data, ['engineCondition']));
    _suspensionSystemController.text = _toBoolStr(_getUniversalValue(data, ['suspensionSystem']));
    _steeringSystemController.text = _toBoolStr(_getUniversalValue(data, ['steeringSystem', 'steeringAssy']));
    _brakeSystemController.text = _toBoolStr(_getUniversalValue(data, ['brakeSystem']));
    _chassisConditionController.text = _toBoolStr(_getUniversalValue(data, ['chassisCondition']));
    _paintWorkController.text = _toBoolStr(_getUniversalValue(data, ['paintWork']));
    _clutchSystemController.text = _toBoolStr(_getUniversalValue(data, ['clutchSystem']));
    _gearboxAssemblyController.text = _toBoolStr(_getUniversalValue(data, ['gearboxAssembly', 'gearBoxAssy']));
    _propellerShaftController.text = _toBoolStr(_getUniversalValue(data, ['propellerShaft']));
    _differentialAssyController.text = _toBoolStr(_getUniversalValue(data, ['differentialAssy']));

    // Number
    _odometerController.text = _getUniversalValue(data, ['odometer']);

    // Free text
    _bodyTypeController.text = _getUniversalValue(data, ['bodyType']);
    _windshieldGlassController.text = _getUniversalValue(data, ['windshieldGlass']);
    _steeringWheelController.text = _getUniversalValue(data, ['steeringWheel']);
    _steeringColumnController.text = _getUniversalValue(data, ['steeringColumn']);
    _steeringBoxController.text = _getUniversalValue(data, ['steeringBox']);
    _steeringLinkagesController.text = _getUniversalValue(data, ['steeringLinkages']);
    _fuelSystemController.text = _getUniversalValue(data, ['fuelSystem']);
    _exteriorConditionController.text = _getUniversalValue(data, ['exteriorCondition']);
    _interiorConditionController.text = _getUniversalValue(data, ['interiorCondition']);
    _bonnetController.text = _getUniversalValue(data, ['bonnet']);
    _bodyConditionController.text = _getUniversalValue(data, ['bodyCondition']);
    _batteryConditionController.text = _getUniversalValue(data, ['batteryCondition']);
    _audioController.text = _getUniversalValue(data, ['audio']);
    _mudguardsController.text = _getUniversalValue(data, ['mudguards']);
    _allGlassesController.text = _getUniversalValue(data, ['allGlasses']);
    _boomController.text = _getUniversalValue(data, ['boom']);
    _bucketController.text = _getUniversalValue(data, ['bucket']);
    _chainTrackController.text = _getUniversalValue(data, ['chainTrack']);
    _hydraulicCylindersController.text = _getUniversalValue(data, ['hydraulicCylinders']);
    _swingUnitController.text = _getUniversalValue(data, ['swingUnit']);
    _cabinController.text = _getUniversalValue(data, ['cabin']);
    _dashboardController.text = _getUniversalValue(data, ['dashboard']);
    _seatsController.text = _getUniversalValue(data, ['seats']);
    _upholestryController.text = _getUniversalValue(data, ['upholestry', 'upholstery']);
    _interiorTrimsController.text = _getUniversalValue(data, ['interiorTrims']);
    _headLampsController.text = _getUniversalValue(data, ['headLamps']);
    _frontController.text = _getUniversalValue(data, ['front', 'frontFairing']);
    _rearController.text = _getUniversalValue(data, ['rear', 'rearCowls']);
    _axlesController.text = _getUniversalValue(data, ['axles', 'frontAxles']);
    _airConditionerController.text = _getUniversalValue(data, ['airConditioner']);
    _electricAssemblyController.text = _getUniversalValue(data, ['electricAssembly']);
    _radiatorController.text = _getUniversalValue(data, ['radiator']);
    _intercoolerController.text = _getUniversalValue(data, ['intercooler', 'interCooler']);
    _allHosePipesController.text = _getUniversalValue(data, ['allHosePipes']);

    // Additional existing fields (already in backend model)
    _speedoMeterController.text = _getUniversalValue(data, ['speedoMeter', 'SpeedoMeter']);
    _frontAxlesController.text = _getUniversalValue(data, ['frontAxles', 'FrontAxles']);
    _rearAxlesController.text = _getUniversalValue(data, ['rearAxles', 'RearAxles']);
    _driveShaftsController.text = _getUniversalValue(data, ['driveShafts', 'DriveShafts']);
    _steeringHandleController.text = _getUniversalValue(data, ['steeringHandle', 'SteeringHandle']);
    _frontForkAssyController.text = _getUniversalValue(data, ['frontForkAssy', 'FrontForkAssy']);
    _frontFairingController.text = _getUniversalValue(data, ['frontFairing', 'FrontFairing']);
    _rearCowlsController.text = _getUniversalValue(data, ['rearCowls', 'RearCowls']);
    _bumpersController.text = _getUniversalValue(data, ['bumpers', 'Bumpers']);
    _doorsController.text = _getUniversalValue(data, ['doors', 'Doors']);
    _fendersController.text = _getUniversalValue(data, ['fenders', 'Fenders']);
    _rightSideWingController.text = _getUniversalValue(data, ['rightSideWing', 'RightSideWing']);
    _leftSideWingController.text = _getUniversalValue(data, ['leftSideWing', 'LeftSideWing']);
    _tailGateController.text = _getUniversalValue(data, ['tailGate', 'TailGate']);
    _loadFloorController.text = _getUniversalValue(data, ['loadFloor', 'LoadFloor']);

    // Brakes Additional
    _parkingBrakeController.text = _getUniversalValue(data, ['parkingBrake', 'ParkingBrake']);
    _absController.text = _getUniversalValue(data, ['abs', 'Abs']);

    // Electrical Additional
    _tailLightsIndicatorsController.text = _getUniversalValue(data, ['tailLightsIndicators', 'TailLightsIndicators']);
    _wiringAssyController.text = _getUniversalValue(data, ['wiringAssy', 'WiringAssy']);

    // Crash Guards
    _frontCrashGuardController.text = _getUniversalValue(data, ['frontCrashGuard', 'FrontCrashGuard']);
    _rearCrashGuardController.text = _getUniversalValue(data, ['rearCrashGuard', 'RearCrashGuard']);

    // 4W Specific
    _airBagsController.text = _getUniversalValue(data, ['airBags', 'AirBags']);
    _sunRoofController.text = _getUniversalValue(data, ['sunRoof', 'SunRoof']);
    _sideFendersController.text = _getUniversalValue(data, ['sideFenders', 'SideFenders']);

    // CV Specific
    _hydraulicLiftController.text = _getUniversalValue(data, ['hydraulicLift', 'HydraulicLift']);
    _sideUnderRunProtectionController.text = _getUniversalValue(data, ['sideUnderRunProtection', 'SideUnderRunProtection']);

    // 2W Specific
    _mainStandController.text = _getUniversalValue(data, ['mainStand', 'MainStand']);
    _sideStandController.text = _getUniversalValue(data, ['sideStand', 'SideStand']);
    _frontMudGuardController.text = _getUniversalValue(data, ['frontMudGuard', 'FrontMudGuard']);
    _rearMudGuardController.text = _getUniversalValue(data, ['rearMudGuard', 'RearMudGuard']);
    _fuelTankConditionController.text = _getUniversalValue(data, ['fuelTankCondition', 'FuelTankCondition']);
    _chainSprocketController.text = _getUniversalValue(data, ['chainSprocket', 'ChainSprocket']);
    _frontBrakeConditionController.text = _getUniversalValue(data, ['frontBrakeCondition', 'FrontBrakeCondition']);
    _rearBrakeConditionController.text = _getUniversalValue(data, ['rearBrakeCondition', 'RearBrakeCondition']);
    _headLightController.text = _getUniversalValue(data, ['headLight', 'HeadLight']);
    _tailLightController.text = _getUniversalValue(data, ['tailLight', 'TailLight']);
    _indicatorsController.text = _getUniversalValue(data, ['indicators', 'Indicators']);
    _hornConditionController.text = _getUniversalValue(data, ['hornCondition', 'HornCondition']);
    _mirrorConditionController.text = _getUniversalValue(data, ['mirrorCondition', 'MirrorCondition']);
    _seatConditionController.text = _getUniversalValue(data, ['seatCondition', 'SeatCondition']);
    _handleBarGripsController.text = _getUniversalValue(data, ['handleBarGrips', 'HandleBarGrips']);
    _footRestController.text = _getUniversalValue(data, ['footRest', 'FootRest']);
    _alloyWheelRimController.text = _getUniversalValue(data, ['alloyWheelRim', 'AlloyWheelRim']);

    // CE Specific
    _retarderController.text = _getUniversalValue(data, ['retarder', 'Retarder']);
    _differentialLockController.text = _getUniversalValue(data, ['differentialLock', 'DifferentialLock']);
    _ptoController.text = _getUniversalValue(data, ['pto', 'Pto']);
    _hydraulicSystemController.text = _getUniversalValue(data, ['hydraulicSystem', 'HydraulicSystem']);
    _boomArmController.text = _getUniversalValue(data, ['boomArm', 'BoomArm']);
    _bucketConditionController.text = _getUniversalValue(data, ['bucketCondition', 'BucketCondition']);
    _bladeConditionController.text = _getUniversalValue(data, ['bladeCondition', 'BladeCondition']);
    _liftingCapacityController.text = _getUniversalValue(data, ['liftingCapacity', 'LiftingCapacity']);
    _tyreConditionCeController.text = _getUniversalValue(data, ['tyreConditionCe', 'TyreConditionCe']);
    _underCarriageController.text = _getUniversalValue(data, ['underCarriage', 'UnderCarriage']);
    _crawlerTracksController.text = _getUniversalValue(data, ['crawlerTracks', 'CrawlerTracks']);
    _steelRimsController.text = _getUniversalValue(data, ['steelRims', 'SteelRims']);
    _attachmentConditionController.text = _getUniversalValue(data, ['attachmentCondition', 'AttachmentCondition']);
    _cabConditionController.text = _getUniversalValue(data, ['cabCondition', 'CabCondition']);
    _counterWeightController.text = _getUniversalValue(data, ['counterWeight', 'CounterWeight']);
    _rockBreakerController.text = _getUniversalValue(data, ['rockBreaker', 'RockBreaker']);

    // BUS Specific
    _coachConditionController.text = _getUniversalValue(data, ['coachCondition', 'CoachCondition']);
    _passengerSeatsController.text = _getUniversalValue(data, ['passengerSeats', 'PassengerSeats']);
    _emergencyExitsController.text = _getUniversalValue(data, ['emergencyExits', 'EmergencyExits']);
    _luggageCompartmentController.text = _getUniversalValue(data, ['luggageCompartment', 'LuggageCompartment']);
    _acSystemController.text = _getUniversalValue(data, ['acSystem', 'AcSystem']);
    _destinationBoardController.text = _getUniversalValue(data, ['destinationBoard', 'DestinationBoard']);
    _sideMirrorsController.text = _getUniversalValue(data, ['sideMirrors', 'SideMirrors']);

    // FE Specific
    _rightIndividualBrakesController.text = _getUniversalValue(data, ['rightIndividualBrakes', 'RightIndividualBrakes']);
    _leftIndividualBrakesController.text = _getUniversalValue(data, ['leftIndividualBrakes', 'LeftIndividualBrakes']);
    _threePointLinkageController.text = _getUniversalValue(data, ['threePointLinkage', 'ThreePointLinkage']);
    _powerTakeOffController.text = _getUniversalValue(data, ['powerTakeOff', 'PowerTakeOff']);
    _hitchSystemController.text = _getUniversalValue(data, ['hitchSystem', 'HitchSystem']);
    _hydraulicLiftFeController.text = _getUniversalValue(data, ['hydraulicLiftFe', 'HydraulicLiftFe']);
    _frontWeightsController.text = _getUniversalValue(data, ['frontWeights', 'FrontWeights']);
    _rearWeightsController.text = _getUniversalValue(data, ['rearWeights', 'RearWeights']);
    _ropsCanopyController.text = _getUniversalValue(data, ['ropsCanopy', 'RopsCanopy']);
    _frontTyreConditionController.text = _getUniversalValue(data, ['frontTyreCondition', 'FrontTyreCondition']);
    _rearTyreConditionController.text = _getUniversalValue(data, ['rearTyreCondition', 'RearTyreCondition']);
    _implementAttachmentsController.text = _getUniversalValue(data, ['implementAttachments', 'ImplementAttachments']);
    _fuelTankFeController.text = _getUniversalValue(data, ['fuelTankFe', 'FuelTankFe']);
    _frontAxleFeController.text = _getUniversalValue(data, ['frontAxleFe', 'FrontAxleFe']);
    _rearDrawbarController.text = _getUniversalValue(data, ['rearDrawbar', 'RearDrawbar']);

    _remarksController.text = _getUniversalValue(data, ['remarks']);
  }

  void _populatePaymentFields(Map<String, dynamic> data) {
    String pStatus = _getUniversalValue(data, ['paymentStatus']);
    _selectedPaymentStatus = _paymentStatuses.contains(pStatus) ? pStatus : 'Pending';

    String pMethod = _getUniversalValue(data, ['paymentMethod']);
    _selectedPaymentMethod = _paymentMethods.contains(pMethod) ? pMethod : 'Online';

    _paymentReferenceController.text = _getUniversalValue(data, ['paymentReference']);
    _paymentDateController.text = _fmtDate(_getUniversalValue(data, ['paymentDate']));

    String pAmount = _getUniversalValue(data, ['paymentAmount']);
    _paymentAmountController.text = pAmount.isNotEmpty ? pAmount : '800';
  }

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
    final isAVOStep = currentStep == 'AVO';

    if (!isRedFlag || remark.isEmpty || !isAVOStep) {
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

        const invalidReturners = ['AVO', 'STAKEHOLDER'];
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

  void _populateBackendFields(Map<String, dynamic> data) {
    _regNoController.text = _getUniversalValue(data, ['registrationNumber']);
    _makeController.text = _getUniversalValue(data, ['make']);
    _modelController.text = _getUniversalValue(data, ['model']);
    _bodyTypeBkController.text = _getUniversalValue(data, ['bodyType']);
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

    _isHypothecated = _getUniversalValue(data, ['hypothecation']).toLowerCase() == "true";
    _isRcActive = _getUniversalValue(data, ['rcStatus']).toLowerCase() == "true";
    _isBlacklisted = _getUniversalValue(data, ['backlistStatus']).toLowerCase() == "true";

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

  Map<String, String> _getSafeContext() {
    Map<String, dynamic> d = <String, dynamic>{
      ...widget.summaryData,
      ..._stakeholderData,
      ..._backendData,
      ..._avoData
    };

    String id = widget.summaryData['valuationId']?.toString() ??
        widget.summaryData['id']?.toString() ?? "";

    String vNo = _vehNoController.text.trim();
    if (vNo.isEmpty) vNo = _getUniversalValue(d, ['VehicleNumber', 'vehicleNumber', 'registrationNumber']);
    if (vNo.isEmpty) vNo = "UNKNOWN";

    String contact = _appContactController.text.trim();
    if (contact.isEmpty) contact = _getUniversalValue(d, ['ApplicantContact', 'applicantContact']);
    if (contact.isEmpty) contact = "0000000000";

    return {"id": id, "vNo": vNo, "contact": contact};
  }

  // ===========================================================================
  // INSPECTION FIELD PAYLOAD — keys match web portal HTML formControlName
  // ===========================================================================
  // Bool fields are sent as "true"/"false" strings.
  // Pseudo-bool fields (UI shows Good/Not Good but backend expects string) are
  // also sent as "true"/"false" because that's what the web portal sends.
  Map<String, dynamic> _buildInspectionFields() {
    return {
      // Required
      "vehicleInspectedBy": _vehicleInspectedByController.text,
      "dateOfInspection": _dateOfInspectionController.text,
      "inspectionLocation": _inspectionLocationController.text,
      // True booleans
      "vehicleMoved": _vehicleMovedController.text,         // "true"/"false"
      "engineStarted": _engineStartedController.text,
      "vinPlate": _vinPlateController.text,
      "otherAccessoryFitment": _otherAccessoryFitmentController.text,
      "roadWorthyCondition": _roadWorthyConditionController.text,
      // Number
      "odometer": _odometerController.text,
      // Free text
      "bodyType": _bodyTypeController.text,
      "windshieldGlass": _windshieldGlassController.text,
      "steeringWheel": _steeringWheelController.text,
      "steeringColumn": _steeringColumnController.text,
      "steeringBox": _steeringBoxController.text,
      "steeringLinkages": _steeringLinkagesController.text,
      "fuelSystem": _fuelSystemController.text,
      "exteriorCondition": _exteriorConditionController.text,
      "interiorCondition": _interiorConditionController.text,
      "bonnet": _bonnetController.text,
      "bodyCondition": _bodyConditionController.text,
      "batteryCondition": _batteryConditionController.text,
      "audio": _audioController.text,
      "mudguards": _mudguardsController.text,
      "allGlasses": _allGlassesController.text,
      "boom": _boomController.text,
      "bucket": _bucketController.text,
      "chainTrack": _chainTrackController.text,
      "hydraulicCylinders": _hydraulicCylindersController.text,
      "swingUnit": _swingUnitController.text,
      "cabin": _cabinController.text,
      "dashboard": _dashboardController.text,
      "seats": _seatsController.text,
      "upholestry": _upholestryController.text,
      "interiorTrims": _interiorTrimsController.text,
      "headLamps": _headLampsController.text,
      "front": _frontController.text,
      "rear": _rearController.text,
      "axles": _axlesController.text,
      "airConditioner": _airConditionerController.text,
      "electricAssembly": _electricAssemblyController.text,
      "radiator": _radiatorController.text,
      "intercooler": _intercoolerController.text,
      "allHosePipes": _allHosePipesController.text,
      // Pseudo-bool fields (UI dropdown, sent as "true"/"false")
      "overallTyreCondition": _overallTyreConditionController.text,
      "engineCondition": _engineConditionController.text,
      "suspensionSystem": _suspensionSystemController.text,
      "steeringSystem": _steeringSystemController.text,
      "brakeSystem": _brakeSystemController.text,
      "chassisCondition": _chassisConditionController.text,
      "paintWork": _paintWorkController.text,
      "clutchSystem": _clutchSystemController.text,
      "gearboxAssembly": _gearboxAssemblyController.text,
      "propellerShaft": _propellerShaftController.text,
      "differentialAssy": _differentialAssyController.text,
      // Additional existing fields
      "speedoMeter": _speedoMeterController.text,
      "frontAxles": _frontAxlesController.text,
      "rearAxles": _rearAxlesController.text,
      "driveShafts": _driveShaftsController.text,
      "steeringHandle": _steeringHandleController.text,
      "frontForkAssy": _frontForkAssyController.text,
      "frontFairing": _frontFairingController.text,
      "rearCowls": _rearCowlsController.text,
      "bumpers": _bumpersController.text,
      "doors": _doorsController.text,
      "fenders": _fendersController.text,
      "rightSideWing": _rightSideWingController.text,
      "leftSideWing": _leftSideWingController.text,
      "tailGate": _tailGateController.text,
      "loadFloor": _loadFloorController.text,
      // Brakes Additional
      "parkingBrake": _parkingBrakeController.text,
      "abs": _absController.text,
      // Electrical Additional
      "tailLightsIndicators": _tailLightsIndicatorsController.text,
      "wiringAssy": _wiringAssyController.text,
      // Crash Guards
      "frontCrashGuard": _frontCrashGuardController.text,
      "rearCrashGuard": _rearCrashGuardController.text,
      // 4W Specific
      "airBags": _airBagsController.text,
      "sunRoof": _sunRoofController.text,
      "sideFenders": _sideFendersController.text,
      // CV Specific
      "hydraulicLift": _hydraulicLiftController.text,
      "sideUnderRunProtection": _sideUnderRunProtectionController.text,
      // 2W Specific
      "mainStand": _mainStandController.text,
      "sideStand": _sideStandController.text,
      "frontMudGuard": _frontMudGuardController.text,
      "rearMudGuard": _rearMudGuardController.text,
      "fuelTankCondition": _fuelTankConditionController.text,
      "chainSprocket": _chainSprocketController.text,
      "frontBrakeCondition": _frontBrakeConditionController.text,
      "rearBrakeCondition": _rearBrakeConditionController.text,
      "headLight": _headLightController.text,
      "tailLight": _tailLightController.text,
      "indicators": _indicatorsController.text,
      "hornCondition": _hornConditionController.text,
      "mirrorCondition": _mirrorConditionController.text,
      "seatCondition": _seatConditionController.text,
      "handleBarGrips": _handleBarGripsController.text,
      "footRest": _footRestController.text,
      "alloyWheelRim": _alloyWheelRimController.text,
      // CE Specific
      "retarder": _retarderController.text,
      "differentialLock": _differentialLockController.text,
      "pto": _ptoController.text,
      "hydraulicSystem": _hydraulicSystemController.text,
      "boomArm": _boomArmController.text,
      "bucketCondition": _bucketConditionController.text,
      "bladeCondition": _bladeConditionController.text,
      "liftingCapacity": _liftingCapacityController.text,
      "tyreConditionCe": _tyreConditionCeController.text,
      "underCarriage": _underCarriageController.text,
      "crawlerTracks": _crawlerTracksController.text,
      "steelRims": _steelRimsController.text,
      "attachmentCondition": _attachmentConditionController.text,
      "cabCondition": _cabConditionController.text,
      "counterWeight": _counterWeightController.text,
      "rockBreaker": _rockBreakerController.text,
      // BUS Specific
      "coachCondition": _coachConditionController.text,
      "passengerSeats": _passengerSeatsController.text,
      "emergencyExits": _emergencyExitsController.text,
      "luggageCompartment": _luggageCompartmentController.text,
      "acSystem": _acSystemController.text,
      "destinationBoard": _destinationBoardController.text,
      "sideMirrors": _sideMirrorsController.text,
      // FE Specific
      "rightIndividualBrakes": _rightIndividualBrakesController.text,
      "leftIndividualBrakes": _leftIndividualBrakesController.text,
      "threePointLinkage": _threePointLinkageController.text,
      "powerTakeOff": _powerTakeOffController.text,
      "hitchSystem": _hitchSystemController.text,
      "hydraulicLiftFe": _hydraulicLiftFeController.text,
      "frontWeights": _frontWeightsController.text,
      "rearWeights": _rearWeightsController.text,
      "ropsCanopy": _ropsCanopyController.text,
      "frontTyreCondition": _frontTyreConditionController.text,
      "rearTyreCondition": _rearTyreConditionController.text,
      "implementAttachments": _implementAttachmentsController.text,
      "fuelTankFe": _fuelTankFeController.text,
      "frontAxleFe": _frontAxleFeController.text,
      "rearDrawbar": _rearDrawbarController.text,
      // Remarks
      "remarks": _remarksController.text,
    };
  }

  Future<Map<String, dynamic>> _savePayment(Map<String, String> ctx) async {
    final paymentAmount = num.tryParse(_paymentAmountController.text) ?? 0;
    final dateText = _paymentDateController.text;
    final paymentDateIso = dateText.isEmpty
        ? DateTime.now().toUtc().toIso8601String()
        : (DateTime.tryParse(dateText) ?? DateTime.now()).toUtc().toIso8601String();

    return api.savePayment(
      valuationId: ctx["id"]!,
      vehicleNumber: ctx["vNo"]!,
      applicantContact: ctx["contact"]!,
      paymentStatus: _selectedPaymentStatus ?? 'Pending',
      paymentReference: _paymentReferenceController.text.isEmpty ? null : _paymentReferenceController.text,
      paymentDate: paymentDateIso,
      paymentMethod: _selectedPaymentMethod ?? 'Online',
      paymentAmount: paymentAmount,
    );
  }

  // ===========================================================================
  // SAVE / SUBMIT / RETURN flows (unchanged from previous version)
  // ===========================================================================

  Future<void> _onSave() async {
    // Validate required AVO fields
    if (_avoFormKey.currentState != null && !_avoFormKey.currentState!.validate()) {
      _showError("Please fill all required fields (*)");
      return;
    }

    setState(() => _isSaving = true);
    final ctx = _getSafeContext();
    final assignee = _assigneeNameForUser();

    final inspRes = await api.saveInspectionForAvo(
      id: ctx["id"]!,
      vNo: ctx["vNo"]!,
      contact: ctx["contact"]!,
      formFields: _buildInspectionFields(),
      assignedTo: assignee,
    );
    if (!mounted) return;
    if (inspRes['success'] != true) {
      setState(() => _isSaving = false);
      _showError("Save failed: ${inspRes['message']}");
      return;
    }

    final payRes = await _savePayment(ctx);
    if (!mounted) return;
    if (payRes['success'] != true) {
      setState(() => _isSaving = false);
      _showError("Payment save failed: ${payRes['message']}");
      return;
    }

    final startRes = await api.startWorkflow(ctx["id"]!, 3, ctx["vNo"]!, ctx["contact"]!);
    if (!mounted) return;
    if (startRes['success'] != true) {
      debugPrint("DEBUG: startWorkflow(3) on save failed (likely already started): ${startRes['message']}");
    }

    final tableRes = await api.updateWorkflowTable(ctx["id"]!, ctx["vNo"]!, ctx["contact"]!,
        {"workflow": "AVO", "workflowStepOrder": 3, "assignedTo": assignee, "avoAssignedTo": assignee});
    if (!mounted) return;
    if (tableRes['success'] != true) {
      debugPrint("DEBUG: updateWorkflowTable on save failed: ${tableRes['message']}");
    }

    await _loadAllData();
    setState(() {
      _isSaving = false;
      _isAvoEditing = false;
    });
    _showSuccess("Saved successfully");
  }

  Future<void> _onSubmit() async {
    if (_avoFormKey.currentState != null && !_avoFormKey.currentState!.validate()) {
      _showError("Please fill all required fields (*)");
      return;
    }

    setState(() => _isSubmitting = true);
    final ctx = _getSafeContext();
    final assignee = _assigneeNameForUser();

    final photoCheck = await api.checkMandatoryPhotos(ctx["id"]!, ctx["vNo"]!, ctx["contact"]!);
    if (!mounted) return;

    if (photoCheck['endpointMissing'] == true) {
      debugPrint("WARN: checkMandatoryPhotos endpoint missing — skipping photo gating");
    } else if (photoCheck['isComplete'] != true) {
      setState(() => _isSubmitting = false);
      final missing = (photoCheck['missingPhotos'] as List?)?.cast<String>() ?? [];
      if (missing.isNotEmpty) {
        await _showMissingPhotosDialog(missing);
      } else {
        _showError(photoCheck['error']?.toString() ?? "Photo validation failed");
      }
      return;
    }

    final inspRes = await api.saveInspectionForAvo(
        id: ctx["id"]!, vNo: ctx["vNo"]!, contact: ctx["contact"]!,
        formFields: _buildInspectionFields(), assignedTo: assignee);
    if (!mounted) return;
    if (inspRes['success'] != true) {
      setState(() => _isSubmitting = false);
      _showError("Submit failed at inspection step: ${inspRes['message']}");
      return;
    }

    final payRes = await _savePayment(ctx);
    if (!mounted) return;
    if (payRes['success'] != true) {
      setState(() => _isSubmitting = false);
      _showError("Submit failed at payment step: ${payRes['message']}");
      return;
    }

    final completeRes = await api.completeWorkflow(ctx["id"]!, 3, ctx["vNo"]!, ctx["contact"]!);
    if (!mounted) return;
    if (completeRes['success'] != true) {
      setState(() => _isSubmitting = false);
      _showError("Submit failed: could not complete AVO step. ${completeRes['message']}");
      return;
    }

    final startQcRes = await api.startWorkflow(ctx["id"]!, 4, ctx["vNo"]!, ctx["contact"]!);
    if (!mounted) return;
    if (startQcRes['success'] != true) {
      setState(() => _isSubmitting = false);
      _showError("Submit failed: could not start QC step. ${startQcRes['message']}");
      return;
    }

    // AI valuation is best-effort — a failure should not block submission.
    // If the GPT call times out or the backend errors, we log a warning and
    // continue; the QC user can still manually enter valuation figures.
    final aiRes = await api.getValuationDetailsfromAI(ctx["id"]!, ctx["vNo"]!, ctx["contact"]!);
    if (!mounted) return;
    if (aiRes['success'] != true) {
      debugPrint("WARN: AI valuation step failed (non-blocking): ${aiRes['message']}");
    }

    final tableRes = await api.updateWorkflowTable(ctx["id"]!, ctx["vNo"]!, ctx["contact"]!,
        {"workflow": "QC", "workflowStepOrder": 4, "assignedTo": assignee, "avoAssignedTo": assignee});
    if (!mounted) return;
    if (tableRes['success'] != true) {
      debugPrint("WARN: updateWorkflowTable failed after Submit: ${tableRes['message']}");
    }

    setState(() => _isSubmitting = false);
    _showSuccess("Submitted to QC successfully");
    Navigator.pop(context);
  }

  Future<void> _onReturnPressed() async {
    final reason = await _showReturnReasonDialog();
    if (reason == null || reason.trim().isEmpty) return;
    await _attemptReturn(reason: reason.trim(), overrideAssigneeId: "");
  }

  Future<void> _attemptReturn({required String reason, required String overrideAssigneeId}) async {
    setState(() => _isReturning = true);
    final ctx = _getSafeContext();
    final user = FirebaseAuth.instance.currentUser;
    final userId = user?.uid ?? user?.phoneNumber ?? 'unknown';
    final userName = user?.displayName ?? user?.email?.split('@').first ?? 'AVO Inspector';

    final res = await api.returnWorkflow(
        valuationId: ctx["id"]!, vehicleNumber: ctx["vNo"]!, applicantContact: ctx["contact"]!,
        currentStep: "AVO", returnReason: reason, currentUserId: userId, currentUserName: userName,
        targetReturnStep: "Backend", overrideAssigneeId: overrideAssigneeId);

    if (!mounted) return;

    if (res['success'] == true) {
      setState(() => _isReturning = false);
      _showSuccess("Case returned to Backend");
      Navigator.pop(context);
      return;
    }

    final statusCode = res['statusCode'];
    final message = (res['message'] ?? '').toString();
    final needsOverride = statusCode == 400 && message.toLowerCase().contains('overrideassigneeid');

    if (needsOverride) {
      setState(() => _isReturning = false);
      final picked = await _showOverridePickerDialog();
      if (picked == null) return;
      await _attemptReturn(reason: reason, overrideAssigneeId: picked);
      return;
    }

    setState(() => _isReturning = false);
    _showError("Return failed: ${res['message']}");
  }

  Future<String?> _showReturnReasonDialog() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Return to Backend"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Why is this case being returned?", style: TextStyle(color: Colors.grey, fontSize: 13)),
            const SizedBox(height: 12),
            TextField(
                controller: controller,
                autofocus: true,
                maxLines: 3,
                decoration: const InputDecoration(border: OutlineInputBorder(), hintText: "e.g. Chassis number mismatch with RC")),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
              onPressed: () {
                if (controller.text.trim().isEmpty) return;
                Navigator.pop(ctx, controller.text.trim());
              },
              child: const Text("Return")),
        ],
      ),
    );
    return result;
  }

  Future<String?> _showOverridePickerDialog() async {
    setState(() => _isReturning = true);
    final users = await api.getUsersByRole('BackEnd');
    if (!mounted) return null;
    setState(() => _isReturning = false);

    if (users.isEmpty) {
      _showError("No Backend users available for override. Contact admin.");
      return null;
    }

    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Original Backend user unavailable"),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Pick a Backend user to assign this case to:",
                  style: TextStyle(color: Colors.grey, fontSize: 13)),
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
                        onTap: () => Navigator.pop(ctx, id));
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

  Future<void> _showMissingPhotosDialog(List<String> missing) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(children: const [
          Icon(Icons.warning_amber_rounded, color: Colors.orange),
          SizedBox(width: 8),
          Text("Photos required"),
        ]),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("${missing.length} mandatory image(s) missing:",
                  style: const TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: missing
                          .map((m) => Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: Text("• $m")))
                          .toList()),
                ),
              ),
              const SizedBox(height: 8),
              const Text("Upload all required photos before submitting.",
                  style: TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Close")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3F51B5), foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => VehicleMediaPage(
                      valuationId: widget.summaryData['valuationId'] ?? "",
                      cameraOnly: true,
                      vehicleNumber: widget.summaryData['vehicleNumber']?.toString(),
                      applicantContact: widget.summaryData['applicantContact']?.toString())));
            },
            child: const Text("Upload photos"),
          ),
        ],
      ),
    );
  }

  String _assigneeNameForUser() {
    final user = FirebaseAuth.instance.currentUser;
    return user?.displayName ?? user?.email?.split('@').first ?? user?.phoneNumber ?? 'AVO Inspector';
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  void _showSuccess(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.green));
  }

  // ===========================================================================
  // BACKEND TAB SAVE (unchanged)
  // ===========================================================================
  Future<void> _saveBackend({bool submitAnyway = false}) async {
    if (!submitAnyway && !_backendFormKey.currentState!.validate()) {
      _showError("Please fill all mandatory fields (*)!");
      return;
    }
    setState(() => _isSaving = true);

    var ctx = _getSafeContext();

    Map<String, dynamic> body = {
      "ValuationId": ctx["id"]!,
      "RegistrationNumber": _regNoController.text,
      "Make": _makeController.text,
      "Model": _modelController.text,
      "BodyType": _bodyTypeBkController.text,
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

    if (!mounted) return;

    if (res["success"] == false) {
      setState(() {
        _isSaving = false;
        _isBackendEditing = false;
      });
      _showError("Save Error: ${res['message']}");
      return;
    }

    await _loadAllData();
    setState(() {
      _isSaving = false;
      _isBackendEditing = false;
    });
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

    if (!mounted) return;

    await _loadAllData();
    setState(() {
      _isSaving = false;
      _isStakeholderEditing = false;
    });

    if (result["success"] == true) {
      _showSuccess("Stakeholder details saved successfully!");
    } else {
      _showError("Error: ${result['message']}");
    }
  }

  Future<void> _pickFile(String type) async {
    FilePickerResult? result = await FilePicker.pickFiles();
    if (result != null && result.files.isNotEmpty) {
      final picked = result.files.single;
      final identifier = picked.path ?? picked.name;
      setState(() {
        if (type == 'RC') {
          _rcPath = identifier;
        } else if (type == 'INS') {
          _insPath = identifier;
        } else {
          _otherPath = identifier;
        }
      });
    }
  }

  Future<void> _selectDate(TextEditingController controller) async {
    DateTime initial = DateTime.tryParse(controller.text) ?? DateTime.now();
    DateTime? picked = await showDatePicker(
        context: context, initialDate: initial, firstDate: DateTime(1990), lastDate: DateTime(2040));
    if (picked != null) setState(() => controller.text = DateFormat('yyyy-MM-dd').format(picked));
  }

  void _launchDownload(String? url) async {
    if (url != null && url.isNotEmpty && await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No document URL found")));
    }
  }

  // ===========================================================================
  // BUILD
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
          title: const Text("Valuation Details", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          backgroundColor: Colors.white,
          elevation: 1,
          iconTheme: const IconThemeData(color: Colors.black)),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildHeaderCard(),
                  if (_currentTab == "AVO" && _returnedBy != null) ...[
                    const SizedBox(height: 12),
                    _buildReturnBanner(),
                  ],
                  const SizedBox(height: 20),
                  if (_currentTab == "AVO")
                    _buildAvoActions()
                  else if (_currentTab == "Backend")
                    _buildLegacyActions(_isBackendEditing,
                        () => setState(() => _isBackendEditing = true), () => _saveBackend(submitAnyway: false))
                  else
                    _buildLegacyActions(_isStakeholderEditing,
                        () => setState(() => _isStakeholderEditing = true), _saveStakeholder),
                  const SizedBox(height: 20),
                  if (_currentTab == "AVO")
                    _buildAVOInspectionForm()
                  else if (_currentTab == "Backend")
                    _buildBackendForm()
                  else
                    _buildStakeholderForm()
                ],
              ),
            ),
    );
  }

  Widget _buildReturnBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3CD),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFFC107)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.assignment_return, color: Color(0xFF856404)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Returned by ${_returnedBy ?? 'Previous Stage'}",
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF856404))),
                const SizedBox(height: 4),
                Text(_returnMessage ?? '', style: const TextStyle(color: Color(0xFF856404))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvoActions() {
    final isProcessing = _isSaving || _isSubmitting || _isReturning;

    if (!_isAvoEditing) {
      return Row(children: [
        Expanded(
            child: ElevatedButton(
                onPressed: () => setState(() => _isAvoEditing = true),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3F51B5), foregroundColor: Colors.white),
                child: const Text("Edit"))),
        const SizedBox(width: 10),
        Expanded(
            child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE53935), foregroundColor: Colors.white),
                child: const Text("Back"))),
      ]);
    }

    return Column(
      children: [
        Row(children: [
          Expanded(
              child: ElevatedButton(
                  onPressed: isProcessing ? null : _onSave,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green, foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12)),
                  child: _isSaving
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text("SAVE"))),
          const SizedBox(width: 8),
          Expanded(
              child: ElevatedButton(
                  onPressed: isProcessing ? null : _onSubmit,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3F51B5), foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12)),
                  child: _isSubmitting
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text("SUBMIT"))),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
              child: ElevatedButton(
                  onPressed: isProcessing ? null : _onReturnPressed,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange, foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12)),
                  child: _isReturning
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text("RETURN TO BACKEND"))),
          const SizedBox(width: 8),
          Expanded(
              child: ElevatedButton(
                  onPressed: isProcessing ? null : () => setState(() => _isAvoEditing = false),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red, foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12)),
                  child: const Text("CANCEL"))),
        ]),
      ],
    );
  }

  Widget _buildLegacyActions(bool isEditing, VoidCallback onEdit, VoidCallback onSave) {
    bool isProcessing = _isSaving || _isSubmitting;

    if (!isEditing) {
      return Row(children: [
        Expanded(
            child: ElevatedButton(
                onPressed: onEdit,
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3F51B5), foregroundColor: Colors.white),
                child: const Text("Edit"))),
        const SizedBox(width: 10),
        Expanded(
            child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE53935), foregroundColor: Colors.white),
                child: const Text("Back"))),
      ]);
    }

    return Row(children: [
      Expanded(
          child: ElevatedButton(
              onPressed: isProcessing ? null : onSave,
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green, foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12)),
              child: _isSaving
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text("SAVE"))),
      const SizedBox(width: 8),
      Expanded(
          child: ElevatedButton(
              onPressed: isProcessing
                  ? null
                  : () => setState(() {
                        _isBackendEditing = false;
                        _isStakeholderEditing = false;
                      }),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red, foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12)),
              child: const Text("CANCEL"))),
    ]);
  }

  // ===========================================================================
  // STAKEHOLDER FORM (unchanged)
  // ===========================================================================
  Widget _buildStakeholderForm() {
    bool canEdit = _isStakeholderEditing;
    return Column(children: [
      Container(
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.only(bottom: 15),
        decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade300)),
        child: _buildField("Pincode", _stkPinController.text, _stkPinController,
            isEditable: canEdit, isRequired: true),
      ),
      _buildSectionContainer("Stakeholder", [
        if (canEdit)
          _buildDropdown("Name of Stakeholder", _stakeholderList, _selectedStakeholderName,
              (val) => setState(() => _selectedStakeholderName = val), isMandatory: true)
        else
          _buildField("Name of Stakeholder", _stkNameController.text, _stkNameController,
              isEditable: false, isRequired: true),
        _buildField("Executive Name", _stkExecController.text, _stkExecController, isEditable: canEdit, isRequired: true),
        _buildField("Contact Number", _stkContactController.text, _stkContactController, isEditable: canEdit, isRequired: true),
        if (canEdit)
          Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(children: [
                Checkbox(
                    value: _sameAsContact,
                    activeColor: Colors.blue,
                    onChanged: (v) {
                      setState(() {
                        _sameAsContact = v!;
                        if (_sameAsContact) _stkWhatsappController.text = _stkContactController.text;
                      });
                    }),
                const Text("Same as Contact Number", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold))
              ])),
        _buildField("WhatsApp Number", _stkWhatsappController.text, _stkWhatsappController,
            isEditable: canEdit && !_sameAsContact),
        _buildField("Email ID", _stkEmailController.text, _stkEmailController, isEditable: canEdit),
        if (canEdit)
          _buildDropdown("Valuation Type", _valuationTypes, _selectedValuationType,
              (val) => setState(() => _selectedValuationType = val))
        else
          _buildField("Valuation Type", _stkValTypeController.text, _stkValTypeController, isEditable: false),
        const SizedBox(height: 15),
        const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Divider()),
        const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text("Address Details", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))),
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
        TextField(
            controller: _stkRemarksController,
            readOnly: !canEdit,
            maxLines: 3,
            decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.all(12))),
      ]),
      const SizedBox(height: 10),
      _buildSectionContainer("Documents", [
        _buildViewDocRow("RC", _getUniversalValue(_stakeholderData, ['rcfile']), 'RC', canEdit),
        _buildViewDocRow("Insurance", _getUniversalValue(_stakeholderData, ['insurancefile']), 'INS', canEdit),
        _buildViewDocRow("Others", _getUniversalValue(_stakeholderData, ['otherfile']), 'OTHER', canEdit),
      ], isOpen: true),
      _buildNotesSection(),
      const SizedBox(height: 20),
      _buildLegacyActions(canEdit, () => setState(() => _isStakeholderEditing = true), _saveStakeholder),
    ]);
  }

  // ===========================================================================
  // GENERIC FIELD HELPERS
  // ===========================================================================

  Widget _buildField(String label, String value, TextEditingController? controller,
      {bool isEditable = false,
      Function(String)? onChanged,
      bool isRequired = false,
      TextInputType? keyboardType,
      String? Function(String?)? validator}) {
    Widget labelWidget = RichText(
        text: TextSpan(text: label, style: TextStyle(color: Colors.grey[600], fontSize: 14), children: [
      if (isRequired) const TextSpan(text: " *", style: TextStyle(color: Colors.red))
    ]));
    if (isEditable && controller != null) {
      return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            labelWidget,
            const SizedBox(height: 6),
            TextFormField(
                controller: controller,
                onChanged: onChanged,
                keyboardType: keyboardType,
                inputFormatters: keyboardType == TextInputType.number
                    ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))]
                    : null,
                validator: validator ??
                    (isRequired
                        ? (v) => (v == null || v.trim().isEmpty) ? "Required" : null
                        : null),
                decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12)))
          ]));
    } else {
      String displayTxt = controller?.text.isNotEmpty == true ? controller!.text : value;
      return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(flex: 2, child: labelWidget),
            Expanded(flex: 3, child: Text(displayTxt.isEmpty ? "-" : displayTxt, style: const TextStyle(fontWeight: FontWeight.w500)))
          ]));
    }
  }

  Widget _buildDropdown(String label, List<String> items, String? value, Function(String?) onChanged,
      {bool isMandatory = false}) {
    Widget labelWidget = RichText(
        text: TextSpan(text: label, style: TextStyle(color: Colors.grey[600], fontSize: 14), children: [
      if (isMandatory) const TextSpan(text: " *", style: TextStyle(color: Colors.red))
    ]));
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
                  .map((item) => DropdownMenuItem(value: item, child: Text(item, style: const TextStyle(fontSize: 13))))
                  .toList(),
              onChanged: onChanged)
        ]));
  }

  // Bool-as-string dropdown — stores "true"/"false" in controller, displays
  // localized labels (Yes/No, Good/Not Good, OK/Not OK).
  // When in read-only mode, shows the localized label as plain text.
  Widget _buildBoolDropdown(
    String label,
    TextEditingController controller, {
    String trueLabel = "Yes",
    String falseLabel = "No",
    bool isEditable = true,
    bool isMandatory = false,
  }) {
    Widget labelWidget = RichText(
        text: TextSpan(text: label, style: TextStyle(color: Colors.grey[600], fontSize: 14), children: [
      if (isMandatory) const TextSpan(text: " *", style: TextStyle(color: Colors.red))
    ]));

    if (!isEditable) {
      String display = "-";
      final v = controller.text;
      if (v == "true") display = trueLabel;
      else if (v == "false") display = falseLabel;
      return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(flex: 2, child: labelWidget),
            Expanded(flex: 3, child: Text(display, style: const TextStyle(fontWeight: FontWeight.w500)))
          ]));
    }

    String? currentValue = controller.text == "true" || controller.text == "false" ? controller.text : null;
    return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          labelWidget,
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
              value: currentValue,
              isExpanded: true,
              decoration: const InputDecoration(
                  border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12)),
              items: [
                DropdownMenuItem(value: "true", child: Text(trueLabel, style: const TextStyle(fontSize: 13))),
                DropdownMenuItem(value: "false", child: Text(falseLabel, style: const TextStyle(fontSize: 13))),
              ],
              validator: isMandatory
                  ? (v) => (v == null || v.isEmpty) ? "Required" : null
                  : null,
              onChanged: (v) {
                setState(() => controller.text = v ?? "");
              })
        ]));
  }

  Widget _buildSectionContainer(String title, List<Widget> children, {bool isOpen = false}) {
    return Container(
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade300)),
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
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Expanded(flex: 2, child: Text(label, style: const TextStyle(fontWeight: FontWeight.w500))),
          Expanded(
              flex: 3,
              child: Row(children: [
                if (canEdit) ...[
                  ElevatedButton(
                      onPressed: () => _pickFile(type),
                      style: ElevatedButton.styleFrom(minimumSize: const Size(80, 30)),
                      child: const Text("Choose File", style: TextStyle(fontSize: 11))),
                  const SizedBox(width: 8),
                  const Text("NO FILE", style: TextStyle(fontSize: 11))
                ] else
                  GestureDetector(
                      onTap: () => _launchDownload(url),
                      child: Text((url != null && url.isNotEmpty && url != "null") ? "Download" : "No Document",
                          style: TextStyle(
                              color: (url != null && url.isNotEmpty && url != "null") ? Colors.blue : Colors.grey,
                              fontWeight: FontWeight.bold,
                              decoration: TextDecoration.underline)))
              ]))
        ]));
  }

  // ===========================================================================
  // BACKEND FORM (unchanged)
  // ===========================================================================
  Widget _buildBackendForm() {
    bool canEdit = _isBackendEditing;
    return Form(
        key: _backendFormKey,
        child: Column(children: [
          _buildSectionContainer("Vehicle Information", [
            _buildField("Registration Number*", _regNoController.text, _regNoController, isEditable: canEdit),
            _buildField("Make*", _makeController.text, _makeController, isEditable: canEdit),
            _buildField("Model*", _modelController.text, _modelController, isEditable: canEdit),
            _buildField("Body Type", _bodyTypeBkController.text, _bodyTypeBkController, isEditable: canEdit),
            _buildField("Colour", _colorController.text, _colorController, isEditable: canEdit),
            if (canEdit)
              _buildDropdown("Fuel Type", _fuelTypes, _selectedFuel, (val) => setState(() => _selectedFuel = val))
            else
              _buildField("Fuel", _fuelTypeController.text, _fuelTypeController, isEditable: canEdit),
          ], isOpen: true),
          _buildSectionContainer("Manufacturing & Engine Details", [
            _buildRow(_buildField("Year of Mfg", _mfgYearController.text, _mfgYearController, isEditable: canEdit),
                _buildField("Month of Mfg", _mfgMonthController.text, _mfgMonthController, isEditable: canEdit)),
            _buildRow(_buildField("Engine No*", _engineNoController.text, _engineNoController, isEditable: canEdit),
                _buildField("Chassis No*", _chassisNoController.text, _chassisNoController, isEditable: canEdit)),
            _buildRow(_buildField("Engine CC", _engineCcController.text, _engineCcController, isEditable: canEdit),
                _buildField("Gross Wt", _grossWeightController.text, _grossWeightController, isEditable: canEdit)),
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
            _buildRow(_buildField("Owner Name*", _ownerNameController.text, _ownerNameController, isEditable: canEdit),
                _buildField("Owner Serial No", _ownerSerialController.text, _ownerSerialController, isEditable: canEdit)),
            _buildField("Present Address", _presentAddrController.text, _presentAddrController, isEditable: canEdit),
            _buildField("Permanent Address", _permAddrController.text, _permAddrController, isEditable: canEdit),
            _buildRow(
                _buildCheckbox("Hypothecation", _isHypothecated, (v) => setState(() => _isHypothecated = v!), canEdit),
                _buildField("Lender", _lenderController.text, _lenderController, isEditable: canEdit))
          ]),
          _buildSectionContainer("Insurance Details", [
            _buildRow(_buildField("Insurer", _insurerController.text, _insurerController, isEditable: canEdit),
                _buildField("Policy No", _policyNoController.text, _policyNoController, isEditable: canEdit)),
            _buildDateField("Valid Up To", _insuranceValidController, canEdit)
          ]),
          _buildSectionContainer("Permit & Fitness", [
            _buildRow(_buildField("Permit No", _permitNoController.text, _permitNoController, isEditable: canEdit),
                _buildDateField("Valid Up To", _permitValidController, canEdit)),
            _buildRow(_buildField("Permit Type", _permitTypeController.text, _permitTypeController, isEditable: canEdit),
                _buildDateField("Issued On", _permitIssuedOnController, canEdit)),
            _buildRow(_buildDateField("Permit From", _permitFromController, canEdit),
                _buildField("Fitness No", _fitnessNoController.text, _fitnessNoController, isEditable: canEdit)),
            _buildDateField("Fitness Valid To", _fitnessValidController, canEdit)
          ]),
          _buildSectionContainer("Pollution & Tax", [
            _buildRow(_buildField("Pollution No", _pollutionNoController.text, _pollutionNoController, isEditable: canEdit),
                _buildDateField("Pollution Valid", _pollutionValidController, canEdit)),
            _buildRow(_buildDateField("Tax Up To", _taxValidController, canEdit),
                _buildDateField("Tax Paid", _taxPaidController, canEdit))
          ]),
          _buildSectionContainer("Additional Info", [
            _buildRow(_buildField("IDV", _idvController.text, _idvController, isEditable: canEdit),
                _buildField("Ex Showroom", _showroomPriceController.text, _showroomPriceController, isEditable: canEdit)),
            _buildRow(_buildCheckbox("Blacklist Status", _isBlacklisted, (v) => setState(() => _isBlacklisted = v!), canEdit),
                _buildCheckbox("RC Status", _isRcActive, (v) => setState(() => _isRcActive = v!), canEdit)),
            _buildDateField("Manufactured Date", _manufacturedDateController, canEdit),
            _buildField("Stencil URL", _stencilUrlController.text, _stencilUrlController, isEditable: canEdit),
            _buildField("Chassis URL", _chassisUrlController.text, _chassisUrlController, isEditable: canEdit),
          ]),
          _buildSectionContainer("Remarks", [
            TextField(
                controller: _backendRemarksController,
                readOnly: !canEdit,
                maxLines: 3,
                decoration: const InputDecoration(border: OutlineInputBorder(), hintText: "Remarks..."))
          ]),
          _buildSectionContainer("Documents", [
            _buildDocButton("RC", _rcPath, () => _pickFile('RC'), canEdit, type: 'RC'),
            _buildDocButton("Insurance", _insPath, () => _pickFile('INS'), canEdit, type: 'INS'),
            _buildDocButton("Other", _otherPath, () => _pickFile('OTHER'), canEdit, type: 'OTHER'),
          ]),
          _buildSectionContainer("Assign", [
            if (canEdit)
              _buildDropdown("Assign To", _assigneeOptions, _selectedAssignee, (v) => setState(() => _selectedAssignee = v))
            else
              const Text("Assignment disabled in view mode")
          ]),
          const SizedBox(height: 20),
          _buildLegacyActions(canEdit, () => setState(() => _isBackendEditing = true), () => _saveBackend(submitAnyway: false)),
        ]));
  }

  // ===========================================================================
  // AVO INSPECTION FORM — sections + visibility map applied
  // ===========================================================================
  Widget _buildAVOInspectionForm() {
    final canEdit = _isAvoEditing;

    // Helper closures so each field is a single line in the section list.
    Widget tf(String label, String key, TextEditingController c, {bool required = false, TextInputType? kb}) {
      if (!_showField(key)) return const SizedBox.shrink();
      return _buildField(label, c.text, c, isEditable: canEdit, isRequired: required, keyboardType: kb);
    }

    Widget bd(String label, String key, TextEditingController c, {String t = "Yes", String f = "No", bool req = false}) {
      if (!_showField(key)) return const SizedBox.shrink();
      return _buildBoolDropdown(label, c, trueLabel: t, falseLabel: f, isEditable: canEdit, isMandatory: req);
    }

    // Returns true if at least one field key in the list is visible for the current vehicle type.
    // Used to hide entire section containers when no fields inside them are relevant.
    bool hv(List<String> keys) => keys.any((k) => _showField(k));

    return Form(
      key: _avoFormKey,
      child: Column(children: [
        // ── 1. INSPECTION INFO (always visible) ─────────────────────────────
        _buildSectionContainer("Inspection Info", [
          tf("Vehicle Inspected By", "vehicleInspectedBy", _vehicleInspectedByController, required: true),
          if (_showField('inspectionDate'))
            _buildDateField("Date of Inspection", _dateOfInspectionController, canEdit, required: true),
          tf("Inspection Location", "inspectionLocation", _inspectionLocationController, required: true),
        ], isOpen: true),

        // ── 2. GENERAL CONDITION ────────────────────────────────────────────
        if (hv(['vehicleMoved', 'engineStarted', 'odometer', 'vinPlate', 'bodyType',
                 'tyreCondition', 'otherAccessoryFitment', 'roadWorthyCondition']))
          _buildSectionContainer("General Condition", [
            bd("Vehicle Moved", "vehicleMoved", _vehicleMovedController),
            bd("Engine Started", "engineStarted", _engineStartedController),
            tf("Odometer (km)", "odometer", _odometerController, kb: TextInputType.number),
            bd("VIN Plate Present", "vinPlate", _vinPlateController),
            tf("Body Type", "bodyType", _bodyTypeController),
            bd("Overall Tyre Condition", "tyreCondition", _overallTyreConditionController, t: "Good", f: "Not Good"),
            bd("Other Accessories Fitted", "otherAccessoryFitment", _otherAccessoryFitmentController),
            bd("Road Worthy Condition", "roadWorthyCondition", _roadWorthyConditionController, t: "OK", f: "Not OK"),
          ]),

        // ── 3. ENGINE & FUEL SYSTEM ─────────────────────────────────────────
        if (hv(['engineCondition', 'fuelSystem', 'fuelTankCondition', 'fuelTankFe',
                 'radiator', 'interCooler', 'allHosePipes', 'batteryCondition']))
          _buildSectionContainer("Engine & Fuel System", [
            bd("Engine Condition", "engineCondition", _engineConditionController, t: "Good", f: "Not Good"),
            tf("Fuel System", "fuelSystem", _fuelSystemController),
            tf("Fuel Tank Condition", "fuelTankCondition", _fuelTankConditionController),
            tf("Fuel Tank (FE)", "fuelTankFe", _fuelTankFeController),
            tf("Radiator", "radiator", _radiatorController),
            tf("Intercooler", "interCooler", _intercoolerController),
            tf("All Hose & Pipes", "allHosePipes", _allHosePipesController),
            tf("Battery Condition", "batteryCondition", _batteryConditionController),
          ]),

        // ── 4. STEERING & SUSPENSION ────────────────────────────────────────
        if (hv(['brakeSystem', 'suspensionSystem', 'steeringSystem', 'steeringWheel',
                 'steeringColumn', 'steeringBox', 'steeringLinkages', 'steeringHandle', 'frontForkAssy']))
          _buildSectionContainer("Steering & Suspension", [
            bd("Brake System", "brakeSystem", _brakeSystemController, t: "Good", f: "Not Good"),
            bd("Suspension System", "suspensionSystem", _suspensionSystemController, t: "Good", f: "Not Good"),
            bd("Steering Assembly", "steeringSystem", _steeringSystemController, t: "Good", f: "Not Good"),
            tf("Steering Wheel", "steeringWheel", _steeringWheelController),
            tf("Steering Column", "steeringColumn", _steeringColumnController),
            tf("Steering Box", "steeringBox", _steeringBoxController),
            tf("Steering Linkages", "steeringLinkages", _steeringLinkagesController),
            tf("Steering Handle", "steeringHandle", _steeringHandleController),
            tf("Front Fork Assembly", "frontForkAssy", _frontForkAssyController),
          ]),

        // ── 5. TRANSMISSION & DRIVETRAIN ────────────────────────────────────
        if (hv(['clutchSystem', 'gearboxAssembly', 'propellerShaft', 'differentialAssy',
                 'driveShafts', 'chainSprocket', 'powerTakeOff', 'retarder',
                 'differentialLock', 'pto', 'frontAxleFe']))
          _buildSectionContainer("Transmission & Drivetrain", [
            bd("Clutch System", "clutchSystem", _clutchSystemController, t: "Good", f: "Not Good"),
            bd("Gearbox Assembly", "gearboxAssembly", _gearboxAssemblyController, t: "Good", f: "Not Good"),
            bd("Propeller Shaft", "propellerShaft", _propellerShaftController, t: "Good", f: "Not Good"),
            bd("Differential Assembly", "differentialAssy", _differentialAssyController, t: "Good", f: "Not Good"),
            tf("Drive Shafts", "driveShafts", _driveShaftsController),
            tf("Chain & Sprocket", "chainSprocket", _chainSprocketController),
            tf("Power Take Off", "powerTakeOff", _powerTakeOffController),
            tf("Retarder", "retarder", _retarderController),
            tf("Differential Lock", "differentialLock", _differentialLockController),
            tf("PTO", "pto", _ptoController),
            tf("Front Axle (FE)", "frontAxleFe", _frontAxleFeController),
          ]),

        // ── 6. BODY & STRUCTURE ─────────────────────────────────────────────
        if (hv(['chassisCondition', 'exteriorCondition', 'bodyCondition', 'interiorCondition',
                 'bonnet', 'bumpers', 'doors', 'fenders', 'rightSideWing', 'leftSideWing',
                 'tailGate', 'loadFloor', 'mudguards', 'allGlasses', 'paintWork', 'windshieldGlass',
                 'frontFairing', 'rearCowls', 'mainStand', 'sideStand', 'frontMudGuard', 'rearMudGuard',
                 'alloyWheelRim', 'handleBarGrips', 'footRest', 'sideFenders', 'sideUnderRunProtection',
                 'coachCondition', 'frontWeights', 'rearWeights', 'ropsCanopy', 'counterWeight',
                 'frontAxles', 'rearAxles', 'boom', 'bucket', 'chainTrack',
                 'hydraulicCylinders', 'swingUnit']))
          _buildSectionContainer("Body & Structure", [
            bd("Chassis Condition", "chassisCondition", _chassisConditionController, t: "Good", f: "Not Good"),
            tf("Exterior Condition", "exteriorCondition", _exteriorConditionController),
            tf("Interior Condition", "interiorCondition", _interiorConditionController),
            tf("Body Condition", "bodyCondition", _bodyConditionController),
            tf("Bonnet", "bonnet", _bonnetController),
            bd("Paint Work", "paintWork", _paintWorkController, t: "Good", f: "Not Good"),
            tf("Windshield / Glass", "windshieldGlass", _windshieldGlassController),
            tf("Bumpers", "bumpers", _bumpersController),
            tf("Doors", "doors", _doorsController),
            tf("Fenders", "fenders", _fendersController),
            tf("Side Fenders", "sideFenders", _sideFendersController),
            tf("Right Side Wing", "rightSideWing", _rightSideWingController),
            tf("Left Side Wing", "leftSideWing", _leftSideWingController),
            tf("Tail Gate", "tailGate", _tailGateController),
            tf("Load Floor", "loadFloor", _loadFloorController),
            tf("Mudguards", "mudguards", _mudguardsController),
            tf("All Glasses", "allGlasses", _allGlassesController),
            tf("Front Axles", "frontAxles", _frontAxlesController),
            tf("Rear Axles", "rearAxles", _rearAxlesController),
            tf("Front Fairing", "frontFairing", _frontFairingController),
            tf("Rear Cowls", "rearCowls", _rearCowlsController),
            tf("Main Stand", "mainStand", _mainStandController),
            tf("Side Stand", "sideStand", _sideStandController),
            tf("Front Mud Guard", "frontMudGuard", _frontMudGuardController),
            tf("Rear Mud Guard", "rearMudGuard", _rearMudGuardController),
            tf("Alloy Wheel / Rim", "alloyWheelRim", _alloyWheelRimController),
            tf("Handle Bar Grips", "handleBarGrips", _handleBarGripsController),
            tf("Foot Rest", "footRest", _footRestController),
            tf("Side Under-Run Protection", "sideUnderRunProtection", _sideUnderRunProtectionController),
            tf("Coach Condition", "coachCondition", _coachConditionController),
            tf("Front Weights", "frontWeights", _frontWeightsController),
            tf("Rear Weights", "rearWeights", _rearWeightsController),
            tf("ROPS / Canopy", "ropsCanopy", _ropsCanopyController),
            tf("Counter Weight", "counterWeight", _counterWeightController),
            tf("Boom", "boom", _boomController),
            tf("Bucket", "bucket", _bucketController),
            tf("Chain Track", "chainTrack", _chainTrackController),
            tf("Hydraulic Cylinders", "hydraulicCylinders", _hydraulicCylindersController),
            tf("Swing Unit", "swingUnit", _swingUnitController),
          ]),

        // ── 7. INTERIOR & CABIN ─────────────────────────────────────────────
        if (hv(['cabinCondition', 'dashBoard', 'seats', 'upholestry', 'interiorTrims',
                 'audio', 'airConditioner', 'airBags', 'sunRoof', 'headLamps', 'front', 'rear',
                 'axles', 'cabCondition', 'passengerSeats', 'emergencyExits',
                 'luggageCompartment', 'acSystem', 'destinationBoard', 'seatCondition']))
          _buildSectionContainer("Interior & Cabin", [
            tf("Cabin Condition", "cabinCondition", _cabinController),
            tf("Dashboard Condition", "dashBoard", _dashboardController),
            tf("Seats Condition", "seats", _seatsController),
            tf("Upholestry", "upholestry", _upholestryController),
            tf("Interior Trims", "interiorTrims", _interiorTrimsController),
            tf("Audio", "audio", _audioController),
            tf("Air Conditioner", "airConditioner", _airConditionerController),
            tf("Air Bags", "airBags", _airBagsController),
            tf("Sun Roof", "sunRoof", _sunRoofController),
            tf("Head Lamps", "headLamps", _headLampsController),
            tf("Front View", "front", _frontController),
            tf("Rear View", "rear", _rearController),
            tf("Axles", "axles", _axlesController),
            tf("Cab Condition", "cabCondition", _cabConditionController),
            tf("Passenger Seats", "passengerSeats", _passengerSeatsController),
            tf("Emergency Exits", "emergencyExits", _emergencyExitsController),
            tf("Luggage Compartment", "luggageCompartment", _luggageCompartmentController),
            tf("AC System", "acSystem", _acSystemController),
            tf("Destination Board", "destinationBoard", _destinationBoardController),
            tf("Seat Condition", "seatCondition", _seatConditionController),
          ]),

        // ── 8. ELECTRICAL & INSTRUMENTS ─────────────────────────────────────
        if (hv(['electricalSystem', 'tailLightsIndicators', 'wiringAssy', 'headLight',
                 'tailLight', 'indicators', 'hornCondition', 'mirrorCondition',
                 'sideMirrors', 'speedoMeter']))
          _buildSectionContainer("Electrical & Instruments", [
            tf("Electric Assembly", "electricalSystem", _electricAssemblyController),
            tf("Tail Lights / Indicators", "tailLightsIndicators", _tailLightsIndicatorsController),
            tf("Wiring Assembly", "wiringAssy", _wiringAssyController),
            tf("Head Light", "headLight", _headLightController),
            tf("Tail Light", "tailLight", _tailLightController),
            tf("Indicators", "indicators", _indicatorsController),
            tf("Horn Condition", "hornCondition", _hornConditionController),
            tf("Mirror Condition", "mirrorCondition", _mirrorConditionController),
            tf("Side Mirrors", "sideMirrors", _sideMirrorsController),
            tf("Speedometer", "speedoMeter", _speedoMeterController),
          ]),

        // ── 9. BRAKES & SAFETY ──────────────────────────────────────────────
        if (hv(['parkingBrake', 'abs', 'frontCrashGuard', 'rearCrashGuard',
                 'frontBrakeCondition', 'rearBrakeCondition',
                 'rightIndividualBrakes', 'leftIndividualBrakes']))
          _buildSectionContainer("Brakes & Safety", [
            tf("Parking Brake", "parkingBrake", _parkingBrakeController),
            tf("ABS", "abs", _absController),
            tf("Front Crash Guard", "frontCrashGuard", _frontCrashGuardController),
            tf("Rear Crash Guard", "rearCrashGuard", _rearCrashGuardController),
            tf("Front Brake Condition", "frontBrakeCondition", _frontBrakeConditionController),
            tf("Rear Brake Condition", "rearBrakeCondition", _rearBrakeConditionController),
            tf("Right Individual Brakes", "rightIndividualBrakes", _rightIndividualBrakesController),
            tf("Left Individual Brakes", "leftIndividualBrakes", _leftIndividualBrakesController),
          ]),

        // ── 10. HYDRAULICS & LIFTING ────────────────────────────────────────
        if (hv(['hydraulicSystem', 'hydraulicLift', 'hydraulicLiftFe', 'boomArm',
                 'bucketCondition', 'bladeCondition', 'liftingCapacity',
                 'threePointLinkage', 'hitchSystem']))
          _buildSectionContainer("Hydraulics & Lifting", [
            tf("Hydraulic System", "hydraulicSystem", _hydraulicSystemController),
            tf("Hydraulic Lift", "hydraulicLift", _hydraulicLiftController),
            tf("Hydraulic Lift (FE)", "hydraulicLiftFe", _hydraulicLiftFeController),
            tf("Boom / Arm", "boomArm", _boomArmController),
            tf("Bucket Condition", "bucketCondition", _bucketConditionController),
            tf("Blade Condition", "bladeCondition", _bladeConditionController),
            tf("Lifting Capacity", "liftingCapacity", _liftingCapacityController),
            tf("Three Point Linkage", "threePointLinkage", _threePointLinkageController),
            tf("Hitch System", "hitchSystem", _hitchSystemController),
          ]),

        // ── 11. GROUND ENGAGEMENT & IMPLEMENTS ─────────────────────────────
        if (hv(['underCarriage', 'crawlerTracks', 'steelRims', 'tyreConditionCe',
                 'attachmentCondition', 'rockBreaker', 'implementAttachments',
                 'frontTyreCondition', 'rearTyreCondition', 'rearDrawbar']))
          _buildSectionContainer("Ground Engagement & Implements", [
            tf("Under Carriage", "underCarriage", _underCarriageController),
            tf("Crawler Tracks", "crawlerTracks", _crawlerTracksController),
            tf("Steel Rims", "steelRims", _steelRimsController),
            tf("Tyre Condition (CE)", "tyreConditionCe", _tyreConditionCeController),
            tf("Attachment Condition", "attachmentCondition", _attachmentConditionController),
            tf("Rock Breaker", "rockBreaker", _rockBreakerController),
            tf("Implement Attachments", "implementAttachments", _implementAttachmentsController),
            tf("Front Tyre Condition", "frontTyreCondition", _frontTyreConditionController),
            tf("Rear Tyre Condition", "rearTyreCondition", _rearTyreConditionController),
            tf("Rear Drawbar", "rearDrawbar", _rearDrawbarController),
          ]),

        // ── PAYMENT & REMARKS ───────────────────────────────────────────────
        _buildSectionContainer("Payment Collection", [
          if (canEdit)
            _buildDropdown("Payment Status", _paymentStatuses, _selectedPaymentStatus,
                (val) => setState(() => _selectedPaymentStatus = val), isMandatory: true)
          else
            _buildField("Payment Status", _selectedPaymentStatus ?? '', null, isEditable: false, isRequired: true),
          _buildField("Payment Reference", _paymentReferenceController.text, _paymentReferenceController, isEditable: canEdit),
          _buildDateField("Payment Date", _paymentDateController, canEdit, required: true),
          if (canEdit)
            _buildDropdown("Payment Method", _paymentMethods, _selectedPaymentMethod,
                (val) => setState(() => _selectedPaymentMethod = val), isMandatory: true)
          else
            _buildField("Payment Method", _selectedPaymentMethod ?? '', null, isEditable: false, isRequired: true),
          _buildField("Payment Amount", _paymentAmountController.text, _paymentAmountController,
              isEditable: canEdit, isRequired: true, keyboardType: TextInputType.number),
        ]),

        _buildSectionContainer("Remarks", [
          TextField(
              controller: _remarksController,
              readOnly: !canEdit,
              maxLines: 3,
              decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.all(12)))
        ]),

        _buildPhotoSection(),
        _buildNotesSection(),
        const SizedBox(height: 20),
        _buildAvoActions(),
      ]),
    );
  }

  Widget _buildRow(Widget left, Widget right) {
    return Padding(
        padding: const EdgeInsets.only(bottom: 0),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: left),
          Expanded(child: right)
        ]));
  }

  Widget _buildCheckbox(String label, bool value, Function(bool?) onChanged, bool isEditable) {
    return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 14)),
          Row(children: [
            Checkbox(value: value, onChanged: isEditable ? onChanged : null, activeColor: Colors.green),
            Text(value ? "YES" : "NO", style: const TextStyle(fontWeight: FontWeight.bold))
          ])
        ]));
  }

  Widget _buildDateField(String label, TextEditingController controller, bool isEditable, {bool required = false}) {
    return GestureDetector(
        onTap: isEditable ? () => _selectDate(controller) : null,
        child: AbsorbPointer(
            child: _buildField(label, controller.text, controller, isEditable: isEditable, isRequired: required)));
  }

  Widget _buildDocButton(String label, String? path, VoidCallback onTap, bool canEdit, {String type = 'RC'}) {
    return _buildViewDocRow(label, path, type, canEdit);
  }

  Widget _buildHeaderCard() {
    return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.grey.shade300)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text("Workflow Status", style: TextStyle(fontWeight: FontWeight.bold)),
            Text("$_currentTab View", style: const TextStyle(color: Colors.grey))
          ]),
          const SizedBox(height: 10),
          RichText(
              text: TextSpan(
                  style: const TextStyle(color: Colors.black, fontSize: 13, height: 1.6),
                  children: [
                const TextSpan(text: "Vehicle Number: ", style: TextStyle(fontWeight: FontWeight.bold)),
                TextSpan(text: "${widget.summaryData['vehicleNumber']} | "),
                const TextSpan(text: "Status: ", style: TextStyle(fontWeight: FontWeight.bold)),
                TextSpan(text: "${widget.summaryData['status']}")
              ])),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              _buildHeaderTabChip("Stake Holder", _currentTab == "Stakeholder"),
              const SizedBox(width: 8),
              _buildHeaderTabChip("Backend", _currentTab == "Backend"),
              const SizedBox(width: 8),
              _buildHeaderTabChip("AVO", _currentTab == "AVO"),
              const SizedBox(width: 8),
              _buildHeaderTabChip("QC", false,
                locked: currentUserRoleLevel < 4,
                onTap: currentUserRoleLevel >= 4 ? () {
                  Navigator.push(context, MaterialPageRoute(
                      builder: (_) => QcDetailPage(summaryData: widget.summaryData)));
                } : null,
              ),
              const SizedBox(width: 8),
              _buildHeaderTabChip("Final Report", false,
                locked: currentUserRoleLevel < 5,
                onTap: currentUserRoleLevel >= 5 ? () {
                  Navigator.push(context, MaterialPageRoute(
                      builder: (_) => FinalReportDetailPage(summaryData: widget.summaryData)));
                } : null,
              ),
            ]),
          )
        ]));
  }

  Widget _buildHeaderTabChip(String label, bool active,
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
        onTap: onTap ?? () {
          setState(() {
            _currentTab = label == "Stake Holder" ? "Stakeholder" : label;
            if (label == "Backend") _isBackendEditing = false;
            if (label == "AVO") _isAvoEditing = false;
            if (label == "Stake Holder") _isStakeholderEditing = false;
          });
        },
        child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration:
                BoxDecoration(color: active ? Colors.green : Colors.grey[200], borderRadius: BorderRadius.circular(4)),
            child: Text(label,
                style: TextStyle(color: active ? Colors.white : Colors.black, fontWeight: FontWeight.bold, fontSize: 12))));
  }

  Widget _buildPhotoSection() {
    return Container(
        margin: const EdgeInsets.symmetric(vertical: 20),
        child: ElevatedButton(
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => VehicleMediaPage(
                    valuationId: widget.summaryData['valuationId'] ?? "",
                    cameraOnly: true,
                    vehicleNumber: widget.summaryData['vehicleNumber']?.toString(),
                    applicantContact: widget.summaryData['applicantContact']?.toString()))),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3F51B5), foregroundColor: Colors.white),
            child: const Text("View / Upload Images")));
  }

  Widget _buildNotesSection() {
    return Container(
        margin: const EdgeInsets.only(bottom: 50),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.grey.shade300)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text("Inspection Notes (${_notes.length})",
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ElevatedButton(
                onPressed: _addNote,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                child: const Text("+ Add Note"))
          ]),
          const SizedBox(height: 15),
          TextField(
              controller: _noteController,
              decoration: const InputDecoration(
                  hintText: "Type a new note here...",
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8))),
          const SizedBox(height: 15),
          _notes.isEmpty
              ? const Center(child: Text("No notes yet.", style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)))
              : ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _notes.length,
                  separatorBuilder: (c, i) => const Divider(),
                  itemBuilder: (context, index) {
                    var note = _notes[index];
                    return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(note['note'] ?? "", style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                        subtitle: Text("${note['createdBy']} • ${_fmtDate(note['createdDate'])}",
                            style: const TextStyle(fontSize: 11, color: Colors.grey)));
                  })
        ]));
  }
}