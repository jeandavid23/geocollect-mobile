import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../config.dart';
import '../services/api.dart';

class MappingScreen extends StatefulWidget {
  final Map<String, dynamic> producer;
  const MappingScreen({super.key, required this.producer});
  @override
  State<MappingScreen> createState() => _MappingScreenState();
}

class _MappingScreenState extends State<MappingScreen> {
  final MapController _map = MapController();
  final List<LatLng> _points = [];
  LatLng? _current;
  double _accuracy = 0;
  bool _saving = false;
  String _status = 'Acquisition du GPS...';

  @override
  void initState() {
    super.initState();
    _startGps();
  }

  Future<void> _startGps() async {
    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
      setState(() => _status = 'Autorisation GPS refusée.');
      return;
    }
    Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.best, distanceFilter: 1),
    ).listen((pos) {
      if (!mounted) return;
      setState(() {
        _current = LatLng(pos.latitude, pos.longitude);
        _accuracy = pos.accuracy;
        _status = 'GPS actif · précision ±${pos.accuracy.toStringAsFixed(0)} m';
      });
      _map.move(_current!, _map.camera.zoom);
    });
  }

  void _markPoint() {
    if (_current == null) return;
    setState(() => _points.add(_current!));
  }

  void _undo() {
    if (_points.isNotEmpty) setState(() => _points.removeLast());
  }

  // Superficie approx (hectares) via formule sphérique
  double _areaHa() {
    if (_points.length < 3) return 0;
    const R = 6371000.0;
    double area = 0;
    for (int i = 0; i < _points.length; i++) {
      final j = (i + 1) % _points.length;
      final lat1 = _points[i].latitude * pi / 180;
      final lat2 = _points[j].latitude * pi / 180;
      final dLng = (_points[j].longitude - _points[i].longitude) * pi / 180;
      area += dLng * (2 + sin(lat1) + sin(lat2));
    }
    area = (area * R * R / 2).abs();
    return area / 10000;
  }

  double _perimeterM() {
    if (_points.length < 2) return 0;
    const dist = Distance();
    double total = 0;
    for (int i = 0; i < _points.length; i++) {
      final j = (i + 1) % _points.length;
      total += dist(_points[i], _points[j]);
    }
    return total;
  }

  Future<void> _finish() async {
    if (_points.length < 3) return;
    setState(() => _saving = true);
    final coords = [
      ..._points.map((p) => [p.longitude, p.latitude]),
      [_points.first.longitude, _points.first.latitude],
    ];
    final body = {
      'producer': widget.producer['id'],
      'name': 'Parcelle ${widget.producer['field_id_base'] ?? ''}',
      'culture': 'Cacao',
      'area_hectares': double.parse(_areaHa().toStringAsFixed(2)),
      'perimeter_meters': _perimeterM().round(),
      'vertex_count': _points.length,
      'geometry': {'type': 'Polygon', 'coordinates': [coords]},
      'is_synced': true,
    };
    final res = await Api.instance.create('/parcels/', body);
    if (!mounted) return;
    setState(() => _saving = false);
    if (res != null) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Parcelle enregistrée ✓'),
          content: Text('${res['field_id'] ?? ''}\nScore EUDR : ${res['eudr_score'] ?? '—'} %\nStockée dans la base.'),
          actions: [
            TextButton(
              onPressed: () { Navigator.pop(context); Navigator.pop(context); },
              child: const Text('Terminer'),
            ),
          ],
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Échec de l\'enregistrement. Vérifiez la connexion.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final center = _current ?? const LatLng(7.67, -5.68);
    return Scaffold(
      appBar: AppBar(title: Text('Mapping · ${widget.producer['full_name'] ?? ''}')),
      body: Column(
        children: [
          Container(
            color: const Color(0xFF123F24),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _stat('Sommets', '${_points.length}'),
                _stat('Superficie', '${_areaHa().toStringAsFixed(2)} ha'),
                _stat('Périmètre', '${_perimeterM().round()} m'),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            color: const Color(0xFFE7F3EA),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Text(_status, style: const TextStyle(fontSize: 12)),
          ),
          Expanded(
            child: FlutterMap(
              mapController: _map,
              options: MapOptions(initialCenter: center, initialZoom: 17),
              children: [
                TileLayer(urlTemplate: kSatelliteTiles, userAgentPackageName: 'ci.geolab.geocollect'),
                if (_points.length >= 3)
                  PolygonLayer(polygons: [
                    Polygon(
                      points: _points,
                      color: const Color(0x5522C55E),
                      borderColor: const Color(kPrimaryColor),
                      borderStrokeWidth: 3,
                    ),
                  ]),
                MarkerLayer(markers: [
                  for (int i = 0; i < _points.length; i++)
                    Marker(
                      point: _points[i], width: 26, height: 26,
                      child: Container(
                        decoration: const BoxDecoration(color: Color(kPrimaryColor), shape: BoxShape.circle),
                        child: Center(child: Text('${i + 1}', style: const TextStyle(color: Colors.white, fontSize: 12))),
                      ),
                    ),
                  if (_current != null)
                    Marker(
                      point: _current!, width: 22, height: 22,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.blue, shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                        ),
                      ),
                    ),
                ]),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _current == null ? null : _markPoint,
                    icon: const Icon(Icons.add_location_alt),
                    label: const Text('Marquer ce point'),
                  ),
                ),
                const SizedBox(height: 8),
                Row(children: [
                  OutlinedButton.icon(
                    onPressed: _points.isEmpty ? null : _undo,
                    icon: const Icon(Icons.undo), label: const Text('Annuler'),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(backgroundColor: Colors.red),
                      onPressed: (_points.length < 3 || _saving) ? null : _finish,
                      icon: _saving
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.check),
                      label: Text(_saving ? 'Enregistrement...' : 'Terminer'),
                    ),
                  ),
                ]),
                if (_points.length < 3)
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Text('Minimum 3 points pour fermer le polygone', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _stat(String label, String value) => Column(
        children: [
          Text(label, style: const TextStyle(color: Color(0xFF9FD8B4), fontSize: 11)),
          Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ],
      );
}
