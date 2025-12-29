import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/lcl_service.dart';

// Model untuk Sugesti Kontainer
class ContainerSuggestion {
  final String id;
  final String number;

  ContainerSuggestion({required this.id, required this.number});

  factory ContainerSuggestion.fromJson(Map<String, dynamic> json) {
    return ContainerSuggestion(
      id: (json['container_id'] ?? '').toString(),
      number: (json['container_number'] ?? '').toString(),
    );
  }
}

class ReadyToShipScreen extends StatefulWidget {
  const ReadyToShipScreen({super.key});

  @override
  State<ReadyToShipScreen> createState() => _ReadyToShipScreenState();
}

class _ReadyToShipScreenState extends State<ReadyToShipScreen> {
  final MobileScannerController _controller = MobileScannerController();
  bool _isFlashOn = false;
  bool _isLoading = false;
  String? _scannedBarcode;

  final LCLService _lclService = LCLService();
  String? _codeBarang;

  // State dan controller untuk kontainer
  final TextEditingController _containerSearchController =
      TextEditingController();
  String? _selectedContainerId;
  String? _selectedContainerNumber;
  List<ContainerSuggestion> _containerSuggestions = [];
  bool _isFetchingContainers = false;
  bool _isContainerSelected = false;
  List<ContainerSuggestion> _allContainers = [];

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
      return statusBarang == '5';
    });

    return !hasPendingItem && allComplete;
  }

  @override
  void initState() {
    super.initState();
    _initContainers();
  }

  @override
  void dispose() {
    _clearContainerSelection();
    _controller.dispose();
    _containerSearchController.dispose();
    super.dispose();
  }

  Future<void> _clearContainerSelection() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('container_id');
    await prefs.remove('container_number');
  }

  Future<void> _loadAllContainers() async {
    setState(() => _isFetchingContainers = true);
    final containersData = await _lclService.getAllContainerNumbers();
    if (containersData != null) {
      setState(() {
        _allContainers =
            containersData
                .map((item) => ContainerSuggestion.fromJson(item))
                .toList();
      });
    }
    setState(() => _isFetchingContainers = false);
  }

  Future<void> _initContainers() async {
    await _loadAllContainers();
    if (mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showContainerSelectionModal();
      });
    }
  }

  void _filterContainerSuggestions(String query, StateSetter dialogSetState) {
    List<ContainerSuggestion> filtered;
    if (query.isEmpty) {
      filtered = _allContainers;
    } else {
      filtered =
          _allContainers.where((container) {
            return container.number.toLowerCase().contains(query.toLowerCase());
          }).toList();
    }
    dialogSetState(() => _containerSuggestions = filtered);
  }

  void _showContainerSelectionModal() {
    setState(() {
      _containerSuggestions = _allContainers;
      _containerSearchController.clear();
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Pilih Nomor Kontainer'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _containerSearchController,
                    onChanged:
                        (value) =>
                            _filterContainerSuggestions(value, setDialogState),
                    decoration: const InputDecoration(
                      labelText: 'Cari nomor kontainer...',
                      suffixIcon: Icon(Icons.search),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _isFetchingContainers
                      ? const Center(child: CircularProgressIndicator())
                      : SizedBox(
                        height: 200,
                        width: double.maxFinite,
                        child: ListView.builder(
                          itemCount: _containerSuggestions.length,
                          itemBuilder: (context, index) {
                            final suggestion = _containerSuggestions[index];
                            return ListTile(
                              title: Text(suggestion.number),
                              onTap: () async {
                                final prefs =
                                    await SharedPreferences.getInstance();
                                await prefs.setString(
                                  'container_id',
                                  suggestion.id,
                                );
                                await prefs.setString(
                                  'container_number',
                                  suggestion.number,
                                );

                                setState(() {
                                  _selectedContainerId = suggestion.id;
                                  _selectedContainerNumber = suggestion.number;
                                  _isContainerSelected = true;
                                });
                                Navigator.of(dialogContext).pop();
                              },
                            );
                          },
                        ),
                      ),
                ],
              ),
            );
          },
        );
      },
    );
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

      if (status != 4) {
        _showErrorDialog(
          context,
          'Status Tidak Valid',
          'Status barang tidak valid untuk proses ini.',
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
          Text('Container: ${_selectedContainerNumber ?? '...'}'),
          const SizedBox(height: 10),
          Text('Kode Barang: $_codeBarang'),
          const SizedBox(height: 20),
          const Text('Ubah status dari Warehouse ke Container?'),
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

            final prefs = await SharedPreferences.getInstance();
            final containerId = prefs.getString('container_id');
            final currentBarcode = _scannedBarcode;

            // 2. Lakukan semua validasi dan proses async di dalam satu blok try-catch
            try {
              if (containerId == null || currentBarcode == null) {
                throw Exception('Data kontainer atau barcode tidak valid.');
              }

              isSuccess = await _lclService.updateStatusReadyToShip(
                numberLpbItem: currentBarcode,
                containerNumber: containerId,
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
                          'Semua barang untuk LPB $lpbHeader telah berhasil diproses.',
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
                          'Status berhasil diubah dari Warehouse ke Container. Lanjutkan scan berikutnya.',
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
                Text(
                  'Warehouse To ${_selectedContainerNumber ?? ''}',
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
                child:
                    _isContainerSelected
                        ? MobileScanner(
                          controller: _controller,
                          onDetect: (capture) async {
                            if (_scannedBarcode != null ||
                                _selectedContainerId == null)
                              return;
                            final barcode = capture.barcodes.first.rawValue;
                            if (barcode != null) {
                              _controller.stop();
                              await _showConfirmationModal(context, barcode);
                            }
                          },
                        )
                        : const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24.0),
                            child: Text(
                              'Pilih nomor kontainer untuk mengaktifkan pemindai.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                        ),
              ),
            ),
          ),
          if (_isContainerSelected)
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
