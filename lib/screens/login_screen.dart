import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../config.dart';
import '../services/api.dart';
import '../services/offline.dart';
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
      await _afterLogin(_pass.text);
    } else if (Api.instance.pendingMfa != null) {
      await _askMfa(_pass.text);
    } else {
      setState(() => _error = 'Identifiant ou mot de passe incorrect.');
    }
  }

  /// Double authentification : code à 6 chiffres de l'application (ou code de secours).
  Future<void> _askMfa(String typedPassword) async {
    final code = TextEditingController();
    String? err;
    while (true) {
      if (!mounted) return;
      final value = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text('Code de vérification'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text("Saisissez le code à 6 chiffres de votre application d'authentification (ou un code de secours)."),
            const SizedBox(height: 12),
            TextField(controller: code, autofocus: true, textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 22, letterSpacing: 6),
                decoration: InputDecoration(hintText: '123456', errorText: err)),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
            FilledButton(onPressed: () => Navigator.pop(ctx, code.text), child: const Text('Valider')),
          ],
        ),
      );
      if (value == null || !mounted) return;
      err = await Api.instance.verifyMfa(value);
      if (err == null) {
        await _afterLogin(typedPassword);
        return;
      }
      code.clear();
    }
  }

  /// Après connexion : mot de passe provisoire → nouveau mot de passe obligatoire, puis accueil.
  Future<void> _afterLogin(String typedPassword) async {
    if (Api.instance.mustChangePassword) {
      final changed = await _forceNewPassword(typedPassword);
      if (!changed) {
        await Api.instance.logout();
        return;
      }
    }
    if (!mounted) return;
    Offline.instance.startAutoSync();
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen()));
  }

  Future<bool> _forceNewPassword(String oldPassword) async {
    final p1 = TextEditingController();
    final p2 = TextEditingController();
    String? err;
    while (true) {
      if (!mounted) return false;
      final go = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text('Choisissez votre mot de passe'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Votre compte a un mot de passe provisoire. Choisissez le vôtre (10 caractères au moins, avec chiffres et lettres).'),
            TextField(controller: p1, obscureText: true, decoration: const InputDecoration(labelText: 'Nouveau mot de passe')),
            TextField(controller: p2, obscureText: true, decoration: InputDecoration(labelText: 'Confirmation', errorText: err)),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Enregistrer')),
          ],
        ),
      );
      if (go != true) return false;
      if (p1.text.length < 10) { err = '10 caractères au moins.'; continue; }
      if (p1.text != p2.text) { err = 'Les deux mots de passe diffèrent.'; continue; }
      if (await Api.instance.changePassword(oldPassword, p1.text)) return true;
      err = 'Mot de passe refusé : trop simple ou trop courant.';
    }
  }

  Future<void> _loginGoogle() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final g = GoogleSignIn(
        scopes: const ['email'],
        serverClientId: kGoogleWebClientId,
        clientId: Platform.isIOS && kGoogleIosClientId.isNotEmpty ? kGoogleIosClientId : null,
      );
      await g.signOut(); // laisse choisir le compte Google à chaque fois
      final account = await g.signIn();
      if (account == null) {
        setState(() => _loading = false); // annulé par l'utilisateur
        return;
      }
      final idToken = (await account.authentication).idToken;
      if (idToken == null) throw Exception('jeton Google absent');
      final err = await Api.instance.loginWithGoogle(idToken);
      if (!mounted) return;
      setState(() => _loading = false);
      if (err == null) {
        Offline.instance.startAutoSync();
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (_) => const HomeScreen()));
      } else if (err == 'mfa') {
        await _askMfa('');
      } else {
        setState(() => _error = err);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Connexion Google impossible. Vérifiez votre connexion Internet.';
      });
    }
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
                      if (kGoogleWebClientId.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          onPressed: _loading ? null : _loginGoogle,
                          icon: const Text('G',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  color: Color(0xFF4285F4))),
                          label: const Text('Se connecter avec Google'),
                          style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(46)),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const Text('Mot de passe oublié ? Demandez-le à votre coopérative.',
                    style: TextStyle(color: Color(0xFF9FD8B4), fontSize: 12)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
