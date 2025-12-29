import 'dart:async';
import 'package:flutter/material.dart';
import 'screens/login_screen.dart';
import 'screens/pelabuhan/main_pelabuhan.dart';
import 'screens/supir/main_supir.dart';
import './services/auth_service.dart';
import 'screens/lcl/main_admlcl.dart';
import 'screens/warehouse/main_warehouse.dart';
import 'screens/warehouse_mks/main_warehouse_mks.dart';
import 'screens/krani_mks/main_krani_mks.dart';
import 'screens/kurir_mks/main_kurir_mks.dart';
import 'screens/invoicer/main_invoicer.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  Future<Widget> _getStartScreen() async {
    final authService = AuthService();

    final isLoggedIn = await authService.isLoggedIn();
    final token = await authService.getValidToken();

    if (isLoggedIn && token != null) {
      final role = await authService.getRole();
      if (role != null) {
        switch (role.toLowerCase()) {
          case '1': // Driver
            return const MainSupir();
          case '3': // Pelabuhan
            return const MainPelabuhan();
          case '4': // Admin LCL
            return const MainLCL();
          case '5': // Kepala Gudang
            return const MainWarehouse();
          case '6': // Warehouse Makassar
            return const MainWarehouseMks();
          case '7': // Krani Makassar
            return const MainKraniMks();
          case '8': // Kurir Makassar
            return const KurirMksScreen();
          case '9': // Invoicer
            return const MainInvoicer();
        }
      }
    }

    return const LoginScreen();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ralisa Mobile App',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFF4C4C),
          brightness: Brightness.light,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
      home: FutureBuilder(
        future: _getStartScreen(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return snapshot.data!;
          }
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        },
      ),
    );
  }
}
