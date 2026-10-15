// inspection_score.dart
// One scoring engine shared by the AVO page and the QC page. A line-for-line port
// of prontofirebase's src/app/shared/inspection-score.ts, which is itself a port of
// CalculateSystemScoreOrNull / MapVerdict in ProntoPDFGeneration's PdfReportService:
// the numbers the app shows must be the numbers the report prints, so change all
// three together.
//
// NO counts as 1/10, so answering NO pulls a section down. Fields and sections
// marked `scored: false` in the registry (OTHER SYSTEMS, ABS, Number of Tyres) are
// facts about the vehicle rather than judgements of its condition and never count.
// N/A is excluded from the average rather than scored zero.

import 'inspection_field_registry.dart';

/// Normalises a stored answer to GOOD / AVERAGE / POOR / DAMAGED / MISSING / YES /
/// NO / NA. Anything else comes back upper-cased and is read as a possible number.
String mapVerdict(String? input) {
  if (input == null || input.trim().isEmpty) return 'NA';
  final lower = input.toLowerCase().trim();
  if (const ['yes', 'true'].contains(lower)) return 'YES';
  if (const ['1', 'good', 'ok'].contains(lower)) return 'GOOD';
  if (const ['0', 'bad', 'poor'].contains(lower)) return 'POOR';
  if (const ['no', 'false'].contains(lower)) return 'NO';
  if (const ['average', 'fair'].contains(lower)) return 'AVERAGE';
  if (const ['damaged', 'damage'].contains(lower)) return 'DAMAGED';
  if (lower.startsWith('missing') || const ['not present', 'absent'].contains(lower)) return 'MISSING';
  if (const ['n/a', 'na', 'n.a.', 'not applicable'].contains(lower)) return 'NA';
  return input.toUpperCase();
}

/// Points one verdict contributes; null means "excluded from the average".
double? _verdictPoints(String verdict) {
  switch (verdict) {
    case 'GOOD':
    case 'YES':
      return 8.5;
    case 'AVERAGE':
      return 5.5;
    case 'POOR':
    case 'BAD':
      return 2.5;
    case 'DAMAGED':
      return 2.0;
    case 'NO':
      return 1.0;
    case 'MISSING':
      return 0.5;
    case 'NA':
      return null;
    default:
      final m = RegExp(r'\d+(\.\d+)?').firstMatch(verdict);
      if (m == null) return null;
      final n = double.tryParse(m.group(0)!);
      return n == null ? null : n.clamp(0, 10).toDouble();
  }
}

/// Points one field's answer contributes, by the field's scoring rule.
double? answerPoints(InspectionField field, Object? value) {
  final raw = value == null ? '' : value.toString().trim();
  switch (field.scoring) {
    case FieldScoring.noIsGood:
      // Only the YES / NO pair swaps; GOOD, POOR, N/A and the rest score as usual.
      final lower = raw.toLowerCase();
      if (lower == 'no' || lower == 'false') return 8.5;
      if (lower == 'yes' || lower == 'true') return 1.0;
      break;
    case FieldScoring.zeroIsGood:
      if (raw.isEmpty) return null;
      final n = num.tryParse(raw);
      if (n == null || !n.isFinite || n < 0) return null;
      return n == 0 ? 8.5 : 1.0;
    case FieldScoring.condition:
      break;
  }
  return _verdictPoints(mapVerdict(raw));
}

double _round1(double n) => (n * 10).round() / 10;

double? _meanOrNull(List<double?> points) {
  final scored = points.whereType<double>().toList();
  if (scored.isEmpty) return null;
  return _round1(scored.reduce((a, b) => a + b) / scored.length);
}

/// Mean of the section scores that could be computed. Unscored sections drop out.
double? overallScoreOrNull(List<double?> sectionScores) => _meanOrNull(sectionScores);

enum ScoreBand { good, average, poor }

/// Thresholds mirror GetScoreDisplayFromDouble: ≥7 green, ≥4 amber, else red.
ScoreBand? scoreBand(double? score) {
  if (score == null) return null;
  return score >= 7 ? ScoreBand.good : score >= 4 ? ScoreBand.average : ScoreBand.poor;
}

class SectionScore {
  final String section;
  final double? score;

  /// How many fields contributed — the rest were left blank or marked N/A.
  final int rated;
  final int total;

  const SectionScore(this.section, this.score, this.rated, this.total);
}

/// Score for one section; null for a section marked `scored: false`.
double? sectionScoreFor(InspectionSection section, Object? Function(String key) readValue) {
  if (!section.scored) return null;
  return _meanOrNull([
    for (final f in section.fields.where((f) => f.scored)) answerPoints(f, readValue(f.key)),
  ]);
}

/// Scores every section of a vehicle type's registry. The AVO page reads values
/// off the live form, the QC page off the saved inspection, so both get identical
/// numbers from identical inputs.
List<SectionScore> scoreSections(VehicleTypeKey? vehicleType, Object? Function(String key) readValue) {
  if (vehicleType == null) return [];
  return [
    for (final section in getFieldRegistry(vehicleType))
      () {
        final scorable = section.scored ? section.fields.where((f) => f.scored).toList() : <InspectionField>[];
        final points = [for (final f in scorable) answerPoints(f, readValue(f.key))];
        return SectionScore(
          section.section,
          scorable.isEmpty ? null : _meanOrNull(points),
          points.whereType<double>().length,
          scorable.length,
        );
      }(),
  ];
}

class InspectionScores {
  final List<SectionScore> sections;
  final double? overall;
  const InspectionScores(this.sections, this.overall);
}

/// Scores a saved inspection whose keys are the camelCase registry keys.
InspectionScores scoreInspection(String? vehicleSegment, Map<String, dynamic>? inspection,
    {String? fallbackType}) {
  final vk = normalizeVehicleType(vehicleSegment) ?? normalizeVehicleType(fallbackType);
  if (vk == null || inspection == null) return const InspectionScores([], null);
  final sections = scoreSections(vk, (key) => _readKey(inspection, key));
  return InspectionScores(sections, overallScoreOrNull([for (final s in sections) s.score]));
}

/// The API returns camelCase keys, but a key may arrive in another case.
Object? _readKey(Map<String, dynamic> m, String key) {
  if (m.containsKey(key)) return m[key];
  final lower = key.toLowerCase();
  for (final e in m.entries) {
    if (e.key.toLowerCase() == lower) return e.value;
  }
  return null;
}
