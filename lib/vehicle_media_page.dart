import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart'; // REQUIRED for MediaType
import 'dart:convert';
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

  final Map<String, PlatformFile?> _localFiles = {
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

  final Map<String, String> _backendKeys = {
    "Front Left Side": "frontLeftSide",
    "Front Right Side": "frontRightSide",
    "Rear Left Side": "rearLeftSide",
    "Rear Right Side": "rearRightSide",
    "Front View (grille)": "frontViewGrille",
    "Rear View (tailgate)": "rearViewTailgate",
    "Driver's Side Profile": "driverSideProfile",
    "Passenger Side Profile": "passengerSideProfile",
    "Dashboard": "dashboard",
    "Instrument Cluster": "instrumentCluster",
    "Engine Bay": "engineBay",
    "Chassis Number Plate": "chassisNumberPlate",
    "Chassis Imprint": "chassisImprint",
    "Gear and Seats": "gearAndSeats",
    "Dashboard Close-up": "dashboardCloseup",
    "Odometer": "odometer",
    "Selfie with Vehicle": "selfieWithVehicle",
    "Underbody": "underbody",
    "Tires and Rims": "tiresAndRims",
    "Vehicle Video": "vehicleVideo",
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
      var currentCase = openCases.firstWhere(
          (c) => (c['valuationId'] ?? c['id']) == widget.valuationId,
          orElse: () => null);

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
          queryParameters: {"vehicleNumber": _vNo.trim(), "applicantContact": _contact.trim()});
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
    FilePickerResult? result = await FilePicker.pickFiles(
      type: isVideo ? FileType.video : FileType.image,
      withData: true,
    );

    if (result != null && result.files.isNotEmpty) {
      final picked = result.files.single;
      if (picked.bytes == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Could not read file contents."), backgroundColor: Colors.red),
          );
        }
        return;
      }
      setState(() {
        _localFiles[key] = picked;
      });
    }
  }

  // ✅ NEW: Uploads a single, specific file (Triggered by "Upload Now" button)
  Future<void> _uploadSingleFile(String uiKey) async {
    final pf = _localFiles[uiKey];
    if (pf == null || pf.bytes == null) return;

    if (_vNo.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Error: Cannot upload without Vehicle Number."), backgroundColor: Colors.red));
      return;
    }

    setState(() => _isSyncing = true);

    try {
      final backendKey = _backendKeys[uiKey]!;
      var uri = Uri.parse('${ApiService().baseUrl}/valuations/${widget.valuationId}/photos').replace(
          queryParameters: {"vehicleNumber": _vNo.trim(), "applicantContact": _contact.trim()});
      
      var request = http.MultipartRequest('PUT', uri);
      
      // ✅ FIX FOR 400 ERROR: Add identifying fields back into the form body!
      request.fields['ValuationId'] = widget.valuationId;
      request.fields['VehicleNumber'] = _vNo;
      request.fields['ApplicantContact'] = _contact;
      // Including camelCase variants just in case the ASP.NET binder is strict
      request.fields['valuationId'] = widget.valuationId;
      request.fields['vehicleNumber'] = _vNo;
      request.fields['applicantContact'] = _contact;

      bool isVideo = uiKey.toLowerCase().contains("video");
      String defaultExt = isVideo ? '.mp4' : '.jpg';
      MediaType mediaType = isVideo ? MediaType('video', 'mp4') : MediaType('image', 'jpeg');
      
      final filename = pf.name.isNotEmpty && pf.name.contains('.') ? pf.name : '$backendKey$defaultExt';

      request.files.add(http.MultipartFile.fromBytes(
        backendKey,
        pf.bytes!,
        filename: filename,
        contentType: mediaType,
      ));

      var response = await request.send();

      if (response.statusCode == 200 || response.statusCode == 204) {
        setState(() => _localFiles[uiKey] = null);
        await _fetchLatestPhotosFromServer();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("$uiKey uploaded successfully!"), backgroundColor: Colors.green));
        }
      } else {
        String respStr = await response.stream.bytesToString();
        throw Exception("Server returned ${response.statusCode}");
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Failed to upload $uiKey: $e"), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  // Uploads ALL pending files sequentially
  Future<void> _uploadAllPending() async {
    bool hasFilesToUpload = _localFiles.values.any((f) => f != null);
    if (!hasFilesToUpload) {
      Navigator.pop(context);
      return;
    }

    setState(() => _isSyncing = true);

    try {
      List<String> pendingKeys = _localFiles.keys.where((k) => _localFiles[k] != null).toList();
      
      for (String key in pendingKeys) {
        await _uploadSingleFile(key); // Reuses the single upload logic above
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
    PlatformFile? localFile = _localFiles[title];
    String? backendUrl = _getBackendUrl(title);

    bool hasLocal = localFile != null && localFile.bytes != null;
    bool hasBackend = backendUrl != null && backendUrl.startsWith("http");

    Color borderColor = hasLocal
        ? Colors.blue.shade600
        : hasBackend
            ? Colors.green.shade600
            : Colors.grey.shade300;

    double borderWidth = (hasLocal || hasBackend) ? 3.0 : 1.0;

    return Card(
      elevation: hasLocal || hasBackend ? 3 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: borderColor, width: borderWidth),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: Stack(
              children: [
                Container(
                  margin: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Center(
                      child: hasLocal
                          ? (isVideo
                              ? Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.videocam, size: 40, color: Colors.blue),
                                    const SizedBox(height: 8),
                                    Text("Video Selected",
                                        style: TextStyle(fontSize: 10, color: Colors.blue.shade700, fontWeight: FontWeight.bold)),
                                  ],
                                )
                              : Image.memory(
                                  localFile!.bytes!,
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  height: double.infinity,
                                  errorBuilder: (c, o, s) => const Icon(Icons.broken_image, color: Colors.red, size: 40),
                                ))
                          : hasBackend
                              ? (isVideo
                                  ? Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Icon(Icons.check_circle, size: 40, color: Colors.green),
                                        const SizedBox(height: 8),
                                        Text("Video Uploaded",
                                            style: TextStyle(fontSize: 10, color: Colors.green.shade700, fontWeight: FontWeight.bold)),
                                      ],
                                    )
                                  : Image.network(
                                      backendUrl,
                                      fit: BoxFit.cover,
                                      width: double.infinity,
                                      height: double.infinity,
                                      errorBuilder: (c, o, s) => const Icon(Icons.broken_image, color: Colors.red, size: 40),
                                    ))
                              : Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(isVideo ? Icons.videocam_outlined : Icons.camera_alt_outlined, size: 40, color: Colors.grey[400]),
                                    const SizedBox(height: 8),
                                    Text(isVideo ? "No Video" : "No Image", style: TextStyle(color: Colors.grey[400], fontSize: 10)),
                                  ],
                                ),
                    ),
                  ),
                ),
                if (hasBackend && !hasLocal)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(12)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.check, color: Colors.white, size: 12),
                          SizedBox(width: 2),
                          Text("Saved", style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                if (hasLocal)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: Colors.blue, borderRadius: BorderRadius.circular(12)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.cloud_upload, color: Colors.white, size: 12),
                          SizedBox(width: 2),
                          Text("Pending", style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: Text(title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(height: 6),
          
          // ✅ NEW: Dynamic Row for Single Upload Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                height: 28,
                child: OutlinedButton(
                  onPressed: _isSyncing ? null : () => _pickMedia(title, isVideo: isVideo),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    backgroundColor: hasLocal ? Colors.blue.shade50 : (hasBackend ? Colors.green.shade50 : Colors.white),
                    side: BorderSide(color: hasLocal ? Colors.blue.shade600 : (hasBackend ? Colors.green.shade600 : Colors.grey.shade400)),
                  ),
                  child: Text(
                    hasLocal ? "Change" : (hasBackend ? "Replace" : "Browse"),
                    style: TextStyle(
                      fontSize: 10,
                      color: hasLocal ? Colors.blue.shade700 : (hasBackend ? Colors.green.shade700 : Colors.black87),
                      fontWeight: hasLocal || hasBackend ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              ),
              if (hasLocal) ...[
                const SizedBox(width: 6),
                SizedBox(
                  height: 28,
                  child: ElevatedButton(
                    onPressed: _isSyncing ? null : () => _uploadSingleFile(title),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade600,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    child: const Text("Upload Now", style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ]
            ],
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
                      decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          border: Border.all(color: Colors.orange),
                          borderRadius: BorderRadius.circular(8)),
                      child: Text("$pendingCount files selected. Click 'Upload Now' on an image, or use the batch button below.",
                          style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
                    ),
                  
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 220,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.75, // Lowered slightly to make room for two buttons
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
                      style: ElevatedButton.styleFrom(
                          backgroundColor: pendingCount > 0 ? const Color(0xFF3F51B5) : Colors.grey),
                      onPressed: _isSyncing ? null : _uploadAllPending,
                      child: _isSyncing
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : Text(
                              pendingCount > 0 ? "Batch Upload All ($pendingCount)" : "Back to Dashboard",
                              style: const TextStyle(color: Colors.white, fontSize: 16)),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }
}