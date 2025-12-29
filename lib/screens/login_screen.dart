import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'lcl/main_admlcl.dart';
import 'warehouse/main_warehouse.dart';
import 'warehouse_mks/main_warehouse_mks.dart';
import 'krani_mks/main_krani_mks.dart';
import 'kurir_mks/main_kurir_mks.dart';
import 'invoicer/main_invoicer.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final AuthService _authService = AuthService();
  bool _isLoading = false;
  String? _errorMessage;
  bool _obscurePassword = true;

  void _handleLogin() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    print("Mencoba login dengan:");
    print("Username: '$username'");
    print("Password: '$password'");

    if (username.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'Username dan Password harus di isi');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await _authService.login(
        username: username,
        password: password,
      );

      if (result != null) {
        _navigateToRoleScreen();
      } else {
        setState(
          () =>
              _errorMessage = 'Login gagal. Cek kembali Username dan Password',
        );
      }
    } catch (e) {
      setState(() => _errorMessage = 'Terjadi kesalahan: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _navigateToRoleScreen() async {
    final role = await _authService.getRole();
    if (role == null) {
      setState(() => _errorMessage = 'Role tidak ditemukan');
      return;
    }

    if (role == '1' || role == '3') {
      setState(
        () =>
            _errorMessage =
                'Akun ini bukan untuk SJR App. Silakan gunakan Ralisa App.',
      );
      _authService.logout();
      return;
    }

    Widget target;

    switch (role.toLowerCase()) {
      case '4': // Krani LCL
        target = const MainLCL();
        break;
      case '5': // Kepala Gudang
        target = const MainWarehouse();
        break;
      case '6': // Warehouse Makassar
        target = const MainWarehouseMks();
        break;
      case '7': // Krani Makassar
        target = const MainKraniMks();
        break;
      case '8': // Kurir Makassar
        target = const KurirMksScreen();
        break;
      case '9': // Invoicer
        target = const MainInvoicer();
        break;
      default:
        setState(() => _errorMessage = 'Role tidak valid untuk aplikasi ini');
        return;
    }

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => target),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Logo
                Image.asset('assets/images/logo.png', height: 48, width: 250),

                const SizedBox(height: 32),

                // Title
                Text(
                  "Login",
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Masukan Username dan Password untuk log in",
                  style: theme.textTheme.bodyMedium,
                ),

                const SizedBox(height: 24),

                // Error message
                if (_errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      _errorMessage!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ),

                // Username Field
                TextField(
                  controller: _usernameController,
                  decoration: InputDecoration(labelText: "Username"),
                ),
                const SizedBox(height: 16),

                // Password Field
                TextField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: "Password",
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                        color: theme.colorScheme.primary,
                      ),
                      onPressed:
                          () => setState(
                            () => _obscurePassword = !_obscurePassword,
                          ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Login Button
                _isLoading
                    ? CircularProgressIndicator(
                      color: theme.colorScheme.primary,
                    )
                    : SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _handleLogin,
                        child: const Text("Log In"),
                      ),
                    ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
