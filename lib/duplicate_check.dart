// duplicate_check.dart
// Duplicate vehicle check + results dialog.
// Mirrors the web portal's duplicate-dialog component backed by
// GET /valuations/check-duplicate (VehicleDuplicateCheckResponse).

import 'package:flutter/material.dart';
import 'services/api_service.dart';

/// Runs the duplicate check and shows a results dialog when duplicates exist.
///
/// When [confirmMode] is true (stakeholder create flow) the dialog offers
/// "Proceed Anyway" / "Cancel" and this returns whether to proceed.
/// When false (view flow) it is informational and always returns true.
/// Network failures never block the user — returns true.
Future<bool> checkDuplicatesAndConfirm(
  BuildContext context, {
  String? vehicleNumber,
  String? engineNumber,
  String? chassisNumber,
  String? excludeId,
  bool confirmMode = false,
}) async {
  final api = ApiService();
  final result = await api.checkDuplicateVehicle(
    vehicleNumber: vehicleNumber,
    engineNumber: engineNumber,
    chassisNumber: chassisNumber,
    excludeId: excludeId,
  );

  if (result == null) return true; // check failed — don't block

  final isDuplicate = result['isDuplicate'] == true;
  if (!isDuplicate) {
    if (!confirmMode && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("No duplicates found."), backgroundColor: Colors.green));
    }
    return true;
  }

  if (!context.mounted) return true;
  final proceed = await showDialog<bool>(
    context: context,
    barrierDismissible: !confirmMode,
    builder: (_) => _DuplicateDialog(response: result, confirmMode: confirmMode),
  );
  return confirmMode ? (proceed ?? false) : true;
}

class _DuplicateDialog extends StatelessWidget {
  final Map<String, dynamic> response;
  final bool confirmMode;
  const _DuplicateDialog({required this.response, required this.confirmMode});

  @override
  Widget build(BuildContext context) {
    final records = (response['existingRecords'] is List)
        ? List<dynamic>.from(response['existingRecords'])
        : <dynamic>[];
    final messages = (response['messages'] is List)
        ? List<dynamic>.from(response['messages'])
        : <dynamic>[];
    final total = response['totalDuplicatesFound'] ?? records.length;
    final avgAmount = response['averageValuationAmount'];

    return AlertDialog(
      title: Row(children: [
        const Icon(Icons.warning_amber_rounded, color: Colors.orange),
        const SizedBox(width: 8),
        Expanded(child: Text("Duplicate Found ($total)",
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
      ]),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final m in messages)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text("• $m", style: const TextStyle(fontSize: 13, color: Colors.black87)),
                ),
              if (avgAmount != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text("Average valuation of duplicates: ₹$avgAmount",
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.teal)),
                ),
              const Divider(),
              for (final r in records) _recordTile(r),
            ],
          ),
        ),
      ),
      actions: confirmMode
          ? [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text("Cancel", style: TextStyle(color: Colors.red)),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
                child: const Text("Proceed Anyway"),
              ),
            ]
          : [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Close"),
              ),
            ],
    );
  }

  Widget _recordTile(dynamic r) {
    if (r is! Map) return const SizedBox.shrink();
    String created = (r['createdDate'] ?? '').toString();
    if (created.length > 10) created = created.substring(0, 10);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Text(r['vehicleNumber']?.toString() ?? '-',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
            Text(r['status']?.toString() ?? '',
                style: const TextStyle(fontSize: 12, color: Colors.blueGrey)),
          ]),
          const SizedBox(height: 4),
          Text("Matched on: ${r['matchedField'] ?? '-'}",
              style: const TextStyle(fontSize: 12, color: Colors.deepOrange)),
          if ((r['company'] ?? '').toString().isNotEmpty)
            Text("Company: ${r['company']}", style: const TextStyle(fontSize: 12)),
          if (r['valuationAmount'] != null)
            Text("Valuation: ₹${r['valuationAmount']}", style: const TextStyle(fontSize: 12)),
          if (created.isNotEmpty)
            Text("Created: $created", style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }
}
