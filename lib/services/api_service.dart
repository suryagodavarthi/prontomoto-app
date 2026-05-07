import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

class ApiService {
  final String baseUrl = "https://prontobackend-bhdnbec2fvd3ecfk.eastus2-01.azurewebsites.net/api";

  // Default timeout for non-AI calls. AI submission gets its own (longer) timeout.
  static const Duration _defaultTimeout = Duration(seconds: 20);
  static const Duration _aiTimeout = Duration(seconds: 30);

  // ===========================================================================
  // 1. AUTHENTICATION
  // ===========================================================================
  Future<Map<String, dynamic>> loginUser(String inputPhone) async {
    try {
      final allUsersUrl = Uri.parse('$baseUrl/users/all');
      final response = await http.get(allUsersUrl).timeout(_defaultTimeout);
      if (response.statusCode == 200) {
        List<dynamic> allUsers = jsonDecode(response.body);
        var user = allUsers.firstWhere(
            (u) => u['phoneNumber'].toString().contains(inputPhone),
            orElse: () => null);

        if (user != null) {
          String fetchedRole = user['roleId']?.toString() ?? "User";
          return {
            "success": true,
            "role": fetchedRole,
            "name": user['name'].toString(),
            "id": user['userId'].toString()
          };
        }
        return {"success": false, "message": "Phone number not found"};
      }
      return {"success": false, "message": "Server Error: ${response.statusCode}"};
    } catch (e) {
      return {"success": false, "message": "Connection Error: $e"};
    }
  }

  // ===========================================================================
  // 2. DASHBOARD & WORKFLOW (LEGACY - KEPT FOR BACKEND/STAKEHOLDER FLOWS)
  // ===========================================================================
  Future<List<dynamic>> getOpenValuations() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/valuations/workflows/open'))
          .timeout(_defaultTimeout);
      return response.statusCode == 200 ? jsonDecode(response.body) : [];
    } catch (e) {
      return [];
    }
  }

  // Internal helper used by advanceToNextStage (legacy self-healing) AND
  // by the new explicit startWorkflow/completeWorkflow methods.
  Future<Map<String, dynamic>> _workflowAction(String id, int stepOrder, String vehicleNo, String contact, String action) async {
    // CRITICAL: Preserve EXACT case from database - Cosmos DB partition keys are case-sensitive
    vehicleNo = vehicleNo.trim();
    contact = contact.trim();

    if (vehicleNo.isEmpty || contact.isEmpty) {
      return {"success": false, "message": "App Error: Missing Vehicle Number or Applicant Contact."};
    }

    try {
      final uri = Uri.parse('$baseUrl/valuations/$id/workflow/$stepOrder/$action').replace(
        queryParameters: {
          "vehicleNumber": vehicleNo,
          "applicantContact": contact
        }
      );

      debugPrint("DEBUG: Workflow action $action for step $stepOrder with vehicle: $vehicleNo");

      final response = await http.post(
        uri,
        headers: {"Accept": "application/json"},
      ).timeout(_defaultTimeout);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        debugPrint("DEBUG: Workflow action $action succeeded");
        return {"success": true};
      }

      // Backend returns 400 when trying to complete a step that is already 'Completed'
      // (cross-device re-submission or retry). Treat as idempotent success.
      if (action == 'complete' && response.statusCode == 400) {
        final body = response.body;
        if (body.contains("'Completed'") || body.toLowerCase().contains("completed")) {
          debugPrint("DEBUG: completeWorkflow step $stepOrder — already Completed, treating as success");
          return {"success": true};
        }
      }

      // Backend returns 400 when trying to start a step that is already 'InProgress'
      // (concurrent calls or retry). Safe to ignore.
      if (action == 'start' && response.statusCode == 400) {
        final body = response.body;
        if (body.contains("'InProgress'") || body.toLowerCase().contains("inprogress")) {
          debugPrint("DEBUG: startWorkflow step $stepOrder — already InProgress, treating as success");
          return {"success": true};
        }
      }

      debugPrint("DEBUG: Workflow action $action failed with ${response.statusCode}: ${response.body}");
      return {"success": false, "message": response.body};
    } catch (e) {
      debugPrint("DEBUG: Workflow action exception: $e");
      return {"success": false, "message": e.toString()};
    }
  }

  Future<Map<String, dynamic>> startInitialWorkflow(String id, String vehicleNo, String contact) async {
    return await _workflowAction(id, 1, vehicleNo, contact, 'start');
  }

  // LEGACY self-healing advance — still used by BackendCaseDetailsPage.
  // AVO dashboard now uses explicit startWorkflow / completeWorkflow / updateWorkflowTable instead.
  Future<Map<String, dynamic>> advanceToNextStage(String id, int currentStepOrder, String vehicleNo, String contact) async {
    contact = contact.trim();

    debugPrint("DEBUG: Starting workflow advance for step $currentStepOrder");
    debugPrint("DEBUG: Vehicle: $vehicleNo, Contact: $contact");

    if (currentStepOrder > 1) {
      int prevStep = currentStepOrder - 1;
      debugPrint("DEBUG: Healing previous step $prevStep");

      var prevStart = await _workflowAction(id, prevStep, vehicleNo, contact, 'start');
      if (prevStart['success'] != true) {
        return {"success": false, "message": "Failed to heal Prev Step ($prevStep) Start: ${prevStart['message']}"};
      }
      debugPrint("DEBUG: Previous step $prevStep started successfully");

      var prevComplete = await _workflowAction(id, prevStep, vehicleNo, contact, 'complete');
      if (prevComplete['success'] != true) {
        return {"success": false, "message": "Failed to heal Prev Step ($prevStep) Complete: ${prevComplete['message']}"};
      }
      debugPrint("DEBUG: Previous step $prevStep completed successfully");
    }

    debugPrint("DEBUG: Starting current step $currentStepOrder");
    var currentStart = await _workflowAction(id, currentStepOrder, vehicleNo, contact, 'start');
    if (currentStart['success'] != true) {
      return {"success": false, "message": "Failed to Start Current Step ($currentStepOrder): ${currentStart['message']}"};
    }
    debugPrint("DEBUG: Current step $currentStepOrder started successfully");

    debugPrint("DEBUG: Completing current step $currentStepOrder");
    var currentComplete = await _workflowAction(id, currentStepOrder, vehicleNo, contact, 'complete');
    if (currentComplete['success'] != true) {
      return {"success": false, "message": "Failed to Complete Current Step ($currentStepOrder): ${currentComplete['message']}"};
    }
    debugPrint("DEBUG: Current step $currentStepOrder completed successfully");

    int nextStepOrder = currentStepOrder + 1;
    debugPrint("DEBUG: Starting next step $nextStepOrder");
    var nextStart = await _workflowAction(id, nextStepOrder, vehicleNo, contact, 'start');
    if (nextStart['success'] != true) {
      return {"success": false, "message": "Failed to Start Next Step ($nextStepOrder): ${nextStart['message']}"};
    }
    debugPrint("DEBUG: Next step $nextStepOrder started successfully");

    String nextStepName = "Backend";
    if (nextStepOrder == 3) nextStepName = "AVO";
    if (nextStepOrder == 4) nextStepName = "QualityControl";
    if (nextStepOrder == 5) nextStepName = "FinalReport";

    var tableUpdate = await updateWorkflowTable(
      id,
      vehicleNo.trim(),
      contact,
      {
        "workflow": nextStepName,
        "workflowStepOrder": nextStepOrder,
        "status": "InProgress",
      },
    );
    if (tableUpdate['success'] != true) {
      debugPrint("DEBUG: Table update failed (non-fatal): ${tableUpdate['message']}");
    }

    debugPrint("DEBUG: Workflow advance completed successfully");
    return {"success": true};
  }

  // LEGACY simple reject — still used by BackendCaseDetailsPage.
  // AVO dashboard now uses returnWorkflow with reason + override fallback.
  Future<Map<String, dynamic>> rejectToPreviousStage(
      String id, int currentStepOrder, String vehicleNo, String contact,
      {String reason = "Rejected from Mobile App"}) async {
    if (vehicleNo.trim().isEmpty) vehicleNo = "UNKNOWN";
    if (contact.trim().isEmpty) contact = "0000000000";

    vehicleNo = vehicleNo.trim();
    contact = contact.trim();

    String currentStepName = currentStepOrder == 3 ? "AVO" : "Backend";
    String targetStep = currentStepOrder == 3 ? "Backend" : "Stakeholder";

    try {
      final uri = Uri.parse('$baseUrl/valuations/$id/workflow/return');
      final response = await http.post(
        uri,
        headers: {"Accept": "application/json", "Content-Type": "application/json"},
        body: jsonEncode({
          "ValuationId": id,
          "VehicleNumber": vehicleNo,
          "ApplicantContact": contact,
          "CurrentStep": currentStepName,
          "TargetReturnStep": targetStep,
          "ReturnReason": reason.isNotEmpty ? reason : "Rejected from Mobile App",
        })
      ).timeout(_defaultTimeout);
      if (response.statusCode >= 200 && response.statusCode < 300) return {"success": true};
      return {"success": false, "message": "Code ${response.statusCode}: ${response.body}"};
    } catch (e) {
      return {"success": false, "message": e.toString()};
    }
  }

  // ===========================================================================
  // 2b. EXPLICIT WORKFLOW METHODS (matches web portal's WorkflowService)
  // ===========================================================================

  /// POST /valuations/{id}/workflow/{stepOrder}/start?vehicleNumber=X&applicantContact=Y
  Future<Map<String, dynamic>> startWorkflow(String id, int stepOrder, String vehicleNo, String contact) async {
    return _workflowAction(id, stepOrder, vehicleNo, contact, 'start');
  }

  /// POST /valuations/{id}/workflow/{stepOrder}/complete?vehicleNumber=X&applicantContact=Y
  Future<Map<String, dynamic>> completeWorkflow(String id, int stepOrder, String vehicleNo, String contact) async {
    return _workflowAction(id, stepOrder, vehicleNo, contact, 'complete');
  }

  /// PUT /valuations/{id}/workflow/Table — updates Azure Table Storage row.
  /// Body matches the web portal: valuationId/vehicleNumber/applicantContact + arbitrary fields.
  Future<Map<String, dynamic>> updateWorkflowTable(
    String id,
    String vehicleNo,
    String contact,
    Map<String, dynamic> fields,
  ) async {
    if (vehicleNo.trim().isEmpty) vehicleNo = "UNKNOWN";
    if (contact.trim().isEmpty) contact = "0000000000";

    try {
      final uri = Uri.parse('$baseUrl/valuations/$id/workflow/Table');
      final body = jsonEncode({
        "valuationId": id,
        "vehicleNumber": vehicleNo.trim(),
        "applicantContact": contact.trim(),
        ...fields,
      });

      final response = await http.put(
        uri,
        headers: {"Accept": "application/json", "Content-Type": "application/json"},
        body: body,
      ).timeout(_defaultTimeout);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return {"success": true};
      }
      return {
        "success": false,
        "message": "Table update failed (${response.statusCode}): ${response.body}",
      };
    } catch (e) {
      return {"success": false, "message": e.toString()};
    }
  }

  /// GET /valuations/{id}/workflow/Table?vehicleNumber=X&applicantContact=Y
  /// Returns the workflow Table row (used to detect "returned" status banner).
  Future<Map<String, dynamic>> getWorkflowTable(String id, String vehicleNo, String contact) async {
    if (vehicleNo.trim().isEmpty) vehicleNo = "UNKNOWN";
    if (contact.trim().isEmpty) contact = "0000000000";

    try {
      final uri = Uri.parse('$baseUrl/valuations/$id/workflow/Table').replace(
        queryParameters: {"vehicleNumber": vehicleNo.trim(), "applicantContact": contact.trim()},
      );
      final response = await http.get(uri).timeout(_defaultTimeout);
      if (response.statusCode == 200) {
        final body = response.body.trim();
        if (body.isEmpty) return {};
        final decoded = jsonDecode(body);
        if (decoded is Map<String, dynamic>) return decoded;
        return {};
      }
      return {};
    } catch (e) {
      return {};
    }
  }

  /// POST /valuations/{id}/workflow/return — return-with-reason flow.
  /// On 400 with "overrideAssigneeId" message, the caller should fetch backend users
  /// and retry with the chosen overrideAssigneeId.
  Future<Map<String, dynamic>> returnWorkflow({
    required String valuationId,
    required String vehicleNumber,
    required String applicantContact,
    required String currentStep,
    required String returnReason,
    required String currentUserId,
    required String currentUserName,
    required String targetReturnStep,
    String overrideAssigneeId = "",
  }) async {
    final cleanVeh = vehicleNumber.trim().isEmpty ? "UNKNOWN" : vehicleNumber.trim();
    final cleanContact = applicantContact.trim().isEmpty ? "0000000000" : applicantContact.trim();

    try {
      final uri = Uri.parse('$baseUrl/valuations/$valuationId/workflow/return');
      final body = jsonEncode({
        "valuationId": valuationId,
        "vehicleNumber": cleanVeh,
        "applicantContact": cleanContact,
        "currentStep": currentStep,
        "returnReason": returnReason,
        "currentUserId": currentUserId,
        "currentUserName": currentUserName,
        "targetReturnStep": targetReturnStep,
        "overrideAssigneeId": overrideAssigneeId,
      });

      final response = await http.post(
        uri,
        headers: {"Accept": "application/json", "Content-Type": "application/json"},
        body: body,
      ).timeout(_defaultTimeout);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return {"success": true};
      }
      // Surface the original status code so caller can detect 400 + "overrideAssigneeId"
      return {
        "success": false,
        "statusCode": response.statusCode,
        "message": response.body,
      };
    } catch (e) {
      return {"success": false, "message": e.toString()};
    }
  }

  // ===========================================================================
  // 2c. PAYMENTS (separate endpoint per workflow.service.ts)
  // ===========================================================================

  /// GET /payments/{valuationId}
  Future<Map<String, dynamic>> getPayment(String valuationId) async {
    try {
      final uri = Uri.parse('$baseUrl/payments/$valuationId');
      final response = await http.get(uri).timeout(_defaultTimeout);
      if (response.statusCode == 200) {
        final body = response.body.trim();
        if (body.isEmpty) return {};
        final decoded = jsonDecode(body);
        if (decoded is Map<String, dynamic>) {
          return decoded.map((k, v) => MapEntry(k.toLowerCase(), v));
        }
        return {};
      }
      // 404 on a brand-new case is normal — return empty rather than error.
      return {};
    } catch (e) {
      return {};
    }
  }

  /// PUT /payments — body matches web portal's savePayment().
  Future<Map<String, dynamic>> savePayment({
    required String valuationId,
    required String vehicleNumber,
    required String applicantContact,
    required String paymentStatus,
    String? paymentReference,
    required String paymentDate, // ISO 8601 UTC string
    required String paymentMethod,
    required num paymentAmount,
    String? paymentNotes,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/payments');
      final body = jsonEncode({
        "valuationId": valuationId,
        "vehicleNumber": vehicleNumber.trim(),
        "applicantContact": applicantContact.trim(),
        "paymentStatus": paymentStatus,
        // Always send — backend has [Required] on this even if value is empty.
        "paymentReference": paymentReference ?? "",
        "paymentDate": paymentDate,
        "paymentMethod": paymentMethod,
        "paymentAmount": paymentAmount,
        "paymentNotes": paymentNotes ?? "",
      });

      final response = await http.put(
        uri,
        headers: {"Accept": "application/json", "Content-Type": "application/json"},
        body: body,
      ).timeout(_defaultTimeout);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return {"success": true};
      }
      return {
        "success": false,
        "message": "Payment save failed (${response.statusCode}): ${response.body}",
      };
    } catch (e) {
      return {"success": false, "message": e.toString()};
    }
  }

  // ===========================================================================
  // 2d. MANDATORY PHOTO CHECK
  // ===========================================================================

  /// VERIFY ENDPOINT: I don't have vehicle-inspection.service.ts. Best guess based
  /// on the URL pattern of other inspection endpoints. If this 404s, replace the
  /// path with the real one.
  ///
  /// Returns: {"isComplete": bool, "missingPhotos": List<String>, "endpointMissing": bool}
  /// If the endpoint itself is missing (404), endpointMissing=true so the UI can
  /// distinguish "missing photos" from "missing API" and decide what to do.
  Future<Map<String, dynamic>> checkMandatoryPhotos(String id, String vNo, String contact) async {
    if (vNo.trim().isEmpty) vNo = "UNKNOWN";
    if (contact.trim().isEmpty) contact = "0000000000";

    try {
      final uri = Uri.parse('$baseUrl/valuations/$id/photos/validate').replace(
        queryParameters: {"vehicleNumber": vNo.trim(), "applicantContact": contact.trim()},
      );
      final response = await http.get(uri).timeout(_defaultTimeout);

      if (response.statusCode == 200) {
        final body = response.body.trim();
        if (body.isEmpty) {
          return {"isComplete": true, "missingPhotos": <String>[]};
        }
        final decoded = jsonDecode(body);
        if (decoded is Map<String, dynamic>) {
          final isComplete = decoded['isComplete'] ?? decoded['IsComplete'] ?? false;
          final missingRaw = decoded['missingPhotos'] ?? decoded['MissingPhotos'] ?? [];
          final missing = (missingRaw is List) ? missingRaw.map((e) => e.toString()).toList() : <String>[];
          return {
            "isComplete": isComplete == true,
            "missingPhotos": missing,
          };
        }
      }
      if (response.statusCode == 404) {
        // Endpoint not deployed yet — surface this so UI doesn't silently block users.
        return {
          "isComplete": true,
          "missingPhotos": <String>[],
          "endpointMissing": true,
        };
      }
      return {
        "isComplete": false,
        "missingPhotos": <String>[],
        "error": "Photo check failed (${response.statusCode}): ${response.body}",
      };
    } catch (e) {
      return {
        "isComplete": false,
        "missingPhotos": <String>[],
        "error": e.toString(),
      };
    }
  }

  // ===========================================================================
  // 2e. AI VALUATION ASSIST (called inline during Submit, like web portal)
  // ===========================================================================

  /// Triggers the AI valuation assist via GET /api/valuations/{id}/valuation.
  /// The backend calls OpenAI/GPT internally and stores the result in the document.
  /// Has a 30s timeout — if AI is slow, Submit hangs up to 30s rather than forever.
  Future<Map<String, dynamic>> getValuationDetailsfromAI(String id, String vNo, String contact) async {
    if (vNo.trim().isEmpty) vNo = "UNKNOWN";
    if (contact.trim().isEmpty) contact = "0000000000";

    try {
      final uri = Uri.parse('$baseUrl/valuations/$id/valuation').replace(
        queryParameters: {"vehicleNumber": vNo.trim(), "applicantContact": contact.trim()},
      );
      final response = await http.get(uri).timeout(_aiTimeout);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return {"success": true};
      }
      return {
        "success": false,
        "statusCode": response.statusCode,
        "message": "AI call failed (${response.statusCode}): ${response.body}",
      };
    } on TimeoutException {
      return {"success": false, "message": "AI service timed out after 30s. Try again."};
    } catch (e) {
      return {"success": false, "message": e.toString()};
    }
  }

  // ===========================================================================
  // 2f. USER LOOKUP (for return-with-override picker)
  // ===========================================================================

  /// VERIFY ENDPOINT: I don't have users.service.ts. Best guess based on the
  /// existing /users/all endpoint. If this 404s, replace path or fall back to
  /// filtering /users/all by role client-side.
  Future<List<Map<String, dynamic>>> getUsersByRole(String role) async {
    try {
      final uri = Uri.parse('$baseUrl/users/byrole/$role');
      final response = await http.get(uri).timeout(_defaultTimeout);
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is List) {
          return decoded.map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e)).toList();
        }
      }
      // Fallback: fetch all users and filter client-side. Slow but works as long as /users/all exists.
      if (response.statusCode == 404) {
        return await _getUsersByRoleFallback(role);
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _getUsersByRoleFallback(String role) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/users/all')).timeout(_defaultTimeout);
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is List) {
          return decoded
              .where((u) => u is Map && (u['role']?.toString().toLowerCase() == role.toLowerCase()))
              .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e))
              .toList();
        }
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // ===========================================================================
  // 3. STAKEHOLDER (FILES & GENERAL DATA)
  // ===========================================================================
  Future<Map<String, dynamic>> createValuation(Map<String, String> formData,
      {String? rcPath, String? insurancePath, String? otherPath,
      Uint8List? rcBytes, String? rcFilename,
      Uint8List? insuranceBytes, String? insuranceFilename,
      Uint8List? otherBytes, String? otherFilename}) async {
    var uuid = const Uuid();
    String newId = uuid.v4();
    final url = Uri.parse('$baseUrl/valuations/$newId/stakeholder');
    try {
      var request = http.MultipartRequest('PUT', url);
      request.fields.addAll(formData);

      request.fields['ValuationId'] = newId;
      request.fields['valuationId'] = newId;

      // Bytes-based path (web + mobile). Falls back to path-based (mobile only) if bytes not provided.
      if (rcBytes != null) {
        request.files.add(http.MultipartFile.fromBytes('rcFile', rcBytes,
            filename: rcFilename ?? 'rc.bin'));
      } else if (rcPath != null) {
        request.files.add(await http.MultipartFile.fromPath('rcFile', rcPath));
      }
      if (insuranceBytes != null) {
        request.files.add(http.MultipartFile.fromBytes('insuranceFile', insuranceBytes,
            filename: insuranceFilename ?? 'insurance.bin'));
      } else if (insurancePath != null) {
        request.files.add(await http.MultipartFile.fromPath('insuranceFile', insurancePath));
      }
      if (otherBytes != null) {
        request.files.add(http.MultipartFile.fromBytes('otherFiles', otherBytes,
            filename: otherFilename ?? 'other.bin'));
      } else if (otherPath != null) {
        request.files.add(await http.MultipartFile.fromPath('otherFiles', otherPath));
      }

      var response = await http.Response.fromStream(await request.send());
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return {"success": true, "message": "Request Created Successfully!", "id": newId};
      }
      return {"success": false, "message": "Server Error: ${response.body}"};
    } catch (e) {
      return {"success": false, "message": "Connection Error: $e"};
    }
  }

  Future<Map<String, dynamic>> updateValuation(String id, Map<String, String> formData,
      {String? rcPath, String? insurancePath, String? otherPath,
      Uint8List? rcBytes, String? rcFilename,
      Uint8List? insuranceBytes, String? insuranceFilename,
      Uint8List? otherBytes, String? otherFilename}) async {
    final url = Uri.parse('$baseUrl/valuations/$id/stakeholder');
    try {
      var request = http.MultipartRequest('PUT', url);
      request.fields.addAll(formData);

      request.fields['ValuationId'] = id;
      request.fields['valuationId'] = id;

      if (rcBytes != null) {
        request.files.add(http.MultipartFile.fromBytes('rcFile', rcBytes,
            filename: rcFilename ?? 'rc.bin'));
      } else if (rcPath != null) {
        request.files.add(await http.MultipartFile.fromPath('rcFile', rcPath));
      }
      if (insuranceBytes != null) {
        request.files.add(http.MultipartFile.fromBytes('insuranceFile', insuranceBytes,
            filename: insuranceFilename ?? 'insurance.bin'));
      } else if (insurancePath != null) {
        request.files.add(await http.MultipartFile.fromPath('insuranceFile', insurancePath));
      }
      if (otherBytes != null) {
        request.files.add(http.MultipartFile.fromBytes('otherFiles', otherBytes,
            filename: otherFilename ?? 'other.bin'));
      } else if (otherPath != null) {
        request.files.add(await http.MultipartFile.fromPath('otherFiles', otherPath));
      }

      var response = await http.Response.fromStream(await request.send());
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return {"success": true, "message": "Updated Successfully!"};
      }
      return {"success": false, "message": "Update Failed: ${response.body}"};
    } catch (e) {
      return {"success": false, "message": "Connection Error: $e"};
    }
  }

  Future<Map<String, dynamic>> getValuationDetails(String id, String vehicleNo, String contact) async {
    if (vehicleNo.trim().isEmpty) vehicleNo = "UNKNOWN";
    if (contact.trim().isEmpty) contact = "0000000000";

    final uri = Uri.parse('$baseUrl/valuations/$id/stakeholder').replace(
        queryParameters: {"vehicleNumber": vehicleNo.trim(), "applicantContact": contact.trim()});
    try {
      final response = await http.get(uri).timeout(_defaultTimeout);
      if (response.statusCode == 200) {
        var decoded = jsonDecode(response.body);
        if (decoded is List && decoded.isNotEmpty) {
          return Map<String, dynamic>.from(decoded[0]).map((k, v) => MapEntry(k.toLowerCase(), v));
        } else if (decoded is Map<String, dynamic>) {
          return decoded.map((k, v) => MapEntry(k.toLowerCase(), v));
        }
      }
      return {};
    } catch (e) {
      return {};
    }
  }

  // ===========================================================================
  // 4. BACKEND VEHICLE DETAILS
  // ===========================================================================
  Future<Map<String, dynamic>> getBackendVehicleDetails(String id, String vNo, String contact) async {
    Map<String, dynamic> data = {};
    Map<String, dynamic> normalize(Map<String, dynamic> d) => d.map((k, v) => MapEntry(k.toLowerCase(), v));

    if (vNo.trim().isEmpty) vNo = "UNKNOWN";
    if (contact.trim().isEmpty) contact = "0000000000";

    String originalVNo = vNo.trim();

    try {
      final rcRes = await http.get(Uri.parse('$baseUrl/valuations/$id/vehicledetails/with-rc').replace(
          queryParameters: {"vehicleNumber": originalVNo, "applicantContact": contact.trim()})).timeout(_defaultTimeout);
      if (rcRes.statusCode == 200) {
        data.addAll(normalize(jsonDecode(rcRes.body)));
      }
    } catch (e) {
      debugPrint("RC fetch error: $e");
    }

    try {
      final savedRes = await http.get(Uri.parse('$baseUrl/valuations/$id/vehicledetails').replace(
          queryParameters: {"vehicleNumber": originalVNo, "applicantContact": contact.trim()})).timeout(_defaultTimeout);
      if (savedRes.statusCode == 200) {
        var saved = normalize(jsonDecode(savedRes.body));
        saved.forEach((k, v) {
          if (v != null && v.toString() != "null") data[k] = v;
        });
      }
    } catch (e) {
      debugPrint("Saved details fetch error: $e");
    }

    return data;
  }

  Future<Map<String, dynamic>> updateBackendVehicleDetails(String id, String vNo, String contact, Map<String, dynamic> data) async {
    if (vNo.trim().isEmpty) vNo = "UNKNOWN";
    if (contact.trim().isEmpty) contact = "0000000000";

    String originalVNo = vNo.trim();

    try {
      final uri = Uri.parse('$baseUrl/valuations/$id/vehicledetails').replace(
          queryParameters: {"vehicleNumber": originalVNo, "applicantContact": contact.trim()});

      var request = http.MultipartRequest('PUT', uri);

      request.fields['ValuationId'] = id;
      request.fields['valuationId'] = id;

      data.forEach((k, v) {
        String val = (v == null || v.toString() == "null") ? "" : v.toString();
        request.fields[k] = val;

        if (k.isNotEmpty) {
          String camelKey = k[0].toLowerCase() + k.substring(1);
          if (camelKey != k) request.fields[camelKey] = val;
        }
        if (k.toLowerCase() != k) request.fields[k.toLowerCase()] = val;
        if (k == 'BacklistStatus') request.fields['BlacklistStatus'] = val;
      });

      var response = await http.Response.fromStream(await request.send());

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return {"success": true, "message": "Saved!"};
      }
      return {"success": false, "message": "Backend Save Failed (${response.statusCode}): ${response.body}"};
    } catch (e) {
      return {"success": false, "message": "Error: $e"};
    }
  }

  Future<bool> assignBackendTask(String id, String vNo, String contact, String assigneeName) async {
    if (vNo.trim().isEmpty) vNo = "UNKNOWN";
    if (contact.trim().isEmpty) contact = "0000000000";

    String originalVNo = vNo.trim();

    try {
      final uri = Uri.parse('$baseUrl/valuations/$id/vehicledetails/assignment').replace(
          queryParameters: {
            "vehicleNumber": originalVNo,
            "applicantContact": contact.trim(),
            "assignedTo": assigneeName.trim()
          });
      final response = await http.post(
        uri,
        headers: {"Accept": "application/json"},
      ).timeout(_defaultTimeout);
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (e) {
      return false;
    }
  }

  // ===========================================================================
  // 5. INSPECTION DETAILS
  // ===========================================================================
  Future<Map<String, dynamic>> getInspectionDetails(String id, String vNo, String contact) async {
    if (vNo.trim().isEmpty) vNo = "UNKNOWN";
    if (contact.trim().isEmpty) contact = "0000000000";

    try {
      final response = await http.get(Uri.parse('$baseUrl/valuations/$id/inspection').replace(
          queryParameters: {"vehicleNumber": vNo.trim(), "applicantContact": contact.trim()})).timeout(_defaultTimeout);
      if (response.statusCode == 200) {
        return (jsonDecode(response.body) as Map<String, dynamic>).map((k, v) => MapEntry(k.toLowerCase(), v));
      }
      return {};
    } catch (e) {
      return {};
    }
  }

  /// LEGACY — kept unchanged for any existing callers.
  Future<Map<String, dynamic>> updateInspectionDetails(String id, String vNo, String contact, Map<String, dynamic> data) async {
    if (vNo.trim().isEmpty) vNo = "UNKNOWN";
    if (contact.trim().isEmpty) contact = "0000000000";

    try {
      var request = http.MultipartRequest('PUT', Uri.parse('$baseUrl/valuations/$id/inspection').replace(
          queryParameters: {"vehicleNumber": vNo.trim(), "applicantContact": contact.trim()}));
      data.forEach((k, v) {
        if (v != null) request.fields[k] = v.toString();
      });
      var response = await http.Response.fromStream(await request.send());
      if (response.statusCode >= 200 && response.statusCode < 300) return {"success": true, "message": "Saved!"};
      return {"success": false, "message": "Inspection Save Failed: ${response.body}"};
    } catch (e) {
      return {"success": false, "message": "Error: $e"};
    }
  }

  /// NEW — used by AVO Save/Submit flow. Sends payload that mirrors the web portal,
  /// including valuationId/vehicleNumber/applicantContact, all assignee fields,
  /// in PascalCase (single casing, no duplicates — ASP.NET binding is case-insensitive,
  /// and sending both casings produces "VALUE,VALUE" which fails validation).
  Future<Map<String, dynamic>> saveInspectionForAvo({
    required String id,
    required String vNo,
    required String contact,
    required Map<String, dynamic> formFields,
    required String assignedTo,
    String assignedToPhoneNumber = "",
    String assignedToEmail = "",
    String assignedToWhatsapp = "",
  }) async {
    if (vNo.trim().isEmpty) vNo = "UNKNOWN";
    if (contact.trim().isEmpty) contact = "0000000000";

    try {
      final uri = Uri.parse('$baseUrl/valuations/$id/inspection').replace(
          queryParameters: {"vehicleNumber": vNo.trim(), "applicantContact": contact.trim()});

      var request = http.MultipartRequest('PUT', uri);

      // Identifiers — single PascalCase to match backend DTO.
      request.fields['ValuationId'] = id;
      request.fields['VehicleNumber'] = vNo.trim();
      request.fields['ApplicantContact'] = contact.trim();

      // Assignee fields (mirrors web portal's buildFormData)
      request.fields['AssignedTo'] = assignedTo;
      request.fields['AssignedToPhoneNumber'] = assignedToPhoneNumber;
      request.fields['AssignedToEmail'] = assignedToEmail;
      request.fields['AssignedToWhatsapp'] = assignedToWhatsapp;

      // Form fields — single casing as provided by caller (PascalCase).
      // DO NOT send dual casing here — ASP.NET binding is case-insensitive
      // and combines duplicates into comma-separated values that fail validation.
      formFields.forEach((k, v) {
        if (k.isEmpty) return;
        final val = (v == null || v.toString() == "null") ? "" : v.toString();
        request.fields[k] = val;
      });

      var response = await http.Response.fromStream(await request.send());
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return {"success": true};
      }
      return {
        "success": false,
        "message": "Inspection save failed (${response.statusCode}): ${response.body}",
      };
    } catch (e) {
      return {"success": false, "message": e.toString()};
    }
  }

  // ===========================================================================
  // 5b. QUALITY CONTROL
  // ===========================================================================

  /// GET /valuations/{id}/qualitycontrol
  Future<Map<String, dynamic>> getQualityControlDetails(String id, String vNo, String contact) async {
    if (vNo.trim().isEmpty) vNo = "UNKNOWN";
    if (contact.trim().isEmpty) contact = "0000000000";

    try {
      final uri = Uri.parse('$baseUrl/valuations/$id/qualitycontrol').replace(
          queryParameters: {"vehicleNumber": vNo.trim(), "applicantContact": contact.trim()});
      final response = await http.get(uri).timeout(_defaultTimeout);
      if (response.statusCode == 200) {
        final body = response.body.trim();
        if (body.isEmpty) return {};
        final decoded = jsonDecode(body);
        if (decoded is Map<String, dynamic>) {
          return decoded.map((k, v) => MapEntry(k.toLowerCase(), v));
        }
      }
      return {};
    } catch (e) {
      return {};
    }
  }

  /// PUT /valuations/{id}/qualitycontrol — JSON body (NOT multipart, per web service)
  Future<Map<String, dynamic>> updateQualityControlDetails(
      String id, String vNo, String contact, Map<String, dynamic> body) async {
    if (vNo.trim().isEmpty) vNo = "UNKNOWN";
    if (contact.trim().isEmpty) contact = "0000000000";

    try {
      final uri = Uri.parse('$baseUrl/valuations/$id/qualitycontrol').replace(
          queryParameters: {"vehicleNumber": vNo.trim(), "applicantContact": contact.trim()});
      final response = await http.put(
        uri,
        headers: {"Accept": "application/json", "Content-Type": "application/json"},
        body: jsonEncode(body),
      ).timeout(_defaultTimeout);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return {"success": true};
      }
      return {
        "success": false,
        "message": "QC save failed (${response.statusCode}): ${response.body}",
      };
    } catch (e) {
      return {"success": false, "message": e.toString()};
    }
  }

  /// POST /valuations/{id}/qualitycontrol/assignment?... — query-string POST per web
  Future<bool> assignQualityControl(String id, String vNo, String contact,
      String name, String phone, String email, String whatsapp) async {
    try {
      final uri = Uri.parse('$baseUrl/valuations/$id/qualitycontrol/assignment').replace(
        queryParameters: {
          "valuationId": id,
          "vehicleNumber": vNo.trim(),
          "applicantContact": contact.trim(),
          "assignedTo": name,
          "assignedToPhoneNumber": phone,
          "assignedToEmail": email,
          "assignedToWhatsapp": whatsapp,
        },
      );
      final response = await http.post(uri, headers: {"Accept": "application/json"}).timeout(_defaultTimeout);
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (e) {
      return false;
    }
  }

  /// POST /valuations/{id}/valuationresponse/assignment?... — query-string POST per web
  Future<bool> assignValuation(String id, String vNo, String contact,
      String name, String phone, String email, String whatsapp) async {
    try {
      final uri = Uri.parse('$baseUrl/valuations/$id/valuationresponse/assignment').replace(
        queryParameters: {
          "valuationId": id,
          "vehicleNumber": vNo.trim(),
          "applicantContact": contact.trim(),
          "assignedTo": name,
          "assignedToPhoneNumber": phone,
          "assignedToEmail": email,
          "assignedToWhatsapp": whatsapp,
        },
      );
      final response = await http.post(uri, headers: {"Accept": "application/json"}).timeout(_defaultTimeout);
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (e) {
      return false;
    }
  }

  /// GET /valuations/{id}/valuationresponse/FinalReport — composite report data
  /// Returns the full FinalReport document including stakeholder, vehicleDetails,
  /// inspectionDetails, qualityControl, valuationResponse, photoUrls, etc.
  /// Returns empty map on 404 — final report may not exist for older cases.
  Future<Map<String, dynamic>> getFinalReport(String id, String vNo, String contact) async {
    if (vNo.trim().isEmpty) vNo = "UNKNOWN";
    if (contact.trim().isEmpty) contact = "0000000000";

    try {
      final uri = Uri.parse('$baseUrl/valuations/$id/valuationresponse/FinalReport').replace(
          queryParameters: {"vehicleNumber": vNo.trim(), "applicantContact": contact.trim()});
      final response = await http.get(uri).timeout(_defaultTimeout);
      if (response.statusCode == 200) {
        final body = response.body.trim();
        if (body.isEmpty) return {};
        final decoded = jsonDecode(body);
        if (decoded is Map<String, dynamic>) return decoded;
      }
      return {};
    } catch (e) {
      return {};
    }
  }

  // ===========================================================================
  // 6. NOTES
  // ===========================================================================
  Future<bool> addNote(String valuationId, String noteText) async {
    try {
      final response = await http.post(Uri.parse('$baseUrl/CommonNote'),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({
            "entityType": "Valuation",
            "entityId": valuationId,
            "note": noteText,
            "createdBy": "System"
          })).timeout(_defaultTimeout);
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (e) {
      return false;
    }
  }

  Future<List<dynamic>> getNotes(String valuationId) async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/CommonNote/entity/Valuation/$valuationId'))
          .timeout(_defaultTimeout);
      if (response.statusCode == 200) return jsonDecode(response.body);
      return [];
    } catch (e) {
      return [];
    }
  }

  // ===========================================================================
  // 7. PINCODE LOOKUP
  // Matches Angular PincodeService → GET /api/Pincodes/{pincode}
  // Returns list of office objects: { name, block, district, division, state, country }
  // ===========================================================================
  Future<List<dynamic>> lookupPincode(String pincode) async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/Pincodes/$pincode'))
          .timeout(_defaultTimeout);
      if (response.statusCode == 200) return jsonDecode(response.body);
      return [];
    } catch (e) {
      return [];
    }
  }

  // ===========================================================================
  // 8. COMPLETE VALUATION (Final Report step)
  // POST /api/valuations/{id}/valuationresponse/complete
  // Matches Angular ValuationResponseService.completeValuationResponse()
  // ===========================================================================
  Future<Map<String, dynamic>> completeValuationResponse({
    required String valuationId,
    required String vehicleNumber,
    required String applicantContact,
    required String completedBy,
    String? completedByPhone,
    String? completedByEmail,
    String? paymentStatus,
    String? paymentReference,
    String? paymentDate,
    String? paymentMethod,
    String? paymentAmount,
    String? remarks,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/valuations/$valuationId/valuationresponse/complete')
          .replace(queryParameters: {
        "vehicleNumber": vehicleNumber,
        "applicantContact": applicantContact,
      });

      final Map<String, dynamic> body = {
        "Status": "Completed",
        "CompletedAt": DateTime.now().toUtc().toIso8601String(),
        "CompletedBy": completedBy,
        "CompletedByPhoneNumber": completedByPhone ?? "",
        "CompletedByEmail": completedByEmail ?? "",
        "CompletedByWhatsapp": completedByPhone ?? "",
        "PaymentStatus": paymentStatus ?? "Pending",
        "PaymentReference": paymentReference ?? "",
        "PaymentDate": paymentDate ?? DateTime.now().toUtc().toIso8601String(),
        "PaymentMethod": paymentMethod ?? "Online",
        "PaymentAmount": paymentAmount ?? "0",
        "Remarks": remarks ?? "",
      };

      final response = await http.post(
        uri,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(body),
      ).timeout(_defaultTimeout);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return {"success": true};
      }
      return {"success": false, "message": response.body};
    } catch (e) {
      return {"success": false, "message": e.toString()};
    }
  }
}