import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'home_screen.dart';
import 'login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkLogin();
  }

  Future<void> _checkLogin() async {
    await Future<void>.delayed(const Duration(seconds: 3));
    if (!mounted) return;

    User? user;
    try {
      user = await FirebaseAuth.instance.authStateChanges().first;
    } catch (error) {
      debugPrint('Gagal memeriksa sesi: $error');
    }

    if (user != null) {
      try {
        final profile = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        if (!profile.exists || profile.data()?['active'] == false) {
          await FirebaseAuth.instance.signOut();
          user = null;
        }
      } catch (error) {
        debugPrint('Gagal memvalidasi profil: $error');
        // Keep a valid existing session when the profile check only fails
        // because the network is temporarily unavailable.
      }
    }

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => user == null ? const LoginScreen() : const HomeScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1769AA),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(25),
              ),
              child: const Icon(
                Icons.science,
                size: 65,
                color: Color(0xFF1769AA),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'PustakaLab',
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Laboratory Inventory System',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 35),
            const CircularProgressIndicator(color: Colors.white),
          ],
        ),
      ),
    );
  }
}
