import 'dart:convert';
import 'package:http/http.dart' as http;

Future<void> main() async {
  String baseUrl = 'https://prontobackend-bhdnbec2fvd3ecfk.eastus2-01.azurewebsites.net/api';
  
  final res = await http.get(Uri.parse('$baseUrl/valuations/workflows/open'));
  List cases = jsonDecode(res.body);
  
  var c1 = cases.firstWhere((c) => c['vehicleNumber'] == 'ap03uh1393', orElse: () => null);
  var c2 = cases.firstWhere((c) => c['vehicleNumber'] == 'TS34F8267', orElse: () => null);
  
  print('Failing Case:');
  print(jsonEncode(c1));
  print('Succeeding Case:');
  print(jsonEncode(c2));
}
