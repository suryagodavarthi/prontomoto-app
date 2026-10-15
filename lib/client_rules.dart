// client_rules.dart
// Rules that depend on who the client (the stakeholder's name) is.
// Mirrors prontofirebase's src/app/shared/client-rules.ts — keep in sync.
//
// TVS Credit wants extra facts on its reports: VIN plate, estimated life
// remaining and whether another finance company has seized the vehicle. The
// report prints an "Additional Details" box on page 3 for TVS Credit alone, and
// the AVO and backend pages ask for those facts on the same cases, so nobody is
// asked a question no report prints. Accident status is on every cover, so it is
// asked on every case and is not part of this rule.

/// Every live TVS case reads "TVS Credit Services Limited". The match is looser
/// than that so "TVS Credit Service Ltd" still counts. Keep it the same as
/// isTvsCredit in the portal and IsTvsCredit in ProntoPDFGeneration.
bool isTvsCredit(String? clientName) =>
    RegExp(r'\btvs\s*credit\b', caseSensitive: false).hasMatch(clientName ?? '');

/// What a TVS Credit report adds to the cover's REMARKS when the AVO found no
/// VIN plate. The client's own wording.
const String vinPlateMissingText =
    'VIN plate not found. Chassis number physically inspected and found original.';
