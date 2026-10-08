import 'package:flutter/material.dart';
import 'services/offline.dart';

/// Carte de synchronisation (accueil) : relevés en attente, envoi manuel, relevés refusés.
class SyncCard extends StatelessWidget {
  const SyncCard({super.key});

  String _ago(DateTime? d) {
    if (d == null) return 'jamais';
    final m = DateTime.now().difference(d).inMinutes;
    if (m < 1) return 'à l\'instant';
    if (m < 60) return 'il y a $m min';
    if (m < 1440) return 'il y a ${m ~/ 60} h';
    return 'il y a ${m ~/ 1440} j';
  }

  @override
  Widget build(BuildContext context) {
    final o = Offline.instance;
    return ListenableBuilder(
      listenable: o,
      builder: (context, _) {
        final pending = o.pendingCount, errors = o.errorCount;
        final ok = pending == 0 && errors == 0;
        return Card(
          color: ok ? const Color(0xFFEAF4EC) : const Color(0xFFFFF4D6),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(ok ? Icons.cloud_done : Icons.cloud_upload, color: ok ? const Color(0xFF235535) : const Color(0xFF7A5300)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    ok ? 'Tout est envoyé' : '$pending parcelle(s) en attente d\'envoi${errors > 0 ? ' · $errors refusée(s)' : ''}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ]),
              const SizedBox(height: 4),
              Text('Dernier envoi : ${_ago(o.lastSync)}${o.lastMessage != null && !ok ? '\n${o.lastMessage}' : ''}',
                  style: const TextStyle(fontSize: 12, color: Colors.black54)),
              if (!ok) ...[
                const SizedBox(height: 10),
                Row(children: [
                  if (pending > 0)
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: o.syncing ? null : () async {
                          final n = await o.sync();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: Text(n > 0 ? '$n parcelle(s) envoyée(s).' : (o.lastMessage ?? 'Aucun envoi possible pour le moment.'))));
                          }
                        },
                        icon: o.syncing
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.sync),
                        label: Text(o.syncing ? 'Envoi…' : 'Envoyer maintenant'),
                      ),
                    ),
                  if (pending > 0) const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OutboxScreen())),
                    child: const Text('Détail'),
                  ),
                ]),
              ],
            ]),
          ),
        );
      },
    );
  }
}

/// Liste des relevés gardés sur le téléphone.
class OutboxScreen extends StatelessWidget {
  const OutboxScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final o = Offline.instance;
    return Scaffold(
      appBar: AppBar(title: const Text('Relevés sur le téléphone')),
      body: ListenableBuilder(
        listenable: o,
        builder: (context, _) {
          final items = o.mine;
          if (items.isEmpty) return const Center(child: Text('Aucun relevé en attente.'));
          return ListView.separated(
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final p = items[i];
              final ha = p.body['area_hectares'];
              return ListTile(
                leading: Icon(p.error == null ? Icons.schedule : Icons.error_outline,
                    color: p.error == null ? const Color(0xFF7A5300) : Colors.red),
                title: Text(p.producerName.isEmpty ? 'Parcelle' : p.producerName),
                subtitle: Text([
                  '${ha ?? '—'} ha · relevée le ${p.createdAt.day.toString().padLeft(2, '0')}/${p.createdAt.month.toString().padLeft(2, '0')} '
                      'à ${p.createdAt.hour.toString().padLeft(2, '0')}:${p.createdAt.minute.toString().padLeft(2, '0')}',
                  if (p.error != null) 'Refusée : ${p.error}',
                ].join('\n')),
                isThreeLine: p.error != null,
                trailing: p.error == null
                    ? null
                    : PopupMenuButton<String>(
                        onSelected: (v) async {
                          if (v == 'retry') await o.retry(p);
                          if (v == 'delete' && context.mounted) {
                            final yes = await showDialog<bool>(
                              context: context,
                              builder: (_) => AlertDialog(
                                title: const Text('Supprimer ce relevé ?'),
                                content: const Text('Il sera définitivement effacé du téléphone.'),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
                                  TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Supprimer')),
                                ],
                              ),
                            );
                            if (yes == true) await o.remove(p);
                          }
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 'retry', child: Text('Renvoyer')),
                          PopupMenuItem(value: 'delete', child: Text('Supprimer du téléphone')),
                        ],
                      ),
              );
            },
          );
        },
      ),
    );
  }
}
