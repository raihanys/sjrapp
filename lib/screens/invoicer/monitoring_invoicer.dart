import 'package:flutter/material.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import 'package:intl/intl.dart';
import '../../services/auth_service.dart';
import '../../services/invoicer_service.dart';

class MonitoringInvoicer extends StatefulWidget {
  final String? invoicingCode;

  const MonitoringInvoicer({Key? key, required this.invoicingCode})
    : super(key: key);

  @override
  State<MonitoringInvoicer> createState() => _MonitoringInvoicerState();
}

class _MonitoringInvoicerState extends State<MonitoringInvoicer> {
  final RefreshController _refreshController = RefreshController();
  final TextEditingController _searchController = TextEditingController();

  // TAMBAHKAN SERVICE
  final AuthService _authService = AuthService();
  late InvoicerService _invoicerService;

  List<dynamic> _monitoringList = [];
  List<dynamic> _filteredMonitoringList = [];
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    // INISIALISASI SERVICE
    _invoicerService = InvoicerService(_authService);
    _loadMonitoringData();
  }

  void _filterList(String query) {
    setState(() {
      _filteredMonitoringList =
          _monitoringList.where((item) {
            final codeNumber =
                item['code_number']?.toString().toLowerCase() ?? '';
            final clientName = item['client']?.toString().toLowerCase() ?? '';

            return codeNumber.contains(query.toLowerCase()) ||
                clientName.contains(query.toLowerCase());
          }).toList();
    });
  }

  Future<void> _loadMonitoringData() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });

      final data = await _invoicerService.fetchMonitoringTagihan();

      setState(() {
        _monitoringList = data;
        _filteredMonitoringList = data;
        if (_searchController.text.isNotEmpty) {
          _filterList(_searchController.text);
        }
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  // Helper untuk memberi warna pada status
  Color _getStatusColor(String? status) {
    if (status == null) return Colors.grey;

    switch (status.toLowerCase()) {
      case 'terkonfirmasi lunas':
        return Colors.green;
      case 'lunas':
        return Colors.orange;
      case 'lunas gudang':
        return Colors.orange;
      case 'lunas makassar':
        return Colors.orange;
      case 'belum lunas/selisih':
        return Colors.deepOrange;
      case 'CST terkirim':
        return Colors.blue;
      case 'Faktur terkirim':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  // Helper baru untuk label PPN/Non-PPN
  Widget _buildTypeChip(String type) {
    String label;
    Color color;

    if (type == 'INVOICE') {
      label = 'PPN';
      color = Colors.blue[100]!;
    } else if (type == 'CST') {
      label = 'Non-PPN';
      color = Colors.teal[100]!;
    } else {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          color: Colors.black87,
          fontSize: 12,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final location = widget.invoicingCode == '1' ? 'Jakarta' : 'Makassar';
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Error: $_errorMessage',
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadMonitoringData,
              child: const Text('Coba Lagi'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Judul
              Expanded(
                flex: 4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Invoicer $location',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const Text(
                      'Monitoring',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 6,
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Cari...',
                    isDense: true,
                    prefixIcon: const Icon(Icons.search, size: 20),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 10,
                      horizontal: 10,
                    ),
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
          child: SmartRefresher(
            controller: _refreshController,
            enablePullDown: true,
            enablePullUp: false,
            onRefresh: () async {
              await _loadMonitoringData();
              _refreshController.refreshCompleted();
            },
            child:
                _filteredMonitoringList.isEmpty
                    ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(height: 16),
                          Text(
                            "Tidak ada data untuk di-monitoring",
                            style: theme.textTheme.titleMedium!.copyWith(
                              color: theme.colorScheme.onSurface.withOpacity(
                                0.6,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                    : ListView.builder(
                      itemCount: _filteredMonitoringList.length,
                      itemBuilder: (context, index) {
                        final item = _filteredMonitoringList[index];

                        // --- AMBIL DATA DARI API ---
                        final codeNumber = item['code_number'] ?? '-';
                        final clientName = item['client'] ?? '-';
                        final clientContact = item['client_contact'] ?? '';
                        final total = item['total'] ?? '0';
                        final dateDibuat = item['tanggal_dibuat'];
                        final dateDitugaskan = item['tanggal_ditugaskan'];
                        final dateDikirim = item['tanggal_dikirim'];
                        final dateDibayar = item['tanggal_dibayar'];
                        final dateDikonfirmasi = item['tanggal_dikonfirmasi'];
                        final status = item['STATUS'] ?? '-';
                        final type = item['type'] ?? ''; // 'INVOICE' or 'CST'

                        // Format currency
                        final formatter = NumberFormat.currency(
                          locale: 'id_ID',
                          symbol: 'Rp. ',
                          decimalDigits: 0,
                        );
                        final formattedTotal = formatter.format(
                          int.tryParse(total) ?? 0,
                        );

                        String? formatDate(String? dateString) {
                          if (dateString == null || dateString.isEmpty)
                            return '-';

                          try {
                            final date = DateTime.parse(dateString);
                            return DateFormat('dd MMMM yyyy').format(date);
                          } catch (e) {
                            return dateString; // fallback kalau format tidak sesuai
                          }
                        }

                        return Card(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Stack(
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            codeNumber,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                        _buildTypeChip(type),
                                      ],
                                    ),
                                    const SizedBox(height: 8),

                                    // Info Klien
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment
                                              .start, // <-- INI WAJIB
                                      children: [
                                        const Text(
                                          'Kepada : ',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Expanded(
                                          child: Text(
                                            clientName,
                                            style: theme.textTheme.titleSmall!
                                                .copyWith(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                            maxLines: 3,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        const Text('Kontak : '),
                                        Expanded(
                                          child: Text(
                                            clientContact,
                                            maxLines: 2,
                                          ),
                                        ),
                                      ],
                                    ),

                                    const Divider(height: 20),

                                    // Detail
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            'tgl. Diterbitkan : ${formatDate(dateDibuat)}',
                                            style: theme.textTheme.bodySmall,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            'tgl. Ditugaskan : ${formatDate(dateDitugaskan)}',
                                            style: theme.textTheme.bodySmall,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            'tgl. Dikirim : ${formatDate(dateDikirim)}',
                                            style: theme.textTheme.bodySmall,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            'tgl. Dibayar : ${formatDate(dateDibayar)}',
                                            style: theme.textTheme.bodySmall,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            'tgl. Dikonfirmasi : ${formatDate(dateDikonfirmasi)}',
                                            style: theme.textTheme.bodySmall,
                                          ),
                                        ),
                                      ],
                                    ),

                                    const Divider(height: 20),

                                    // Total
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            'Total : $formattedTotal',
                                            style: theme.textTheme.titleSmall!
                                                .copyWith(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                          ),
                                        ),
                                      ],
                                    ),

                                    const SizedBox(height: 4),

                                    // Status
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            'Status : $status',
                                            style: theme.textTheme.titleSmall!
                                                .copyWith(
                                                  color: _getStatusColor(
                                                    status,
                                                  ),
                                                  fontWeight: FontWeight.bold,
                                                ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
          ),
        ),
      ],
    );
  }
}
