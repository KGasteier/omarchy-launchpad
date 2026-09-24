**Deutsch** · [English](README.en.md)

# Radial Mesh Launchpad

App-Launchpad im Omarchy-4-Stil mit **Filter nach Fenstertyp** — als
Overlay-Plugin für die [Omarchy](https://omarchy.org)-Shell. Gebaut für den
Radial-Mesh-Modus von
[hypr-radial-mesh](https://github.com/KGasteier/hypr-radial-mesh). Branch `radialmesh` von
[omarchy-launchpad](https://github.com/KGasteier/omarchy-launchpad).

![6×6-Raster mit Typ-Filterleiste](docs/screenshot.png)

Das Plugin läuft im Shell-Prozess selbst (Quickshell/QML) — kein zusätzliches
Programm, keine Fensterregeln, keine Theme-Templates. Farben, Schrift, Radien
und Rahmen kommen aus den Menü-Tokens des aktiven Themas.

## Eigenschaften

- **Typ-Filterleiste** unter der Suche: Alle · Terminals · TUIs · Agents ·
  GUIs · Webviews · Files. Jeder Knopf zeigt, wie viele Programme er hat;
  Knöpfe ohne Programm blendet das Layout aus
- **Mehrfachbelegung**: Ein Programm kann zu mehreren Typen gehören und
  erscheint in allen — Pi ist Agent *und* TUI, w3m ist TUI *und* Webview,
  Nautilus ist File *und* GUI. Gefärbt wird nach dem Typ, den das Mesh
  zuordnet
- **Alphabetisch** innerhalb jedes Typs, Suche bleibt relevant sortiert
- **Typfarbe im Icon-Hintergrund**: Jede Kachel liegt auf einer klar
  erkennbaren, getönten Fläche in ihrer Typfarbe — ohne abgesetzte Linie,
  unter dem Cursor etwas kräftiger
- **Zeile „zuletzt benutzt"** zwischen Suche und Filterleiste, dezent
  hinterlegt, feine Linie darunter; sie scrollt nicht mit und startet
  das Programm direkt per Klick
- **6 × 6 Raster**, scrollt bei mehr Programmen; **Punkte am unteren Rand**,
  solange darunter weitere liegen
- **Suche** wie im Omarchy-Menü, mit Nerd-Font-Lupe; im Suchfeld steht
  „Suchen in TUIs…", wenn ein Typ gewählt ist
- **Stufenweises Esc**: erst Suchtext, dann Typwahl, dann schließen
- **Tab / Shift+Tab** springt zum nächsten / vorherigen Typ
- **Monogramm-Kacheln** für Programme ohne Icon (`Monogram.js`)
- **Themenabhängig** ohne eigene Konfiguration

## Installation

```bash
git clone -b radialmesh https://github.com/KGasteier/omarchy-launchpad.git radialmesh-launchpad
cd radialmesh-launchpad
./install.sh
```

Danach öffnet `SUPER + R` das Raster. Die Shell wird beim Installieren
einmal neu gestartet (`omarchy restart shell`), das dauert wenige Sekunden –
bei gesperrtem Bildschirm nicht (das ließe die Sperre verwaist zurück); dann
nach dem Entsperren `omarchy restart shell` ausführen. Ist `SUPER + R` schon
anders belegt, warnt das Skript.

Mitinstalliert wird es auch von
[hypr-radial-mesh](https://github.com/udk-gwk/hypr-radial-mesh).

**Tausch gegen `omarchy-launchpad`**: zuerst dort `./install.sh --uninstall`
ausführen, dann dieses hier installieren. Beide auf `SUPER + R` darf Hyprland
nicht haben. Die rofi-basierte Fassung bleibt davon unberührt.

Neben dem Original installiert werden kann es trotzdem — dann aber die
Bindung in `~/.config/hypr/radialmesh-launchpad.lua` ändern (z. B. auf
`SUPER + SHIFT + R`), eigene Plugin-ID und eigener MRU-Stand vorausgesetzt.

Entfernen:

```bash
./install.sh --uninstall
```

Das nimmt nur die eigenen Artefakte heraus (Plugin-Ordner, Bindungs-Datei,
der `require`-Block in `hyprland.lua` in Markierungen, `shell.json`-Eintrag,
MRU-Stand). Vor jedem Eingriff in `hyprland.lua` wird eine Sicherung
`hyprland.lua.bak.rmlaunchpad.<zeit>` angelegt; die fünf jüngsten bleiben.

## Was wo landet

| Pfad | Zweck |
|---|---|
| `~/.config/omarchy/plugins/community.radialmesh-launchpad/` | das Plugin (Kopie von `plugin/`) |
| `~/.config/hypr/radialmesh-launchpad.lua` | Tastenbindung |
| `~/.config/hypr/hyprland.lua` | ein Block `require("hypr.radialmesh-launchpad")` zwischen Markierungen |
| `~/.config/omarchy/shell.json` | Eintrag unter `plugins` (Shell-verwaltet) |
| `~/.local/state/radialmesh-launchpad/recent.json` | zuletzt gestartete Apps (beim ersten Start aus der MRU des Originals übernommen) |

## Typen

Ein Programm wird aus den Desktop-Datei-Feldern eingeteilt: `Exec`
(Terminal-Starter, `--app-id=TUI.agent`, `omarchy-launch-webapp`),
`Terminal=true` und `Categories`. Die Typen und ihre Farben sind identisch
mit `M.config.colors` in `hypr-radial-mesh` — ein Programm trägt im Launchpad
dieselbe Farbe wie später seine Karte im Mesh.

| Typ | Farbe | erkannt über |
|---|---|---|
| Terminals | Türkis | Kategorie `TerminalEmulator` |
| TUIs | Grün | `Terminal=true`, `xdg-terminal-exec`, `ConsoleOnly` |
| Agents | Magenta | `--app-id=TUI.agent`, `org.omarchy.agent` (auch TUI) |
| Webviews | Orange | Kategorie `WebBrowser`, `omarchy-launch-webapp` |
| Files | Sand | Kategorie `FileManager` / `FileSystem` |
| GUIs | Rosé | alles mit eigenem Fenster, das nicht Terminal/TUI/Webview ist |

Editoren, Viewer und Systemkacheln behalten ihren eigenen Farbtyp (Blau,
Violett, Grau), sind aber über die Knöpfe oben erreichbar — sie sind zugleich
GUI. Zuordnung von Hand in `plugin/Types.js` (`OVERRIDES`, Schlüssel ist die
Desktop-ID).

## Aufruf und Anpassen

Von Hand oder aus Skripten, auch mit vor gewähltem Typ:

```bash
omarchy-shell shell toggle community.radialmesh-launchpad
omarchy-shell shell toggle community.radialmesh-launchpad '{"type":"tui"}'
omarchy-shell shell toggle community.radialmesh-launchpad '{"type":"ai"}'
```

Möglich sind alle Mesh-Kategorien: `terminal`, `tui`, `ai`, `gui`, `webview`,
`files`, `editor`, `viewer`, `config`. Die letzten drei haben normalerweise
keinen eigenen Knopf. Werden sie so vorgewählt, erscheint ihr Knopf
zusätzlich am Ende der Leiste, bis das Launchpad geschlossen wird. Ein
unbekannter Typ öffnet „Alle".

Der Companion `radialmesh-companion` von
[hypr-radial-mesh](https://github.com/udk-gwk/hypr-radial-mesh) öffnet das
Launchpad bei Klick auf das „+" einer Leerzelle, gefiltert auf die Kategorie
der Nachbarkarte (ab hypr-radial-mesh 0.26.1 für alle Kategorien).

### Größe und Raster

Vorgabe ist ein Raster aus 6 × 6 Programmen, gut 60 % der Bildschirmbreite.
Einstellen lässt es sich im eigenen Plugin-Eintrag in
`~/.config/omarchy/shell.json`, z. B. für kleinere Bildschirme:

```json
"plugins": [
  { "id": "community.radialmesh-launchpad", "columns": 5, "rows": 5, "iconSize": 30, "width": 0.42 }
]
```

| Schlüssel | Vorgabe | Bereich | Bedeutung |
|---|---|---|---|
| `columns` | 6 | 3–10 | Spalten (auch Länge der MRU-Zeile) |
| `rows` | 6 | 2–10 | sichtbare Zeilen, weitere per Scrollen |
| `iconSize` | 38 | 20–96 | Icongröße in logischen Pixeln; Zeilenhöhe und Typfläche folgen |
| `width` | 0.615 | 0.3–1 | Kartenbreite als Anteil der Bildschirmbreite |

Die Shell beobachtet `shell.json`; die neuen Werte gelten beim nächsten
Öffnen, ohne Neustart.

**Kleine Auflösungen passen sich von selbst an:** Die Karte erscheint auf
dem Monitor mit dem Fokus und bleibt immer ganz auf dem Bildschirm. Reicht
die Höhe nicht, zeigt sie weniger Zeilen (nie eine angeschnittene), reicht
die Breite nicht, weniger Spalten. Passen die Typknöpfe nicht in eine Zeile,
entfallen Zähler und Farbpunkte, die Knöpfe bleiben farbig getönt. Ein
Bildschirm mit 900 × 565 logischen Pixeln zeigt so noch 6 × 2.

Die Tastenkombination steht in `~/.config/hypr/radialmesh-launchpad.lua`.
`./install.sh --no-bind` installiert ohne Tastenbelegung.

## Bekannte Eigenheiten

- **Hot Reload greift bei diesem Overlay nicht.** Die Shell erkennt
  Änderungen im Launchpad-Ordner (inotify), die geladene
  Overlay-Instanz bleibt aber bestehen. Nach Änderungen:
  `omarchy restart shell`.
- **Kein Symlink statt Kopie** im Launchpad-Ordner wird von der Überwachung
  nicht gesehen — `install.sh` kopiert deshalb.
- Die Lupe im Suchfeld ist eine Nerd-Font-Glyphe (`U+F002`); ohne
  Nerd-Schrift erscheint ein Ersatzkästchen (`ttf-jetbrains-mono-nerd`
  hilft).
- Die Suche zeigt nur die Treffer, keine MRU-Zeile — wie im Original.
- Editoren, Viewer und System haben **keine eigenen Knöpfe** (sie wären mit
  `GUIs` doppelt); ihre Farbe unterscheidet sie trotzdem.

## Lizenz

MIT, siehe [LICENSE](LICENSE).
