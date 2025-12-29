import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'auth_service.dart';
import 'api_config.dart';

class LCLService {
  final AuthService _authService = AuthService();

  Future<List<Map<String, dynamic>>?> getAllContainerNumbers() async {
    final token = await _authService.getValidToken();
    if (token == null) return null;

    final url = Uri.parse('$baseUrl/getContainerNumberLCL?token=$token');

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == true && data['data'] != null) {
          return (data['data']['item'] as List).cast<Map<String, dynamic>>();
        }
      }
      return null;
    } catch (e) {
      print('Error getting all container numbers: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> getLPBInfo(String numberLpb) async {
    final token = await _authService.getValidToken();
    if (token == null) return null;

    final url = Uri.parse(
      '$baseUrl/getLPBInfo?token=$token&number_lpb=$numberLpb',
    );

    print('Fetching LPB info for: $numberLpb');

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == true && data['items'] != null) {
          return data;
        }
        return null;
      } else {
        print('Error getting LPB Info: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Exception in getLPBInfo: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> getLPBInfoDetail(String numberLpbChild) async {
    final token = await _authService.getValidToken();
    if (token == null) return null;

    // Menggunakan baseUrl untuk membangun URL
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

  Future<List<Map<String, dynamic>>?> getAllItemSuggestions() async {
    final token = await _authService.getValidToken();
    if (token == null) return null;

    final url = Uri.parse('$baseUrl/getItemDetail?token=$token');

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == true && data['data'] != null) {
          return (data['data']['item'] as List).cast<Map<String, dynamic>>();
        }
      }
      return null;
    } catch (e) {
      print('Error getting all item suggestions: $e');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getTipeBarangList() async {
    final token = await _authService.getValidToken();
    if (token == null) return [];

    // Menggunakan baseUrl untuk membangun URL
    final url = Uri.parse('$baseUrl/getDetailTipeBarang?token=$token');

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == true && data['data'] != null) {
          // PASTIKAN selalu return list meski kosong
          return (data['data']['tipe_barang'] as List? ?? [])
              .cast<Map<String, dynamic>>();
        }
      }
      return []; // Return empty list jika error
    } catch (e) {
      print('Error getting item types: $e');
      return []; // Return empty list jika error
    }
  }

  Future<bool> saveLPBDetail({
    required List<String> number_lpb_items,
    required String weight,
    required String height,
    required String length,
    required String width,
    required String nama_barang,
    required String tipe_barang,
    String? barang_id,
    String? container_number,
    String? status,
    String? keterangan,
    File? foto_terima_barang,
    bool deleteExistingFoto = false,
  }) async {
    final token = await _authService.getValidToken();
    if (token == null) {
      print('Token is null!');
      return false;
    }

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/store_lpb_detail'),
    );

    final fields = {
      'token': token,
      'weight': weight.trim(),
      'height': height.trim(),
      'length': length.trim(),
      'width': width.trim(),
      'nama_barang': nama_barang.trim(),
      'tipe_barang': tipe_barang.trim(),
    };

    if (barang_id != null) {
      fields['barang_id'] = barang_id.trim();
    }
    if (container_number != null) {
      fields['container_number'] = container_number.trim();
    }
    if (status != null) {
      fields['status'] = status;
    }
    if (keterangan != null) {
      fields['keterangan'] = keterangan.trim();
    }
    if (deleteExistingFoto) {
      fields['foto_terima_barang'] = '';
    }

    request.fields.addAll(fields);

    for (String itemCode in number_lpb_items) {
      request.files.add(
        http.MultipartFile.fromString(
          'number_lpb_item[]', // <-- PLURAL 'items' + brackets
          itemCode.trim(),
        ),
      );
    }

    if (foto_terima_barang != null) {
      final fileStream = http.ByteStream(foto_terima_barang.openRead());
      final fileLength = await foto_terima_barang.length();

      final multipartFile = http.MultipartFile(
        'foto_terima_barang',
        fileStream,
        fileLength,
        filename: foto_terima_barang.path.split('/').last,
      );
      request.files.add(multipartFile);
    }

    print('Sending request with files: ${request.files}');
    print('Sending request with fields: ${request.fields}');
    if (foto_terima_barang != null) {
      print('Sending file: ${foto_terima_barang.path}');
    }

    try {
      final response = await request.send();
      final resBody = await response.stream.bytesToString();

      if (resBody.trim().startsWith('<!DOCTYPE') ||
          resBody.trim().startsWith('<div')) {
        print('Server returned HTML error: $resBody');
        return false;
      }

      final data = jsonDecode(resBody);

      if (response.statusCode == 401 ||
          (data['error'] == true && data['message'] == 'Token Not Found')) {
        final newToken = await _authService.softLoginRefresh();
        if (newToken != null) {
          return saveLPBDetail(
            number_lpb_items: number_lpb_items,
            weight: weight,
            height: height,
            length: length,
            width: width,
            nama_barang: nama_barang,
            tipe_barang: tipe_barang,
            barang_id: barang_id,
            container_number: container_number,
            status: status,
            keterangan: keterangan,
            foto_terima_barang: foto_terima_barang,
            deleteExistingFoto: deleteExistingFoto,
          );
        }
      }

      return response.statusCode == 200 && data['status'] == true;
    } catch (e) {
      print('Error saving LPB detail: $e');
      return false;
    }
  }

  Future<bool> updateNotification({
    required String ttNumber,
    required bool status,
  }) async {
    final token = await _authService.getValidToken();
    if (token == null) {
      print('updateNotification: Token is null!');
      return false;
    }

    final url = Uri.parse('$baseUrl/update_notification');

    print('updateNotification parameters:');
    print('tt_number: $ttNumber');
    print('status: $status');

    try {
      // Prepare the JSON body
      final Map<String, dynamic> requestBody = {
        'token': token,
        'tt_number': ttNumber.trim(),
        'status': status,
      };

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('updateNotification API response: $data');
        return data['status'] == true;
      }

      print(
        'updateNotification: Server responded with status code ${response.statusCode}',
      );
      print('Response body: ${response.body}');
      return false;
    } catch (e) {
      print('Error updating notification: $e');
      return false;
    }
  }

  Future<bool> updateStatusReadyToShip({
    required String numberLpbItem,
    required String containerNumber,
  }) async {
    final token = await _authService.getValidToken();
    if (token == null) {
      print('updateStatusReadyToShip: Token is null!');
      return false;
    }

    final url = Uri.parse('$baseUrl/update_status_ready_to_ship');

    print('updateStatusReadyToShip parameters:');
    print('numberLpbItem: $numberLpbItem');
    print('containerNumber: $containerNumber');

    try {
      final response = await http.post(
        url,
        body: {
          'token': token,
          'number_lpb_item': numberLpbItem.trim(),
          'container_id': containerNumber.trim(),
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('updateStatusReadyToShip API response: $data');
        return data['status'] == true;
      }
      print(
        'updateStatusReadyToShip: Server responded with status code ${response.statusCode}',
      );
      print('Response body: ${response.body}');
      return false;
    } catch (e) {
      print('Error updating status: $e');
      return false;
    }
  }

  Future<bool> updateStatusToWarehouse({required String numberLpbItem}) async {
    final token = await _authService.getValidToken();
    if (token == null) {
      print('updateStatusToWarehouse: Token is null!');
      return false;
    }

    final url = Uri.parse(
      '$baseUrl/update_status_item_from_container_to_warehouse',
    );

    print('updateStatusToWarehouse parameters:');
    print('numberLpbItem: $numberLpbItem');

    try {
      final response = await http.post(
        url,
        body: {'token': token, 'number_lpb_item': numberLpbItem.trim()},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('updateStatusToWarehouse API response: $data');
        return data['status'] == true;
      }
      print(
        'updateStatusToWarehouse: Server responded with status code ${response.statusCode}',
      );
      print('Response body: ${response.body}');
      return false;
    } catch (e) {
      print('Error updating status: $e');
      return false;
    }
  }

  Future<List<Map<String, dynamic>>?> getLPBHeaderAll() async {
    final token = await _authService.getValidToken();
    if (token == null) {
      print('getLPBHeaderAll: Token is null!');
      return null;
    }

    final url = Uri.parse('$baseUrl/getLPBHeaderAll?token=$token');

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == true && data['data'] != null) {
          return List<Map<String, dynamic>>.from(data['data']['item']);
        } else {
          print('API error: ${data['message']}');
        }
      } else if (response.statusCode == 401) {
        final newToken = await _authService.softLoginRefresh();
        if (newToken != null) {
          return getLPBHeaderAll();
        }
      }
      return null;
    } catch (e) {
      print('Error fetching LPB headers: $e');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>?> getLPBItemDetail(String numberLpb) async {
    final token = await _authService.getValidToken();
    if (token == null) {
      print('getLPBItemDetail: Token is null!');
      return null;
    }

    final url = Uri.parse(
      '$baseUrl/getLPBItem?token=$token&number_lpb=$numberLpb',
    );

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == true && data['data'] != null) {
          return List<Map<String, dynamic>>.from(data['data']['item']);
        } else {
          print('API error: ${data['message']}');
        }
      } else if (response.statusCode == 401) {
        final newToken = await _authService.softLoginRefresh();
        if (newToken != null) {
          return getLPBItemDetail(numberLpb);
        }
      }
      return null;
    } catch (e) {
      print('Error fetching LPB item details: $e');
      return null;
    }
  }
}
