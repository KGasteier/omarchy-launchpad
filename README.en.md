**English** · [Deutsch](README.md)

# Omarchy Launchpad

A larger app launchpad in Omarchy 4 style, as an overlay plugin for the
[Omarchy](https://omarchy.org) shell (Omarchy 4.0 or newer).

![6×6 grid](docs/screenshot.png)

The plugin runs inside the shell process itself (Quickshell/QML) — no extra
program, no window rules, no theme templates. Colours, fonts, radii and
borders come from the menu tokens of the active theme.

For older Omarchy versions without a plugin system there is the rofi variant
[omarchy-rofi-launcher](https://github.com/KGasteier/omarchy-rofi-launcher).

## Features

- **6 × 6 grid** with icon and label; scrolls when there are more apps
- **A "recently used" row** at the top, gently tinted and set off by a
  hairline; gaps stay empty, so the alphabetical list always starts in row 2
- **Three dots at the bottom edge** while further apps are waiting below;
  they fade out at the end of the list
- **Search** as in the Omarchy menu (matches by relevance), search field
  with a magnifier
- **Mouse and keyboard**: hover highlights, click launches; arrow keys,
  `Enter`, `Escape` (clears the search first, then closes)
- **Monogram tiles** for apps without an icon — hue derived from the icon
  name, initials from the app name (`Google Maps` → `Ga`,
  `Google Messages` → `Gm`)
- **Follows the theme** without any configuration of its own

## Installation

```bash
git clone https://github.com/KGasteier/omarchy-launchpad.git
cd omarchy-launchpad
./install.sh
```

`SUPER + R` then opens the grid. The shell is restarted once during
installation (`omarchy restart shell`), which takes a few seconds.

To remove:

```bash
./install.sh --uninstall
```

This takes out only its own artefacts (plugin folder, binding file, the
`require` block in `hyprland.lua`, the entry in `shell.json`, the MRU state).
Before every change to `hyprland.lua` a backup
`hyprland.lua.bak.launchpad.<time>` is written.

## What goes where

| Path | Purpose |
|---|---|
| `~/.config/omarchy/plugins/community.launchpad/` | the plugin (copy of `plugin/`) |
| `~/.config/hypr/launchpad.lua` | key binding |
| `~/.config/hypr/hyprland.lua` | a `require("hypr.launchpad")` block between markers |
| `~/.config/omarchy/shell.json` | entry under `plugins` (managed by the shell) |
| `~/.local/state/omarchy-launchpad/recent.json` | recently launched apps |

## Customising

Key combination in `~/.config/hypr/launchpad.lua`; column and row count, icon
size and card width are properties at the top of `Launchpad.qml` (`columns`,
`visibleRows`, `iconSize`, `cardWidth`).
The card height follows from `visibleRows * cellHeight + indicatorHeight` — if
you change the number of rows, adjust `cellHeight` the other way to keep the
card the same size.
Changes in the plugin folder only take effect for overlays after
`omarchy restart shell`.

Calling it by hand or from other scripts:

```bash
omarchy-shell shell toggle community.launchpad
```

## Known quirks

- **Hot reload does not work for this overlay.** The shell does notice changes
  in the plugin folder (inotify), but the already loaded overlay instance stays
  around. After changes: `omarchy restart shell`.
- **Symlinks instead of a copy** in the plugin folder are not seen by the
  watcher — which is why `install.sh` copies.
- The magnifier in the search field is a Nerd Font glyph (`U+F002`); without a
  Nerd font you get a replacement box (`ttf-jetbrains-mono-nerd` helps).
- Search shows only the matches, no MRU row — as in the original.

## Licence

MIT, see [LICENSE](LICENSE).
