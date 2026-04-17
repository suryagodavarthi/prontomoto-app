import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

class ApiService {
  final String baseUrl = "https://prontobackend-bhdnbec2fvd3ecfk.eastus2-01.azurewebsites.net/api";

  // ===========================================================================
  // 1. AUTHENTICATION
  // ===========================================================================
  Future<Map<String, dynamic>> loginUser(String inputPhone) async {
    try {
      final allUsersUrl = Uri.parse('$baseUrl/users/all');
      final response = await http.get(allUsersUrl);
      if (response.statusCode == 200) {
        List<dynamic> allUsers = jsonDecode(response.body);
        var user = allUsers.firstWhere(
            (u) => u['phoneNumber'].toString().contains(inputPhone),
            orElse: () => null);
        
        if (user != null) {
          String fetchedRole = user['role']?.toString() ?? "User"; 
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
  // 2. DASHBOARD & WORKFLOW
  // ===========================================================================
  Future<List<dynamic>> getOpenValuations() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/valuations/workflows/open'));
      return response.statusCode == 200 ? jsonDecode(response.body) : [];
    } catch (e) { return []; }
  }

  Future<Map<String, dynamic>> _workflowAction(String id, int stepOrder, String vehicleNo, String contact, String action) async {
    if (vehicleNo.trim().isEmpty || contact.trim().isEmpty) {
      return {"success": false, "message": "App Error: Missing Vehicle Number or Applicant Contact."};
    }

    try {
      final uri = Uri.parse('$baseUrl/valuations/$id/workflow/$stepOrder/$action').replace(
        queryParameters: {
          "vehicleNumber": vehicleNo.trim(), 
          "applicantContact": contact.trim()
        }
      );
      
      final response = await http.post(
        uri,
        headers: {
          "Accept": "application/json",
          "Content-Type": "application/json" 
        },
        body: jsonEncode({
          "vehicleNumber": vehicleNo.trim(),
          "applicantContact": contact.trim(),
          "VehicleNumber": vehicleNo.trim(),
          "ApplicantContact": contact.trim()
        }),
      );
      
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return {"success": true};
      }
      return {"success": false, "message": "Code ${response.statusCode}: ${response.body}"};
    } catch (e) {
      return {"success": false, "message": e.toString()};
    }
  }

  Future<Map<String, dynamic>> startInitialWorkflow(String id, String vehicleNo, String contact) async {
    return await _workflowAction(id, 1, vehicleNo, contact, 'start');
  }

  Future<Map<String, dynamic>> advanceToNextStage(String id, int currentStepOrder, String vehicleNo, String contact) async {
    // 1. Complete Current Step
    var completeRes = await _workflowAction(id, currentStepOrder, vehicleNo, contact, 'complete');
    if (completeRes['success'] != true) return completeRes;

    // 2. Start Next Step
    int nextStepOrder = currentStepOrder + 1;
    var startRes = await _workflowAction(id, nextStepOrder, vehicleNo, contact, 'start');
    if (startRes['success'] != true) return startRes;

    // 3. Update the Table Storage so Dashboards properly filter the case
    String nextStepName = "Backend";
    if (nextStepOrder == 3) nextStepName = "AVO";
    if (nextStepOrder == 4) nextStepName = "QualityControl";
    if (nextStepOrder == 5) nextStepName = "FinalReport";

    try {
      final uri = Uri.parse('$baseUrl/workflows/$id');
      await http.put(
        uri,
        headers: {"Accept": "application/json", "Content-Type": "application/json"},
        body: jsonEncode({
          "ValuationId": id,
          "VehicleNumber": vehicleNo.trim(),
          "ApplicantContact": contact.trim(),
          "WorkflowStepOrder": nextStepOrder,
          "Workflow": nextStepName,
          "Status": "InProgress"
        }),
      );
    } catch (e) {
      print("Table update failed: $e");
    }

    return {"success": true};
  }

  Future<Map<String, dynamic>> rejectToPreviousStage(String id, int currentStepOrder, String vehicleNo, String contact) async {
    if (vehicleNo.trim().isEmpty) vehicleNo = "UNKNOWN";
    if (contact.trim().isEmpty) contact = "0000000000";

    String currentStepName = currentStepOrder == 3 ? "AVO" : "Backend";
    String targetStep = currentStepOrder == 3 ? "Backend" : "Stakeholder";

    try {
      final uri = Uri.parse('$baseUrl/valuations/$id/workflow/return');
      final response = await http.post(
        uri,
        headers: {"Accept": "application/json", "Content-Type": "application/json"},
        body: jsonEncode({
          "ValuationId": id,
          "VehicleNumber": vehicleNo.trim(),
          "ApplicantContact": contact.trim(),
          "CurrentStep": currentStepName,
          "TargetReturnStep": targetStep,
          "ReturnReason": "Rejected from Mobile App",
        })
      );
      if (response.statusCode >= 200 && response.statusCode < 300) return {"success": true};
      return {"success": false, "message": "Code ${response.statusCode}: ${response.body}"};
    } catch (e) {
      return {"success": false, "message": e.toString()};
    }
  }

  // ===========================================================================
  // 3. STAKEHOLDER (FILES & GENERAL DATA)
  // ===========================================================================
  Future<Map<String, dynamic>> createValuation(Map<String, String> formData, {String? rcPath, String? insurancePath, String? otherPath}) async {
    var uuid = const Uuid();
    String newId = uuid.v4(); 
    final url = Uri.parse('$baseUrl/valuations/$newId/stakeholder'); 
    try {
      var request = http.MultipartRequest('PUT', url);
      request.fields.addAll(formData);
      
      request.fields['ValuationId'] = newId;
      request.fields['valuationId'] = newId;
      
      if (rcPath != null) request.files.add(await http.MultipartFile.fromPath('rcFile', rcPath));
      if (insurancePath != null) request.files.add(await http.MultipartFile.fromPath('insuranceFile', insurancePath));
      if (otherPath != null) request.files.add(await http.MultipartFile.fromPath('otherFiles', otherPath));
      
      var response = await http.Response.fromStream(await request.send());
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return {"success": true, "message": "Request Created Successfully!", "id": newId};
      }
      return {"success": false, "message": "Server Error: ${response.body}"};
    } catch (e) {
      return {"success": false, "message": "Connection Error: $e"};
    }
  }

  Future<Map<String, dynamic>> updateValuation(String id, Map<String, String> formData, {String? rcPath, String? insurancePath, String? otherPath}) async {
    final url = Uri.parse('$baseUrl/valuations/$id/stakeholder');
    try {
        var request = http.MultipartRequest('PUT', url);
        request.fields.addAll(formData);
        
        request.fields['ValuationId'] = id;
        request.fields['valuationId'] = id;
        
        if (rcPath != null) request.files.add(await http.MultipartFile.fromPath('rcFile', rcPath));
        if (insurancePath != null) request.files.add(await http.MultipartFile.fromPath('insuranceFile', insurancePath));
        if (otherPath != null) request.files.add(await http.MultipartFile.fromPath('otherFiles', otherPath));
        
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

    final uri = Uri.parse('$baseUrl/valuations/$id/stakeholder').replace(queryParameters: {"vehicleNumber": vehicleNo.trim(), "applicantContact": contact.trim()});
    try {
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        var decoded = jsonDecode(response.body);
        if (decoded is List && decoded.isNotEmpty) return Map<String, dynamic>.from(decoded[0]).map((k, v) => MapEntry(k.toLowerCase(), v));
        else if (decoded is Map<String, dynamic>) return decoded.map((k, v) => MapEntry(k.toLowerCase(), v));
      }
      return {};
    } catch (e) { return {}; }
  }

  // ===========================================================================
  // 4. BACKEND VEHICLE DETAILS
  // ===========================================================================
  Future<Map<String, dynamic>> getBackendVehicleDetails(String id, String vNo, String contact) async {
    Map<String, dynamic> data = {};
    Map<String, dynamic> normalize(Map<String, dynamic> d) => d.map((k, v) => MapEntry(k.toLowerCase(), v));

    if (vNo.trim().isEmpty) vNo = "UNKNOWN";
    if (contact.trim().isEmpty) contact = "0000000000";

    try {
      final rcRes = await http.get(Uri.parse('$baseUrl/valuations/$id/vehicledetails/with-rc').replace(queryParameters: {"vehicleNumber": vNo.trim(), "applicantContact": contact.trim()}));
      if (rcRes.statusCode == 200) data.addAll(normalize(jsonDecode(rcRes.body)));
    } catch (e) {}

    try {
      final savedRes = await http.get(Uri.parse('$baseUrl/valuations/$id/vehicledetails').replace(queryParameters: {"vehicleNumber": vNo.trim(), "applicantContact": contact.trim()}));
      if (savedRes.statusCode == 200) {
        var saved = normalize(jsonDecode(savedRes.body));
        saved.forEach((k, v) { if (v != null && v.toString() != "null") data[k] = v; });
      }
    } catch (e) {}
    return data;
  }

  Future<Map<String, dynamic>> updateBackendVehicleDetails(String id, String vNo, String contact, Map<String, dynamic> data) async {
    if (vNo.trim().isEmpty) vNo = "UNKNOWN";
    if (contact.trim().isEmpty) contact = "0000000000";

    try {
      final uri = Uri.parse('$baseUrl/valuations/$id/vehicledetails').replace(queryParameters: {"vehicleNumber": vNo.trim(), "applicantContact": contact.trim()});
      
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
    } catch (e) { return {"success": false, "message": "Error: $e"}; }
  }

  Future<bool> assignBackendTask(String id, String vNo, String contact, String assigneeName) async {
    if (vNo.trim().isEmpty) vNo = "UNKNOWN";
    if (contact.trim().isEmpty) contact = "0000000000";

    try {
      final uri = Uri.parse('$baseUrl/valuations/$id/vehicledetails/assignment').replace(queryParameters: {"vehicleNumber": vNo.trim(), "applicantContact": contact.trim()});
      final response = await http.post(
        uri, 
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(assigneeName) 
      );
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (e) { return false; }
  }

  // ===========================================================================
  // 5. INSPECTION DETAILS
  // ===========================================================================
  Future<Map<String, dynamic>> getInspectionDetails(String id, String vNo, String contact) async {
    if (vNo.trim().isEmpty) vNo = "UNKNOWN";
    if (contact.trim().isEmpty) contact = "0000000000";

    try {
      final response = await http.get(Uri.parse('$baseUrl/valuations/$id/inspection').replace(queryParameters: {"vehicleNumber": vNo.trim(), "applicantContact": contact.trim()}));
      if (response.statusCode == 200) {
        return (jsonDecode(response.body) as Map<String, dynamic>).map((k, v) => MapEntry(k.toLowerCase(), v));
      }
      return {};
    } catch (e) { return {}; }
  }

  Future<Map<String, dynamic>> updateInspectionDetails(String id, String vNo, String contact, Map<String, dynamic> data) async {
    if (vNo.trim().isEmpty) vNo = "UNKNOWN";
    if (contact.trim().isEmpty) contact = "0000000000";

    try {
      var request = http.MultipartRequest('PUT', Uri.parse('$baseUrl/valuations/$id/inspection').replace(queryParameters: {"vehicleNumber": vNo.trim(), "applicantContact": contact.trim()}));
      data.forEach((k, v) { if (v != null) request.fields[k] = v.toString(); });
      var response = await http.Response.fromStream(await request.send());
      if (response.statusCode >= 200 && response.statusCode < 300) return {"success": true, "message": "Saved!"};
      return {"success": false, "message": "Inspection Save Failed: ${response.body}"};
    } catch (e) { return {"success": false, "message": "Error: $e"}; }
  }

  // ===========================================================================
  // 6. NOTES
  // ===========================================================================
  Future<bool> addNote(String valuationId, String noteText) async {
    try {
      final response = await http.post(Uri.parse('$baseUrl/CommonNote'), headers: {"Content-Type": "application/json"}, body: jsonEncode({"entityType": "Valuation", "entityId": valuationId, "note": noteText, "createdBy": "System"}));
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (e) { return false; }
  }

  Future<List<dynamic>> getNotes(String valuationId) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/CommonNote/entity/Valuation/$valuationId'));
      if (response.statusCode == 200) return jsonDecode(response.body);
      return [];
    } catch (e) { return []; }
  }
}