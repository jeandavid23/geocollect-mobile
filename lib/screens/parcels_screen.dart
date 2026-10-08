import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../config.dart';
import '../services/api.dart';
import '../services/offline.dart';

class ParcelsScreen extends StatefulWidget {
  const ParcelsScreen({super.key});
  @override
  State<ParcelsScreen> createState() => _ParcelsScreenState();
}

class _ParcelsScreenState extends State<ParcelsScreen> {
  List<dynamic> _parcels = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final r = await Api.instance.listCached('/parcels/?page_size=2000', 'parcels');
    if (!mounted) return;
    setState(() { _parcels = r.data; _loading = false; });
  }

  Color _color(String? status) {
    switch (status) {
      case 'compliant': return const Color(0xFF16A34A);
      case 'non_compliant': return const Color(0xFFDC2626);
      default: return const Color(0xFFF59E0B);
    }
  }

  List<Polygon> _polygons() {
    final polys = <Polygon>[];
    for (final p in _parcels) {
      final geom = p['geometry'];
      if (geom == null) continue;
      final ring = (geom['coordinates'] as List).isEmpty ? null : geom['coordinates'][0] as List;
      if (ring == null || ring.length < 3) continue;
      final pts = ring.map<LatLng>((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble())).toList();
      final c = _color(p['eudr_status'] as String?);
      polys.add(Polygon(points: pts, color: c.withValues(alpha: 0.35), borderColor: c, borderStrokeWidth: 2));
    }
    // relevés pas encore envoyés : en bleu, bordure pointillée
    for (final p in Offline.instance.mine) {
      final ring = (p.body['geometry']?['coordinates'] as List?)?.first as List?;
      if (ring == null || ring.length < 3) continue;
      final pts = ring.map<LatLng>((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble())).toList();
      polys.add(Polygon(points: pts, color: const Color(0x552563EB), borderColor: const Color(0xFF2563EB), borderStrokeWidth: 2,
          pattern: StrokePattern.dashed(segments: const [8, 6])));
    }
    return polys;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Parcelles (${_parcels.length}${Offline.instance.pendingCount > 0 ? ' + ${Offline.instance.pendingCount} en attente' : ''})')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : FlutterMap(
              options: const MapOptions(initialCenter: LatLng(7.67, -5.68), initialZoom: 12),
              children: [
                TileLayer(urlTemplate: kSatelliteTiles, userAgentPackageName: 'ci.geolab.geocollect'),
                PolygonLayer(polygons: _polygons()),
              ],
            ),
    );
  }
}
