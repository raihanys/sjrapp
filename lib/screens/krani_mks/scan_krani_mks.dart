import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../services/krani_mks_service.dart';

class ScanKraniMks extends StatefulWidget {
  final String containerId; // Tambahkan parameter containerId

  const ScanKraniMks({Key? key, required this.containerId}) : super(key: key);

  @override
  State<ScanKraniMks> createState() => _ScanKraniMksState();
}

class _ScanKraniMksState extends State<ScanKraniMks> {
  final MobileScannerController _controller = MobileScannerController();
  final KraniMksService _kraniMksService = KraniMksService();
  bool _isFlashOn = false;
  bool _isLoading = false;
  String? _scannedBarcode;

  // Controllers untuk field readonly
  final TextEditingController _noLpbController = TextEditingController();
  final TextEditingController _kodebarangController = TextEditingController();
  final TextEditingController _urutanbarangController = TextEditingController();
  final TextEditingController _totalbarangController = TextEditingController();
  final TextEditingController _namaController = TextEditingController();
  final TextEditingController _panjangController = TextEditingController();
  final TextEditingController _lebarController = TextEditingController();
  final TextEditingController _tinggiController = TextEditingController();
  final TextEditingController _volumeController = TextEditingController();
  final TextEditingController _beratController = TextEditingController();

  // Variabel untuk status dan foto
  String? _selectedCondition = 'Normal';
  TextEditingController _keteranganController = TextEditingController();
  bool _showFotoUpload = false;
  bool _showKeteranganField = false;
  bool _isReadOnly = false; // Tambahkan variabel untuk kontrol readonly
  File? _fotoFile;
  final ImagePicker _imagePicker = ImagePicker();
  String? _fotoUrl;

  late String _selectedContainerId;

  @override
  void initState() {
    super.initState();
    _selectedContainerId = widget.containerId;
    _selectedCondition = 'Normal';
    _keteranganController = TextEditingController();
    _showFotoUpload = false;
    _showKeteranganField = false;
    _isReadOnly = false;
  }

  @override
  void dispose() {
    _controller.dispose();
    _noLpbController.dispose();
    _kodebarangController.dispose();
    _urutanbarangController.dispose();
    _totalbarangController.dispose();
    _namaController.dispose();
    _panjangController.dispose();
    _lebarController.dispose();
    _tinggiController.dispose();
    _volumeController.dispose();
    _beratController.dispose();
    _keteranganController.dispose();
    super.dispose();
  }

  void _toggleFlash() {
    setState(() {
      _isFlashOn = !_isFlashOn;
      _controller.toggleTorch();
    });
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final pickedFile = await _imagePicker.pickImage(source: source);
      if (pickedFile != null) {
        setState(() {
          _fotoFile = File(pickedFile.path);
        });
      }
    } catch (e) {
      print('Error picking image: $e');
    }
  }

  Future<void> _showInputModal(
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
      // Reset values
      _selectedCondition = 'Normal';
      _keteranganController.clear();
      _showFotoUpload = false;
      _showKeteranganField = false;
      _isReadOnly = false;
      _fotoFile = null;
      _fotoUrl = null;
    });

    try {
      final lpbData = await _kraniMksService.getLPBInfoDetail(scannedBarcode);
      setState(() => _isLoading = false);

      if (lpbData == null || lpbData['data'] == null) {
        _showErrorDialog(
          context,
          'Gagal Memuat Data',
          'Data barang tidak ditemukan',
        );
        return;
      }

      final data = lpbData['data'] as Map<String, dynamic>;

      if (data['status'] != '7') {
        _showErrorDialog(
          context,
          'Status Tidak Valid',
          'Status barang tidak valid untuk proses Bongkar Barang.',
        );
        return;
      }

      String containerIdFromData = (data['container_id'] ?? '').toString();
      if (containerIdFromData != _selectedContainerId) {
        _showErrorDialog(
          context,
          'Container Tidak Cocok',
          'Barang tidak termasuk dalam container yang dipilih.',
        );
        return;
      }

      // Isi field readonly
      _noLpbController.text = (data['nomor_lpb'] ?? '').toString().trim();
      _kodebarangController.text =
          (data['code_barang'] ?? '').toString().trim();
      _urutanbarangController.text =
          (data['number_item'] ?? '').toString().trim();
      _totalbarangController.text =
          (data['total_barang'] ?? '').toString().trim();
      _namaController.text = (data['nama_barang'] ?? '').toString().trim();
      _panjangController.text = (data['length'] ?? '').toString().trim();
      _lebarController.text = (data['width'] ?? '').toString().trim();
      _tinggiController.text = (data['height'] ?? '').toString().trim();
      _beratController.text = (data['weight'] ?? '').toString().trim();

      // Hitung volume
      _hitungVolume();

      // Cek status penerimaan barang dari database
      String statusPenerimaan =
          (data['status_penerimaan_barang'] ?? '').toString();
      String keterangan =
          (data['keterangan_penerimaan_barang'] ?? '').toString();
      String fotoUrl =
          (data['foto_url_status_penerimaan_barang'] ?? '').toString();

      String selectedCondition;
      bool isReadOnly = false;
      bool showFotoUpload = false;
      bool showKeteranganField = false;

      // Logika untuk menentukan kondisi berdasarkan status
      if (statusPenerimaan == '3') {
        selectedCondition = 'Rusak (Sebelum Dikirim)';
        isReadOnly = true; // Set readonly untuk status 3
        showFotoUpload = true;
        showKeteranganField = true;
      } else if (statusPenerimaan == '5') {
        selectedCondition = 'Rusak (Saat Dikirim)';
        showFotoUpload = true;
        showKeteranganField = true;
      } else {
        selectedCondition = 'Normal';
        showFotoUpload = false;
        showKeteranganField = false;
      }

      setState(() {
        _selectedCondition = selectedCondition;
        _keteranganController.text = keterangan;
        _isReadOnly = isReadOnly;
        _showFotoUpload = showFotoUpload;
        _showKeteranganField = showKeteranganField;

        if (showFotoUpload && fotoUrl.isNotEmpty) {
          _fotoUrl = _kraniMksService.getImageUrl(fotoUrl);
        } else {
          _fotoUrl = null;
        }
      });

      showMaterialModalBottomSheet(
        context: context,
        isDismissible: false,
        enableDrag: false,
        builder: (context) => _buildInputModal(context),
      ).whenComplete(() {
        _scannedBarcode = null;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorDialog(
        context,
        'Kesalahan',
        'Terjadi kesalahan: ${e.toString()}',
      );
    }
  }

  Future<void> _showErrorDialog(
    BuildContext context,
    String title,
    String message,
  ) async {
    await showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text('OK'),
              ),
            ],
          ),
    );
    // Restart the scanner after the dialog is closed
    _scannedBarcode = null;
    _controller.start();
  }

  void _hitungVolume() {
    final double? panjang = double.tryParse(_panjangController.text.trim());
    final double? lebar = double.tryParse(_lebarController.text.trim());
    final double? tinggi = double.tryParse(_tinggiController.text.trim());

    if (panjang != null && lebar != null && tinggi != null) {
      double volume = panjang * lebar * tinggi / 1000000;
      _volumeController.text = volume.toStringAsFixed(3);
    } else {
      _volumeController.text = '0.000';
    }
  }

  Widget _buildInputModal(BuildContext context) {
    return StatefulBuilder(
      builder: (BuildContext context, StateSetter setModalState) {
        List<String> dropdownOptions =
            _isReadOnly
                ? ['Rusak (Sebelum Dikirim)']
                : ['Normal', 'Rusak (Saat Dikirim)'];

        return SizedBox(
          height: MediaQuery.of(context).size.height * 0.87,
          child: GestureDetector(
            onTap: () {
              FocusScope.of(context).unfocus();
            },
            child: Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 16,
                right: 16,
                top: 16,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Data Barang',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            if (mounted) {
                              _controller.start();
                            }
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
                    const SizedBox(height: 20),
                    _buildReadOnlyField('No. LPB', _noLpbController),
                    const SizedBox(height: 10),
                    _buildReadOnlyField('Kode Barang', _kodebarangController),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(flex: 1, child: Container()),
                        Expanded(
                          flex: 1,
                          child: _buildReadOnlyField(
                            'Urutan',
                            _urutanbarangController,
                            textAlign: TextAlign.center,
                            fontSize: 18,
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8.0),
                          child: Text('/', style: TextStyle(fontSize: 24)),
                        ),
                        Expanded(
                          flex: 1,
                          child: _buildReadOnlyField(
                            'Total',
                            _totalbarangController,
                            textAlign: TextAlign.center,
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _buildReadOnlyField('Nama Barang', _namaController),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _buildReadOnlyField(
                            'Panjang (cm)',
                            _panjangController,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildReadOnlyField(
                            'Lebar (cm)',
                            _lebarController,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildReadOnlyField(
                            'Tinggi (cm)',
                            _tinggiController,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _buildReadOnlyField(
                            'Berat (kg)',
                            _beratController,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildReadOnlyField(
                            'Volume (m³)',
                            _volumeController,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // Dropdown dan Tombol Foto dalam satu baris
                    Row(
                      children: [
                        Expanded(
                          flex: 1,
                          child: DropdownButtonFormField<String>(
                            value: _selectedCondition,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Kondisi Barang',
                              border: OutlineInputBorder(),
                            ),
                            items:
                                dropdownOptions.map<DropdownMenuItem<String>>((
                                  String value,
                                ) {
                                  return DropdownMenuItem<String>(
                                    value: value,
                                    child: Text(
                                      value,
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                  );
                                }).toList(),
                            onChanged:
                                _isReadOnly
                                    ? null
                                    : (String? newValue) {
                                      bool newShowFotoUpload =
                                          newValue == 'Rusak (Saat Dikirim)';
                                      bool newShowKeteranganField =
                                          newValue == 'Rusak (Saat Dikirim)';

                                      setModalState(() {
                                        _selectedCondition = newValue;
                                        _showFotoUpload = newShowFotoUpload;
                                        _showKeteranganField =
                                            newShowKeteranganField;
                                        if (!newShowFotoUpload) {
                                          _fotoFile = null;
                                          _keteranganController.clear();
                                          _fotoUrl = null;
                                        }
                                      });
                                    },
                          ),
                        ),
                        const SizedBox(width: 10),
                        if (_showFotoUpload && !_isReadOnly)
                          Expanded(
                            flex: 1,
                            child: Container(
                              height: 56,
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
                                        title: const Text(
                                          "Pilih Sumber Gambar",
                                        ),
                                        actions: [
                                          TextButton.icon(
                                            icon: const Icon(Icons.camera_alt),
                                            label: const Text("Kamera"),
                                            onPressed: () async {
                                              Navigator.of(context).pop();
                                              await _pickImage(
                                                ImageSource.camera,
                                              );
                                              setModalState(() {});
                                            },
                                          ),
                                          TextButton.icon(
                                            icon: const Icon(Icons.image),
                                            label: const Text("Galeri"),
                                            onPressed: () async {
                                              Navigator.of(context).pop();
                                              await _pickImage(
                                                ImageSource.gallery,
                                              );
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
                          ),
                      ],
                    ),

                    // Tampilkan foto di baris baru
                    if (_fotoFile != null) ...[
                      const SizedBox(height: 10),
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
                                                minimumSize: const Size(40, 40),
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
                          // Tambahkan kondisi !_isReadOnly di sini
                          if (!_isReadOnly)
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
                    ] else if (_fotoUrl != null) ...[
                      const SizedBox(height: 10),
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
                                              child: Image.network(
                                                _fotoUrl!,
                                                fit: BoxFit.contain,
                                                width: double.infinity,
                                                errorBuilder: (
                                                  context,
                                                  error,
                                                  stackTrace,
                                                ) {
                                                  return const Center(
                                                    child: Text(
                                                      'Gagal memuat gambar',
                                                      style: TextStyle(
                                                        color: Colors.white,
                                                      ),
                                                    ),
                                                  );
                                                },
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
                                                minimumSize: const Size(40, 40),
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
                              child: Image.network(
                                _fotoUrl!,
                                height: 120,
                                width: 120,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return const Icon(Icons.error, size: 40);
                                },
                              ),
                            ),
                          ),
                          // Tambahkan kondisi !_isReadOnly di sini
                          if (!_isReadOnly)
                            Expanded(
                              flex: 1,
                              child: TextButton(
                                onPressed: () {
                                  setModalState(() {
                                    _fotoUrl = null;
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
                    const SizedBox(height: 15),

                    // Tampilkan keterangan hanya jika diperlukan
                    if (_showKeteranganField) ...[
                      TextFormField(
                        controller: _keteranganController,
                        enabled: !_isReadOnly,
                        decoration: const InputDecoration(
                          labelText: 'Keterangan Barang',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],

                    const SizedBox(height: 20),

                    ElevatedButton(
                      onPressed: () async {
                        // Validasi: jika status rusak, harus ada foto
                        if (_selectedCondition == 'Rusak (Saat Dikirim)' &&
                            _fotoFile == null &&
                            _fotoUrl == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Foto wajib diisi untuk kondisi rusak',
                              ),
                            ),
                          );
                          return;
                        }

                        setState(() => _isLoading = true);
                        try {
                          String? statusValue;
                          String? keteranganValue;
                          File? fotoValue;

                          // Hanya kirim data tambahan jika status adalah Rusak (Saat Dikirim)
                          if (_selectedCondition == 'Rusak (Saat Dikirim)') {
                            statusValue = '5';
                            keteranganValue = _keteranganController.text.trim();
                            fotoValue =
                                _fotoFile; // Kirim file foto hanya untuk status 5
                          }

                          final success = await _kraniMksService
                              .updateItemStatus(
                                _kodebarangController.text.trim(),
                                statusKondisiBarang: statusValue,
                                keteranganKondisiBarang: keteranganValue,
                                fotoTerimaBarang: fotoValue,
                              );

                          if (mounted) {
                            Navigator.of(context).pop();
                            showDialog(
                              context: context,
                              builder:
                                  (context) => AlertDialog(
                                    title: Text(success ? 'Berhasil' : 'Gagal'),
                                    content: Text(
                                      success
                                          ? 'Status berhasil diupdate'
                                          : 'Gagal mengupdate status',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed:
                                            () => Navigator.of(context).pop(),
                                        child: const Text('OK'),
                                      ),
                                    ],
                                  ),
                            ).then((_) {
                              if (mounted) {
                                _controller.start();
                              }
                            });
                          }
                        } catch (e) {
                          if (mounted) {
                            showDialog(
                              context: context,
                              builder:
                                  (context) => AlertDialog(
                                    title: const Text('Error'),
                                    content: Text(
                                      'Terjadi kesalahan: ${e.toString()}',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed:
                                            () => Navigator.of(context).pop(),
                                        child: const Text('OK'),
                                      ),
                                    ],
                                  ),
                            ).then((_) {
                              if (mounted) {
                                _controller.start();
                              }
                            });
                          }
                        } finally {
                          if (mounted) setState(() => _isLoading = false);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                      ),
                      child:
                          _isLoading
                              ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                              : const Text('Simpan Perubahan'),
                    ),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildReadOnlyField(
    String label,
    TextEditingController controller, {
    TextAlign textAlign = TextAlign.left,
    double fontSize = 14,
  }) {
    return TextFormField(
      controller: controller,
      textAlign: textAlign,
      style: TextStyle(fontSize: fontSize),
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        filled: true,
        fillColor: Colors.grey[200],
      ),
      readOnly: true,
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Image.asset(
                      'assets/images/logo.png',
                      height: 40,
                      width: 200,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const Text(
                  'Aplikasi Krani Makassar',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const Text(
                  'Scan Barang',
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
                      setState(() => _scannedBarcode = barcode);
                      _controller.stop();
                      await _showInputModal(context, barcode);
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
