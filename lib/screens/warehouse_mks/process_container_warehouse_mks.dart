import 'package:flutter/material.dart';
import 'dart:async';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import '../../services/warehouse_mks_service.dart';

class ProcessContainerWarehouseMks extends StatefulWidget {
  const ProcessContainerWarehouseMks({Key? key}) : super(key: key);

  @override
  State<ProcessContainerWarehouseMks> createState() =>
      _ProcessContainerWarehouseMks();
}

class _ProcessContainerWarehouseMks
    extends State<ProcessContainerWarehouseMks> {
  final WarehouseMksService _warehouseMksService = WarehouseMksService();
  List<dynamic> _closingContainers = [];
  bool _isLoading = true;
  final RefreshController _refreshController = RefreshController();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _fetchContainers();
    _timer = Timer.periodic(const Duration(minutes: 10), (timer) {
      _fetchContainers();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _fetchContainers() async {
    setState(() => _isLoading = true);
    final data = await _warehouseMksService.getContainers();

    setState(() {
      if (data != null && data['data'] != null) {
        _closingContainers = data['data']['container_received'] ?? [];
      } else {
        _closingContainers = [];
      }
      _isLoading = false;
    });

    _refreshController.refreshCompleted();
  }

  // Future<void> _showConfirmationDialog(
  //   String containerId,
  //   String containerNumber,
  // ) async {
  //   return showDialog(
  //     context: context,
  //     barrierDismissible: false,
  //     builder: (BuildContext context) {
  //       return AlertDialog(
  //         title: const Text('Konfirmasi'),
  //         content: Text('Konfirmasi closing $containerNumber?'),
  //         actions: [
  //           TextButton(
  //             onPressed: () => Navigator.of(context).pop(),
  //             child: const Text('Batal'),
  //           ),
  //           TextButton(
  //             onPressed: () async {
  //               Navigator.of(context).pop();
  //               await _updateContainerToClose(containerId);
  //             },
  //             child: const Text('Iya'),
  //           ),
  //         ],
  //       );
  //     },
  //   );
  // }

  // Future<void> _updateContainerToClose(String containerId) async {
  //   final success = await _warehouseMksService.updateContainerToClose(
  //     containerId,
  //   );

  //   if (success) {
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       const SnackBar(content: Text('Status closing berhasil diupdate')),
  //     );

  //     await _fetchContainers();

  //     if (mounted) {
  //       setState(() {});
  //     }
  //   } else {
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       const SnackBar(content: Text('Gagal mengupdate status closing')),
  //     );
  //   }
  // }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_closingContainers.isEmpty) {
      return SmartRefresher(
        controller: _refreshController,
        onRefresh: _fetchContainers,
        child: Center(
          child: Text(
            "Tidak ada container yang sedang dalam proses bongkar",
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
        itemCount: _closingContainers.length,
        itemBuilder: (context, index) {
          final container = _closingContainers[index];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: ListTile(
                contentPadding: EdgeInsets.zero,
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
                    Text('Dalam Proses Bongkar'),
                  ],
                ),
                // trailing: ElevatedButton(
                //   onPressed:
                //       () => _showConfirmationDialog(
                //         container['container_id'].toString(),
                //         container['container_number'] ?? '-',
                //       ),
                //   style: ElevatedButton.styleFrom(
                //     backgroundColor: Colors.red,
                //     foregroundColor: Colors.white,
                //     padding: const EdgeInsets.symmetric(
                //       horizontal: 8,
                //       vertical: 12,
                //     ),
                //     shape: RoundedRectangleBorder(
                //       borderRadius: BorderRadius.circular(8),
                //     ),
                //   ),
                //   child: const Text("Closing"),
                // ),
              ),
            ),
          );
        },
      ),
    );
  }
}
