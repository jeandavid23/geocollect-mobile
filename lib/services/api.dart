import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';

/// Service API unique (singleton) — gère le token JWT et les appels au backend Django.
class Api {
  Api._();
  static final Api instance = Api._();

  String? _access;
  String? _refresh;
  Map<String, dynamic>? user;

  bool get isLoggedIn => _access != null;
  String get role => (user?['role'] ?? '').toString();
  String get fullName => (user?['full_name'] ?? user?['username'] ?? '').toString();
  String? get cooperativeId => user?['cooperative_id']?.toString();

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_access != null) 'Authorization': 'Bearer $_access',
      };

  Future<void> loadToken() async {
    final p = await SharedPreferences.getInstance();
    _access = p.getString('access');
    _refresh = p.getString('refresh');
    final u = p.getString('user');
    if (u != null) user = jsonDecode(u) as Map<String, dynamic>;
  }

  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    if (_access != null) await p.setString('access', _access!);
    if (_refresh != null) await p.setString('refresh', _refresh!);
    if (user != null) await p.setString('user', jsonEncode(user));
  }

  Future<void> logout() async {
    final p = await SharedPreferences.getInstance();
    await p.remove('access');
    await p.remove('refresh');
    await p.remove('user');
    _access = null;
    _refresh = null;
    user = null;
  }

  /// Connexion — renvoie true si succès.
  Future<bool> login(String username, String password) async {
    final r = await http.post(
      Uri.parse('$kApiBase/auth/login/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username, 'password': password}),
    );
    if (r.statusCode == 200) {
      final d = jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
      _access = d['access'];
      _refresh = d['refresh'];
      user = d['user'];
      await _save();
      return true;
    }
    return false;
  }

  /// Connexion avec Google : le jeton d'identité est vérifié par le serveur, qui retrouve le compte par son e-mail.
  /// Renvoie null si succès, sinon le message d'erreur à afficher.
  Future<String?> loginWithGoogle(String idToken) async {
    final r = await http.post(
      Uri.parse('$kApiBase/auth/google/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'credential': idToken}),
    );
    final d = jsonDecode(utf8.decode(r.bodyBytes));
    if (r.statusCode == 200 && d is Map<String, dynamic>) {
      _access = d['access'];
      _refresh = d['refresh'];
      user = d['user'];
      await _save();
      return null;
    }
    return (d is Map && d['detail'] != null) ? d['detail'].toString() : 'Connexion Google impossible.';
  }

  /// Liste (gère la pagination DRF).
  Future<List<dynamic>> list(String path) async {
    final r = await http.get(Uri.parse('$kApiBase$path'), headers: _headers);
    if (r.statusCode == 200) {
      final d = jsonDecode(utf8.decode(r.bodyBytes));
      if (d is List) return d;
      return (d['results'] ?? []) as List<dynamic>;
    }
    return [];
  }

  /// Création (POST).
  Future<Map<String, dynamic>?> create(String path, Map<String, dynamic> body) async {
    final r = await http.post(Uri.parse('$kApiBase$path'), headers: _headers, body: jsonEncode(body));
    if (r.statusCode == 200 || r.statusCode == 201) {
      return jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
    }
    return null;
  }

  /// Changement de mot de passe.
  Future<bool> changePassword(String oldP, String newP) async {
    final r = await http.post(
      Uri.parse('$kApiBase/auth/change-password/'),
      headers: _headers,
      body: jsonEncode({'old_password': oldP, 'new_password': newP}),
    );
    return r.statusCode == 200;
  }
}
