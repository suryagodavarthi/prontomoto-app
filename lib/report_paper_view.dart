// report_paper_view.dart
// The case laid out like the report: the header with the Unique ID, the vehicle
// and its valuation, then numbered sections. Mirrors the "report paper" on the
// portal's Final Report page (final-report.component.html). The QC page shows the
// case part (sections 1-3 and the photos); the Final Report page passes the QC
// checklist too, and gets the whole report: checklist summary, condition
// assessment, the photos QC chose, and the final recommendation.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'date_format.dart';
import 'inspection_score.dart' show mapVerdict, scoreBand, ScoreBand;
import 'services/brand.dart';

class ReportPaperView extends StatelessWidget {
  final Map<String, dynamic> report;
  final String valuationId;
  final String? referenceNumber;

  /// The valuation as QC has it now, so the figure updates while they type.
  final num? valuationAmount;

  /// Overall score as shown ("8.2"), or null when nothing is scored yet.
  final String? rating;

  final num? lowRange;
  final num? midRange;
  final num? highRange;
  final bool rangeLoading;

  /// Original / Re-Punched / Tampered, as QC has it now.
  final String? chassisPunch;

  /// Opens a photo full screen.
  final void Function(String url, String label) onPhotoTap;

  /// Shown above the photo grid, e.g. the report photo selector.
  final Widget? photoAction;

  /// The QC checklist. When given, the view is the whole report: sections 4 and
  /// 5, the final recommendation, and only the photos in [selectedPhotoKeys].
  final Map<String, String?>? checklist;

  /// The QC checklist remarks; 'rec' is printed under the condition assessment.
  final Map<String, String>? checklistRemarks;

  /// The BRAKES section score, for the condition assessment's Brakes tile.
  final double? brakesScore;

  /// Photos QC chose for the report; null or empty means all of them.
  final List<String>? selectedPhotoKeys;

  const ReportPaperView({
    super.key,
    required this.report,
    required this.valuationId,
    this.referenceNumber,
    this.valuationAmount,
    this.rating,
    this.lowRange,
    this.midRange,
    this.highRange,
    this.rangeLoading = false,
    this.chassisPunch,
    required this.onPhotoTap,
    this.photoAction,
    this.checklist,
    this.checklistRemarks,
    this.brakesScore,
    this.selectedPhotoKeys,
  });

  // ── data ──────────────────────────────────────────────────────────────────

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

  Map? get _vd => _get(report, 'vehicleDetails') as Map?;
  Map? get _ins => _get(report, 'inspectionDetails') as Map?;
  Map? get _st => _get(report, 'stakeholder') as Map?;

  static final NumberFormat _inr = NumberFormat.decimalPattern('en_IN');
  static String _money(num? n) => n == null ? '—' : '₹${_inr.format(n.round())}';

  bool get _hasRange => (lowRange ?? 0) > 0 && (highRange ?? 0) > 0;
  bool get _inRange {
    final a = valuationAmount ?? 0;
    return _hasRange && a >= lowRange! && a <= highRange!;
  }

  /// Uploaded photos, front view first: it is the photo the report leads with.
  List<MapEntry<String, String>> get _photos {
    final photos = _get(report, 'photoUrls');
    if (photos is! Map) return [];
    final list = [
      for (final e in photos.entries)
        if (e.value != null && e.value.toString().startsWith('http')) MapEntry(e.key.toString(), e.value.toString()),
    ];
    int rank(String k) => k == 'FrontViewGrille' ? 0 : k == 'FrontLeftSide' ? 1 : 2;
    list.sort((a, b) => rank(a.key).compareTo(rank(b.key)));
    return list;
  }

  /// The photos the report prints: QC's selection, where it made one.
  List<MapEntry<String, String>> get _reportPhotos {
    final chosen = selectedPhotoKeys ?? const [];
    if (chosen.isEmpty) return _photos;
    return _photos.where((p) => chosen.contains(p.key)).toList();
  }

  String get _chassisPunchLabel {
    // QC's field first, then the checklist's verdict, as the portal's chassisPunchLabel reads them.
    var raw = (chassisPunch ?? _s(_get(report, 'qualityControl'), 'chassisPunch')).trim();
    if (raw.isEmpty) raw = (checklist?['docChassis'] ?? '').trim();
    switch (raw.toUpperCase().replaceAll(RegExp(r'[-\s]'), '')) {
      case 'ORIGINAL':
        return 'ORIGINAL';
      case 'REPUNCHED':
        return 'RE-PUNCHED';
      case 'TAMPERED':
        return 'TAMPERED';
      default:
        return raw.isEmpty ? 'NOT RECORDED' : raw.toUpperCase();
    }
  }

  /// "FrontLeftSide" → "Front Left Side".
  static String _photoLabel(String key) =>
      key.replaceAllMapped(RegExp(r'([a-z0-9])([A-Z])'), (m) => '${m[1]} ${m[2]}').replaceAll(RegExp(r'[_-]+'), ' ');

  // ── layout ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final brand = Brand.profile;
    final dark = Color.lerp(brand.color, Colors.black, 0.3)!;
    final photos = _photos;
    final cl = checklist;
    final gallery = cl == null ? photos : _reportPhotos;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _header(brand, dark),
        _hero(context, brand, dark, photos),
        _section(brand, dark, '1. STAKEHOLDER & APPLICANT', [
          _row('Stakeholder', _s(_st, 'name')),
          _row('Executive', _s(_st, 'executiveName')),
          _row('Contact', _s(_st, 'executiveContact')),
          _row('WhatsApp', _s(_st, 'executiveWhatsapp')),
          _row('Email', _s(_st, 'executiveEmail')),
          _row('Applicant Name', _s(_get(_st, 'applicant'), 'name')),
          _row('Applicant Contact', _s(_get(_st, 'applicant'), 'contact')),
        ]),
        _section(brand, dark, '2. VEHICLE DETAILS', [
          _row('Registration No', _s(_vd, 'registrationNumber'), mono: true),
          _row('Make', _s(_vd, 'make')),
          _row('Model', _s(_vd, 'model')),
          _row('Year of Manufacture', _s(_vd, 'yearOfMfg')),
          _row('Body Type', _s(_vd, 'bodyType')),
          _row('Fuel Type', _s(_vd, 'fuel')),
          _row('Colour', _s(_vd, 'colour')),
          _row('RTO', _s(_vd, 'rto')),
          _row('Chassis Number', _s(_vd, 'chassisNumber'), mono: true),
          _row('Engine Number', _s(_vd, 'engineNumber'), mono: true),
          _row('Owner Name', _s(_vd, 'ownerName')),
          _row('Class of Vehicle', _s(_vd, 'classOfVehicle')),
          _badgeRow('Chassis Punch Status', _chassisPunchLabel),
          _row('Hypothecation', _s(_vd, 'hypothecation') == 'true' ? (_s(_vd, 'lender').isEmpty ? 'Yes' : _s(_vd, 'lender')) : 'NIL'),
          if (_s(_vd, 'remarks').isNotEmpty) _remarks(brand, _s(_vd, 'remarks')),
        ]),
        _section(brand, dark, '3. INSPECTION DETAILS', [
          _row('Inspected By', _s(_ins, 'vehicleInspectedBy')),
          _row('Date of Inspection', formatDdMmYyyy(_s(_ins, 'dateOfInspection'))),
          _row('Inspection Location', _s(_ins, 'inspectionLocation')),
          _row('Odometer Reading', _odometerText(), mono: true),
          _row('Accident Status', _yesNo(_s(_ins, 'accidental'))),
          _row('Transmission Type', _s(_ins, 'transmissionType')),
          if (_s(_ins, 'remarks').isNotEmpty) _remarks(brand, _s(_ins, 'remarks')),
        ]),
        if (cl != null) ...[
          _section(brand, dark, '4. QC CHECKLIST SUMMARY', _checklistRows(cl)),
          _section(brand, dark, '5. CONDITION ASSESSMENT', _conditionAssessment(cl)),
        ],
        _section(brand, dark, '${cl == null ? 4 : 6}. VEHICLE PHOTOGRAPHS (${gallery.length})', [
          if (photoAction != null) Padding(padding: const EdgeInsets.only(bottom: 10), child: photoAction!),
          if (gallery.isEmpty)
            const Text('No photos available.', style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic))
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3, crossAxisSpacing: 6, mainAxisSpacing: 6, childAspectRatio: 0.82),
              itemCount: gallery.length,
              itemBuilder: (_, i) {
                final p = gallery[i];
                final label = _photoLabel(p.key);
                return InkWell(
                  onTap: () => onPhotoTap(p.value, label),
                  child: Column(children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: Image.network(p.value,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            errorBuilder: (_, _, _) => Container(
                                color: Colors.grey.shade200, child: const Icon(Icons.broken_image, color: Colors.grey))),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 9.5)),
                  ]),
                );
              },
            ),
        ]),
        if (cl != null) _finalRecommendation(cl),
        _footer(brand),
      ]),
    );
  }

  // ── The report's checklist, condition and recommendation ─────────────────

  static const _green = (Color(0xFFDCFCE7), Color(0xFF15803D));
  static const _amber = (Color(0xFFFEF3C7), Color(0xFFA16207));
  static const _red = (Color(0xFFFEE2E2), Color(0xFFB91C1C));
  static const _grey = (Color(0xFFF1F5F9), Color(0xFF94A3B8));

  /// One verdict as the report prints it: the word, in its colour, and nothing else.
  static Widget verdictBadge(String text, (Color, Color) colours) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(color: colours.$1, borderRadius: BorderRadius.circular(20)),
        child: Text(text, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: colours.$2)),
      );

  /// The badge for a checklist verdict, in the report's words.
  static (String, (Color, Color)) checklistBadge(String key, String? v) {
    if (key == 'docHypo') {
      return v == 'no' ? ('✓ No', _green) : v == 'yes' ? ('● Yes', _amber) : ('—', _grey);
    }
    switch (v) {
      case 'ok':
        return ('✓ OK', _green);
      case 'flag':
        return ('✗ Flag', _red);
      case 'pass':
        return ('✓ Pass', _green);
      case 'fail':
        return ('✗ Fail', _red);
      case 'na':
        return ('N/A', _grey);
      default:
        return ('—', _grey);
    }
  }

  List<Widget> _checklistRows(Map<String, String?> cl) {
    Widget sub(String t) => Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 2),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(t, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.6, color: Color(0xFF6B7280))),
          ),
        );
    Widget row(String key, String label) {
      final (text, colours) = checklistBadge(key, cl[key]);
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFF3F4F6)))),
        child: Row(children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 12.5, color: Color(0xFF374151)))),
          verdictBadge(text, colours),
        ]),
      );
    }

    return [
      sub('DOCUMENT VERIFICATION'),
      row('docRC', 'Registration Certificate (RC)'),
      row('docIns', 'Insurance Policy'),
      row('docPermit', 'Permit'),
      row('docFitness', 'Fitness Certificate'),
      row('docTax', 'Road Tax'),
      row('docHypo', 'Hypothecation'),
      sub('DATA ACCURACY'),
      row('accReg', 'Registration No matches photos & RC'),
      row('accChassis', 'Chassis No matches photos, RC & stencil'),
      row('accOdo', 'Odometer reading matches reported KM'),
      row('accVIN', 'VIN plate matches RC & inspection report'),
      row('accMfgReg', 'Manufacture year vs registration gap logical'),
      row('accVahan', 'VAHAN data matches inspection findings'),
      row('accTransmission', 'Transmission type consistent with RC variant'),
      sub('VALUATION QUALITY'),
      row('valMinPhotos', 'Minimum required photos uploaded'),
      row('valDedupe', 'Blacklist check completed'),
      row('valAgeOdo', 'Vehicle age & odometer reading consistent'),
      row('valScore', 'Checklist ratings support overall vehicle score'),
    ];
  }

  static const _cvGreen = (Color(0xFFF0FDF4), Color(0xFF15803D));
  static const _cvAmber = (Color(0xFFFFFBEB), Color(0xFFA16207));
  static const _cvRed = (Color(0xFFFEF2F2), Color(0xFFB91C1C));
  static const _cvPlain = (Color(0xFFF8FAFC), Color(0xFF374151));
  static const _cvUnset = (Color(0xFFF8FAFC), Color(0xFF94A3B8));

  /// Colour for a condition the AVO recorded, read the way the scoring engine reads it.
  static (Color, Color) _condColours(String? value) {
    switch (mapVerdict(value)) {
      case 'GOOD':
      case 'YES':
        return _cvGreen;
      case 'AVERAGE':
        return _cvAmber;
      case 'POOR':
      case 'BAD':
      case 'DAMAGED':
      case 'MISSING':
      case 'NO':
        return _cvRed;
      default:
        return _cvUnset;
    }
  }

  List<Widget> _conditionAssessment(Map<String, String?> cl) {
    (String, (Color, Color)) pick(String? v, Map<String, (String, (Color, Color))> m) => m[v] ?? ('—', _cvUnset);

    final engineStarted = _s(_ins, 'engineStarted');
    final roadWorthy = _s(_ins, 'roadWorthyCondition') == 'true';
    final brakesBand = scoreBand(brakesScore);
    final tiles = <(String, (String, (Color, Color)))>[
      ('Exterior Condition', pick(cl['recExterior'], {'good': ('GOOD', _cvGreen), 'minor': ('MINOR DAMAGE', _cvAmber), 'major': ('MAJOR DAMAGE', _cvRed)})),
      ('Engine / Mechanical', pick(cl['recEngine'], {'good': ('GOOD', _cvGreen), 'average': ('AVERAGE', _cvAmber), 'poor': ('POOR', _cvRed)})),
      ('Tyre Condition', pick(cl['recTyre'], {'good': ('GOOD', _cvGreen), 'average': ('AVERAGE', _cvAmber), 'replacement': ('NEEDS REPLACEMENT', _cvRed)})),
      ('Damage Detected', pick(cl['recDamage'], {'none': ('NONE', _cvGreen), 'minor': ('MINOR', _cvAmber), 'major': ('MAJOR', _cvRed)})),
      ('Missing Parts', pick(cl['recMissingParts'], {'none': ('NONE', _cvGreen), 'present': ('PARTS MISSING', _cvRed)})),
      ('Engine Started', (engineStarted.isEmpty ? '—' : engineStarted, _condColours(engineStarted))),
      ('Road Worthy', (roadWorthy ? 'YES' : 'NO', roadWorthy ? _cvGreen : _cvRed)),
      ('Transmission Type', (_s(_ins, 'transmissionType').isEmpty ? '—' : _s(_ins, 'transmissionType'), _cvPlain)),
      ('Brakes', (
        brakesScore == null ? '—' : '${brakesScore!.toStringAsFixed(1)} / 10',
        brakesBand == ScoreBand.good ? _cvGreen : brakesBand == ScoreBand.average ? _cvAmber : brakesBand == ScoreBand.poor ? _cvRed : _cvUnset,
      )),
    ];

    final remarks = (checklistRemarks?['rec'] ?? '').trim();
    return [
      GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 2.3,
        children: [
          for (final (label, (value, colours)) in tiles)
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: colours.$1,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(label, style: const TextStyle(fontSize: 10.5, color: Color(0xFF6B7280))),
                const SizedBox(height: 2),
                Text(value,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: colours.$2)),
              ]),
            ),
        ],
      ),
      if (remarks.isNotEmpty) _remarks(Brand.profile, remarks, label: 'QC Summary Remarks: '),
    ];
  }

  Widget _finalRecommendation(Map<String, String?> cl) {
    final rec = cl['recFinal'];
    final (bg, edge) = switch (rec) {
      'recommended' => (const Color(0xFFF0FDF4), const Color(0xFF86EFAC)),
      'conditional' => (const Color(0xFFFFFBEB), const Color(0xFFFDE68A)),
      'not-recommended' => (const Color(0xFFFEF2F2), const Color(0xFFFCA5A5)),
      _ => (const Color(0xFFF8FAFC), const Color(0xFFE5E7EB)),
    };
    Widget item(String label, String value, Color colour) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
            Text(value, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: colour)),
          ]),
        );
    Color tone(String? v, String good, String mid, String bad) =>
        v == good ? _cvGreen.$2 : v == mid ? _cvAmber.$2 : v == bad ? _cvRed.$2 : _cvUnset.$2;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: bg, border: Border(top: BorderSide(color: edge, width: 2))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('FINAL QC RECOMMENDATION',
            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, letterSpacing: 0.6, color: Color(0xFF6B7280))),
        const SizedBox(height: 4),
        item('1. Overall Vehicle Condition',
            {'good': 'GOOD', 'average': 'AVERAGE', 'poor': 'POOR'}[cl['recCondition']] ?? '—',
            tone(cl['recCondition'], 'good', 'average', 'poor')),
        item('2. Chassis Punch',
            {'original': 'ORIGINAL', 'repunched': 'RE-PUNCHED', 'tampered': 'TAMPERED'}[cl['docChassis']] ?? '—',
            tone(cl['docChassis'], 'original', 'repunched', 'tampered')),
        item('3. Final QC Recommendation',
            {'recommended': 'RECOMMENDED', 'conditional': 'RECOMMENDED WITH CONDITIONS', 'not-recommended': 'NOT RECOMMENDED'}[rec] ?? '—',
            tone(rec, 'recommended', 'conditional', 'not-recommended')),
      ]),
    );
  }

  String _odometerText() {
    final odo = num.tryParse(_s(_ins, 'odometer'));
    if (odo != null && odo > 0) return '${_inr.format(odo)} km';
    final remark = _s(_ins, 'odometerRemark');
    return remark.isEmpty ? '—' : remark;
  }

  static String _yesNo(String v) => v == 'true' ? 'YES' : v == 'false' ? 'NO' : '—';

  Widget _header(BrandProfile brand, Color dark) {
    final created = formatDdMmYyyy(_s(report, 'createdAt'));
    final ref = (referenceNumber ?? '').isNotEmpty
        ? referenceNumber!
        : (valuationId.length >= 8 ? valuationId.substring(0, 8).toUpperCase() : valuationId);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(gradient: LinearGradient(colors: [dark, brand.color])),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('VEHICLE INSPECTION & VALUATION REPORT',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13, letterSpacing: 0.4)),
            const SizedBox(height: 2),
            Text('${brand.name} Vehicle Valuation Platform',
                style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 11)),
          ]),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          if (created.isNotEmpty) Text('Date: $created', style: const TextStyle(color: Colors.white, fontSize: 11)),
          Text('Ref: $ref', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
        ]),
      ]),
    );
  }

  Widget _hero(BuildContext context, BrandProfile brand, Color dark, List<MapEntry<String, String>> photos) {
    final meta = [_s(_vd, 'yearOfMfg'), _s(_vd, 'fuel'), _s(_vd, 'bodyType'), _s(_vd, 'colour')]
        .where((s) => s.isNotEmpty)
        .join(' · ');
    final owner = _s(_vd, 'ownerName');

    final identity = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('${_s(_vd, 'make')} ${_s(_vd, 'model')}'.trim(),
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: dark)),
      const SizedBox(height: 2),
      Text(_s(_vd, 'registrationNumber'),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 1.2, fontFamily: 'monospace')),
      if (meta.isNotEmpty) Text(meta, style: TextStyle(fontSize: 11.5, color: Colors.grey.shade700)),
      const SizedBox(height: 2),
      Text('Owner: ${owner.isEmpty ? '—' : owner}', style: TextStyle(fontSize: 11.5, color: Colors.grey.shade700)),
    ]);

    return Container(
      color: const Color(0xFFF8FAFC),
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          GestureDetector(
            onTap: photos.isEmpty ? null : () => onPhotoTap(photos.first.value, _photoLabel(photos.first.key)),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                width: 120,
                height: 90,
                child: photos.isEmpty
                    ? Container(
                        color: Colors.grey.shade200,
                        alignment: Alignment.center,
                        child: const Text('NO IMAGE', style: TextStyle(fontSize: 11, color: Colors.grey)))
                    : Image.network(photos.first.value,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(color: Colors.grey.shade200)),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: identity),
        ]),
        const SizedBox(height: 12),
        _valuationBox(brand, dark),
      ]),
    );
  }

  Widget _valuationBox(BrandProfile brand, Color dark) {
    Widget rangeItem(String l, num? v, Color c) => Expanded(
          child: Column(children: [
            Text(l, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: c, letterSpacing: 0.5)),
            Text(_money(v), style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: c)),
          ]),
        );

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: brand.color.withOpacity(0.35)),
      ),
      child: Column(children: [
        Text('QC RECOMMENDED VALUATION',
            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 0.6, color: Colors.grey.shade700)),
        const SizedBox(height: 2),
        Text(_money(valuationAmount), style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: dark)),
        Text.rich(TextSpan(style: TextStyle(fontSize: 12, color: Colors.grey.shade800), children: [
          const TextSpan(text: 'Rating: '),
          TextSpan(text: '${rating ?? '—'} / 10', style: const TextStyle(fontWeight: FontWeight.bold)),
        ])),
        const SizedBox(height: 8),
        if (_hasRange) ...[
          Row(children: [
            rangeItem('LOW', lowRange, const Color(0xFFDC2626)),
            rangeItem('MID', midRange, brand.color),
            rangeItem('HIGH', highRange, const Color(0xFF16A34A)),
          ]),
          const SizedBox(height: 6),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(_inRange ? Icons.check_circle : Icons.warning_amber_rounded,
                size: 15, color: _inRange ? const Color(0xFF059669) : const Color(0xFFDC2626)),
            const SizedBox(width: 4),
            Text(_inRange ? 'Within Market Range' : 'Outside Market Range',
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w700, color: _inRange ? const Color(0xFF059669) : const Color(0xFFDC2626))),
          ]),
        ] else
          // No range is a different thing from a range of zero.
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFFCBD5E1)),
            ),
            child: Text(rangeLoading ? 'Fetching market range…' : 'Market range not available for this vehicle.',
                textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
          ),
      ]),
    );
  }

  Widget _section(BrandProfile brand, Color dark, String heading, List<Widget> children) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          border: Border(
            left: BorderSide(color: brand.color, width: 4),
            bottom: BorderSide(color: brand.color, width: 2),
          ),
        ),
        child: Text(heading, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, letterSpacing: 0.5, color: dark)),
      ),
      Padding(padding: const EdgeInsets.fromLTRB(12, 6, 12, 10), child: Column(children: children)),
    ]);
  }

  Widget _row(String label, String value, {bool mono = false}) => Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFF3F4F6)))),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 130, child: Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)))),
          Expanded(
            child: Text(value.isEmpty ? '—' : value,
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1F2937),
                    fontFamily: mono ? 'monospace' : null)),
          ),
        ]),
      );

  Widget _badgeRow(String label, String value) {
    final (bg, fg) = switch (value) {
      'ORIGINAL' => (const Color(0xFFDCFCE7), const Color(0xFF15803D)),
      'RE-PUNCHED' => (const Color(0xFFFEF3C7), const Color(0xFFA16207)),
      'TAMPERED' => (const Color(0xFFFEE2E2), const Color(0xFFB91C1C)),
      _ => (const Color(0xFFF1F5F9), const Color(0xFF64748B)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFF3F4F6)))),
      child: Row(children: [
        SizedBox(width: 130, child: Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)))),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
          child: Text(value, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: fg)),
        ),
      ]),
    );
  }

  Widget _remarks(BrandProfile brand, String text, {String label = 'Remarks: '}) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          border: Border(left: BorderSide(color: brand.color, width: 3)),
        ),
        child: Text.rich(TextSpan(style: const TextStyle(fontSize: 12, color: Color(0xFF374151)), children: [
          TextSpan(text: label, style: const TextStyle(fontWeight: FontWeight.bold)),
          TextSpan(text: text),
        ])),
      );

  Widget _footer(BrandProfile brand) => Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        color: const Color(0xFFF8FAFC),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('GENERATED BY', style: TextStyle(fontSize: 9.5, color: Colors.grey, letterSpacing: 0.5)),
              Text('${brand.name} Vehicle Valuation Platform', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            const Text('GENERATED ON', style: TextStyle(fontSize: 9.5, color: Colors.grey, letterSpacing: 0.5)),
            Text(formatDdMmYyyyHhMm(_s(report, 'createdAt')), style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
          ]),
        ]),
      );
}
