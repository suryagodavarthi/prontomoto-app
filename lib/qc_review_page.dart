// qc_review_page.dart
// "Preview QC": the QC review as a page, with the machine's own values beside the
// QC officer's — so an approver sees what the automatic checks and the photo
// reader concluded even where the officer changed it.
//
// The AI side is rebuilt, not remembered: the same rules the QC page runs, from
// the case data, with the photo reader's verdicts on top. The backend keeps what
// the reader SAW and recomputes its verdicts on every request, so asking again
// costs nothing unless the photos changed. The officer's side is the checklist QC
// saved, and qcChecklistReviewerKeys says which checks they decided by hand.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'date_format.dart';
import 'inspection_score.dart' show scoreInspection;
import 'qc_checklist.dart';
import 'services/api_service.dart';
import 'services/brand.dart';

class QcReviewPage extends StatefulWidget {
  final Map<String, dynamic> report;
  final String valuationId;
  final String vehicleNumber;
  final String applicantContact;
  final String? valuationType;
  final String? referenceNumber;
  final num? lowRange;
  final num? midRange;
  final num? highRange;

  const QcReviewPage({
    super.key,
    required this.report,
    required this.valuationId,
    required this.vehicleNumber,
    required this.applicantContact,
    this.valuationType,
    this.referenceNumber,
    this.lowRange,
    this.midRange,
    this.highRange,
  });

  @override
  State<QcReviewPage> createState() => _QcReviewPageState();
}

class _QcReviewPageState extends State<QcReviewPage> {
  final _api = ApiService();
  bool _loading = true;

  /// What the machine concluded, per check, and why.
  Map<String, String?> _ai = {};
  Map<String, String> _aiWhy = {};

  /// Keys the photo reader settled, and keys it looked at but could not.
  final Set<String> _readByAi = {};
  Map<String, String> _aiStatus = {};

  Map<String, dynamic>? _readings;
  String? _readAt;
  String? _aiError;
  List<String> _observations = [];

  /// What the QC officer saved, and which checks they decided by hand.
  Map<String, String?> _qc = {};
  Set<String> _reviewerKeys = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  static dynamic _get(Object? m, String key) {
    if (m is! Map) return null;
    if (m.containsKey(key)) return m[key];
    final lower = key.toLowerCase();
    for (final e in m.entries) {
      if (e.key.toString().toLowerCase() == lower) return e.value;
    }
    return null;
  }

  static String _s(Object? m, String key) {
    final v = _get(m, key);
    return (v == null || v.toString() == 'null') ? '' : v.toString();
  }

  Map? get _qcDoc => _get(widget.report, 'qualityControl') as Map?;
  Map? get _vd => _get(widget.report, 'vehicleDetails') as Map?;
  Map? get _ins => _get(widget.report, 'inspectionDetails') as Map?;

  List<String> _list(Object? v) => v is List ? [for (final x in v) x.toString()] : <String>[];
  Map<String, String> _map(Object? v) =>
      v is Map ? {for (final e in v.entries) if (e.value != null) e.key.toString(): e.value.toString()} : {};

  Future<void> _load() async {
    final audit = await _api.runAiPhotoAudit(widget.valuationId, widget.vehicleNumber, widget.applicantContact);
    if (!mounted) return;

    final readings = audit['readings'] is Map ? Map<String, dynamic>.from(audit['readings']) : null;
    final segment = _s(_get(widget.report, 'stakeholder'), 'vehicleSegment');
    final scores = scoreInspection(segment, _ins is Map ? Map<String, dynamic>.from(_ins!) : null,
        fallbackType: widget.valuationType);
    final photos = _get(widget.report, 'photoUrls');
    final photoKeys = photos is Map
        ? [for (final e in photos.entries) if (e.value != null && e.value.toString().isNotEmpty) e.key.toString()]
        : <String>[];

    final status = _map(audit['status']);
    final auditCl = _map(audit['cl']);

    // The machine's view: the rules, fed machine inputs. The overall rating is the
    // score derived from the AVO's answers. The chassis punch is the one the photo
    // reader read; the final recommendation needs one, so where the reader read
    // none it falls back to the officer's, and the Chassis Punch card says so.
    final aiPunch = audit['error'] == null ? chassisPunchLabels[auditCl['docChassis']] : null;
    final machine = buildQcChecklist(
      report: widget.report,
      overallRating: scores.overall?.toStringAsFixed(1),
      chassisPunch: aiPunch ?? _s(_qcDoc, 'chassisPunch'),
      photoKeys: photoKeys,
      vehicleSegment: segment,
      valuationType: widget.valuationType,
      aiFindings: readings == null
          ? null
          : QcAiFindings(
              damage: _list(readings['damageFound']),
              missingParts: _list(readings['missingParts']),
              photosRead: true,
            ),
    );

    if (audit['error'] == null) {
      _map(audit['why']).forEach((k, v) {
        if (v.isNotEmpty) machine.why[k] = v;
      });
      // A check the reader looked at and could not settle is undecided, not failed.
      status.forEach((k, st) {
        if (st == 'unresolved' && (auditCl[k] ?? '').isEmpty) machine.cl[k] = null;
      });
      auditCl.forEach((k, v) {
        if (v.isEmpty) return;
        machine.cl[k] = v;
        _readByAi.add(k);
      });
    }

    if (!_readByAi.contains('docChassis')) {
      machine.cl['docChassis'] = null;
      machine.why['docChassis'] = 'Not judged by the AI: the photo reader did not settle the chassis punch, '
          "so it is the QC officer's call.";
    }

    final saved = _get(_qcDoc, 'qcChecklist');
    setState(() {
      _ai = machine.cl;
      _aiWhy = machine.why;
      _aiStatus = status;
      _readings = readings;
      _readAt = audit['readAt']?.toString();
      _aiError = audit['error']?.toString();
      _observations = _list(audit['observations']);
      _qc = saved is Map ? {for (final e in saved.entries) e.key.toString(): e.value?.toString()} : {};
      // docHypo was same/different before it became yes/no.
      final hypo = _qc['docHypo'];
      if (hypo == 'same') _qc['docHypo'] = 'no';
      if (hypo == 'different') _qc['docHypo'] = 'yes';
      _reviewerKeys = _list(_get(_qcDoc, 'qcChecklistReviewerKeys')).toSet();
      _loading = false;
    });
  }

  // ── layout ────────────────────────────────────────────────────────────────

  static final NumberFormat _inr = NumberFormat.decimalPattern('en_IN');
  static String _money(num? n) => n == null ? '—' : '₹${_inr.format(n.round())}';

  bool _changed(String key) => _qc.containsKey(key) && _qc[key] != _ai[key];

  Iterable<QcCard> get _allCards sync* {
    for (final section in qcChecklistSections) {
      for (final group in section.groups) {
        yield* group.cards;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF525659), // the grey a PDF viewer sits on
      appBar: AppBar(title: Text("QC review — ${widget.vehicleNumber}", style: const TextStyle(fontSize: 16))),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : InteractiveViewer(
              minScale: 1,
              maxScale: 4,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(10),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.35), blurRadius: 8, offset: const Offset(0, 3))],
                  ),
                  child: _paper(),
                ),
              ),
            ),
    );
  }

  Widget _paper() {
    final brand = Brand.profile;
    final dark = Color.lerp(brand.color, Colors.black, 0.3)!;
    final checks = _allCards.where((c) => _ai.containsKey(c.key) || _qc.containsKey(c.key)).toList();
    final changedByOfficer = checks.where((c) => _changed(c.key) && _reviewerKeys.contains(c.key)).length;
    final otherDiffs = checks.where((c) => _changed(c.key) && !_reviewerKeys.contains(c.key)).length;

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      // Header
      Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(gradient: LinearGradient(colors: [dark, brand.color])),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('QC REVIEW — AI VS QC OFFICER',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13, letterSpacing: 0.4)),
              Text('${brand.name} Vehicle Valuation Platform', style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 11)),
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('Date: ${DateFormat('dd-MM-yyyy').format(DateTime.now())}', style: const TextStyle(color: Colors.white, fontSize: 11)),
            if ((widget.referenceNumber ?? '').isNotEmpty)
              Text('Ref: ${widget.referenceNumber}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
          ]),
        ]),
      ),
      // Vehicle line and the count of changes
      Container(
        color: const Color(0xFFF8FAFC),
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${_s(_vd, 'make')} ${_s(_vd, 'model')}  ·  ${_s(_vd, 'registrationNumber').isEmpty ? widget.vehicleNumber : _s(_vd, 'registrationNumber')}',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: dark)),
          const SizedBox(height: 6),
          Text.rich(TextSpan(style: const TextStyle(fontSize: 12.5, color: Color(0xFF374151)), children: [
            TextSpan(text: '${checks.length} checks  ·  '),
            TextSpan(
                text: '$changedByOfficer changed by the QC officer',
                style: TextStyle(fontWeight: FontWeight.bold, color: changedByOfficer > 0 ? const Color(0xFFB45309) : const Color(0xFF15803D))),
            if (otherDiffs > 0) TextSpan(text: '  ·  $otherDiffs saved differently from today\'s AI result'),
          ])),
          const SizedBox(height: 6),
          Wrap(spacing: 10, runSpacing: 4, children: [
            _legend(const Color(0xFFFFF7ED), const Color(0xFFF59E0B), 'Changed by the QC officer'),
            _legend(const Color(0xFFF8FAFC), const Color(0xFFCBD5E1), 'AI = automatic checks + photo reader'),
          ]),
        ]),
      ),
      _heading(brand, dark, '1. WHAT THE PHOTO READER SAW'),
      ..._readerSection(),
      _heading(brand, dark, '2. VALUATION'),
      _valuation(),
      for (final section in qcChecklistSections) ...[
        _heading(brand, dark, '${3 + qcChecklistSections.indexOf(section)}. ${section.title.toUpperCase()}'),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
          child: Column(children: [
            _tableHead(),
            for (final group in section.groups)
              for (final card in group.cards)
                if (_ai.containsKey(card.key) || _qc.containsKey(card.key)) _checkRow(card),
            if ((_map(_get(_qcDoc, 'qcChecklistRemarks'))[section.id] ?? '').trim().isNotEmpty)
              _note('QC officer\'s remarks: ', _map(_get(_qcDoc, 'qcChecklistRemarks'))[section.id]!.trim()),
          ]),
        ),
      ],
      if (_s(_qcDoc, 'remarks').trim().isNotEmpty)
        Padding(padding: const EdgeInsets.fromLTRB(12, 0, 12, 10), child: _note('General remarks: ', _s(_qcDoc, 'remarks').trim())),
      Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        color: const Color(0xFFF8FAFC),
        child: Text(
          'The AI column is what the automatic checks and the photo reader conclude from this case\'s data and photos today. '
          'The QC officer column is what QC saved.',
          style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600),
        ),
      ),
    ]);
  }

  Widget _legend(Color fill, Color edge, String text) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 14, height: 10, decoration: BoxDecoration(color: fill, border: Border.all(color: edge))),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
      ]);

  Widget _heading(BrandProfile brand, Color dark, String text) => Container(
        margin: const EdgeInsets.only(top: 4),
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          border: Border(left: BorderSide(color: brand.color, width: 4), bottom: BorderSide(color: brand.color, width: 2)),
        ),
        child: Text(text, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, letterSpacing: 0.5, color: dark)),
      );

  Widget _row(String label, String value, {String? compare, bool mismatch = false}) => Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFF3F4F6)))),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 120, child: Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)))),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(value.isEmpty ? '—' : value,
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: mismatch ? const Color(0xFFB91C1C) : const Color(0xFF1F2937))),
              if (compare != null) Text(compare, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
            ]),
          ),
        ]),
      );

  List<Widget> _readerSection() {
    if (_aiError != null) {
      return [Padding(padding: const EdgeInsets.all(12), child: Text('The photo reader could not run: $_aiError', style: const TextStyle(color: Color(0xFFB45309))))];
    }
    final r = _readings;
    if (r == null) {
      return [const Padding(padding: EdgeInsets.all(12), child: Text('The photos have not been read for this case.', style: TextStyle(color: Colors.grey)))];
    }
    String norm(String v) => v.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    final plate = _s(r, 'registrationPlate');
    final rcPlate = _s(_vd, 'registrationNumber');
    final chassis = _s(r, 'chassisNumber');
    final rcChassis = _s(_vd, 'chassisNumber');
    final odoPhoto = num.tryParse(_s(r, 'odometerKm'));
    final odoAvo = num.tryParse(_s(_ins, 'odometer'));
    final readAt = formatDdMmYyyyHhMm(_readAt);

    return [
      if (readAt.isNotEmpty)
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 2),
          child: Text('Read on $readAt', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
        ),
      _row('Number plate', plate.isEmpty ? 'Not read' : plate,
          compare: rcPlate.isEmpty ? null : 'RC: $rcPlate',
          mismatch: plate.isNotEmpty && rcPlate.isNotEmpty && norm(plate) != norm(rcPlate)),
      _row('Chassis number', chassis.isEmpty ? 'Not read' : chassis,
          compare: rcChassis.isEmpty ? null : 'RC: $rcChassis',
          mismatch: chassis.isNotEmpty && rcChassis.isNotEmpty && norm(chassis) != norm(rcChassis)),
      _row('Chassis stencil', _s(r, 'chassisStencil').isEmpty ? 'Not read' : _s(r, 'chassisStencil')),
      _row('VIN plate', _s(r, 'vinPlate').isEmpty ? 'Not read' : _s(r, 'vinPlate')),
      _row('Odometer', odoPhoto == null || odoPhoto <= 0 ? 'Not read' : '${_inr.format(odoPhoto)} km',
          compare: odoAvo == null || odoAvo <= 0 ? null : 'AVO recorded: ${_inr.format(odoAvo)} km',
          mismatch: odoPhoto != null && odoPhoto > 0 && odoAvo != null && odoAvo > 0 && odoPhoto != odoAvo),
      _row('Photo locations', _list(r['places']).join(' · ')),
      _row('Capture dates', _list(r['captureDates']).join(' · ')),
      _row('Stamped photos', '${_s(r, 'stampedPhotos').isEmpty ? '0' : _s(r, 'stampedPhotos')} of ${_s(r, 'totalPhotos').isEmpty ? '0' : _s(r, 'totalPhotos')}'),
      _row('Damage seen', _list(r['damageFound']).isEmpty ? 'None' : _list(r['damageFound']).join('\n')),
      _row('Missing parts seen', _list(r['missingParts']).isEmpty ? 'None' : _list(r['missingParts']).join('\n')),
      if (_observations.isNotEmpty)
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Observations', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            for (final o in _observations) Text('• $o', style: const TextStyle(fontSize: 11.5, color: Color(0xFF374151))),
          ]),
        ),
    ];
  }

  Widget _valuation() {
    final amount = num.tryParse(_s(_qcDoc, 'valuationAmount'));
    final hasRange = (widget.lowRange ?? 0) > 0 && (widget.highRange ?? 0) > 0;
    final inRange = hasRange && amount != null && amount >= widget.lowRange! && amount <= widget.highRange!;
    return Column(children: [
      _row('AI market range',
          hasRange ? '${_money(widget.lowRange)}  –  ${_money(widget.highRange)}' : 'Not available',
          compare: hasRange && widget.midRange != null ? 'Mid: ${_money(widget.midRange)}' : null),
      _row('QC valuation', _money(amount),
          compare: hasRange ? (inRange ? 'Within the AI market range' : 'Outside the AI market range') : null,
          mismatch: hasRange && !inRange),
      _row('Chassis punch', _s(_qcDoc, 'chassisPunch').isEmpty ? 'Not recorded' : _s(_qcDoc, 'chassisPunch'),
          compare: 'Saved by the QC officer'),
    ]);
  }

  Widget _tableHead() => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: const [
          Expanded(child: Text('CHECK', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF9CA3AF)))),
          SizedBox(width: 92, child: Text('AI', textAlign: TextAlign.center, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF9CA3AF)))),
          SizedBox(width: 92, child: Text('QC OFFICER', textAlign: TextAlign.center, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF9CA3AF)))),
        ]),
      );

  Widget _badge(String key, String? value) {
    final pill = qcPillFor(key, value);
    final (bg, fg) = qcBadgeColours(pill?.tone);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(pill?.label ?? '—', textAlign: TextAlign.center, maxLines: 2,
          style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: fg)),
    );
  }

  Widget _checkRow(QcCard card) {
    final changed = _changed(card.key);
    final byOfficer = changed && _reviewerKeys.contains(card.key);
    final why = splitEvidence(_aiWhy[card.key]);
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 7, 6, 7),
      margin: const EdgeInsets.only(bottom: 2),
      decoration: BoxDecoration(
        color: byOfficer ? const Color(0xFFFFF7ED) : null,
        border: byOfficer
            ? const Border(left: BorderSide(color: Color(0xFFF59E0B), width: 3))
            : const Border(bottom: BorderSide(color: Color(0xFFF3F4F6))),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Text(card.title.replaceFirst(RegExp(r'^\d+\.\s*'), '').replaceAll(' *', ''),
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF1F2937))),
          ),
          SizedBox(width: 92, child: Center(child: _badge(card.key, _ai[card.key]))),
          SizedBox(width: 92, child: Center(child: _badge(card.key, _qc.containsKey(card.key) ? _qc[card.key] : _ai[card.key]))),
        ]),
        if (why.lead.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text.rich(TextSpan(style: TextStyle(fontSize: 11, color: Colors.grey.shade700), children: [
              TextSpan(text: _readByAi.contains(card.key) ? 'Photo reader: ' : (_aiStatus[card.key] == 'unresolved' ? 'Photo reader, inconclusive: ' : 'AI: '),
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              TextSpan(text: why.full ?? why.lead),
            ])),
          ),
        if (byOfficer)
          const Padding(
            padding: EdgeInsets.only(top: 3),
            child: Text('Changed by the QC officer', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFFB45309))),
          )
        else if (changed)
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text('Saved differently from today\'s AI result (the case data or photos may have changed since QC saved)',
                style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600)),
          ),
      ]),
    );
  }

  Widget _note(String label, String text) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(top: 6),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: const Color(0xFFF9FAFB), border: Border(left: BorderSide(color: Brand.profile.color, width: 3))),
        child: Text.rich(TextSpan(style: const TextStyle(fontSize: 12, color: Color(0xFF374151)), children: [
          TextSpan(text: label, style: const TextStyle(fontWeight: FontWeight.bold)),
          TextSpan(text: text),
        ])),
      );
}
