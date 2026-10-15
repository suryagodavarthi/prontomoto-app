// case_payment_page.dart
// The case's payment, as the portal's 💳 Payment dialog (case-payment.component)
// handles it: the same fields, options and rules, saved to the same record, and
// reached from every case page rather than saved as a side effect of another form.
//
// Before this, the AVO and Final Report pages wrote a payment whenever they were
// saved, with defaults filled in (Pending / Online / ₹800 on AVO, Completed /
// Online on approval), and "Credit" was not an option, so a Credit payment saved
// in the portal became Pending the next time the AVO saved.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import 'main.dart';
import 'services/api_service.dart';

const List<String> paymentStatuses = ['Completed', 'Pending', 'Credit'];
const List<String> paymentMethods = ['Online', 'Cash', 'UPI', 'Card'];

/// Who sees the Payment button (portal canAccessPayment).
bool canAccessPayment() => const [
      'CanViewInspection', 'CanCreateInspection', 'CanEditInspection',
      'CanViewQualityControl', 'CanCreateQualityControl', 'CanEditQualityControl',
      'CanViewFinalReport', 'CanCreateFinalReport', 'CanEditFinalReport',
    ].any(currentUserRoles.contains);

/// Who may change it (portal CasePaymentComponent.canEdit).
bool canEditPayment() => const [
      'CanCreateInspection', 'CanEditInspection',
      'CanCreateQualityControl', 'CanEditQualityControl',
      'CanCreateFinalReport', 'CanEditFinalReport',
    ].any(currentUserRoles.contains);

/// The badge on the Payment button: Paid once Completed, else the status, else Pending.
String paymentBadgeLabel(Map<String, dynamic> payment) {
  final status = (payment['paymentstatus'] ?? '').toString().trim();
  if (status.isEmpty) return 'Pending';
  return status.toLowerCase() == 'completed' ? 'Paid' : status;
}

// Payment times are shown and entered in IST, whatever the phone's timezone,
// and stored as UTC. IST has no daylight saving, so a fixed offset is exact.
const Duration _istOffset = Duration(hours: 5, minutes: 30);
DateTime _toIstWall(DateTime instant) => instant.toUtc().add(_istOffset);
DateTime _istWallToUtc(DateTime wall) =>
    DateTime.utc(wall.year, wall.month, wall.day, wall.hour, wall.minute, wall.second).subtract(_istOffset);
DateTime _istNow() => _toIstWall(DateTime.now());

/// Opens the payment page; resolves to true when a payment was saved.
Future<bool> openCasePayment(BuildContext context,
    {required String valuationId, required String vehicleNumber, required String applicantContact}) async {
  final saved = await Navigator.push<bool>(
    context,
    MaterialPageRoute(
      builder: (_) => CasePaymentPage(
          valuationId: valuationId, vehicleNumber: vehicleNumber, applicantContact: applicantContact),
    ),
  );
  return saved == true;
}

class CasePaymentPage extends StatefulWidget {
  final String valuationId;
  final String vehicleNumber;
  final String applicantContact;

  const CasePaymentPage({
    super.key,
    required this.valuationId,
    required this.vehicleNumber,
    required this.applicantContact,
  });

  @override
  State<CasePaymentPage> createState() => _CasePaymentPageState();
}

class _CasePaymentPageState extends State<CasePaymentPage> {
  final _api = ApiService();
  final _amountController = TextEditingController();
  final _referenceController = TextEditingController();
  final _notesController = TextEditingController();

  String _status = '';
  String _method = '';

  /// Payment date as an IST wall clock, converted to UTC on save.
  DateTime? _date;

  /// While true the date tracks the current time, so a payment taken now is
  /// stamped with the moment it is saved. Picking a date, or a date already
  /// saved on the case, switches it off.
  bool _dateIsLive = true;
  Timer? _clock;

  /// What is stored on the case, shown above the form. Null when nothing is.
  Map<String, dynamic>? _saved;

  bool _loading = true;
  bool _saving = false;

  bool get _canEdit => canEditPayment();
  bool get _needsMethodAndDate => _status != 'Pending';

  @override
  void initState() {
    super.initState();
    _date = _istNow();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_dateIsLive && !_saving && mounted) setState(() => _date = _istNow());
    });
    _load();
  }

  @override
  void dispose() {
    _clock?.cancel();
    _amountController.dispose();
    _referenceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  // getPayment lower-cases the keys.
  String _str(Map<String, dynamic> p, String key) => (p[key] ?? '').toString();

  Future<void> _load() async {
    final p = await _api.getPayment(widget.valuationId);
    if (!mounted) return;
    setState(() {
      final status = _str(p, 'paymentstatus');
      final amount = p['paymentamount'];
      if (status.isNotEmpty || amount != null) _saved = p;
      _status = paymentStatuses.contains(status) ? status : '';
      final method = _str(p, 'paymentmethod');
      _method = paymentMethods.contains(method) ? method : '';
      final date = DateTime.tryParse(_str(p, 'paymentdate'));
      if (date != null) {
        _date = _toIstWall(date);
        _dateIsLive = false;
      }
      final a = double.tryParse('${amount ?? ''}');
      _amountController.text = a == null ? '' : (a == a.roundToDouble() ? a.round().toString() : '$a');
      _referenceController.text = _str(p, 'paymentreference');
      _notesController.text = _str(p, 'paymentnotes');
      _loading = false;
    });
  }

  Future<void> _pickDateTime() async {
    final now = _istNow();
    final date = await showDatePicker(
      context: context,
      initialDate: _date ?? now,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 2),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_date ?? now));
    if (!mounted) return;
    setState(() {
      _dateIsLive = false;
      _date = DateTime(date.year, date.month, date.day, time?.hour ?? 0, time?.minute ?? 0);
    });
  }

  Future<void> _save() async {
    if (!_canEdit) return;
    final amount = double.tryParse(_amountController.text.trim());
    // The portal's rules: status and amount always; method and date unless Pending.
    if (_status.isEmpty || amount == null || amount <= 0) {
      _message('Please fill all required payment fields.');
      return;
    }
    if (_needsMethodAndDate && (_method.isEmpty || _date == null)) {
      _message('Please fill Method and Date fields.');
      return;
    }

    setState(() => _saving = true);
    final istDate = _dateIsLive ? _istNow() : _date;
    final res = await _api.savePayment(
      valuationId: widget.valuationId,
      vehicleNumber: widget.vehicleNumber,
      applicantContact: widget.applicantContact,
      paymentStatus: _status,
      paymentReference: _referenceController.text.trim(),
      paymentDate: _istWallToUtc(istDate ?? _istNow()).toIso8601String(),
      paymentMethod: _method,
      paymentAmount: amount,
      paymentNotes: _notesController.text.trim(),
      savedBy: currentUserName.isNotEmpty ? currentUserName : 'Unknown',
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (res['success'] == true) {
      Navigator.pop(context, true);
    } else {
      _message('Failed to save payment details.');
    }
  }

  void _message(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text), backgroundColor: Colors.red));

  static String _formatAmount(dynamic raw) {
    final a = double.tryParse('${raw ?? ''}');
    if (a == null) return '—';
    final pattern = a == a.roundToDouble() ? '#,##0' : '#,##0.00';
    return '₹ ${NumberFormat(pattern, 'en_IN').format(a)}';
  }

  static String _formatInstantIst(String raw) {
    final d = DateTime.tryParse(raw);
    return d == null ? '—' : '${DateFormat('dd-MM-yyyy h:mm a').format(_toIstWall(d))} IST';
  }

  Widget _savedRow(String label, String value, {bool muted = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 96, child: Text(label, style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600))),
          Expanded(
            child: Text(value.isEmpty ? '—' : value,
                style: TextStyle(fontSize: 13.5, fontWeight: muted ? FontWeight.w400 : FontWeight.w600)),
          ),
        ]),
      );

  Widget _buildSavedCard(Map<String, dynamic> p) {
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: primary.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: primary.withOpacity(0.3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.receipt_long, size: 18, color: primary),
          const SizedBox(width: 8),
          Text('SAVED PAYMENT DETAILS',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.5, color: primary)),
        ]),
        const SizedBox(height: 10),
        _savedRow('Status', _str(p, 'paymentstatus')),
        _savedRow('Method', _str(p, 'paymentmethod')),
        _savedRow('Amount', _formatAmount(p['paymentamount'])),
        _savedRow('Date', _formatInstantIst(_str(p, 'paymentdate'))),
        _savedRow('Reference', _str(p, 'paymentreference')),
        _savedRow('Notes', _str(p, 'paymentnotes')),
        const Divider(height: 18),
        _savedRow('Saved by', _str(p, 'savedby'), muted: true),
        _savedRow('Saved on', _formatInstantIst(_str(p, 'savedat')), muted: true),
      ]),
    );
  }

  String _hint(bool required) => required ? ' *' : ' (optional)';

  @override
  Widget build(BuildContext context) {
    final editable = _canEdit && !_saving;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment Details'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(24),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(widget.vehicleNumber, style: const TextStyle(fontSize: 13)),
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: ListView(padding: const EdgeInsets.all(20), children: [
                if (_saved != null) _buildSavedCard(_saved!),
                if (!_canEdit)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 16),
                    child: Text('You can view this payment but not change it.', style: TextStyle(color: Colors.grey)),
                  ),
                DropdownButtonFormField<String>(
                  value: _status.isEmpty ? null : _status,
                  decoration: const InputDecoration(labelText: 'Payment Status *', border: OutlineInputBorder()),
                  items: [for (final s in paymentStatuses) DropdownMenuItem(value: s, child: Text(s))],
                  onChanged: editable ? (v) => setState(() => _status = v ?? '') : null,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _amountController,
                  enabled: editable,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                  decoration: const InputDecoration(labelText: 'Payment Amount *', prefixText: '₹ ', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _method.isEmpty ? null : _method,
                  decoration: InputDecoration(
                      labelText: 'Payment Method${_hint(_needsMethodAndDate)}', border: const OutlineInputBorder()),
                  items: [for (final m in paymentMethods) DropdownMenuItem(value: m, child: Text(m))],
                  onChanged: editable ? (v) => setState(() => _method = v ?? '') : null,
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: editable ? _pickDateTime : null,
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Payment Date (IST)${_hint(_needsMethodAndDate)}',
                      border: const OutlineInputBorder(),
                      suffixIcon: const Icon(Icons.event),
                      helperText: _dateIsLive ? 'Live — updates until you pick a time or save' : null,
                    ),
                    child: Row(children: [
                      Expanded(
                        child: Text(_date == null
                            ? 'Tap to select'
                            : '${DateFormat('dd-MM-yyyy h:mm:ss a').format(_date!)} IST'),
                      ),
                      if (!_dateIsLive && editable)
                        TextButton(
                          onPressed: () => setState(() {
                            _dateIsLive = true;
                            _date = _istNow();
                          }),
                          child: const Text('Use now', style: TextStyle(fontSize: 11)),
                        ),
                    ]),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _referenceController,
                  enabled: editable,
                  decoration: const InputDecoration(labelText: 'Payment Reference (optional)', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _notesController,
                  enabled: editable,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Payment Notes (optional)',
                    hintText: 'Enter payment related notes here…',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 24),
                if (_canEdit)
                  FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                    icon: _saving
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.save),
                    label: Text(_saving ? 'Saving…' : 'SAVE'),
                  ),
              ]),
            ),
    );
  }
}
