import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';

class ArchivePelabuhan extends StatelessWidget {
  final List<dynamic> orders;
  final Function onOrderUpdated;
  final RefreshController _refreshController;

  void _showDetailModal(BuildContext context, dynamic order) {
    final theme = Theme.of(context);

    String formattedDate = '-';
    String formattedTime = '-';

    final rawDate = order['tgl_rc_dibuat'];
    final rawTime = order['jam_rc_dibuat'];

    if (rawDate != null) {
      final parsedDate = DateTime.tryParse(rawDate);
      if (parsedDate != null) {
        formattedDate = DateFormat('dd/MM/yyyy').format(parsedDate);
      }
    }

    if (rawTime != null) {
      try {
        final parsedTime = DateFormat('HH:mm:ss').parse(rawTime);
        formattedTime = DateFormat('HH:mm').format(parsedTime);
      } catch (_) {}
    }

    final items = [
      {'label': 'Nomor RO', 'value': order['no_ro'] ?? '-'},
      {'label': 'Tujuan', 'value': order['destination_name'] ?? '-'},
      {'label': 'Supir', 'value': order['driver_name'] ?? '-'},
      {'label': 'Nopol', 'value': order['truck_name'] ?? '-'},
      {'label': 'Pabrik', 'value': order['sender_name'] ?? '-'},
      {'label': 'Kapal', 'value': order['nama_kapal'] ?? '-'},
      {'label': 'Voyage', 'value': order['nomor_voy'] ?? '-'},
      {'label': 'Pelayaran', 'value': order['nama_pelayaran'] ?? '-'},
      {'label': 'Nomor Kontainer', 'value': order['container_num'] ?? '-'},
      {'label': 'Nomor Segel 1', 'value': order['seal_number'] ?? '-'},
      {
        'label': 'Nomor Segel 2',
        'value':
            (order['seal_number2'] != null &&
                    order['seal_number2'].toString().trim().isNotEmpty)
                ? order['seal_number2']
                : '-',
      },
      {'label': 'Tanggal RC Diproses', 'value': formattedDate},
      {'label': 'Waktu RC Diproses', 'value': formattedTime},
      {'label': 'Petugas', 'value': order['agent'] ?? '-'},
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 15),
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text('Detail Order', style: theme.textTheme.titleLarge),
                const SizedBox(height: 20),

                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children:
                      items.map((item) {
                        return IntrinsicWidth(
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color.fromARGB(255, 236, 212, 212),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item['label']!,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.black54,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  item['value']!,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                ),

                const SizedBox(height: 16),

                Text(
                  'Foto RC',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),

                if (order['foto_rc_url'] != null &&
                    order['foto_rc_url'].toString().isNotEmpty)
                  Column(
                    children: [
                      GestureDetector(
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (context) {
                              return Dialog(
                                insetPadding: const EdgeInsets.all(16),
                                backgroundColor: Colors.transparent,
                                child: Stack(
                                  children: [
                                    InteractiveViewer(
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: Image.network(
                                          order['foto_rc_url'].toString(),
                                          fit: BoxFit.contain,
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      top: 10,
                                      right: 10,
                                      child: ElevatedButton(
                                        onPressed:
                                            () => Navigator.of(context).pop(),
                                        style: ElevatedButton.styleFrom(
                                          shape: const CircleBorder(),
                                          backgroundColor: Colors.red,
                                          padding: const EdgeInsets.all(10),
                                        ),
                                        child: const Icon(
                                          Icons.close,
                                          color: Colors.white,
                                          size: 24,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          );
                        },
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            order['foto_rc_url'].toString(),
                            height: 150,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder:
                                (context, error, stackTrace) => const Center(
                                  child: Icon(Icons.broken_image),
                                ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            'Tutup',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  )
                else
                  Container(
                    width: double.infinity,
                    height: 100,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: Text(
                        'Tidak ada foto',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  ArchivePelabuhan({
    Key? key,
    required this.orders,
    required this.onOrderUpdated,
  }) : _refreshController = RefreshController(),
       super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (orders.isEmpty) {
      return Center(
        child: Text(
          "Tidak ada data",
          style: theme.textTheme.titleMedium!.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(0.6),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: SmartRefresher(
            controller: _refreshController,
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
                        "Memuat data archive...",
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
                return Container(height: 60, child: Center(child: body));
              },
            ),
            onRefresh: () async {
              await onOrderUpdated();
              _refreshController.refreshCompleted();
            },
            child: ListView.builder(
              itemCount: orders.length,
              itemBuilder: (context, index) {
                final order = orders[index];
                final roNumber = order['no_ro'] ?? '-';
                final user = order['agent'];
                final nopol = order['truck_name'] ?? '-';
                final driverName = order['driver_name'] ?? '-';
                final rawDate = order['tgl_rc_dibuat'];
                final rawTime = order['jam_rc_dibuat'];

                String formattedDate = '-';
                String formattedTime = '-';

                if (rawDate != null) {
                  final parsedDate = DateTime.tryParse(rawDate);
                  if (parsedDate != null) {
                    formattedDate = DateFormat('dd/MM/yyyy').format(parsedDate);
                  }
                }

                if (rawTime != null) {
                  try {
                    final parsedTime = DateFormat('HH:mm:ss').parse(rawTime);
                    formattedTime = DateFormat('HH:mm').format(parsedTime);
                  } catch (_) {}
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
                  child: ListTile(
                    onTap: () => _showDetailModal(context, order),
                    contentPadding: const EdgeInsets.all(16),
                    title: Text(
                      'Nomor RO: $roNumber',
                      style: theme.textTheme.titleMedium,
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(
                              Icons.local_shipping,
                              size: 16,
                              color: Colors.grey,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Nopol: $nopol',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            const Icon(
                              Icons.person,
                              size: 16,
                              color: Colors.grey,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Supir: $driverName',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            const Icon(
                              Icons.calendar_today,
                              size: 16,
                              color: Colors.grey,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Tanggal RC Diproses: $formattedDate',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            const Icon(
                              Icons.access_time,
                              size: 16,
                              color: Colors.grey,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Jam RC Diproses: $formattedTime',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Diproses oleh: $user',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
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
