import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';
import 'api_config.dart';

class WarehouseMksService {
  final AuthService _authService = AuthService();

  Future<Map<String, dynamic>?> getContainers() async {
    final token = await _authService.getValidToken();
    if (token == null) return null;

    final url = Uri.parse(
      '$baseUrl/getContainerShippingAndReceived?token=$token',
    );

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      print('Error getting containers: $e');
      return null;
    }
  }

  Future<bool> updateContainerStatus(String containerId) async {
    final token = await _authService.getValidToken();
    if (token == null) return false;

    final url = Uri.parse('$baseUrl/update_status_container_to_received');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'token': token,
          'data': {'container_id': containerId},
        }),
      );

      return response.statusCode == 200 &&
          jsonDecode(response.body)['status'] == true;
    } catch (e) {
      print('Error updating container status: $e');
      return false;
    }
  }

  // Future<Map<String, dynamic>?> getContainersToClose() async {
  //   final token = await _authService.getValidToken();
  //   if (token == null) return null;

  //   final url = Uri.parse('$baseUrl/getContainerToClose?token=$token');

  //   try {
  //     final response = await http.get(url);
  //     if (response.statusCode == 200) {
  //       return jsonDecode(response.body);
  //     }
  //     return null;
  //   } catch (e) {
  //     print('Error getting containers to close: $e');
  //     return null;
  //   }
  // }

  // Future<bool> updateContainerToClose(String containerId) async {
  //   final token = await _authService.getValidToken();
  //   if (token == null) return false;

  //   final url = Uri.parse('$baseUrl/update_status_container_to_close');

  //   try {
  //     final response = await http.post(
  //       url,
  //       headers: {'Content-Type': 'application/json'},
  //       body: jsonEncode({
  //         'token': token,
  //         'data': {'container_id': containerId},
  //       }),
  //     );

  //     return response.statusCode == 200 &&
  //         jsonDecode(response.body)['status'] == true;
  //   } catch (e) {
  //     print('Error updating container to close: $e');
  //     return false;
  //   }
  // }
}
