import 'package:http/http.dart' as http;

Future<void> main() async {
  String baseUrl = 'https://prontobackend-bhdnbec2fvd3ecfk.eastus2-01.azurewebsites.net/api';
  
  String id = '0bdf496e-94f2-4f56-8d0b-e7abec98d2a2';
  String vNo = 'ap03uh1393';
  String contact = '7842429322';
  
  final uri = Uri.parse('$baseUrl/valuations/$id/vehicledetails').replace(queryParameters: {"vehicleNumber": vNo, "applicantContact": contact});
  var request = http.MultipartRequest('PUT', uri);
  request.fields['ValuationId'] = id;
  request.fields['VehicleNumber'] = vNo;
  request.fields['ApplicantContact'] = contact;
  request.fields['RedFlag'] = 'Test';
  request.fields['Remarks'] = 'Test';
  
  final streamedResponse = await request.send();
  final response = await http.Response.fromStream(streamedResponse);
  print('PUT vehicle details: ' + response.statusCode.toString());
  print('Error body: ' + response.body);
}
