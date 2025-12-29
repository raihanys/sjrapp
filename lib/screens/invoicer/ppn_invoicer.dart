import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/auth_service.dart';
import '../../services/invoicer_service.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';

class PpnInvoicer extends StatefulWidget {
  final String? invoicingCode;

  const PpnInvoicer({Key? key, required this.invoicingCode}) : super(key: key);

  @override
  State<PpnInvoicer> createState() => _PpnInvoicerState();
}

class _PpnInvoicerState extends State<PpnInvoicer> {
  final AuthService _authService = AuthService();
  late InvoicerService _invoicerService;
  final RefreshController _refreshController = RefreshController();
  final TextEditingController _searchController = TextEditingController();

  List<dynamic> _invoices = [];
  List<dynamic> _filteredInvoices = [];
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _invoicerService = InvoicerService(_authService);
    _loadInvoices();
  }

  void _filterList(String query) {
    setState(() {
      _filteredInvoices =
          _invoices.where((item) {
            final invoiceNumber =
                item['invoice_number']?.toString().toLowerCase() ?? '';
            final clientName = item['name']?.toString().toLowerCase() ?? '';
            return invoiceNumber.contains(query.toLowerCase()) ||
                clientName.contains(query.toLowerCase());
          }).toList();
    });
  }

  Future<void> _loadInvoices() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });

      final typeInvoice = widget.invoicingCode ?? '0';
      final invoices = await _invoicerService.fetchInvoices(typeInvoice);

      setState(() {
        _invoices = invoices;
        _filteredInvoices = invoices;
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

  void _showInvoiceDetailModal(Map<String, dynamic> invoice) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder:
          (context) => InvoiceDetailModal(
            invoice: invoice,
            invoicingCode: widget.invoicingCode,
            onSave: _handleSaveInvoice,
          ),
    );
  }

  Future<void> _handleSaveInvoice({
    required String invoiceId,
    required String paymentType,
    String? paymentAmount,
    String? paymentDifference,
    String? paymentNotes,
    File? buktiPembayaranInvoice,
    String? bankId,
  }) async {
    try {
      final success = await _invoicerService.updateInvoiceStatus(
        invoiceId: invoiceId,
        paymentType: paymentType,
        paymentAmount: paymentAmount,
        paymentDifference: paymentDifference,
        paymentNotes: paymentNotes,
        buktiPembayaranInvoice: buktiPembayaranInvoice,
        bankId: bankId,
      );

      if (success) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invoice berhasil diproses')),
        );
        Navigator.pop(context);
        await _loadInvoices();
      } else {
        throw Exception('Failed to update invoice');
      }
    } catch (e) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Gagal'),
            content: Text('Gagal memproses invoice: $e'),
            actions: <Widget>[
              TextButton(
                child: const Text('OK'),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ],
          );
        },
      );
    }
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
              onPressed: _loadInvoices,
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
                      'PPN',
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
              await _loadInvoices();
              _refreshController.refreshCompleted();
            },
            child:
                _filteredInvoices.isEmpty
                    ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(height: 16),
                          Text(
                            "Tidak ada tagihan untuk di-proses",
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
                      itemCount: _filteredInvoices.length,
                      itemBuilder: (context, index) {
                        final invoice = _filteredInvoices[index];
                        final invoiceNumber = invoice['invoice_number'] ?? '-';
                        final clientName = invoice['name'] ?? '-';
                        final clientContact = invoice['contact'] ?? '-';
                        final total = invoice['total'] ?? '0';
                        final invoiceDate =
                            invoice['tanggal_ditugaskan'] ?? '-';

                        final formatter = NumberFormat.currency(
                          locale: 'id_ID',
                          symbol: 'Rp. ',
                          decimalDigits: 0,
                        );
                        final formattedTotal = formatter.format(
                          int.tryParse(total) ?? 0,
                        );

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
                            contentPadding: const EdgeInsets.all(16),
                            title: Text(
                              '$invoiceNumber',
                              style: theme.textTheme.titleSmall!.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 8),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
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
                                      child: Text(clientContact, maxLines: 2),
                                    ),
                                  ],
                                ),
                                const Divider(height: 20),
                                Row(
                                  children: [
                                    Text(
                                      'Tgl. Ditugaskan : $invoiceDate',
                                      style: theme.textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                                const Divider(height: 20),
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
                              ],
                            ),
                            trailing: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              onPressed: () => _showInvoiceDetailModal(invoice),
                              child: const Text("Proses"),
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

class CurrencyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue.copyWith(text: '');
    }
    String cleanText = newValue.text.replaceAll(RegExp(r'[^\d]'), '');
    if (cleanText.isEmpty) {
      return const TextEditingValue();
    }
    final number = int.parse(cleanText);
    final formatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: '',
      decimalDigits: 0,
    );
    String formattedText = formatter.format(number);
    return TextEditingValue(
      text: formattedText,
      selection: TextSelection.collapsed(offset: formattedText.length),
    );
  }
}

class InvoiceDetailModal extends StatefulWidget {
  final Map<String, dynamic> invoice;
  final String? invoicingCode;

  final Function({
    required String invoiceId,
    required String paymentType,
    String? paymentAmount,
    String? paymentDifference,
    String? paymentNotes,
    File? buktiPembayaranInvoice,
    String? bankId,
  })
  onSave;

  const InvoiceDetailModal({
    Key? key,
    required this.invoice,
    required this.invoicingCode,
    required this.onSave,
  }) : super(key: key);

  @override
  State<InvoiceDetailModal> createState() => _InvoiceDetailModalState();
}

class _InvoiceDetailModalState extends State<InvoiceDetailModal> {
  String? _selectedPaymentType;
  final TextEditingController _amountController = TextEditingController();
  bool _isLoading = false;
  Map<String, dynamic>? _invoiceDetail;
  bool _showAmountField = false;

  String? _selectedDifference;
  bool _showNotesField = false;
  final TextEditingController _notesController = TextEditingController();

  File? _fotoFile;
  final ImagePicker _imagePicker = ImagePicker();
  bool _showFotoUpload = false;

  String? _selectedBankId;
  bool _showBankDropdown = false;
  final List<Map<String, String>> _bankOptions = [
    {'id': '13', 'name': 'BCA - 1628.111.111 - PT. SULAWESI JAYA RAYA'},
    {'id': '14', 'name': 'BCA - 162.888.1234 - TIFFANY YUANITA RUNGKAT'},
  ];

  // === VARIABEL STATUS PEMBAYARAN (TUNAI & TRANSFER) ===
  // Values: 'lunas', 'belum_transfer', 'belum_bayar'
  String? _selectedSubStatus;
  bool _showSubStatusDropdown = false;
  // ==========================================

  @override
  void initState() {
    super.initState();
    _loadInvoiceDetail();

    final total = widget.invoice['total'] ?? '0';
    if (total.isNotEmpty) {
      final formatter = NumberFormat.currency(
        locale: 'id_ID',
        symbol: '',
        decimalDigits: 0,
      );
      final formattedTotal = formatter.format(int.tryParse(total) ?? 0);
      _amountController.text = formattedTotal.trim();
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadInvoiceDetail() async {
    try {
      final authService = AuthService();
      final invoicerService = InvoicerService(authService);
      final detail = await invoicerService.fetchInvoiceDetail(
        widget.invoice['invoice_id'].toString(),
      );
      setState(() {
        _invoiceDetail = detail;
      });
    } catch (e) {
      print('Error loading invoice detail: $e');
      setState(() {
        _invoiceDetail = widget.invoice;
      });
    }
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
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal memproses gambar: $e')));
      }
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Kesalahan'),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              child: const Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _handleSave() {
    if (_selectedPaymentType == null) {
      _showErrorDialog('Pilih metode pembayaran terlebih dahulu');
      return;
    }

    String? paymentAmountValue;
    String? paymentDifferenceValue;
    String? paymentNotesValue;
    String? bankIdValue;
    File? fileValue = _fotoFile;

    // === LOGIKA BARU YANG DI-UNIFIKASI ===

    if (_selectedSubStatus == null) {
      _showErrorDialog('Pilih status pembayaran (Lunas / Belum)');
      return;
    }

    // Cek apakah LUNAS (berlaku untuk Tunai & Transfer)
    if (_selectedSubStatus == 'lunas') {
      if (_amountController.text.isEmpty) {
        _showErrorDialog('Masukkan jumlah pembayaran');
        return;
      }
      if (_selectedDifference == null) {
        _showErrorDialog('Pilih status selisih pembayaran');
        return;
      }
      if (_fotoFile == null) {
        _showErrorDialog('Harap upload bukti pembayaran');
        return;
      }

      // Validasi khusus Transfer: Harus pilih Bank
      if (_selectedPaymentType == '2' && _selectedBankId == null) {
        _showErrorDialog('Pilih rekening tujuan untuk metode Transfer');
        return;
      }

      // Validasi Selisih
      if (_selectedDifference == '1') {
        if (_notesController.text.isEmpty) {
          _showErrorDialog('Harap isi keterangan selisih');
          return;
        }
        final totalAmountString = widget.invoice['total']?.toString() ?? '0';
        final totalAmount = int.tryParse(totalAmountString) ?? 0;
        final paymentAmountString = _amountController.text.replaceAll('.', '');
        final paymentAmount = int.tryParse(paymentAmountString) ?? 0;

        if (paymentAmount == totalAmount) {
          _showErrorDialog(
            'Jumlah pembayaran tidak boleh sama dengan total tagihan jika memilih opsi "Selisih".',
          );
          return;
        }
      }

      // Set Data untuk LUNAS
      paymentAmountValue = _amountController.text.replaceAll('.', '');
      paymentDifferenceValue = _selectedDifference;
      paymentNotesValue = _showNotesField ? _notesController.text : null;
      // Bank ID null jika Tunai
      bankIdValue = (_selectedPaymentType == '2') ? _selectedBankId : null;
    } else {
      // === LOGIKA BELUM BAYAR / BELUM TRANSFER ===
      if (_fotoFile == null) {
        _showErrorDialog('Harap upload Tanda Terima');
        return;
      }

      // Set Data untuk BELUM BAYAR
      paymentAmountValue = null;
      paymentDifferenceValue = null;
      paymentNotesValue = "Faktur Telah Dikirim";
      bankIdValue = null;
    }

    setState(() {
      _isLoading = true;
    });

    widget
        .onSave(
          invoiceId: widget.invoice['invoice_id'].toString(),
          paymentType: _selectedPaymentType!,
          paymentAmount: paymentAmountValue,
          paymentDifference: paymentDifferenceValue,
          paymentNotes: paymentNotesValue,
          buktiPembayaranInvoice: fileValue,
          bankId: bankIdValue,
        )
        .catchError((error) {
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('Error: $error')));
          }
        })
        .whenComplete(() {
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
          }
        });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final invoice = _invoiceDetail ?? widget.invoice;

    final formatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp. ',
      decimalDigits: 0,
    );
    final formattedTotal = formatter.format(
      int.tryParse(invoice['total'] ?? '0') ?? 0,
    );

    final List<Map<String, String>> paymentOptions = [];
    if (widget.invoicingCode != '1') {
      paymentOptions.add({'value': '1', 'label': 'Tunai'});
    }
    paymentOptions.add({'value': '2', 'label': 'Transfer'});

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.80,
      child: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Proses Invoice',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
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
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDetailRow(
                        'No. Invoice',
                        invoice['invoice_number'] ?? '-',
                      ),
                      _buildDetailRow('Kepada', invoice['name'] ?? '-'),
                      _buildDetailRow('Kontak', invoice['contact'] ?? '-'),
                      _buildDetailRow('Total Tagihan', formattedTotal),
                      _buildDetailRow(
                        'Tgl. Diterbitkan',
                        invoice['tanggal_invoice'] ?? '-',
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Metode Pembayaran',
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 20),
                      DropdownButtonFormField<String>(
                        value: _selectedPaymentType,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Pilih Metode Pembayaran',
                          border: OutlineInputBorder(),
                        ),
                        items:
                            paymentOptions.map<DropdownMenuItem<String>>((
                              option,
                            ) {
                              return DropdownMenuItem<String>(
                                value: option['value'],
                                child: Text(option['label']!),
                              );
                            }).toList(),
                        onChanged: (String? newValue) {
                          setState(() {
                            _selectedPaymentType = newValue;

                            // Reset semua field
                            _selectedSubStatus = null;
                            _showSubStatusDropdown =
                                true; // Selalu true jika tipe dipilih
                            _showAmountField = false;
                            _showFotoUpload = false;
                            _showBankDropdown = false;
                            _selectedDifference = null;
                            _showNotesField = false;
                            _notesController.clear();
                            _fotoFile = null;
                            _selectedBankId = null;
                          });
                        },
                      ),
                      const SizedBox(height: 15),

                      // === DROPDOWN STATUS PEMBAYARAN (TUNAI & TRANSFER) ===
                      if (_showSubStatusDropdown &&
                          _selectedPaymentType != null) ...[
                        DropdownButtonFormField<String>(
                          value: _selectedSubStatus,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Status Pembayaran',
                            border: OutlineInputBorder(),
                          ),
                          items:
                              (_selectedPaymentType == '1')
                                  ? const [
                                    // Item untuk TUNAI
                                    DropdownMenuItem(
                                      value: 'lunas',
                                      child: Text('Lunas'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'belum_bayar',
                                      child: Text('Belum Bayar'),
                                    ),
                                  ]
                                  : const [
                                    // Item untuk TRANSFER
                                    DropdownMenuItem(
                                      value: 'lunas',
                                      child: Text('Lunas'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'belum_transfer',
                                      child: Text('Belum Transfer'),
                                    ),
                                  ],
                          onChanged: (String? newValue) {
                            setState(() {
                              _selectedSubStatus = newValue;

                              // Reset field turunan
                              _showAmountField = false;
                              _showFotoUpload = false;
                              _showBankDropdown = false;
                              _selectedDifference = null;
                              _showNotesField = false;
                              _notesController.clear();
                              _fotoFile = null;
                              _selectedBankId = null;

                              if (newValue == 'lunas') {
                                // Tampilkan field lengkap untuk lunas
                                _showAmountField = true;
                                _showFotoUpload = true;
                                // Bank hanya jika Transfer
                                if (_selectedPaymentType == '2') {
                                  _showBankDropdown = true;
                                }
                              } else {
                                // Belum Bayar / Belum Transfer
                                // Hanya tampilkan upload foto (Tanda Terima)
                                _showFotoUpload = true;
                              }
                            });
                          },
                        ),
                        const SizedBox(height: 15),
                      ],

                      // ======================================
                      if (_showBankDropdown) ...[
                        DropdownButtonFormField<String>(
                          value: _selectedBankId,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Rekening Tujuan',
                            border: OutlineInputBorder(),
                          ),
                          items:
                              _bankOptions.map((bank) {
                                return DropdownMenuItem<String>(
                                  value: bank['id'],
                                  child: Text(bank['name']!),
                                );
                              }).toList(),
                          onChanged: (String? newValue) {
                            setState(() {
                              _selectedBankId = newValue;
                            });
                          },
                        ),
                        const SizedBox(height: 15),
                      ],

                      if (_showAmountField) ...[
                        TextFormField(
                          controller: _amountController,
                          decoration: const InputDecoration(
                            labelText: 'Jumlah Pembayaran',
                            border: OutlineInputBorder(),
                            prefixText: 'Rp. ',
                          ),
                          keyboardType: TextInputType.number,
                          inputFormatters: [CurrencyInputFormatter()],
                        ),
                        const SizedBox(height: 15),
                        DropdownButtonFormField<String>(
                          value: _selectedDifference,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Selisih Pembayaran',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(value: '0', child: Text('Tidak')),
                            DropdownMenuItem(
                              value: '1',
                              child: Text('Selisih'),
                            ),
                          ],
                          onChanged: (String? newValue) {
                            setState(() {
                              _selectedDifference = newValue;
                              if (newValue == '1') {
                                _showNotesField = true;
                              } else {
                                _showNotesField = false;
                                _notesController.clear();
                              }
                            });
                          },
                        ),
                        const SizedBox(height: 15),
                        if (_showNotesField)
                          TextFormField(
                            controller: _notesController,
                            decoration: const InputDecoration(
                              labelText: 'Keterangan Selisih',
                              border: OutlineInputBorder(),
                              hintText: 'Jelaskan alasan selisih pembayaran...',
                            ),
                          ),
                        const SizedBox(height: 15),
                      ],

                      if (_showFotoUpload && _fotoFile == null) ...[
                        Container(
                          height: 56,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              TextButton.icon(
                                icon: const Icon(Icons.camera_alt),
                                // Label dinamis
                                label: Text(
                                  (_selectedSubStatus == 'belum_transfer' ||
                                          _selectedSubStatus == 'belum_bayar')
                                      ? "Upload Tanda Terima"
                                      : "Upload Bukti Pembayaran",
                                ),
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
                                              setState(() {});
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
                                              setState(() {});
                                            },
                                          ),
                                        ],
                                      );
                                    },
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],

                      if (_fotoFile != null) ...[
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
                                  setState(() {
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
                        const SizedBox(height: 10),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleSave,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
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
                          : const Text('Submit'),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          const Text(': '),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
