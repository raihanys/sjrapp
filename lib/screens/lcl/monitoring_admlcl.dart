import 'package:flutter/material.dart';
import 'detail_monitoring_admlcl.dart';
import '../../services/auth_service.dart';
import '../../services/lcl_service.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import 'main_admlcl.dart';
import 'package:intl/intl.dart';

class MonitoringAdmLCL extends StatefulWidget {
  const MonitoringAdmLCL({Key? key}) : super(key: key);

  @override
  _MonitoringAdmLCLState createState() => _MonitoringAdmLCLState();
}

class _MonitoringAdmLCLState extends State<MonitoringAdmLCL> {
  late AuthService _authService;
  late LCLService _lclService;
  List<Map<String, dynamic>> _lpbList = [];
  bool _isLoading = true;
  String? _username;

  // 0 = Warehouse, 1 = Container. Digunakan untuk BottomNavigationBar index.
  int _selectedTab = 0;

  final RefreshController _refreshController = RefreshController(
    initialRefresh: false,
  );
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _filteredLpbList = [];

  void _backToMainLCL() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const MainLCL()),
    );
  }

  @override
  void initState() {
    super.initState();
    _authService = AuthService();
    _lclService = LCLService();
    _fetchUsernameAndData();
  }

  Future<void> _fetchUsernameAndData() async {
    _username = await _authService.getUsername();
    _fetchLPBData();
  }

  Future<void> _fetchLPBData() async {
    setState(() => _isLoading = true);
    try {
      if (_username == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Gagal mendapatkan username!')),
          );
        }
        setState(() => _isLoading = false);
        return;
      }

      final allData = await _lclService.getLPBHeaderAll();

      if (allData != null) {
        final filteredData =
            allData.where((item) {
              final petugas = item['petugas']?.toString().toLowerCase() ?? '';
              return petugas == _username!.toLowerCase();
            }).toList();

        if (mounted) {
          setState(() {
            _lpbList = filteredData;
            // Terapkan filter list awal jika ada teks pencarian
            _filterList(_searchController.text);
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _lpbList = [];
            _filteredLpbList = [];
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _onRefresh() async {
    await _fetchLPBData();
    _refreshController.refreshCompleted();
  }

  void _filterList(String query) {
    if (_lpbList.isEmpty) return;

    setState(() {
      if (query.isEmpty) {
        _filteredLpbList = _lpbList;
      } else {
        _filteredLpbList =
            _lpbList.where((item) {
              final noLpb = item['no_lpb']?.toString().toLowerCase() ?? '';
              final sender = item['sender']?.toString().toLowerCase() ?? '';
              final receiver = item['receiver']?.toString().toLowerCase() ?? '';
              return noLpb.contains(query.toLowerCase()) ||
                  sender.contains(query.toLowerCase()) ||
                  receiver.contains(query.toLowerCase());
            }).toList();
      }
    });
  }

  // Helper untuk mendapatkan list final berdasarkan Tab yang dipilih dan hasil pencarian
  List<Map<String, dynamic>> get _tabFilteredList {
    return _filteredLpbList.where((item) {
      // Cek apakah item punya container_id dan tidak kosong
      bool hasContainer =
          item['container_id'] != null &&
          item['container_id'].toString().isNotEmpty;

      if (_selectedTab == 0) {
        // Tab Warehouse: Tampilkan yg TIDAK punya container
        return !hasContainer;
      } else {
        // Tab Container: Tampilkan yg PUNYA container
        return hasContainer;
      }
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(150.0),
        child: SafeArea(child: _buildCustomAppBar(context)),
      ),
      // Body diisi dengan SmartRefresher dan list item
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SmartRefresher(
                controller: _refreshController,
                onRefresh: _onRefresh,
                child: ListView(
                  // Menggunakan padding standard
                  padding: const EdgeInsets.only(
                    top: 16,
                    left: 16,
                    right: 16,
                    bottom: 16,
                  ),
                  children: _buildListItems(),
                ),
              ),

      // Menggunakan bottomNavigationBar untuk Floating Tab Bar
      bottomNavigationBar: _buildFloatingNavBar(Theme.of(context)),

      floatingActionButton: FloatingActionButton(
        onPressed: _backToMainLCL,
        tooltip: 'Kembali ke Menu Utama',
        backgroundColor: Theme.of(context).primaryColor,
        child: const Icon(Icons.arrow_back, color: Colors.white),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.miniStartFloat,
    );
  }

  // --- Widget Baru untuk Floating Tab Bar (mengikuti gaya main_invoicer) ---
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
          currentIndex: _selectedTab,
          onTap: (index) => setState(() => _selectedTab = index),
          backgroundColor: theme.colorScheme.surface,
          selectedItemColor: theme.colorScheme.primary,
          unselectedItemColor: theme.colorScheme.onSurface.withOpacity(0.6),
          showSelectedLabels: true,
          showUnselectedLabels: true,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.warehouse_outlined),
              activeIcon: Icon(Icons.warehouse),
              label: 'Warehouse',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.local_shipping_outlined),
              activeIcon: Icon(Icons.local_shipping),
              label: 'Container',
            ),
          ],
        ),
      ),
    );
  }
  // ------------------------------------------------------------------------

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
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Image.asset('assets/images/logo.png', height: 40, width: 200),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Aplikasi LCL',
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                      Text(
                        'Monitoring Scan',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Cari LPB...',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                      suffixIcon:
                          _searchController.text.isNotEmpty
                              ? IconButton(
                                icon: const Icon(Icons.clear, size: 20),
                                onPressed: () {
                                  _searchController.clear();
                                  _filterList('');
                                },
                              )
                              : null,
                    ),
                    onChanged: _filterList,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      margin: const EdgeInsets.only(right: 8),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$label: $value',
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 12,
          color: Colors.black87,
        ),
      ),
    );
  }

  List<Widget> _buildListItems() {
    final displayList = _tabFilteredList;

    if (displayList.isEmpty) {
      return [
        const SizedBox(height: 50),
        Center(
          child: Text(
            // Tampilkan pesan yang relevan berdasarkan tab yang dipilih
            "Tidak ada data ${_selectedTab == 0 ? 'Warehouse' : 'Container'} untuk Anda.",
            style: const TextStyle(color: Colors.grey),
          ),
        ),
      ];
    }

    String formatDate(String? dateString) {
      if (dateString == null || dateString.isEmpty) return '-';
      try {
        final date = DateTime.parse(dateString);
        return DateFormat('dd MMMM yyyy').format(date);
      } catch (e) {
        return '-';
      }
    }

    String formatTime(String? dateString) {
      if (dateString == null || dateString.isEmpty) return '-';
      try {
        final date = DateTime.parse(dateString);
        return DateFormat('HH:mm').format(date);
      } catch (e) {
        return '-';
      }
    }

    // Menggunakan kode Card yang sama persis seperti sebelumnya (tidak diubah)
    return displayList.map((item) {
      return Card(
        margin: const EdgeInsets.only(bottom: 16),
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      item['no_lpb'] ?? 'No LPB',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Pengirim: ${item['sender'] ?? '-'}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Penerima: ${item['receiver'] ?? '-'}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Petugas: ${item['petugas'] ?? '-'}',
                style: const TextStyle(fontSize: 14),
              ),
              if (_selectedTab == 0) ...[
                Text(
                  'Tanggal: ${formatDate(item['warehouse_scanned_date'])}',
                  style: const TextStyle(fontSize: 14),
                ),
                Text(
                  'Waktu: ${formatTime(item['warehouse_scanned_date'])}',
                  style: const TextStyle(fontSize: 14),
                ),
              ],
              if (_selectedTab == 1) ...[
                Text(
                  'Tanggal: ${formatDate(item['container_scanned_date'])}',
                  style: const TextStyle(fontSize: 14),
                ),
                Text(
                  'Waktu: ${formatTime(item['container_scanned_date'])}',
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 12),
                Text(
                  'Container: ${item['container_number'] ?? '-'}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 8.0,
                      runSpacing: 8.0,
                      children: [
                        _buildInfoChip(
                          'QTY',
                          '${item['total_item'] ?? '0'} item',
                        ),
                        _buildInfoChip('Berat', '${item['weight'] ?? '0'} kg'),
                        _buildInfoChip('Volume', '${item['volume'] ?? '0'} m3'),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red[300],
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (context) => DetailMonitoringAdmLCL(
                                noLpb: item['no_lpb'],
                                totalQty: '${item['total_item'] ?? '0'} item',
                                totalWeight: '${item['weight'] ?? '0'} kg',
                                totalVolume: '${item['volume'] ?? '0'} m3',
                              ),
                        ),
                      ).then((shouldRefresh) {
                        if (shouldRefresh == true) {
                          _fetchLPBData();
                        }
                      });
                    },
                    child: const Text("View"),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }).toList();
  }
}
