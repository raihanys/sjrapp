import 'package:flutter/material.dart';
import 'dart:async';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import '../../services/auth_service.dart';
import '../../services/krani_mks_service.dart';
import '../login_screen.dart';
import 'scan_krani_mks.dart';

class MainKraniMks extends StatefulWidget {
  const MainKraniMks({Key? key}) : super(key: key);

  @override
  State<MainKraniMks> createState() => _MainKraniMksState();
}

class _MainKraniMksState extends State<MainKraniMks> {
  final AuthService _authService = AuthService();
  final KraniMksService _kraniMksService = KraniMksService();
  List<dynamic> _shippedContainers = [];
  bool _isLoading = true;
  final RefreshController _refreshController = RefreshController();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _fetchContainers();
    // Set up a periodic timer to fetch data every 10 minutes
    _timer = Timer.periodic(const Duration(minutes: 10), (timer) {
      _fetchContainers();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _refreshController.dispose();
    super.dispose();
  }

  Future<void> _fetchContainers() async {
    setState(() => _isLoading = true);
    final data = await _kraniMksService.getContainers();

    if (data != null && data['data'] != null) {
      setState(() {
        _shippedContainers = data['data']['container_received'] ?? [];
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
    _refreshController.refreshCompleted();
  }

  Widget _buildCustomAppBar(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Image.asset('assets/images/logo.png', height: 40, width: 200),
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
            const SizedBox(height: 24),
            const Text(
              'Aplikasi Krani Makassar',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const Text(
              'Bongkar Container',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContainerList() {
    final theme = Theme.of(context);

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_shippedContainers.isEmpty) {
      return SmartRefresher(
        controller: _refreshController,
        onRefresh: _fetchContainers,
        child: Center(
          child: Text(
            "Tidak ada container",
            style: theme.textTheme.titleMedium!.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
        ),
      );
    }

    return SmartRefresher(
      controller: _refreshController,
      onRefresh: _fetchContainers,
      child: ListView.builder(
        itemCount: _shippedContainers.length,
        itemBuilder: (context, index) {
          final container = _shippedContainers[index];

          return Card(
            margin: EdgeInsets.only(
              left: 16,
              right: 16,
              top: index == 0 ? 16 : 8,
              bottom: 8,
            ),
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              title: Text(
                '${container['container_number'] ?? '-'}',
                style: theme.textTheme.titleMedium!.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 10),
                  Text('Seal 1: ${container['seal_number'] ?? '-'}'),
                  Text('Seal 2: ${container['seal_number2'] ?? '-'}'),
                  const SizedBox(height: 10),
                  Text('Ready to Unload'),
                ],
              ),
              trailing: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed:
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (context) => ScanKraniMks(
                              containerId:
                                  container['container_id']?.toString() ?? '',
                            ),
                      ),
                    ).then((_) => _fetchContainers()),
                child: const Text(
                  "Proses",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(150.0),
        child: SafeArea(child: _buildCustomAppBar(context)),
      ),
      body: _buildContainerList(),
    );
  }
}
