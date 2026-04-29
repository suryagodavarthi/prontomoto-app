import 'package:http/http.dart' as http;

Future<void> main() async {
  String baseUrl = 'https://prontobackend-bhdnbec2fvd3ecfk.eastus2-01.azurewebsites.net/api';
  
  String id = '0bdf496e-94f2-4f56-8d0b-e7abec98d2a2';
  String vNo = 'ap03uh1393';
  String contact = '7842429322';
  
  final uri = Uri.parse('$baseUrl/valuations/$id/vehicledetails/assignment').replace(queryParameters: {
    "vehicleNumber": vNo, 
    "applicantContact": contact,
    "assignedTo": "SHEKHAR (AVO)"
  });
  final res = await http.post(uri, headers: {"Content-Type": "application/json"});
  print('POST assignment: ' + res.statusCode.toString());
  print('Error body: ' + res.body);
}
