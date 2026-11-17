import 'package:flutter/material.dart';

import '../services/auth_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final nameController = TextEditingController();
  final classController = TextEditingController();
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

  Future<void> register() async {
    final name = nameController.text.trim();
    final kelas = classController.text.trim();
    final email = emailController.text.trim();
    final password = passwordController.text;

    final missing = <String>[];
    if (name.isEmpty) missing.add('Nama lengkap');
    if (kelas.isEmpty) missing.add('Kelas');
    if (email.isEmpty) missing.add('Email');
    if (password.isEmpty) missing.add('Password');

    if (missing.isNotEmpty) {
      await _showAlert(
        'Data belum lengkap',
        'Bagian berikut wajib diisi:\n\n${missing.map((field) => '• $field').join('\n')}',
      );
      return;
    }

    final emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    if (!emailPattern.hasMatch(email)) {
      await _showAlert('Email tidak valid', 'Periksa kembali bagian Email.');
      return;
    }
    if (password.length < 6) {
      await _showAlert(
        'Password belum memenuhi syarat',
        'Bagian Password harus berisi minimal 6 karakter.',
      );
      return;
    }

    setState(() => loading = true);
    final error = await auth.register(
      name: name,
      kelas: kelas,
      email: email,
      password: password,
    );

    if (!mounted) return;
    setState(() => loading = false);

    if (error == null) {
      Navigator.of(context).pop(true);
    } else {
      await _showAlert('Pendaftaran gagal', error);
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    classController.dispose();
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Buat akun')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(25),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Daftar PustakaLab',
                    style: TextStyle(fontSize: 27, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text('Buat akun untuk mulai menggunakan inventaris.'),
                  const SizedBox(height: 30),
                  _label('Nama Lengkap'),
                  TextField(
                    controller: nameController,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      hintText: 'Nama lengkap',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                  ),
                  const SizedBox(height: 18),
                  _label('Kelas'),
                  TextField(
                    controller: classController,
                    textCapitalization: TextCapitalization.characters,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      hintText: 'Contoh: XI RPL 1',
                      prefixIcon: Icon(Icons.school_outlined),
                    ),
                  ),
                  const SizedBox(height: 18),
                  _label('Email'),
                  TextField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      hintText: 'Email aktif',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                  ),
                  const SizedBox(height: 18),
                  _label('Password'),
                  TextField(
                    controller: passwordController,
                    obscureText: obscure,
                    onSubmitted: (_) {
                      if (!loading) register();
                    },
                    decoration: InputDecoration(
                      hintText: 'Minimal 6 karakter',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        tooltip: obscure ? 'Tampilkan password' : 'Sembunyikan password',
                        icon: Icon(obscure ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setState(() => obscure = !obscure),
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton(
                      onPressed: loading ? null : register,
                      child: loading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text('Daftar sekarang'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Center(
                    child: Text(
                      'Setelah mendaftar, kamu akan diarahkan kembali ke halaman login.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: Colors.black54),
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

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600)),
      );
}
