// qc_checklist.dart
// The QC verification checklist: one engine that derives every card's verdict
// from the case data, and the cards themselves.
//
// A port of prontofirebase's src/app/shared/qc-checklist.ts (buildQcChecklist,
// applySavedChecklist, permitApplicability), src/app/shared/evidence.ts
// (splitEvidence) and the card list in quality-control-update.component.html.
// Every verdict comes with a note saying what was compared to reach it, in the
// portal's words, so a reviewer on the app reads exactly what one on the portal
// reads. Change the two together.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'date_format.dart';
import 'inspection_field_registry.dart';
import 'inspection_score.dart';

// ─── Card definitions (quality-control-update.component.html) ──────────────

enum QcPillTone { ok, warn, flag, na }

class QcPill {
  final String value;
  final String label;
  final QcPillTone tone;
  const QcPill(this.value, this.label, this.tone);
}

class QcCard {
  final String key;
  final String title;
  final String hint;
  final List<QcPill> pills;
  const QcCard(this.key, this.title, this.pills, {this.hint = ''});
}

class QcCardGroup {
  final String title;
  final List<QcCard> cards;
  const QcCardGroup(this.title, this.cards);
}

class QcSectionDef {
  /// The remarks key: doc / acc / val / rec.
  final String id;
  final String title;
  final List<QcCardGroup> groups;
  final String remarksLabel;
  final String remarksHint;
  const QcSectionDef(this.id, this.title, this.groups, this.remarksLabel, this.remarksHint);
}

const _okFlag = [QcPill('ok', '✓ OK', QcPillTone.ok), QcPill('flag', '✗ Flag', QcPillTone.flag)];
const _okFlagNa = [
  QcPill('ok', '✓ OK', QcPillTone.ok),
  QcPill('flag', '✗ Flag', QcPillTone.flag),
  QcPill('na', '— N/A', QcPillTone.na),
];
const _passFail = [QcPill('pass', '✓ Pass', QcPillTone.ok), QcPill('fail', '✗ Fail', QcPillTone.flag)];
const _passFailNa = [
  QcPill('pass', '✓ Pass', QcPillTone.ok),
  QcPill('fail', '✗ Fail', QcPillTone.flag),
  QcPill('na', '— N/A', QcPillTone.na),
];

const List<QcSectionDef> qcChecklistSections = [
  QcSectionDef('doc', 'Document Verification', [
    QcCardGroup('DOCUMENT STATUS', [
      QcCard('docRC', 'Registration Certificate (RC)', _okFlag),
      QcCard('docIns', 'Insurance Policy', _okFlag),
      QcCard('docPermit', 'Permit', _okFlagNa),
      QcCard('docFitness', 'Fitness Certificate', _okFlag),
      QcCard('docTax', 'Road Tax', _okFlag),
      QcCard('docHypo', 'Hypothecation', [QcPill('no', '✓ No', QcPillTone.ok), QcPill('yes', '● Yes', QcPillTone.warn)]),
    ]),
  ], 'Document Verification Remarks', 'Note any document issues or expiry concerns…'),
  QcSectionDef('acc', 'Data Accuracy', [
    QcCardGroup('VEHICLE IDENTITY VERIFICATION', [
      QcCard('accReg', 'Registration Number matches photos & RC', _passFail,
          hint: 'Verify plate visible in front & rear photos'),
      QcCard('accChassis', 'Chassis Number matches photos, RC & stencil', _passFail,
          hint: 'Compare across all 3 sources'),
      QcCard('accChassisPhotos', 'Every chassis photo shows the same number', _passFail,
          hint: 'Catches one photo taken of a different vehicle'),
      QcCard('accOdo', 'Odometer in photo matches reported KM', _passFail,
          hint: 'Compare dashboard photo vs report KM'),
      QcCard('accVIN', 'VIN plate matches RC & inspection report', _passFail,
          hint: 'Check VIN plate photo matches report exactly'),
      QcCard('accMfgReg', 'Manufacture year vs registration gap is logical', _passFail,
          hint: 'Registration typically within 12 months of manufacture'),
      QcCard('accVahan', 'VAHAN data matches physical inspection', _passFail,
          hint: 'Make, model, colour, engine CC, body type'),
    ]),
    QcCardGroup('TECHNICAL SPECIFICATIONS', [
      QcCard('accTransmission', 'Transmission type consistent with RC variant', _passFailNa,
          hint: 'VAHAN returns no gearbox field; compared against the variant name where it states one'),
    ]),
    QcCardGroup('PHOTO QUALITY & COMPLETENESS', [
      QcCard('accPhotoLoc', 'All photos taken at the same location', _passFail,
          hint: 'Background, GPS tags and timestamp consistent'),
      QcCard('accDaylight', 'Vehicle photos taken in clear daylight', _passFail,
          hint: 'No dark, blurry or indoors photos'),
      QcCard('accPlate', 'Number plate clearly visible in front & rear', _passFail,
          hint: 'Plate must be legible — not covered, dirty or angled'),
      QcCard('accGPS', 'GPS timestamp matches declared inspection date', _passFail),
      QcCard('recExterior', 'Exterior Condition', [
        QcPill('good', '✨ Good', QcPillTone.ok),
        QcPill('minor', '🔧 Minor Damage', QcPillTone.warn),
        QcPill('major', '💥 Major Damage', QcPillTone.flag),
      ], hint: 'Judged from the body panels in the photos'),
      QcCard('recEngine', 'Engine / Mechanical Condition', [
        QcPill('good', '⚙️ Good', QcPillTone.ok),
        QcPill('average', '⚠️ Average', QcPillTone.warn),
        QcPill('poor', '❌ Poor', QcPillTone.flag),
      ], hint: 'Judged from the engine bay photo'),
      QcCard('recTyre', 'Tyre Condition', [
        QcPill('good', '🟢 Good', QcPillTone.ok),
        QcPill('average', '🟡 Average', QcPillTone.warn),
        QcPill('replacement', '🔴 Needs Replacement', QcPillTone.flag),
      ], hint: 'Worst tyre visible across the wheel photos'),
      QcCard('recDamage', 'Damage Detected', [
        QcPill('none', '✅ None', QcPillTone.ok),
        QcPill('minor', '⚠️ Minor', QcPillTone.warn),
        QcPill('major', '💥 Major', QcPillTone.flag),
      ]),
      QcCard('recMissingParts', 'Missing Parts', [
        QcPill('none', '✅ None', QcPillTone.ok),
        QcPill('present', '❌ Parts Missing', QcPillTone.flag),
      ]),
    ]),
  ], 'Data Accuracy Remarks', 'Note any discrepancies found during data verification…'),
  QcSectionDef('val', 'Valuation Quality', [
    QcCardGroup('VALUATION ACCURACY', [
      QcCard('valMinPhotos', 'Minimum required photos uploaded', _passFail,
          hint: 'Front, Rear, Left, Right, Odometer, Engine, Chassis, Stencil'),
      QcCard('valDedupe', 'Blacklist check — not stolen or blacklisted', _passFail),
      QcCard('valAgeOdo', 'Age & odometer consistent with condition rating', _passFail),
      QcCard('valScore', 'Inspection checklist supports overall vehicle score', _passFail),
    ]),
  ], 'Valuation Quality Remarks', 'Note any concerns about valuation quality or market range discrepancies…'),
  QcSectionDef('rec', 'QC Recommendation', [
    QcCardGroup('', [
      QcCard('recCondition', '1. Overall Vehicle Condition', [
        QcPill('good', '🟢 Good', QcPillTone.ok),
        QcPill('average', '🟡 Average', QcPillTone.warn),
        QcPill('poor', '🔴 Poor', QcPillTone.flag),
      ]),
      QcCard('docChassis', '2. Chassis Punch *', [
        QcPill('original', '✓ Original', QcPillTone.ok),
        QcPill('repunched', '~ Re-Punched', QcPillTone.warn),
        QcPill('tampered', '✗ Tampered', QcPillTone.flag),
      ]),
      QcCard('recFinal', '3. Final QC Recommendation', [
        QcPill('recommended', '✅ Recommended', QcPillTone.ok),
        QcPill('conditional', '⚠️ With Conditions', QcPillTone.warn),
        QcPill('not-recommended', '❌ Not Recommended', QcPillTone.flag),
      ]),
    ]),
  ], 'QC Summary Remarks', 'Summarise the overall QC findings for the Approver…'),
];

/// The pill a verdict reads as, for any checklist key — its label and tone.
QcPill? qcPillFor(String key, String? value) {
  if (value == null) return null;
  for (final section in qcChecklistSections) {
    for (final group in section.groups) {
      for (final card in group.cards) {
        if (card.key != key) continue;
        for (final p in card.pills) {
          if (p.value == value) return p;
        }
      }
    }
  }
  return null;
}

/// The badge colours the report uses: green for a good result, red for a bad one,
/// amber in between, grey when nothing is decided. (background, text)
(Color, Color) qcBadgeColours(QcPillTone? tone) {
  switch (tone) {
    case QcPillTone.ok:
      return (const Color(0xFFDCFCE7), const Color(0xFF15803D));
    case QcPillTone.warn:
      return (const Color(0xFFFEF3C7), const Color(0xFFA16207));
    case QcPillTone.flag:
      return (const Color(0xFFFEE2E2), const Color(0xFFB91C1C));
    case QcPillTone.na:
    case null:
      return (const Color(0xFFF1F5F9), const Color(0xFF64748B));
  }
}

/// Checklist verdict → the value stored on QualityControl.chassisPunch.
const Map<String, String> chassisPunchLabels = {
  'original': 'Original',
  'repunched': 'Re-Punched',
  'tampered': 'Tampered',
};

/// Checklist keys the photo reader answers. Everything else is derived on the
/// phone and never waits on a read. Keep in step with QcVisionAuditService.
const Set<String> aiAnsweredKeys = {
  'accChassis', 'accChassisPhotos', 'accDaylight', 'accGPS', 'accOdo', 'accPhotoLoc', 'accPlate',
  'accReg', 'accVIN', 'docChassis', 'recEngine', 'recExterior', 'recTyre',
};

// ─── Evidence (evidence.ts) ────────────────────────────────────────────────

class Evidence {
  /// The cause, for the face of the card.
  final String lead;

  /// The complete sentence, or null when the lead already is it.
  final String? full;
  const Evidence(this.lead, this.full);
}

const int _maxLead = 90;

/// Splits a note into the cause and the rest: the finding comes first and the
/// advice after an em dash or a full stop, so the card shows the finding and
/// the ⓘ opens the rest.
Evidence splitEvidence(String? text) {
  final full = (text ?? '').trim();
  if (full.isEmpty) return const Evidence('', null);
  final candidates = [full.indexOf(' — '), full.indexOf('. ')].where((i) => i > 0).toList();
  final breakAt = candidates.isEmpty ? -1 : candidates.reduce((a, b) => a < b ? a : b);
  if (breakAt > 0 && breakAt <= _maxLead) return Evidence(full.substring(0, breakAt).trim(), full);
  if (full.length <= _maxLead) return Evidence(full, null);
  final cut = full.lastIndexOf(' ', _maxLead);
  var lead = full.substring(0, cut > 40 ? cut : _maxLead).trim();
  lead = lead.replaceAll(RegExp(r'[,;:.—-]$'), '');
  return Evidence('$lead…', full);
}

// ─── Engine (qc-checklist.ts) ──────────────────────────────────────────────

class QcAiFindings {
  final List<String> damage;
  final List<String> missingParts;

  /// True once the photos have actually been read for this case.
  final bool photosRead;
  const QcAiFindings({this.damage = const [], this.missingParts = const [], this.photosRead = false});
}

class QcChecklistResult {
  /// key → verdict, or null where the reviewer has to decide.
  final Map<String, String?> cl;

  /// key → what the system compared to reach the verdict. Always populated.
  final Map<String, String> why;
  QcChecklistResult(this.cl, this.why);
}

/// Case-insensitive lookup: the API's casing varies by object.
dynamic _get(Object? m, String key) {
  if (m is! Map) return null;
  if (m.containsKey(key)) return m[key];
  final lower = key.toLowerCase();
  for (final e in m.entries) {
    if (e.key.toString().toLowerCase() == lower) return e.value;
  }
  return null;
}

String _str(Object? m, String key) {
  final v = _get(m, key);
  return (v == null || v.toString() == 'null') ? '' : v.toString();
}

num? _num(Object? m, String key) {
  final v = _get(m, key);
  if (v is num) return v;
  return num.tryParse('${v ?? ''}');
}

/// true / false / null, reading "true" and "false" strings too.
bool? _bool(Object? m, String key) {
  final v = _get(m, key);
  if (v is bool) return v;
  final s = '${v ?? ''}'.toLowerCase();
  return s == 'true' ? true : s == 'false' ? false : null;
}

DateTime? _date(String? s) {
  if (s == null || s.trim().isEmpty) return null;
  return DateTime.tryParse(s.trim())?.toLocal();
}

final NumberFormat _inrFormat = NumberFormat.decimalPattern('en_IN');
String _inr(num n) => _inrFormat.format(n);

/// Prints a number the way JavaScript does: 1197, not 1197.0.
String _numText(num n) => n == n.roundToDouble() ? n.round().toString() : n.toString();

/// Overall Rating is the derived score ("8.5"), banded the way the report bands it.
/// Older cases hold a word, which passes through.
String _bandRating(String? raw) {
  final s = (raw ?? '').trim();
  if (s.isEmpty) return '';
  final n = double.tryParse(s);
  if (n == null) return s.toUpperCase();
  return n >= 7 ? 'GOOD' : n >= 4 ? 'AVERAGE' : 'POOR';
}

/// Transmission named in an RC variant string, or null. Word boundaries matter:
/// "AT" sits inside plenty of model names.
String? _transmissionFromVariant(String? variant) {
  final v = (variant ?? '').toUpperCase();
  if (v.isEmpty) return null;
  bool has(String token) => RegExp('(^|[^A-Z0-9])$token([^A-Z0-9]|\$)').hasMatch(v);
  if (has('AMT')) return 'AMT';
  if (has('CVT')) return 'CVT';
  if (has('DCT') || has('DSG')) return 'DCT';
  if (has('MANUAL') || has('IMT') || has('MT')) return 'MANUAL';
  if (has('AUTOMATIC') || has('AUTO') || has('AT')) return 'AUTOMATIC';
  return null;
}

/// MANUAL or AUTOMATIC (AMT, CVT and DCT are automatics), or null when unrecognised.
String? _transmissionFamily(String type) {
  final t = type.toUpperCase().trim();
  if (t == 'MANUAL' || t == 'MT' || t == 'IMT') return 'MANUAL';
  if (const ['AUTOMATIC', 'AUTO', 'AT', 'AMT', 'CVT', 'DCT', 'DSG'].contains(t)) return 'AUTOMATIC';
  return null;
}

enum PermitApplicability { required, notApplicable, unknown }

const _nonTransportCodes = {'LMV', 'LMVNT', 'MCWG', 'MCWOG', 'MCWGNT', 'MC', 'MCY', '2WN', '2WNT', '3WN'};
const _transportCodes = {
  'HGV', 'HPV', 'MGV', 'MPV', 'LGV', 'LPV', 'HTV', 'MTV', 'LTV',
  '3WT', '4WT', 'TRAILER', 'ERICKSHAW', 'ERICKSHAWWITHCART',
};

/// Whether this vehicle needs a permit at all: the RC's own permit fields first,
/// then VAHAN's category and class, and only then the case's vehicle segment.
PermitApplicability permitApplicability(Map? vd, String? vehicleSegment, String? valuationType) {
  if (_str(vd, 'permitNo').isNotEmpty || _str(vd, 'permitType').isNotEmpty || _str(vd, 'permitValidUpTo').isNotEmpty) {
    return PermitApplicability.required;
  }
  final code = _str(vd, 'categoryCode').toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
  final klass = _str(vd, 'classOfVehicle').toUpperCase();
  if (code.isNotEmpty && _nonTransportCodes.contains(code)) return PermitApplicability.notApplicable;
  if (code.isNotEmpty && _transportCodes.contains(code)) return PermitApplicability.required;
  if (RegExp(r'\bNON[- ]?TRANSPORT\b').hasMatch(klass) || klass.contains('(NT)') || RegExp(r'\bNT\b').hasMatch(klass)) {
    return PermitApplicability.notApplicable;
  }
  if (RegExp(r'MOTOR CAR|MOTOR CYCLE|M-?CYCLE|SCOOTER|MOPED').hasMatch(klass)) return PermitApplicability.notApplicable;
  if (RegExp(r'TRANSPORT|GOODS|CARRIER|BUS|TAXI|MAXI|TRACTOR|TRAILER').hasMatch(klass)) return PermitApplicability.required;
  final vk = normalizeVehicleType(vehicleSegment) ?? normalizeVehicleType(valuationType);
  if (vk == VehicleTypeKey.fw || vk == VehicleTypeKey.tw) return PermitApplicability.notApplicable;
  if (vk != null) return PermitApplicability.required;
  return PermitApplicability.unknown;
}

QcChecklistResult buildQcChecklist({
  required Map<String, dynamic> report,
  String? overallRating,
  String? chassisPunch,
  required List<String> photoKeys,
  String? vehicleSegment,
  String? valuationType,
  QcAiFindings? aiFindings,
}) {
  final cl = <String, String?>{};
  final why = <String, String>{};

  void mark(String key, String? verdict, String reason, [String? detail]) {
    if (verdict != null) cl[key] = verdict;
    why[key] = detail != null ? '$reason — $detail' : reason;
  }

  final vd = _get(report, 'vehicleDetails') as Map? ?? const {};
  final ins = _get(report, 'inspectionDetails') as Map? ?? const {};
  final photos = _get(report, 'photoUrls') as Map? ?? const {};
  bool has(List<String> keys) => keys.any((k) => _str(photos, k).isNotEmpty);

  final punch = (chassisPunch ?? '').toUpperCase().replaceAll(RegExp(r'[-\s]'), '');
  final rating = _bandRating(overallRating);
  final ratingShown = (overallRating ?? '').trim();
  final engineCond = _str(ins, 'engineCondition').toUpperCase();
  final tyreCond = (_str(ins, 'tyreCondition').isNotEmpty ? _str(ins, 'tyreCondition') : _str(ins, 'overallTyreCondition')).toUpperCase();
  final exteriorCond = _str(ins, 'exteriorCondition').toUpperCase();
  final bodyCondition = _str(ins, 'bodyCondition').toUpperCase();
  final photoCount = photoKeys.length;

  final inspectedOn = _date(_str(ins, 'dateOfInspection'));
  final asOf = inspectedOn ?? DateTime.now();

  String? condMap(String v) => v == 'GOOD' ? 'good' : v == 'AVERAGE' ? 'average' : v == 'POOR' ? 'poor' : null;

  void checkExpiry(String key, String label, String validTo) {
    if (validTo.isEmpty) {
      mark(key, 'flag', '$label expiry date not captured in Vehicle Details — verify from the uploaded document before approving.');
      return;
    }
    final d = _date(validTo);
    if (d == null) {
      mark(key, 'flag', '$label expiry "$validTo" could not be read — verify manually before approving.');
      return;
    }
    final shown = formatDdMmYyyy(validTo);
    if (!d.isBefore(asOf)) {
      mark(key, 'ok', '$label valid to $shown — still valid on the inspection date.');
    } else {
      mark(key, 'flag', '$label expired on $shown — before the inspection date.');
    }
  }

  // ── Document Verification ───────────────────────────────────────────────
  final regNo = _str(vd, 'registrationNumber');
  final regDate = _str(vd, 'dateOfRegistration');
  if (regNo.isNotEmpty && _bool(vd, 'rcStatus') != false) {
    mark('docRC', 'ok', 'RC $regNo returned by VAHAN${regDate.isNotEmpty ? ', registered ${formatDdMmYyyy(regDate)}' : ''}.');
  } else if (regNo.isNotEmpty) {
    mark('docRC', 'flag', 'VAHAN reports RC status inactive for $regNo.');
  } else {
    mark('docRC', 'flag', 'No registration number captured in Vehicle Details.');
  }

  final insurer = _str(vd, 'insurer');
  checkExpiry('docIns', 'Insurance${insurer.isNotEmpty ? ' ($insurer)' : ''}', _str(vd, 'insuranceValidUpTo'));
  final permitNeeded = permitApplicability(vd, vehicleSegment, valuationType);
  if (permitNeeded == PermitApplicability.notApplicable) {
    final basis = [_str(vd, 'categoryCode'), _str(vd, 'classOfVehicle'), vehicleSegment ?? '', valuationType ?? '']
        .firstWhere((s) => s.isNotEmpty, orElse: () => '');
    mark('docPermit', 'na', 'No permit required${basis.isNotEmpty ? ' for a $basis' : ''} — non-transport vehicles do not carry one.');
  } else {
    final permitNo = _str(vd, 'permitNo');
    checkExpiry('docPermit', 'Permit${permitNo.isNotEmpty ? ' $permitNo' : ''}', _str(vd, 'permitValidUpTo'));
  }
  final fitnessNo = _str(vd, 'fitnessNo');
  checkExpiry('docFitness', 'Fitness${fitnessNo.isNotEmpty ? ' $fitnessNo' : ''}', _str(vd, 'fitnessValidTo'));
  checkExpiry('docTax', 'Road tax', _str(vd, 'taxUpto'));

  if (_bool(vd, 'hypothecation') == true) {
    final lender = _str(vd, 'lender');
    mark('docHypo', 'yes', lender.isNotEmpty
        ? 'RC shows hypothecation to $lender.'
        : 'RC shows hypothecation, though VAHAN returned no lender name.');
  } else {
    mark('docHypo', 'no', 'RC shows no hypothecation on record.');
  }

  if (punch == 'ORIGINAL') {
    mark('docChassis', 'original', 'Chassis punch recorded as Original on the QC form.');
  } else if (punch == 'REPUNCHED') {
    mark('docChassis', 'repunched', 'Chassis punch recorded as Re-punched on the QC form.');
  } else if (punch == 'TAMPERED') {
    mark('docChassis', 'tampered', 'Chassis punch recorded as Tampered on the QC form.');
  } else {
    mark('docChassis', null, 'Chassis punch not recorded on the QC form.');
  }

  // ── Data Accuracy: vehicle identity ──────────────────────────────────────
  if (regNo.isNotEmpty) {
    mark('accReg', 'fail', has(['FrontViewGrille', 'RearViewTailgate'])
        ? 'Not compared yet: the plate has not been read from the photos. RC says $regNo, and the front/rear photos are on file — check the plate against them by eye.'
        : 'Cannot be compared: no front or rear photo was uploaded to read the plate from. RC says $regNo.');
  } else {
    mark('accReg', 'fail', 'Cannot be compared: no registration number was captured in Vehicle Details.');
  }

  final chassisNo = _str(vd, 'chassisNumber');
  if (chassisNo.isNotEmpty) {
    mark('accChassis', 'fail', has(['ChassisStencilTrace', 'ChassisImprint', 'ChassisVerification'])
        ? 'Not compared yet: the chassis number has not been read from the photos. RC says $chassisNo, and a stencil/imprint photo is on file — compare it against them by eye.'
        : 'Cannot be compared: no stencil or imprint photo was uploaded to read the chassis number from. RC says $chassisNo.');
  } else {
    mark('accChassis', 'fail', 'Cannot be compared: no chassis number was captured in Vehicle Details.');
  }

  final odo = _num(ins, 'odometer') ?? 0;
  if (odo > 0) {
    mark('accOdo', 'fail', has(['Odometer', 'InstrumentCluster'])
        ? 'Not compared yet: the dial has not been read from the photos. AVO recorded ${_inr(odo)} km and an odometer photo is on file — read the dial off it by eye.'
        : 'Cannot be compared: no odometer photo was uploaded to read the dial from. AVO recorded ${_inr(odo)} km.');
  } else {
    mark('accOdo', 'fail', 'Cannot be compared: AVO recorded no odometer reading.');
  }

  final vinAbsent = _bool(ins, 'vinPlate') == false;
  if (has(['VinPlate'])) {
    mark('accVIN', 'fail', vinAbsent
        ? 'AVO marked the VIN plate as not present on the vehicle, even though a VIN plate photo was uploaded.'
        : 'Not compared yet: the VIN plate has not been read from the photos. The photo is on file — compare it to the RC by eye.');
  } else {
    mark('accVIN', 'fail', vinAbsent
        ? 'AVO marked the VIN plate as not present on the vehicle.'
        : 'Cannot be compared: no VIN plate photo was uploaded to read the VIN from.');
  }

  final mfgYear = (_num(vd, 'yearOfMfg') ?? 0).toInt();
  final reg = _date(regDate);
  if (mfgYear != 0 && reg != null) {
    final mfgMonth = (_num(vd, 'monthOfMfg') ?? 1).toInt();
    final months = (reg.year - mfgYear) * 12 + (reg.month - 1) - (mfgMonth - 1);
    final ok = months >= 0 && months <= 18;
    mark('accMfgReg', ok ? 'pass' : 'fail',
        'Manufactured $mfgYear, registered ${formatDdMmYyyy(regDate)} — a gap of $months month(s), '
        '${ok ? 'within the normal 18-month window.' : 'outside the normal 18-month window.'}');
  } else {
    final what = mfgYear == 0 && regDate.isEmpty
        ? 'neither the manufacture year nor the registration date was captured'
        : mfgYear == 0
            ? 'no manufacture year was captured'
            : 'no registration date was captured';
    mark('accMfgReg', 'fail', 'Cannot be compared: $what in Vehicle Details, so the gap cannot be calculated.');
  }

  final make = _str(vd, 'make');
  final model = _str(vd, 'model');
  if (make.isNotEmpty && model.isNotEmpty) {
    final rcBody = _str(vd, 'bodyType').trim().toUpperCase();
    final insBody = _str(ins, 'bodyType').trim().toUpperCase();
    final bodyOk = rcBody.isEmpty || insBody.isEmpty || rcBody == insBody;
    final colour = _str(vd, 'colour');
    final cc = _num(vd, 'engineCC');
    mark('accVahan', bodyOk ? 'pass' : 'fail',
        'VAHAN: $make $model'
        '${colour.isNotEmpty ? ', $colour' : ''}'
        '${cc != null && cc != 0 ? ', ${_numText(cc)}cc' : ''}'
        '${rcBody.isNotEmpty ? ', body $rcBody' : ''}'
        '${insBody.isNotEmpty ? (bodyOk ? ' — matches the body type recorded by AVO.' : ' — AVO recorded body type $insBody instead.') : ' — AVO did not record a body type to compare.'}');
  } else {
    mark('accVahan', 'fail', 'Cannot be compared: VAHAN returned no make/model, so there is nothing to check the inspection entry against.');
  }

  // ── Data Accuracy: technical specifications ─────────────────────────────
  final recordedTx = _str(ins, 'transmissionType').toUpperCase().trim();
  final rcVariant = _str(vd, 'makerVariant').isNotEmpty ? _str(vd, 'makerVariant') : model;
  final rcTx = _transmissionFromVariant(rcVariant);
  final recordedFamily = _transmissionFamily(recordedTx);
  final rcFamily = rcTx != null ? _transmissionFamily(rcTx) : null;

  if (recordedTx.isEmpty) {
    mark('accTransmission', 'fail', rcVariant.isNotEmpty
        ? 'AVO did not record a transmission type. RC lists $rcVariant — confirm from the variant and the interior photos.'
        : 'Cannot be compared: AVO did not record a transmission type, and the RC returned no variant to infer one from.');
  } else if (rcFamily == null) {
    mark('accTransmission', 'na',
        'AVO recorded $recordedTx at inspection. '
        '${rcVariant.isNotEmpty ? 'RC lists $rcVariant, which does not state a gearbox' : 'The RC variant was not captured'}'
        ', and VAHAN does not return a transmission field — so there is nothing to compare against.');
  } else if (recordedFamily == null) {
    mark('accTransmission', 'fail',
        'AVO recorded "$recordedTx", which is not a recognised gearbox type. RC variant $rcVariant indicates $rcTx — confirm from the interior photos.');
  } else if (recordedFamily == rcFamily) {
    mark('accTransmission', 'pass', 'AVO recorded $recordedTx and the RC variant $rcVariant indicates $rcTx — consistent.');
  } else {
    mark('accTransmission', 'fail',
        'AVO recorded $recordedTx but the RC variant $rcVariant indicates $rcTx — check the interior photos before approving.');
  }

  // ── Data Accuracy: photo quality & completeness ─────────────────────────
  final metadata = _get(report, 'photoMetadata') as Map? ?? const {};
  final metaEntries = metadata.entries.where((e) => _str(photos, e.key.toString()).isNotEmpty).toList();
  final places = <String>{
    for (final e in metaEntries)
      if (_str(e.value, 'locationText').trim().isNotEmpty) _str(e.value, 'locationText').trim(),
  }.toList();
  final declaredPlace = _str(ins, 'inspectionLocation');

  if (places.isEmpty) {
    mark('accPhotoLoc', 'fail',
        'Not checked yet: the capture location is stamped into the image itself, not into '
        'the photo metadata, and the $photoCount uploaded photo(s) have not been read'
        '${declaredPlace.isNotEmpty ? ' (declared: "$declaredPlace")' : ''}'
        ' — open the photos and read the stamp yourself.');
  } else if (places.length == 1) {
    mark('accPhotoLoc', 'pass', 'All ${metaEntries.length} stamped photo(s) captured at "${places.first}".');
  } else {
    mark('accPhotoLoc', 'fail', 'Photos captured at ${places.length} different locations: ${places.map((p) => '"$p"').join(', ')}.');
  }

  mark('accDaylight', 'fail', 'Not checked: lighting cannot be judged from the form data. Open the photos and confirm the vehicle was shot in daylight.');

  mark('accPlate', 'fail', has(['FrontViewGrille', 'RearViewTailgate'])
      ? 'Not checked: legibility cannot be judged from the form data. Front and rear photos are on file — confirm the plate is readable in both.'
      : 'Cannot be checked: the front or rear photo is missing, so the plate is not visible.');

  bool sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
  final shotDates = [
    for (final e in metaEntries)
      if (_date(_str(e.value, 'capturedDate')) != null) _date(_str(e.value, 'capturedDate'))!,
  ];
  final declaredDate = _str(ins, 'dateOfInspection');

  if (declaredDate.isEmpty) {
    mark('accGPS', 'fail', 'Cannot be compared: AVO declared no inspection date to check the photo timestamps against.');
  } else if (shotDates.isEmpty) {
    mark('accGPS', 'fail',
        'Not checked yet: the capture date is stamped into the photos themselves, not into '
        'the photo metadata, and they have not been read. AVO declared ${formatDdMmYyyy(declaredDate)}'
        ' — open the photos and read the stamp yourself.');
  } else {
    final declared = _date(declaredDate)!;
    final offDay = shotDates.where((d) => !sameDay(d, declared)).toList();
    if (offDay.isEmpty) {
      mark('accGPS', 'pass',
          'All ${shotDates.length} stamped photo(s) captured on ${formatDdMmYyyy(declaredDate)}, matching the declared inspection date.');
    } else {
      final shown = {for (final d in offDay) DateFormat('d/M/yyyy').format(d)}.join(', ');
      mark('accGPS', 'fail',
          '${offDay.length} of ${shotDates.length} photo(s) captured on $shown, not the declared inspection date ${formatDdMmYyyy(declaredDate)}.');
    }
  }

  // ── Valuation Quality ────────────────────────────────────────────────────
  if (photoCount >= 8) {
    mark('valMinPhotos', 'pass', '$photoCount photos uploaded — at or above the minimum of 8.');
  } else {
    mark('valMinPhotos', 'fail', '$photoCount photo(s) uploaded — below the minimum of 8.');
  }

  if (_bool(vd, 'backlistStatus') == true) {
    mark('valDedupe', 'fail', 'VAHAN reports this vehicle as blacklisted.');
  } else if (regNo.isNotEmpty) {
    mark('valDedupe', 'pass', 'VAHAN reports no blacklist flag on $regNo.');
  } else {
    // The report prints this verdict; an unrun check must stay unset so it
    // prints PENDING rather than BLACKLIST: YES.
    mark('valDedupe', null, 'No registration number available to run the blacklist check against.');
  }

  if (mfgYear != 0 && odo > 0) {
    final age = DateTime.now().year - mfgYear;
    final avgKm = age > 0 ? odo / age : odo;
    final ok = avgKm < 60000;
    mark('valAgeOdo', ok ? 'pass' : 'fail',
        '${_inr(avgKm.round())} km/year over ${age == 0 ? 1 : age} year(s)'
        '${ok ? ' — within the usual range.' : ' — above the 60,000 km/year threshold.'}');
  } else {
    final what = mfgYear == 0 && odo == 0
        ? 'neither the manufacture year nor an odometer reading was captured'
        : mfgYear == 0
            ? 'no manufacture year was captured'
            : 'AVO recorded no odometer reading';
    mark('valAgeOdo', 'fail', 'Cannot be derived: $what, so usage per year cannot be calculated.');
  }

  if (rating == 'GOOD') {
    mark('valScore', 'pass', 'Overall vehicle score $ratingShown — in the GOOD band (7 and above).');
  } else if (rating == 'POOR') {
    mark('valScore', 'fail', 'Overall vehicle score $ratingShown — in the POOR band (below 4).');
  } else if (rating.isNotEmpty) {
    mark('valScore', 'fail', 'Overall vehicle score $ratingShown — in the AVERAGE band (4 to 7); a judgement call.');
  } else {
    mark('valScore', 'fail', 'No inspection sections have been scored yet, so there is no overall score.');
  }

  // ── QC Recommendation ────────────────────────────────────────────────────
  mark('recCondition', condMap(rating), rating.isNotEmpty
      ? 'Derived from the overall vehicle score $ratingShown ($rating band).'
      : 'No overall vehicle score available yet.');

  mark('recEngine', condMap(engineCond), engineCond.isNotEmpty
      ? 'AVO recorded engine condition as $engineCond.'
      : 'AVO did not record an engine condition.');

  final extVal = exteriorCond.isNotEmpty ? exteriorCond : bodyCondition;
  final extVerdict = extVal == 'GOOD'
      ? 'good'
      : (extVal == 'AVERAGE' || extVal == 'FAIR')
          ? 'minor'
          : (extVal == 'POOR' || extVal == 'DAMAGED')
              ? 'major'
              : null;
  mark('recExterior', extVerdict, extVal.isNotEmpty
      ? 'AVO recorded exterior/body condition as $extVal.'
      : 'AVO did not record an exterior or body condition.');

  final tyreVerdict = tyreCond == 'GOOD'
      ? 'good'
      : tyreCond == 'AVERAGE'
          ? 'average'
          : (tyreCond == 'POOR' || tyreCond == 'DAMAGED')
              ? 'replacement'
              : null;
  mark('recTyre', tyreVerdict, tyreCond.isNotEmpty
      ? 'AVO recorded overall tyre condition as $tyreCond.'
      : 'AVO did not record an overall tyre condition.');

  // Damage and missing parts as the AVO recorded them, quoted beside the photo findings.
  final vk = normalizeVehicleType(vehicleSegment) ?? normalizeVehicleType(valuationType);
  final damaged = <String>[];
  final missing = <String>[];
  if (vk != null && ins.isNotEmpty) {
    for (final section in getFieldRegistry(vk)) {
      // Engine Started, Test Drive and the rest are checks, not parts.
      if (section.section == 'FUNCTIONALITY') continue;
      for (final f in section.fields) {
        final raw = _get(ins, f.key);
        if (f.type == FieldType.number) {
          if (f.scoring == FieldScoring.zeroIsGood && (num.tryParse('${raw ?? ''}') ?? 0) > 0) missing.add('${f.label} ($raw)');
          continue;
        }
        if (f.scoring == FieldScoring.noIsGood) {
          final answer = '${raw ?? ''}'.trim().toLowerCase();
          if (answer == 'no') continue;
          if (answer == 'yes') {
            damaged.add(f.label);
            continue;
          }
        }
        final v = mapVerdict(raw?.toString());
        if (v == 'DAMAGED' || v == 'POOR' || v == 'BAD') {
          damaged.add(f.label);
        } else if (v == 'MISSING' || v == 'NO') {
          missing.add(f.label);
        }
      }
    }
  }
  String list(List<String> xs, [int cap = 6]) =>
      xs.take(cap).join(', ') + (xs.length > cap ? ', +${xs.length - cap} more' : '');

  final avoDamageNote = vk == null || ins.isEmpty
      ? 'no inspection entries could be read for this vehicle type'
      : damaged.isEmpty
          ? 'AVO marked nothing damaged'
          : 'AVO marked ${damaged.length}: ${list(damaged)}';
  final avoMissingNote = vk == null || ins.isEmpty
      ? 'no inspection entries could be read for this vehicle type'
      : missing.isEmpty
          ? 'AVO marked nothing missing'
          : 'AVO marked ${missing.length}: ${list(missing)}';

  if (aiFindings == null || !aiFindings.photosRead) {
    mark('recDamage', null, 'Not judged yet: the photos have not been read.',
        'Damage is taken from the images, not from the inspection form. Until the photo read completes there is nothing to judge from — $avoDamageNote.');
    mark('recMissingParts', null, 'Not judged yet: the photos have not been read.',
        'Missing parts are taken from the images, not from the inspection form. Until the photo read completes there is nothing to judge from — $avoMissingNote.');
  } else {
    final seenDamage = aiFindings.damage;
    final seenMissing = aiFindings.missingParts;
    final damageVerdict = seenDamage.isEmpty ? 'none' : seenDamage.length <= 2 ? 'minor' : 'major';
    mark('recDamage', damageVerdict,
        seenDamage.isEmpty
            ? 'No visible damage in the photos'
            : '${seenDamage.length} visible defect${seenDamage.length == 1 ? '' : 's'} in the photos: ${list(seenDamage)}',
        '${seenDamage.isEmpty ? 'The photos show no visible damage to the body.' : 'Photos show ${seenDamage.length} defect(s): ${list(seenDamage, 10)}.'}'
        ' For comparison, $avoDamageNote.');
    mark('recMissingParts', seenMissing.isEmpty ? 'none' : 'present',
        seenMissing.isEmpty
            ? 'No part seen missing in the photos'
            : '${seenMissing.length} part${seenMissing.length == 1 ? '' : 's'} seen missing: ${list(seenMissing)}',
        '${seenMissing.isEmpty ? 'No externally visible part was seen to be missing. Parts outside the frame cannot be judged, so this is not a completeness guarantee.' : 'Photos show these parts absent: ${list(seenMissing, 10)}.'}'
        ' For comparison, $avoMissingNote.');
  }

  if (punch == 'TAMPERED' || rating == 'POOR') {
    mark('recFinal', 'not-recommended', punch == 'TAMPERED' ? 'Chassis punch is recorded as tampered.' : 'Overall rating is POOR.');
  } else if (rating == 'GOOD' && punch == 'ORIGINAL') {
    mark('recFinal', 'recommended', 'Overall rating GOOD and chassis punch Original.');
  } else {
    mark('recFinal', 'conditional',
        'Neither a clean pass nor a clear reject on rating (${rating.isEmpty ? 'not set' : rating}) '
        'and chassis punch (${punch.isEmpty ? 'not set' : punch}).');
  }

  return QcChecklistResult(cl, why);
}

/// Puts the reviewer's saved checklist back over the automatic verdicts. Where a
/// person overruled the machine the note says so. [reviewerKeys] null means the
/// case predates tracking who decided what, so any difference counts as theirs.
void applySavedChecklist(QcChecklistResult result, Map? saved, Iterable<String>? reviewerKeys) {
  if (saved == null) return;
  final byReviewer = reviewerKeys?.toSet();
  saved.forEach((k, rawV) {
    if (rawV == null || rawV.toString() == 'null') return;
    final key = k.toString();
    var v = rawV.toString();
    // docHypo was same/different before it became yes/no.
    if (key == 'docHypo') v = v == 'same' ? 'no' : v == 'different' ? 'yes' : v;
    final changed = result.cl[key] != v;
    final isReviewers = byReviewer == null ? changed : byReviewer.contains(key);
    if (changed && isReviewers) {
      result.why[key] = 'Saved by the reviewer'
          '${result.cl[key] != null ? ', overriding the automatic verdict — ${result.why[key] ?? ''}' : '.'}';
    }
    result.cl[key] = v;
  });
}

// ─── The cards ──────────────────────────────────────────────────────────────

/// Renders the checklist sections. The parent owns all state; this widget only
/// reads it and reports taps.
class QcChecklistView extends StatefulWidget {
  final Map<String, String?> cl;
  final Map<String, String> why;
  final Map<String, String> remarks;
  final bool enabled;

  /// Keys whose current verdict came from the photo reader.
  final Set<String> aiVerified;

  /// key → 'resolved' / 'unresolved' for keys the reader examined.
  final Map<String, String> aiStatus;

  /// True while the reader is still working on this key.
  final bool Function(String key) aiPending;

  final void Function(String key, String value) onSet;

  /// Extra content shown on a card, such as the odometer comparison.
  final Widget? Function(String key)? cardExtra;

  /// Shown above a section, keyed by that section's id.
  final Widget? Function(String sectionId)? before;

  const QcChecklistView({
    super.key,
    required this.cl,
    required this.why,
    required this.remarks,
    required this.enabled,
    required this.aiVerified,
    required this.aiStatus,
    required this.aiPending,
    required this.onSet,
    this.cardExtra,
    this.before,
  });

  @override
  State<QcChecklistView> createState() => _QcChecklistViewState();
}

class _QcChecklistViewState extends State<QcChecklistView> {
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
        return Colors.green.shade700;
      case QcPillTone.warn:
        return Colors.orange.shade800;
      case QcPillTone.flag:
        return Colors.red.shade700;
      case QcPillTone.na:
        return Colors.blueGrey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    for (final section in qcChecklistSections) {
      final before = widget.before?.call(section.id);
      if (before != null) children.add(before);
      children.add(_buildSection(section));
    }
    return Column(children: children);
  }

  Widget _buildSection(QcSectionDef section) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: ExpansionTile(
        initiallyExpanded: true,
        title: Text(section.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        children: [
          for (final group in section.groups) ...[
            if (group.title.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(group.title,
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: Colors.grey.shade600)),
                ),
              ),
            for (final card in group.cards) _buildCard(card),
          ],
          const SizedBox(height: 8),
          TextField(
            controller: _remarkControllers[section.id],
            enabled: widget.enabled,
            maxLines: section.id == 'rec' ? 4 : 3,
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              labelText: section.remarksLabel,
              hintText: section.remarksHint,
              hintStyle: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  /// One check as the report shows it: its name and its result, a single badge
  /// in the result's colour. Tapping it opens the reason and, while editing,
  /// the choices.
  Widget _buildCard(QcCard card) {
    final current = widget.cl[card.key];
    QcPill? pill;
    for (final p in card.pills) {
      if (p.value == current) pill = p;
    }
    final (bg, fg) = qcBadgeColours(pill?.tone);
    final pending = widget.aiPending(card.key);
    final evidence = splitEvidence(widget.why[card.key]);
    final extra = widget.cardExtra?.call(card.key);

    return InkWell(
      onTap: () => _openCard(card),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9)))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(card.title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1F2937))),
                if (!pending && evidence.lead.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Row(children: [
                      if (widget.aiVerified.contains(card.key)) _tag('AI', Colors.indigo),
                      if (widget.aiStatus[card.key] == 'unresolved') _tag('READ, INCONCLUSIVE', Colors.orange.shade800),
                      Expanded(
                        child: Text(evidence.lead,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600)),
                      ),
                    ]),
                  ),
              ]),
            ),
            const SizedBox(width: 8),
            if (pending)
              Row(mainAxisSize: MainAxisSize.min, children: [
                const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 1.5)),
                const SizedBox(width: 6),
                Text('Reading…', style: TextStyle(fontSize: 11.5, color: Colors.grey.shade700)),
              ])
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
                child: Text(pill?.label ?? '—', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: fg)),
              ),
            if (widget.enabled) Icon(Icons.chevron_right, size: 18, color: Colors.grey.shade400),
          ]),
          if (extra != null) extra,
        ]),
      ),
    );
  }

  /// The check in full: what was compared and, while editing, the choices.
  Future<void> _openCard(QcCard card) async {
    final evidence = splitEvidence(widget.why[card.key]);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(card.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            if (card.hint.isNotEmpty) Text(card.hint, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            const SizedBox(height: 12),
            if ((evidence.full ?? evidence.lead).isNotEmpty)
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (widget.aiVerified.contains(card.key)) _tag('AI', Colors.indigo),
                Icon(Icons.info_outline, size: 16, color: Colors.blueGrey.shade400),
                const SizedBox(width: 6),
                Expanded(child: Text(evidence.full ?? evidence.lead, style: const TextStyle(fontSize: 13))),
              ]),
            const SizedBox(height: 16),
            if (widget.enabled)
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final p in card.pills)
                  _pillButton(card.key, p, selected: widget.cl[card.key] == p.value, onDone: () => Navigator.pop(ctx)),
              ])
            else
              Text('Tap Edit on the page to change this.', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          ]),
        ),
      ),
    );
  }

  Widget _tag(String text, Color color) => Container(
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
        child: Text(text, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
      );

  Widget _pillButton(String key, QcPill pill, {required bool selected, VoidCallback? onDone}) {
    final color = _toneColor(pill.tone);
    return InkWell(
      onTap: widget.enabled
          ? () {
              widget.onSet(key, pill.value);
              onDone?.call();
            }
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
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: selected ? Colors.white : color)),
      ),
    );
  }
}
