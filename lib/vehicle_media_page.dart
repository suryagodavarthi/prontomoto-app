import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'services/api_service.dart';

class VehicleMediaPage extends StatefulWidget {
  final String valuationId;
  final Map<String, dynamic> existingImages; 
  
  const VehicleMediaPage({super.key, required this.valuationId, this.existingImages = const {}});

  @override
  State<VehicleMediaPage> createState() => _VehicleMediaPageState();
}

class _VehicleMediaPageState extends State<VehicleMediaPage> {
  bool _isSyncing = false;
  bool _isLoadingData = true;
  String _vNo = "";
  String _contact = "";

  Map<String, String> _serverImages = {};

  final Map<String, String?> _localFiles = {
    "Front Left Side": null,
    "Front Right Side": null,
    "Rear Left Side": null,
    "Rear Right Side": null,
    "Front View (grille)": null,
    "Rear View (tailgate)": null,
    "Driver's Side Profile": null,
    "Passenger Side Profile": null,
    "Dashboard": null,
    "Instrument Cluster": null,
    "Engine Bay": null,
    "Chassis Number Plate": null,
    "Chassis Imprint": null,
    "Gear and Seats": null,
    "Dashboard Close-up": null,
    "Odometer": null,
    "Selfie with Vehicle": null,
    "Underbody": null,
    "Tires and Rims": null,
    "Vehicle Video": null,
  };

  // Maps the UI labels to the exact DTO properties expected by the .NET API
  final Map<String, String> _backendKeys = {
    "Front Left Side": "FrontLeftSide",
    "Front Right Side": "FrontRightSide",
    "Rear Left Side": "RearLeftSide",
    "Rear Right Side": "RearRightSide",
    "Front View (grille)": "FrontViewGrille",
    "Rear View (tailgate)": "RearViewTailgate",
    "Driver's Side Profile": "DriverSideProfile",
    "Passenger Side Profile": "PassengerSideProfile",
    "Dashboard": "Dashboard",
    "Instrument Cluster": "InstrumentCluster",
    "Engine Bay": "EngineBay",
    "Chassis Number Plate": "ChassisNumberPlate",
    "Chassis Imprint": "ChassisImprint",
    "Gear and Seats": "GearAndSeats",
    "Dashboard Close-up": "DashboardCloseup",
    "Odometer": "Odometer",
    "Selfie with Vehicle": "SelfieWithVehicle",
    "Underbody": "Underbody",
    "Tires and Rims": "TiresAndRims",
    "Vehicle Video": "VehicleVideo",
  };

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    widget.existingImages.forEach((key, value) {
      if (value != null && value.toString().isNotEmpty) {
        _serverImages[key] = value.toString();
      }
    });

    try {
      var openCases = await ApiService().getOpenValuations();
      var currentCase = openCases.firstWhere((c) => (c['valuationId'] ?? c['id']) == widget.valuationId, orElse: () => null);
      
      if (currentCase != null) {
        _vNo = currentCase['vehicleNumber'] ?? "";
        _contact = currentCase['applicantContact'] ?? "";
        await _fetchLatestPhotosFromServer();
      }
    } catch (e) {
      print("Init error: $e");
    } finally {
      if (mounted) setState(() => _isLoadingData = false);
    }
  }

  Future<void> _fetchLatestPhotosFromServer() async {
    if (_vNo.isEmpty) return;
    try {
      final uri = Uri.parse('${ApiService().baseUrl}/valuations/${widget.valuationId}/photos').replace(
        queryParameters: {"vehicleNumber": _vNo.trim(), "applicantContact": _contact.trim()}
      );
      final response = await http.get(uri);
      
      if (response.statusCode == 200) {
        Map<String, dynamic> data = jsonDecode(response.body);
        setState(() {
          data.forEach((k, v) {
            if (v != null && v.toString().isNotEmpty) _serverImages[k] = v.toString();
          });
        });
      }
    } catch (e) {
      print("Failed to fetch latest photos: $e");
    }
  }

  Future<void> _pickMedia(String key, {bool isVideo = false}) async {
    // FIXED: Removed .platform to fix compile error
    FilePickerResult? result = await FilePicker.pickFiles(
      type: isVideo ? FileType.video : FileType.image,
    );

    if (result != null && result.files.single.path != null) {
      setState(() {
        _localFiles[key] = result.files.single.path;
      });
    }
  }

  Future<void> _syncMedia() async {
    bool hasFilesToUpload = _localFiles.values.any((path) => path != null);
    if (!hasFilesToUpload) {
      Navigator.pop(context);
      return;
    }

    if (_vNo.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Error: Cannot upload without Vehicle Number context."), backgroundColor: Colors.red));
      return;
    }

    setState(() => _isSyncing = true);

    try {
      var uri = Uri.parse('${ApiService().baseUrl}/valuations/${widget.valuationId}/photos');
      var request = http.MultipartRequest('PUT', uri);

      request.fields['ValuationId'] = widget.valuationId;
      request.fields['VehicleNumber'] = _vNo;
      request.fields['ApplicantContact'] = _contact;

      for (var entry in _localFiles.entries) {
        if (entry.value != null) {
          String backendKey = _backendKeys[entry.key]!;
          request.files.add(await http.MultipartFile.fromPath(backendKey, entry.value!));
        }
      }

      var response = await request.send();

      if (response.statusCode == 200 || response.statusCode == 204) {
        setState(() {
          _localFiles.updateAll((key, value) => null);
        });
        await _fetchLatestPhotosFromServer();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Upload Successful!"), backgroundColor: Colors.green));
        }
      } else {
        String respStr = await response.stream.bytesToString();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Upload failed (${response.statusCode}): $respStr"), backgroundColor: Colors.red));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Connection Error: $e"), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  String? _getBackendUrl(String title) {
    String backendKey = _backendKeys[title]!;
    for (var key in _serverImages.keys) {
      if (key.toLowerCase() == backendKey.toLowerCase()) {
        return _serverImages[key];
      }
    }
    return null;
  }

  Widget _buildMediaCard(String title, {bool isVideo = false}) {
    String? localPath = _localFiles[title];
    String? backendUrl = _getBackendUrl(title);

    bool hasLocal = localPath != null;
    bool hasBackend = backendUrl != null && backendUrl.startsWith("http");

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(8),
              color: Colors.grey[200],
              child: Center(
                child: hasLocal
                    ? (isVideo 
                        ? const Icon(Icons.videocam, size: 40, color: Colors.blue) 
                        : Image.file(
                            File(localPath), 
                            fit: BoxFit.cover,
                            errorBuilder: (c, o, s) => const Icon(Icons.broken_image, color: Colors.red),
                          ))
                    : hasBackend 
                        ? (isVideo
                            ? const Icon(Icons.check_circle, size: 40, color: Colors.green)
                            : Image.network(backendUrl, fit: BoxFit.cover, errorBuilder: (c,o,s) => const Icon(Icons.broken_image, color: Colors.red)))
                        : Text("No Image", style: TextStyle(color: Colors.grey[400], fontSize: 10)),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600), maxLines: 2, overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 28,
            width: 80,
            child: OutlinedButton(
              onPressed: _isSyncing ? null : () => _pickMedia(title, isVideo: isVideo),
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.zero,
                side: BorderSide(color: hasLocal ? Colors.blue : Colors.grey.shade400),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              ),
              child: Text(hasLocal ? "Change" : "Browse", style: TextStyle(fontSize: 10, color: hasLocal ? Colors.blue : Colors.black87)),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    int pendingCount = _localFiles.values.where((p) => p != null).length;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Vehicle Media Upload", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.green,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoadingData 
        ? const Center(child: CircularProgressIndicator()) 
        : SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                if (pendingCount > 0)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(color: Colors.orange.shade50, border: Border.all(color: Colors.orange), borderRadius: BorderRadius.circular(8)),
                    child: Text("$pendingCount files selected. Tap 'Upload & Save' to sync to server.", style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
                  ),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2, 
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 0.9,
                  ),
                  itemCount: _localFiles.length,
                  itemBuilder: (context, index) {
                    String key = _localFiles.keys.elementAt(index);
                    return _buildMediaCard(key, isVideo: key.contains("Video"));
                  },
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: pendingCount > 0 ? const Color(0xFF3F51B5) : Colors.grey), 
                    onPressed: _isSyncing ? null : _syncMedia,
                    child: _isSyncing 
                        ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text(pendingCount > 0 ? "Upload & Save ($pendingCount)" : "Back to Dashboard", style: const TextStyle(color: Colors.white, fontSize: 16)),
                  ),
                ),
                 const SizedBox(height: 40),
              ],
            ),
      ),
    );
  }
}