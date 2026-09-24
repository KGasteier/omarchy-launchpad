// Fenstertypen fuer das Radial-Mesh-Launchpad.
//
// Die Typen und Farben entsprechen denen von hypr-radial-mesh
// (hypr/radialmesh.lua, M.config.colors): Ein Programm traegt im Launchpad
// dieselbe Farbe wie spaeter seine Karte im Mesh.
//
// Ein Programm kann mehreren Typen angehoeren (Pi ist Agent UND TUI, w3m ist
// TUI UND Webview). Gefiltert wird ueber alle Typen, gefaerbt nach dem
// ersten Typ in PRIMARY_ORDER - das ist die Kategorie, unter der das Mesh
// das Fenster einsortiert.
.pragma library

// Reihenfolge der Filterknoepfe (nur Typen mit mindestens einem Programm
// erscheinen). "all" steht immer vorn. Editor, Viewer und Config sind nur
// Farbtypen: Ihre Programme sind zugleich GUI oder TUI und ueber diese
// Knoepfe erreichbar. Mehr Knoepfe passen nicht in die Kartenbreite.
var BUTTONS = ["all", "terminal", "tui", "ai", "gui", "webview", "files"]

var LABELS = {
  all: "Alle",
  terminal: "Terminals",
  tui: "TUIs",
  ai: "Agents",
  gui: "GUIs",
  webview: "Webviews",
  files: "Files",
  editor: "Editoren",
  viewer: "Viewer",
  config: "System"
}

// Farben wie radialmesh.lua M.config.colors (Hex ohne #).
var COLORS = {
  terminal: "7fd4c1",   // Tuerkis  - Shell
  tui:      "9ad67a",   // Gruen    - Terminal-Anwendung
  ai:       "e879d0",   // Magenta  - Agenten
  webview:  "e2a05f",   // Orange   - Browser, Webapps
  editor:   "8fb8f0",   // Blau     - Editor
  viewer:   "c79bd8",   // Violett  - Medien
  files:    "e6cf7a",   // Sand     - Dateien
  config:   "9aa6b2",   // Grau     - Einstellungen
  gui:      "d68a92"    // Rose     - sonstige GUI
}

// Welcher Typ faerbt, wenn ein Programm mehrere hat. Entspricht der
// Mesh-Logik: Agent-Terminal vor TUI (Klasse TUI.agent -> ai), TUI vor
// Webview (w3m ist im Mesh org.omarchy.w3m -> tui), die spezifischen
// GUI-Typen vor dem Sammeltyp gui.
var PRIMARY_ORDER = ["ai", "tui", "terminal", "webview", "files", "editor", "viewer", "config", "gui"]

// Handverlesene Zuordnungen, Schluessel ist die Desktop-ID (Dateiname ohne
// .desktop). Ueberschreibt die Regeln vollstaendig.
var OVERRIDES = {
  "org.gnome.DiskUtility": ["config", "gui"]
}

function has(list, name) {
  for (var i = 0; i < list.length; i++) if (String(list[i]).toLowerCase() === name) return true
  return false
}

function toList(v) {
  if (!v) return []
  if (typeof v === "string") return v.split(";")
  var out = []
  try { for (var i = 0; i < v.length; i++) out.push(String(v[i])) } catch (e) {}
  return out
}

// entry: Quickshell DesktopEntry (id, execString, runInTerminal, categories).
// Liefert die Typen in PRIMARY_ORDER-Reihenfolge; das erste Element ist der
// Farbtyp.
function classify(entry) {
  var id = String((entry && entry.id) || "")
  if (OVERRIDES[id]) return OVERRIDES[id].slice()

  var exec = String((entry && entry.execString) || "")
  var cats = toList(entry && entry.categories)
  var set = {}

  // Agenten: Starter mit app-id TUI.agent (Claude Code, Pi, OpenCode) oder
  // die Omarchy-Agent-Oberflaeche. Sie laufen im Terminal - also auch TUI.
  var agent = /--app-id[= ]TUI\.agent\b/.test(exec) || /org\.omarchy\.agent\b/.test(exec)
  if (agent) { set.ai = true; set.tui = true }

  if (has(cats, "terminalemulator")) set.terminal = true

  // TUI: laeuft im Terminal - per Terminal=true, ueber einen Terminal-Starter
  // oder als ConsoleOnly markiert.
  if (!set.terminal && ((entry && entry.runInTerminal === true)
      || /\bxdg-terminal-exec\b/.test(exec)
      || /\bomarchy-launch-or-focus-tui\b/.test(exec)
      || /\bomarchy-launch-tui\b/.test(exec)
      || has(cats, "consoleonly")))
    set.tui = true

  // Webviews: Browser und Omarchy-Webapps.
  if (has(cats, "webbrowser")
      || /\bomarchy-launch-webapp\b/.test(exec)
      || /\bomarchy-webapp-handler/.test(exec))
    set.webview = true

  if (has(cats, "filemanager") || has(cats, "filesystem")) set.files = true
  if (has(cats, "texteditor") || has(cats, "ide")) set.editor = true
  if (has(cats, "viewer") || has(cats, "player")) set.viewer = true
  if (has(cats, "settings") || has(cats, "desktopsettings") || has(cats, "hardwaresettings"))
    set.config = true

  // GUI: alles mit eigenem grafischen Fenster, das weder Terminal noch TUI
  // noch Webview ist - auch Editoren, Viewer und Dateimanager.
  if (!set.terminal && !set.tui && !set.webview) set.gui = true

  var out = []
  for (var i = 0; i < PRIMARY_ORDER.length; i++) if (set[PRIMARY_ORDER[i]]) out.push(PRIMARY_ORDER[i])
  return out
}

function color(type) {
  return "#" + (COLORS[type] || "9aa6b2")
}

function label(type) {
  return LABELS[type] || type
}
