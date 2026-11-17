import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import 'home_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final AuthService auth = AuthService();

  bool loading = false;
  bool obscure = true;

  Future<void> _showAlert(String title, String message) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Mengerti'),
          ),
        ],
      ),
    );
  }

  Future<void> login() async {
    final email = emailController.text.trim();
    final password = passwordController.text;
    final missing = <String>[];
    if (email.isEmpty) missing.add('Email');
    if (password.isEmpty) missing.add('Password');
    if (missing.isNotEmpty) {
      await _showAlert(
        'Data belum lengkap',
        'Bagian berikut wajib diisi:\n\n${missing.map((field) => '• $field').join('\n')}',
      );
      return;
    }

    setState(() => loading = true);
    final error = await auth.login(email: email, password: password);

    if (!mounted) return;
    setState(() => loading = false);

    if (error == null) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (route) => false,
      );
    } else {
      await _showAlert('Login gagal', error);
    }
  }

  Future<void> _openRegister() async {
    if (loading) return;
    final registered = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const RegisterScreen()),
    );
    if (!mounted || registered != true) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Akun berhasil dibuat. Silakan login menggunakan akun baru.'),
      ),
    );
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const ink = Color(0xFF172B3A);
    const muted = Color(0xFF71808C);
    const blue = Color(0xFF1769AA);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FB),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(26, 36, 26, 28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 410),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: blue,
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: const Icon(
                          Icons.menu_book_rounded,
                          color: Colors.white,
                          size: 21,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'pustakalab',
                        style: TextStyle(
                          color: ink,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -.4,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 58),
                  const Text(
                    'Masuk.',
                    style: TextStyle(
                      color: ink,
                      fontSize: 36,
                      height: 1,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1.3,
                    ),
                  ),
                  const SizedBox(height: 11),
                  const Text(
                    'Gunakan akunmu untuk melanjutkan.',
                    style: TextStyle(color: muted, fontSize: 14),
                  ),
                  const SizedBox(height: 38),
                  const Text(
                    'EMAIL',
                    style: TextStyle(
                      color: muted,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.3,
                    ),
                  ),
                  const SizedBox(height: 9),
                  TextField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.username],
                    decoration: InputDecoration(
                      hintText: 'nama@email.com',
                      prefixIcon: const Icon(Icons.alternate_email, size: 19),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(vertical: 17, horizontal: 15),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE4EAF0)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: blue, width: 1.4),
                      ),
                    ),
                  ),
                  const SizedBox(height: 23),
                  const Text(
                    'PASSWORD',
                    style: TextStyle(
                      color: muted,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.3,
                    ),
                  ),
                  const SizedBox(height: 9),
                  TextField(
                    controller: passwordController,
                    obscureText: obscure,
                    onSubmitted: (_) {
                      if (!loading) login();
                    },
                    autofillHints: const [AutofillHints.password],
                    decoration: InputDecoration(
                      hintText: 'Masukkan password',
                      prefixIcon: const Icon(Icons.lock_outline, size: 19),
                      suffixIcon: IconButton(
                        tooltip: obscure ? 'Tampilkan password' : 'Sembunyikan password',
                        onPressed: () => setState(() => obscure = !obscure),
                        icon: Icon(obscure ? Icons.visibility_off : Icons.visibility, size: 19),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(vertical: 17, horizontal: 15),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE4EAF0)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: blue, width: 1.4),
                      ),
                    ),
                  ),
                  const SizedBox(height: 29),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton(
                      onPressed: loading ? null : login,
                      style: FilledButton.styleFrom(
                        backgroundColor: ink,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: loading
                          ? const SizedBox(
                              width: 21,
                              height: 21,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              'Masuk ke PustakaLab',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Center(
                    child: Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        const Text('Belum punya akun? ', style: TextStyle(color: muted, fontSize: 13)),
                        TextButton(
                          onPressed: loading ? null : _openRegister,
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text('Daftar', style: TextStyle(fontWeight: FontWeight.w800)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 42),
                  const Center(
                    child: Text(
                      'INVENTARIS LABORATORIUM',
                      style: TextStyle(
                        color: Color(0xFF9BA7B1),
                        fontSize: 9,
                        letterSpacing: 1.8,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
