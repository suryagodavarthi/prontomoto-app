// Unit tests for the role/workflow level mapping that drives dashboard
// routing and case navigation. (The full app can't be pumped in widget tests
// because LoginPage requires an initialized Firebase app.)

import 'package:flutter_test/flutter_test.dart';

import 'package:prontomoto_app/main.dart';

void main() {
  test('roleLevelOf maps known roles to workflow levels', () {
    expect(roleLevelOf('stakeholder'), 1);
    expect(roleLevelOf('CanCreateStakeholder'), 1);
    expect(roleLevelOf('backend'), 2);
    expect(roleLevelOf('avo'), 3);
    expect(roleLevelOf('valuer'), 3);
    expect(roleLevelOf('qc'), 4);
    expect(roleLevelOf('CanEditQualityControl'), 4);
    expect(roleLevelOf('finalreport'), 5);
    expect(roleLevelOf('superadmin'), 5);
    expect(roleLevelOf('stateadmin'), 5);
  });

  test('roleLevelOf falls back to fuzzy matching for unknown variants', () {
    expect(roleLevelOf('QualityControl'), 4);
    expect(roleLevelOf('AvoUser'), 3);
    expect(roleLevelOf('BackendTeam'), 2);
    expect(roleLevelOf('somethingelse'), 1);
  });

  test('workflowLevelOf maps workflow names to levels', () {
    expect(workflowLevelOf('Stakeholder'), 1);
    expect(workflowLevelOf('Backend'), 2);
    expect(workflowLevelOf('AVO'), 3);
    expect(workflowLevelOf('Inspection'), 3);
    expect(workflowLevelOf('QualityControl'), 4);
    expect(workflowLevelOf('FinalReport'), 5);
  });
}
