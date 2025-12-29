import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import '../login_screen.dart';
import '../../services/auth_service.dart';
import 'absen_supir.dart';
import 'tugas_supir.dart';
import '../../services/supir_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';

class MainSupir extends StatefulWidget {
  const MainSupir({Key? key}) : super(key: key);

  @override
  State<MainSupir> createState() => _MainSupirState();
}

class _MainSupirState extends State<MainSupir> with WidgetsBindingObserver {
  int _currentIndex = 0;
  late AuthService _authService;
  late SupirService _supirService;
  Timer? _taskPollingTimer;
  Timer? _locationUpdateTimer;
  Timer? _debounceTimer;
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  final RefreshController _absenRefreshController = RefreshController(
    initialRefresh: false,
  );
  final RefreshController _tugasRefreshController = RefreshController(
    initialRefresh: false,
  );

  // Data untuk Absen
  bool _isLoadingAbsen = false;
  bool _showAbsenButton = false;
  String _statusText = '';
  String _errorMessageAbsen = '';
  String _latitude = '0';
  String _longitude = '0';

  // Data untuk Tugas
  bool _isLoadingTugas = false;
  bool _isLoadingButton = false;
  bool _isSubmittingArrival = false;
  Map<String, dynamic>? _taskData;
  bool _isWaitingAssignment = false;
  final TextEditingController _truckNameController = TextEditingController();
  final TextEditingController _containerNumController = TextEditingController();
  final TextEditingController _sealNum1Controller = TextEditingController();
  final TextEditingController _sealNum2Controller = TextEditingController();
  String? _selectedTipeContainer;

  // Seal Validation
  List<String> _sealNumberSuggestions = [];
  bool _isSealNumberValid = true;
  FocusNode _sealNum1FocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _authService = AuthService();
    _supirService = SupirService(_authService);
    _initializeNotifications().then((_) async {
      final NotificationAppLaunchDetails? details =
          await flutterLocalNotificationsPlugin
              .getNotificationAppLaunchDetails();

      if (details?.didNotificationLaunchApp ?? false) {
        if (mounted) {
          setState(() => _currentIndex = 1);
          await _fetchTaskData();
        }
      }
    });
    _initializeServices();
    _startBackgroundProcesses();
    _sealNum1FocusNode.addListener(_onSealNum1FocusChange);
  }

  @override
  void dispose() {
    _taskPollingTimer?.cancel();
    _locationUpdateTimer?.cancel();
    _truckNameController.dispose();
    _containerNumController.dispose();
    _sealNum1Controller.dispose();
    _sealNum2Controller.dispose();
    WidgetsBinding.instance.removeObserver(this);
    _sealNum1FocusNode.removeListener(_onSealNum1FocusChange);
    _sealNum1FocusNode.dispose();
    _debounceTimer?.cancel();
    _absenRefreshController.dispose();
    _tugasRefreshController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadAbsenStatus();
      _fetchTaskData();
    }
  }

  Future<void> _initializeNotifications() async {
    final status = await Permission.notification.request();
    if (!status.isGranted) {
      print('Notification permission not granted');
    }

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    await flutterLocalNotificationsPlugin.initialize(
      InitializationSettings(android: initializationSettingsAndroid),
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        if (mounted) {
          setState(() => _currentIndex = 1);
          await _fetchTaskData();
        }
      },
    );
  }

  void _initializeServices() async {
    await SupirBackgroundService(_authService).initializeService();
    _loadDraftData();
  }

  void _startBackgroundProcesses() {
    // Polling tugas setiap 30 detik
    _loadDraftData();
    _taskPollingTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _fetchTaskData();
    });

    // Update lokasi setiap 30 detik
    _locationUpdateTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _getCurrentLocation();
    });

    // Load data awal
    _loadAbsenStatus();
    _fetchTaskData();
    _getCurrentLocation();
  }

  Future<void> _loadDraftData() async {
    final prefs = await SharedPreferences.getInstance();
    final draftContainer = prefs.getString('draft_container_num');
    final draftSeal1 = prefs.getString('draft_seal_num1');
    final draftSeal2 = prefs.getString('draft_seal_num2');
    _containerNumController.text = prefs.getString('draft_container_num') ?? '';
    _sealNum1Controller.text = prefs.getString('draft_seal_num1') ?? '';
    _sealNum2Controller.text = prefs.getString('draft_seal_num2') ?? '';
    _truckNameController.text = prefs.getString('draft_truck') ?? '';

    // Jika ada draft, gunakan nilai draft. Jika tidak, baru ambil dari API
    _containerNumController.text = draftContainer ?? '';
    _sealNum1Controller.text = draftSeal1 ?? '';
    _sealNum2Controller.text = draftSeal2 ?? '';

    // Panggil fetchTaskData() setelah draft di-load
    await _fetchTaskData();
  }

  Future<void> _saveDraftData({
    bool containerAndSeal1 = false,
    bool seal2 = false,
    bool truck = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (containerAndSeal1) {
      await prefs.setString(
        'draft_container_num',
        _containerNumController.text,
      );
      await prefs.setString('draft_seal_num1', _sealNum1Controller.text);
    }
    if (seal2) {
      await prefs.setString('draft_seal_num2', _sealNum2Controller.text);
    }
    if (truck) {
      await prefs.setString('draft_truck', _truckNameController.text);
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }

      if (permission == LocationPermission.deniedForever) return;

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      if (mounted) {
        setState(() {
          _latitude = position.latitude.toString();
          _longitude = position.longitude.toString();
        });
      }
    } catch (e) {
      debugPrint('Error getting location: $e');
    }
  }

  Future<void> _loadAbsenStatus() async {
    if (mounted) {
      setState(() {
        _isLoadingAbsen = true;
        _errorMessageAbsen = '';
      });
    }

    try {
      final response = await _supirService.getAttendanceStatus();

      if (mounted) {
        setState(() {
          _showAbsenButton = response['show_button'] == true;
          _statusText = response['notes'];
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessageAbsen = 'Gagal memuat status: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingAbsen = false);
      }
    }
  }

  Future<void> _fetchTaskData() async {
    if (mounted) {
      setState(() {
        _isLoadingTugas = true;
      });
    }

    try {
      final response = await _supirService.getTaskDriver();

      if (response['error'] == false && response['data'].isNotEmpty) {
        final task = response['data'][0];

        if (mounted) {
          setState(() {
            _taskData = task;

            if (_containerNumController.text.isEmpty &&
                (task['container_num'] != null &&
                    task['container_num'] != '-')) {
              _containerNumController.text = task['container_num'].toString();
            }

            if (_sealNum1Controller.text.isEmpty &&
                (task['seal_num1'] != null && task['seal_num1'] != '-')) {
              _sealNum1Controller.text = task['seal_num1'].toString();
            }

            if (_sealNum2Controller.text.isEmpty &&
                (task['seal_num2'] != null && task['seal_num2'] != '-')) {
              _sealNum2Controller.text = task['seal_num2'].toString();
            }
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _taskData = null;
          });
        }
      }
    } catch (e) {
      debugPrint('Fetch Task Error: $e');
      if (mounted) {
        setState(() {
          _taskData = null;
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingTugas = false);
      }
    }
  }

  Future<void> _handleAbsen() async {
    if (mounted) {
      setState(() {
        _isLoadingAbsen = true;
        _errorMessageAbsen = '';
      });
    }

    try {
      final result = await _supirService.kirimAbsen(
        latitude: _latitude,
        longitude: _longitude,
      );

      if (result['success'] == true) {
        await _loadAbsenStatus();
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(result['message'])));
        }
      } else if (mounted) {
        setState(() {
          _errorMessageAbsen = result['message'];
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessageAbsen = 'Terjadi kesalahan: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingAbsen = false);
      }
    }
  }

  Future<void> _sendReady() async {
    if (_selectedTipeContainer == null || _truckNameController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Lengkapi semua field')));
      return;
    }

    setState(() {
      _isLoadingButton = true;
    });

    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final response = await _supirService.sendReady(
        longitude: position.longitude,
        latitude: position.latitude,
        tipeContainer: _selectedTipeContainer!,
        truckName: _truckNameController.text,
      );

      if (response['error'] == false) {
        setState(() {
          _isWaitingAssignment = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ready dikirim, menunggu tugas...')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal Ready: ${response['message']}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() {
        _isLoadingButton = false;
      });
    }
  }

  // Modifikasi _fetchSealNumberSuggestions untuk debouncing
  Future<void> _fetchSealNumberSuggestions(String query) async {
    if (query.isEmpty) {
      setState(() {
        _sealNumberSuggestions = [];
        _isSealNumberValid = true; // Reset validasi saat kosong
      });
      return;
    }

    // Batalkan timer sebelumnya jika ada
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();

    // Set timer baru
    _debounceTimer = Timer(const Duration(milliseconds: 500), () async {
      try {
        final data = await _supirService.getSealNumber(sealNumber: query);
        setState(() {
          _sealNumberSuggestions =
              data.map((item) => item['number'].toString()).toList();
          // Opsional: Langsung validasi saat fetch saran juga
          // _isSealNumberValid = data.any((item) => item['number'] == query);
        });
      } catch (e) {
        debugPrint('Error fetching suggestions: $e');
        setState(() {
          _sealNumberSuggestions = [];
        });
      }
    });
  }

  // Metode untuk memvalidasi nomor segel saat fokus berubah
  void _onSealNum1FocusChange() async {
    // Panggil validasi hanya jika field kehilangan fokus DAN tidak kosong
    if (!_sealNum1FocusNode.hasFocus && _sealNum1Controller.text.isNotEmpty) {
      await _validateSealNumber(_sealNum1Controller.text);
    } else if (_sealNum1FocusNode.hasFocus) {
      // Saat fokus, pastikan error state di-reset jika sebelumnya invalid
      if (!_isSealNumberValid) {
        setState(() {
          _isSealNumberValid = true;
        });
      }
    }
  }

  // Perbaiki logika _validateSealNumber
  Future<bool> _validateSealNumber(String sealNumber) async {
    if (sealNumber.isEmpty) {
      setState(() {
        _isSealNumberValid =
            true; // Nomor segel kosong dianggap valid untuk saat ini
      });
      return true;
    }

    try {
      final data = await _supirService.getSealNumber(sealNumber: sealNumber);
      // Cek apakah ada nomor segel yang persis sama dengan input di data yang diterima
      final isValid = data.any((item) => item['number'] == sealNumber);

      setState(() {
        _isSealNumberValid = isValid;
      });

      if (!isValid) {
        // Tampilkan pop-up dan kosongkan textbox jika tidak valid
        if (mounted) {
          showDialog(
            context: context,
            builder:
                (ctx) => AlertDialog(
                  title: const Text('Nomor Segel Tidak Valid'),
                  content: Text(
                    'Nomor segel "$sealNumber" tidak valid. Mohon masukkan nomor segel yang valid.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        _sealNum1Controller.clear(); // Kosongkan textbox
                        // Penting: Hapus draft data jika segel tidak valid
                        _saveDraftData(containerAndSeal1: true);
                        setState(() {
                          _sealNumberSuggestions = []; // Bersihkan saran juga
                        });
                      },
                      child: const Text('OK'),
                    ),
                  ],
                ),
          );
        }
      }
      return isValid;
    } catch (e) {
      debugPrint('Error validating seal number: $e');
      setState(() {
        _isSealNumberValid = false; // Set ke false jika ada error API
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error validasi nomor segel: $e')),
        );
      }
      return false; // Kembalikan false jika ada error
    }
  }

  // Modifikasi _submitArrival untuk menyertakan validasi nomor segel
  Future<void> _submitArrival() async {
    // Validasi apakah field container dan seal 1 kosong
    if (_containerNumController.text.isEmpty ||
        _sealNum1Controller.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Lengkapi semua field (Container Number dan Seal Number 1)',
          ),
        ),
      );
      return;
    }

    // Validasi nomor segel 1 sebelum melanjutkan
    final isValidSeal = await _validateSealNumber(_sealNum1Controller.text);
    if (!isValidSeal) {
      return; // Hentikan proses submit jika nomor segel tidak valid
    }

    setState(() {
      _isSubmittingArrival = true;
    });

    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final response = await _supirService.submitArrival(
        taskId: _taskData?['task_id'],
        longitude: position.longitude,
        latitude: position.latitude,
        containerNum: _containerNumController.text,
        sealNum1: _sealNum1Controller.text,
      );

      if (response['error'] == false) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('draft_truck');
        await prefs.remove('draft_container_num');
        await prefs.remove('draft_seal_num1');

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Berhasil Sampai Pabrik')));

        await _fetchTaskData();
        setState(() {}); // Refresh UI setelah berhasil submit
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal: ${response['message']}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() {
        _isSubmittingArrival = false;
      });
    }
  }

  Future<void> _sendDeparture() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final now = DateTime.now();
      final departureDate =
          '${now.day.toString().padLeft(2, '0')}-${now.month.toString().padLeft(2, '0')}-${now.year}';
      final departureTime =
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

      final response = await _supirService.submitDeparture(
        taskId: _taskData?['task_id'],
        departureDate: departureDate,
        departureTime: departureTime,
        longitude: position.longitude,
        latitude: position.latitude,
        sealNum2: _sealNum2Controller.text,
      );

      if (response['error'] == false) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Berhasil keluar pabrik')));

        await _fetchTaskData();
        setState(() {});
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal keluar: ${response['message']}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _handlePortArrival() async {
    setState(() {
      _isLoadingButton = true;
    });

    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final now = DateTime.now();
      final postArrivalDate =
          '${now.day.toString().padLeft(2, '0')}-${now.month.toString().padLeft(2, '0')}-${now.year}';
      final postArrivalTime =
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

      final response = await _supirService.submitPortArrival(
        taskId: _taskData?['task_id'],
        postArrivalDate: postArrivalDate,
        postArrivalTime: postArrivalTime,
        longitude: position.longitude,
        latitude: position.latitude,
      );

      if (response['status'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response['message'] ?? 'Berhasil sampai pelabuhan'),
          ),
        );
        await _fetchTaskData(); // Refresh data tugas
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(response['message'] ?? 'Gagal mengirim data')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() {
        _isLoadingButton = false;
      });
    }
  }

  void _onAbsenRefresh() async {
    try {
      await _loadAbsenStatus();
      _absenRefreshController.refreshCompleted();
    } catch (e) {
      _absenRefreshController.refreshFailed();
    }
  }

  void _onTugasRefresh() async {
    try {
      await _fetchTaskData();
      _tugasRefreshController.refreshCompleted();
    } catch (e) {
      _tugasRefreshController.refreshFailed();
    }
  }

  final List<String> _titles = ['Absen', 'Tugas'];

  List<Widget> _buildPages() {
    return [
      // Untuk Absen
      SmartRefresher(
        controller: _absenRefreshController,
        onRefresh: _onAbsenRefresh,
        enablePullDown: true,
        enablePullUp: false,
        header: CustomHeader(
          builder: (BuildContext context, RefreshStatus? mode) {
            Widget body;
            if (mode == RefreshStatus.idle) {
              body = Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.arrow_downward,
                    color: Theme.of(context).primaryColor,
                  ),
                  SizedBox(height: 8),
                  Text(
                    "Tarik ke bawah untuk refresh",
                    style: TextStyle(color: Theme.of(context).primaryColor),
                  ),
                ],
              );
            } else if (mode == RefreshStatus.refreshing) {
              body = Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Theme.of(context).primaryColor,
                      ),
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    "Memuat data absen...",
                    style: TextStyle(color: Theme.of(context).primaryColor),
                  ),
                ],
              );
            } else if (mode == RefreshStatus.failed) {
              body = Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, color: Colors.red),
                  SizedBox(height: 8),
                  Text(
                    "Gagal memuat, coba lagi",
                    style: TextStyle(color: Colors.red),
                  ),
                ],
              );
            } else if (mode == RefreshStatus.completed) {
              body = Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.check_circle,
                    color: Theme.of(context).primaryColor,
                  ),
                  SizedBox(height: 8),
                  Text(
                    "Data absen diperbarui",
                    style: TextStyle(color: Theme.of(context).primaryColor),
                  ),
                ],
              );
            } else {
              body = Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.arrow_upward,
                    color: Theme.of(context).primaryColor,
                  ),
                  SizedBox(height: 8),
                  Text(
                    "Lepaskan untuk refresh",
                    style: TextStyle(color: Theme.of(context).primaryColor),
                  ),
                ],
              );
            }
            return Container(height: 50, child: Center(child: body));
          },
        ),
        child: AbsenSupirScreen(
          isLoading: _isLoadingAbsen,
          showButton: _showAbsenButton,
          statusText: _statusText,
          errorMessage: _errorMessageAbsen,
          latitude: _latitude,
          longitude: _longitude,
          onAbsenPressed: _handleAbsen,
        ),
      ),

      // Untuk Tugas
      SmartRefresher(
        controller: _tugasRefreshController,
        onRefresh: _onTugasRefresh,
        enablePullDown: true,
        enablePullUp: false,
        header: CustomHeader(
          builder: (BuildContext context, RefreshStatus? mode) {
            Widget body;
            if (mode == RefreshStatus.idle) {
              body = Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.arrow_downward,
                    color: Theme.of(context).primaryColor,
                  ),
                  SizedBox(height: 8),
                  Text(
                    "Tarik ke bawah untuk refresh",
                    style: TextStyle(color: Theme.of(context).primaryColor),
                  ),
                ],
              );
            } else if (mode == RefreshStatus.refreshing) {
              body = Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Theme.of(context).primaryColor,
                      ),
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    "Memuat data tugas...",
                    style: TextStyle(color: Theme.of(context).primaryColor),
                  ),
                ],
              );
            } else if (mode == RefreshStatus.failed) {
              body = Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, color: Colors.red),
                  SizedBox(height: 8),
                  Text(
                    "Gagal memuat, coba lagi",
                    style: TextStyle(color: Colors.red),
                  ),
                ],
              );
            } else if (mode == RefreshStatus.completed) {
              body = Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.check_circle,
                    color: Theme.of(context).primaryColor,
                  ),
                  SizedBox(height: 8),
                  Text(
                    "Data tugas diperbarui",
                    style: TextStyle(color: Theme.of(context).primaryColor),
                  ),
                ],
              );
            } else {
              body = Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.arrow_upward,
                    color: Theme.of(context).primaryColor,
                  ),
                  SizedBox(height: 8),
                  Text(
                    "Lepaskan untuk refresh",
                    style: TextStyle(color: Theme.of(context).primaryColor),
                  ),
                ],
              );
            }
            return Container(height: 50, child: Center(child: body));
          },
        ),
        child: TugasSupirScreen(
          isLoading: _isLoadingTugas,
          taskData: _taskData,
          isWaitingAssignment: _isWaitingAssignment,
          isLoadingButton: _isLoadingButton,
          isSubmittingArrival: _isSubmittingArrival,
          truckNameController: _truckNameController,
          containerNumController: _containerNumController,
          sealNum1Controller: _sealNum1Controller,
          sealNum1FocusNode: _sealNum1FocusNode, // Pass the FocusNode
          sealNumberSuggestions: _sealNumberSuggestions,
          isSealNumberValid: _isSealNumberValid,
          onSealNum1Changed: (value) {
            _saveDraftData(containerAndSeal1: true);
            _fetchSealNumberSuggestions(value); // Fetch suggestions on change
          },
          onSealNumberSuggestionSelected: (suggestion) {
            _sealNum1Controller.text = suggestion;
            _sealNumberSuggestions = []; // Clear suggestions after selection
            _saveDraftData(containerAndSeal1: true);
          },
          sealNum2Controller: _sealNum2Controller,
          selectedTipeContainer: _selectedTipeContainer,
          onTipeContainerChanged: (value) {
            setState(() {
              _selectedTipeContainer = value;
            });
          },
          onReadyPressed: _sendReady,
          onArrivalPressed: _submitArrival,
          onDeparturePressed: _sendDeparture,
          onPortArrivalPressed: _handlePortArrival,
          onSaveDraft: _saveDraftData,
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
      },
      child: Scaffold(
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(150.0),
          child: SafeArea(child: _buildCustomAppBar(context, _currentIndex)),
        ),
        body: IndexedStack(index: _currentIndex, children: _buildPages()),
        bottomNavigationBar: _buildFloatingNavBar(theme),
      ),
    );
  }

  Widget _buildCustomAppBar(BuildContext context, int currentIndex) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Image.asset('assets/images/logo.png', height: 40, width: 200),
              Row(
                children: [
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () async {
                      await _authService.logout();
                      if (!mounted) return;
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                      );
                    },
                    child: const Text('Logout'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            'Aplikasi Supir',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
          Text(
            _titles[currentIndex],
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingNavBar(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          backgroundColor: theme.colorScheme.surface,
          selectedItemColor: theme.colorScheme.primary,
          unselectedItemColor: theme.colorScheme.onSurface.withOpacity(0.6),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.access_time_outlined),
              activeIcon: Icon(Icons.access_time),
              label: 'Absen',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.assignment_outlined),
              activeIcon: Icon(Icons.assignment),
              label: 'Tugas',
            ),
          ],
        ),
      ),
    );
  }
}
