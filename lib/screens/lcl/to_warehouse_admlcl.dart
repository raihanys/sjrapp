import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../services/lcl_service.dart';

class ToWarehouseScreen extends StatefulWidget {
  const ToWarehouseScreen({super.key});

  @override
  State<ToWarehouseScreen> createState() => _ToWarehouseScreenState();
}

class _ToWarehouseScreenState extends State<ToWarehouseScreen> {
  final MobileScannerController _controller = MobileScannerController();
  bool _isFlashOn = false;
  bool _isLoading = false;
  String? _scannedBarcode;

  final LCLService _lclService = LCLService();
  String? _codeBarang;

  String _getLpbHeader(String fullBarcode) {
    int lastSlashIndex = fullBarcode.lastIndexOf('/');
    if (lastSlashIndex != -1) {
      return fullBarcode.substring(0, lastSlashIndex);
    }
    return fullBarcode;
  }

  Future<bool> _checkLpbCompletion(String lpbHeader) async {
    final lpbInfo = await _lclService.getLPBInfo(lpbHeader);

    if (lpbInfo == null || lpbInfo['items'] is! List) {
      return false;
    }

    final List<dynamic> items = lpbInfo['items'];
    if (items.isEmpty) return false;

    bool hasPendingItem = items.any((item) {
      final String statusBarang = item['status_barang']?.toString() ?? '';
      final dynamic statusPenerimaan = item['status_penerimaan_barang'];

      if (statusBarang == '1' && statusPenerimaan == null) {
        return true;
      }
      return false;
    });

    bool allComplete = items.every((item) {
      final String statusBarang = item['status_barang']?.toString() ?? '';
      return statusBarang == '4';
    });

    return !hasPendingItem && allComplete;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggleFlash() {
    setState(() {
      _isFlashOn = !_isFlashOn;
      _controller.toggleTorch();
    });
  }

  void _showErrorDialog(BuildContext context, String title, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              child: const Text('OK'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
                if (mounted) {
                  _scannedBarcode = null;
                  _controller.start();
                }
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _showConfirmationModal(
    BuildContext context,
    String scannedBarcode,
  ) async {
    if (_isFlashOn) {
      _controller.toggleTorch();
      setState(() => _isFlashOn = false);
    }

    setState(() {
      _isLoading = true;
      _scannedBarcode = scannedBarcode;
    });

    try {
      final lpbData = await _lclService.getLPBInfoDetail(scannedBarcode);
      setState(() => _isLoading = false);

      if (lpbData == null || lpbData['data'] == null) {
        _showErrorDialog(
          context,
          'Data Tidak Ditemukan',
          'Data barang tidak ditemukan',
        );
        return;
      }

      final data = lpbData['data'] as Map<String, dynamic>;
      final int status = int.tryParse(data['status']?.toString() ?? '0') ?? 0;

      if (status != 5) {
        _showErrorDialog(
          context,
          'Status Tidak Valid',
          'Status barang tidak valid untuk dikembalikan ke gudang.',
        );
        return;
      }

      _codeBarang = data['code_barang'] ?? '';

      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => _buildConfirmationDialog(context),
      );
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorDialog(context, 'Error', 'Terjadi kesalahan: ${e.toString()}');
    } finally {
      if (mounted) {
        _scannedBarcode = null;
        _codeBarang = null;
      }
    }
  }

  Widget _buildConfirmationDialog(BuildContext context) {
    return AlertDialog(
      title: const Text('Konfirmasi Update Status'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Kode Barang: $_codeBarang'),
          const SizedBox(height: 20),
          const Text('Ubah status dari Container ke Warehouse?'),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            if (mounted) _controller.start();
          },
          child: const Text('Batal'),
        ),
        TextButton(
          onPressed: () async {
            // 1. Set loading state
            setState(() => _isLoading = true);

            String? errorMessage;
            bool isSuccess = false;
            bool? isLpbComplete;
            String lpbHeader = '';

            final currentBarcode = _scannedBarcode;

            // 2. Lakukan semua validasi dan proses async di dalam satu blok try-catch
            try {
              if (currentBarcode == null) {
                throw Exception('Data barcode tidak valid.');
              }

              isSuccess = await _lclService.updateStatusToWarehouse(
                numberLpbItem: currentBarcode,
              );

              if (isSuccess) {
                lpbHeader = _getLpbHeader(currentBarcode);
                isLpbComplete = await _checkLpbCompletion(lpbHeader);
              } else {
                errorMessage = 'Gagal mengubah status barang.';
              }
            } catch (e) {
              errorMessage = 'Terjadi kesalahan: ${e.toString()}';
            }

            // 3. Hentikan loading state
            if (mounted) {
              setState(() => _isLoading = false);
            }

            // 4. Pastikan widget masih ada di tree SEBELUM melakukan navigasi
            if (!mounted) return;

            // 5. Tutup dialog konfirmasi (HANYA SATU KALI)
            Navigator.pop(context);

            // 6. Tampilkan dialog hasil berdasarkan variabel yang sudah disimpan
            if (isSuccess) {
              if (isLpbComplete == true) {
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder:
                      (context) => AlertDialog(
                        title: const Text('LPB Selesai'),
                        content: Text(
                          'Semua barang untuk LPB $lpbHeader telah selesai diproses.',
                        ),
                        actions: [
                          TextButton(
                            onPressed:
                                () => Navigator.of(
                                  context,
                                ).popUntil((route) => route.isFirst),
                            child: const Text('OK'),
                          ),
                        ],
                      ),
                );
              } else {
                showDialog(
                  context: context,
                  builder:
                      (context) => AlertDialog(
                        title: const Text('Berhasil'),
                        content: const Text(
                          'Status berhasil diubah dari Container ke Warehouse. Lanjutkan scan berikutnya.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                              if (mounted) _controller.start();
                            },
                            child: const Text('OK'),
                          ),
                        ],
                      ),
                );
              }
            } else {
              _showErrorDialog(
                context,
                'Gagal',
                errorMessage ?? 'Terjadi kesalahan tidak diketahui.',
              );
            }
          },
          child: const Text('Iya'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(150.0),
        child: SafeArea(
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 12.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset('assets/images/logo.png', height: 40, width: 200),
                const SizedBox(height: 24),
                const Text(
                  'Aplikasi LCL',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const Text(
                  'Container To Warehouse',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(bottom: 80),
              width: MediaQuery.of(context).size.width * 0.9,
              height: MediaQuery.of(context).size.height * 0.8,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey, width: 2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: MobileScanner(
                  controller: _controller,
                  onDetect: (capture) async {
                    if (_scannedBarcode != null) return;
                    final barcode = capture.barcodes.first.rawValue;
                    if (barcode != null) {
                      _controller.stop();
                      await _showConfirmationModal(context, barcode);
                    }
                  },
                ),
              ),
            ),
          ),
          Center(
            child: Container(
              width: MediaQuery.of(context).size.width * 0.6,
              height: MediaQuery.of(context).size.width * 0.6,
              margin: const EdgeInsets.only(bottom: 80),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.red, width: 4),
              ),
            ),
          ),
          if (_isLoading) const Center(child: CircularProgressIndicator()),
          Positioned(
            left: 16,
            bottom: 16,
            child: SafeArea(
              child: FloatingActionButton(
                heroTag: 'backButton',
                onPressed: () => Navigator.pop(context),
                child: const Icon(Icons.arrow_back),
              ),
            ),
          ),
          Positioned(
            right: 16,
            bottom: 16,
            child: SafeArea(
              child: FloatingActionButton(
                heroTag: 'flashButton',
                onPressed: _toggleFlash,
                child: Icon(_isFlashOn ? Icons.flash_off : Icons.flash_on),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
