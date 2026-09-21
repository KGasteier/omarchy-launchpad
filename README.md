**Deutsch** · [English](README.en.md)

# Omarchy Launchpad

Ein größeres App-Launchpad im Omarchy-4-Stil als Overlay-Plugin für die
[Omarchy](https://omarchy.org)-Shell (Omarchy 4.0 oder neuer).

![Raster 6×6](docs/screenshot.png)

Das Plugin läuft im Shell-Prozess selbst (Quickshell/QML) — kein zusätzliches
Programm, keine Fensterregeln, keine Theme-Templates. Farben, Schrift, Radien
und Rahmen kommen aus den Menü-Tokens des aktiven Themes.

Für ältere Omarchy-Versionen ohne Plugin-System gibt es die rofi-Fassung
[omarchy-rofi-launcher](https://github.com/KGasteier/omarchy-rofi-launcher).

## Eigenschaften

- **6 × 6 Raster** mit Icon und Beschriftung; scrollt bei mehr Apps
- **Zeile „zuletzt benutzt"** ganz oben, dezent hinterlegt und durch eine
  feine Linie abgesetzt; Lücken bleiben leer, die alphabetische Liste
  beginnt immer in Zeile 2
- **Drei Punkte am unteren Rand**, solange weitere Apps unterhalb liegen;
  am Listenende blenden sie aus
- **Suche** wie im Omarchy-Menü (Treffer nach Relevanz), Suchfeld mit Lupe
- **Maus und Tastatur**: Hover markiert, Klick startet; Pfeiltasten, `Enter`,
  `Escape` (löscht erst die Suche, dann schließt es)
- **Monogramm-Kacheln** für Apps ohne Icon — Farbton aus dem Icon-Namen,
  Kürzel aus dem App-Namen (`Google Maps` → `Ga`, `Google Messages` → `Gm`)
- **Themenabhängig** ohne eigene Konfiguration

## Installation

```bash
git clone https://github.com/KGasteier/omarchy-launchpad.git
cd omarchy-launchpad
./install.sh
```

Danach öffnet `SUPER + R` das Raster. Die Shell wird beim Installieren
einmal neu gestartet (`omarchy restart shell`), das dauert wenige Sekunden.

Entfernen:

```bash
./install.sh --uninstall
```

Das nimmt nur die eigenen Artefakte heraus (Plugin-Ordner, Binding-Datei,
den `require`-Block in `hyprland.lua`, den Eintrag in `shell.json`, den
MRU-Stand). Vor jedem Eingriff in `hyprland.lua` wird eine Sicherung
`hyprland.lua.bak.launchpad.<zeit>` angelegt.

## Was wo landet

| Pfad | Zweck |
|---|---|
| `~/.config/omarchy/plugins/community.launchpad/` | das Plugin (Kopie von `plugin/`) |
| `~/.config/hypr/launchpad.lua` | Tastenbindung |
| `~/.config/hypr/hyprland.lua` | ein `require("hypr.launchpad")`-Block zwischen Markierungen |
| `~/.config/omarchy/shell.json` | Eintrag unter `plugins` (von der Shell verwaltet) |
| `~/.local/state/omarchy-launchpad/recent.json` | zuletzt gestartete Apps |

## Anpassen

Tastenkombination in `~/.config/hypr/launchpad.lua`; Spalten- und Zeilenzahl,
Icon-Größe und Kartenbreite stehen als Properties am Anfang von
`Launchpad.qml` (`columns`, `visibleRows`, `iconSize`, `cardWidth`).
Die Kartenhöhe ergibt sich aus `visibleRows * cellHeight + indicatorHeight` —
wer die Zeilenzahl ändert, passt `cellHeight` gegenläufig an, wenn die Karte
gleich groß bleiben soll.
Änderungen im Plugin-Ordner greifen bei Overlays erst nach
`omarchy restart shell`.

Aufruf von Hand oder aus anderen Skripten:

```bash
omarchy-shell shell toggle community.launchpad
```

## Bekannte Eigenheiten

- **Hot-Reload greift bei diesem Overlay nicht.** Die Shell erkennt
  Änderungen im Plugin-Ordner (inotify), die bereits geladene Overlay-Instanz
  bleibt aber bestehen. Nach Änderungen: `omarchy restart shell`.
- **Symlinks statt Kopie** im Plugin-Ordner werden von der Überwachung nicht
  gesehen — `install.sh` kopiert deshalb.
- Die Lupe im Suchfeld ist eine Nerd-Font-Glyphe (`U+F002`); ohne Nerd-Schrift
  erscheint ein Ersatzkästchen (`ttf-jetbrains-mono-nerd` hilft).
- Die Suche liefert nur die Treffer, keine MRU-Zeile — wie im Vorbild.

## Lizenz

MIT, siehe [LICENSE](LICENSE).
