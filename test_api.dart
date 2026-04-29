import 'dart:convert';
import 'package:http/http.dart' as http;

Future<void> main() async {
  String baseUrl = 'https://prontobackend-bhdnbec2fvd3ecfk.eastus2-01.azurewebsites.net/api';
  
  // Get an open valuation in Backend
  final res = await http.get(Uri.parse('$baseUrl/valuations/workflows/open'));
  if (res.statusCode != 200) { print('Failed to get cases'); return; }
  
  List cases = jsonDecode(res.body);
  var beCase = cases.firstWhere((c) => (c['workflow'] ?? '').toString().toLowerCase().contains('backend'), orElse: () => null);
  
  if (beCase == null) {
      print('No Backend cases found.');
      return;
  }
  
  print('Found case: ${beCase['valuationId']} - ${beCase['vehicleNumber']}');
  
  String id = beCase['valuationId'];
  String vNo = beCase['vehicleNumber'];
  String contact = beCase['applicantContact'];
  int stepOrder = beCase['workflowStepOrder'];
  
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
      
      final tableUri = Uri.parse('$baseUrl/valuations/$id/workflow/Table');
      final body = {
          'ValuationId': id, 'valuationId': id,
          'VehicleNumber': vNo, 'vehicleNumber': vNo,
          'ApplicantContact': contact, 'applicantContact': contact,
          'WorkflowStepOrder': stepOrder+1, 'workflowStepOrder': stepOrder+1,
          'Workflow': 'AVO', 'workflow': 'AVO',
          'Status': 'InProgress', 'status': 'InProgress'
      };
      final tableRes = await http.put(tableUri, headers: {'Accept': 'application/json', 'Content-Type': 'application/json'}, body: jsonEncode(body));
      print('PUT table: ${tableRes.statusCode} ${tableRes.body}');
  } catch (e) {
      print('Exception: $e');
  }
}
