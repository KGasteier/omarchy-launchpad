[Deutsch](README.md) · **English**

# Radial Mesh Launchpad

An app launchpad in the Omarchy 4 style with **filtering by window type** —
as an overlay plugin for the [Omarchy](https://omarchy.org) shell. Built for
the radial-mesh mode of
[hypr-radial-mesh](https://github.com/KGasteier/hypr-radial-mesh), fork of
[omarchy-launchpad](https://github.com/KGasteier/omarchy-launchpad).

![6×6 grid with type filter bar](docs/screenshot.png)

The plugin runs inside the shell process itself (Quickshell/QML) — no extra
program, no window rules, no theme templates. Colors, fonts, radii and
borders come from the menu tokens of the active theme.

## Features

- **Type filter bar** below the search: All · Terminals · TUIs · Agents ·
  GUIs · Webviews · Files. Each button shows how many programs it holds;
  buttons with no programs are hidden
- **Multiple assignments**: a program can belong to several types and shows
  up in all of them — Pi is an agent *and* a TUI, w3m is a TUI *and* a
  webview, Nautilus is files *and* GUI. The tint follows the type the mesh
  assigns
- **Alphabetical** within each type; search stays relevance-ordered
- **Type colour behind every icon**: each tile sits on a clearly visible
  tinted square in its type colour — no separate outline, slightly stronger
  under the cursor — including the MRU row
- **“Recently used" row** between the search field and the filter bar; it
  does not scroll and launches the app directly on click
- **6 × 6 grid**, scrolls when there are more programs; **dots at the
  bottom** while more programs lie below
- **Search** like the Omarchy menu, with a Nerd Font magnifier; the field
  reads “Search in TUIs…" while a type is selected
- **Esc steps back**: first the search text, then the type, then close
- **Tab / Shift+Tab** jumps to the next / previous type
- **Monogram tiles** for programs without an icon (`Monogram.js`)
- **Theme dependent**, no configuration of its own

## Installation

```bash
git clone https://github.com/KGasteier/radialmesh-launchpad.git
cd radialmesh-launchpad
./install.sh
```

`SUPER + R` then opens the grid. The installer restarts the shell once
(`omarchy restart shell`), which takes a few seconds.

**Replacing `omarchy-launchpad`**: run `./install.sh --uninstall` there
first, then install this one. Hyprland must not see two `SUPER + R`
bindings. The rofi-based version is unaffected.

Side-by-side installs still work — but then change the binding in
`~/.config/hypr/radialmesh-launchpad.lua` (e. g. to `SUPER + SHIFT + R`);
the plugin ID and the MRU file are separate either way.

To remove:

```bash
./install.sh --uninstall
```

This removes only its own artifacts (plugin folder, binding file, the
`require("hypr.radialmesh-launchpad")` block between markers in
`hyprland.lua`, the `shell.json` entry, the MRU state). Before every edit of
`hyprland.lua` a backup `hyprland.lua.bak.rmlaunchpad.<time>` is written.

## What lands where

| Path | Purpose |
|---|---|
| `~/.config/omarchy/plugins/community.radialmesh-launchpad/` | the plugin (copy of `plugin/`) |
| `~/.config/hypr/radialmesh-launchpad.lua` | key binding |
| `~/.config/hypr/hyprland.lua` | a `require("hypr.radialmesh-launchpad")` block between markers |
| `~/.config/omarchy/shell.json` | entry under `plugins` (managed by the shell) |
| `~/.local/state/radialmesh-launchpad/recent.json` | recently launched apps (seeded from the original's MRU on first run) |

## Types

Each program is classified from its desktop file fields: `Exec` (terminal
starters, `--app-id=TUI.agent`, `omarchy-launch-webapp`), `Terminal=true`
and `Categories`. The types and their colours are identical to
`M.config.colors` in `hypr-radial-mesh` — a program carries the same colour
in the launchpad as its card later has in the mesh.

| Type | Colour | detected via |
|---|---|---|
| Terminals | turquoise | category `TerminalEmulator` |
| TUIs | green | `Terminal=true`, `xdg-terminal-exec`, `ConsoleOnly` |
| Agents | magenta | `--app-id=TUI.agent`, `org.omarchy.agent` (also a TUI) |
| Webviews | orange | category `WebBrowser`, `omarchy-launch-webapp` |
| Files | sand | category `FileManager` / `FileSystem` |
| GUIs | rose | anything with its own window that is not terminal/TUI/webview |

Editors, viewers and system tiles keep their own colour type (blue, violet,
grey) but stay reachable through the buttons above — they are GUIs as well.
Hand assignments live in `plugin/Types.js` (`OVERRIDES`, keyed by desktop ID).

## Invocation and customization

By hand or from scripts, optionally with a preselected type:

```bash
omarchy-shell shell toggle community.radialmesh-launchpad
omarchy-shell shell toggle community.radialmesh-launchpad '{"type":"tui"}'
omarchy-shell shell toggle community.radialmesh-launchpad '{"type":"ai"}'
```

`gui`, `tui`, `terminal`, `webview` and `files` are accepted. The companion
`radialmesh-companion` opens the launchpad with the type of the neighbouring
card when an empty cell is clicked.

The shortcut lives in `~/.config/hypr/radialmesh-launchpad.lua`; column and
row count, icon size and card width are properties at the top of
`Launchpad.qml` (`columns`, `visibleRows`, `iconSize`, `cardWidth`). Card
height follows `visibleRows * cellHeight + indicatorHeight` — if you change
the row count, adjust `cellHeight` in the opposite direction to keep the
card the same size. Changes in the plugin folder only take effect for
overlays after `omarchy restart shell`.

## Known quirks

- **Hot reload does not work for this overlay.** The shell notices changes
  in the plugin folder (inotify), but the loaded overlay instance stays as
  it is. After changes: `omarchy restart shell`.
- **Symlinks instead of a copy** in the plugin folder are not seen by the
  watcher — `install.sh` copies for that reason.
- The magnifier in the search field is a Nerd Font glyph (`U+F002`); without
  a Nerd Font a placeholder box appears (`ttf-jetbrains-mono-nerd` helps).
- Search shows only the hits, no MRU row — like the original.
- Editors, viewers and system tiles have **no buttons of their own** (they
  would duplicate `GUIs`); their tint still tells them apart.

## License

MIT, see [LICENSE](LICENSE).
