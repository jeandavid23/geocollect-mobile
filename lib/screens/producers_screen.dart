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

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final list = await Api.instance.list('/producers/');
    if (!mounted) return;
    setState(() { _producers = list; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.forMapping ? 'Choisir un producteur' : 'Producteurs')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _producers.isEmpty
                  ? ListView(children: const [
                      Padding(padding: EdgeInsets.all(40),
                          child: Center(child: Text('Aucun producteur.\nTirez pour rafraîchir.', textAlign: TextAlign.center)))
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
                              : Text('${p['parcel_count'] ?? 0} parc.'),
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
