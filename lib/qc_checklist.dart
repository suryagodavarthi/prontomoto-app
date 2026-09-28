// qc_checklist.dart
// QC verification checklist — ports the web portal's quality-control-update
// checklist (qcChecklist + qcChecklistRemarks on the QualityControl document).
// Keep sections/keys in sync with quality-control-update.component.html.

import 'package:flutter/material.dart';

enum QcPillTone { ok, warn, flag }

class QcPill {
  final String value;
  final String label;
  final QcPillTone tone;
  const QcPill(this.value, this.label, this.tone);
}

class QcChecklistItem {
  final String key;
  final String label;
  final List<QcPill> pills;
  const QcChecklistItem(this.key, this.label, this.pills);
}

class QcChecklistSectionDef {
  final String id; // remarks key: doc / acc / val / rec
  final String title;
  final String remarksHint;
  final List<QcChecklistItem> items;
  const QcChecklistSectionDef(this.id, this.title, this.remarksHint, this.items);
}

const _okFlag = [QcPill('ok', '✓ OK', QcPillTone.ok), QcPill('flag', '✗ Flag', QcPillTone.flag)];
const _passFail = [QcPill('pass', '✓ Pass', QcPillTone.ok), QcPill('fail', '✗ Fail', QcPillTone.flag)];

const List<QcChecklistSectionDef> qcChecklistSections = [
  QcChecklistSectionDef('doc', 'Document Verification', 'Note any document issues or expiry concerns…', [
    QcChecklistItem('docRC', 'Registration Certificate (RC)', _okFlag),
    QcChecklistItem('docIns', 'Insurance Policy', _okFlag),
    QcChecklistItem('docPermit', 'Permit', _okFlag),
    QcChecklistItem('docFitness', 'Fitness Certificate', _okFlag),
    QcChecklistItem('docTax', 'Road Tax', _okFlag),
    QcChecklistItem('docHypo', 'Hypothecation', [
      QcPill('same', '✓ Same Bank', QcPillTone.ok),
      QcPill('different', '✗ Different', QcPillTone.flag),
    ]),
  ]),
  QcChecklistSectionDef('acc', 'Data Accuracy', 'Note any discrepancies found during data verification…', [
    QcChecklistItem('accReg', 'Registration Number matches photos & RC', _passFail),
    QcChecklistItem('accChassis', 'Chassis Number matches photos, RC & stencil', _passFail),
    QcChecklistItem('accOdo', 'Odometer in photo matches reported KM', _passFail),
    QcChecklistItem('accVIN', 'VIN plate matches RC & inspection report', _passFail),
    QcChecklistItem('accMfgReg', 'Manufacture year vs registration gap is logical', _passFail),
    QcChecklistItem('accVahan', 'VAHAN data matches physical inspection', _passFail),
    QcChecklistItem('accOwner', 'Owner & applicant identity verified from docs', _passFail),
    QcChecklistItem('accSerial', 'Ownership serial verified (1st / 2nd / 3rd owner)', _passFail),
    QcChecklistItem('accTransmission', 'Transmission type matches RC & vehicle class', _passFail),
    QcChecklistItem('accFuel', 'Fuel type matches engine specs & RC', _passFail),
    QcChecklistItem('accPhotoLoc', 'All photos taken at the same location', _passFail),
    QcChecklistItem('accDaylight', 'Vehicle photos taken in clear daylight', _passFail),
    QcChecklistItem('accPlate', 'Number plate clearly visible in front & rear', _passFail),
    QcChecklistItem('accGPS', 'GPS timestamp matches declared inspection date', _passFail),
    QcChecklistItem('accReportDate', 'Report date is valid — not in the future', _passFail),
    QcChecklistItem('accMandatory', 'All mandatory fields filled — no blanks', _passFail),
    QcChecklistItem('accRemarks', 'Inspector remarks are complete and relevant', _passFail),
  ]),
  QcChecklistSectionDef('val', 'Valuation Quality', 'Note any concerns about valuation quality or market range discrepancies…', [
    QcChecklistItem('valMinPhotos', 'Minimum required photos uploaded', _passFail),
    QcChecklistItem('valInRange', 'Valuation amount within acceptable market range', _passFail),
    QcChecklistItem('valDedupe', 'Dedupe check — not stolen or blacklisted', _passFail),
    QcChecklistItem('valAgeOdo', 'Age & odometer consistent with condition rating', _passFail),
    QcChecklistItem('valScore', 'Inspection checklist supports overall vehicle score', _passFail),
  ]),
  QcChecklistSectionDef('rec', 'QC Recommendation', 'Summarise the overall QC findings for the Approver…', [
    QcChecklistItem('recCondition', 'Overall Vehicle Condition', [
      QcPill('good', '🟢 Good', QcPillTone.ok),
      QcPill('average', '🟡 Average', QcPillTone.warn),
      QcPill('poor', '🔴 Poor', QcPillTone.flag),
    ]),
    QcChecklistItem('recExterior', 'Exterior Condition', [
      QcPill('good', '✨ Good', QcPillTone.ok),
      QcPill('minor', '🔧 Minor Damage', QcPillTone.warn),
      QcPill('major', '💥 Major Damage', QcPillTone.flag),
    ]),
    QcChecklistItem('recEngine', 'Engine / Mechanical Condition', [
      QcPill('good', '⚙️ Good', QcPillTone.ok),
      QcPill('average', '⚠️ Average', QcPillTone.warn),
      QcPill('poor', '❌ Poor', QcPillTone.flag),
    ]),
    QcChecklistItem('recTyre', 'Tyre Condition', [
      QcPill('good', '🟢 Good', QcPillTone.ok),
      QcPill('average', '🟡 Average', QcPillTone.warn),
      QcPill('replacement', '🔴 Needs Replacement', QcPillTone.flag),
    ]),
    QcChecklistItem('recDamage', 'Damage Detected', [
      QcPill('none', '✅ None', QcPillTone.ok),
      QcPill('minor', '⚠️ Minor', QcPillTone.warn),
      QcPill('major', '💥 Major', QcPillTone.flag),
    ]),
    QcChecklistItem('recMissingParts', 'Missing Parts', [
      QcPill('none', '✅ None', QcPillTone.ok),
      QcPill('present', '❌ Parts Missing', QcPillTone.flag),
    ]),
    QcChecklistItem('docChassis', 'Chassis Punch', [
      QcPill('original', '✓ Original', QcPillTone.ok),
      QcPill('repunched', '~ Re-Punched', QcPillTone.warn),
      QcPill('tampered', '✗ Tampered', QcPillTone.flag),
    ]),
    QcChecklistItem('recFinal', 'Final QC Recommendation', [
      QcPill('recommended', '✅ Recommended', QcPillTone.ok),
      QcPill('conditional', '⚠️ With Conditions', QcPillTone.warn),
      QcPill('not-recommended', '❌ Not Recommended', QcPillTone.flag),
    ]),
  ]),
];

/// Auto-prefills checklist values from report data — port of the portal's
/// prefillChecklist(). Saved values (loaded afterwards) override these.
void prefillQcChecklist(
  Map<String, String?> cl, {
  required Map<String, dynamic> report,
  required String overallRating,
  required String chassisPunchRaw,
  required num valuationAmount,
}) {
  Map<String, dynamic> section(String key) {
    final v = report[key] ?? report[key[0].toUpperCase() + key.substring(1)];
    return v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};
  }

  String rd(Map<String, dynamic> m, String key) {
    final v = m[key] ?? m[key[0].toUpperCase() + key.substring(1)];
    return (v == null || v.toString() == 'null') ? '' : v.toString();
  }

  final vd = section('vehicleDetails');
  final ins = section('inspectionDetails');
  final ve = section('valuationResponse');
  final stakeholder = section('stakeholder');
  final photos = report['photoUrls'];
  final photoCount = photos is Map ? photos.values.where((v) => v != null && v.toString().startsWith('http')).length : 0;

  final chassisPunch = chassisPunchRaw.toUpperCase().replaceAll(RegExp(r'[-\s]'), '');
  final rating = overallRating.toUpperCase();
  final engineCond = rd(ins, 'engineCondition').toUpperCase();
  final tyreCond = rd(ins, 'overallTyreCondition').toUpperCase();
  final exteriorCond = (rd(ins, 'exteriorCondition').isNotEmpty
          ? rd(ins, 'exteriorCondition')
          : rd(ins, 'bodyCondition'))
      .toUpperCase();
  final low = num.tryParse(rd(ve, 'lowRange')) ?? 0;
  final high = num.tryParse(rd(ve, 'highRange')) ?? 0;

  String? condMap(String v) =>
      v == 'GOOD' ? 'good' : v == 'AVERAGE' ? 'average' : v == 'POOR' ? 'poor' : null;

  // Document Verification
  if (rd(vd, 'registrationNumber').isNotEmpty) cl['docRC'] = 'ok';
  if (chassisPunch == 'ORIGINAL') {
    cl['docChassis'] = 'original';
  } else if (chassisPunch == 'REPUNCHED') {
    cl['docChassis'] = 'repunched';
  } else if (chassisPunch == 'TAMPERED') {
    cl['docChassis'] = 'tampered';
  }

  // Data Accuracy
  if (rd(vd, 'registrationNumber').isNotEmpty) cl['accReg'] = 'pass';
  if (rd(vd, 'chassisNumber').isNotEmpty || rd(ins, 'vinPlate').isNotEmpty) cl['accChassis'] = 'pass';
  if ((num.tryParse(rd(ins, 'odometer')) ?? 0) > 0) cl['accOdo'] = 'pass';
  if (rd(vd, 'fuel').isNotEmpty) cl['accFuel'] = 'pass';
  if (rd(vd, 'make').isNotEmpty && rd(vd, 'model').isNotEmpty) cl['accVahan'] = 'pass';
  final applicant = stakeholder['applicant'] ?? stakeholder['Applicant'];
  if (applicant is Map && (applicant['name'] ?? applicant['Name'] ?? '').toString().isNotEmpty) {
    cl['accOwner'] = 'pass';
  }
  if (rd(vd, 'ownerName').isNotEmpty) cl['accSerial'] = 'pass';
  if (rd(ins, 'vehicleInspectedBy').isNotEmpty) cl['accMandatory'] = 'pass';
  if (rd(ins, 'remarks').isNotEmpty || rd(ins, 'vehicleInspectedBy').isNotEmpty) cl['accRemarks'] = 'pass';

  // Valuation Quality
  if (photoCount >= 8) {
    cl['valMinPhotos'] = 'pass';
  } else if (photoCount > 0) {
    cl['valMinPhotos'] = 'fail';
  }
  if (low > 0 && high > 0) {
    cl['valInRange'] = (valuationAmount >= low && valuationAmount <= high) ? 'pass' : 'fail';
  }
  final yearOfMfg = int.tryParse(rd(vd, 'yearOfMfg')) ?? 0;
  final odometer = num.tryParse(rd(ins, 'odometer')) ?? 0;
  if (yearOfMfg > 0 && odometer > 0) {
    final age = DateTime.now().year - yearOfMfg;
    final avgKm = age > 0 ? odometer / age : 0;
    cl['valAgeOdo'] = avgKm < 60000 ? 'pass' : 'fail';
  }
  if (rating == 'GOOD') {
    cl['valScore'] = 'pass';
  } else if (rating == 'POOR') {
    cl['valScore'] = 'fail';
  }

  // QC Recommendation
  cl['recCondition'] = condMap(rating);
  cl['recEngine'] = condMap(engineCond);
  if (exteriorCond == 'GOOD') {
    cl['recExterior'] = 'good';
  } else if (exteriorCond == 'AVERAGE' || exteriorCond == 'FAIR') {
    cl['recExterior'] = 'minor';
  } else if (exteriorCond == 'POOR') {
    cl['recExterior'] = 'major';
  }
  if (tyreCond == 'GOOD') {
    cl['recTyre'] = 'good';
  } else if (tyreCond == 'AVERAGE') {
    cl['recTyre'] = 'average';
  } else if (tyreCond == 'POOR') {
    cl['recTyre'] = 'replacement';
  }
  if (chassisPunch == 'TAMPERED' || rating == 'POOR') {
    cl['recFinal'] = 'not-recommended';
  } else if (rating == 'GOOD' && chassisPunch == 'ORIGINAL') {
    cl['recFinal'] = 'recommended';
  } else {
    cl['recFinal'] = 'conditional';
  }
}

/// Renders the four checklist sections. Mutates [cl] / [remarks] in place —
/// the parent owns the maps and includes them in the QC save body.
class QcChecklistWidget extends StatefulWidget {
  final Map<String, String?> cl;
  final Map<String, String> remarks;
  final bool enabled;
  const QcChecklistWidget({super.key, required this.cl, required this.remarks, this.enabled = true});

  @override
  State<QcChecklistWidget> createState() => _QcChecklistWidgetState();
}

class _QcChecklistWidgetState extends State<QcChecklistWidget> {
  final Map<String, TextEditingController> _remarkControllers = {};

  @override
  void initState() {
    super.initState();
    for (final section in qcChecklistSections) {
      final c = TextEditingController(text: widget.remarks[section.id] ?? '');
      c.addListener(() => widget.remarks[section.id] = c.text);
      _remarkControllers[section.id] = c;
    }
  }

  @override
  void dispose() {
    for (final c in _remarkControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Color _toneColor(QcPillTone tone) {
    switch (tone) {
      case QcPillTone.ok:
        return Colors.green;
      case QcPillTone.warn:
        return Colors.orange;
      case QcPillTone.flag:
        return Colors.red;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final section in qcChecklistSections) _buildSection(section),
      ],
    );
  }

  Widget _buildSection(QcChecklistSectionDef section) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: ExpansionTile(
        title: Text(section.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        children: [
          for (final item in section.items) _buildItem(item),
          const SizedBox(height: 8),
          TextField(
            controller: _remarkControllers[section.id],
            enabled: widget.enabled,
            maxLines: 3,
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              labelText: "${section.title} Remarks",
              hintText: section.remarksHint,
              hintStyle: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItem(QcChecklistItem item) {
    final current = widget.cl[item.key];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(item.label, style: const TextStyle(fontSize: 13)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final pill in item.pills)
                _pillButton(item.key, pill, selected: current == pill.value),
            ],
          ),
        ],
      ),
    );
  }

  Widget _pillButton(String key, QcPill pill, {required bool selected}) {
    final color = _toneColor(pill.tone);
    return InkWell(
      onTap: widget.enabled
          ? () => setState(() {
                // Toggle like the portal's setCl(): tapping the active pill clears it.
                widget.cl[key] = widget.cl[key] == pill.value ? null : pill.value;
              })
          : null,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? color : color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? color : color.withOpacity(0.4)),
        ),
        child: Text(pill.label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : color,
            )),
      ),
    );
  }
}
