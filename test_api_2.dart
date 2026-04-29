import 'dart:convert';
import 'package:http/http.dart' as http;

Future<void> main() async {
  String baseUrl = 'https://prontobackend-bhdnbec2fvd3ecfk.eastus2-01.azurewebsites.net/api';
  
  final res = await http.get(Uri.parse('$baseUrl/valuations/workflows/open'));
  if (res.statusCode != 200) { print('Failed to get cases'); return; }
  
  List cases = jsonDecode(res.body);
  var beCase = cases.firstWhere((c) => (c['workflow'] ?? '').toString().toLowerCase().contains('backend'), orElse: () => null);
  
  if (beCase == null) {
      print('No Backend cases found.');
      return;
  }
  
  String id = beCase['valuationId'];
  String vNo = beCase['vehicleNumber'];
  String contact = beCase['applicantContact'];
  int stepOrder = beCase['workflowStepOrder'];
  
  print('Testing on $id, step $stepOrder');
  
  final tableUri = Uri.parse('$baseUrl/valuations/$id/workflow/Table');
  Map<String, dynamic> tableBody = {
      'ValuationId': id, 'valuationId': id,
      'VehicleNumber': vNo, 'vehicleNumber': vNo,
      'ApplicantContact': contact, 'applicantContact': contact,
      'WorkflowStepOrder': stepOrder+1, 'workflowStepOrder': stepOrder+1,
      'Workflow': 'AVO', 'workflow': 'AVO',
      'Status': 'InProgress', 'status': 'InProgress'
  };
  
  String assignee = 'SHEKHAR (AVO)';
  tableBody['AssignedTo'] = assignee; tableBody['assignedTo'] = assignee;
  tableBody['AVOAssignedTo'] = assignee; tableBody['avoAssignedTo'] = assignee;
  
  final tableRes = await http.put(tableUri, headers: {'Accept': 'application/json', 'Content-Type': 'application/json'}, body: jsonEncode(tableBody));
  print('PUT table: ' + tableRes.statusCode.toString() + ' ' + tableRes.body);
}
