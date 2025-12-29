import 'dart:async';
import 'dart:convert';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_service.dart';
import 'package:http_parser/http_parser.dart';
import 'api_config.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

@pragma('vm:entry-point')
void pelabuhanOnStart(ServiceInstance service) async {
  final pelabuhanService = PelabuhanService(AuthService());

  service.on('stopService').listen((event) {
    service.stopSelf();
  });

  try {
    final token = await pelabuhanService._authService.getValidToken();
    if (token == null) {
      await service.stopSelf();
      return;
    }
    await pelabuhanService._checkForNewOrders(service);
  } catch (e) {
    print('Background service error: $e');
  }
}

class PelabuhanService {
  final AuthService _authService;
  final String _ordersUrl = '$baseUrl/get_new_salesorder_for_krani_pelabuhan';
  final String _submitRcUrl = '$baseUrl/agent_create_rc';
  final String _archiveUrl = '$baseUrl/get_new_salesorder_for_archive';

  PelabuhanService(this._authService);

  Future<void> initializeService() async {
    final service = FlutterBackgroundService();
    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: pelabuhanOnStart,
        isForegroundMode: true,
        autoStart: true,
        notificationChannelId: 'order_service_channel',
        initialNotificationTitle: 'Ralisa App Service',
        initialNotificationContent: 'Monitoring Progress...',
        foregroundServiceNotificationId: 888,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: true,
        onForeground: pelabuhanOnStart,
        onBackground: (_) async => true,
      ),
    );
    await service.startService();
  }

  Future<List<dynamic>> fetchOrders() async {
    final token = await _authService.getValidToken();
    if (token == null) return [];
    final response = await http.get(Uri.parse('$_ordersUrl?token=$token'));
    if (response.statusCode == 200) {
      final jsonData = json.decode(response.body);
      return jsonData['data'] is List ? jsonData['data'] : [];
    }
    return [];
  }

  Future<List<dynamic>> fetchArchiveOrders() async {
    final token = await _authService.getValidToken();
    if (token == null) return [];
    final response = await http.get(Uri.parse('$_archiveUrl?token=$token'));
    if (response.statusCode == 200) {
      final jsonData = json.decode(response.body);
      return jsonData['data'] is List ? jsonData['data'] : [];
    }
    return [];
  }

  Future<bool> submitRC({
    required String soId,
    required String containerNum,
    required String sealNumber,
    required String sealNumber2,
    required String fotoRcPath,
    required String agent,
  }) async {
    final token = await _authService.getValidToken();
    if (token == null) return false;

    final request =
        http.MultipartRequest('POST', Uri.parse(_submitRcUrl))
          ..fields.addAll({
            'so_id': soId,
            'container_num': containerNum,
            'seal_number': sealNumber,
            'seal_number2': sealNumber2,
            'agent': agent,
            'token': token,
          })
          ..files.add(
            await http.MultipartFile.fromPath(
              'foto_rc',
              fotoRcPath,
              contentType: MediaType('image', 'jpeg'),
            ),
          );

    final response = await request.send();
    final resBody = await response.stream.bytesToString();
    final data = jsonDecode(resBody);

    if (response.statusCode == 401 || data['error'] == true) {
      final newToken = await _authService.softLoginRefresh();
      if (newToken != null) {
        return submitRC(
          soId: soId,
          containerNum: containerNum,
          sealNumber: sealNumber,
          sealNumber2: sealNumber2,
          fotoRcPath: fotoRcPath,
          agent: agent,
        );
      }
    }
    return response.statusCode == 200 &&
        (data['status'] == true || data['error'] == false);
  }

  Future<void> _checkForNewOrders(ServiceInstance service) async {
    try {
      final token = await _authService.getValidToken();
      if (token == null) {
        service.invoke('force_relogin');
        return;
      }

      final response = await http.get(Uri.parse('$_ordersUrl?token=$token'));

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = json.decode(response.body);
        if (jsonData.containsKey('data') && jsonData['data'] is List) {
          final List<dynamic> orders = jsonData['data'];
          if (orders.isNotEmpty) {
            final prefs = await SharedPreferences.getInstance();
            // Simpan data order ke shared_preferences
            await prefs.setString('orders', jsonEncode(orders));
            final lastOrderId = prefs.getString('lastOrderId');
            final newOrder = orders.first;
            final currentOrderId = newOrder['so_id'].toString();
            final fotoRc = newOrder['foto_rc']?.toString().trim() ?? '';

            if (fotoRc.isEmpty && currentOrderId != lastOrderId) {
              await prefs.setString('lastOrderId', currentOrderId);
              await showNewOrderNotification(
                orderId: currentOrderId,
                noRo: newOrder['no_ro']?.toString() ?? 'No RO',
              );
            }
          }
        }
      }
    } catch (e) {
      print('Error in _checkForNewOrders: $e');
    }
  }

  Future<void> showNewOrderNotification({
    required String orderId,
    required String noRo,
  }) async {
    final AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'order_service_channel',
          'Order Service Channel',
          channelDescription: 'New order notifications from background service',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
          icon: '@mipmap/ic_launcher',
          ledOnMs: 1000,
          ledOffMs: 500,
          ticker: 'Data Order Perlu Di Proses!',
          fullScreenIntent: true,
          styleInformation: BigTextStyleInformation(
            'Nomor RO: $noRo\nStatus: Menunggu RC!',
            contentTitle: 'Data Order Perlu di proses!',
            htmlFormatContentTitle: true,
          ),
        );

    final NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
    );

    await flutterLocalNotificationsPlugin.show(
      int.tryParse(orderId) ?? 0,
      'Data Order Perlu di proses!',
      'Nomor RO: $noRo',
      platformDetails,
      payload: 'inbox',
    );
  }
}
