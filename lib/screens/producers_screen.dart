import 'package:flutter/material.dart';
import '../config.dart';
import '../services/api.dart';
import 'mapping_screen.dart';

class ProducersScreen extends StatefulWidget {
  final bool forMapping;
  const ProducersScreen({super.key, required this.forMapping});
  @override
  State<ProducersScreen> createState() => _ProducersScreenState();
}

class _ProducersScreenState extends State<ProducersScreen> {
  List<dynamic> _producers = [];
  bool _loading = true;
  bool _fromCache = false;
  // mapping : par défaut les producteurs du registre sans aucun polygone (« à mapper »)
  bool _onlyToMap = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final toMap = widget.forMapping && _onlyToMap;
    final r = await Api.instance.listCached(
        toMap ? '/producers/?to_map=true&page_size=2000' : '/producers/?page_size=2000', toMap ? 'producers_to_map' : 'producers');
    if (!mounted) return;
    setState(() { _producers = r.data; _fromCache = r.fromCache; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.forMapping ? (_onlyToMap ? 'Producteurs à mapper' : 'Tous les producteurs') : 'Producteurs'),
        actions: [
          if (widget.forMapping)
            TextButton(
              onPressed: () { setState(() => _onlyToMap = !_onlyToMap); _load(); },
              child: Text(_onlyToMap ? 'Voir tous' : 'À mapper', style: const TextStyle(color: Colors.white)),
            ),
        ],
        bottom: _fromCache
            ? const PreferredSize(
                preferredSize: Size.fromHeight(28),
                child: ColoredBox(
                  color: Color(0xFFFFF4D6),
                  child: SizedBox(width: double.infinity, height: 28,
                      child: Center(child: Text('Hors ligne : liste enregistrée sur le téléphone',
                          style: TextStyle(fontSize: 12, color: Color(0xFF7A5300))))),
                ))
            : null,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _producers.isEmpty
                  ? ListView(children: const [
                      Padding(padding: EdgeInsets.all(40),
                          child: Center(child: Text('Aucun producteur à afficher.\nTirez pour rafraîchir.', textAlign: TextAlign.center)))
                    ])
                  : ListView.separated(
                      itemCount: _producers.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final p = _producers[i] as Map<String, dynamic>;
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: const Color(0xFFDCFCE7),
                            child: Text('${p['field_id_base'] ?? ''}'.padRight(1)[0],
                                style: const TextStyle(color: Color(kPrimaryColor))),
                          ),
                          title: Text('${p['full_name'] ?? ''}'),
                          subtitle: Text('${p['field_id_base'] ?? ''} · ${p['village'] ?? ''}'),
                          trailing: widget.forMapping
                              ? const Icon(Icons.satellite_alt, color: Color(kPrimaryColor))
                              : Text('${p['polygon_count'] ?? p['parcel_count'] ?? 0} polyg.'),
                          onTap: widget.forMapping
                              ? () => Navigator.push(context, MaterialPageRoute(
                                  builder: (_) => MappingScreen(producer: p)))
                              : null,
                        );
                      },
                    ),
            ),
    );
  }
}
