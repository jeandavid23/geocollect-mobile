import 'package:flutter/material.dart';
import '../config.dart';
import '../services/api.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});
  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final _old = TextEditingController();
  final _new = TextEditingController();
  final _confirm = TextEditingController();
  bool _saving = false;
  String? _msg;
  bool _ok = false;

  Future<void> _change() async {
    setState(() { _msg = null; });
    if (_new.text.length < 6) { setState(() { _msg = 'Minimum 6 caractères.'; _ok = false; }); return; }
    if (_new.text != _confirm.text) { setState(() { _msg = 'Les mots de passe ne correspondent pas.'; _ok = false; }); return; }
    setState(() => _saving = true);
    final ok = await Api.instance.changePassword(_old.text, _new.text);
    if (!mounted) return;
    setState(() {
      _saving = false; _ok = ok;
      _msg = ok ? 'Mot de passe modifié avec succès.' : 'Échec (mot de passe actuel incorrect ?).';
      if (ok) { _old.clear(); _new.clear(); _confirm.clear(); }
    });
  }

  @override
  Widget build(BuildContext context) {
    final api = Api.instance;
    return Scaffold(
      appBar: AppBar(title: const Text('Mon compte')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: const Color(kPrimaryColor),
                child: Text(api.fullName.isNotEmpty ? api.fullName[0].toUpperCase() : '?',
                    style: const TextStyle(color: Colors.white)),
              ),
              title: Text(api.fullName),
              subtitle: Text('Identifiant : ${api.user?['username'] ?? ''}'),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Changer mon mot de passe', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          TextField(controller: _old, obscureText: true, decoration: const InputDecoration(labelText: 'Mot de passe actuel', border: OutlineInputBorder())),
          const SizedBox(height: 10),
          TextField(controller: _new, obscureText: true, decoration: const InputDecoration(labelText: 'Nouveau mot de passe', border: OutlineInputBorder())),
          const SizedBox(height: 10),
          TextField(controller: _confirm, obscureText: true, decoration: const InputDecoration(labelText: 'Confirmer', border: OutlineInputBorder())),
          if (_msg != null) Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(_msg!, style: TextStyle(color: _ok ? Colors.green : Colors.red)),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _saving ? null : _change,
            child: Text(_saving ? 'Modification...' : 'Modifier le mot de passe'),
          ),
        ],
      ),
    );
  }
}
