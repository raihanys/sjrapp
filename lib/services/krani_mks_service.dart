import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';
import 'api_config.dart';

class KraniMksService {
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

  Future<Map<String, dynamic>?> getLPBInfoDetail(String numberLpbChild) async {
    final token = await _authService.getValidToken();
    if (token == null) return null;

    final url = Uri.parse(
      '$baseUrl/getLPBInfoDetail?token=$token&number_lpb_child=$numberLpbChild',
    );

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  String getImageUrl(String imagePath) {
    if (imagePath.isEmpty) return '';
    String base = baseUrl.replaceAll('/index.php/api', '');
    return '$base/uploads/terima_barang/$imagePath';
  }

  Future<bool> updateItemStatus(
    String numberLpbItem, {
    String? statusKondisiBarang,
    String? keteranganKondisiBarang,
    File? fotoTerimaBarang,
  }) async {
    final token = await _authService.getValidToken();
    if (token == null) {
      print("❌ Token null");
      return false;
    }

    final url = Uri.parse('$baseUrl/update_status_item_to_received');

    try {
      if (fotoTerimaBarang != null) {
        // 📸 Multipart request (ada foto)
        var request = http.MultipartRequest('POST', url);

        // Fields
        request.fields['token'] = token;
        request.fields['number_lpb_item'] = numberLpbItem;
        if (statusKondisiBarang != null) {
          request.fields['status_kondisi_barang'] = statusKondisiBarang;
        }
        if (keteranganKondisiBarang != null) {
          request.fields['keterangan_kondisi_barang'] = keteranganKondisiBarang;
        }

        // File
        var fileStream = http.ByteStream(
          Stream.castFrom(fotoTerimaBarang.openRead()),
        );
        var fileLength = await fotoTerimaBarang.length();
        var multipartFile = http.MultipartFile(
          'foto_terima_barang',
          fileStream,
          fileLength,
          filename: 'foto_${DateTime.now().millisecondsSinceEpoch}.jpg',
        );
        request.files.add(multipartFile);

        print("==== DEBUG MULTIPART UPDATE ITEM ====");
        print("URL: $url");
        print("Fields: ${request.fields}");
        print("=====================================");

        var response = await request.send();
        var responseString = await response.stream.bytesToString();

        print("Response Code: ${response.statusCode}");
        print("Response Body: $responseString");

        // ✅ FIX: Handle response yang mengandung HTML error + JSON
        return _handleResponse(responseString, response.statusCode);
      } else {
        // 🔹 FORM DATA request (tanpa foto)
        Map<String, String> body = {
          'token': token,
          'number_lpb_item': numberLpbItem,
        };

        if (statusKondisiBarang != null) {
          body['status_kondisi_barang'] = statusKondisiBarang;
        }
        if (keteranganKondisiBarang != null) {
          body['keterangan_kondisi_barang'] = keteranganKondisiBarang;
        }

        print("==== DEBUG FORM DATA UPDATE ITEM ====");
        print("URL: $url");
        print("Body: $body");
        print("================================");

        final response = await http.post(url, body: body);

        print("Response Code: ${response.statusCode}");
        print("Response Body: ${response.body}");

        // ✅ FIX: Handle response yang mengandung HTML error + JSON
        return _handleResponse(response.body, response.statusCode);
      }
    } catch (e) {
      print('❌ Error updating item status: $e');
      return false;
    }
  }

  // ✅ NEW METHOD: Handle response yang mengandung HTML + JSON
  bool _handleResponse(String responseBody, int statusCode) {
    try {
      // Coba langsung parse sebagai JSON
      final responseData = jsonDecode(responseBody);
      return statusCode == 200 && responseData['status'] == true;
    } catch (e) {
      // Jika gagal, coba ekstrak JSON dari response yang mengandung HTML
      try {
        // Cari bagian JSON dalam response (setelah HTML error)
        final jsonStart = responseBody.indexOf('{');
        final jsonEnd = responseBody.lastIndexOf('}');

        if (jsonStart != -1 && jsonEnd != -1 && jsonEnd > jsonStart) {
          final jsonString = responseBody.substring(jsonStart, jsonEnd + 1);
          final responseData = jsonDecode(jsonString);
          return statusCode == 200 && responseData['status'] == true;
        }

        // Jika tidak bisa ekstrak JSON, coba cari pesan success
        if (responseBody.contains('Successfully Update Data LPB to Received')) {
          return true;
        }

        return false;
      } catch (e2) {
        print('❌ Error parsing response: $e2');
        return false;
      }
    }
  }
}
