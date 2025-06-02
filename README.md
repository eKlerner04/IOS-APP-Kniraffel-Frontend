
# 🦒 Kniraffel – README

🎲 **Kniraffel** ist ein Multiplayer-Würfelspiel mit modernen Features, coolem UI und Firebase-Integration. Es bietet Standard- und erweiterten Modus, Münzsystem, Highscores und Rematch-Funktionalität.

---
**Im App Store verfügbar!**  
[Hier klicken, um die App herunterzuladen](https://apps.apple.com/de/app/kniraffel/id6746126607?l=en-GB)

---

##  Features

- Apple Login mit Firestore-Integration  
- Benutzerprofil mit Statistiken, Score-Historie und Diagrammen  
- Lobby-System: Host kann Spielmodus („Standard“ / „Erweitert“) und Einsatz (Münzen) festlegen  
- Echtzeit-Chat im Spiel  
- Münz-Belohnungen und Einsätze, automatische Verteilung
- Shop mit Skins für Würfel, die man mit erspielten Ingame-Münzen kaufen kann
- Würfelsounds, Button-Sounds, Hintergrundmusik (abschaltbar)  
- Rematch-Funktion nach Spielende  
- Highscore-Listen (global & benutzerspezifisch)  
- Skins für Würfel (Shop-Support vorbereitet)  
- Version-Check für verpflichtende App-Updates

---

## Installation

1. **Voraussetzungen:**
   - Xcode (min. 14)
   - Firebase-Projekt eingerichtet (GoogleService-Info.plist)
   - Swift Packages: Charts, FirebaseAuth, FirebaseFirestore

2. **Setup:**
   - Clonen oder runterladen
   - GoogleService-Info.plist ins Projekt einfügen
   - Sounddateien (z. B. `button_click.mp3`, `dice_rolling.mp3`) in den Bundle-Ressourcen bereitstellen
   - Projekt in Xcode öffnen und auf ein echtes Gerät oder Simulator deployen

---

## Projektstruktur

| Datei                      | Funktion                                             |
|----------------------------|------------------------------------------------------|
| `ContentView.swift`         | Start- und Hauptmenü, Highscores, Navigation         |
| `LobbyView.swift`           | Lobby-Management, Spieleranzeige, Startlogik         |
| `GameView.swift`           | Hauptspiellogik mit Würfeln, Punkten, Chat, Rematch  |
| `ScoreboardView.swift`      | Spielstandstabelle mit Zugriff auf Detailansicht     |
| `ProfileView.swift`         | Spielerprofil mit Statistiken und Diagrammen         |
| `FirestoreManager.swift`    | Alle Firebase-Kommunikationen (Spiele, Coins, User) |
| `SoundEffectManager.swift`  | Soundeffekte steuern (Würfeln, Buttons)             |
| `SettingsView.swift`        | App-Einstellungen (Sound, Logout)                   |
| `UsernameSetupView.swift`   | Username-Eingabe nach Login                         |
| `LoginView.swift`           | Sign In with Apple                                 |
| `KnubbelGameApp.swift`      | App-EntryPoint mit Firebase-Setup                   |

---

##  Spielmodi

- **Standard**:
  - 5 Würfel, klassische Regeln
  - Bonus ab 63 Punkten im oberen Block

- **Erweitert**:
  - 6 Würfel, neue Kategorien wie „1 Paar“, „2 Paare“, „Zwei Drillinge“
  - Bonus ab 108 Punkten im oberen Block
  - „Kniraffel“ nur bei sechs gleichen Würfeln gültig

---

##  Münzsystem & Shop

- Spieler sammeln Münzen durch Siege & hohe Scores
- Host kann Einsatz pro Spieler setzen (Coins werden automatisch abgezogen und an den Gewinner ausgeschüttet)
- Mit erspielten Münzen können im Shop neue Würfelskins gekauft werden
- Highscores und Ranglisten zeigen Punkte (nicht Coins)


---

## Statistik & Highscores

- Globale Top-5-Ranglisten (Standard / Erweitert)
- Pro-User-Toplisten (Ø Punkte pro Spiel)
- Detaillierte Punkteverläufe im Profil mit Diagrammen

---

## Wichtige technische Details

- Echtzeit-Updates über Firestore Snapshots
- Soundsteuerung über `UserDefaults` (z. B. Hintergrundmusik)
- Rematch-Mechanik setzt Firestore-Daten gezielt zurück
- Versions-Check prüft verpflichtende App-Updates via Firestore
- Shop-Integration vorbereitet (Skins, Käufe)

---

##  ToDo / Ideen für die Zukunft

- In-App Purchases für Münzen oder Skins
- Push Notifications für Freundeseinladungen
- Mehr Würfelskins und personalisierte Spielfelder
- Tägliche Challenges mit Münzbelohnungen
- Web- oder Desktop-Version

