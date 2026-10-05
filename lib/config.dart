// Configuration globale de l'application GeoCollect EUDR (mobile)
const String kApiBase = 'https://geocollect-backend.onrender.com/api/v1';
const String kAppName = 'GeoCollect EUDR';

// Connexion avec Google : identifiant client OAuth de type « Application Web » (le même que sur le serveur,
// variable GOOGLE_CLIENT_IDS). Vide = bouton Google masqué.
const String kGoogleWebClientId = '';
// iOS uniquement : identifiant client OAuth de type « iOS » (et son schéma inversé dans ios/Runner/Info.plist).
const String kGoogleIosClientId = '';

// Fonds de carte (mêmes que la version web)
const String kSatelliteTiles = 'https://mt1.google.com/vt/lyrs=s&x={x}&y={y}&z={z}';
const String kOsmTiles = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

// Couleur principale (vert EUDR)
const int kPrimaryColor = 0xFF16A34A;
