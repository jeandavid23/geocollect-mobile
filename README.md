# 📱 GeoCollect EUDR — Application mobile (Flutter)

Application mobile native (Android / iOS) de cartographie GPS et de conformité EUDR, connectée à la **même API** que la version web.

- 🔌 API : `https://geocollect-backend.onrender.com/api/v1`
- Comptes démo : `admin/admin123` · `coop/coop123` · `agent/agent123`

## Fonctionnalités
- Connexion sécurisée (JWT) avec les mêmes comptes que le web
- **Agent** : sélection d'un producteur → **cartographie GPS temps réel** (marquage des sommets, superficie/périmètre en direct) → enregistrement dans la base
- Carte des parcelles (fond satellite), colorées par statut EUDR
- Producteurs de la coopérative
- Mon compte + changement de mot de passe

## Stack
Flutter · Dart · `http` · `shared_preferences` · `geolocator` (GPS) · `flutter_map` + `latlong2` (cartes)

## Structure
```
lib/
  main.dart              point d'entrée + thème
  config.dart            URL de l'API + fonds de carte
  services/api.dart      client HTTP + gestion du token JWT
  screens/
    login_screen.dart    connexion
    home_screen.dart     accueil par rôle
    producers_screen.dart liste / sélection des producteurs
    mapping_screen.dart  cartographie GPS (cœur de l'app)
    parcels_screen.dart  carte des parcelles
    account_screen.dart  profil + mot de passe
```

## Finaliser et lancer

Ce dépôt contient le code source. Pour générer les dossiers de plateforme (android/ios) et lancer :

```bash
# 1. Installer Flutter (https://docs.flutter.dev/get-started/install)
#    puis, dans ce dossier :
flutter create .            # génère android/ ios/ (sans écraser lib/ ni pubspec.yaml)
flutter pub get             # installe les dépendances

# 2. Autoriser la localisation dans Android :
#    android/app/src/main/AndroidManifest.xml  ->  ajouter avant <application> :
#    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
#    <uses-permission android:name="android.permission.INTERNET"/>

# 3. Lancer sur un appareil/emulateur :
flutter run

# 4. Générer l'APK :
flutter build apk --release   # -> build/app/outputs/flutter-apk/app-release.apk
```

*GeoCollect EUDR — une solution GeoLab Service.*
