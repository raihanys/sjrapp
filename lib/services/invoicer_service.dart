import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'auth_service.dart';
import 'api_config.dart';

class InvoicerService {
  final AuthService authService;

  InvoicerService(this.authService);

  Future<http.Response> _handleRequest(
    Future<http.Response> Function(String token) requestFunction,
  ) async {
    String? token = await authService.getValidToken();
    if (token == null) throw Exception('Token not available');

    var response = await requestFunction(token);

    if (response.statusCode == 401) {
      print("Token expired, attempting to refresh...");
      final newToken = await authService.softLoginRefresh();
      if (newToken != null) {
        print("Token refreshed successfully. Retrying request...");
        response = await requestFunction(newToken);
      } else {
        throw Exception('Failed to refresh token. Please log in again.');
      }
    }

    return response;
  }

  Future<List<dynamic>> fetchInvoices(String typeInvoice) async {
    try {
      final response = await _handleRequest((token) {
        final uri = Uri.parse('$baseUrl/getInvoiceAll').replace(
          queryParameters: {'token': token, 'type_invoice': typeInvoice},
        );
        return http
            .get(uri, headers: {'Content-Type': 'application/json'})
            .timeout(const Duration(seconds: 15));
      });

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Handle berbagai format response
        if (data['status'] == true || data['error'] == false) {
          // Jika data ada dan tidak kosong
          if (data['data'] != null) {
            if (data['data'] is List) {
              return data['data'];
            } else {
              return [];
            }
          } else {
            return [];
          }
        } else {
          return [];
        }
      } else if (response.statusCode == 404) {
        print('Endpoint not found (404), returning empty list');
        return [];
      } else {
        throw Exception('HTTP error: ${response.statusCode}');
      }
    } catch (e) {
      if (e.toString().contains('timed out') ||
          e.toString().contains('Connection') ||
          e.toString().contains('404')) {
        print('Network error, returning empty list: $e');
        return [];
      }
      print('Error fetching invoices: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> fetchInvoiceDetail(String invoiceId) async {
    try {
      final response = await _handleRequest((token) {
        // UBAH INI: dari POST ke GET dengan query parameters
        final uri = Uri.parse(
          '$baseUrl/getInvoiceDetail',
        ).replace(queryParameters: {'token': token, 'invoice_id': invoiceId});
        return http
            .get(uri, headers: {'Content-Type': 'application/json'})
            .timeout(const Duration(seconds: 15));
      });

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == true && data['data'] != null) {
          return data['data'];
        } else {
          throw Exception('Failed to fetch invoice detail: ${data['message']}');
        }
      } else {
        throw Exception('HTTP error: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching invoice detail: $e');
      rethrow;
    }
  }

  Future<bool> updateInvoiceStatus({
    required String invoiceId,
    required String paymentType,
    String? paymentAmount,
    String? paymentDifference,
    String? paymentNotes,
    File? buktiPembayaranInvoice,
    String? bankId,
  }) async {
    final token = await authService.getValidToken();
    if (token == null) {
      print('Token is null!');
      return false;
    }

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/update_status_invoice'),
    );

    Map<String, String> fields = {
      'token': token,
      'invoice_id': invoiceId,
      'payment_type': paymentType,
    };

    if (paymentAmount != null) {
      fields['payment_amount'] = paymentAmount.replaceAll('.', '');
    }
    if (paymentDifference != null) {
      fields['is_diff'] = paymentDifference;
    }
    if (paymentNotes != null && paymentNotes.isNotEmpty) {
      fields['notes'] = paymentNotes;
    }
    if (bankId != null) {
      fields['bank_id'] = bankId;
    }

    request.fields.addAll(fields);

    // Menambahkan file jika ada
    if (buktiPembayaranInvoice != null) {
      request.files.add(
        await http.MultipartFile.fromPath(
          'bukti_pembayaran_invoice',
          buktiPembayaranInvoice.path,
          filename: buktiPembayaranInvoice.path.split('/').last,
        ),
      );
    }

    print('Sending Invoice update with fields: ${request.fields}');
    if (buktiPembayaranInvoice != null) {
      print('Sending Invoice file: ${buktiPembayaranInvoice.path}');
    }

    try {
      final response = await request.send();
      final resBody = await response.stream.bytesToString();
      final data = jsonDecode(resBody);

      if (response.statusCode == 401 ||
          (data['error'] == true && data['message'] == 'Token Not Found')) {
        final newToken = await authService.softLoginRefresh();
        if (newToken != null) {
          // Coba lagi dengan token baru
          return updateInvoiceStatus(
            invoiceId: invoiceId,
            paymentType: paymentType,
            paymentAmount: paymentAmount,
            paymentDifference: paymentDifference,
            paymentNotes: paymentNotes,
            buktiPembayaranInvoice: buktiPembayaranInvoice,
            bankId: bankId,
          );
        }
      }

      return response.statusCode == 200 && data['status'] == true;
    } catch (e) {
      print('Error updating invoice status: $e');
      rethrow;
    }
  }

  Future<List<dynamic>> fetchCSTAll(String typeInvoice) async {
    try {
      final response = await _handleRequest((token) {
        final uri = Uri.parse('$baseUrl/getCSTAll').replace(
          queryParameters: {'token': token, 'type_invoice': typeInvoice},
        );
        return http
            .get(uri, headers: {'Content-Type': 'application/json'})
            .timeout(const Duration(seconds: 15));
      });

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Handle berbagai format response
        if (data['status'] == true || data['error'] == false) {
          // Jika data ada dan tidak kosong
          if (data['data'] != null) {
            if (data['data'] is List) {
              return data['data'];
            } else {
              return [];
            }
          } else {
            return [];
          }
        } else {
          return [];
        }
      } else if (response.statusCode == 404) {
        print('Endpoint CST not found (404), returning empty list');
        return [];
      } else {
        throw Exception('HTTP error: ${response.statusCode}');
      }
    } catch (e) {
      if (e.toString().contains('timed out') ||
          e.toString().contains('Connection') ||
          e.toString().contains('404')) {
        print('Network error CST, returning empty list: $e');
        return [];
      }
      print('Error fetching CST: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> fetchCSTDetail(String shipId) async {
    try {
      final response = await _handleRequest((token) {
        final uri = Uri.parse(
          '$baseUrl/getCSTDetail',
        ).replace(queryParameters: {'token': token, 'ship_id': shipId});
        return http
            .get(uri, headers: {'Content-Type': 'application/json'})
            .timeout(const Duration(seconds: 15));
      });

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == true && data['data'] != null) {
          return data['data'];
        } else {
          throw Exception('Failed to fetch CST detail: ${data['message']}');
        }
      } else {
        throw Exception('HTTP error: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching CST detail: $e');
      rethrow;
    }
  }

  Future<bool> updateCSTStatus({
    required String shipId,
    required String paymentType,
    String? paymentAmount,
    String? paymentDifference,
    String? paymentNotes,
    File? buktiPembayaranCst,
    String? bankId,
  }) async {
    final token = await authService.getValidToken();
    if (token == null) {
      print('Token is null!');
      return false;
    }

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/update_status_cst'),
    );

    Map<String, String> fields = {
      'token': token,
      'ship_id': shipId,
      'payment_type': paymentType,
    };

    if (paymentAmount != null) {
      fields['payment_amount'] = paymentAmount.replaceAll('.', '');
    }
    if (paymentDifference != null) {
      fields['is_diff'] = paymentDifference;
    }
    if (paymentNotes != null && paymentNotes.isNotEmpty) {
      fields['notes'] = paymentNotes;
    }
    if (bankId != null) {
      fields['bank_id'] = bankId;
    }

    request.fields.addAll(fields);

    // Menambahkan file jika ada
    if (buktiPembayaranCst != null) {
      request.files.add(
        await http.MultipartFile.fromPath(
          'bukti_pembayaran_cst',
          buktiPembayaranCst.path,
          filename: buktiPembayaranCst.path.split('/').last,
        ),
      );
    }

    print('Sending CST update with fields: ${request.fields}');
    if (buktiPembayaranCst != null) {
      print('Sending CST file: ${buktiPembayaranCst.path}');
    }

    try {
      final response = await request.send();
      final resBody = await response.stream.bytesToString();
      final data = jsonDecode(resBody);

      if (response.statusCode == 401 ||
          (data['error'] == true && data['message'] == 'Token Not Found')) {
        final newToken = await authService.softLoginRefresh();
        if (newToken != null) {
          // Coba lagi dengan token baru
          return updateCSTStatus(
            shipId: shipId,
            paymentType: paymentType,
            paymentAmount: paymentAmount,
            paymentDifference: paymentDifference,
            paymentNotes: paymentNotes,
            buktiPembayaranCst: buktiPembayaranCst,
            bankId: bankId,
          );
        }
      }

      return response.statusCode == 200 && data['status'] == true;
    } catch (e) {
      print('Error updating CST status: $e');
      rethrow;
    }
  }

  Future<List<dynamic>> fetchMonitoringTagihan() async {
    final String? username = await authService.getUsername();
    if (username == null) {
      throw Exception('Username tidak ditemukan. Harap login ulang.');
    }

    try {
      final response = await _handleRequest((token) {
        final uri = Uri.parse(
          '$baseUrl/getMonitoringTagihan',
        ).replace(queryParameters: {'token': token, 'petugas': username});
        return http
            .get(uri, headers: {'Content-Type': 'application/json'})
            .timeout(const Duration(seconds: 15));
      });

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Sesuaikan dengan format response kamu
        if (data['status'] == true || data['code'] == 200) {
          if (data['data'] != null && data['data'] is List) {
            return data['data'];
          } else {
            return []; // Data null atau bukan list
          }
        } else {
          return []; // Status false
        }
      } else if (response.statusCode == 404) {
        print('Endpoint monitoring tidak ditemukan (404), list kosong');
        return [];
      } else {
        throw Exception('HTTP error: ${response.statusCode}');
      }
    } catch (e) {
      if (e.toString().contains('timed out') ||
          e.toString().contains('Connection') ||
          e.toString().contains('404')) {
        print('Network error monitoring, list kosong: $e');
        return [];
      }
      print('Error fetching monitoring data: $e');
      rethrow;
    }
  }
}
