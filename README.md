# Kaggu Xam Xam 🎙️

Application Flutter d'enseignements islamiques audio — **Taysir Digital Group (TDG)**

---

## 📁 Structure du projet

```
kaggu_xam_xam/
├── lib/
│   ├── main.dart                    # Point d'entrée
│   ├── models/
│   │   └── models.dart              # Professor, AudioTheme, AudioTrack
│   ├── providers/
│   │   └── app_provider.dart        # État global (Provider)
│   ├── services/
│   │   ├── bibliotheque_service.dart  # Chargement JSON (remote + local)
│   │   ├── download_service.dart      # Téléchargement audios par thème
│   │   ├── audio_service.dart         # Lecteur just_audio
│   │   └── ad_service.dart            # AdMob bannière + interstitiel
│   ├── screens/
│   │   ├── home_screen.dart           # Page principale
│   │   └── info_screen.dart           # Page infos / à propos
│   ├── widgets/
│   │   ├── sidebar_drawer.dart        # Drawer avec profs et thèmes
│   │   ├── audio_track_list.dart      # Liste des pistes audio
│   │   ├── audio_player_widget.dart   # Lecteur complet
│   │   ├── download_sheet.dart        # Bottom sheet téléchargement
│   │   └── banner_ad_widget.dart      # Bannière AdMob
│   └── utils/
│       ├── constants.dart             # URLs, IDs AdMob, infos app
│       ├── app_theme.dart             # Thème Material 3
│       └── string_utils.dart          # formatAudioTitle, formatDuration
├── assets/
│   ├── bibliotheque.json              # Catalogue embarqué (fallback)
│   └── images/
│       ├── kxx_icon.png               # Icône Kaggu Xam Xam
│       ├── tdg_logo.png               # Logo Taysir Digital Group
│       ├── sam_mbaye.jpg              # Photo S. Sam Mbaye
│       ├── bass_khelcom.jpg           # Photo S. Bass Kelcom
│       └── abdou_rahmane.jpg           # Photo S. Abdou Rahmane
└── android/
    └── app/
        ├── build.gradle               # NDK r26d, minSdk 24
        └── src/main/
            └── AndroidManifest.xml    # Permissions + services audio
```

---

## 🚀 Installation et build

### Prérequis

| Outil | Version |
|-------|---------|
| Flutter SDK | ≥ 3.22 |
| Dart SDK | ≥ 3.2 |
| Android NDK | **r26d** (26.1.10909125) |
| Android API | **minSdk 24** (Android 7.0+) |
| Java | 17+ |

### 1. Cloner et installer les dépendances

```bash
cd kaggu_xam_xam
flutter pub get
```

### 2. Ajouter les images assets

Placer dans `assets/images/` :
- `kxx_icon.png` — icône de l'app (512×512 recommandé)
- `tdg_logo.png` — logo TDG rond
- `sam_mbaye.jpg` — photo S. Sam Mbaye
- `bass_khelcom.jpg` — photo S. Bass Kelcom
- `abdou_rahmane.jpg` — photo S. Abdou Rahmane

### 3. Configurer le NDK dans local.properties

```properties
# android/local.properties
sdk.dir=/path/to/your/Android/sdk
flutter.sdk=/path/to/your/flutter
ndk.dir=/path/to/your/Android/sdk/ndk/26.1.10909125
```

Ou installer le NDK r26d via Android Studio :
> SDK Manager → SDK Tools → NDK (Side by side) → 26.1.10909125

### 4. Générer les icônes lanceur

```bash
flutter pub run flutter_launcher_icons
```

### 5. Build APK debug

```bash
flutter build apk --debug
```

### 6. Build APK release

```bash
flutter build apk --release --split-per-abi
```

Les APKs se trouvent dans `build/app/outputs/flutter-apk/`.

---

## ⚙️ Configuration

### Changer les URLs du dépôt audio

Éditer `lib/utils/constants.dart` :

```dart
static const String repoBaseUrl =
    'https://raw.githubusercontent.com/VotreOrg/votre-repo/main';
```

### Structure attendue dans le dépôt GitHub

```
votre-repo/
├── bibliotheque.json          # Catalogue des audios
└── audio/
    ├── s_abdou_rahmane/
    │   ├── kun_katiman/
    │   │   ├── kun_katiman_001.ogg
    │   │   └── kun_katiman_002.ogg
    │   └── tazawwudus_sixar/
    │       ├── tazawudus_sixar_001.ogg
    │       └── ...
    ├── s_bass_kelcom/
    │   └── histoire_du_prophete_psl/
    │       ├── 01_le_debut_de_l_islam.ogg
    │       └── ...
    └── s_sam_mbaye/
        ├── ak_talube/
        │   └── ...
        └── axiruz_zaman/
            └── ...
```

> **Note :** Les noms de dossiers sont générés automatiquement par `toSlug()` à partir des noms dans `bibliotheque.json`.

### Configurer AdMob en production

Remplacer dans `lib/utils/constants.dart` :

```dart
static const String admobAppId = 'ca-app-pub-XXXXX~XXXXXXXX'; // votre App ID
static const String bannerAdUnitId = 'ca-app-pub-XXXXX/XXXXXXXX';
static const String interstitialAdUnitId = 'ca-app-pub-XXXXX/XXXXXXXX';
```

Et dans `android/app/src/main/AndroidManifest.xml`, mettre à jour :

```xml
<meta-data
    android:name="com.google.android.gms.ads.APPLICATION_ID"
    android:value="ca-app-pub-XXXXX~XXXXXXXX" />
```

---

## 🎵 Fonctionnement de la bibliothèque hybride

1. **Au démarrage**, l'app tente de télécharger `bibliotheque.json` depuis GitHub.
2. Elle calcule le **hash MD5** du JSON distant et le compare au hash stocké localement.
3. Si le hash a changé → mise à jour du fichier local.
4. Si pas de réseau → utilise le fichier local sauvegardé, ou l'asset embarqué.

### Lecture des audios

- Si un audio est **téléchargé** → lecture locale (`file://`)
- Sinon → **streaming direct** depuis GitHub (`https://`)

### Téléchargement

- Bouton 📥 sur chaque thème dans la liste et dans le drawer
- Bottom sheet avec progression par piste
- Annulation possible
- Suppression des audios locaux

---

## 📢 Publicité

| Type | Déclencheur |
|------|-------------|
| Bannière | Toujours visible en bas (Home + Info) |
| Interstitiel | Clic sur un thème (1er clic ou si ≥ 3min depuis la dernière pub) |

---

## 🔧 Dépendances principales

| Package | Usage |
|---------|-------|
| `just_audio` | Lecteur audio multi-format |
| `just_audio_background` | Lecture en arrière-plan + notification |
| `audio_session` | Gestion session audio Android |
| `provider` | State management |
| `dio` | Téléchargements HTTP avec progression |
| `path_provider` | Chemins de stockage |
| `shared_preferences` | Persistance hash + timing pub |
| `crypto` | Hash MD5 du JSON |
| `marquee` | Défilement du titre long dans le lecteur |
| `google_mobile_ads` | AdMob bannière + interstitiel |
| `permission_handler` | Permissions stockage |

---

## 📄 Licence

© 2025 Taysir Digital Group (TDG) — Tous droits réservés
