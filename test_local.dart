import 'dart:convert';
import 'package:http/http.dart' as http;

Future<void> main() async {
  String baseUrl = 'http://localhost:5037/api'; // Localport
  
  String id = '0bdf496e-94f2-4f56-8d0b-e7abec98d2a2';
  String vNo = 'ap03uh1393';
  String contact = '7842429322';
  
  final compUri = Uri.parse('$baseUrl/valuations/$id/workflow/2/complete').replace(queryParameters: {'vehicleNumber': vNo, 'applicantContact': contact});
  final compRes = await http.post(compUri, headers: {'Accept': 'application/json', 'Content-Type': 'application/json'}, body: '{}');
  print('POST complete: ' + compRes.statusCode.toString());
  print('Error body: ' + compRes.body);
}
