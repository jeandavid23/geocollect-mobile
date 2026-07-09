import 'package:flutter/material.dart';
import '../config.dart';
import '../services/api.dart';
import 'login_screen.dart';
import 'producers_screen.dart';
import 'parcels_screen.dart';
import 'account_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  String get _roleLabel {
    switch (Api.instance.role) {
      case 'super_admin': return 'Super Administrateur';
      case 'cooperative': return 'Coopérative';
      default: return 'Agent Mappeur';
    }
  }

  @override
  Widget build(BuildContext context) {
    final api = Api.instance;
    final isAgent = api.role == 'agent';
    return Scaffold(
      appBar: AppBar(
        title: const Text(kAppName),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Déconnexion',
            onPressed: () async {
              await api.logout();
              if (context.mounted) {
                Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
              }
            },
          ),
        ],
      ),
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
              title: Text(api.fullName, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(_roleLabel),
            ),
          ),
          const SizedBox(height: 16),
          if (isAgent) ...[
            _tile(context, Icons.satellite_alt, 'Nouveau mapping',
                'Cartographier une parcelle au GPS', () => _open(context, const ProducersScreen(forMapping: true))),
            _tile(context, Icons.map, 'Mes parcelles',
                'Voir les parcelles que j\'ai enregistrées', () => _open(context, const ParcelsScreen())),
            _tile(context, Icons.people, 'Producteurs à mapper',
                'Producteurs de ma coopérative', () => _open(context, const ProducersScreen(forMapping: false))),
          ] else ...[
            _tile(context, Icons.people, 'Producteurs',
                'Liste des producteurs', () => _open(context, const ProducersScreen(forMapping: false))),
            _tile(context, Icons.map, 'Parcelles',
                'Carte des parcelles', () => _open(context, const ParcelsScreen())),
          ],
          _tile(context, Icons.person, 'Mon compte',
              'Profil et mot de passe', () => _open(context, const AccountScreen())),
        ],
      ),
    );
  }

  void _open(BuildContext c, Widget page) =>
      Navigator.push(c, MaterialPageRoute(builder: (_) => page));

  Widget _tile(BuildContext c, IconData icon, String title, String sub, VoidCallback onTap) => Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: ListTile(
          leading: Icon(icon, color: const Color(kPrimaryColor), size: 30),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text(sub),
          trailing: const Icon(Icons.chevron_right),
          onTap: onTap,
        ),
      );
}
