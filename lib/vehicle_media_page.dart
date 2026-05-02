import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'dart:convert';
import 'services/api_service.dart';

// Simple holder so we can store camera bytes and file-picker bytes the same way.
class _MediaFile {
  final String name;
  final Uint8List bytes;
  const _MediaFile({required this.name, required this.bytes});
}

class VehicleMediaPage extends StatefulWidget {
  final String valuationId;
  final Map<String, dynamic> existingImages;

  /// When [cameraOnly] is true every "Browse" button is replaced with
  /// "📷 Take Photo" that launches the device camera directly.
  /// Pass cameraOnly: true from AVO; leave default (false) from QC / FinalReport.
  final bool cameraOnly;

  const VehicleMediaPage({
    super.key,
    required this.valuationId,
    this.existingImages = const {},
    this.cameraOnly = false,
  });

  @override
  State<VehicleMediaPage> createState() => _VehicleMediaPageState();
}

class _VehicleMediaPageState extends State<VehicleMediaPage> {
  bool _isSyncing = false;
  bool _isLoadingData = true;
  String _vNo = "";
  String _contact = "";

  Map<String, String> _serverImages = {};

  final Map<String, _MediaFile?> _localFiles = {
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
      final openCases = await ApiService().getOpenValuations();
      final currentCase = openCases.firstWhere(
          (c) => (c['valuationId'] ?? c['id']) == widget.valuationId,
          orElse: () => null);

      if (currentCase != null) {
        _vNo = currentCase['vehicleNumber'] ?? "";
        _contact = currentCase['applicantContact'] ?? "";
        await _fetchLatestPhotosFromServer();
      }
    } catch (e) {
      debugPrint("Init error: $e");
    } finally {
      if (mounted) setState(() => _isLoadingData = false);
    }
  }

  Future<void> _fetchLatestPhotosFromServer() async {
    if (_vNo.isEmpty) return;
    try {
      final uri = Uri.parse(
              '${ApiService().baseUrl}/valuations/${widget.valuationId}/photos')
          .replace(queryParameters: {
        "vehicleNumber": _vNo.trim(),
        "applicantContact": _contact.trim()
      });
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        setState(() {
          data.forEach((k, v) {
            if (v != null && v.toString().isNotEmpty) {
              _serverImages[k] = v.toString();
            }
          });
        });
      }
    } catch (e) {
      debugPrint("Failed to fetch latest photos: $e");
    }
  }

  // ── PICK / CAPTURE ────────────────────────────────────────────────────────

  Future<void> _pickMedia(String key, {bool isVideo = false}) async {
    if (widget.cameraOnly) {
      // ── CAMERA ONLY MODE (AVO) ─────────────────────────────────────────
      await _captureWithCamera(key, isVideo: isVideo);
    } else {
      // ── FILE PICKER MODE (QC / FinalReport) ────────────────────────────
      await _pickFromFiles(key, isVideo: isVideo);
    }
  }

  Future<void> _captureWithCamera(String key, {bool isVideo = false}) async {
    final picker = ImagePicker();
    try {
      if (isVideo) {
        final XFile? video =
            await picker.pickVideo(source: ImageSource.camera);
        if (video == null) return;
        final bytes = await video.readAsBytes();
        setState(() => _localFiles[key] =
            _MediaFile(name: video.name.isNotEmpty ? video.name : '$key.mp4', bytes: bytes));
      } else {
        final XFile? photo =
            await picker.pickImage(source: ImageSource.camera, imageQuality: 85);
        if (photo == null) return;
        final bytes = await photo.readAsBytes();
        setState(() => _localFiles[key] =
            _MediaFile(name: photo.name.isNotEmpty ? photo.name : '$key.jpg', bytes: bytes));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("Camera error: $e"), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _pickFromFiles(String key, {bool isVideo = false}) async {
    final result = await FilePicker.pickFiles(
      type: isVideo ? FileType.video : FileType.image,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final picked = result.files.single;
    if (picked.bytes == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("Could not read file contents."),
            backgroundColor: Colors.red));
      }
      return;
    }
    setState(() => _localFiles[key] =
        _MediaFile(name: picked.name, bytes: picked.bytes!));
  }

  // ── UPLOAD ────────────────────────────────────────────────────────────────

  Future<void> _uploadSingleFile(String uiKey) async {
    final mf = _localFiles[uiKey];
    if (mf == null) return;

    if (_vNo.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Error: Cannot upload without Vehicle Number."),
          backgroundColor: Colors.red));
      return;
    }

    setState(() => _isSyncing = true);
    try {
      final backendKey = _backendKeys[uiKey]!;
      final uri = Uri.parse(
              '${ApiService().baseUrl}/valuations/${widget.valuationId}/photos')
          .replace(queryParameters: {
        "vehicleNumber": _vNo.trim(),
        "applicantContact": _contact.trim()
      });

      final request = http.MultipartRequest('PUT', uri);
      request.fields['ValuationId'] = widget.valuationId;
      request.fields['VehicleNumber'] = _vNo;
      request.fields['ApplicantContact'] = _contact;
      request.fields['valuationId'] = widget.valuationId;
      request.fields['vehicleNumber'] = _vNo;
      request.fields['applicantContact'] = _contact;

      final isVideo = uiKey.toLowerCase().contains("video");
      final mediaType =
          isVideo ? MediaType('video', 'mp4') : MediaType('image', 'jpeg');
      final filename = mf.name.isNotEmpty && mf.name.contains('.')
          ? mf.name
          : '$backendKey${isVideo ? '.mp4' : '.jpg'}';

      request.files.add(http.MultipartFile.fromBytes(
        backendKey,
        mf.bytes,
        filename: filename,
        contentType: mediaType,
      ));

      final response = await request.send();
      if (response.statusCode == 200 || response.statusCode == 204) {
        setState(() => _localFiles[uiKey] = null);
        await _fetchLatestPhotosFromServer();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text("$uiKey uploaded successfully!"),
              backgroundColor: Colors.green));
        }
      } else {
        throw Exception("Server returned ${response.statusCode}");
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("Failed to upload $uiKey: $e"),
            backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  Future<void> _uploadAllPending() async {
    final hasFiles = _localFiles.values.any((f) => f != null);
    if (!hasFiles) {
      Navigator.pop(context);
      return;
    }
    setState(() => _isSyncing = true);
    try {
      for (final key in _localFiles.keys.where((k) => _localFiles[k] != null).toList()) {
        await _uploadSingleFile(key);
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  // ── HELPERS ───────────────────────────────────────────────────────────────

  String? _getBackendUrl(String title) {
    final backendKey = _backendKeys[title]!;
    for (final key in _serverImages.keys) {
      if (key.toLowerCase() == backendKey.toLowerCase()) return _serverImages[key];
    }
    return null;
  }

  // ── CARD ──────────────────────────────────────────────────────────────────

  Widget _buildMediaCard(String title, {bool isVideo = false}) {
    final localFile = _localFiles[title];
    final backendUrl = _getBackendUrl(title);

    final hasLocal = localFile != null;
    final hasBackend = backendUrl != null && backendUrl.startsWith("http");

    final borderColor = hasLocal
        ? Colors.blue.shade600
        : hasBackend
            ? Colors.green.shade600
            : Colors.grey.shade300;
    final borderWidth = (hasLocal || hasBackend) ? 3.0 : 1.0;

    // Label & colours for the action button
    final String btnLabel;
    final Color btnBg;
    final Color btnFg;
    final IconData btnIcon;

    if (hasLocal) {
      btnLabel = "Change";
      btnBg = Colors.blue.shade50;
      btnFg = Colors.blue.shade700;
      btnIcon = widget.cameraOnly ? Icons.camera_alt : Icons.edit;
    } else if (hasBackend) {
      btnLabel = widget.cameraOnly ? "Re-shoot" : "Replace";
      btnBg = Colors.green.shade50;
      btnFg = Colors.green.shade700;
      btnIcon = widget.cameraOnly ? Icons.camera_alt : Icons.swap_horiz;
    } else {
      btnLabel = widget.cameraOnly ? "Take Photo" : "Browse";
      btnBg = Colors.white;
      btnFg = Colors.black87;
      btnIcon = widget.cameraOnly ? Icons.camera_alt : Icons.folder_open;
    }

    return Card(
      elevation: hasLocal || hasBackend ? 3 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: borderColor, width: borderWidth),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // ── Preview area ──────────────────────────────────────────────
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
                                    const Icon(Icons.videocam,
                                        size: 40, color: Colors.blue),
                                    const SizedBox(height: 6),
                                    Text("Video Ready",
                                        style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.blue.shade700,
                                            fontWeight: FontWeight.bold)),
                                  ],
                                )
                              : Image.memory(
                                  localFile.bytes,
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  height: double.infinity,
                                  errorBuilder: (_, __, ___) => const Icon(
                                      Icons.broken_image,
                                      color: Colors.red,
                                      size: 40),
                                ))
                          : hasBackend
                              ? (isVideo
                                  ? Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        const Icon(Icons.check_circle,
                                            size: 40, color: Colors.green),
                                        const SizedBox(height: 6),
                                        Text("Video Uploaded",
                                            style: TextStyle(
                                                fontSize: 10,
                                                color: Colors.green.shade700,
                                                fontWeight: FontWeight.bold)),
                                      ],
                                    )
                                  : Image.network(
                                      backendUrl,
                                      fit: BoxFit.cover,
                                      width: double.infinity,
                                      height: double.infinity,
                                      errorBuilder: (_, __, ___) =>
                                          const Icon(Icons.broken_image,
                                              color: Colors.red, size: 40),
                                    ))
                              : Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                        isVideo
                                            ? Icons.videocam_outlined
                                            : (widget.cameraOnly
                                                ? Icons.camera_alt_outlined
                                                : Icons.image_outlined),
                                        size: 40,
                                        color: Colors.grey[400]),
                                    const SizedBox(height: 6),
                                    Text(
                                        isVideo
                                            ? "No Video"
                                            : (widget.cameraOnly
                                                ? "Tap to Capture"
                                                : "No Image"),
                                        style: TextStyle(
                                            color: Colors.grey[400],
                                            fontSize: 10)),
                                  ],
                                ),
                    ),
                  ),
                ),
                // Status badge
                if (hasBackend && !hasLocal)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: _badge(Icons.check, "Saved", Colors.green),
                  ),
                if (hasLocal)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: _badge(Icons.cloud_upload, "Pending", Colors.blue),
                  ),
              ],
            ),
          ),

          // ── Label ─────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: Text(title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(height: 6),

          // ── Action buttons ────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                height: 30,
                child: OutlinedButton.icon(
                  onPressed: _isSyncing
                      ? null
                      : () => _pickMedia(title, isVideo: isVideo),
                  icon: Icon(btnIcon, size: 12),
                  label: Text(btnLabel,
                      style: TextStyle(fontSize: 10, color: btnFg,
                          fontWeight: hasLocal || hasBackend
                              ? FontWeight.bold
                              : FontWeight.normal)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    backgroundColor: btnBg,
                    side: BorderSide(
                        color: hasLocal
                            ? Colors.blue.shade600
                            : hasBackend
                                ? Colors.green.shade600
                                : Colors.grey.shade400),
                  ),
                ),
              ),
              if (hasLocal) ...[
                const SizedBox(width: 4),
                SizedBox(
                  height: 30,
                  child: ElevatedButton(
                    onPressed: _isSyncing
                        ? null
                        : () => _uploadSingleFile(title),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade600,
                        padding:
                            const EdgeInsets.symmetric(horizontal: 8)),
                    child: const Text("Upload",
                        style: TextStyle(
                            fontSize: 10,
                            color: Colors.white,
                            fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _badge(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration:
          BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 12),
          const SizedBox(width: 2),
          Text(label,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  // ── BUILD ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final pendingCount = _localFiles.values.where((f) => f != null).length;
    final isCamera = widget.cameraOnly;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          isCamera ? "Vehicle Photos (Camera)" : "Vehicle Media",
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: isCamera ? Colors.teal : Colors.green,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: isCamera
            ? [
                const Padding(
                  padding: EdgeInsets.only(right: 12),
                  child: Row(
                    children: [
                      Icon(Icons.camera_alt, size: 18, color: Colors.white70),
                      SizedBox(width: 4),
                      Text("Camera Only",
                          style: TextStyle(
                              color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                )
              ]
            : null,
      ),
      body: _isLoadingData
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Info banner for camera mode
                  if (isCamera)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                          color: Colors.teal.shade50,
                          border: Border.all(color: Colors.teal.shade200),
                          borderRadius: BorderRadius.circular(8)),
                      child: Row(children: const [
                        Icon(Icons.camera_alt, color: Colors.teal, size: 18),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            "Tap 'Take Photo' on each slot to capture live using your camera.",
                            style: TextStyle(
                                color: Colors.teal,
                                fontSize: 12,
                                fontWeight: FontWeight.w500),
                          ),
                        ),
                      ]),
                    ),

                  // Pending files banner
                  if (pendingCount > 0)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          border: Border.all(color: Colors.orange),
                          borderRadius: BorderRadius.circular(8)),
                      child: Text(
                        "$pendingCount photo(s) ready. Tap 'Upload' on each, or use Batch Upload below.",
                        style: const TextStyle(
                            color: Colors.orange,
                            fontWeight: FontWeight.bold),
                      ),
                    ),

                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 220,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.75,
                    ),
                    itemCount: _localFiles.length,
                    itemBuilder: (context, index) {
                      final key = _localFiles.keys.elementAt(index);
                      return _buildMediaCard(key,
                          isVideo: key.contains("Video"));
                    },
                  ),

                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: pendingCount > 0
                              ? (isCamera ? Colors.teal : const Color(0xFF3F51B5))
                              : Colors.grey),
                      onPressed: _isSyncing ? null : _uploadAllPending,
                      child: _isSyncing
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                          : Text(
                              pendingCount > 0
                                  ? "Batch Upload All ($pendingCount)"
                                  : "Back to Dashboard",
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 16)),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }
}
