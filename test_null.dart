import 'dart:convert';
import 'package:http/http.dart' as http;

Future<void> main() async {
  String baseUrl = 'https://prontobackend-bhdnbec2fvd3ecfk.eastus2-01.azurewebsites.net/api';
  
  String id = '0bdf496e-94f2-4f56-8d0b-e7abec98d2a2';
  String vNo = 'ap03uh1393';
  String contact = '9491636906'; // Need to guess contact from the open valuations list
  
  final res = await http.get(Uri.parse('$baseUrl/valuations/workflows/open'));
  List cases = jsonDecode(res.body);
  var beCase = cases.firstWhere((c) => c['valuationId'] == id);
  contact = beCase['applicantContact'];
  
  final stepsUri = Uri.parse('$baseUrl/valuations/$id/workflow').replace(queryParameters: {'vehicleNumber': vNo, 'applicantContact': contact});
  final stepsRes = await http.get(stepsUri, headers: {'Accept': 'application/json'});
  print('GET steps: ' + stepsRes.statusCode.toString() + ' ' + stepsRes.body);
}
