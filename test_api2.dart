import 'dart:convert';
import 'package:http/http.dart' as http;

Future<void> main() async {
  String baseUrl = 'https://prontobackend-bhdnbec2fvd3ecfk.eastus2-01.azurewebsites.net/api';
  
  String id = '90d46602-e4cb-4982-8998-744382a6b2d2';
  String vNo = 'CAR';
  String contact = '8500244673';
  int stepOrder = 2; // Test transitioning from Backend to AVO
  
  // Reset the case to Backend manually for testing
  final tableUri = Uri.parse('$baseUrl/valuations/$id/workflow/Table');
  final resetBody = {
      'ValuationId': id, 'valuationId': id,
      'VehicleNumber': vNo, 'vehicleNumber': vNo,
      'ApplicantContact': contact, 'applicantContact': contact,
      'WorkflowStepOrder': stepOrder, 'workflowStepOrder': stepOrder,
      'Workflow': 'Backend', 'workflow': 'Backend',
      'Status': 'InProgress', 'status': 'InProgress'
  };
  await http.put(tableUri, headers: {'Accept': 'application/json', 'Content-Type': 'application/json'}, body: jsonEncode(resetBody));
  
  // Simulate advanceToNextStage
  try {
      final stepsUri = Uri.parse('$baseUrl/valuations/$id/workflow').replace(queryParameters: {'vehicleNumber': vNo, 'applicantContact': contact});
      final stepsRes = await http.get(stepsUri, headers: {'Accept': 'application/json'});
      print('GET steps: ${stepsRes.statusCode} ${stepsRes.body}');
      
      final compUri = Uri.parse('$baseUrl/valuations/$id/workflow/$stepOrder/complete').replace(queryParameters: {'vehicleNumber': vNo, 'applicantContact': contact});
      final compRes = await http.post(compUri, headers: {'Accept': 'application/json', 'Content-Type': 'application/json'}, body: '{}');
      print('POST complete: ${compRes.statusCode} ${compRes.body}');
      
      final startUri = Uri.parse('$baseUrl/valuations/$id/workflow/${stepOrder+1}/start').replace(queryParameters: {'vehicleNumber': vNo, 'applicantContact': contact});
      final startRes = await http.post(startUri, headers: {'Accept': 'application/json', 'Content-Type': 'application/json'}, body: '{}');
      print('POST start: ${startRes.statusCode} ${startRes.body}');
      
      final body = {
          'ValuationId': id, 'valuationId': id,
          'VehicleNumber': vNo, 'vehicleNumber': vNo,
          'ApplicantContact': contact, 'applicantContact': contact,
          'WorkflowStepOrder': stepOrder+1, 'workflowStepOrder': stepOrder+1,
          'Workflow': 'AVO', 'workflow': 'AVO',
          'Status': 'InProgress', 'status': 'InProgress',
          'AssignedTo': 'SHEKHAR (AVO)', 'assignedTo': 'SHEKHAR (AVO)',
          'AVOAssignedTo': 'SHEKHAR (AVO)', 'avoAssignedTo': 'SHEKHAR (AVO)'
      };
      final tableRes = await http.put(tableUri, headers: {'Accept': 'application/json', 'Content-Type': 'application/json'}, body: jsonEncode(body));
      print('PUT table: ${tableRes.statusCode} ${tableRes.body}');
  } catch (e) {
      print('Exception: $e');
  }
}
