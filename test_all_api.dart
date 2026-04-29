import 'dart:convert';
import 'package:http/http.dart' as http;

Future<void> main() async {
  String baseUrl = 'https://prontobackend-bhdnbec2fvd3ecfk.eastus2-01.azurewebsites.net/api';
  
  final res = await http.get(Uri.parse('$baseUrl/valuations/workflows/open'));
  List cases = jsonDecode(res.body);
  var beCases = cases.where((c) => (c['workflow'] ?? '').toString().toLowerCase().contains('backend')).toList();
  
  print('Found ${beCases.length} Backend cases.');
  
  for (var beCase in beCases) {
      String id = beCase['valuationId'];
      String vNo = beCase['vehicleNumber'];
      String contact = beCase['applicantContact'];
      int stepOrder = beCase['workflowStepOrder'];
      
      print('Testing $id - $vNo');
      
      final compUri = Uri.parse('$baseUrl/valuations/$id/workflow/$stepOrder/complete').replace(queryParameters: {'vehicleNumber': vNo, 'applicantContact': contact});
      final compRes = await http.post(compUri, headers: {'Accept': 'application/json', 'Content-Type': 'application/json'}, body: '{}');
      print('  POST complete: ' + compRes.statusCode.toString());
      if (compRes.statusCode >= 400) print('    Error: ' + compRes.body);
  }
}
