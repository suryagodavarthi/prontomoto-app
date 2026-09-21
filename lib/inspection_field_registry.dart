// inspection_field_registry.dart
// Single source of truth for inspection form fields across all vehicle types.
// Mirrors inspection-field-registry.ts — keep in sync. The registry below matches the
// 2026-09 checklist (VEHGA_REPORT_ALL_SEGMENTS_UPDATED) section for section, in the
// portal's order, and was generated from the portal's copy.
//
// condition → a dropdown of conditionOptions. number → a typed whole number (tyre counts).

enum FieldType { condition, yesNo, text, date, number }

enum VehicleTypeKey { cv, fw, tw, thrw, ce, bus, fe }

class InspectionField {
  final String key;
  final String label;
  final FieldType type;
  final String? defaultValue;

  const InspectionField({
    required this.key,
    required this.label,
    required this.type,
    this.defaultValue,
  });
}

class InspectionSection {
  final String section;
  final List<InspectionField> fields;

  const InspectionSection({required this.section, required this.fields});
}

// Keep in sync with CONDITION_OPTIONS in prontofirebase's
// inspection-field-registry.ts — the portal and the PDF read these same strings.
const List<String> conditionOptions = [
  'GOOD',
  'AVERAGE',
  'POOR',
  'DAMAGED',
  'MISSING / NOT PRESENT',
  'N/A',
  'YES',
  'NO',
];
const List<String> yesNoOptions = ['YES', 'NO'];

// ─── Categories ────────────────────────────────────────────────────────────
// The four systems the report's cover rates. A VIEW over the sections below, not
// a replacement: the inspection form still collects all of them, and the saved
// shape is unchanged.
//
// This replaces verdictSections, which listed four per-vehicle-type verdict
// labels (ENGINE / CABIN / LOAD BODY / OTHER SYSTEMS). Those named the banded
// verdict boxes on an older cover; the cover has been redesigned twice since and
// nothing referenced the map any more.
//
// Derived from the section NAME, exactly as categoryOf() does in the portal's
// inspection-field-registry.ts and CategoryOf() in ProntoPDFGeneration's
// PdfReportService.Cover.cs. Three copies of one rule — change them together.

enum InspectionCategoryKey { mechanical, structural, electrical, tyres }

class InspectionCategory {
  final InspectionCategoryKey key;

  /// As the checklist page heads it.
  final String title;

  /// As the cover tile labels it.
  final String tileTitle;

  const InspectionCategory({
    required this.key,
    required this.title,
    required this.tileTitle,
  });
}

/// In the order the report prints them.
const List<InspectionCategory> inspectionCategories = [
  InspectionCategory(
      key: InspectionCategoryKey.mechanical,
      title: 'MECHANICAL',
      tileTitle: 'MECHANICAL SYSTEMS'),
  InspectionCategory(
      key: InspectionCategoryKey.structural,
      title: 'STRUCTURAL',
      tileTitle: 'STRUCTURAL SYSTEMS'),
  InspectionCategory(
      key: InspectionCategoryKey.electrical,
      title: 'ELECTRICAL',
      tileTitle: 'ELECTRICAL'),
  InspectionCategory(
      key: InspectionCategoryKey.tyres,
      title: 'TYRES',
      tileTitle: 'TYRES'),
];

/// Which category a section belongs to, or null when it is listed but never rated.
///
/// FUNCTIONALITY and OTHER SYSTEMS return null: the report captions the tiles as
/// ratings, and a section it does not score has no rating to show. Anything
/// unrecognised falls to structural, which is where the body, cabin and
/// attachment sections differ by vehicle type.
InspectionCategoryKey? categoryOf(String sectionName) {
  final n = sectionName.trim().toUpperCase();
  if (n == 'FUNCTIONALITY' || n == 'OTHER SYSTEMS') return null;
  if (n == 'ELECTRICAL SYSTEM') return InspectionCategoryKey.electrical;
  if (n.startsWith('TIRE') || n.startsWith('TYRE')) return InspectionCategoryKey.tyres;
  if (const {
    'ENGINE CONDITION',
    'TRANSMISSION SYSTEM',
    'BRAKES',
    'STEERING SYSTEM',
    'SUSPENSION SYSTEM',
    'HYDRAULIC SYSTEM',
  }.contains(n)) {
    return InspectionCategoryKey.mechanical;
  }
  return InspectionCategoryKey.structural;
}

VehicleTypeKey? normalizeVehicleType(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  final s = raw.trim().toLowerCase();
  if (s.contains('commercial') || s == 'cv') return VehicleTypeKey.cv;
  if (s.contains('four') || s == '4w') return VehicleTypeKey.fw;
  if (s.contains('two') || s == '2w') return VehicleTypeKey.tw;
  if (s.contains('three') || s == '3w') return VehicleTypeKey.thrw;
  if (s.contains('construction') || s == 'ce') return VehicleTypeKey.ce;
  if (s.contains('bus')) return VehicleTypeKey.bus;
  if (s.contains('tractor') || s.contains('farm') || s == 'fe') return VehicleTypeKey.fe;
  return null;
}

// ─── Registry ──────────────────────────────────────────────────────────────

const Map<VehicleTypeKey, List<InspectionSection>> fieldRegistry = {

  // ═══════════════════════════════════════════════════════════════════════════
  // CV — Commercial Vehicle
  // ═══════════════════════════════════════════════════════════════════════════
  VehicleTypeKey.cv: [
    InspectionSection(section: 'ENGINE CONDITION', fields: [
      InspectionField(key: 'engineCondition', label: 'Engine Condition', type: FieldType.condition, defaultValue: 'GOOD'),
      InspectionField(key: 'fluidLeaks', label: 'Fluid Leaks', type: FieldType.condition, defaultValue: 'NO'),
      InspectionField(key: 'radiator', label: 'Radiator', type: FieldType.condition, defaultValue: 'GOOD'),
      InspectionField(key: 'allHosePipes', label: 'All Hose Pipes', type: FieldType.condition, defaultValue: 'GOOD'),
      InspectionField(key: 'fuelSystem', label: 'Fuel System', type: FieldType.condition, defaultValue: 'GOOD'),
    ]),
    InspectionSection(section: 'TRANSMISSION SYSTEM', fields: [
      InspectionField(key: 'gearBoxAssy', label: 'Gearbox Assy', type: FieldType.condition, defaultValue: 'GOOD'),
      InspectionField(key: 'clutchSystem', label: 'Clutch System', type: FieldType.condition, defaultValue: 'GOOD'),
      InspectionField(key: 'differentialAssy', label: 'Differential Assy', type: FieldType.condition, defaultValue: 'GOOD'),
    ]),
    InspectionSection(section: 'BRAKES', fields: [
      InspectionField(key: 'frontBrakes', label: 'Front Brakes', type: FieldType.condition, defaultValue: 'GOOD'),
      InspectionField(key: 'rearBrakes', label: 'Rear Brakes', type: FieldType.condition, defaultValue: 'GOOD'),
      InspectionField(key: 'parkingBrake', label: 'Parking Brake', type: FieldType.condition, defaultValue: 'GOOD'),
      InspectionField(key: 'abs', label: 'ABS', type: FieldType.condition, defaultValue: 'YES'),
    ]),
    InspectionSection(section: 'STEERING SYSTEM', fields: [
      InspectionField(key: 'steeringWheel', label: 'Steering Wheel', type: FieldType.condition, defaultValue: 'GOOD'),
      InspectionField(key: 'steeringColumn', label: 'Steering Column', type: FieldType.condition, defaultValue: 'GOOD'),
      InspectionField(key: 'steeringBox', label: 'Steering Box', type: FieldType.condition, defaultValue: 'GOOD'),
    ]),
    InspectionSection(section: 'SUSPENSION SYSTEM', fields: [
      InspectionField(key: 'frontSuspension', label: 'Front Suspension', type: FieldType.condition, defaultValue: 'GOOD'),
      InspectionField(key: 'rearSuspension', label: 'Rear Suspension', type: FieldType.condition, defaultValue: 'GOOD'),
      InspectionField(key: 'axles', label: 'Front & Rear Axles', type: FieldType.condition, defaultValue: 'GOOD'),
    ]),
    InspectionSection(section: 'CABIN ASSEMBLY', fields: [
      InspectionField(key: 'cabin', label: 'Cabin', type: FieldType.condition, defaultValue: 'GOOD'),
      InspectionField(key: 'dashboard', label: 'Dashboard', type: FieldType.condition, defaultValue: 'GOOD'),
      InspectionField(key: 'doors', label: 'Doors', type: FieldType.condition, defaultValue: 'GOOD'),
      InspectionField(key: 'allGlasses', label: 'All Glasses', type: FieldType.condition, defaultValue: 'GOOD'),
      InspectionField(key: 'seats', label: 'Seats', type: FieldType.condition, defaultValue: 'GOOD'),
    ]),
    InspectionSection(section: 'LOAD BODY', fields: [
      InspectionField(key: 'bodyCondition', label: 'Body Condition', type: FieldType.condition, defaultValue: 'GOOD'),
      InspectionField(key: 'rightSideGate', label: 'Right Side Gate', type: FieldType.condition, defaultValue: 'GOOD'),
      InspectionField(key: 'leftSideGate', label: 'Left Side Gate', type: FieldType.condition, defaultValue: 'GOOD'),
      InspectionField(key: 'tailGate', label: 'Tail Gate', type: FieldType.condition, defaultValue: 'GOOD'),
      InspectionField(key: 'loadFloor', label: 'Load Floor', type: FieldType.condition, defaultValue: 'GOOD'),
      InspectionField(key: 'chassisCondition', label: 'Chassis / Vehicle Frame', type: FieldType.condition, defaultValue: 'GOOD'),
      InspectionField(key: 'paintWork', label: 'Paint Work', type: FieldType.condition, defaultValue: 'GOOD'),
    ]),
    InspectionSection(section: 'ELECTRICAL SYSTEM', fields: [
      InspectionField(key: 'headLights', label: 'Head Lights', type: FieldType.condition, defaultValue: 'GOOD'),
      InspectionField(key: 'tailLightsIndicators', label: 'Tail Lights / Indicators', type: FieldType.condition, defaultValue: 'GOOD'),
      InspectionField(key: 'batteryCondition', label: 'Battery', type: FieldType.condition, defaultValue: 'GOOD'),
      InspectionField(key: 'wiringAssy', label: 'Wiring Assy', type: FieldType.condition, defaultValue: 'GOOD'),
      InspectionField(key: 'clusterUnit', label: 'Cluster Unit', type: FieldType.condition, defaultValue: 'GOOD'),
    ]),
    InspectionSection(section: 'TIRES', fields: [
      InspectionField(key: 'tyreCondition', label: 'Tyre Condition', type: FieldType.condition, defaultValue: 'AVERAGE'),
      InspectionField(key: 'numberOfTyres', label: 'Number of Tyres', type: FieldType.number),
      InspectionField(key: 'missingTyres', label: 'Missing Tyres', type: FieldType.number, defaultValue: '0'),
    ]),
    InspectionSection(section: 'FUNCTIONALITY', fields: [
      InspectionField(key: 'engineStarted', label: 'Engine Started', type: FieldType.condition, defaultValue: 'YES'),
      InspectionField(key: 'testDrive', label: 'Test Drive', type: FieldType.condition, defaultValue: 'YES'),
      InspectionField(key: 'vehicleMoved', label: 'Vehicle Moved', type: FieldType.condition, defaultValue: 'YES'),
      InspectionField(key: 'warningLights', label: 'Warning Lights', type: FieldType.condition, defaultValue: 'YES'),
    ]),
    InspectionSection(section: 'OTHER SYSTEMS', fields: [
      InspectionField(key: 'audio', label: 'Audio', type: FieldType.condition, defaultValue: 'NO'),
      InspectionField(key: 'upholstery', label: 'Upholstery', type: FieldType.condition, defaultValue: 'GOOD'),
      InspectionField(key: 'hydraulicLift', label: 'Hydraulic Lift', type: FieldType.condition, defaultValue: 'YES'),
      InspectionField(key: 'frontCrashGuard', label: 'Front Crash Guard', type: FieldType.condition, defaultValue: 'NO'),
      InspectionField(key: 'rearCrashGuard', label: 'Rear Crash Guard', type: FieldType.condition, defaultValue: 'NO'),
      InspectionField(key: 'sideUnderRunProtection', label: 'Side Under Run Protection', type: FieldType.condition, defaultValue: 'NO'),
    ]),
  ],

  // ═══════════════════════════════════════════════════════════════════════════
  // 4W — Four Wheeler
  // ═══════════════════════════════════════════════════════════════════════════
  VehicleTypeKey.fw: [
    InspectionSection(section: 'ENGINE CONDITION', fields: [
      InspectionField(key: 'engineCondition', label: 'Engine Condition', type: FieldType.condition, defaultValue: 'GOOD'),
      InspectionField(key: 'fluidLeaks', label: 'Fluid Leaks', type: FieldType.condition, defaultValue: 'NO'),
      InspectionField(key: 'radiator', label: 'Radiator', type: FieldType.condition, defaultValue: 'GOOD'),
      InspectionField(key: 'allHosePipes', label: 'All Hose Pipes', type: FieldType.condition, defaultValue: 'GOOD'),
      InspectionField(key: 'fuelSystem', label: 'Fuel System', type: FieldType.condition, defaultValue: 'GOOD'),
    ]),
    InspectionSection(section: 'TRANSMISSION SYSTEM', fields: [
      InspectionField(key: 'gearBoxAssy', label: 'Gearbox Assy', type: FieldType.condition, defaultValue: 'GOOD'),
      InspectionField(key: 'clutchSystem', label: 'Clutch System', type: FieldType.condition, defaultValue: 'GOOD'),
      InspectionField(key: 'driveShafts', label: 'Drive Shafts', type: FieldType.condition, defaultValue: 'GOOD'),
    ]),
    InspectionSection(section: 'BRAKES', fields: [
      InspectionField(key: 'frontBrakes', label: 'Front Brakes', type: FieldType.condition, defaultValue: 'GOOD'),
      InspectionField(key: 'rearBrakes', label: 'Rear Brakes', type: FieldType.condition, defaultValue: 'GOOD'),
      InspectionField(key: 'parkingBrake', label: 'Parking Brake', type: FieldType.condition, defaultValue: 'GOOD'),
      InspectionField(key: 'abs', label: 'ABS', type: FieldType.condition, defaultValue: 'NO'),
    ]),
    InspectionSection(section: 'STEERING SYSTEM', fields: [
      InspectionField(key: 'steeringWheel', label: 'Steering Wheel', type: FieldType.condition, defaultValue: 'GOOD'),
      InspectionField(key: 'steeringColumn', label: 'Steering Column', type: FieldType.condition, defaultValue: 'GOOD'),
      InspectionField(key: 'steeringBox', label: 'Steering Box', type: FieldType.condition, defaultValue: 'GOOD'),
    ]),
    InspectionSection(section: 'SUSPENSION SYSTEM', fields: [
      InspectionField(key: 'frontSuspension', label: 'Front Suspension', type: FieldType.condition, defaultValue: 'GOOD'),
      InspectionField(key: 'rearSuspension', label: 'Rear Suspension', type: FieldType.condition, defaultValue: 'GOOD'),
      InspectionField(key: 'axles', label: 'Front & Rear Axles', type: FieldType.condition, defaultValue: 'GOOD'),
    ]),
    InspectionSection(section: 'EXTERIOR', fields: [
      InspectionField(key: 'bonnet', label: 'Bonnet Assy', type: FieldType.condition, defaultValue: 'GOOD'),
      InspectionField(key: 'bumpers', label: 'Bumpers', type: FieldType.condition, defaultValue: 'GOOD'),
      InspectionField(key: 'doors', label: 'Doors', type: FieldType.condition, defaultValue: 'GOOD'),
      InspectionField(key: 'allGlasses', label: 'All Glasses', type: FieldType.condition, defaultValue: 'GOOD'),
      InspectionField(key: 'sideFenders', label: 'Side Fenders', type: FieldType.condition, defaultValue: 'GOOD'),
      // Not on the 4W sheet; kept on request (2026-09-17), as in the portal.
      InspectionField(key: 'paintWork', label: 'Paint Work', type: FieldType.condition, defaultValue: 'GOOD'),
    ]),
    InspectionSection(section: 'INTERIOR', fields: [
      InspectionField(key: 'dashboard', label: 'Dash Board', type: FieldType.condition, defaultValue: 'GOOD'),
      InspectionField(key: 'seats', label: 'Seats & Mats', type: FieldType.condition, defaultValue: 'GOOD'),
      InspectionField(key: 'interiorTrims', label: 'Interior Trims', type: FieldType.condition, defaultValue: 'GOOD'),
    ]),
    InspectionSection(section: 'ELECTRICAL SYSTEM', fields: [
      InspectionField(key: 'headLights', label: 'Head Lights', type: FieldType.condition, defaultValue: 'GOOD'),
      InspectionField(key: 'tailLightsIndicators', label: 'Tail Lights / Indicators', type: FieldType.condition, defaultValue: 'GOOD'),
      InspectionField(key: 'batteryCondition', label: 'Battery', type: FieldType.condition, defaultValue: 'GOOD'),
      InspectionField(key: 'wiringAssy', label: 'Wiring Assy', type: FieldType.condition, defaultValue: 'GOOD'),
      InspectionField(key: 'clusterUnit', label: 'Cluster Unit', type: FieldType.condition, defaultValue: 'GOOD'),
    ]),
    InspectionSection(section: 'TIRES', fields: [
      InspectionField(key: 'tyreCondition', label: 'Tyre Condition', type: FieldType.condition, defaultValue: 'AVERAGE'),
      InspectionField(key: 'numberOfTyres', label: 'Number of Tyres', type: FieldType.number),
      InspectionField(key: 'missingTyres', label: 'Missing Tyres', type: FieldType.number, defaultValue: '0'),
    ]),
    InspectionSection(section: 'FUNCTIONALITY', fields: [
      InspectionField(key: 'engineStarted', label: 'Engine Started', type: FieldType.condition, defaultValue: 'YES'),
      InspectionField(key: 'testDrive', label: 'Test Drive', type: FieldType.condition, defaultValue: 'YES'),
      InspectionField(key: 'vehicleMoved', label: 'Vehicle Moved', type: FieldType.condition, defaultValue: 'YES'),
      InspectionField(key: 'warningLights', label: 'Warning Lights', type: FieldType.condition, defaultValue: 'YES'),
    ]),
    InspectionSection(section: 'OTHER SYSTEMS', fields: [
      InspectionField(key: 'audio', label: 'Audio', type: FieldType.condition, defaultValue: 'NO'),
      InspectionField(key: 'airConditioner', label: 'Air Conditioner', type: FieldType.condition, defaultValue: 'NO'),
      InspectionField(key: 'upholstery', label: 'Upholstery', type: FieldType.condition, defaultValue: 'GOOD'),
      InspectionField(key: 'sunRoof', label: 'Sun Roof', type: FieldType.condition, defaultValue: 'NO'),
      InspectionField(key: 'rearCrashGuard', label: 'Rear Crash Guard', type: FieldType.condition, defaultValue: 'NO'),
      InspectionField(key: 'frontCrashGuard', label: 'Front Crash Guard', type: FieldType.condition, defaultValue: 'NO'),
    ]),
  ],

  // ═══════════════════════════════════════════════════════════════════════════
  // 2W — Two Wheeler
  // ═══════════════════════════════════════════════════════════════════════════
  VehicleTypeKey.tw: [
    InspectionSection(section: 'ENGINE CONDITION', fields: [
      InspectionField(key: 'engineCondition', label: 'Engine Condition', type: FieldType.condition, defaultValue: 'GOOD'),
      InspectionField(key: 'fluidLeaks', label: 'Fluid Leaks', type: FieldType.condition, defaultValue: 'NO'),
      InspectionField(key: 'radiator', label: 'Radiator', type: FieldType.condition, defaultValue: 'GOOD'),
      InspectionField(key: 'allHosePipes', label: 'All Hose Pipes', type: FieldType.condition, defaultValue: 'GOOD'),
      InspectionField(key: 'fuelSystem', label: 'Fuel System', type: FieldType.condition, defaultValue: 'GOOD'),
    ]),
    InspectionSection(section: 'TRANSMISSION SYSTEM', fields: [
      InspectionField(key: 'gearBoxAssy', label: 'Gearbox Assy', type: FieldType.condition, defaultValue: 'GOOD'),
      InspectionField(key: 'clutchSystem', label: 'Clutch System', type: FieldType.condition, defaultValue: 'GOOD'),
      InspectionField(key: 'finalDrive', label: 'Final Drive / Chain', type: FieldType.condition, defaultValue: 'GOOD'),
    ]),
    InspectionSection(section: 'BRAKES', fields: [
      InspectionField(key: 'frontBrakes', label: 'Front Brake', type: FieldType.condition, defaultValue: 'GOOD'),
      InspectionField(key: 'rearBrakes', label: 'Rear Brake', type: FieldType.condition, defaultValue: 'GOOD'),
      InspectionField(key: 'brakeLeversFluid', label: 'Brake Levers / Fluid', type: FieldType.condition, defaultValue: 'GOOD'),
      InspectionField(key: 'abs', label: 'ABS', type: FieldType.condition, defaultValue: 'NO'),
    ]),
    InspectionSection(section: 'STEERING SYSTEM', fields: [
      InspectionField(key: 'handleBar', label: 'Handle Bar', type: FieldType.condition, defaultValue: 'GOOD'),
      InspectionField(key: 'steeringStem', label: 'Steering Stem', type: FieldType.condition, defaultValue: 'GOOD'),
      InspectionField(key: 'frontForkAssy', label: 'Front Fork', type: FieldType.condition, defaultValue: 'GOOD'),
    ]),
    InspectionSection(section: 'SUSPENSION SYSTEM', fields: [
      InspectionField(key: 'frontShockAbsorber', label: 'Front Shock Absorber', type: FieldType.condition, defaultValue: 'GOOD'),
      InspectionField(key: 'rearShockAbsorber', label: 'Rear Shock Absorber', type: FieldType.condition, defaultValue: 'GOOD'),
      InspectionField(key: 'alloyWheelRim', label: 'Alloy / Wheel Rim', type: FieldType.condition, defaultValue: 'GOOD'),
    ]),
    InspectionSection(section: 'EXTERIOR', fields: [
      InspectionField(key: 'fuelTankCondition', label: 'Fuel Tank Assy', type: FieldType.condition, defaultValue: 'GOOD'),
      InspectionField(key: 'frontScoop', label: 'Front Scoop', type: FieldType.condition, defaultValue: 'GOOD'),
      InspectionField(key: 'seatCondition', label: 'Seat', type: FieldType.condition, defaultValue: 'GOOD'),
      InspectionField(key: 'rvMirrors', label: 'R/V Mirrors', type: FieldType.condition, defaultValue: 'GOOD'),
      InspectionField(key: 'lockSet', label: 'Lock Set', type: FieldType.condition, defaultValue: 'GOOD'),
    ]),
    InspectionSection(section: 'BODY', fields: [
      InspectionField(key: 'frontMudGuard', label: 'Mudguard - Front', type: FieldType.condition, defaultValue: 'GOOD'),
      InspectionField(key: 'rearMudGuard', label: 'Mudguard - Rear', type: FieldType.condition, defaultValue: 'GOOD'),
      InspectionField(key: 'sideCovers', label: 'Side Covers (LH, RH)', type: FieldType.condition, defaultValue: 'GOOD'),
      InspectionField(key: 'bellyPanels', label: 'Belly / Floor Panels', type: FieldType.condition, defaultValue: 'GOOD'),
    ]),
    InspectionSection(section: 'ELECTRICAL SYSTEM', fields: [
      InspectionField(key: 'headLights', label: 'Head Lights', type: FieldType.condition, defaultValue: 'GOOD'),
      InspectionField(key: 'tailLightsIndicators', label: 'Tail Lights / Indicators', type: FieldType.condition, defaultValue: 'GOOD'),
      InspectionField(key: 'batteryCondition', label: 'Battery', type: FieldType.condition, defaultValue: 'GOOD'),
      InspectionField(key: 'wiringAssy', label: 'Wiring Assy', type: FieldType.condition, defaultValue: 'GOOD'),
      InspectionField(key: 'switches', label: 'Switches', type: FieldType.condition, defaultValue: 'GOOD'),
    ]),
    InspectionSection(section: 'TIRES', fields: [
      InspectionField(key: 'tyreCondition', label: 'Tyre Condition', type: FieldType.condition, defaultValue: 'AVERAGE'),
      InspectionField(key: 'numberOfTyres', label: 'Number of Tyres', type: FieldType.number),
      InspectionField(key: 'missingTyres', label: 'Missing Tyres', type: FieldType.number, defaultValue: '0'),
    ]),
    InspectionSection(section: 'FUNCTIONALITY', fields: [
      InspectionField(key: 'engineStarted', label: 'Engine Started', type: FieldType.condition, defaultValue: 'YES'),
      InspectionField(key: 'testDrive', label: 'Test Ride', type: FieldType.condition, defaultValue: 'YES'),
      InspectionField(key: 'vehicleMoved', label: 'Vehicle Moved', type: FieldType.condition, defaultValue: 'YES'),
      InspectionField(key: 'warningLights', label: 'Warning Lights', type: FieldType.condition, defaultValue: 'YES'),
    ]),
    InspectionSection(section: 'OTHER SYSTEMS', fields: [
      InspectionField(key: 'mainStand', label: 'Main Stand', type: FieldType.condition, defaultValue: 'NO'),
      InspectionField(key: 'sideStand', label: 'Side Stand', type: FieldType.condition, defaultValue: 'NO'),
      InspectionField(key: 'horn', label: 'Horn', type: FieldType.condition, defaultValue: 'NO'),
      InspectionField(key: 'kickPedalFootRest', label: 'Kick Pedal / Foot Rest', type: FieldType.condition, defaultValue: 'NO'),
      InspectionField(key: 'chainGuard', label: 'Chain Guard', type: FieldType.condition, defaultValue: 'NO'),
      InspectionField(key: 'selfStart', label: 'Self Start', type: FieldType.condition, defaultValue: 'NO'),
    ]),
  ],

  // ═══════════════════════════════════════════════════════════════════════════
  // 3W — Three Wheeler
  // ═══════════════════════════════════════════════════════════════════════════
  VehicleTypeKey.thrw: [
    InspectionSection(section: 'ENGINE CONDITION', fields: [
      InspectionField(key: 'engineCondition', label: 'Engine Condition', type: FieldType.condition, defaultValue: 'GOOD'),
      InspectionField(key: 'fluidLeaks', label: 'Fluid Leaks', type: FieldType.condition, defaultValue: 'NO'),
      InspectionField(key: 'radiator', label: 'Radiator', type: FieldType.condition, defaultValue: 'GOOD'),
      InspectionField(key: 'allHosePipes', label: 'All Hose Pipes', type: FieldType.condition, defaultValue: 'GOOD'),
      InspectionField(key: 'fuelSystem', label: 'Fuel System', type: FieldType.condition, defaultValue: 'GOOD'),
    ]),
    InspectionSection(section: 'TRANSMISSION SYSTEM', fields: [
      InspectionField(key: 'gearBoxAssy', label: 'Gearbox Assy', type: FieldType.condition, defaultValue: 'GOOD'),
      InspectionField(key: 'clutchSystem', label: 'Clutch System', type: FieldType.condition, defaultValue: 'GOOD'),
      InspectionField(key: 'differentialAssy', label: 'Differential Assy', type: FieldType.condition, defaultValue: 'GOOD'),
    ]),
    InspectionSection(section: 'BRAKES', fields: [
      InspectionField(key: 'frontBrakes', label: 'Front Brakes', type: FieldType.condition, defaultValue: 'GOOD'),
      InspectionField(key: 'rearBrakes', label: 'Rear Brakes', type: FieldType.condition, defaultValue: 'GOOD'),
      InspectionField(key: 'parkingBrake', label: 'Parking Brake', type: FieldType.condition, defaultValue: 'GOOD'),
      InspectionField(key: 'abs', label: 'ABS', type: FieldType.condition, defaultValue: 'NO'),
    ]),
    InspectionSection(section: 'STEERING SYSTEM', fields: [
      InspectionField(key: 'steeringHandle', label: 'Steering Handle', type: FieldType.condition, defaultValue: 'GOOD'),
      InspectionField(key: 'steeringColumn', label: 'Steering Column', type: FieldType.condition, defaultValue: 'GOOD'),
      InspectionField(key: 'steeringLinkages', label: 'Steering Linkages', type: FieldType.condition, defaultValue: 'GOOD'),
    ]),
    InspectionSection(section: 'SUSPENSION SYSTEM', fields: [
      InspectionField(key: 'frontSuspension', label: 'Front Suspension', type: FieldType.condition, defaultValue: 'GOOD'),
      InspectionField(key: 'rearSuspension', label: 'Rear Suspension', type: FieldType.condition, defaultValue: 'GOOD'),
      InspectionField(key: 'axles', label: 'Front & Rear Axles', type: FieldType.condition, defaultValue: 'GOOD'),
    ]),
    InspectionSection(section: 'CABIN ASSEMBLY', fields: [
      InspectionField(key: 'frontPanel', label: 'Front Panel', type: FieldType.condition, defaultValue: 'GOOD'),
      InspectionField(key: 'frontGlassFrame', label: 'Fr Glass Frame', type: FieldType.condition, defaultValue: 'GOOD'),
      InspectionField(key: 'dashboard', label: 'Dash Board', type: FieldType.condition, defaultValue: 'GOOD'),
      InspectionField(key: 'seats', label: 'Seats & Mats', type: FieldType.condition, defaultValue: 'GOOD'),
      InspectionField(key: 'mudguards', label: 'Mudguards', type: FieldType.condition, defaultValue: 'GOOD'),
    ]),
    InspectionSection(section: 'LOAD BODY', fields: [
      InspectionField(key: 'rightSideGate', label: 'Right Side Gate', type: FieldType.condition, defaultValue: 'GOOD'),
      InspectionField(key: 'leftSideGate', label: 'Left Side Gate', type: FieldType.condition, defaultValue: 'GOOD'),
      InspectionField(key: 'tailGate', label: 'Tail Gate', type: FieldType.condition, defaultValue: 'GOOD'),
      InspectionField(key: 'loadFloor', label: 'Load Floor', type: FieldType.condition, defaultValue: 'GOOD'),
      InspectionField(key: 'chassisCondition', label: 'Chassis / Vehicle Frame', type: FieldType.condition, defaultValue: 'GOOD'),
      InspectionField(key: 'paintWork', label: 'Paint Work', type: FieldType.condition, defaultValue: 'GOOD'),
    ]),
    InspectionSection(section: 'ELECTRICAL SYSTEM', fields: [
      InspectionField(key: 'headLights', label: 'Lights', type: FieldType.condition, defaultValue: 'GOOD'),
      InspectionField(key: 'tailLightsIndicators', label: 'Tail Lights / Indicators', type: FieldType.condition, defaultValue: 'GOOD'),
      InspectionField(key: 'batteryCondition', label: 'Battery', type: FieldType.condition, defaultValue: 'GOOD'),
      InspectionField(key: 'wiringAssy', label: 'Wiring Assy', type: FieldType.condition, defaultValue: 'GOOD'),
      InspectionField(key: 'switches', label: 'Switches', type: FieldType.condition, defaultValue: 'GOOD'),
    ]),
    InspectionSection(section: 'TIRES', fields: [
      InspectionField(key: 'tyreCondition', label: 'Tyre Condition', type: FieldType.condition, defaultValue: 'AVERAGE'),
      InspectionField(key: 'numberOfTyres', label: 'Number of Tyres', type: FieldType.number),
      InspectionField(key: 'missingTyres', label: 'Missing Tyres', type: FieldType.number, defaultValue: '0'),
    ]),
    InspectionSection(section: 'FUNCTIONALITY', fields: [
      InspectionField(key: 'engineStarted', label: 'Engine Started', type: FieldType.condition, defaultValue: 'YES'),
      InspectionField(key: 'testDrive', label: 'Test Drive', type: FieldType.condition, defaultValue: 'YES'),
      InspectionField(key: 'vehicleMoved', label: 'Vehicle Moved', type: FieldType.condition, defaultValue: 'YES'),
      InspectionField(key: 'warningLights', label: 'Warning Lights', type: FieldType.condition, defaultValue: 'YES'),
    ]),
    InspectionSection(section: 'OTHER SYSTEMS', fields: [
      InspectionField(key: 'audio', label: 'Audio', type: FieldType.condition, defaultValue: 'NO'),
      InspectionField(key: 'upholstery', label: 'Upholstery', type: FieldType.condition, defaultValue: 'GOOD'),
      InspectionField(key: 'loadCarrier', label: 'Load Carrier', type: FieldType.condition, defaultValue: 'YES'),
      InspectionField(key: 'frontCrashGuard', label: 'Front Crash Guard', type: FieldType.condition, defaultValue: 'NO'),
      InspectionField(key: 'rearCrashGuard', label: 'Rear Crash Guard', type: FieldType.condition, defaultValue: 'NO'),
      InspectionField(key: 'sideMirrors', label: 'Side Mirrors', type: FieldType.condition, defaultValue: 'NO'),
    ]),
  ],

  // ═══════════════════════════════════════════════════════════════════════════
  // CE — Construction Equipment
  // ═══════════════════════════════════════════════════════════════════════════
  VehicleTypeKey.ce: [
    InspectionSection(section: 'ENGINE CONDITION', fields: [
      InspectionField(key: 'engineCondition', label: 'Engine Condition', type: FieldType.condition, defaultValue: 'GOOD'),
      InspectionField(key: 'fluidLeaks', label: 'Fluid Leaks', type: FieldType.condition, defaultValue: 'NO'),
      InspectionField(key: 'radiator', label: 'Radiator', type: FieldType.condition, defaultValue: 'GOOD'),
      InspectionField(key: 'hydraulicOilCooler', label: 'Hydraulic Oil Cooler', type: FieldType.condition, defaultValue: 'GOOD'),
      InspectionField(key: 'fuelSystem', label: 'Fuel System', type: FieldType.condition, defaultValue: 'GOOD'),
    ]),
    InspectionSection(section: 'TRANSMISSION SYSTEM', fields: [
      InspectionField(key: 'gearBoxAssy', label: 'Gearbox Assy', type: FieldType.condition, defaultValue: 'GOOD'),
      InspectionField(key: 'torqueConverter', label: 'Torque Converter', type: FieldType.condition, defaultValue: 'GOOD'),
      InspectionField(key: 'finalDrive', label: 'Final Drive', type: FieldType.condition, defaultValue: 'GOOD'),
    ]),
    InspectionSection(section: 'BRAKES', fields: [
      InspectionField(key: 'serviceBrake', label: 'Service Brake', type: FieldType.condition, defaultValue: 'GOOD'),
      InspectionField(key: 'retarder', label: 'Retarder', type: FieldType.condition, defaultValue: 'GOOD'),
      InspectionField(key: 'parkingBrake', label: 'Parking Brake', type: FieldType.condition, defaultValue: 'GOOD'),
      InspectionField(key: 'emergencyStop', label: 'Emergency Stop', type: FieldType.condition, defaultValue: 'NO'),
    ]),
    InspectionSection(section: 'STEERING SYSTEM', fields: [
      InspectionField(key: 'steeringControlLevers', label: 'Steering / Control Levers', type: FieldType.condition, defaultValue: 'GOOD'),
      InspectionField(key: 'hydraulicSteeringPump', label: 'Hydraulic Steering Pump', type: FieldType.condition, defaultValue: 'GOOD'),
      InspectionField(key: 'swivelJoints', label: 'Swivel Joints', type: FieldType.condition, defaultValue: 'GOOD'),
    ]),
    InspectionSection(section: 'HYDRAULIC SYSTEM', fields: [
      InspectionField(key: 'hydraulicPump', label: 'Hydraulic Pump', type: FieldType.condition, defaultValue: 'GOOD'),
      InspectionField(key: 'hydraulicCylinders', label: 'Cylinders', type: FieldType.condition, defaultValue: 'GOOD'),
      InspectionField(key: 'hosesAndFittings', label: 'Hoses & Fittings', type: FieldType.condition, defaultValue: 'GOOD'),
    ]),
    InspectionSection(section: 'CABIN ASSEMBLY', fields: [
      InspectionField(key: 'cabinStructure', label: 'Cabin Structure', type: FieldType.condition, defaultValue: 'GOOD'),
      InspectionField(key: 'dashboardControls', label: 'Dash Board & Controls', type: FieldType.condition, defaultValue: 'GOOD'),
      InspectionField(key: 'doors', label: 'Doors', type: FieldType.condition, defaultValue: 'GOOD'),
      InspectionField(key: 'glassPanels', label: 'Glass Panels', type: FieldType.condition, defaultValue: 'GOOD'),
      InspectionField(key: 'seats', label: 'Seat', type: FieldType.condition, defaultValue: 'GOOD'),
    ]),
    InspectionSection(section: 'ATTACHMENTS', fields: [
      InspectionField(key: 'boomArm', label: 'Boom / Arm', type: FieldType.condition, defaultValue: 'GOOD'),
      InspectionField(key: 'bucketBlade', label: 'Bucket / Blade', type: FieldType.condition, defaultValue: 'GOOD'),
      InspectionField(key: 'counterWeight', label: 'Counter Weight', type: FieldType.condition, defaultValue: 'GOOD'),
      InspectionField(key: 'paintWork', label: 'Paint Work', type: FieldType.condition, defaultValue: 'GOOD'),
    ]),
    InspectionSection(section: 'ELECTRICAL SYSTEM', fields: [
      InspectionField(key: 'headLights', label: 'Lights', type: FieldType.condition, defaultValue: 'GOOD'),
      InspectionField(key: 'warningIndicatorLights', label: 'Warning / Indicator Lights', type: FieldType.condition, defaultValue: 'GOOD'),
      InspectionField(key: 'batteryCondition', label: 'Battery', type: FieldType.condition, defaultValue: 'GOOD'),
      InspectionField(key: 'wiringAssy', label: 'Wiring Assy', type: FieldType.condition, defaultValue: 'GOOD'),
      InspectionField(key: 'sensors', label: 'Sensors', type: FieldType.condition, defaultValue: 'GOOD'),
    ]),
    InspectionSection(section: 'TIRE / TRACK', fields: [
      InspectionField(key: 'tyreCondition', label: 'Tyre / Track Condition', type: FieldType.condition, defaultValue: 'AVERAGE'),
      InspectionField(key: 'numberOfTyres', label: 'Number of Tyres / Tracks', type: FieldType.number),
      InspectionField(key: 'missingTyres', label: 'Missing / Damaged', type: FieldType.number, defaultValue: '0'),
    ]),
    InspectionSection(section: 'FUNCTIONALITY', fields: [
      InspectionField(key: 'engineStarted', label: 'Engine Started', type: FieldType.condition, defaultValue: 'YES'),
      InspectionField(key: 'testDrive', label: 'Functional Test', type: FieldType.condition, defaultValue: 'YES'),
      InspectionField(key: 'vehicleMoved', label: 'Machine Moved', type: FieldType.condition, defaultValue: 'YES'),
      InspectionField(key: 'warningLights', label: 'Warning Lights', type: FieldType.condition, defaultValue: 'YES'),
    ]),
    InspectionSection(section: 'OTHER SYSTEMS', fields: [
      InspectionField(key: 'swingMechanism', label: 'Swing Mechanism', type: FieldType.condition, defaultValue: 'NO'),
      InspectionField(key: 'trackChains', label: 'Track Chains', type: FieldType.condition, defaultValue: 'NO'),
      InspectionField(key: 'sprockets', label: 'Sprockets', type: FieldType.condition, defaultValue: 'GOOD'),
      InspectionField(key: 'rollers', label: 'Rollers', type: FieldType.condition, defaultValue: 'GOOD'),
      InspectionField(key: 'hourMeter', label: 'Hour Meter', type: FieldType.condition, defaultValue: 'NO'),
      InspectionField(key: 'rockBreaker', label: 'Rock Breaker', type: FieldType.condition, defaultValue: 'NO'),
    ]),
  ],

  // ═══════════════════════════════════════════════════════════════════════════
  // BUS
  // ═══════════════════════════════════════════════════════════════════════════
  VehicleTypeKey.bus: [
    InspectionSection(section: 'ENGINE CONDITION', fields: [
      InspectionField(key: 'engineCondition', label: 'Engine Condition', type: FieldType.condition, defaultValue: 'GOOD'),
      InspectionField(key: 'fluidLeaks', label: 'Fluid Leaks', type: FieldType.condition, defaultValue: 'NO'),
      InspectionField(key: 'radiator', label: 'Radiator', type: FieldType.condition, defaultValue: 'GOOD'),
      InspectionField(key: 'allHosePipes', label: 'All Hose Pipes', type: FieldType.condition, defaultValue: 'GOOD'),
      InspectionField(key: 'fuelSystem', label: 'Fuel System', type: FieldType.condition, defaultValue: 'GOOD'),
    ]),
    InspectionSection(section: 'TRANSMISSION SYSTEM', fields: [
      InspectionField(key: 'gearBoxAssy', label: 'Gearbox Assy', type: FieldType.condition, defaultValue: 'GOOD'),
      InspectionField(key: 'clutchSystem', label: 'Clutch System', type: FieldType.condition, defaultValue: 'GOOD'),
      InspectionField(key: 'differentialAssy', label: 'Differential Assy', type: FieldType.condition, defaultValue: 'GOOD'),
    ]),
    InspectionSection(section: 'BRAKES', fields: [
      InspectionField(key: 'frontBrakes', label: 'Front Brakes', type: FieldType.condition, defaultValue: 'GOOD'),
      InspectionField(key: 'rearBrakes', label: 'Rear Brakes', type: FieldType.condition, defaultValue: 'GOOD'),
      InspectionField(key: 'parkingBrake', label: 'Parking Brake', type: FieldType.condition, defaultValue: 'GOOD'),
      InspectionField(key: 'abs', label: 'ABS', type: FieldType.condition, defaultValue: 'YES'),
    ]),
    InspectionSection(section: 'STEERING SYSTEM', fields: [
      InspectionField(key: 'steeringWheel', label: 'Steering Wheel', type: FieldType.condition, defaultValue: 'GOOD'),
      InspectionField(key: 'steeringColumn', label: 'Steering Column', type: FieldType.condition, defaultValue: 'GOOD'),
      InspectionField(key: 'steeringBox', label: 'Steering Box', type: FieldType.condition, defaultValue: 'GOOD'),
    ]),
    InspectionSection(section: 'SUSPENSION SYSTEM', fields: [
      InspectionField(key: 'frontSuspension', label: 'Front Suspension', type: FieldType.condition, defaultValue: 'GOOD'),
      InspectionField(key: 'rearSuspension', label: 'Rear Suspension', type: FieldType.condition, defaultValue: 'GOOD'),
      InspectionField(key: 'axles', label: 'Front & Rear Axles', type: FieldType.condition, defaultValue: 'GOOD'),
    ]),
    InspectionSection(section: 'COACH ASSEMBLY', fields: [
      InspectionField(key: 'driverCabin', label: 'Driver Cabin', type: FieldType.condition, defaultValue: 'GOOD'),
      InspectionField(key: 'dashboard', label: 'Dashboard', type: FieldType.condition, defaultValue: 'GOOD'),
      InspectionField(key: 'doors', label: 'Doors', type: FieldType.condition, defaultValue: 'GOOD'),
      InspectionField(key: 'allGlasses', label: 'All Glasses', type: FieldType.condition, defaultValue: 'GOOD'),
      InspectionField(key: 'bumpersAndGrilles', label: 'Bumpers & Grilles', type: FieldType.condition, defaultValue: 'GOOD'),
    ]),
    InspectionSection(section: 'BODY ASSEMBLY', fields: [
      InspectionField(key: 'seatsAndBerths', label: 'Seats & Berths', type: FieldType.condition, defaultValue: 'GOOD'),
      InspectionField(key: 'interiorTrims', label: 'Interior Trims', type: FieldType.condition, defaultValue: 'GOOD'),
      InspectionField(key: 'sideBodyPanels', label: 'Side Body Panels', type: FieldType.condition, defaultValue: 'GOOD'),
      InspectionField(key: 'rearBodyPanels', label: 'Rear Body Panels', type: FieldType.condition, defaultValue: 'GOOD'),
      InspectionField(key: 'chassisCondition', label: 'Chassis / Body Frame', type: FieldType.condition, defaultValue: 'GOOD'),
      InspectionField(key: 'paintWork', label: 'Paint Work', type: FieldType.condition, defaultValue: 'GOOD'),
    ]),
    InspectionSection(section: 'ELECTRICAL SYSTEM', fields: [
      InspectionField(key: 'headLights', label: 'Head Lights', type: FieldType.condition, defaultValue: 'GOOD'),
      InspectionField(key: 'tailLightsIndicators', label: 'Tail Lights / Indicators', type: FieldType.condition, defaultValue: 'GOOD'),
      InspectionField(key: 'batteryCondition', label: 'Battery', type: FieldType.condition, defaultValue: 'GOOD'),
      InspectionField(key: 'wiringAssy', label: 'Wiring Assy', type: FieldType.condition, defaultValue: 'GOOD'),
      InspectionField(key: 'clusterUnit', label: 'Cluster Unit', type: FieldType.condition, defaultValue: 'GOOD'),
    ]),
    InspectionSection(section: 'TIRES', fields: [
      InspectionField(key: 'tyreCondition', label: 'Tyre Condition', type: FieldType.condition, defaultValue: 'AVERAGE'),
      InspectionField(key: 'numberOfTyres', label: 'Number of Tyres', type: FieldType.number),
      InspectionField(key: 'missingTyres', label: 'Missing Tyres', type: FieldType.number, defaultValue: '0'),
    ]),
    InspectionSection(section: 'FUNCTIONALITY', fields: [
      InspectionField(key: 'engineStarted', label: 'Engine Started', type: FieldType.condition, defaultValue: 'YES'),
      InspectionField(key: 'testDrive', label: 'Test Drive', type: FieldType.condition, defaultValue: 'YES'),
      InspectionField(key: 'vehicleMoved', label: 'Vehicle Moved', type: FieldType.condition, defaultValue: 'YES'),
      InspectionField(key: 'warningLights', label: 'Warning Lights', type: FieldType.condition, defaultValue: 'YES'),
    ]),
    InspectionSection(section: 'OTHER SYSTEMS', fields: [
      InspectionField(key: 'airConditioner', label: 'Air Conditioner', type: FieldType.condition, defaultValue: 'NO'),
      InspectionField(key: 'audio', label: 'Audio', type: FieldType.condition, defaultValue: 'NO'),
      InspectionField(key: 'upholstery', label: 'Upholstery', type: FieldType.condition, defaultValue: 'GOOD'),
      InspectionField(key: 'loadCarrier', label: 'Load Carrier', type: FieldType.condition, defaultValue: 'YES'),
      InspectionField(key: 'frontCrashGuard', label: 'Front Crash Guard', type: FieldType.condition, defaultValue: 'NO'),
      InspectionField(key: 'rearCrashGuard', label: 'Rear Crash Guard', type: FieldType.condition, defaultValue: 'NO'),
    ]),
  ],

  // ═══════════════════════════════════════════════════════════════════════════
  // FE — Farm Equipment / Tractor
  // ═══════════════════════════════════════════════════════════════════════════
  VehicleTypeKey.fe: [
    InspectionSection(section: 'ENGINE CONDITION', fields: [
      InspectionField(key: 'engineCondition', label: 'Engine Condition', type: FieldType.condition, defaultValue: 'GOOD'),
      InspectionField(key: 'fluidLeaks', label: 'Fluid Leaks', type: FieldType.condition, defaultValue: 'NO'),
      InspectionField(key: 'radiator', label: 'Radiator', type: FieldType.condition, defaultValue: 'GOOD'),
      InspectionField(key: 'allHosePipes', label: 'All Hose Pipes', type: FieldType.condition, defaultValue: 'GOOD'),
      InspectionField(key: 'fuelSystem', label: 'Fuel System', type: FieldType.condition, defaultValue: 'GOOD'),
    ]),
    InspectionSection(section: 'TRANSMISSION SYSTEM', fields: [
      InspectionField(key: 'gearBoxAssy', label: 'Gearbox Assy', type: FieldType.condition, defaultValue: 'GOOD'),
      InspectionField(key: 'clutchSystem', label: 'Clutch System', type: FieldType.condition, defaultValue: 'GOOD'),
      InspectionField(key: 'differentialAssy', label: 'Differential Assy', type: FieldType.condition, defaultValue: 'GOOD'),
    ]),
    InspectionSection(section: 'BRAKES', fields: [
      InspectionField(key: 'rightIndividualBrakes', label: 'Right Individual Brakes', type: FieldType.condition, defaultValue: 'GOOD'),
      InspectionField(key: 'leftIndividualBrakes', label: 'Left Individual Brakes', type: FieldType.condition, defaultValue: 'GOOD'),
      InspectionField(key: 'parkingBrake', label: 'Parking Brake', type: FieldType.condition, defaultValue: 'GOOD'),
      InspectionField(key: 'brakeEqualization', label: 'Brake Equalization', type: FieldType.condition, defaultValue: 'GOOD'),
    ]),
    InspectionSection(section: 'STEERING SYSTEM', fields: [
      InspectionField(key: 'steeringWheel', label: 'Steering Wheel', type: FieldType.condition, defaultValue: 'GOOD'),
      InspectionField(key: 'steeringColumn', label: 'Steering Column', type: FieldType.condition, defaultValue: 'GOOD'),
      InspectionField(key: 'steeringBox', label: 'Steering Box', type: FieldType.condition, defaultValue: 'GOOD'),
    ]),
    InspectionSection(section: 'SUSPENSION SYSTEM', fields: [
      InspectionField(key: 'frontAxleFe', label: 'Front Axle', type: FieldType.condition, defaultValue: 'GOOD'),
      InspectionField(key: 'rearAxleFe', label: 'Rear Axle', type: FieldType.condition, defaultValue: 'GOOD'),
      InspectionField(key: 'tieRodsJoints', label: 'Tie Rods & Joints', type: FieldType.condition, defaultValue: 'GOOD'),
    ]),
    InspectionSection(section: 'CABIN ASSEMBLY', fields: [
      InspectionField(key: 'operatorStation', label: 'Operator Station', type: FieldType.condition, defaultValue: 'GOOD'),
      InspectionField(key: 'dashboard', label: 'Dash Board', type: FieldType.condition, defaultValue: 'GOOD'),
      InspectionField(key: 'canopy', label: 'Canopy', type: FieldType.condition, defaultValue: 'GOOD'),
      InspectionField(key: 'lockSet', label: 'Lock Set', type: FieldType.condition, defaultValue: 'GOOD'),
      InspectionField(key: 'seats', label: 'Seat', type: FieldType.condition, defaultValue: 'GOOD'),
    ]),
    InspectionSection(section: 'BODY ASSEMBLY', fields: [
      InspectionField(key: 'bonnet', label: 'Bonnet', type: FieldType.condition, defaultValue: 'GOOD'),
      InspectionField(key: 'frontGrilles', label: 'Front Grilles', type: FieldType.condition, defaultValue: 'GOOD'),
      InspectionField(key: 'sideFenders', label: 'Side Fenders', type: FieldType.condition, defaultValue: 'GOOD'),
      InspectionField(key: 'fuelTankFe', label: 'Fuel Tank', type: FieldType.condition, defaultValue: 'GOOD'),
      InspectionField(key: 'operatorPlatform', label: 'Operator Platform', type: FieldType.condition, defaultValue: 'GOOD'),
      InspectionField(key: 'paintWork', label: 'Paint Work', type: FieldType.condition, defaultValue: 'GOOD'),
    ]),
    InspectionSection(section: 'ELECTRICAL SYSTEM', fields: [
      InspectionField(key: 'headLights', label: 'Head Lights', type: FieldType.condition, defaultValue: 'GOOD'),
      InspectionField(key: 'tailLightsIndicators', label: 'Tail Lights / Indicators', type: FieldType.condition, defaultValue: 'GOOD'),
      InspectionField(key: 'batteryCondition', label: 'Battery', type: FieldType.condition, defaultValue: 'GOOD'),
      InspectionField(key: 'wiringAssy', label: 'Wiring Assy', type: FieldType.condition, defaultValue: 'GOOD'),
      InspectionField(key: 'switches', label: 'Switches', type: FieldType.condition, defaultValue: 'GOOD'),
    ]),
    InspectionSection(section: 'TIRES', fields: [
      InspectionField(key: 'tyreCondition', label: 'Tyre Condition', type: FieldType.condition, defaultValue: 'AVERAGE'),
      InspectionField(key: 'numberOfTyres', label: 'Number of Tyres', type: FieldType.number),
      InspectionField(key: 'missingTyres', label: 'Missing Tyres', type: FieldType.number, defaultValue: '0'),
    ]),
    InspectionSection(section: 'FUNCTIONALITY', fields: [
      InspectionField(key: 'engineStarted', label: 'Engine Started', type: FieldType.condition, defaultValue: 'YES'),
      InspectionField(key: 'testDrive', label: 'Field Function Test', type: FieldType.condition, defaultValue: 'YES'),
      InspectionField(key: 'vehicleMoved', label: 'Vehicle Moved', type: FieldType.condition, defaultValue: 'YES'),
      InspectionField(key: 'warningLights', label: 'Warning Lights', type: FieldType.condition, defaultValue: 'YES'),
    ]),
    InspectionSection(section: 'OTHER SYSTEMS', fields: [
      InspectionField(key: 'muffler', label: 'Muffler', type: FieldType.condition, defaultValue: 'NO'),
      InspectionField(key: 'airFilter', label: 'Air Filter', type: FieldType.condition, defaultValue: 'NO'),
      InspectionField(key: 'attachmentHitch', label: 'Attachment Hitch', type: FieldType.condition, defaultValue: 'GOOD'),
      InspectionField(key: 'hydraulicLiftFe', label: 'Hydraulic Lift Arm', type: FieldType.condition, defaultValue: 'YES'),
      InspectionField(key: 'dropArm', label: 'Drop Arm', type: FieldType.condition, defaultValue: 'NO'),
      InspectionField(key: 'rearDrawbar', label: 'Rear Drawbar', type: FieldType.condition, defaultValue: 'NO'),
    ]),
  ],
};

List<InspectionSection> getFieldRegistry(VehicleTypeKey vehicleType) {
  return fieldRegistry[vehicleType] ?? [];
}

List<String> getAllFieldKeys(VehicleTypeKey vehicleType) {
  return getFieldRegistry(vehicleType)
      .expand((s) => s.fields.map((f) => f.key))
      .toList();
}
