import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../login_screen.dart';
import 'ppn_invoicer.dart';
import 'non_ppn_invoicer.dart';
import 'monitoring_invoicer.dart';

class MainInvoicer extends StatefulWidget {
  const MainInvoicer({Key? key}) : super(key: key);

  @override
  State<MainInvoicer> createState() => _MainInvoicerState();
}

class _MainInvoicerState extends State<MainInvoicer> {
  final AuthService _authService = AuthService();
  bool _isLoading = true;
  String? _invoicingCode;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final isLoggedIn = await _authService.isLoggedIn();
    if (!isLoggedIn) {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
      return;
    }

    _invoicingCode = await _authService.getInvoicingCode();
    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return _MainInvoicerContent(invoicingCode: _invoicingCode);
  }
}

class _MainInvoicerContent extends StatefulWidget {
  final String? invoicingCode;

  const _MainInvoicerContent({Key? key, required this.invoicingCode})
    : super(key: key);

  @override
  State<_MainInvoicerContent> createState() => _MainInvoicerContentState();
}

class _MainInvoicerContentState extends State<_MainInvoicerContent> {
  int _currentIndex = 0;
  final AuthService _authService = AuthService();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(70.0),
        child: SafeArea(child: _buildCustomAppBar(context)),
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          PpnInvoicer(invoicingCode: widget.invoicingCode),
          NonPpnInvoicer(invoicingCode: widget.invoicingCode),
          MonitoringInvoicer(invoicingCode: widget.invoicingCode),
        ],
      ),
      bottomNavigationBar: _buildFloatingNavBar(theme),
    );
  }

  Widget _buildCustomAppBar(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Image.asset('assets/images/logo.png', height: 40, width: 200),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () async {
                await _authService.logout();
                if (!mounted) return;
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              },
              child: const Text('Logout'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingNavBar(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          backgroundColor: theme.colorScheme.surface,
          selectedItemColor: theme.colorScheme.primary,
          unselectedItemColor: theme.colorScheme.onSurface.withOpacity(0.6),
          showSelectedLabels: true,
          showUnselectedLabels: true,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.receipt_long_outlined),
              activeIcon: Icon(Icons.receipt_long),
              label: 'PPN',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.receipt_outlined),
              activeIcon: Icon(Icons.receipt),
              label: 'Non PPN',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.monitor_outlined),
              activeIcon: Icon(Icons.monitor),
              label: 'Monitoring',
            ),
          ],
        ),
      ),
    );
  }
}
