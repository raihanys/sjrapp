import 'package:flutter/material.dart';
import '../../services/lcl_service.dart';

class DetailMonitoringAdmLCL extends StatefulWidget {
  final String noLpb;
  final String totalQty;
  final String totalWeight;
  final String totalVolume;

  const DetailMonitoringAdmLCL({
    Key? key,
    required this.noLpb,
    required this.totalQty,
    required this.totalWeight,
    required this.totalVolume,
  }) : super(key: key);

  @override
  _DetailMonitoringAdmLCLState createState() => _DetailMonitoringAdmLCLState();
}

class _DetailMonitoringAdmLCLState extends State<DetailMonitoringAdmLCL> {
  late LCLService _lclService;
  List<Map<String, dynamic>> _items = [];
  bool _isLoading = true;
  List<bool> _checkedItems = [];

  @override
  void initState() {
    super.initState();
    _lclService = LCLService();
    _fetchItems();
  }

  Future<void> _fetchItems() async {
    setState(() => _isLoading = true);
    try {
      final items = await _lclService.getLPBItemDetail(widget.noLpb);
      if (mounted) {
        setState(() {
          _items = items ?? [];
          _checkedItems =
              _items.map((item) {
                final status = item['status_kondisi_barang']?.toString() ?? '';

                final isStatusUnwanted =
                    status == 'Barang Kurang' ||
                    status == 'Rusak Tidak Dikirim';

                final length =
                    double.tryParse(item['length']?.toString() ?? '0') ?? 0;
                final width =
                    double.tryParse(item['width']?.toString() ?? '0') ?? 0;
                final height =
                    double.tryParse(item['height']?.toString() ?? '0') ?? 0;
                final weight =
                    double.tryParse(item['weight']?.toString() ?? '0') ?? 0;
                final volume =
                    double.tryParse(item['volume']?.toString() ?? '0') ?? 0;

                return length > 0 &&
                    width > 0 &&
                    height > 0 &&
                    weight > 0 &&
                    volume > 0 &&
                    !isStatusUnwanted;
              }).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memuat detail: ${e.toString()}')),
        );
      }
    }
  }

  Widget _buildInfoChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      margin: const EdgeInsets.only(right: 8, bottom: 8),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.shade100!),
      ),
      child: Text(
        '$label: $value',
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 16,
          color: Colors.black87,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(150.0),
        child: SafeArea(
          child: Container(
            decoration: const BoxDecoration(),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 12.0,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Image.asset(
                        'assets/images/logo.png',
                        height: 40,
                        width: 200,
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Aplikasi LCL',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  Text(
                    widget.noLpb,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Daftar Barang',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SingleChildScrollView(
                          child: Table(
                            columnWidths: const {
                              0: FixedColumnWidth(60),
                              1: FixedColumnWidth(160),
                              2: FixedColumnWidth(70),
                              3: FixedColumnWidth(70),
                              4: FixedColumnWidth(70),
                              5: FixedColumnWidth(70),
                              6: FixedColumnWidth(100),
                              7: FixedColumnWidth(120),
                              8: FixedColumnWidth(79),
                              9: FixedColumnWidth(60),
                            },
                            border: TableBorder.all(
                              color: Colors.grey.shade300,
                              width: 1,
                            ),
                            children: [
                              TableRow(
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade200,
                                ),
                                children: const [
                                  _HeaderCell('No'),
                                  _HeaderCell('Kode Barang', alignLeft: true),
                                  _HeaderCell('P'),
                                  _HeaderCell('L'),
                                  _HeaderCell('T'),
                                  _HeaderCell('Berat'),
                                  _HeaderCell('Volume'),
                                  _HeaderCell('Status'),
                                  _HeaderCell('Petugas'),
                                  _HeaderCell(''),
                                ],
                              ),
                              ...List.generate(_items.length, (index) {
                                final item = _items[index];
                                return TableRow(
                                  decoration: BoxDecoration(
                                    color:
                                        index.isEven
                                            ? Colors.white
                                            : Colors.grey.shade50,
                                  ),
                                  children: [
                                    _BodyCell('${index + 1}'),
                                    _BodyCell(
                                      item['barang_kode'] ?? '-',
                                      alignLeft: true,
                                    ),
                                    _BodyCell(
                                      item['length']?.toString() ?? '-',
                                    ),
                                    _BodyCell(item['width']?.toString() ?? '-'),
                                    _BodyCell(
                                      item['height']?.toString() ?? '-',
                                    ),
                                    _BodyCell(
                                      item['weight']?.toString() ?? '-',
                                    ),
                                    _BodyCell(
                                      item['volume']?.toString() ?? '-',
                                    ),
                                    _BodyCell(
                                      item['status_kondisi_barang']
                                              ?.toString() ??
                                          '-',
                                    ),
                                    _BodyCell(item['petugas'] ?? '-'),
                                    Container(
                                      height: 72,
                                      alignment: Alignment.center,
                                      child: Checkbox(
                                        value: _checkedItems[index],
                                        onChanged: null,
                                        activeColor: Colors.green,
                                      ),
                                    ),
                                  ],
                                );
                              }),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Wrap(
                      spacing: 8.0,
                      runSpacing: 8.0,
                      children: [
                        _buildInfoChip('Total QTY', widget.totalQty),
                        _buildInfoChip('Total Berat', widget.totalWeight),
                        _buildInfoChip('Total Volume', widget.totalVolume),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context, false),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text('Kembali'),
                      ),
                    ),
                  ],
                ),
              ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  const _HeaderCell(this.text, {this.alignLeft = false});
  final String text;
  final bool alignLeft;

  @override
  Widget build(BuildContext context) => Container(
    height: 48,
    alignment: alignLeft ? Alignment.centerLeft : Alignment.center,
    padding: const EdgeInsets.symmetric(horizontal: 8.0),
    child: Text(
      text,
      style: const TextStyle(fontWeight: FontWeight.bold),
      textAlign: alignLeft ? TextAlign.left : TextAlign.center,
    ),
  );
}

class _BodyCell extends StatelessWidget {
  const _BodyCell(this.text, {this.alignLeft = false});
  final String text;
  final bool alignLeft;

  @override
  Widget build(BuildContext context) => Container(
    height: 72,
    alignment: alignLeft ? Alignment.centerLeft : Alignment.center,
    padding: const EdgeInsets.symmetric(horizontal: 8.0),
    child: Text(text, textAlign: alignLeft ? TextAlign.left : TextAlign.center),
  );
}
