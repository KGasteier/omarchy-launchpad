**Deutsch** · [English](README.en.md)

# Radial Mesh Launchpad

App-Launchpad im Omarchy-4-Stil mit **Filter nach Fenstertyp** — als
Overlay-Plugin für die [Omarchy](https://omarchy.org)-Shell. Gebaut für den
Radial-Mesh-Modus von
[hypr-radial-mesh](https://github.com/KGasteier/hypr-radial-mesh), Fork von
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
- **Typfarbe im Icon-Hintergrund**: Jede Kachel liegt auf einer dezent
  getönten Fläche in ihrer Typfarbe — auch in der MRU-Zeile
- **Zeile „zuletzt benutzt"** ganz oben, dezent hinterlegt, feine Linie
  darunter; Lücken bleiben leer, die Liste beginnt immer in Zeile 2
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
git clone https://github.com/KGasteier/radialmesh-launchpad.git
cd radialmesh-launchpad
./install.sh
```

Danach öffnet `SUPER + SHIFT + R` das Raster. Die Shell wird beim
Installieren einmal neu gestartet (`omarchy restart shell`), das dauert
wenige Sekunden.

Die rofi-basierte Fassung und `omarchy-launchpad` (Taste `SUPER + R`) können
gleichzeitig installiert bleiben — eigene Plugin-ID, eigene Bindung, eigener
MRU-Stand.

Entfernen:

```bash
./install.sh --uninstall
```

Das nimmt nur die eigenen Artefakte heraus (Plugin-Ordner, Bindungs-Datei,
der `require`-Block in `hyprland.lua` in Markierungen, `shell.json`-Eintrag,
MRU-Stand). Vor jedem Eingriff in `hyprland.lua` wird eine Sicherung
`hyprland.lua.bak.rmlaunchpad.<zeit>` angelegt.

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

`gui`, `tui`, `terminal`, `webview`, `files` sind möglich. Der Companion
`radialmesh-companion` ruft das Launchpad mit dem Typ der Nachbarskarte auf,
wenn eine leere Zelle angeklickt wird.

Tastenkombination in `~/.config/hypr/radialmesh-launchpad.lua`; Spalten- und
Zeilenzahl, Icon-Größe und Kartenbreite stehen als Properties am Anfang von
`Launchpad.qml` (`columns`, `visibleRows`, `iconSize`, `cardWidth`). Die
Kartenhöhe folgt aus `visibleRows * cellHeight + indicatorHeight` — wer die
Zeilenzahl ändert, passt `cellHeight` gegenläufig an, wenn die Karte gleich
groß bleiben soll. Änderungen im Launchpad-Ordner greifen bei Overlays erst
nach `omarchy restart shell`.

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
