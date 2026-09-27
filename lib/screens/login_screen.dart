import 'package:flutter/material.dart';
import '../config.dart';
import '../services/api.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _user = TextEditingController();
  final _pass = TextEditingController();
  bool _loading = false;
  String? _error;

  Future<void> _login() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final ok = await Api.instance.login(_user.text.trim(), _pass.text);
    if (!mounted) return;
    setState(() => _loading = false);
    if (ok) {
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => const HomeScreen()));
    } else {
      setState(() => _error = 'Identifiant ou mot de passe incorrect.');
    }
  }

  void _fill(String u, String p) {
    _user.text = u;
    _pass.text = p;
  }

  @override
  Widget build(BuildContext context) {
    const green = Color(kPrimaryColor);
    return Scaffold(
      backgroundColor: const Color(0xFF123F24),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20)),
                  child: Icon(Icons.eco, color: green, size: 40),
                ),
                const SizedBox(height: 16),
                const Text('GeoCollect EUDR',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.bold)),
                const Text('Cartographie GPS & conformité EUDR',
                    style: TextStyle(color: Color(0xFFC7E4D1))),
                const SizedBox(height: 28),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20)),
                  child: Column(
                    children: [
                      TextField(
                        controller: _user,
                        decoration: const InputDecoration(
                            labelText: 'Identifiant',
                            border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _pass,
                        obscureText: true,
                        decoration: const InputDecoration(
                            labelText: 'Mot de passe',
                            border: OutlineInputBorder()),
                      ),
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(_error!,
                              style: const TextStyle(color: Colors.red)),
                        ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: _loading ? null : _login,
                        child: _loading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : const Text('Se connecter'),
                      ),
                      const SizedBox(height: 8),
                      Wrap(spacing: 6, children: [
                        _demo('admin', 'admin123'),
                        _demo('coop', 'coop123'),
                        _demo('agent', 'agent123'),
                      ]),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const Text('Le serveur peut mettre 30-50 s à se réveiller.',
                    style: TextStyle(color: Color(0xFF9FD8B4), fontSize: 12)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _demo(String u, String p) => ActionChip(
        label: Text(u, style: const TextStyle(fontSize: 12)),
        onPressed: () => _fill(u, p),
      );
}
