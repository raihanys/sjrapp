import 'package:flutter/material.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import '../../services/warehouse_service.dart';
import 'lpbincontainer_warehouse.dart';

class ContainerListWarehouse extends StatefulWidget {
  const ContainerListWarehouse({Key? key}) : super(key: key);

  @override
  _ContainerListWarehouseState createState() => _ContainerListWarehouseState();
}

class _ContainerListWarehouseState extends State<ContainerListWarehouse> {
  final WarehouseService _warehouseService = WarehouseService();
  List<Map<String, dynamic>> _containerList = [];
  List<Map<String, dynamic>> _filteredContainerList = [];
  bool _isLoading = true;

  final RefreshController _refreshController = RefreshController();
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchContainers();
  }

  Future<void> _fetchContainers() async {
    setState(() => _isLoading = true);
    try {
      final data = await _warehouseService.getContainerReady();
      if (mounted) {
        setState(() {
          _containerList = data ?? [];
          _filteredContainerList = _containerList;
        });
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
    await _fetchContainers();
    _refreshController.refreshCompleted();
  }

  void _filterList(String query) {
    setState(() {
      _filteredContainerList =
          _containerList.where((container) {
            final number =
                container['container_number']?.toString().toLowerCase() ?? '';
            final seal =
                container['seal_number']?.toString().toLowerCase() ?? '';
            return number.contains(query.toLowerCase()) ||
                seal.contains(query.toLowerCase());
          }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Aplikasi Kepala Gudang',
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                    Text(
                      'List Kontainer',
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
                    hintText: 'Cari No. Kontainer / Seal...',
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
        ),
        Expanded(
          child:
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : SmartRefresher(
                    controller: _refreshController,
                    onRefresh: _onRefresh,
                    child: _buildContent(),
                  ),
        ),
      ],
    );
  }

  Widget _buildContent() {
    if (_filteredContainerList.isEmpty) {
      return const Center(child: Text("Tidak ada data kontainer"));
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(
        16,
        8,
        16,
        16,
      ), // Padding atas dikurangi
      itemCount: _filteredContainerList.length,
      itemBuilder: (context, index) {
        final container = _filteredContainerList[index];
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
                  container['container_number'] ?? 'No. Container',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                Text('No. Seal 1: ${container['seal_number'] ?? '-'}'),
                Text('No. Seal 2: ${container['seal_number2'] ?? '-'}'),
                const SizedBox(height: 16),
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
                            '${container['qty'] ?? '0'} item',
                          ),
                          _buildInfoChip(
                            'Berat',
                            '${container['weight'] ?? '0'} kg',
                          ),
                          _buildInfoChip(
                            'Volume',
                            '${container['volume'] ?? '0'} m3',
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
                                (context) => LpbInContainerWarehouse(
                                  containerId: container['container_id'],
                                  containerNumber:
                                      container['container_number'],
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
