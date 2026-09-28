// qc_photo_review.dart
// QC photo review: report-gallery photo selection.
// Mirrors the web portal's quality-control-update gallery slots.
//
// Selection: GET/PUT /valuations/{id}/photos/gallery-selection. Saving an
// empty list means "standard" (every photo stays included), so if the user
// checks everything we save [] — same rule as the portal. Only the selected
// photos appear in the report PDF's gallery pages.

import 'package:flutter/material.dart';
import 'services/api_service.dart';

// Mirrors GALLERY_SLOT_DEFS in the portal's quality-control-update component
// (which mirrors ProntoPDFGeneration's gallery slots) — keep in sync.
const List<MapEntry<String, List<String>>> _gallerySlotDefs = [
  MapEntry('Front View', ['FrontViewGrille', 'FrontView']),
  MapEntry('Rear View', ['RearViewTailgate', 'RearView']),
  MapEntry('Front Right', ['FrontRightSide', 'FrontRight']),
  MapEntry('Front Left', ['FrontLeftSide', 'FrontLeft']),
  MapEntry('Rear Right', ['RearRightSide', 'RearRight']),
  MapEntry('Rear Left', ['RearLeftSide', 'RearLeft']),
  MapEntry('Right Side', ['DriverSideProfile', 'RightSideView']),
  MapEntry('Left Side', ['PassengerSideProfile', 'LeftSideView']),
  MapEntry('Odo Meter', ['Odometer', 'OdoMeter', 'InstrumentCluster']),
  MapEntry('Engine Bay', ['EngineBay', 'Engine']),
  MapEntry('Dashboard', ['Dashboard', 'DashboardCloseup']),
  MapEntry('Selfie', ['SelfieWithVehicle', 'Selfie']),
  MapEntry('Chassis Number', ['ChassisNumberPlate', 'ChassisNumber', 'Chassis', 'ChassisImprint']),
  MapEntry('VIN Plate', ['VinPlate', 'VIN']),
  MapEntry('Tyre - Front Left', ['TireFrontLeft']),
  MapEntry('Tyre - Front Right', ['TireFrontRight']),
  MapEntry('Tyre - Rear Left', ['TireRearLeft']),
  MapEntry('Tyre - Rear Right', ['TireRearRight']),
];

class _GallerySlot {
  final String label;
  final String key;
  String url;
  bool selected;
  String? annotationNote;
  _GallerySlot({required this.label, required this.key, required this.url, this.selected = true, this.annotationNote});
}

class QcPhotoReviewPage extends StatefulWidget {
  final String valuationId;
  final String vehicleNumber;
  final String applicantContact;
  const QcPhotoReviewPage({
    super.key,
    required this.valuationId,
    required this.vehicleNumber,
    required this.applicantContact,
  });

  @override
  State<QcPhotoReviewPage> createState() => _QcPhotoReviewPageState();
}

class _QcPhotoReviewPageState extends State<QcPhotoReviewPage> {
  final ApiService _api = ApiService();
  bool _isLoading = true;
  bool _isSaving = false;
  List<_GallerySlot> _slots = [];

  /// Uploaded photos that aren't part of the PDF's gallery slots — shown
  /// read-only so QC sees everything in one place.
  List<MapEntry<String, String>> _otherPhotos = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final photosFuture = _api.getVehiclePhotoUrls(widget.valuationId, widget.vehicleNumber, widget.applicantContact);
    final selectionFuture = _api.getGallerySelection(widget.valuationId, widget.vehicleNumber, widget.applicantContact);
    final metadataFuture = _api.getPhotosMetadata(widget.valuationId, widget.vehicleNumber, widget.applicantContact);

    final photos = await photosFuture;
    final savedSelection = await selectionFuture;
    final metadata = await metadataFuture;

    // Case-insensitive photo key lookup, first candidate key wins per slot.
    final normalized = <String, MapEntry<String, String>>{};
    photos.forEach((k, v) {
      if (v != null && v.toString().startsWith('http')) {
        normalized[k.toLowerCase()] = MapEntry(k, v.toString());
      }
    });

    String? noteFor(String key) {
      final md = metadata[key] ?? metadata[key.toLowerCase()];
      if (md is Map) {
        final note = md['annotationNote'] ?? md['AnnotationNote'];
        if (note != null && note.toString().isNotEmpty) return note.toString();
      }
      return null;
    }

    final slots = <_GallerySlot>[];
    for (final def in _gallerySlotDefs) {
      for (final candidate in def.value) {
        final hit = normalized[candidate.toLowerCase()];
        if (hit != null) {
          final actualKey = hit.key;
          slots.add(_GallerySlot(
            label: def.key,
            key: actualKey,
            url: hit.value,
            selected: savedSelection.isEmpty || savedSelection.contains(actualKey),
            annotationNote: noteFor(actualKey),
          ));
          break;
        }
      }
    }

    // Everything uploaded that didn't land in a gallery slot.
    final usedKeys = slots.map((s) => s.key.toLowerCase()).toSet();
    final others = <MapEntry<String, String>>[];
    for (final entry in normalized.values) {
      if (!usedKeys.contains(entry.key.toLowerCase())) {
        others.add(entry);
      }
    }

    if (mounted) {
      setState(() {
        _slots = slots;
        _otherPhotos = others;
        _isLoading = false;
      });
    }
  }

  Future<void> _saveSelection() async {
    setState(() => _isSaving = true);
    // If everything is checked, save [] so it behaves as "standard" — photos
    // added later stay included automatically (portal rule).
    final allSelected = _slots.every((s) => s.selected);
    final keys = allSelected ? <String>[] : _slots.where((s) => s.selected).map((s) => s.key).toList();
    final ok = await _api.saveGallerySelection(widget.valuationId, widget.vehicleNumber, widget.applicantContact, keys);
    if (!mounted) return;
    setState(() => _isSaving = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok ? "Gallery selection saved" : "Failed to save gallery selection"),
      backgroundColor: ok ? Colors.green : Colors.red,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final selectedCount = _slots.where((s) => s.selected).length;
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text("Report Photos",
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _slots.isEmpty
              ? const Center(child: Text("No photos uploaded for this case yet.",
                  style: TextStyle(color: Colors.grey)))
              : Column(children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Row(children: [
                      Expanded(
                        child: Text("$selectedCount of ${_slots.length} photos in report gallery",
                            style: const TextStyle(fontSize: 13, color: Colors.blueGrey)),
                      ),
                      TextButton(
                        onPressed: () => setState(() {
                          final all = _slots.every((s) => s.selected);
                          for (final s in _slots) {
                            s.selected = !all;
                          }
                        }),
                        child: const Text("Toggle All"),
                      ),
                    ]),
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 0.82,
                          ),
                          itemCount: _slots.length,
                          itemBuilder: (context, i) => _buildSlotCard(_slots[i]),
                        ),
                        if (_otherPhotos.isNotEmpty) ...[
                          const SizedBox(height: 20),
                          const Divider(),
                          const SizedBox(height: 8),
                          Text("Other uploaded photos (${_otherPhotos.length}) — not part of the report gallery",
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.blueGrey)),
                          const SizedBox(height: 10),
                          SizedBox(
                            height: 120,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: _otherPhotos.length,
                              separatorBuilder: (_, __) => const SizedBox(width: 10),
                              itemBuilder: (context, i) {
                                final e = _otherPhotos[i];
                                return Column(children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(
                                      e.value,
                                      width: 120,
                                      height: 96,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Container(
                                        width: 120,
                                        height: 96,
                                        color: Colors.grey.shade200,
                                        child: const Icon(Icons.broken_image, color: Colors.grey),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  SizedBox(
                                    width: 120,
                                    child: Text(e.key,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(fontSize: 10, color: Colors.grey)),
                                  ),
                                ]);
                              },
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                      ],
                    ),
                  ),
                ]),
      bottomNavigationBar: _slots.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _saveSelection,
                  icon: _isSaving
                      ? const SizedBox(height: 16, width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.save),
                  label: const Text("Save Gallery Selection", style: TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF007B7B),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildSlotCard(_GallerySlot slot) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: slot.selected ? const Color(0xFF007B7B) : Colors.grey.shade300, width: slot.selected ? 2 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(children: [
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(9)),
                  child: GestureDetector(
                    onTap: () => setState(() => slot.selected = !slot.selected),
                    child: Image.network(
                      slot.url,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: Colors.grey.shade200,
                        child: const Icon(Icons.broken_image, color: Colors.grey),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 4,
                left: 4,
                child: Container(
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.85), shape: BoxShape.circle),
                  child: Checkbox(
                    value: slot.selected,
                    activeColor: const Color(0xFF007B7B),
                    shape: const CircleBorder(),
                    onChanged: (v) => setState(() => slot.selected = v ?? false),
                  ),
                ),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(slot.label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              if (slot.annotationNote != null)
                Text(slot.annotationNote!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 10, color: Colors.orange)),
            ]),
          ),
        ],
      ),
    );
  }
}
