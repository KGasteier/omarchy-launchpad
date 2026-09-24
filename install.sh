#!/bin/bash
# Installiert das Radial-Mesh-Launchpad in die Omarchy-Shell (Omarchy >= 4.0).
# Belegt SUPER + R; davor omarchy-launchpad mit dessen --uninstall entfernen.
# Eigene Plugin-ID und eigener MRU-Stand, laeuft also auch nebenbei.
# Aufruf: ./install.sh              installieren / aktualisieren
#         ./install.sh --uninstall  restlos entfernen
set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CFG="${XDG_CONFIG_HOME:-$HOME/.config}"
STATE="${XDG_STATE_HOME:-$HOME/.local/state}"
HYPR="$CFG/hypr"
MAIN="$HYPR/hyprland.lua"
PLUGIN_ID="community.radialmesh-launchpad"
PLUGIN_DIR="$CFG/omarchy/plugins/$PLUGIN_ID"
MARK_BEGIN="-- >>> radialmesh-launchpad >>>"
MARK_END="-- <<< radialmesh-launchpad <<<"

strip_block() {
  [[ -f "$MAIN" ]] || return 0
  if grep -qF -- "$MARK_BEGIN" "$MAIN"; then
    cp "$MAIN" "$MAIN.bak.rmlaunchpad.$(date +%s)"
    sed -i "\\|$MARK_BEGIN|,\\|$MARK_END|d" "$MAIN"
    # Leerzeilen am Dateiende einsammeln, sonst wachsen sie mit jedem Lauf.
    sed -i -e :a -e '/^\n*$/{$d;N;ba' -e '}' "$MAIN"
  fi
}

if [[ "${1:-}" == "--uninstall" ]]; then
  omarchy-shell shell hide "$PLUGIN_ID" >/dev/null 2>&1 || true
  # Nimmt den Eintrag unter "plugins" in shell.json wieder heraus.
  omarchy-shell shell setPluginEnabled "$PLUGIN_ID" false >/dev/null 2>&1 || true
  strip_block
  rm -f "$HYPR/radialmesh-launchpad.lua"
  rm -rf "$PLUGIN_DIR"
  rm -rf "$STATE/radialmesh-launchpad"
  omarchy-shell shell rescanPlugins >/dev/null 2>&1 || true
  hyprctl reload >/dev/null 2>&1 || true
  echo "Radial Mesh Launchpad entfernt."
  exit 0
fi

# --- Voraussetzungen -------------------------------------------------------
command -v hyprctl >/dev/null \
  || { echo "hyprctl nicht gefunden - ist Hyprland installiert?" >&2; exit 1; }
command -v omarchy-shell >/dev/null \
  || { echo "omarchy-shell nicht gefunden - erwartet wird Omarchy 4.0 oder neuer." >&2; exit 1; }
[[ -f "$MAIN" ]] \
  || { echo "$MAIN nicht gefunden - erwartet wird Omarchy mit Lua-Konfiguration." >&2; exit 1; }

# Die Lupe im Suchfeld ist eine Nerd-Font-Glyphe (U+F002).
if ! fc-list ':charset=f002' family 2>/dev/null | grep -qi "nerd"; then
  echo "Hinweis: keine Nerd-Schrift mit U+F002 gefunden - statt der Lupe" >&2
  echo "         erscheint ein Ersatzkaestchen. Abhilfe: ttf-jetbrains-mono-nerd" >&2
fi

# --- Plugin ----------------------------------------------------------------
# Echtes Verzeichnis, kein Symlink: die Shell ueberwacht Plugin-Ordner mit
# inotify, und das folgt Symlinks nicht.
mkdir -p "$(dirname "$PLUGIN_DIR")"
rm -rf "$PLUGIN_DIR"
cp -a "$SRC/plugin" "$PLUGIN_DIR"

mkdir -p "$STATE/radialmesh-launchpad"

# --- Hyprland-Binding ------------------------------------------------------
install -m 644 "$SRC/hypr/radialmesh-launchpad.lua" "$HYPR/radialmesh-launchpad.lua"
strip_block
cp "$MAIN" "$MAIN.bak.rmlaunchpad.$(date +%s)"
printf '\n%s\nrequire("hypr.radialmesh-launchpad")\n%s\n' "$MARK_BEGIN" "$MARK_END" >> "$MAIN"

# --- Aktivieren ------------------------------------------------------------
# Traegt das Plugin unter "plugins" in ~/.config/omarchy/shell.json ein;
# ohne diesen Eintrag ignoriert die Shell das Overlay ("plugin not enabled").
omarchy-shell shell rescanPlugins >/dev/null 2>&1 || true
sleep 1
if [[ "$(omarchy-shell shell enablePlugin "$PLUGIN_ID" '{}' 2>/dev/null)" != "ok" ]]; then
  echo "Warnung: Plugin konnte nicht aktiviert werden. Nachholen mit:" >&2
  echo "         omarchy-shell shell enablePlugin $PLUGIN_ID '{}'" >&2
fi
# Die Shell laedt Overlays mit keepLoaded nur beim Start neu; ein Neustart
# der Shell ist bei Updates deshalb noetig. omarchy restart shell ist
# schnell und verliert keinen Zustand.
# Braucht die alte Shell zum Beenden laenger als 5 s, startet
# omarchy-restart-shell die neue zu frueh; sie bricht mit "An instance of this
# configuration is already running" ab und die Leiste bleibt weg. Deshalb
# pruefen und notfalls einmal nachstarten.
#
# Nie bei gesperrtem Bildschirm: Die Sperre lebt im Shell-Prozess, ein
# Neustart hinterlaesst sie verwaist ("lock-stranded") - die Sitzung war
# danach nur noch per Neustart der VM zu retten (2026-09-24).
if [[ "$(omarchy-shell lock isLocked 2>/dev/null)" == "true" ]]; then
  echo "Hinweis: Bildschirm gesperrt - Shell-Neustart ausgelassen." >&2
  echo "         Nach dem Entsperren: omarchy restart shell" >&2
else
  omarchy restart shell >/dev/null 2>&1 || true
  sleep 2
  if ! omarchy-shell shell ping >/dev/null 2>&1; then
    sleep 5
    omarchy restart shell >/dev/null 2>&1 || true
  fi
  omarchy-shell shell ping >/dev/null 2>&1 \
    || echo "Warnung: Shell laeuft nicht - bitte 'omarchy restart shell' ausfuehren." >&2
fi
hyprctl reload >/dev/null 2>&1 || true

cat <<EOF
Radial Mesh Launchpad installiert.
  Plugin:   $PLUGIN_DIR
  Tasten:   SUPER + R  (aendern in $HYPR/radialmesh-launchpad.lua)
  Aufruf:   omarchy-shell shell toggle $PLUGIN_ID
  MRU:      $STATE/radialmesh-launchpad/recent.json
  Typ vorwaehlen: omarchy-shell shell toggle $PLUGIN_ID '{"type":"ai"}'
EOF
