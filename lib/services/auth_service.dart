import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'api_config.dart';

// For getting device IMEI (Actived in Production)
// import 'package:device_info_plus/device_info_plus.dart';

class AuthService {
  final String loginUrl = '$baseUrl/login';

  // For getting device IMEI (Actived in Production)
  // Future<String> _getDeviceImei() async {
  //   final deviceInfo = DeviceInfoPlugin();
  //   final androidInfo = await deviceInfo.androidInfo;
  //   return androidInfo.id;
  // }

  Future<Map<String, dynamic>?> login({
    required String username,
    required String password,
  }) async {
    // Dummy IMEI (Actived in Testing)
    final imei = 'ac9ba078-0a12-45ad-925b-2d761ad9770f';

    // For getting device IMEI (Actived in Production)
    // final imei = await _getDeviceImei();

    return await _attemptLogin(
      username: username,
      password: password,
      version: '1.0',
      imei: imei,
    );
  }

  Future<Map<String, dynamic>?> _attemptLogin({
    required String username,
    required String password,
    required String version,
    required String imei,
  }) async {
    try {
      final body = {
        'username': username,
        'password': password,
        'version': version,
        'imei': imei,
        'firebase': 'dummy_token',
      };

      print('Attempting login for user: $username');

      final res = await http
          .post(
            Uri.parse(loginUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);

        // Cek jika API merespon dengan 'error' == false dan 'data' tidak null
        if (data['error'] == false && data['data'] != null) {
          final user = data['data'];
          final prefs = await SharedPreferences.getInstance();

          // Ambil 'type' dari response API dan simpan
          final role = user['type']?.toString();
          if (role == null) {
            print('Login failed: Role (type) not found in API response.');
            return null;
          }

          final invoicingCode = user['invoicing_code']?.toString();

          await prefs.setBool('isLoggedIn', true);
          await prefs.setString('username', username);
          await prefs.setString(
            'password',
            password,
          ); // Simpan untuk soft-refresh
          await prefs.setString('role', role); // Simpan role dari API
          await prefs.setString('invoicing_code', invoicingCode ?? '0');
          await prefs.setString('version', version);
          await prefs.setString('token', user['token'] ?? '');

          print('Login success! Role: $role, Version: $version');
          return user; // Kembalikan data user untuk menandakan sukses
        } else {
          // Pesan error dari API
          print('Login failed: ${data['message']}');
          return null;
        }
      } else {
        // Error koneksi HTTP
        print('HTTP error: ${res.statusCode} - ${res.body}');
        return null;
      }
    } catch (e) {
      // Error lain (timeout, tidak ada koneksi, dll)
      print('Error during login attempt: $e');
      return null;
    }
  }

  Future<void> logout() async {
    try {
      // Hentikan background service dengan cara yang benar
      final service = FlutterBackgroundService();
      service.invoke('stopService');

      // Hapus semua data login
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      print("Logout berhasil, service dihentikan dan data dibersihkan.");
    } catch (e) {
      print("Gagal logout: $e");
    }
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  Future<String?> getRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('role');
  }

  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('isLoggedIn') ?? false;
  }

  Future<void> saveAuthData(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', token);
    await prefs.setString('token_saved_at', DateTime.now().toIso8601String());
  }

  Future<String?> getValidToken() async {
    final currentToken = await getToken();
    if (currentToken == null) return null;

    if (await isTokenValid()) {
      return currentToken;
    }

    return await softLoginRefresh();
  }

  Future<bool> isTokenValid() async {
    final prefs = await SharedPreferences.getInstance();
    final savedAt = prefs.getString('token_saved_at');
    if (savedAt == null) return false;

    final tokenAge = DateTime.now().difference(DateTime.parse(savedAt));
    return tokenAge.inHours < 12;
  }

  Future<String?> softLoginRefresh() async {
    final prefs = await SharedPreferences.getInstance();
    final username = prefs.getString('username');
    final password = prefs.getString('password');
    if (username == null || password == null) return null;
    try {
      final result = await login(username: username, password: password);
      return result?['token'];
    } catch (e) {
      return null;
    }
  }

  Future<String?> getInvoicingCode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('invoicing_code');
  }

  Future<void> saveInvoicingCode(String invoicingCode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('invoicing_code', invoicingCode);
  }

  Future<String?> getUsername() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('username');
  }
}
