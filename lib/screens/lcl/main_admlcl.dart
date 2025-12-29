import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../login_screen.dart';
import 'warehouse_admlcl.dart';
import 'container_admlcl.dart';
import 'shipping_admlcl.dart';
import 'to_warehouse_admlcl.dart';
import 'monitoring_admlcl.dart';

class MainLCL extends StatefulWidget {
  const MainLCL({super.key});

  @override
  State<MainLCL> createState() => _MainLCLState();
}

class _MainLCLState extends State<MainLCL> {
  final AuthService _authService = AuthService();

  void _logout(BuildContext context) async {
    await _authService.logout();
    if (context.mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
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
                  'Aplikasi LCL',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const Text(
                  'Home',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
      ),
      body: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  final double spacing = 12.0;

  Widget _buildMenuCard(
    BuildContext context,
    IconData icon,
    String title,
    Color color,
    VoidCallback onTap,
  ) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(spacing / 2),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: color.withOpacity(0.5), width: 1.5),
                ),
                child: Icon(icon, size: 35, color: color),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.all(spacing),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildMenuCard(
                context,
                Icons.warehouse,
                'Warehouse',
                Colors.green,
                () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const WarehouseScreen()),
                ),
              ),
              _buildMenuCard(
                context,
                Icons.local_shipping,
                'Container',
                Colors.orange,
                () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ContainerScreen()),
                ),
              ),
              _buildMenuCard(
                context,
                Icons.bar_chart,
                'Monitoring',
                Colors.red,
                () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const MonitoringAdmLCL()),
                ),
              ),
            ],
          ),
        ),

        Center(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: spacing),
            child: Row(
              children: [
                _buildMenuCard(
                  context,
                  Icons.redo,
                  'Warehouse to Container',
                  Colors.blue,
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ReadyToShipScreen(),
                    ),
                  ),
                ),
                _buildMenuCard(
                  context,
                  Icons.undo,
                  'Container to Warehouse',
                  Colors.purple,
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ToWarehouseScreen(),
                    ),
                  ),
                ),
                // Tambahkan Expanded kosong untuk mengisi ruang kolom ke-3
                const Expanded(child: SizedBox.shrink()),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
