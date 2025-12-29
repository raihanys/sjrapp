import 'dart:io';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';

import '../../services/kurir_mks_service.dart';
import '../../services/auth_service.dart';
import '../login_screen.dart';

class KurirMksScreen extends StatefulWidget {
  const KurirMksScreen({super.key});

  @override
  State<KurirMksScreen> createState() => _KurirMksScreenState();
}

class _KurirMksScreenState extends State<KurirMksScreen> {
  final MobileScannerController _controller = MobileScannerController();
  final KurirMksService _kurirMksService = KurirMksService();
  final AuthService _authService = AuthService();
  final ImagePicker _imagePicker = ImagePicker();

  bool _isFlashOn = false;
  bool _isLoading = false;
  String? _scannedBarcode;

  File? _fotoFile;
  List<Map<String, dynamic>> _eligibleItems = [];
  List<String> _selectedItems = [];
  String _nomorLpbHeader = "";
  String _totalBarangLpb = "0";

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _getLpbHeader(String fullBarcode) {
    int lastSlashIndex = fullBarcode.lastIndexOf('/');
    if (lastSlashIndex != -1) {
      return fullBarcode.substring(0, lastSlashIndex);
    }
    return fullBarcode;
  }

  void _logout(BuildContext context) async {
    await _authService.logout();
    if (context.mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  void _toggleFlash() {
    setState(() {
      _isFlashOn = !_isFlashOn;
      _controller.toggleTorch();
    });
  }

  void _restartScanner() {
    if (mounted) {
      setState(() {
        _scannedBarcode = null;
        _fotoFile = null;
        _eligibleItems = [];
        _selectedItems = [];
        _totalBarangLpb = "0";
      });
      _controller.start();
    }
  }

  Future<void> _handleScannedBarcode(String barcode) async {
    _controller.stop();
    setState(() {
      _isLoading = true;
      _scannedBarcode = barcode;
    });

    try {
      final detailData = await _kurirMksService.getLPBInfoDetail(barcode);

      if (detailData == null || detailData['data'] == null) {
        setState(() => _isLoading = false);
        _showErrorDialog(context, 'Gagal', 'Data barang tidak ditemukan.');
        return;
      }

      final dataDetail = detailData['data'] as Map<String, dynamic>;
      final String kodeBarang = dataDetail['code_barang'] as String? ?? '';
      final String totalBarang = (dataDetail['total_barang'] ?? '0').toString();
      final String headerLpb = _getLpbHeader(barcode);

      final headerData = await _kurirMksService.getLPBInfo(headerLpb);
      setState(() => _isLoading = false);

      if (!mounted) return;

      if (headerData == null || headerData['items'] == null) {
        _showErrorDialog(context, 'Gagal', 'Gagal mengambil daftar item LPB.');
        return;
      }

      final List<dynamic> allItems = headerData['items'];

      List<Map<String, dynamic>> readyItems = [];
      for (var item in allItems) {
        if (item['status_barang'].toString().trim() == '8') {
          readyItems.add(Map<String, dynamic>.from(item));
        }
      }

      setState(() {
        _nomorLpbHeader = headerLpb;
        _totalBarangLpb = totalBarang;
        _eligibleItems = readyItems;

        _selectedItems =
            readyItems.map((e) => e['barang_kode'].toString()).toList();
      });

      final int status =
          int.tryParse(dataDetail['status']?.toString() ?? '0') ?? 0;

      if (status < 8) {
        _showErrorDialog(
          context,
          'Status Tidak Valid',
          'Barang $kodeBarang Belum Siap Dikirim.',
        );
        return;
      }
      if (status > 8) {
        _showErrorDialog(
          context,
          'Status Tidak Valid',
          'Barang $kodeBarang Sudah Terkirim.',
        );
        return;
      }

      if (_eligibleItems.isEmpty) {
        _showErrorDialog(
          context,
          'Info',
          'Tidak ada barang yang siap dikirim di LPB ini.',
        );
        return;
      }

      await _showDeliveryModal();
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorDialog(context, 'Error', 'Terjadi kesalahan: $e');
    }
  }

  Future<void> _showDeliveryModal() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (context) => StatefulBuilder(
            builder: (context, setModalState) {
              return Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                  left: 16,
                  right: 16,
                  top: 20,
                ),
                child: SizedBox(
                  height: MediaQuery.of(context).size.height * 0.87,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Konfirmasi Pengiriman',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          ElevatedButton(
                            onPressed: () {
                              Navigator.pop(context);
                              _restartScanner();
                            },
                            style: ElevatedButton.styleFrom(
                              shape: const CircleBorder(),
                              backgroundColor: Colors.red,
                              padding: const EdgeInsets.all(10),
                              minimumSize: const Size(40, 40),
                            ),
                            child: const Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 30),

                      _buildReadOnlyField('Nomor LPB', _nomorLpbHeader),
                      const SizedBox(height: 10),

                      _buildReadOnlyField(
                        'Total Barang LPB',
                        '$_totalBarangLpb Koli',
                      ),

                      const SizedBox(height: 15),
                      const Text(
                        'List Barang:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Expanded(
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: ListView.separated(
                            itemCount: _eligibleItems.length,
                            separatorBuilder:
                                (ctx, i) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final item = _eligibleItems[index];
                              final code = item['barang_kode'] ?? '-';
                              final isChecked = _selectedItems.contains(code);

                              return CheckboxListTile(
                                dense: true,
                                title: Text(
                                  code,
                                  style: const TextStyle(fontSize: 12),
                                ),
                                value: isChecked,
                                activeColor: Colors.redAccent,
                                onChanged: (bool? val) {
                                  setModalState(() {
                                    if (val == true) {
                                      _selectedItems.add(code);
                                    } else {
                                      _selectedItems.remove(code);
                                    }
                                  });
                                },
                              );
                            },
                          ),
                        ),
                      ),

                      const Text(
                        'Foto Surat Jalan:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),

                      if (_fotoFile == null) ...[
                        Container(
                          width: double.infinity,
                          height: 54,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: IconButton(
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (BuildContext context) {
                                  return AlertDialog(
                                    title: const Text("Pilih Sumber Gambar"),
                                    actions: [
                                      TextButton.icon(
                                        icon: const Icon(Icons.camera_alt),
                                        label: const Text("Kamera"),
                                        onPressed: () async {
                                          Navigator.of(context).pop();
                                          await _pickImage(ImageSource.camera);
                                          setModalState(() {});
                                        },
                                      ),
                                      TextButton.icon(
                                        icon: const Icon(Icons.image),
                                        label: const Text("Galeri"),
                                        onPressed: () async {
                                          Navigator.of(context).pop();
                                          await _pickImage(ImageSource.gallery);
                                          setModalState(() {});
                                        },
                                      ),
                                    ],
                                  );
                                },
                              );
                            },
                            icon: const Icon(Icons.camera_alt, size: 28),
                          ),
                        ),
                      ] else ...[
                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: GestureDetector(
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
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                child: Image.file(
                                                  _fotoFile!,
                                                  fit: BoxFit.contain,
                                                  width: double.infinity,
                                                ),
                                              ),
                                            ),
                                            Positioned(
                                              top: 10,
                                              right: 10,
                                              child: ElevatedButton(
                                                onPressed:
                                                    () =>
                                                        Navigator.of(
                                                          context,
                                                        ).pop(),
                                                style: ElevatedButton.styleFrom(
                                                  shape: const CircleBorder(),
                                                  backgroundColor: Colors.red,
                                                  padding: const EdgeInsets.all(
                                                    10,
                                                  ),
                                                  minimumSize: const Size(
                                                    40,
                                                    40,
                                                  ),
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
                                child: Image.file(
                                  _fotoFile!,
                                  height: 120,
                                  width: 120,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 1,
                              child: TextButton(
                                onPressed: () {
                                  setModalState(() {
                                    _fotoFile = null;
                                  });
                                },
                                child: const Text(
                                  'Hapus Foto',
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],

                      const SizedBox(height: 20),

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(double.infinity, 50),
                          ),
                          onPressed:
                              _isLoading
                                  ? null
                                  : () => _handleSubmit(setModalState),
                          child:
                              _isLoading
                                  ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                  : Text('Submit'),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              );
            },
          ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final pickedFile = await _imagePicker.pickImage(source: source);
      if (pickedFile == null) return;

      final sourcePath = pickedFile.path;
      final tempDir = await getTemporaryDirectory();
      final targetPath =
          '${tempDir.path}/${DateTime.now().millisecondsSinceEpoch}.jpg';

      final compressedFile = await FlutterImageCompress.compressAndGetFile(
        sourcePath,
        targetPath,
        quality: 90,
      );

      if (compressedFile == null) {
        print('Kompresi gambar gagal.');
        return;
      }

      setState(() {
        _fotoFile = File(compressedFile.path);
      });
    } catch (e) {
      print('Error picking and compressing image: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal memproses gambar: $e')));
    }
  }

  Future<void> _handleSubmit(StateSetter setModalState) async {
    if (_selectedItems.isEmpty) {
      _showSimpleDialog('Peringatan', 'Pilih minimal 1 barang untuk dikirim.');
      return;
    }
    if (_fotoFile == null) {
      _showSimpleDialog('Peringatan', 'Foto Surat Jalan wajib diisi.');
      return;
    }

    setModalState(() => _isLoading = true);

    final success = await _kurirMksService.submitDelivery(
      itemCodes: _selectedItems,
      fotoSuratJalan: _fotoFile!,
    );

    setModalState(() => _isLoading = false);

    if (!mounted) return;

    Navigator.pop(context);

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (ctx) => AlertDialog(
            title: Text(success ? 'Berhasil' : 'Gagal'),
            content: Text(
              success
                  ? 'Data pengiriman berhasil disimpan.'
                  : 'Gagal menyimpan data. Silakan coba lagi.',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _restartScanner();
                },
                child: const Text('OK'),
              ),
            ],
          ),
    );
  }

  Widget _buildReadOnlyField(String label, String value) {
    return TextField(
      controller: TextEditingController(text: value),
      readOnly: true,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        filled: true,
        fillColor: Colors.grey[200],
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    );
  }

  Future<void> _showErrorDialog(
    BuildContext context,
    String title,
    String message,
  ) async {
    await _showSimpleDialog(title, message, onOk: _restartScanner);
  }

  Future<void> _showSimpleDialog(
    String title,
    String message, {
    VoidCallback? onOk,
  }) async {
    await showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  if (onOk != null) onOk();
                },
                child: const Text('OK'),
              ),
            ],
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
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 12.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Image.asset(
                      'assets/images/logo.png',
                      height: 40,
                      width: 200,
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: () => _logout(context),
                      child: const Text('Logout'),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const Text(
                  'Aplikasi Kurir Makassar',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const Text(
                  'Scan Pengiriman Barang',
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
              margin: const EdgeInsets.only(bottom: 90),
              width: MediaQuery.of(context).size.width * 0.9,
              height: MediaQuery.of(context).size.height * 0.6,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey, width: 2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: MobileScanner(
                  controller: _controller,
                  onDetect: (capture) {
                    if (_scannedBarcode != null) return;
                    final barcode = capture.barcodes.first.rawValue;
                    if (barcode != null) {
                      _handleScannedBarcode(barcode);
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
              margin: const EdgeInsets.only(bottom: 90),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.red, width: 4),
              ),
            ),
          ),
          if (_isLoading) const Center(child: CircularProgressIndicator()),
          Positioned(
            right: 16,
            bottom: 40,
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
