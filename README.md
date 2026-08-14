# Kaggu Xam Xam 🎙️

Application Flutter d'enseignements islamiques audio — **Taysir Digital Group (TDG)**

---

## 📁 Structure du projet

```
kaggu_xam_xam/
├── lib/
│   ├── main.dart
│   ├── models/
│   │   └── models.dart                    # Professor (+ role), AudioTheme, AudioTrack
│   ├── providers/
│   │   └── app_provider.dart              # État global, persistance lecture, téléchargement
│   ├── services/
│   │   ├── bibliotheque_service.dart      # Chargement JSON (remote → local → asset)
│   │   ├── download_service.dart          # Téléchargement, retry, suppression
│   │   ├── audio_service.dart             # Lecteur just_audio + artwork notification
│   │   ├── ad_service.dart                # AdMob bannière + interstitiel (cooldown 3min)
│   │   ├── connectivity_service.dart      # Détection réseau hors-ligne
│   │   ├── permission_service.dart        # Permissions stockage Android
│   │   └── playback_persistence_service.dart  # Sauvegarde/restauration position lecture
│   ├── screens/
│   │   ├── home_screen.dart               # Page principale + bloc Reprendre + copyright
│   │   └── info_screen.dart               # Page infos / à propos / soutenir
│   ├── widgets/
│   │   ├── sidebar_drawer.dart            # Drawer profs/thèmes + dialogs offline/resume
│   │   ├── audio_track_list.dart          # Liste pistes + dialog hors-ligne piste
│   │   ├── audio_player_widget.dart       # Lecteur complet (slider, vitesse, boucle)
│   │   ├── download_sheet.dart            # Bottom sheet téléchargement/suppression
│   │   └── banner_ad_widget.dart          # Bannière AdMob
│   └── utils/
│       ├── constants.dart                 # URLs, IDs AdMob, constantes réseau, infos app
│       ├── app_theme.dart                 # Thème Material 3 (navy + gold)
│       └── string_utils.dart             # formatAudioTitle, formatDuration, toSlug
├── assets/
│   ├── bibliotheque.json                  # Catalogue embarqué (fallback hors-ligne)
│   ├── audios/                            # Audios embarqués (copiés au 1er lancement)
│   │   ├── s_sam_mbaye/
│   │   │   ├── <themeKey>/
│   │   │   │   └── *.ogg
│   │   └── ...
│   └── images/
│       ├── kxx_icon.png                   # Icône Kaggu Xam Xam (512×512)
│       ├── tdg_logo.png                   # Logo Taysir Digital Group
│       ├── s_sam_mbaye.jpg                # Photo S. Sam Mbaye   ← convention auto
│       ├── s_bass_khelcom.jpg             # Photo S. Bass Khelcom ← convention auto
│       └── s_abdou_rahmane.jpg            # Photo S. Abdou Rahmane ← convention auto
└── android/
    ├── app/
    │   ├── build.gradle                   # NDK 28.2.13676358, compileSdk 36, minSdk 24
    │   └── src/main/
    │       └── AndroidManifest.xml        # Permissions + service audio arrière-plan
    ├── settings.gradle                    # AGP 8.7.3, Kotlin 2.1.0
    └── gradle/wrapper/
        └── gradle-wrapper.properties      # Gradle 8.11.1
```

---

## 🚀 Installation et build

### Prérequis

| Outil | Version |
|-------|---------|
| Flutter SDK | ≥ 3.22 |
| Dart SDK | ≥ 3.2 |
| Android NDK | **28.2.13676358** (requis par les plugins audio/ads) |
| Android compileSdk | **36** |
| Android minSdk | **24** (Android 7.0+) |
| Java | 17+ |

### 1. Installer les dépendances

```bash
cd kaggu_xam_xam
flutter pub get
```

### 2. Ajouter les images assets

Placer dans `assets/images/` en respectant la **convention de nommage automatique** :

| Nom dans `bibliotheque.json` | Fichier image attendu |
|------------------------------|-----------------------|
| `S Sam Mbaye` | `assets/images/s_sam_mbaye.jpg` |
| `S Bass Khelcom` | `assets/images/s_bass_khelcom.jpg` |
| `S Abdou Rahmane` | `assets/images/s_abdou_rahmane.jpg` |
| `S Saliou Sow` | `assets/images/s_saliou_sow.jpg` |

> La règle est `toSlug(nomDuProf) + ".jpg"`.
> Si l'image est absente, l'app affiche les deux premières lettres du nom (fallback).
> Formats acceptés : `.jpg`, `.jpeg`, `.png`, `.webp`

Fichiers toujours nécessaires :
- `kxx_icon.png` — icône de l'app
- `tdg_logo.png` — logo TDG (page Infos)

### 3. Ajouter les audios embarqués (optionnel)

Les audios placés dans `assets/audios/` sont copiés automatiquement dans le
stockage interne au **premier lancement**. Ils sont disponibles hors-ligne sans
téléchargement et ne peuvent pas être supprimés par l'utilisateur.

Structure :
```
assets/audios/
└── <profKey>/          # ex: s_sam_mbaye
    └── <themeKey>/     # ex: ak_talube  (toSlug du nom du thème)
        └── *.ogg
```

Déclarer chaque sous-dossier dans `pubspec.yaml` :
```yaml
flutter:
  assets:
    - assets/audios/s_sam_mbaye/ak_talube/
    - assets/audios/s_sam_mbaye/axiruz_zaman/
    # etc.
```

> ⚠️ Flutter ne supporte pas les wildcards récursifs : déclarer chaque dossier thème.

### 4. Générer les icônes lanceur

```bash
dart run flutter_launcher_icons
```

### 5. Build APK debug

```bash
flutter build apk --debug --target-platform android-arm64
```

### 6. Build APK release (split par architecture — taille réduite)

```bash
flutter build apk --release --split-per-abi
```

APKs dans `build/app/outputs/flutter-apk/`.

---

## ⚙️ Configuration

### Changer le dépôt distant

Tout est centralisé dans `lib/utils/constants.dart` :

```dart
static const String repoOwner  = 'kxxDatas';   // ← votre org/user GitHub
static const String repoName   = 'kxxDatas';   // ← votre dépôt
static const String repoBranch = 'main';
```

### Structure attendue dans le dépôt GitHub

```
kxxDatas/
├── bibliotheque.json
└── audios/                          # même slug que assets/audios/
    ├── s_abdou_rahmane/
    │   ├── kun_katiman/
    │   │   ├── kun_katiman_001.ogg
    │   │   └── ...
    │   └── tazawwudus_sixar/
    │       └── ...
    ├── s_bass_khelcom/
    │   └── histoire_du_prophete_psl/
    │       └── ...
    └── s_sam_mbaye/
        ├── ak_talube/
        └── axiruz_zaman/
```

> Les noms de dossiers sont générés par `toSlug()` appliqué aux noms dans `bibliotheque.json`.

### Ajouter un nouveau professeur

1. Ajouter son entrée dans `bibliotheque.json` (dépôt GitHub).
2. Placer son image dans `assets/images/<toSlug(nom)>.jpg` **et** déclarer dans `pubspec.yaml`.
3. *(Optionnel)* Ajouter son rôle dans `_profRoles` dans `bibliotheque_service.dart` :
   ```dart
   static const Map<String, String> _profRoles = {
     'S Sam Mbaye':     'Conférences',
     'S Bass Khelcom':  'Histoires',
     'S Abdou Rahmane': 'Enseignements',
     'S Saliou Sow':    'Khutbas',   // ← nouveau prof
   };
   ```
   Sans entrée → `"Enseignements"` par défaut.
4. Uploader ses audios dans le dépôt sous `audios/<toSlug(nom)>/<toSlug(theme)>/`.

**Aucune autre modification de code n'est nécessaire.**

### Configurer AdMob en production

Dans `lib/utils/constants.dart` :
```dart
static const String admobAppId           = 'ca-app-pub-XXXXX~XXXXXXXX';
static const String bannerAdUnitId       = 'ca-app-pub-XXXXX/XXXXXXXX';
static const String interstitialAdUnitId = 'ca-app-pub-XXXXX/XXXXXXXX';
```

Dans `android/app/src/main/AndroidManifest.xml` :
```xml
<meta-data
    android:name="com.google.android.gms.ads.APPLICATION_ID"
    android:value="ca-app-pub-XXXXX~XXXXXXXX" />
```

---

## 🎵 Fonctionnement de la bibliothèque hybride

### Synchronisation du catalogue

Au démarrage, l'app tente de récupérer `bibliotheque.json` depuis GitHub :

1. Téléchargement du JSON distant.
2. Comparaison du **hash MD5** avec la version en cache.
3. Si différent → mise à jour du cache local.
4. Si pas de réseau → cache local, puis asset embarqué en fallback absolu.

### Priorité de lecture des audios

| Priorité | Source | URI |
|----------|--------|-----|
| 1 | Fichier téléchargé dans `Documents/audios/` | `file://` |
| 2 | Asset embarqué copié au 1er lancement | `file://` (copie cache) |
| 3 | Streaming GitHub Raw | `https://` |

### Téléchargement

- Bouton ⬇️ sur chaque thème (sidebar + liste)
- Bottom sheet avec progression globale et par piste
- **3 tentatives automatiques** en cas d'erreur réseau
- Annulation possible en cours de route
- Suppression des audios téléchargés (les embarqués sont protégés)
- **Après téléchargement complet** : si le thème était en cours de lecture, la playlist bascule automatiquement vers les fichiers locaux en conservant la position et l'état play/pause.

### Gestion hors-ligne

- Clic sur un **thème** sans aucun audio local et sans connexion → dialog avec bouton "Télécharger"
- Clic sur une **piste** non disponible localement et sans connexion → dialog avec bouton "Télécharger"

### Continuation de lecture

- La position de lecture est sauvegardée automatiquement toutes les 5 secondes.
- Au clic d'un thème déjà partiellement lu → dialog **"Continuer la lecture ?"** avec choix "Reprendre" ou "Depuis le début".
- Écran d'accueil : bloc **"Reprendre la lecture de…"** visible tant que le thème n'est pas terminé.
- Un thème est marqué terminé quand le dernier audio est lu à ≥ 95%.

---

## 📢 Publicité

| Type | Déclencheur |
|------|-------------|
| Bannière | Toujours visible en bas (Home + Infos) |
| Interstitiel | Clic sur un thème (1er clic ou si ≥ 3 min depuis la dernière pub) |

---

## 🔧 Dépendances principales

| Package | Usage |
|---------|-------|
| `just_audio` | Lecteur audio multi-format (ogg, mp3, aac…) |
| `just_audio_background` | Lecture en arrière-plan + notification Android |
| `audio_session` | Gestion session audio, interruptions (appels…) |
| `provider` | State management |
| `dio` | Téléchargements HTTP avec progression + retry |
| `path_provider` | Chemins de stockage |
| `shared_preferences` | Persistance hash, timing pub, position lecture |
| `crypto` | Hash MD5 du JSON catalogue |
| `marquee` | Défilement des titres longs dans le lecteur |
| `google_mobile_ads` | AdMob bannière + interstitiel |
| `permission_handler` | Permissions stockage Android |
| `connectivity_plus` | Détection hors-ligne avant lecture/téléchargement |

---

## 📐 Architecture résumée

```
bibliotheque.json (GitHub)
        │
        ▼
BibliothequeService ──── hash MD5 ──── SharedPreferences
        │
        ▼
  List<Professor>
  (name, key, imagePath, role, themes)
        │
        ▼
   AppProvider  ◄──── ConnectivityService
        │         ◄──── PlaybackPersistenceService
        │         ◄──── DownloadService
        │
        ├──► AudioPlayerService (just_audio)
        │         └── artUri → fichier cache temp (image prof → notification)
        │
        ├──► AdService (interstitiel cooldown 3min)
        │
        └──► UI
              ├── SidebarDrawer (profs/thèmes, dialogs offline/resume)
              ├── AudioTrackList (pistes, dialog offline piste)
              ├── AudioPlayerWidget (slider, vitesse, boucle, volume)
              ├── HomeScreen (WelcomePane + ResumeCard + Copyright)
              └── InfoScreen (À propos, contacts, soutenir)
```

---

## 📄 Licence

© 2026 Taysir Digital Group (TDG) — Tous droits réservés
