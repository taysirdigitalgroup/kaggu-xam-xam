# Rapport Technique — Kaggu Xam Xam

**Application Mobile Android — Plateforme d'enseignements islamiques**

| Champ | Valeur |
|---|---|
| Développeur | Aliou Mbengue — PDG, Taysir Digital Group (TDG) |
| Version | 1.0.0 (build 1) |
| Plateforme | Android 7.0+ (API 24+) · Flutter 3 · Dart SDK ≥ 3.2.0 |
| Framework | Flutter / Dart · Gradle / Kotlin · NDK r26d |
| Dépôt audio | GitHub Raw — TaysirDigitalGroup/kaggu-xam-xam-data |
| Date rapport | Juin 2025 |
| Contact | taysirdigitalgroup@gmail.com · +221 76 455 03 58 |

---

## 1. Présentation générale

### 1.1 Contexte et objectif

Kaggu Xam Xam (en wolof : « acquiers la connaissance ») est une application mobile Android conçue et développée par Taysir Digital Group (TDG). Elle centralise des enregistrements audio d'enseignements islamiques dispensés par des professeurs reconnus, et les rend accessibles en toutes circonstances — en ligne comme hors-ligne.

### 1.2 Modèle hybride de distribution audio

L'application adopte un modèle à trois niveaux de disponibilité des contenus, appliqués par ordre de priorité lors de la lecture :

| Priorité | Source | Description |
|:---:|---|---|
| 1 | Stockage local | Fichiers téléchargés dans `getApplicationDocumentsDirectory()`. Disponibilité totale hors-ligne, latence nulle. |
| 2 | Assets embarqués | Audios fournis dans le bundle APK (`assets/audios/`). Disponibles dès l'installation, sans réseau. |
| 3 | Streaming distant | Lecture directe depuis le dépôt GitHub raw. Nécessite une connexion internet. |

### 1.3 Catalogue (bibliotheque.json)

La bibliothèque est décrite par un fichier JSON versionné sur le dépôt distant et embarqué dans le bundle. Au lancement, l'application tente de le synchroniser automatiquement.

| Professeur | Thème | Audios |
|---|---|:---:|
| S Abou Rahmane | Kun Katiman | 2 |
| | Tazawwudus Sixar | 41 |
| S Bass Khelcom | Histoire Du Prophete Psl | 20 |
| S Sam Mbaye | Ak Talube | 3 |
| | Axiruz Zaman | 3 |
| **Total** | **5 thèmes / 3 professeurs** | **69** |

---

## 2. Architecture technique

### 2.1 Stack technologique

| Composant | Technologie / Version |
|---|---|
| Langage | Dart ≥ 3.2.0 |
| Framework UI | Flutter 3 · Material Design 3 |
| État applicatif | Provider 6.1.1 (ChangeNotifier) |
| Lecture audio | just_audio 0.9.36 + just_audio_background 0.0.1-beta.11 + audio_session 0.1.18 |
| Téléchargement | Dio 5.4.1 (HTTP client, progress, cancel token) |
| Persistance | path_provider 2.1.2 + shared_preferences 2.2.2 |
| Intégrité JSON | crypto 3.0.3 (hash MD5 du catalogue) |
| Permissions | permission_handler 11.3.0 |
| Publicité | google_mobile_ads 5.1.0 (bannière + interstitiel) |
| UI complémentaire | marquee 2.3.0 + cached_network_image 3.3.1 |
| Android SDK | minSdk 24 (Android 7.0) · targetSdk 34 · NDK r26d |
| Build tooling | Gradle · Kotlin · Proguard (minify + shrink release) |

### 2.2 Structure des fichiers sources

```
lib/
├── main.dart                    # Point d'entrée, orientation portrait, just_audio_background init
├── providers/
│   └── app_provider.dart        # ChangeNotifier central (état, téléchargements, lecteur)
├── models/
│   └── models.dart              # AudioTrack, AudioTheme, Professor
├── services/
│   ├── bibliotheque_service.dart  # Sync JSON distant / cache local / asset embarqué
│   ├── download_service.dart      # Téléchargement, refresh (delete-diff), URI de lecture
│   ├── audio_service.dart         # Lecteur just_audio (playlist, seek, vitesse…)
│   └── ad_service.dart            # AdMob (bannière + interstitiel cooldown 3 min)
├── screens/
│   ├── home_screen.dart           # Écran principal (drawer + liste + lecteur)
│   └── info_screen.dart           # À propos, contacts, donations
├── widgets/
│   ├── sidebar_drawer.dart        # Drawer professeurs/thèmes + boutons Download/Refresh
│   ├── audio_player_widget.dart   # Lecteur complet (progress, contrôles, vitesse, boucle)
│   ├── audio_track_list.dart      # Liste des pistes avec statut local/cloud
│   ├── download_sheet.dart        # Sheets Download et Refresh (delete-diff)
│   └── banner_ad_widget.dart      # Bannière AdMob stateful
└── utils/
    ├── constants.dart             # URLs, clés prefs, couleurs, infos app
    ├── app_theme.dart             # Thème Material 3 (navy/gold)
    └── string_utils.dart          # formatAudioTitle, formatDuration, toSlug
```

### 2.3 Modèles de données

#### AudioTrack

Représente un fichier audio individuel avec ses deux flags de disponibilité offline.

| Propriété | Type | Description |
|---|---|---|
| `filename` | String | Nom de fichier exact (ex : `kun_katiman_001.ogg`) |
| `profKey` | String | Slug du professeur (ex : `s_abou_rahmane`) |
| `themeKey` | String | Slug du thème (ex : `kun_katiman`) |
| `isDownloaded` | bool | Fichier présent dans le stockage local (documents) |
| `isBundled` | bool | Fichier présent dans les assets embarqués du bundle |
| `downloadProgress` | double | Progression du téléchargement en cours (0.0 → 1.0) |

#### AudioTheme

Agrège une liste de pistes et expose des propriétés calculées :

- `isFullyDownloaded` — tous les tracks sont en local
- `isFullyAvailableOffline` — tous les tracks sont disponibles (local OU bundled)
- `hasLocalDownloads` — au moins un track est téléchargé en local
- `isBundledOnly` — tous bundled, aucun local
- `bundledCount` / `downloadedCount` / `availableOfflineCount`

#### Professor

Regroupe le nom, la clé (slug), le chemin image local et la liste des thèmes.

---

## 3. Gestion des audios

### 3.1 Structure des répertoires

Les trois sources partagent la même arborescence `prof/thème/fichier`. Seule la racine diffère :

| Source | Racine |
|---|---|
| Assets embarqués | `assets/audios/<prof_key>/<theme_key>/<fichier>.ogg` |
| Dépôt distant | `https://…/kaggu-xam-xam-data/main/audio/<prof_key>/<theme_key>/<fichier>.ogg` |
| Stockage local | `getApplicationDocumentsDirectory()/audio/<prof_key>/<theme_key>/<fichier>.ogg` |

Structure complète des assets embarqués :

```
assets/audios/
  s_abou_rahmane/
    kun_katiman/            ← 2 fichiers embarqués
    tazawwudus_sixar/       ← 41 fichiers embarqués
  s_bass_khelcom/
    histoire_du_prophete_psl/  ← 20 fichiers embarqués
  s_sam_mbaye/
    ak_talube/              ← 3 fichiers embarqués
    axiruz_zaman/           ← 3 fichiers embarqués
```

### 3.2 Normalisation des noms (slug)

La fonction `toSlug()` de `string_utils.dart` génère les clés de répertoires depuis les noms du JSON. Elle remplace les accents et les caractères non alphanumériques par des underscores.

```
toSlug("S Abou Rahmane")           → "s_abou_rahmane"
toSlug("S Bass Khelcom")            → "s_bass_khelcom"
toSlug("S Sam Mbaye")              → "s_sam_mbaye"
toSlug("Kun Katiman")              → "kun_katiman"
toSlug("Tazawwudus Sixar")         → "tazawwudus_sixar"
toSlug("Histoire Du Prophete Psl") → "histoire_du_prophete_psl"
toSlug("Ak Talube")                → "ak_talube"
toSlug("Axiruz Zaman")             → "axiruz_zaman"
```

Le script externe de génération du catalogue garantit la cohérence entre les noms JSON, les dossiers du dépôt et les dossiers des assets.

### 3.3 Résolution d'URI de lecture (getPlayableUri)

Avant de charger une piste dans le lecteur, `download_service.dart` applique la règle de priorité suivante :

1. **Local** — `File(localPath).existsSync()` → URI `file://…`
2. **Bundle** — `rootBundle.load(assetPath)` → URI `asset:///…`
3. **Streaming** — URL GitHub raw → URI `https://…`

Cette logique garantit qu'un appareil sans connexion peut toujours lire les audios embarqués ou précédemment téléchargés.

### 3.4 Téléchargement initial (downloadTheme)

Déclenché via le bouton ⬇ (doré) dans la sidebar ou l'en-tête de la liste de pistes.

- Seuls les tracks absents en local sont téléchargés (bundled ou déjà locaux sont ignorés)
- Dio gère la progression octets reçus / taille totale, remontée via `onTrackProgress`
- Un `CancelToken` permet l'annulation à tout moment
- Un `DownloadState` par thème est exposé dans `AppProvider` pour l'UI

### 3.5 Rafraîchissement — règle delete-diff (refreshTheme)

Déclenché via le bouton 🔄 (vert), affiché uniquement sur les thèmes qui ont déjà des audios locaux. Opère en 3 étapes :

1. **Inventaire local** — liste des fichiers `.ogg` présents dans le dossier thème local
2. **Suppression diff** — les fichiers locaux absents de la liste JSON distante sont supprimés (obsolètes ou renommés)
3. **Téléchargement des manquants** — les fichiers du JSON non présents en local sont téléchargés

Les fichiers déjà présents et toujours référencés ne sont pas re-téléchargés.

---

## 4. Synchronisation du catalogue

### 4.1 Stratégie de chargement

Au démarrage, `BibliothequeService.loadBibliotheque()` suit cet ordre :

| Étape | Action | Condition |
|:---:|---|---|
| 1 | Requête GET du JSON distant (timeout 10 s) | Toujours tentée en premier |
| 2 | Comparaison hash MD5 distant vs cache | Si réponse valide reçue |
| 3 | Sauvegarde en cache local + mise à jour hash | Si hash différent (nouveau catalogue) |
| 4 | Utilisation du cache local (documents) | Si erreur réseau ou même hash |
| 5 | Fallback sur l'asset embarqué | Si aucun cache local disponible |

### 4.2 Persistance du hash

Le hash MD5 du dernier catalogue synchronisé est stocké dans `SharedPreferences` (clé `biblio_hash`). Cela évite de ré-écrire le fichier local à chaque lancement quand le catalogue n'a pas changé.

### 4.3 Affichage de tous les thèmes

Grâce à la synchronisation du catalogue, l'app affiche la liste complète des thèmes même si leurs audios n'ont pas encore été téléchargés. Chaque thème indique visuellement son état (bundled, local, distant) via les badges et boutons d'action.

---

## 5. Lecteur audio

### 5.1 Fonctionnalités

| Fonctionnalité | Détail |
|---|---|
| Playlist continue | `ConcatenatingAudioSource` — navigation auto entre les pistes d'un thème |
| Barre de progression | Slider cliquable, mise à jour temps réel via `positionStream` |
| Navigation | ⏮ Piste précédente · ⏪ -10s / +10s ⏩ · Piste suivante ⏭ |
| Vitesse de lecture | 0.5× 0.75× 1× 1.25× 1.5× 2× — sélection via bottom sheet |
| Mode boucle | `LoopMode.one` (piste en cours) ou `LoopMode.off` |
| Volume | Slider inline dans le lecteur |
| Titre défilant | Marquee automatique si le titre dépasse 35 caractères |
| Notification système | Contrôles play/pause/skip dans la barre de notifications Android |
| Lecture arrière-plan | `ForegroundService` Android de type `mediaPlayback` |
| Sources multi-format | `file://` (local) · `asset:///` (bundle) · `https://` (streaming) |

### 5.2 Service audio (AudioPlayerService)

`AudioPlayerService` encapsule l'instance `just_audio` et expose :

- `loadTheme(theme, startIndex)` — construit la `ConcatenatingAudioSource` après résolution des URIs
- `play()`, `pause()`, `stop()`, `seekTo()`, `seekToIndex()`
- `skipForward()` / `skipBackward()` — sauts de ±10 secondes
- `skipToNext()` / `skipToPrevious()` — avec règle retour début de piste si position > 3 s
- `setSpeed()`, `setLoopMode()`, `setVolume()`
- Streams exposés : `playerStateStream`, `positionStream`, `durationStream`, `sequenceStateStream`

---

## 6. Interface utilisateur

### 6.1 Charte graphique

| Élément | Valeur | Usage |
|---|---|---|
| Bleu marine (Navy) | `#0D2B5E` | Fonds, AppBar, drawer |
| Or principal (Gold) | `#C8982A` | Bouton play, accents |
| Or clair (Gold Light) | `#F0C84A` | Textes secondaires |
| Fond page | `#F4F6FA` | Scaffold background |
| Police | Arial / Material 3 | Tout le texte |
| Orientation | Portrait uniquement | Verrouillé au démarrage |

### 6.2 Écrans et composants

#### Splash Screen

Affiché pendant `AppState.loading`. Présente le logo, le nom et un indicateur de chargement. En cas d'erreur, une `ErrorScreen` propose un bouton « Réessayer ».

#### HomeScreen

- `AppBar` avec logo, titre et sous-titre (thème en cours)
- `SidebarDrawer` (ouvert via menu hamburger)
- Zone centrale : `WelcomePane` (aucun thème sélectionné) ou `AudioTrackList`
- `AudioPlayerWidget` (lecteur complet, persistant en bas d'écran)
- `BannerAdWidget` (bannière AdMob 50 px)

#### SidebarDrawer

Drawer de largeur 300 px listant professeurs et thèmes. Chaque thème porte un bouton d'action contextuel :

| État du thème | Bouton affiché | Action |
|---|---|---|
| Téléchargement en cours | Spinner circulaire | — |
| Audios locaux présents | 🔄 Sync (vert) | `showRefreshSheet()` |
| Aucun audio local | ⬇ Download (doré) | `showDownloadSheet()` |

#### AudioTrackList

Liste des pistes avec numéro, titre formaté, indicateur de piste en cours (play/pause live), et icône d'état (`offline_pin` si local, `cloud` si distant).

#### Sheets de gestion audio

Deux bottom sheets distincts :

- **Download Sheet** — stats (total / locales / bundled), barre de progression, boutons Télécharger / Annuler / Supprimer
- **Refresh Sheet** — explication de la règle delete-diff, boutons Synchroniser / Supprimer les audios locaux

#### InfoScreen

À propos de l'app, informations développeur, contacts (appel, email, site web) et moyens de soutien financier (PayPal, Wave, Orange Money — avec copie du numéro dans le presse-papiers).

---

## 7. Publicité — Google AdMob

### 7.1 Formats intégrés

| Format | Emplacement | Comportement |
|---|---|---|
| Bannière (320×50) | Bas de HomeScreen et InfoScreen | Permanente, chargée au mount du widget |
| Interstitiel | Transition lors de la sélection d'un thème | Cooldown de 3 minutes entre deux affichages |

### 7.2 Logique de cooldown interstitiel

Le timestamp du dernier affichage est stocké dans `SharedPreferences` (clé `last_interstitial_time`). À chaque changement de thème, `AdService` vérifie que 180 secondes se sont écoulées avant d'afficher un nouvel interstitiel.

L'interstitiel suivant est préchargé immédiatement après fermeture de l'annonce précédente, garantissant une disponibilité continue.

---

## 8. Permissions Android

| Permission | Motif |
|---|---|
| `INTERNET` | Streaming audio, téléchargements, AdMob, sync catalogue |
| `ACCESS_NETWORK_STATE` | Détection de la connectivité |
| `READ_EXTERNAL_STORAGE` (≤ API 32) | Lecture fichiers audio sur Android 12 et antérieur |
| `WRITE_EXTERNAL_STORAGE` (≤ API 29) | Écriture sur Android 9 et antérieur |
| `FOREGROUND_SERVICE` | Service audio en arrière-plan |
| `FOREGROUND_SERVICE_MEDIA_PLAYBACK` | Type explicite du foreground service (Android 13+) |
| `WAKE_LOCK` | Maintien du service audio actif pendant la lecture |
| `RECEIVE_BOOT_COMPLETED` | Redémarrage du service après reboot appareil |

---

## 9. Dépôt de données distant

### 9.1 Structure du dépôt GitHub

```
kaggu-xam-xam-data/
├── bibliotheque.json               # Catalogue JSON (source de vérité)
└── audio/
    ├── s_abou_rahmane/
    │   ├── kun_katiman/
    │   │   ├── kun_katiman_001.ogg
    │   │   └── kun_katiman_002.ogg
    │   └── tazawwudus_sixar/
    │       ├── tazawudus_sixar_001.ogg
    │       └── … (41 fichiers)
    ├── s_bass_khelcom/
    │   └── histoire_du_prophete_psl/
    │       └── … (20 fichiers)
    └── s_sam_mbaye/
        ├── ak_talube/
        │   └── … (3 fichiers)
        └── axiruz_zaman/
            └── … (3 fichiers)
```

### 9.2 Procédure d'ajout d'un nouveau thème

1. Créer `audio/<prof_key>/<theme_key>/` dans le dépôt et y déposer les fichiers `.ogg`
2. Mettre à jour `bibliotheque.json` avec le nouveau professeur/thème et la liste des fichiers
3. Committer et pousser sur la branche `main`
4. Dans `pubspec.yaml`, ajouter `assets/audios/<prof_key>/<theme_key>/` si des audios sont embarqués
5. Relancer `flutter pub get` et recompiler l'APK

Les utilisateurs bénéficient du nouveau thème dès le prochain lancement (sync automatique du catalogue). Les audios sont lus en streaming jusqu'au téléchargement.

---

## 10. État applicatif — AppProvider

`AppProvider` (ChangeNotifier) est l'unique source de vérité de l'application.

| Propriété / Méthode | Rôle |
|---|---|
| `state` (AppState) | Cycle de vie : `loading` → `ready` ou `error` |
| `professors` | Liste chargée depuis `BibliothequeService` |
| `selectedProfessor` / `selectedTheme` | Sélection courante, détermine ce que joue le lecteur |
| `currentTrackIndex` | Index de la piste active dans la playlist |
| `downloadStates` (Map) | `DownloadState` par thème (progression, `isRefreshing`, `cancelToken`) |
| `expandedProfs` (Set) | Professeurs dépliés dans le drawer |
| `playbackSpeed` / `isLooping` / `volume` | Paramètres du lecteur audio persistés en session |
| `init()` | Initialise AdMob, AudioSession, charge et vérifie tous les tracks |
| `selectTheme()` | Sélectionne un thème, affiche un interstitiel si éligible, charge la playlist |
| `downloadTheme()` | Lance le téléchargement initial des tracks manquants |
| `refreshTheme()` | Lance la synchronisation delete-diff du thème |
| `cancelDownload()` | Annule via `CancelToken` et nettoie le `DownloadState` |
| `deleteTheme()` | Supprime le répertoire local du thème |

---

## 11. Sécurité et optimisations build

### 11.1 Build release

| Option | Valeur |
|---|---|
| `minifyEnabled` | `true` — obfuscation et compression du bytecode |
| `shrinkResources` | `true` — suppression des ressources Android non référencées |
| ProGuard | `proguard-android-optimize.txt` + `proguard-rules.pro` |
| MultiDex | `true` — support des apps avec > 65 536 méthodes |
| `applicationIdSuffix` debug | `.debug` — distingue build debug et release sur l'appareil |

### 11.2 Icône adaptative

`flutter_launcher_icons` génère l'icône adaptative Android (fond navy `#0D2B5E`, avant-plan `kxx_icon.png`) pour API 26+, pour toutes les densités (mdpi → xxxhdpi).

### 11.3 Connexions réseau

Le flag `android:usesCleartextTraffic="true"` autorise les connexions HTTP non chiffrées. Il peut être retiré en production puisque toutes les URLs du dépôt utilisent déjà HTTPS (GitHub raw).

---

## 12. Points d'attention et évolutions

### 12.1 Points d'attention actuels

| N° | Sujet | Description |
|:---:|---|---|
| 1 | Signature release | `signingConfig signingConfigs.debug` encore utilisé. Configurer un keystore de production avant publication. |
| 2 | url_launcher manquant | `InfoScreen` appelle `_launch()` pour ouvrir URLs (téléphone, email, PayPal, Wave) mais `url_launcher` n'est pas dans `pubspec.yaml`. À ajouter. |
| 3 | cleartext traffic | `usesCleartextTraffic=true` peut être retiré si toutes les URLs sont en HTTPS (cas actuel). |
| 4 | pubspec à maintenir | Chaque nouveau thème embarqué nécessite l'ajout manuel dans `pubspec.yaml`. À automatiser si le catalogue grandit. |
| 5 | IDs AdMob de test | Les IDs actuels sont les IDs de test Google. À remplacer par les vrais IDs avant publication sur le Play Store. |

### 12.2 Évolutions envisageables

- Ajout de `url_launcher` pour les liens de contact et donation
- Support iOS (pubspec et assets déjà compatibles Flutter multiplateforme)
- Favoris : marquer des pistes en favori (persistance `SharedPreferences`)
- Recherche : barre de recherche dans le drawer pour filtrer thèmes et professeurs
- Mode nuit : thème sombre (navy profond + or atténué), facilement réalisable avec Material 3
- Statistiques d'écoute : nombre d'écoutes par piste, durée totale
- Notifications push : informer l'utilisateur des nouvelles mises à jour du catalogue
- Script d'automatisation `pubspec` : génération automatique de la liste des assets depuis `assets/audios/`

---

*© 2025 Taysir Digital Group (TDG) — Aliou Mbengue, PDG*
*« Vos rêves, nos défis »*
