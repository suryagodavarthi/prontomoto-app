import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/api_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import 'backend_dashboard.dart';
import 'avo_dashboard.dart';
import 'qc_dashboard.dart';
import 'finalreport_dashboard.dart';
import 'firebase_options.dart';

// ── Role-Based Access Control ─────────────────────────────────────────────────
// Set once at login; read by all dashboards and case-detail pages.
String currentUserRole = '';
int currentUserRoleLevel = 1; // 1=Stakeholder 2=Backend 3=AVO 4=QC 5=FinalReport

int roleLevelOf(String roleId) {
  final r = roleId.toLowerCase();
  switch (r) {
    case 'cancreatestakeholder':
    case 'stakeholder':
      return 1;
    case 'backend':
      return 2;
    case 'avo':
    case 'valuer':
      return 3;
    case 'caneditqualitycontrol':
    case 'qc':
      return 4;
    case 'finalreport':
    case 'admin':
    case 'superadmin':
    case 'stateadmin':
      return 5;
    default:
      // Fuzzy fallback — handles variations like "QualityControl", "AvoUser", etc.
      if (r.contains('final') || r.contains('admin')) return 5;
      if (r.contains('quality') || r.contains('qc')) return 4;
      if (r.contains('avo') || r.contains('valuer') || r.contains('inspection')) return 3;
      if (r.contains('backend')) return 2;
      return 1;
  }
}

int workflowLevelOf(String workflow) {
  final wf = workflow.toLowerCase();
  if (wf.contains('stakeholder')) return 1;
  if (wf.contains('backend')) return 2;
  if (wf.contains('avo') || wf.contains('inspection')) return 3;
  if (wf.contains('qc') || wf.contains('quality')) return 4;
  return 5; // final report or unknown
}

/// Navigate to a case capped at the current user's max accessible stage.
/// e.g. AVO user (level 3) opening a FinalReport case (level 5) → opens at AVO view.
void navigateToCase(
    BuildContext context, Map<String, dynamic> item, VoidCallback onReturn) {
  final int caseLevel = workflowLevelOf(item['workflow'] ?? '');
  final int effectiveLevel = caseLevel.clamp(1, currentUserRoleLevel);

  if (effectiveLevel >= 5) {
    Navigator.push(context,
        MaterialPageRoute(builder: (_) => FinalReportDetailPage(summaryData: item))).then((_) => onReturn());
  } else if (effectiveLevel >= 4) {
    Navigator.push(context,
        MaterialPageRoute(builder: (_) => QcDetailPage(summaryData: item))).then((_) => onReturn());
  } else if (effectiveLevel >= 3) {
    Navigator.push(context,
        MaterialPageRoute(builder: (_) => InspectionFormPage(summaryData: item))).then((_) => onReturn());
  } else if (effectiveLevel >= 2) {
    Navigator.push(context,
        MaterialPageRoute(builder: (_) => BackendCaseDetailsPage(summaryData: item))).then((_) => onReturn());
  } else {
    Navigator.push(context,
        MaterialPageRoute(builder: (_) => VehicleDetailsPage(summaryData: item))).then((_) => onReturn());
  }
}
// ─────────────────────────────────────────────────────────────────────────────

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint("Firebase Warning: $e");
  }
  runApp(const ProntoMotoApp());
}

class ProntoMotoApp extends StatelessWidget {
  const ProntoMotoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ProntoMoto',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.green,
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.white,
        fontFamily: 'Roboto',
      ),
      home: const LoginPage(),
    );
  }
}

// ===============================================================
// 1. LOGIN PAGE
// ===============================================================
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  final LocalAuthentication auth = LocalAuthentication();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  String? _verificationId;
  bool _isLoading = false;
  bool _codeSent = false; 
  String? _savedPhone; 
  String? _savedName;

  @override
  void initState() {
    super.initState();
    _checkSavedUser();
  }

  Future<void> _checkSavedUser() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _savedPhone = prefs.getString('saved_phone');
      _savedName = prefs.getString('saved_name');
    });
  }

  void _handleSendOtp() async {
    String phone = _phoneController.text.trim();
    if (phone.length < 10) return _showSnack("Enter valid 10-digit number", Colors.red);
    setState(() => _isLoading = true);
    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: "+91$phone",
        verificationCompleted: (PhoneAuthCredential credential) async {
          await _auth.signInWithCredential(credential);
          _verifyWithAzure(phone);
        },
        verificationFailed: (FirebaseAuthException e) {
          setState(() => _isLoading = false);
          _showSnack(e.message ?? "Verification Failed", Colors.red);
        },
        codeSent: (String verificationId, int? resendToken) {
          setState(() { _isLoading = false; _codeSent = true; _verificationId = verificationId; });
          _showSnack("OTP Sent", Colors.green);
        },
        codeAutoRetrievalTimeout: (String verificationId) => _verificationId = verificationId,
      );
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnack("Error: $e", Colors.red);
    }
  }

  void _handleVerifyOtp() async {
    String otp = _otpController.text.trim();
    if (otp.length != 6) return _showSnack("Enter 6-digit OTP", Colors.red);
    setState(() => _isLoading = true);
    try {
      PhoneAuthCredential credential = PhoneAuthProvider.credential(verificationId: _verificationId!, smsCode: otp);
      await _auth.signInWithCredential(credential);
      _verifyWithAzure(_phoneController.text.trim());
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnack("Invalid OTP", Colors.red);
    }
  }

  Future<void> _handleBiometricLogin() async {
    if (_savedPhone == null) return; 
    try {
      if (await auth.canCheckBiometrics) {
        if (await auth.authenticate(localizedReason: 'Login as $_savedName', biometricOnly: true)) {
          setState(() => _isLoading = true);
          _verifyWithAzure(_savedPhone!);
        }
      } else { _showSnack("Fingerprint not available", Colors.orange); }
    } catch (e) { _showSnack("Biometric Error: $e", Colors.red); }
  }

  void _verifyWithAzure(String phone) async {
    // Use the full +91 number from Firebase when available (matches stored phoneNumber field)
    final firebasePhone = FirebaseAuth.instance.currentUser?.phoneNumber;
    final lookupPhone = (firebasePhone != null && firebasePhone.isNotEmpty)
        ? firebasePhone
        : (phone.startsWith('+') ? phone : '+91$phone');

    ApiService api = ApiService();
    var result = await api.loginUser(lookupPhone);
    setState(() => _isLoading = false);

    if (result["success"] == true) {
      // roleId comes directly from the backend user document — no name-guessing
      final String roleId = result["role"].toString().toLowerCase();
      final String name = result["name"].toString();

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('saved_phone', lookupPhone);
      await prefs.setString('saved_name', name);
      await prefs.setString('saved_role', roleId);

      if (!mounted) return;

      // Set global role level used for access control across all pages
      currentUserRole = roleId;
      currentUserRoleLevel = roleLevelOf(roleId);

      // Route by computed level — inherits fuzzy matching from roleLevelOf.
      // backend/superadmin/stateadmin are kept on BackendDashboard even at level 5.
      if (roleId == 'backend' || roleId == 'superadmin' || roleId == 'stateadmin') {
        Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (context) => BackendDashboard(userName: name)));
      } else if (currentUserRoleLevel >= 5) {
        Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (context) => FinalReportDashboard(userName: name)));
      } else if (currentUserRoleLevel >= 4) {
        Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (context) => QcDashboard(userName: name)));
      } else if (currentUserRoleLevel >= 3) {
        Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (context) => AvoDashboard(userName: name)));
      } else if (currentUserRoleLevel >= 2) {
        Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (context) => BackendDashboard(userName: name)));
      } else {
        // Stakeholder and any other role
        Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (context) => StakeholderDashboard(userName: name)));
      }
    } else {
      _showSnack(result["message"] ?? "Login Failed", Colors.red);
      _auth.signOut();
    }
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              height: 300,
              decoration: const BoxDecoration(color: Colors.green, borderRadius: BorderRadius.only(bottomLeft: Radius.circular(50), bottomRight: Radius.circular(50))),
              child: Center(
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Container(padding: const EdgeInsets.all(15), decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle), child: const Icon(Icons.directions_car, size: 50, color: Colors.green)),
                    const SizedBox(height: 15),
                    const Text('ProntoMoto', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1.2)),
                    const Text('Valuation Dashboard', style: TextStyle(fontSize: 14, color: Colors.white70)),
                ]),
              ),
            ),
            const SizedBox(height: 40),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(_codeSent ? "Verification" : "Login", style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black87)),
                  const SizedBox(height: 8),
                  Text(_codeSent ? "Enter the code sent to your mobile" : "Please sign in to continue", style: TextStyle(fontSize: 14, color: Colors.grey[600])),
                  const SizedBox(height: 30),
                  if (!_codeSent) TextField(controller: _phoneController, keyboardType: TextInputType.phone, decoration: InputDecoration(prefixIcon: const Icon(Icons.phone, color: Colors.green), prefixText: "+91 ", labelText: "Phone Number", border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
                  if (_codeSent) TextField(controller: _otpController, keyboardType: TextInputType.number, textAlign: TextAlign.center, maxLength: 6, decoration: InputDecoration(counterText: "", hintText: "------", border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
                  const SizedBox(height: 30),
                  SizedBox(width: double.infinity, height: 55, child: ElevatedButton(onPressed: _isLoading ? null : (_codeSent ? _handleVerifyOtp : _handleSendOtp), style: ElevatedButton.styleFrom(backgroundColor: Colors.green, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : Text(_codeSent ? 'VERIFY & LOGIN' : 'SEND OTP', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)))),
                  if (_codeSent) ...[
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(
                        child: TextButton.icon(
                          onPressed: _isLoading ? null : () => setState(() { _codeSent = false; _otpController.clear(); }),
                          icon: const Icon(Icons.arrow_back, size: 16),
                          label: const Text("Change Number"),
                          style: TextButton.styleFrom(foregroundColor: Colors.grey),
                        ),
                      ),
                      Expanded(
                        child: TextButton(
                          onPressed: _isLoading ? null : _handleSendOtp,
                          style: TextButton.styleFrom(foregroundColor: Colors.green),
                          child: const Text("Resend OTP", style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ]),
                  ],
                  if (!_codeSent && _savedPhone != null) ...[const SizedBox(height: 30), const Row(children: [Expanded(child: Divider()), Padding(padding: EdgeInsets.symmetric(horizontal: 10), child: Text("OR")), Expanded(child: Divider())]), const SizedBox(height: 20), Center(child: GestureDetector(onTap: _handleBiometricLogin, child: Column(children: [Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), shape: BoxShape.circle, border: Border.all(color: Colors.green, width: 2)), child: const Icon(Icons.fingerprint, size: 40, color: Colors.green)), const SizedBox(height: 10), Text("Login as $_savedName", style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold))])))]
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

// ===============================================================
// 2. STAKEHOLDER DASHBOARD
// ===============================================================
class StakeholderDashboard extends StatefulWidget {
  final String userName;
  const StakeholderDashboard({super.key, required this.userName});

  @override
  State<StakeholderDashboard> createState() => _StakeholderDashboardState();
}

class _StakeholderDashboardState extends State<StakeholderDashboard> {
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
      // Filter to Stakeholder step only
      final filtered = all.where((c) {
        final wf = (c['workflow'] ?? "").toString().toLowerCase();
        return wf.contains("stakeholder");
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
            const Text("ProntoMoto", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18)),
            Text("Hello, ${widget.userName}", style: const TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh, color: Colors.black), onPressed: _loadDashboardData),
          IconButton(icon: const Icon(Icons.logout, color: Colors.red), onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if(context.mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginPage()));
          }),
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const CreateRequestPage())).then((_) => _loadDashboardData()),
        label: const Text("New Request"),
        icon: const Icon(Icons.add),
        backgroundColor: Colors.green,
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
    String status = item['workflow'] ?? "Stakeholder";
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

// ===============================================================
// 3. CREATE REQUEST PAGE
// ===============================================================
class CreateRequestPage extends StatefulWidget {
  const CreateRequestPage({super.key});

  @override
  State<CreateRequestPage> createState() => _CreateRequestPageState();
}

class _CreateRequestPageState extends State<CreateRequestPage> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isLoadingPincode = false; 
  bool _isSameAsContact = false;

  final _pincodeController = TextEditingController();
  final _executiveNameController = TextEditingController();
  final _contactController = TextEditingController();
  final _whatsappController = TextEditingController();
  final _emailController = TextEditingController();
  final _stakeholderNameController = TextEditingController();
  final _locationController = TextEditingController();
  final _cityController = TextEditingController();
  final _districtController = TextEditingController();
  final _divisionController = TextEditingController();
  final _stateController = TextEditingController();
  final _countryController = TextEditingController(text: "India");
  final _applicantNameController = TextEditingController();
  final _applicantContactController = TextEditingController();
  final _remarksController = TextEditingController();
  final _vehicleNoController = TextEditingController();
  final _vehicleSegmentController = TextEditingController();
  final _valuationTypeController = TextEditingController(); 

  String? _selectedStakeholder;
  String? _selectedValuationType;
  String? _selectedLocation;
  String? _rcPath;
  String? _insurancePath;
  String? _otherPath;

  List<String> _locationList = []; 
  final List<String> _stakeholderList = [
    "State Bank of India (SBI)", "HDFC Bank", "ICICI Bank", "Axis Bank", "IndusInd Bank",
    "Punjab National Bank (PNB)", "Federal Bank", "Union Bank of India", "Bank of Baroda",
    "IDFC FIRST Bank", "Karur Vysya Bank", "Kotak Mahindra Bank", "Mahindra Finance",
    "Bajaj Finserv", "Hero FinCorp", "TVS Credit Services", "Shriram Finance",
    "Muthoot Capital Services", "Cholamandalam Investment and Finance Company",
    "Sundaram Finance", "Manappuram Finance", "L&T Finance"
  ];
  final List<String> _valuationTypes = ["Four Wheeler", "Commercial Vehicle", "Two Wheeler", "Three Wheeler", "Tractor", "Construction Equipment"];

  @override
  void initState() {
    super.initState();
    _pincodeController.addListener(() {
      if (_pincodeController.text.length == 6) {
        _fetchPincodeDetails(_pincodeController.text);
      }
    });
  }

  @override
  void dispose() {
    _pincodeController.dispose();
    _executiveNameController.dispose();
    _contactController.dispose();
    _whatsappController.dispose();
    _emailController.dispose();
    _stakeholderNameController.dispose();
    _locationController.dispose();
    _cityController.dispose();
    _districtController.dispose();
    _divisionController.dispose();
    _stateController.dispose();
    _countryController.dispose();
    _applicantNameController.dispose();
    _applicantContactController.dispose();
    _remarksController.dispose();
    _vehicleNoController.dispose();
    _vehicleSegmentController.dispose();
    _valuationTypeController.dispose();
    super.dispose();
  }

  Future<void> _fetchPincodeDetails(String pincode) async {
    setState(() => _isLoadingPincode = true);
    try {
      // Uses backend GET /api/Pincodes/{pin} — matches Angular PincodeService
      final data = await ApiService().lookupPincode(pincode);
      if (data.isNotEmpty) {
            final firstOffice = data[0];
            setState(() {
              _cityController.text = firstOffice['block'] ?? "";
              _districtController.text = firstOffice['district'] ?? "";
              _divisionController.text = firstOffice['division'] ?? "";
              _stateController.text = firstOffice['state'] ?? "";
              _countryController.text = firstOffice['country'] ?? "India";
              _locationList = data.map<String>((office) => office['name'].toString()).toSet().toList();
              _selectedLocation = null;
            });

      } else {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Invalid Pincode"), backgroundColor: Colors.orange));
      }
    } catch (e) {
      debugPrint("Error fetching pincode: $e");
    } finally {
      setState(() => _isLoadingPincode = false);
    }
  }

  Future<void> _pickFile(String type) async {
    FilePickerResult? result = await FilePicker.pickFiles();
    if (result != null) {
      setState(() {
        if (type == 'RC') _rcPath = result.files.single.path;
        if (type == 'Insurance') _insurancePath = result.files.single.path;
        if (type == 'Other') _otherPath = result.files.single.path;
      });
    }
  }

  void _handleDataSubmission({required bool exitPage}) async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please fix the errors in red"), backgroundColor: Colors.red));
      return;
    }
    setState(() => _isLoading = true);
    
    Map<String, String> formData = {
      "Name": _selectedStakeholder ?? _stakeholderNameController.text,
      "ExecutiveName": _executiveNameController.text,
      "ExecutiveContact": _contactController.text,
      "ExecutiveWhatsapp": _whatsappController.text,
      "ExecutiveEmail": _emailController.text,
      "ValuationType": _selectedValuationType ?? _valuationTypeController.text,
      "VehicleSegment": _vehicleSegmentController.text,
      "LocationName": _selectedLocation ?? _locationController.text,
      "Block": _cityController.text,
      "District": _districtController.text,
      "Division": _divisionController.text,
      "State": _stateController.text,
      "Country": _countryController.text,
      "ApplicantName": _applicantNameController.text,
      "ApplicantContact": _applicantContactController.text,
      "Remarks": _remarksController.text,
      "VehicleNumber": _vehicleNoController.text,
      "Pincode": _pincodeController.text,
    };

    ApiService api = ApiService();
    var result = await api.createValuation(formData, rcPath: _rcPath, insurancePath: _insurancePath, otherPath: _otherPath);

    if (!mounted) return;

    if (result["success"] == true) {
      String newId = result["id"].toString();
      
      await api.startInitialWorkflow(newId, _vehicleNoController.text, _applicantContactController.text);

      if (exitPage) {
        var advanced = await api.advanceToNextStage(newId, 1, _vehicleNoController.text, _applicantContactController.text);
        if (!mounted) return;
        setState(() => _isLoading = false);
        if (advanced["success"] == true) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Successfully Submitted to Backend!"), backgroundColor: Colors.green));
          Navigator.pop(context);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Saved, but Submit failed: ${advanced['message']}"), backgroundColor: Colors.orange));
        }
      } else {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Draft Saved Successfully!"), backgroundColor: Colors.green));
      }
    } else {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result["message"] ?? "Unknown Error"), backgroundColor: Colors.red));
    }
  }

  void _toggleSameAsContact(bool? value) {
    setState(() {
      _isSameAsContact = value ?? false;
      if (_isSameAsContact) {
        _whatsappController.text = _contactController.text;
      } else {
        _whatsappController.clear();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text("Stakeholder New Request"), backgroundColor: const Color(0xFFFFFBE6), iconTheme: const IconThemeData(color: Colors.black)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
               _buildTextField("Pincode*", _pincodeController, inputType: TextInputType.number, maxLength: 6, isRequired: true),
               const SizedBox(height: 20),
               
               _buildAccordionSection(
                  title: "Stakeholder", 
                  isOpen: true,
                  children: [
                    _buildDropdown("Name of Stakeholder*", _stakeholderList, _selectedStakeholder, (val) => setState(() => _selectedStakeholder = val)),
                    const SizedBox(height: 10),
                    _buildTextField("Executive Name*", _executiveNameController, isRequired: true),
                    const SizedBox(height: 10),
                    _buildTextField("Contact Number", _contactController, inputType: TextInputType.phone, onChanged: (val) {
                      if (_isSameAsContact) setState(() => _whatsappController.text = val);
                    }),
                    const SizedBox(height: 10),
                    _buildTextField("WhatsApp Number", _whatsappController, inputType: TextInputType.phone),
                    Row(children: [Checkbox(value: _isSameAsContact, onChanged: _toggleSameAsContact, activeColor: Colors.green), const Text("Same as Contact Number", style: TextStyle(fontSize: 12, color: Colors.grey))]),
                    const SizedBox(height: 10),
                    _buildTextField("Email ID", _emailController, inputType: TextInputType.emailAddress),
                    const SizedBox(height: 10),
                    _buildDropdown("Valuation Type*", _valuationTypes, _selectedValuationType, (val) => setState(() => _selectedValuationType = val)),
                    const SizedBox(height: 15),
                    const Divider(),
                    const SizedBox(height: 5),
                    const Text("Address Details", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                    const SizedBox(height: 10),
                    
                    Row(children: [
                      Expanded(
                        child: _locationList.isEmpty 
                          ? _buildTextField("Location (Enter Pincode First)", _locationController, enabled: false)
                          : _buildDropdown("Location*", _locationList, _selectedLocation, (val) => setState(() => _selectedLocation = val))
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: _buildTextField("Block / City", _cityController)),
                    ]),
                    
                    const SizedBox(height: 10),
                    Row(children: [
                      Expanded(child: _buildTextField("District", _districtController)), 
                      const SizedBox(width: 10),
                      Expanded(child: _buildTextField("Division", _divisionController)), 
                    ]),
                    const SizedBox(height: 10),
                    Row(children: [
                      Expanded(child: _buildTextField("State", _stateController)), 
                      const SizedBox(width: 10),
                      Expanded(child: _buildTextField("Country", _countryController)), 
                    ]),
                  ]
               ),

               const SizedBox(height: 16),

               _buildAccordionSection(
                  title: "Applicant",
                  children: [
                    Row(children: [
                      Expanded(child: _buildTextField("Applicant Name*", _applicantNameController, isRequired: true)),
                      const SizedBox(width: 10),
                      Expanded(child: _buildTextField("Applicant Contact*", _applicantContactController, inputType: TextInputType.phone, isRequired: true)),
                    ]),
                  ]
               ),

               const SizedBox(height: 16),

               _buildAccordionSection(
                  title: "Remarks",
                  children: [
                    _buildTextField("Remarks", _remarksController, maxLines: 3),
                  ]
               ),

               const SizedBox(height: 16),

               _buildAccordionSection(
                  title: "Vehicle Details",
                  children: [
                    Row(children: [
                      Expanded(child: _buildTextField("Vehicle Number*", _vehicleNoController, isRequired: true)),
                      const SizedBox(width: 10),
                      Expanded(child: _buildTextField("Vehicle Segment", _vehicleSegmentController)),
                    ]),
                  ]
               ),

               const SizedBox(height: 16),

               _buildAccordionSection(
                  title: "Documents",
                  children: [
                    _buildFilePicker("Upload RC", "RC", _rcPath),
                    const SizedBox(height: 10),
                    _buildFilePicker("Upload Insurance", "Insurance", _insurancePath),
                    const SizedBox(height: 10),
                    _buildFilePicker("Upload Others", "Other", _otherPath),
                  ]
               ),

               const SizedBox(height: 30),

               Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : () => _handleDataSubmission(exitPage: false), 
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF4081), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 15)),
                      child: _isLoading ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text("Save"),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isLoading ? null : () => _handleDataSubmission(exitPage: true),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        side: const BorderSide(color: Colors.green),
                      ),
                      child: _isLoading ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(color: Colors.green, strokeWidth: 2)) : const Text("Submit", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 15)),
                      child: const Text("Cancel"),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 50),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAccordionSection({required String title, required List<Widget> children, bool isOpen = false}) {
    return Container(
      decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(5)),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: isOpen,
          title: Text(title, style: const TextStyle(fontSize: 18, color: Colors.black87)),
          childrenPadding: const EdgeInsets.all(16),
          children: children,
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, {int maxLines = 1, Function(String)? onChanged, TextInputType? inputType, bool enabled = true, int? maxLength, bool isRequired = false}) {
    return Container(
      color: enabled ? Colors.grey[100] : Colors.grey[200], 
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        onChanged: onChanged,
        keyboardType: inputType,
        enabled: enabled,
        maxLength: maxLength,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.grey[600]),
          border: const OutlineInputBorder(borderSide: BorderSide.none), 
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          counterText: "", 
        ),
        validator: (val) {
          if (isRequired || label.contains("*")) {
            if (val == null || val.trim().isEmpty) return "Required";
          }
          return null;
        },
      ),
    );
  }

  Widget _buildDropdown(String label, List<String> items, String? value, Function(String?) onChanged) {
    return Container(
      color: Colors.grey[100],
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: DropdownButtonFormField<String>(
        value: value,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.grey[600]),
          border: InputBorder.none,
        ),
        items: items.map((item) => DropdownMenuItem(value: item, child: Text(item, style: const TextStyle(fontSize: 13)))).toList(),
        onChanged: onChanged,
        validator: (val) {
          if (label.contains("*") && val == null) return "Required";
          return null;
        },
      ),
    );
  }

  Widget _buildFilePicker(String label, String type, String? path) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: Colors.grey[700], fontSize: 12)),
        const SizedBox(height: 5),
        Row(
          children: [
            OutlinedButton(
              onPressed: () => _pickFile(type),
              style: OutlinedButton.styleFrom(side: BorderSide(color: Colors.grey.shade400)),
              child: const Text("Choose File", style: TextStyle(color: Colors.black)),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(path != null ? path.split('/').last : "NO FILE CHOSEN", style: const TextStyle(color: Colors.grey, fontSize: 12), overflow: TextOverflow.ellipsis)),
          ],
        ),
      ],
    );
  }
}

// ===============================================================
// 4. VEHICLE DETAILS PAGE
// ===============================================================
class VehicleDetailsPage extends StatefulWidget {
  final Map<String, dynamic> summaryData; 
  const VehicleDetailsPage({super.key, required this.summaryData});

  @override
  State<VehicleDetailsPage> createState() => _VehicleDetailsPageState();
}

class _VehicleDetailsPageState extends State<VehicleDetailsPage> {
  ApiService api = ApiService();
  bool _isLoading = true;
  bool _isEditing = false;
  
  bool _isSavingDraft = false; 
  bool _isSubmitting = false;
  
  bool _sameAsContact = false;
  
  Map<String, dynamic> _fullData = {};
  List<dynamic> _notes = [];

  final List<String> _stakeholderList = [
    "State Bank of India (SBI)", "HDFC Bank", "ICICI Bank", "Axis Bank", "IndusInd Bank", 
    "Punjab National Bank (PNB)", "Federal Bank", "Union Bank of India", "Bank of Baroda", 
    "IDFC FIRST Bank", "Karur Vysya Bank", "Kotak Mahindra Bank", "Mahindra Finance", 
    "Bajaj Finserv", "Hero FinCorp", "TVS Credit Services", "Shriram Finance", 
    "Muthoot Capital Services", "Cholamandalam Investment and Finance Company", 
    "Sundaram Finance", "Manappuram Finance", "L&T Finance"
  ];
  final List<String> _valuationTypes = ["Four Wheeler", "Commercial Vehicle", "Two Wheeler", "Three Wheeler", "Tractor", "Construction Equipment"];
  
  List<dynamic> _pincodeLocations = []; 
  List<String> _locationNames = []; 
  
  String? _selectedStakeholder, _selectedValuationType, _selectedRcPath, _selectedInsurancePath, _selectedOtherPath;
  String? _selectedLocationName; 
  
  final _executiveNameController = TextEditingController(); 
  final _contactController = TextEditingController(); 
  final _whatsappController = TextEditingController(); 
  final _emailController = TextEditingController();
  
  final _pincodeController = TextEditingController(); 
  final _locationController = TextEditingController(); 
  final _blockController = TextEditingController(); 
  final _districtController = TextEditingController(); 
  final _divisionController = TextEditingController(); 
  final _stateController = TextEditingController(); 
  final _countryController = TextEditingController();
  
  final _applicantNameController = TextEditingController(); 
  final _applicantContactController = TextEditingController(); 
  final _remarksController = TextEditingController();
  
  final _vehicleNoController = TextEditingController(); 
  final _vehicleSegmentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _contactController.addListener(() {
      if (_sameAsContact) {
        _whatsappController.text = _contactController.text;
      }
    });
    _loadFullDetails();
  }

  @override
  void dispose() {
    _executiveNameController.dispose();
    _contactController.dispose();
    _whatsappController.dispose();
    _emailController.dispose();
    _pincodeController.dispose();
    _locationController.dispose();
    _blockController.dispose();
    _districtController.dispose();
    _divisionController.dispose();
    _stateController.dispose();
    _countryController.dispose();
    _applicantNameController.dispose();
    _applicantContactController.dispose();
    _remarksController.dispose();
    _vehicleNoController.dispose();
    _vehicleSegmentController.dispose();
    super.dispose();
  }

  Future<void> _loadFullDetails() async {
    String id = widget.summaryData['valuationId'] ?? widget.summaryData['id'] ?? "";
    String vehicleNo = widget.summaryData['vehicleNumber'] ?? widget.summaryData['VehicleNumber'] ?? "";
    String contact = widget.summaryData['applicantContact'] ?? widget.summaryData['ApplicantContact'] ?? "";
    
    if (id.isEmpty) { setState(() => _isLoading = false); return; }
    
    var details = await api.getValuationDetails(id, vehicleNo, contact);
    var fetchedNotes = await api.getNotes(id);

    if (mounted) {
      setState(() {
        _fullData = details;
        _notes = fetchedNotes;
        _populateControllers();
      });
      if (_pincodeController.text.length == 6) {
        await _fetchLocationsForPincode(_pincodeController.text);
      }
      setState(() => _isLoading = false);
    }
  }

  void _populateControllers() {
    var d = {...widget.summaryData, ..._fullData}; 
    
    _executiveNameController.text = _getUniversalValue(d, ['ExecutiveName', 'executiveName', 'Executive']);
    _contactController.text = _getUniversalValue(d, ['ExecutiveContact', 'executiveContact', 'contactNumber', 'Mobile', 'Contact']);
    _whatsappController.text = _getUniversalValue(d, ['ExecutiveWhatsapp', 'executiveWhatsapp', 'whatsappNumber', 'Whatsapp']);
    _emailController.text = _getUniversalValue(d, ['ExecutiveEmail', 'executiveEmail', 'email', 'Email']);
    
    if (_contactController.text.isNotEmpty && _contactController.text == _whatsappController.text) {
      _sameAsContact = true;
    }

    _pincodeController.text = _getUniversalValue(d, ['Pincode', 'pincode', 'vehicleLocation.pincode', 'Pin']);
    
    String locName = _getUniversalValue(d, ['LocationName', 'locationName', 'Location', 'location', 'vehicleLocation.name']);
    _locationController.text = locName;
    _selectedLocationName = locName.isNotEmpty ? locName : null;

    _blockController.text = _getUniversalValue(d, ['Block', 'block', 'city', 'City', 'vehicleLocation.block']);
    _districtController.text = _getUniversalValue(d, ['District', 'district', 'vehicleLocation.district']);
    _divisionController.text = _getUniversalValue(d, ['Division', 'division', 'vehicleLocation.division']);
    _stateController.text = _getUniversalValue(d, ['State', 'state', 'vehicleLocation.state']);
    _countryController.text = _getUniversalValue(d, ['Country', 'country', 'vehicleLocation.country']);
    
    _applicantNameController.text = _getUniversalValue(d, ['ApplicantName', 'applicantName', 'applicant.name']);
    _applicantContactController.text = _getUniversalValue(d, ['ApplicantContact', 'applicantContact', 'applicant.contact']);
    _remarksController.text = _getUniversalValue(d, ['Remarks', 'remarks']);
    
    _vehicleNoController.text = _getUniversalValue(d, ['VehicleNumber', 'vehicleNumber']);
    _vehicleSegmentController.text = _getUniversalValue(d, ['VehicleSegment', 'vehicleSegment']);

    String currentStakeholder = _getUniversalValue(d, ['Name', 'stakeholderName', 'name', 'stakeholder.name']);
    if (_stakeholderList.contains(currentStakeholder)) _selectedStakeholder = currentStakeholder;
    
    String currentValType = _getUniversalValue(d, ['ValuationType', 'valuationType']);
    if (_valuationTypes.contains(currentValType)) _selectedValuationType = currentValType;
  }

  Future<void> _fetchLocationsForPincode(String val) async {
    try {
      // Uses backend GET /api/Pincodes/{pin} via ApiService — matches Angular PincodeService
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
    } catch (e) { debugPrint("Pincode fetch error: $e"); }
  }

  void _onPincodeChanged(String val) {
    if (val.length == 6) {
      _fetchLocationsForPincode(val);
    }
  }

  void _onLocationSelected(String? locName) {
    if (locName == null) return;
    setState(() {
      _selectedLocationName = locName;
      _locationController.text = locName; 
      var locData = _pincodeLocations.firstWhere((e) => e['name'] == locName, orElse: () => null);
      if (locData != null) {
        _blockController.text = locData['block'] ?? "";
        _districtController.text = locData['district'] ?? "";
        _divisionController.text = locData['division'] ?? "";
        _stateController.text = locData['state'] ?? "";
        _countryController.text = locData['country'] ?? "";
      }
    });
  }

  String _getUniversalValue(Map<String, dynamic> data, List<String> keys) {
    for (String key in keys) {
      if (data[key] != null && data[key].toString() != "null" && data[key].toString().isNotEmpty) return data[key].toString();
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
             if (match != null) current = current[match]; else { found = false; break; }
          } else { found = false; break; }
        }
        if (found && current != null && current.toString().isNotEmpty && current.toString() != "null") return current.toString();
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

  void _toggleEdit() { setState(() => _isEditing = !_isEditing); }

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

  Future<void> _handleSave() async {
    if (!_validateMandatory()) return;
    setState(() => _isSavingDraft = true);
    await _performUpdate(isSubmit: false);
  }

  Future<void> _handleSubmit() async {
    if (!_validateMandatory()) return;
    setState(() => _isSubmitting = true);
    await _performUpdate(isSubmit: true);
  }

  Future<void> _directSubmit() async {
    // Delegates to handleSubmit which validates, saves form, then advances workflow
    await _handleSubmit();
  }

  bool _validateMandatory() {
    if (_pincodeController.text.trim().isEmpty) return _showError("Pincode is required");
    if (_isEditing && _locationController.text.trim().isEmpty) return _showError("Location is required");
    if (_selectedStakeholder == null && (_getUniversalValue({...widget.summaryData, ..._fullData}, ['Name']).isEmpty)) return _showError("Stakeholder Name is required");
    if (_executiveNameController.text.trim().isEmpty) return _showError("Executive Name is required");
    if (_contactController.text.trim().isEmpty) return _showError("Contact Number is required");
    if (_applicantNameController.text.trim().isEmpty) return _showError("Applicant Name is required");
    if (_applicantContactController.text.trim().isEmpty) return _showError("Applicant Contact is required");
    if (_vehicleNoController.text.trim().isEmpty) return _showError("Vehicle Number is required");
    if (_vehicleSegmentController.text.trim().isEmpty) return _showError("Vehicle Segment is required");
    return true;
  }

  bool _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
    return false;
  }

  Future<void> _performUpdate({required bool isSubmit}) async {
    String id = widget.summaryData['valuationId'] ?? widget.summaryData['id'] ?? "";
    var d = {...widget.summaryData, ..._fullData};
    String currentStakeholderName = _selectedStakeholder ?? _getUniversalValue(d, ['Name', 'stakeholderName']);

    Map<String, String> formData = {
      "ValuationId": id, 
      "Name": currentStakeholderName, 
      "ExecutiveName": _executiveNameController.text,
      "ExecutiveContact": _contactController.text, 
      "ExecutiveWhatsapp": _whatsappController.text,
      "ExecutiveEmail": _emailController.text,
      "ValuationType": _selectedValuationType ?? _getUniversalValue(d, ['ValuationType', 'valuationType']),
      "VehicleSegment": _vehicleSegmentController.text,
      "LocationName": _locationController.text, 
      "Block": _blockController.text,
      "District": _districtController.text,
      "Division": _divisionController.text,
      "State": _stateController.text,
      "Country": _countryController.text,
      "ApplicantName": _applicantNameController.text,
      "ApplicantContact": _applicantContactController.text,
      "Remarks": _remarksController.text,
      "VehicleNumber": _vehicleNoController.text,
      "Pincode": _pincodeController.text,
    };

    String? existingRc = _findFileUrl(d, 'RC');
    String? existingIns = _findFileUrl(d, 'Insurance');
    String? existingOth = _findFileUrl(d, 'Other');
    
    if (_selectedRcPath == null && existingRc != null) formData['RcFile'] = existingRc;
    if (_selectedInsurancePath == null && existingIns != null) formData['InsuranceFile'] = existingIns;
    if (_selectedOtherPath == null && existingOth != null) formData['OtherFiles'] = existingOth;

    var result = await api.updateValuation(id, formData, rcPath: _selectedRcPath, insurancePath: _selectedInsurancePath, otherPath: _selectedOtherPath);

    if (!mounted) return;

    if (result["success"] == true) {
      if (isSubmit) {
        int stepOrder = widget.summaryData['workflowStepOrder'] ?? widget.summaryData['stepOrder'] ?? 1;
        
        String vNo = _vehicleNoController.text.trim();
        if (vNo.isEmpty) vNo = _getUniversalValue(d, ['VehicleNumber', 'vehicleNumber']);
        if (vNo.isEmpty) vNo = "UNKNOWN";

        String contact = _applicantContactController.text.trim();
        if (contact.isEmpty) contact = _getUniversalValue(d, ['ApplicantContact', 'applicantContact']);
        if (contact.isEmpty) contact = "0000000000";

        await api.startInitialWorkflow(id, vNo, contact);

        var advanceResult = await api.advanceToNextStage(id, stepOrder, vNo, contact);
        
        if (!mounted) return;
        setState(() { _isSavingDraft = false; _isSubmitting = false; });

        if (advanceResult["success"] == true) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Submitted to Backend!"), backgroundColor: Colors.green));
          Navigator.pop(context); 
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Saved, but Submit failed: ${advanceResult['message']}"), backgroundColor: Colors.orange));
        }
      } else {
        // --- ADDED RE-FETCH TO PREVENT UI FROM BLANKING OUT ---
        await _loadFullDetails();

        setState(() { _isSavingDraft = false; _isSubmitting = false; _isEditing = false; _selectedRcPath=null; _selectedInsurancePath=null; _selectedOtherPath=null; });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Saved Successfully!"), backgroundColor: Colors.green));
      }
    } else {
      setState(() { _isSavingDraft = false; _isSubmitting = false; });
      String err = (result["message"] ?? "Unknown Error").toString();
      if (err.contains("LocationName")) err = "Location Name is required";
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $err"), backgroundColor: Colors.red));
    }
  }

  void _showAddNoteDialog() {
    TextEditingController noteController = TextEditingController();
    showDialog(context: context, builder: (ctx) => AlertDialog(
        title: const Text("Add Note"),
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

  Future<void> _launchDownload(String? url) async {
    if (url != null && url.startsWith("http")) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No document URL available")));
    }
  }

  // --- UI HELPERS ---
  Widget _buildField(String label, String value, TextEditingController? controller, {Function(String)? onChanged, bool readOnly = false, bool isMandatory = false}) {
    Widget labelWidget = RichText(text: TextSpan(text: label, style: TextStyle(color: Colors.grey[600], fontSize: 14), children: [if(isMandatory) const TextSpan(text: " *", style: TextStyle(color: Colors.red))]));
    if (_isEditing && controller != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), 
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [labelWidget, const SizedBox(height: 6), TextField(controller: controller, onChanged: onChanged, readOnly: readOnly, decoration: InputDecoration(border: const OutlineInputBorder(), isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12), filled: readOnly, fillColor: readOnly ? Colors.grey[200] : Colors.white))])
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
  
  Widget _buildStageChip(String label, bool active,
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
          Text(label, style: TextStyle(color: Colors.grey[400], fontSize: 12, fontWeight: FontWeight.w500)),
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

  Widget _buildSection({required String title, required List<Widget> children, bool isOpen = false}) {
    return Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade300)), child: ExpansionTile(initiallyExpanded: isOpen, title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)), children: children));
  }
  
  Widget _buildDocRow(String label, String? url, String type) {
    var d = {...widget.summaryData, ..._fullData};
    String? foundUrl = url ?? _findFileUrl(d, type);
    bool hasFile = foundUrl != null && foundUrl.startsWith("http");
    String? newPath;
    if (type == 'RC') newPath = _selectedRcPath;
    if (type == 'Insurance') newPath = _selectedInsurancePath;
    if (type == 'Other') newPath = _selectedOtherPath;

    return Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Expanded(flex: 2, child: Text(label, style: const TextStyle(fontWeight: FontWeight.w500))), Expanded(flex: 3, child: Row(children: [Expanded(child: Text(newPath != null ? "New: ${newPath.split('/').last}" : (hasFile ? "Existing File" : "No File"), style: TextStyle(color: newPath != null ? Colors.blue : (hasFile ? Colors.green : Colors.grey), fontSize: 12, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)), if (_isEditing) IconButton(icon: const Icon(Icons.upload_file, color: Colors.blue), onPressed: () => _pickFile(type)) else if (hasFile) InkWell(onTap: () => _launchDownload(foundUrl), child: const Text("Download", style: TextStyle(color: Colors.blue, decoration: TextDecoration.underline)))]))]));
  }

  @override
  Widget build(BuildContext context) {
    var d = {...widget.summaryData, ..._fullData};
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(title: const Text("Valuation Details", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)), backgroundColor: Colors.white, elevation: 0, iconTheme: const IconThemeData(color: Colors.black)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade300)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Text("Workflow Status", style: TextStyle(fontWeight: FontWeight.bold)),
                  const Text("Stakeholder — step 1", style: TextStyle(color: Colors.grey)),
                ]),
                const Divider(height: 16),
                Text("Vehicle: ${_vehicleNoController.text}", style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(children: [
                    _buildStageChip("Stake Holder", true),
                    const SizedBox(width: 8),
                    _buildStageChip("Backend", false,
                      locked: currentUserRoleLevel < 2,
                      onTap: currentUserRoleLevel >= 2 ? () => Navigator.push(context, MaterialPageRoute(builder: (_) => BackendCaseDetailsPage(summaryData: widget.summaryData))) : null,
                    ),
                    const SizedBox(width: 8),
                    _buildStageChip("AVO", false,
                      locked: currentUserRoleLevel < 3,
                      onTap: currentUserRoleLevel >= 3 ? () => Navigator.push(context, MaterialPageRoute(builder: (_) => InspectionFormPage(summaryData: widget.summaryData, initialTab: "AVO"))) : null,
                    ),
                    const SizedBox(width: 8),
                    _buildStageChip("QC", false,
                      locked: currentUserRoleLevel < 4,
                      onTap: currentUserRoleLevel >= 4 ? () => Navigator.push(context, MaterialPageRoute(builder: (_) => QcDetailPage(summaryData: widget.summaryData))) : null,
                    ),
                    const SizedBox(width: 8),
                    _buildStageChip("Final Report", false,
                      locked: currentUserRoleLevel < 5,
                      onTap: currentUserRoleLevel >= 5 ? () => Navigator.push(context, MaterialPageRoute(builder: (_) => FinalReportDetailPage(summaryData: widget.summaryData))) : null,
                    ),
                  ]),
                ),
              ]),
            ),
            const SizedBox(height: 15),
            
            if (!_isEditing)
              Row(children: [
                Expanded(child: ElevatedButton(onPressed: _toggleEdit, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3F51B5), foregroundColor: Colors.white), child: const Text("Edit"))), 
                const SizedBox(width: 8), 
                Expanded(child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _directSubmit,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                  child: _isSubmitting ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text("Submit")
                )),
                const SizedBox(width: 8), 
                Expanded(child: ElevatedButton(onPressed: () => Navigator.pop(context), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF4081), foregroundColor: Colors.white), child: const Text("Back")))
              ]),
            const SizedBox(height: 20),

            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 15),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade300)),
              child: _buildField("Pincode", "", _pincodeController, onChanged: _onPincodeChanged, isMandatory: true),
            ),

            _buildSection(title: "Stakeholder", isOpen: true, children: [
               if (_isEditing) _buildDropdown("Name of Stakeholder", _stakeholderList, _selectedStakeholder, (val) => setState(() => _selectedStakeholder = val), isMandatory: true) else _buildField("Name of Stakeholder", _getUniversalValue(d, ['Name', 'stakeholderName', 'name']), null, isMandatory: true),
               _buildField("Executive Name", "", _executiveNameController, isMandatory: true),
               _buildField("Contact Number", "", _contactController, isMandatory: true),
               
               if (_isEditing) Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Row(children: [Checkbox(value: _sameAsContact, activeColor: Colors.blue, onChanged: (v) { setState(() { _sameAsContact = v!; if(_sameAsContact) _whatsappController.text = _contactController.text; }); }), const Text("Same as Contact Number", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold))])),
               
               _buildField("WhatsApp Number", "", _whatsappController, readOnly: _sameAsContact),
               
               _buildField("Email ID", "", _emailController),
               if (_isEditing) _buildDropdown("Valuation Type", _valuationTypes, _selectedValuationType, (val) => setState(() => _selectedValuationType = val)) else _buildField("Valuation Type", _getUniversalValue(d, ['ValuationType', 'valuationType']), null),
               
               if (_isEditing) ...[
                 if (_locationNames.isNotEmpty) 
                   _buildDropdown("Location", _locationNames, _selectedLocationName, _onLocationSelected, isMandatory: true)
                 else 
                   _buildField("Location", _locationController.text, _locationController, isMandatory: true),
               ] else ...[
                 _buildField("Pincode", "", _pincodeController),
               ],

               _buildField("Block / City", "", _blockController, readOnly: true),
               _buildField("District", "", _districtController, readOnly: true),
               _buildField("Division", "", _divisionController, readOnly: true),
               _buildField("State", "", _stateController, readOnly: true),
               _buildField("Country", "", _countryController, readOnly: true),
            ]),
            const SizedBox(height: 10),

            _buildSection(title: "Applicant", children: [_buildField("Applicant Name", "", _applicantNameController, isMandatory: true), _buildField("Applicant Contact", "", _applicantContactController, isMandatory: true)]),
            const SizedBox(height: 10),

            _buildSection(title: "Vehicle Details", children: [_buildField("Vehicle Number", "", _vehicleNoController, isMandatory: true), _buildField("Vehicle Segment", "", _vehicleSegmentController, isMandatory: true)]),
            const SizedBox(height: 10),

            _buildSection(title: "Remarks", children: [_buildField("Remarks", "", _remarksController)]),
            const SizedBox(height: 10),

            _buildSection(title: "Documents", isOpen: true, children: [
              _buildDocRow("RC", _findFileUrl(d, 'RC'), 'RC'),
              _buildDocRow("Insurance", _findFileUrl(d, 'Insurance'), 'Insurance'),
              _buildDocRow("Other", _findFileUrl(d, 'Other'), 'Other'),
            ]),
            const SizedBox(height: 20),
            
            if (_isEditing)
              Row(children: [
                Expanded(child: ElevatedButton(onPressed: (_isSavingDraft || _isSubmitting) ? null : _handleSave, style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12)), child: _isSavingDraft ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text("SAVE"))),
                const SizedBox(width: 8),
                Expanded(child: ElevatedButton(onPressed: (_isSavingDraft || _isSubmitting) ? null : _handleSubmit, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3F51B5), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12)), child: _isSubmitting ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text("SUBMIT"))),
                const SizedBox(width: 8),
                Expanded(child: ElevatedButton(onPressed: (_isSavingDraft || _isSubmitting) ? null : _toggleEdit, style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12)), child: const Text("CANCEL"))),
              ]),
            
            const SizedBox(height: 20),
            Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade300)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text("Stakeholder Notes (${_notes.length})", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), ElevatedButton.icon(onPressed: _showAddNoteDialog, icon: const Icon(Icons.add, size: 16, color: Colors.white), label: const Text("Add Note", style: TextStyle(color: Colors.white)), style: ElevatedButton.styleFrom(backgroundColor: Colors.green))]), const Divider(), if (_notes.isEmpty) const Padding(padding: EdgeInsets.all(20), child: Center(child: Text("No notes yet.", style: TextStyle(color: Colors.grey)))) else for (var n in _notes) ListTile(title: Text(n['note'].toString()), subtitle: Text(n['createdDate'].toString()), leading: const Icon(Icons.comment))])),
          ],
        ),
      ),
    );
  }
}