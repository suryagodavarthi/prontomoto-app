import 'dart:convert';
import 'package:http/http.dart' as http;

Future<void> main() async {
  String baseUrl = 'https://prontobackend-bhdnbec2fvd3ecfk.eastus2-01.azurewebsites.net/api';
  
  String id = '0bdf496e-94f2-4f56-8d0b-e7abec98d2a2';
  String vNo = 'ap03uh1393';
  String contact = '7842429322';
  
  final stepsUri = Uri.parse('$baseUrl/valuations/$id/workflow').replace(queryParameters: {'vehicleNumber': vNo, 'applicantContact': contact});
  final stepsRes = await http.get(stepsUri, headers: {'Accept': 'application/json'});
  print('Steps for ap03uh1393: ' + stepsRes.body);
  
  String id2 = 'f259a072-934f-4e21-a740-6a3306ebe27c';
  String vNo2 = 'ap05hi9023';
  String contact2 = '8309192997'; // I'll get the real contact using Table API
  
  final res = await http.get(Uri.parse('$baseUrl/valuations/workflows/open'));
  List cases = jsonDecode(res.body);
  var c2 = cases.firstWhere((c) => c['valuationId'] == id2);
  contact2 = c2['applicantContact'];
  
  final stepsUri2 = Uri.parse('$baseUrl/valuations/$id2/workflow').replace(queryParameters: {'vehicleNumber': vNo2, 'applicantContact': contact2});
  final stepsRes2 = await http.get(stepsUri2, headers: {'Accept': 'application/json'});
  print('Steps for ap05hi9023: ' + stepsRes2.body);
}
