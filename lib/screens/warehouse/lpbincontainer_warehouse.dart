import 'package:flutter/material.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import '../../services/warehouse_service.dart';
import 'itemlpb_warehouse.dart';
import 'package:intl/intl.dart';

class LpbInContainerWarehouse extends StatefulWidget {
  final String containerId;
  final String containerNumber;

  const LpbInContainerWarehouse({
    Key? key,
    required this.containerId,
    required this.containerNumber,
  }) : super(key: key);

  @override
  _LpbInContainerWarehouseState createState() =>
      _LpbInContainerWarehouseState();
}

class _LpbInContainerWarehouseState extends State<LpbInContainerWarehouse> {
  final WarehouseService _warehouseService = WarehouseService();
  List<Map<String, dynamic>> _lpbList = [];
  List<Map<String, dynamic>> _filteredLpbList = [];
  bool _isLoading = true;

  final RefreshController _refreshController = RefreshController();
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchLPBData();
  }

  Future<void> _fetchLPBData() async {
    setState(() => _isLoading = true);
    try {
      final allData = await _warehouseService.getLPBHeaderAll();
      if (allData != null) {
        final filteredData =
            allData.where((item) {
              return item['container_id']?.toString() == widget.containerId;
            }).toList();

        if (mounted) {
          setState(() {
            _lpbList = filteredData;
            _filteredLpbList = _lpbList;
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
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onRefresh() async {
    await _fetchLPBData();
    _refreshController.refreshCompleted();
  }

  void _filterList(String query) {
    setState(() {
      _filteredLpbList =
          _lpbList.where((item) {
            final noLpb = item['no_lpb']?.toString().toLowerCase() ?? '';
            final sender = item['sender']?.toString().toLowerCase() ?? '';
            final receiver = item['receiver']?.toString().toLowerCase() ?? '';
            return noLpb.contains(query.toLowerCase()) ||
                sender.contains(query.toLowerCase()) ||
                receiver.contains(query.toLowerCase());
          }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(150.0),
        child: SafeArea(child: _buildCustomAppBar(context)),
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SmartRefresher(
                controller: _refreshController,
                onRefresh: _onRefresh,
                child: _buildContent(),
              ),
    );
  }

  Widget _buildCustomAppBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Image.asset('assets/images/logo.png', height: 40, width: 200),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Aplikasi Kepala Gudang',
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                    Text(
                      widget.containerNumber,
                      style: const TextStyle(
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
    );
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

  Widget _buildContent() {
    if (_filteredLpbList.isEmpty) {
      return const Center(child: Text("Tidak ada data LPB di kontainer ini"));
    }
    // Ganti _lpbList menjadi _filteredLpbList
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredLpbList.length,
      itemBuilder: (context, index) {
        final item = _filteredLpbList[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['no_lpb'] ?? 'No LPB',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
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
                Text(
                  'Tanggal: ${formatDate(item['container_scanned_date'])}',
                  style: const TextStyle(fontSize: 14),
                ),
                Text(
                  'Waktu: ${formatTime(item['container_scanned_date'])}',
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                          _buildInfoChip(
                            'Berat',
                            '${item['weight'] ?? '0'} kg',
                          ),
                          _buildInfoChip(
                            'Volume',
                            '${item['volume'] ?? '0'} m3',
                          ),
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
                                (context) => ItemLpbWarehouse(
                                  noLpb: item['no_lpb'],
                                  totalQty: '${item['total_item'] ?? '0'} item',
                                  totalWeight: '${item['weight'] ?? '0'} kg',
                                  totalVolume: '${item['volume'] ?? '0'} m3',
                                ),
                          ),
                        ).then((_) => _onRefresh());
                      },
                      child: const Text("View"),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
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
}
