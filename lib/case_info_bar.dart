// case_info_bar.dart
// The strip every case page shows under its title, mirroring the portal's
// workflow-buttons header: the case's Unique ID, who it is assigned to, and the
// Payment button with its Paid / Pending badge.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'case_payment_page.dart';
import 'services/api_service.dart';

class CaseInfoBar extends StatefulWidget {
  final String valuationId;
  final String vehicleNumber;
  final String applicantContact;

  const CaseInfoBar({
    super.key,
    required this.valuationId,
    required this.vehicleNumber,
    required this.applicantContact,
  });

  @override
  State<CaseInfoBar> createState() => _CaseInfoBarState();
}

class _CaseInfoBarState extends State<CaseInfoBar> {
  final _api = ApiService();
  String? _reference;
  Map<String, dynamic> _assigned = {};
  Map<String, dynamic> _payment = {};
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (widget.valuationId.isEmpty) return;
    final results = await Future.wait([
      _api.getReferenceNumber(widget.valuationId, widget.vehicleNumber, widget.applicantContact),
      _api.getAssignedUser(widget.valuationId, widget.vehicleNumber, widget.applicantContact),
      _api.getPayment(widget.valuationId),
    ]);
    if (!mounted) return;
    setState(() {
      _reference = results[0] as String?;
      _assigned = results[1] as Map<String, dynamic>;
      _payment = results[2] as Map<String, dynamic>;
      _loaded = true;
    });
  }

  Future<void> _openPayment() async {
    final saved = await openCasePayment(context,
        valuationId: widget.valuationId,
        vehicleNumber: widget.vehicleNumber,
        applicantContact: widget.applicantContact);
    if (saved && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment details saved'), backgroundColor: Colors.green));
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final assignedName = (_assigned['name'] ?? '').toString();
    final assignedPhone = (_assigned['phoneNumber'] ?? '').toString();
    final badge = paymentBadgeLabel(_payment);
    final paid = badge == 'Paid';

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (_reference != null)
              InkWell(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: _reference!));
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Unique ID copied')));
                },
                child: Text.rich(TextSpan(children: [
                  const TextSpan(text: 'Unique ID: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  TextSpan(text: _reference, style: const TextStyle(fontSize: 13, letterSpacing: 0.5)),
                ])),
              )
            else if (!_loaded)
              const Text('Loading…', style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 2),
            Text(
              assignedName.isEmpty
                  ? 'No user is currently assigned.'
                  : 'Assigned: $assignedName${assignedPhone.isNotEmpty ? ' — $assignedPhone' : ''}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
            ),
          ]),
        ),
        if (canAccessPayment())
          OutlinedButton.icon(
            onPressed: _openPayment,
            icon: const Icon(Icons.payments_outlined, size: 18),
            label: Text(_loaded ? 'Payment · $badge' : 'Payment'),
            style: OutlinedButton.styleFrom(
              foregroundColor: paid ? Colors.green.shade700 : Colors.orange.shade800,
              side: BorderSide(color: paid ? Colors.green.shade300 : Colors.orange.shade300),
              padding: const EdgeInsets.symmetric(horizontal: 10),
            ),
          ),
      ]),
    );
  }
}
