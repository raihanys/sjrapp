import 'package:flutter/widgets.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_config.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

@pragma('vm:entry-point')
void supirOnStart(ServiceInstance service) async {
  // Pastikan SharedPreferences diinisialisasi sebelum digunakan
  WidgetsFlutterBinding.ensureInitialized();
  final supirService = SupirBackgroundService(AuthService());
  Timer? periodicTimer; // <-- Tambahkan timer

  service.on('stopService').listen((event) {
    periodicTimer?.cancel(); // <-- Hentikan timer saat service berhenti
    service.stopSelf();
  });

  try {
    final token = await supirService._authService.getValidToken();
    if (token == null) {
      await service.stopSelf();
      return;
    }

    // Jalankan pengecekan pertama kali
    await supirService.checkTaskStatus(service, token);

    // Setup periodic check setiap 10 dtk
    periodicTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
      final newToken = await supirService._authService.getValidToken();
      if (newToken != null) {
        await supirService.checkTaskStatus(service, newToken);
      }
    });
  } catch (e) {
    print('Background service error: $e');
  }
}

class SupirService {
  final AuthService _authService;
  Timer? _timer;

  SupirService(this._authService) {
    _initializeNotifications();
  }

  // Centralized API endpoints
  String get _attendanceStatusUrl => '$baseUrl/get_attendance_driver';
  String get _attendanceSubmitUrl => '$baseUrl/driver_attendance';
  String get _taskDriverUrl => '$baseUrl/get_task_driver';
  String get _driverReadyUrl => '$baseUrl/driver_ready';
  String get _driverArrivalUrl => '$baseUrl/driver_arrival_input';
  String get _driverDepartureUrl => '$baseUrl/driver_departure_input';
  String get _sealUrl => '$baseUrl/get_seal_number';
  String get _portArrivalUrl => '$baseUrl/arrived_to_harbor';

  Future<void> _initializeNotifications() async {
    final status = await Permission.notification.request();
    if (!status.isGranted) {
      print('Notification permission not granted');
    }

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    await flutterLocalNotificationsPlugin.initialize(
      const InitializationSettings(android: initializationSettingsAndroid),
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        if (response.payload != null) {
          // Handle notification tap if needed
        }
      },
    );

    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'supir_channel',
      'Supir Notifications',
      description: 'Channel for driver task notifications',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);
  }

  Future<Map<String, dynamic>> getAttendanceStatus() async {
    try {
      final token = await _authService.getValidToken();
      if (token == null) throw Exception('Token not available');

      final response = await http.get(
        Uri.parse('$_attendanceStatusUrl?token=$token'),
      );

      print('📡 Response status: ${response.statusCode}');
      print('📡 Response body: ${response.body}');

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        if (data['error'] == false) {
          final list = data['data'];
          _startAutoRefresh();

          if (list is List && list.isEmpty) {
            return {
              'show_button': true,
              'notes': 'Silakan lakukan absen',
              'statusCode': 200,
            };
          }

          if (list is List && list.isNotEmpty) {
            return {
              'show_button': list[0]['show_button'] == 1,
              'notes': list[0]['notes'] ?? '',
              'statusCode': 200,
            };
          }
        }
        throw Exception(data['message'] ?? 'Gagal mendapatkan status absen');
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error in getAttendanceStatus: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> kirimAbsen({
    required String latitude,
    required String longitude,
  }) async {
    try {
      final token = await _authService.getValidToken();
      if (token == null) throw Exception('Token not available');

      final response = await http.post(
        Uri.parse(_attendanceSubmitUrl),
        body: {'token': token, 'latitude': latitude, 'longitude': longitude},
      );

      final data = json.decode(response.body);

      return {
        'success': (response.statusCode == 200 && data['error'] == false),
        'message': data['message'] ?? 'Absen berhasil',
        'statusCode': response.statusCode,
      };
    } catch (e) {
      print('❌ Error in kirimAbsen: $e');
      return {
        'success': false,
        'message': 'Terjadi kesalahan jaringan',
        'statusCode': 500,
      };
    }
  }

  Future<Map<String, dynamic>> getTaskDriver() async {
    try {
      final token = await _authService.getValidToken();
      if (token == null) throw Exception('Token not available');

      final response = await http.get(
        Uri.parse('$_taskDriverUrl?token=$token'),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to fetch task driver');
      }
    } catch (e) {
      print('❌ Error in getTaskDriver: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> sendReady({
    required double longitude,
    required double latitude,
    required String tipeContainer,
    required String truckName,
  }) async {
    try {
      final token = await _authService.getValidToken();
      if (token == null) throw Exception('Token not available');

      final response = await http.post(
        Uri.parse(_driverReadyUrl),
        body: {
          'token': token,
          'longitude': longitude.toString(),
          'latitude': latitude.toString(),
          'tipe_container': tipeContainer,
          'truck_name': truckName,
        },
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to send ready');
      }
    } catch (e) {
      print('❌ Error in sendReady: $e');
      rethrow;
    }
  }

  Future<List<dynamic>> getSealNumber({required String sealNumber}) async {
    try {
      final token =
          await _authService
              .getValidToken(); // Use AuthService to get the token
      if (token == null)
        throw Exception('Token not available'); // Add null check for token

      final response = await http.get(
        Uri.parse('$_sealUrl?token=$token&seal_number=$sealNumber'),
      );

      final responseData = json.decode(response.body);

      if (response.statusCode == 200 && responseData['status'] == true) {
        return responseData['data'] as List<dynamic>;
      } else {
        debugPrint(
          'Failed to get seal number: ${responseData['message'] ?? response.body}',
        );
        return []; // Return empty list if status is false or data is empty
      }
    } catch (e) {
      debugPrint('Error fetching seal numbers: $e');
      throw Exception('Failed to connect to API: $e');
    }
  }

  Future<Map<String, dynamic>> submitArrival({
    required int taskId,
    required double longitude,
    required double latitude,
    required String containerNum,
    required String sealNum1,
  }) async {
    try {
      final token = await _authService.getValidToken();
      if (token == null) throw Exception('Token not available');

      final response = await http.post(
        Uri.parse(_driverArrivalUrl),
        body: {
          'token': token,
          'id_task': taskId.toString(),
          'longitude': longitude.toString(),
          'latitude': latitude.toString(),
          'container_num': containerNum,
          'seal_num1': sealNum1,
        },
      );

      return json.decode(response.body);
    } catch (e) {
      print('❌ Error in submitArrival: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> submitDeparture({
    required int taskId,
    required String departureDate,
    required String departureTime,
    required double longitude,
    required double latitude,
    required String sealNum2,
  }) async {
    try {
      final token = await _authService.getValidToken();
      if (token == null) throw Exception('Token not available');

      final response = await http.post(
        Uri.parse(_driverDepartureUrl),
        body: {
          'token': token,
          'id_task': taskId.toString(),
          'departure_date': departureDate,
          'departure_time': departureTime,
          'longitude': longitude.toString(),
          'latitude': latitude.toString(),
          'seal_num2': sealNum2,
        },
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to submit departure');
      }
    } catch (e) {
      print('❌ Error in submitDeparture: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> submitPortArrival({
    required int taskId,
    required String postArrivalDate,
    required String postArrivalTime,
    required double longitude,
    required double latitude,
  }) async {
    try {
      final token = await _authService.getValidToken();
      if (token == null) throw Exception('Token tidak tersedia');

      final response = await http.post(
        Uri.parse(_portArrivalUrl),
        body: {
          'token': token,
          'id_task': taskId.toString(),
          'post_arrival_date': postArrivalDate,
          'post_arrival_time': postArrivalTime,
          'longitude': longitude.toString(),
          'latitude': latitude.toString(),
        },
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Gagal mengirim data kedatangan pelabuhan');
      }
    } catch (e) {
      print('❌ Error in submitPortArrival: $e');
      rethrow;
    }
  }

  Future<void> checkTaskStatus(ServiceInstance service, String token) async {
    try {
      final task = await _fetchTask(token);
      if (task != null) {
        await _checkAndShowNewTaskNotification(task);
        await _checkAndShowRcReadyNotification(task);
      }
    } catch (e) {
      print('Error in checkTaskStatus: $e');
    }
  }

  Future<Map<String, dynamic>?> _fetchTask(String token) async {
    final response = await http.get(Uri.parse('$_taskDriverUrl?token=$token'));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['error'] == false && data['data'].isNotEmpty) {
        return data['data'][0];
      }
    }
    return null;
  }

  Future<void> _checkAndShowNewTaskNotification(
    Map<String, dynamic> task,
  ) async {
    final taskAssign = task['task_assign'] ?? 0;
    final taskId = task['task_id']?.toString() ?? '';
    final prefs = await SharedPreferences.getInstance();
    final String notificationKey = 'notified_task_$taskId';

    if (taskAssign != 0 &&
        (task['arrival_date'] == null || task['arrival_date'] == '-')) {
      if (!prefs.containsKey(notificationKey)) {
        // Cek apakah notifikasi sudah pernah ditampilkan
        await _showNotification(
          id: 1,
          title: 'Tugas Baru',
          body: 'Anda mendapatkan tugas baru!',
          payload: 'task_$taskId',
        );
        await prefs.setBool(notificationKey, true);
      }
    } else {
      if (prefs.containsKey(notificationKey)) {
        await prefs.remove(notificationKey);
      }
    }
  }

  Future<void> _checkAndShowRcReadyNotification(
    Map<String, dynamic> task,
  ) async {
    final fotoRcUrl = task['foto_rc_url'];
    final taskId = task['task_id']?.toString() ?? '';
    final prefs = await SharedPreferences.getInstance();
    final String notificationKey = 'notified_rc_$taskId';

    if (fotoRcUrl != null &&
        fotoRcUrl != '-' &&
        (task['post_arrival_date'] == null ||
            task['post_arrival_date'] == '-')) {
      if (!prefs.containsKey(notificationKey)) {
        await _showNotification(
          id: 2,
          title: 'RC Tersedia',
          body: 'Foto RC sudah tersedia.',
          payload: 'rc_${task['task_id']}',
        );
        await prefs.setBool(notificationKey, true);
      }
    } else {
      // Jika kondisi RC tidak lagi memenuhi kriteria notifikasi, hapus status notifikasi
      if (prefs.containsKey(notificationKey)) {
        await prefs.remove(notificationKey);
      }
    }
  }

  Future<void> _showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'supir_channel',
          'Supir Notifications',
          channelDescription: 'Channel for driver task notifications',
          importance: Importance.max,
          priority: Priority.high,
          ticker: 'ticker',
          playSound: true,
          enableVibration: true,
        );

    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
    );

    await flutterLocalNotificationsPlugin.show(
      id,
      title,
      body,
      platformDetails,
      payload: payload,
    );
  }

  void _startAutoRefresh() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(hours: 1), (_) async {
      print('⏰ Auto-refresh absen ...');
      try {
        await getAttendanceStatus();
      } catch (_) {}
    });
  }

  void cancelAutoRefresh() {
    _timer?.cancel();
    _timer = null;
  }
}

class SupirBackgroundService {
  final AuthService _authService;

  String get _taskDriverUrl => '$baseUrl/get_task_driver';

  SupirBackgroundService(this._authService);

  Future<void> initializeService() async {
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'supir_channel',
      'Supir Service',
      description: 'Notifikasi untuk tugas supir',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);

    final service = FlutterBackgroundService();
    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: supirOnStart,
        isForegroundMode: true,
        autoStart: true,
        notificationChannelId: 'supir_channel',
        initialNotificationTitle: 'Ralisa App Service',
        initialNotificationContent: 'Monitoring Progress...',
        foregroundServiceNotificationId: 999,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: true,
        onForeground: supirOnStart,
        onBackground: (_) async => true,
      ),
    );

    await service.startService();
  }

  Future<void> checkTaskStatus(ServiceInstance service, String token) async {
    print('⏰ checkTaskStatus started at ${DateTime.now()}'); // Log mulai fungsi
    try {
      final response = await http.get(
        Uri.parse('$_taskDriverUrl?token=$token'),
      );

      print(
        '📡 API Response Status Code: ${response.statusCode}',
      ); // Log Status Code
      print(
        '📡 API Response Body (partial): ${response.body.substring(0, response.body.length)}...',
      ); // Log sebagian body

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print(
          '✅ API response parsed successfully. Error: ${data['error']}, Data empty: ${data['data'].isEmpty}',
        ); // Log parsing sukses

        if (data['error'] == false && data['data'].isNotEmpty) {
          final task = data['data'][0];
          print(
            '➡️ Calling _handleTaskNotifications with task data.',
          ); // Log sebelum panggil handler
          await _handleTaskNotifications(task);
        } else {
          print(
            'ℹ️ API response indicates error or empty data, not calling _handleTaskNotifications.',
          );
          // Tambahkan logika untuk menghapus semua notifikasi terkait tugas jika tidak ada tugas
          // atau jika API mengembalikan error. Ini untuk me-reset status jika tugas sebelumnya hilang.
          await _clearAllTaskNotifications();
        }
      } else {
        print('❌ API call failed with status code: ${response.statusCode}');
        // Mungkin tambahkan logika untuk softLoginRefresh di sini jika status code 401
        // Di dalam SupirBackgroundService.checkTaskStatus
        if (response.statusCode == 401) {
          print('Token invalid, attempting soft login refresh...');
          final newToken = await _authService.softLoginRefresh();
          if (newToken != null) {
            print('Soft login success');
            await checkTaskStatus(service, newToken); // Retry dengan token baru
          }
        }
      }
    } catch (e) {
      print(
        '❌ Error in checkTaskStatus API call: $e',
      ); // Log error saat fetch API
      // Handle network errors etc.
    } finally {
      print(
        '✅ checkTaskStatus finished at ${DateTime.now()}',
      ); // Log selesai fungsi
    }
  }

  Future<void> _handleTaskNotifications(Map<String, dynamic> task) async {
    final taskId = task['task_id']?.toString() ?? '';
    final taskAssign = task['task_assign'] ?? 0;
    final arrivalDate = task['arrival_date'];
    final fotoRCUrl = task['foto_rc_url']?.toString() ?? '';
    final postArrivalDate = task['post_arrival_date']?.toString() ?? '';

    final prefs = await SharedPreferences.getInstance();
    // Notifikasi Tugas Baru
    final String newTaskNotificationKey = 'notified_task_$taskId';
    if (taskAssign != 0 && (arrivalDate == null || arrivalDate == '-')) {
      if (!prefs.containsKey(newTaskNotificationKey)) {
        print('  -> Triggering New Task Notification for Task ID: $taskId');
        await _showNotification(
          id: 1,
          title: 'Penugasan Diterima',
          body: 'Anda mendapat tugas baru.',
          payload: 'task',
        );
        await prefs.setBool(newTaskNotificationKey, true);
      }
    } else {
      // Jika tugas sudah tidak baru atau sudah tiba, hapus status notifikasi tugas baru
      if (prefs.containsKey(newTaskNotificationKey)) {
        await prefs.remove(newTaskNotificationKey);
      }
    }

    // Notifikasi RC Tersedia
    final String rcNotificationKey = 'notified_rc_$taskId';
    if ((fotoRCUrl.isNotEmpty && fotoRCUrl != '-') &&
        (postArrivalDate.isEmpty || postArrivalDate == '-')) {
      if (!prefs.containsKey(rcNotificationKey)) {
        print(
          '  -> Triggering RC Available Notification (Simplified Logic) for Task ID: $taskId',
        );
        await _showNotification(
          id: 2,
          title: 'RC Tersedia',
          body: 'Foto RC sudah tersedia.',
          payload: 'rc',
        );
        await prefs.setBool(rcNotificationKey, true);
      }
    } else {
      if (prefs.containsKey(rcNotificationKey)) {
        await prefs.remove(rcNotificationKey);
      }
    }
  }

  // Fungsi untuk menghapus semua status notifikasi tugas jika tidak ada tugas
  Future<void> _clearAllTaskNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();
    for (String key in keys) {
      if (key.startsWith('notified_task_') || key.startsWith('notified_rc_')) {
        await prefs.remove(key);
      }
    }
    print('ℹ️ All task and RC notifications cleared from SharedPreferences.');
  }

  Future<void> _showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'supir_channel',
          'Supir Notifications',
          channelDescription: 'Notifikasi untuk tugas supir',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
        );

    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
    );

    // ID notifikasi 1 untuk tugas baru, 2 untuk RC tersedia
    // Ini memastikan notifikasi yang sama (misal selalu ID 1 untuk tugas baru)
    // akan mengupdate notifikasi sebelumnya jika sudah ada, bukan membuat yang baru berulang.
    // Namun, dengan logika SharedPreferences, ini tidak akan sering terjadi.

    await flutterLocalNotificationsPlugin.show(
      id,
      title,
      body,
      platformDetails,
      payload: payload,
    );
  }
}
