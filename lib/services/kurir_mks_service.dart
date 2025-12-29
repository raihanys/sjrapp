import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'auth_service.dart';
import 'api_config.dart';

class KurirMksService {
  final AuthService _authService = AuthService();

  Future<Map<String, dynamic>?> getLPBInfo(String numberLpb) async {
    final token = await _authService.getValidToken();
    if (token == null) return null;

    final url = Uri.parse(
      '$baseUrl/getLPBInfo?token=$token&number_lpb=$numberLpb',
    );

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == true) {
          return data;
        }
        return null;
      }
      return null;
    } catch (e) {
      print('Error getLPBInfo: $e');
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

  Future<bool> submitDelivery({
    required List<String> itemCodes,
    required File fotoSuratJalan,
  }) async {
    final token = await _authService.getValidToken();
    if (token == null) return false;

    final url = Uri.parse('$baseUrl/update_lpb_partial_shipping');

    final request = http.MultipartRequest('POST', url);

    request.fields['token'] = token;

    for (String code in itemCodes) {
      request.files.add(
        http.MultipartFile.fromString(
          'number_lpb_item[]', // <-- PLURAL 'items' + brackets
          code.trim(),
        ),
      );
    }
    final fileStream = http.ByteStream(fotoSuratJalan.openRead());
    final fileLength = await fotoSuratJalan.length();

    final multipartFile = http.MultipartFile(
      'bukti_pengiriman',
      fileStream,
      fileLength,
      filename: fotoSuratJalan.path.split('/').last,
    );
    request.files.add(multipartFile);

    try {
      // 🕵️ DEBUG LOGS: Apa yang dikirim?
      print('--- DEBUG SUBMIT DELIVERY REQUEST ---');
      print('Request URL: $url');
      print(
        'Fields yang dikirim: ${request.fields.map((k, v) => MapEntry(k, v))}',
      );
      print('Files yang dikirim: ${request.files.map((f) => f.filename)}');
      print('-------------------------------------');

      final response = await request.send();
      final resBody = await response.stream.bytesToString();

      // 🕵️ DEBUG LOGS: Respon Server
      print('--- DEBUG SUBMIT DELIVERY RESPONSE ---');
      print('HTTP Status Code: ${response.statusCode}');
      print('Response Body: $resBody');
      print('--------------------------------------');

      // Pengecekan status
      if (response.statusCode == 200) {
        final data = jsonDecode(resBody);
        return data['status'] == true;
      }

      // Jika Status Code BUKAN 200 (seperti 404 yang Anda temui)
      return false;
    } catch (e) {
      print(
        '❌ Error submitDelivery: Gagal decode JSON atau error jaringan. $e',
      );
      return false;
    }
  }
}
