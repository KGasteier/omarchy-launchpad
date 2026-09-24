import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import QtQuick
import qs.Commons
import qs.Ui
import "Monogram.js" as Monogram
import "Types.js" as Types

// Radial-Mesh-Launchpad: App-Raster fuer den Radial-Mesh-Modus
// (hypr-radial-mesh), Fork von omarchy-launchpad.
//
// Unterschiede zum Original:
//  - Unter dem Suchfeld eine Knopfleiste mit den Fenstertypen des Mesh
//    (Terminals, TUIs, Agents, GUIs, Webviews, Files, ...). Ein Programm kann
//    mehreren Typen angehoeren (Pi: Agent + TUI). Nach Wahl eines Typs zeigt
//    das Raster nur dessen Programme, weiter alphabetisch.
//  - Jedes Icon liegt auf einer dezenten Flaeche in seiner Typfarbe - dieselbe
//    Farbe, die das Fenster spaeter im Mesh traegt (Types.js).
//  - Payload {"type":"tui"} waehlt beim Oeffnen gleich einen Typ vor.
//
// Aus dem Original:
//
// Aufbau nach dem Vorbild des Emojis-Overlays: ein Layer-Shell-Fenster ueber
// dem ganzen Bildschirm, darin eine Karte mit Suchfeld und GridView.
// Die App-Liste, Icon-Aufloesung und das Starten uebernimmt der Shell-Dienst
// shell.appLibrary - hier steckt nur Darstellung, Suche und Tastatur.
//
// Ueber der Knopfleiste zeigt eine eigene Zeile die zuletzt gestarteten Apps
// (bis zu `columns` Stueck), darunter das Raster alphabetisch. Sobald gesucht
// wird, entfaellt die MRU-Zeile. Der MRU-Stand liegt als JSON in
// ~/.local/state/radialmesh-launchpad/recent.json.
//
// Groesse: Spalten, Zeilen, Icongroesse und Kartenbreite lassen sich im
// Plugin-Eintrag von ~/.config/omarchy/shell.json einstellen (siehe README):
//   { "id": "community.radialmesh-launchpad", "columns": 5, "rows": 5, "iconSize": 32 }
// Passt das Raster nicht auf den Bildschirm, nimmt die Karte von sich aus
// Zeilen und Spalten weg - angeschnittene Zeilen gibt es nicht.

Item {
  id: root

  property var shell: null
  property var manifest: null
  readonly property var appLibrary: root.shell ? root.shell.appLibrary : null
  // Rueckfall ohne shell.appLibrary (aeltere Omarchy-4-Staende, dort ist der Dienst
  // noch nicht injiziert): Liste direkt aus DesktopEntries, Icons ueber Quickshell,
  // Start per gtk-launch. Sonst blieb das Raster leer ("Keine Programme vom Typ Alle").
  // Der Shell-Dienst wird nur genommen, wenn er die erwartete Schnittstelle hat
  // und beim letzten Oeffnen Eintraege lieferte (libEmpty, gesetzt in open()).
  property bool libEmpty: false
  readonly property bool libUsable: !!root.appLibrary && typeof root.appLibrary.sortedEntries === "function"
                                     && typeof root.appLibrary.launch === "function" && !root.libEmpty
  readonly property var apps: root.libUsable ? root.appLibrary : fallbackLibrary
  QtObject {
    id: fallbackLibrary
    signal appsChanged()
    function sortedEntries(query) {
      var all = DesktopEntries.applications.values || []
      var q = String(query || "").toLowerCase().trim()
      var out = []
      for (var i = 0; i < all.length; i++) {
        var e = all[i]
        if (!e || e.noDisplay) continue
        var name = String(e.name || e.id || "")
        if (q) {
          var hay = [name, e.genericName, e.comment, e.id, (e.keywords || []).join ? e.keywords.join(" ") : ""].join(" ").toLowerCase()
          var terms = q.split(/\s+/), ok = true
          for (var k = 0; k < terms.length; k++) if (hay.indexOf(terms[k]) < 0) { ok = false; break }
          if (!ok) continue
        }
        out.push({ entry: e, score: 0, key: name.toLowerCase(), name: name })
      }
      out.sort(function(a, b) { return a.key < b.key ? -1 : a.key > b.key ? 1 : 0 })
      return out
    }
    // Icon-Index wie im Shell-Dienst: */apps/* und */devices/* aller XDG-Icon-
    // Verzeichnisse plus /usr/share/pixmaps, SVG vor PNG, erster Treffer gewinnt.
    property var iconIndex: ({})
    function iconSource(icon) {
      var v = String(icon || "")
      if (v.indexOf("file://") === 0 || v.indexOf("image://") === 0) return v
      if (v.charAt(0) === "/") return "file://" + v
      if (v && iconIndex[v]) return "file://" + iconIndex[v]
      var themed = v ? Quickshell.iconPath(v, true) : ""
      return themed.length > 0 ? themed : Quickshell.iconPath("application-x-executable", true)
    }
    function entryName(e) { return String((e && e.name) || (e && e.id) || "") }
    function refreshIcons() { if (!iconScan.running) iconScan.running = true }
    function launch(id, name) {
      if (!id) return
      Quickshell.execDetached(["sh", "-c", "uwsm-app -- gtk-launch \"$1\" || gtk-launch \"$1\"", "sh", String(id) + ".desktop"])
    }
  }
  Process {
    id: iconScan
    command: ["bash", "-c", 'dirs="$HOME/.icons $HOME/.local/share/icons"; IFS=":"; for d in ${XDG_DATA_DIRS:-/usr/local/share:/usr/share}; do dirs="$dirs $d/icons"; done; unset IFS; for ext in svg png; do for base in $dirs; do [[ -d $base ]] && find "$base" \\( -path "*/apps/*" -o -path "*/devices/*" \\) -name "*.$ext" 2>/dev/null; done; find /usr/share/pixmaps -maxdepth 1 -name "*.$ext" 2>/dev/null; done']
    stdout: StdioCollector {
      onStreamFinished: {
        var idx = ({})
        var lines = this.text.split("\n")
        for (var i = 0; i < lines.length; i++) {
          var f = lines[i]
          if (!f) continue
          var n = f.substring(f.lastIndexOf("/") + 1).replace(/\.(svg|png)$/, "")
          if (!idx[n]) idx[n] = f
        }
        fallbackLibrary.iconIndex = idx
        fallbackLibrary.appsChanged()
      }
    }
  }
  Connections {
    target: root.libUsable ? null : DesktopEntries.applications
    function onValuesChanged() { fallbackLibrary.appsChanged() }
  }
  readonly property string pluginId: (root.manifest && root.manifest.id) || "community.radialmesh-launchpad"

  // Eigener Eintrag unter "plugins" in shell.json. Die Shell beobachtet die
  // Datei; Aenderungen greifen beim naechsten Oeffnen ohne Neustart.
  readonly property var settings: {
    var cfg = root.shell ? root.shell.shellConfig : null
    var list = cfg && Array.isArray(cfg.plugins) ? cfg.plugins : []
    for (var i = 0; i < list.length; i++)
      if (list[i] && list[i].id === root.pluginId) return list[i]
    return ({})
  }
  // Zahl aus den Einstellungen, auf [lo, hi] begrenzt; sonst Vorgabe.
  function setting(key, def, lo, hi) {
    var v = Number(root.settings[key])
    if (root.settings[key] === undefined || !isFinite(v) || v <= 0) return def
    return Math.max(lo, Math.min(hi, v))
  }

  property bool opened: false
  property string filterText: ""
  property int selectedIndex: 0
  property bool cursorActive: false

  // Gewaehlter Typ ("all" = keine Einschraenkung) und die Zahl der Programme
  // je Typ - Knoepfe ohne Programme werden ausgeblendet.
  property string activeType: "all"
  property var typeCounts: ({})
  // Ein Farbtyp ohne eigenen Knopf (Editor, Viewer, System) bekommt einen,
  // solange er gewaehlt ist - etwa beim Aufruf aus einer Leerzelle des Mesh
  // mit {"type":"editor"}. So bleibt sichtbar, wonach gefiltert wird.
  property string extraType: ""
  readonly property var visibleTypes: {
    var out = []
    for (var i = 0; i < Types.BUTTONS.length; i++) {
      var t = Types.BUTTONS[i]
      if (t === "all" || (root.typeCounts[t] || 0) > 0) out.push(t)
    }
    if (root.extraType && out.indexOf(root.extraType) < 0 && (root.typeCounts[root.extraType] || 0) > 0)
      out.push(root.extraType)
    return out
  }

  // Klassifikation je Desktop-ID, gilt bis sich die App-Liste aendert. Spart
  // bei jedem Tastendruck das erneute Klassifizieren aller Programme.
  property var typeCache: ({})
  // Zuletzt aufgebaute Zeilen je App-ID - Quelle fuer die MRU-Zeile.
  property var itemsById: ({})

  // Zuletzt gestartete App-IDs, neueste zuerst. Gespeichert werden mehr,
  // als die Zeile zeigt, damit eine breitere Einstellung nicht leer beginnt.
  readonly property int recentKeep: 12
  property var recentIds: []
  readonly property string statePath: Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")
  readonly property string recentPath: statePath + "/radialmesh-launchpad/recent.json"
  // MRU-Zeile nur ohne Suchtext.
  readonly property bool showRecent: root.filterText.length === 0

  FileView {
    id: recentFile
    path: root.recentPath
    printErrors: false
    onLoaded: {
      try {
        var v = JSON.parse(text())
        root.recentIds = Array.isArray(v) ? v.filter(function(x) { return typeof x === "string" }) : []
      } catch (e) { root.recentIds = [] }
      // reload() liefert asynchron - nur die MRU-Zeile nachziehen.
      if (root.opened) root.rebuildRecent()
    }
    // Noch keine eigene MRU: einmalig die des Original-Launchpads
    // uebernehmen, damit die Zeile nicht leer beginnt.
    onLoadFailed: { root.recentIds = []; legacyRecent.reload() }
  }

  FileView {
    id: legacyRecent
    path: root.statePath + "/omarchy-launchpad/recent.json"
    printErrors: false
    onLoaded: {
      if (root.recentIds.length > 0) return
      try {
        var v = JSON.parse(text())
        if (!Array.isArray(v)) return
        root.recentIds = v.filter(function(x) { return typeof x === "string" }).slice(0, root.recentKeep)
        recentFile.setText(JSON.stringify(root.recentIds))
        if (root.opened) root.rebuildRecent()
      } catch (e) {}
    }
  }

  function rememberLaunch(appId) {
    var next = [appId]
    for (var i = 0; i < root.recentIds.length && next.length < root.recentKeep; i++)
      if (root.recentIds[i] !== appId) next.push(root.recentIds[i])
    root.recentIds = next
    recentFile.setText(JSON.stringify(next))
  }

  // Farben aus den Menue-Tokens des Themes - so folgt das Raster jedem
  // Themenwechsel automatisch.
  property color background: Color.menu.background
  property color foreground: Color.menu.text
  property color border: Color.menu.border
  property var borderSpec: Border.surfaceSpec("menu", "border", border, Math.max(1, Style.space(2)))
  property color scrim: Color.menu.scrim
  property color selectedBackground: Color.menu.selectedBackground
  readonly property int cornerRadius: Style.cornerRadius
  property string fontFamily: Style.font.menuFamily

  // Raster, Vorgabe 6 x 6. Die Karte ist so breit wie das rofi-Vorbild (rund
  // 61 % der Bildschirmbreite); die Zellbreite ergibt sich aus dem
  // verfuegbaren Platz, damit die Spaltenzahl garantiert aufgeht -
  // Style.space() skaliert mit der Theme-Schrift, feste Werte gehen nicht auf.
  //
  // Alle Zellmasse leiten sich von iconSize ab (Vorgabe 38): Typflaeche =
  // Icon + 2 * iconPad, Zeile = Icon + 40 (Flaeche, Abstand, Beschriftung).
  // Das Icon ist kleiner als im Original (44), damit die Typflaeche darum
  // herum in dieselbe Zeilenhoehe passt.
  readonly property int columns: Math.round(root.setting("columns", 6, 3, 10))
  readonly property int rows: Math.round(root.setting("rows", 6, 2, 10))
  readonly property int iconBase: Math.round(root.setting("iconSize", 38, 20, 96))
  readonly property real widthFraction: root.setting("width", 0.615, 0.3, 1)

  property int iconSize: Style.space(iconBase)
  property int iconPad: Style.space(Math.max(4, Math.round(iconBase * 0.21)))
  property int cellHeight: Style.space(iconBase + 40)
  // Schmaler wird eine Zelle nie: Typflaeche plus etwas Luft fuer die
  // Beschriftung. Reicht die Breite nicht, faellt eine Spalte weg.
  property int minCellWidth: Style.space(iconBase + Math.max(4, Math.round(iconBase * 0.21)) * 2 + 30)
  // Streifen unter dem Raster fuer die "mehr da"-Punkte.
  property int indicatorHeight: Style.space(36)
  property int contentMargin: Style.spacing.panelPadding
  property int headerHeight: Math.max(Style.space(34), Style.font.title + Style.spacing.controlPaddingY * 2)
  property int contentSpacing: Style.spacing.md
  property int chipHeight: Math.max(Style.space(28), Style.font.body + Style.spacing.controlPaddingY * 2)
  // Mindestabstand der Karte zum Bildschirmrand.
  readonly property int screenMargin: Style.space(16)

  readonly property int insetsH: card.contentLeftInset + card.contentRightInset
  readonly property int insetsV: card.contentTopInset + card.contentBottomInset

  // Breite: Anteil am Bildschirm, aber nie so schmal, dass die gewuenschten
  // Spalten unter minCellWidth fallen - und nie breiter als der Schirm.
  property int cardWidth: Math.min(panel.width - screenMargin * 2,
    Math.max(Math.round(panel.width * widthFraction), columns * minCellWidth + insetsH))
  readonly property int effectiveColumns: Math.max(2, Math.min(columns,
    Math.floor((cardWidth - insetsH) / minCellWidth)))
  // Beim Oeffnen kennt das Panel seine Breite noch nicht (erst 0, dann der
  // Bildschirm) - die MRU-Zeile muss der endgueltigen Spaltenzahl folgen.
  onEffectiveColumnsChanged: if (root.opened) root.rebuildRecent()
  property int cellWidth: Math.floor(resultGrid.width / effectiveColumns)

  // Hoehe: alles ausser dem Raster ist fest. Die MRU-Zeile ist immer
  // eingerechnet, damit die Karte beim ersten Tastendruck nicht springt -
  // beim Suchen bekommt das Raster ihren Platz (eine Reihe mehr).
  readonly property int fixedHeight: insetsV + headerHeight + cellHeight + chipHeight
    + contentSpacing * 3 + indicatorHeight
  readonly property int effectiveRows: Math.max(1, Math.min(rows,
    Math.floor((panel.height - screenMargin * 2 - fixedHeight) / cellHeight)))
  property int cardHeight: fixedHeight + effectiveRows * cellHeight

  // Monitor mit dem Fokus; ohne Treffer waehlt Quickshell selbst.
  property var targetScreen: null
  function focusedScreen() {
    var m = Hyprland.focusedMonitor
    if (!m) return null
    var list = Quickshell.screens
    for (var i = 0; i < list.length; i++) if (list[i].name === m.name) return list[i]
    return null
  }

  function open(payloadJson) {
    var payload = ({})
    try { payload = JSON.parse(payloadJson || "{}") || ({}) } catch (e) { payload = ({}) }
    root.targetScreen = root.focusedScreen()
    root.opened = true
    root.filterText = ""
    // Jeder Typ aus Types.LABELS ist erlaubt, auch die ohne eigenen Knopf.
    root.activeType = (payload.type && Types.LABELS[payload.type]) ? String(payload.type) : "all"
    root.extraType = Types.BUTTONS.indexOf(root.activeType) < 0 ? root.activeType : ""
    root.selectedIndex = 0
    root.cursorActive = false
    // Liefert der Shell-Dienst nichts, obwohl es Desktop-Eintraege gibt, auf den
    // eigenen Rueckfall wechseln (Bericht 2026-09-24: Raster auf frischer VM leer).
    if (root.appLibrary && !root.libEmpty) {
      var probe = []
      try { probe = root.appLibrary.sortedEntries("") || [] } catch (err) { probe = [] }
      if (probe.length === 0 && (DesktopEntries.applications.values || []).length > 0) {
        console.warn("radialmesh-launchpad: shell.appLibrary liefert keine Programme - nutze DesktopEntries")
        root.libEmpty = true
      }
    }
    if (!root.libUsable && Object.keys(fallbackLibrary.iconIndex).length === 0) fallbackLibrary.refreshIcons()
    else root.apps.refreshIcons()
    root.refreshCounts()
    root.rebuildDisplay()
    recentFile.reload()
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  function close() {
    root.opened = false
  }

  function dismiss() {
    root.opened = false
    if (root.shell && typeof root.shell.hide === "function")
      root.shell.hide(root.pluginId)
  }

  function toggle() {
    if (root.opened) root.dismiss()
    else root.open("{}")
  }

  function typesOf(e) {
    var id = String(e.id || "")
    var t = root.typeCache[id]
    if (!t) { t = Types.classify(e); root.typeCache[id] = t }
    return t
  }

  // Programme je Typ, immer ueber die ganze Liste (ohne Suchtext), damit die
  // Knopfleiste beim Tippen nicht springt. Nur beim Oeffnen und wenn sich die
  // App-Liste aendert.
  function refreshCounts() {
    if (!root.apps) return
    var all = root.apps.sortedEntries("")
    var counts = {}
    for (var c = 0; c < all.length; c++) {
      var ts = root.typesOf(all[c].entry)
      for (var q = 0; q < ts.length; q++) counts[ts[q]] = (counts[ts[q]] || 0) + 1
    }
    counts.all = all.length
    root.typeCounts = counts
  }

  // MRU-Zeile in Reihenfolge der recentIds; deinstallierte Programme
  // fallen stillschweigend heraus.
  function rebuildRecent() {
    recentModel.clear()
    if (!root.showRecent) return
    for (var r = 0; r < root.recentIds.length && recentModel.count < root.effectiveColumns; r++) {
      var hit = root.itemsById[root.recentIds[r]]
      if (hit) recentModel.append(hit)
    }
  }

  function rebuildDisplay() {
    displayModel.clear()
    if (!root.apps) return
    // sortedEntries liefert Wrapper { entry, score, key, name } - der
    // eigentliche Desktop-Eintrag steckt in .entry.
    var rows = root.apps.sortedEntries(root.filterText)
    var items = []
    for (var i = 0; i < rows.length; i++) {
      var e = rows[i].entry
      var types = root.typesOf(e)
      var src = root.apps.iconSource(e.icon)
      items.push({
        typeKey: types[0] || "gui",
        // Mit Kommas umrahmt, damit indexOf(",tui,") eindeutig trifft;
        // ListModel speichert keine Arrays.
        typeList: "," + types.join(",") + ",",
        appId: String(e.id || ""),
        label: root.apps.entryName(e),
        iconKey: String(e.icon || ""),
        iconSource: src,
        // Kein Icon oder nur der generische Fallback: Monogramm-Kachel.
        needsMonogram: !e.icon || src.indexOf("application-x-executable") >= 0,
        mono: "", hue: 0
      })
    }
    Monogram.assign(items)
    if (root.activeType !== "all" && !(root.typeCounts[root.activeType] > 0)) root.activeType = "all"

    // Ohne Suchtext ist das die vollstaendige Liste - Quelle der MRU-Zeile.
    // ListModel.append kopiert, die Objekte duerfen geteilt werden.
    if (root.filterText.length === 0) {
      var byId = {}
      for (var k = 0; k < items.length; k++) byId[items[k].appId] = items[k]
      root.itemsById = byId
    }
    root.rebuildRecent()

    for (var j = 0; j < items.length; j++) {
      if (root.activeType !== "all" && items[j].typeList.indexOf("," + root.activeType + ",") < 0) continue
      displayModel.append(items[j])
    }
    if (displayModel.count === 0) selectedIndex = 0
    else if (selectedIndex >= displayModel.count) selectedIndex = displayModel.count - 1
    Qt.callLater(function() {
      if (displayModel.count > 0) resultGrid.positionViewAtIndex(root.selectedIndex, GridView.Contain)
    })
  }

  function select(delta) {
    if (displayModel.count === 0) return
    if (!cursorActive) {
      cursorActive = true
      selectedIndex = delta < 0 ? displayModel.count - 1 : 0
    } else {
      selectedIndex = (selectedIndex + delta + displayModel.count) % displayModel.count
    }
    resultGrid.positionViewAtIndex(selectedIndex, GridView.Contain)
  }

  function selectRow(delta) {
    if (displayModel.count === 0) return
    if (!cursorActive) {
      cursorActive = true
      selectedIndex = delta < 0 ? displayModel.count - 1 : 0
    } else {
      selectedIndex = Math.max(0, Math.min(displayModel.count - 1, selectedIndex + delta * effectiveColumns))
    }
    resultGrid.positionViewAtIndex(selectedIndex, GridView.Contain)
  }

  function setFilter(next) {
    root.filterText = next
    root.selectedIndex = 0
    root.cursorActive = next.length > 0
    root.rebuildDisplay()
  }

  function setType(t) {
    if (root.activeType === t) return
    root.activeType = t
    root.selectedIndex = 0
    root.cursorActive = root.filterText.length > 0
    root.rebuildDisplay()
    resultGrid.positionViewAtBeginning()
  }

  // Tab / Shift+Tab: zum naechsten / vorigen sichtbaren Typ.
  function cycleType(delta) {
    var vt = root.visibleTypes
    if (vt.length === 0) return
    var i = vt.indexOf(root.activeType)
    root.setType(vt[((i < 0 ? 0 : i) + delta + vt.length) % vt.length])
  }

  function activateIndex(index) {
    if (index < 0 || index >= displayModel.count) return
    var row = displayModel.get(index)
    root.dismiss()
    root.rememberLaunch(row.appId)
    if (root.apps) root.apps.launch(row.appId, row.label)
  }

  function activateRecent(index) {
    if (index < 0 || index >= recentModel.count) return
    var row = recentModel.get(index)
    if (!row.appId) return
    root.dismiss()
    root.rememberLaunch(row.appId)
    if (root.apps) root.apps.launch(row.appId, row.label)
  }

  ListModel { id: displayModel }
  ListModel { id: recentModel }

  Connections {
    target: root.apps
    ignoreUnknownSignals: true
    function onAppsChanged() {
      root.typeCache = ({})
      if (root.opened) { root.refreshCounts(); root.rebuildDisplay() }
    }
  }

  PanelWindow {
    id: panel
    visible: root.opened
    screen: root.targetScreen
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    WlrLayershell.namespace: "radialmesh-launchpad"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    exclusionMode: ExclusionMode.Ignore

    Rectangle { anchors.fill: parent; color: root.scrim }
    MouseArea { anchors.fill: parent; onClicked: root.dismiss() }

    BorderSurface {
      id: card
      width: root.cardWidth
      height: root.cardHeight
      radius: root.cornerRadius
      anchors.centerIn: parent
      color: root.background
      borderSpec: root.borderSpec
      padding: root.contentMargin

      MouseArea { anchors.fill: parent; onClicked: {} }

      Item {
        id: keyCatcher
        anchors.fill: parent
        focus: true
        Keys.priority: Keys.BeforeItem
        Keys.onPressed: function(event) {
          if (event.key === Qt.Key_Escape) {
            // Stufenweise zurueck: erst Suchtext, dann Typ, dann schliessen.
            if (root.filterText) root.setFilter("")
            else if (root.activeType !== "all") root.setType("all")
            else root.dismiss()
            event.accepted = true
          } else if (event.key === Qt.Key_Backtab || (event.key === Qt.Key_Tab && (event.modifiers & Qt.ShiftModifier))) {
            root.cycleType(-1); event.accepted = true
          } else if (event.key === Qt.Key_Tab) {
            root.cycleType(1); event.accepted = true
          } else if (Util.editsFilter(event, root.filterText)) {
            root.setFilter(Util.editedFilter(event, root.filterText))
            event.accepted = true
          } else if (event.key === Qt.Key_Left) { root.select(-1); event.accepted = true }
          else if (event.key === Qt.Key_Right) { root.select(1); event.accepted = true }
          else if (event.key === Qt.Key_Up) { root.selectRow(-1); event.accepted = true }
          else if (event.key === Qt.Key_Down) { root.selectRow(1); event.accepted = true }
          else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            if (root.cursorActive) root.activateIndex(root.selectedIndex)
            else if (displayModel.count > 0) root.activateIndex(0)
            event.accepted = true
          } else if (event.text && event.text.length === 1 && event.text.charCodeAt(0) >= 32 && event.text.charCodeAt(0) !== 127) {
            root.setFilter(root.filterText + event.text)
            event.accepted = true
          }
        }
      }

      Column {
        anchors.fill: parent
        anchors.topMargin: card.contentTopInset
        anchors.rightMargin: card.contentRightInset
        anchors.bottomMargin: card.contentBottomInset
        anchors.leftMargin: card.contentLeftInset
        spacing: root.contentSpacing

        // Suchfeld
        Rectangle {
          width: parent.width
          height: root.headerHeight
          radius: root.cornerRadius
          color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.06)

          Row {
            anchors.fill: parent
            anchors.leftMargin: Style.space(12)
            anchors.rightMargin: Style.space(12)
            spacing: Style.space(8)

            Text {
              text: "\uf002"   // Lupe (Nerd Font)
              color: root.foreground
              opacity: 0.5
              font.family: root.fontFamily
              font.pixelSize: Style.font.title
              anchors.verticalCenter: parent.verticalCenter
            }
            Text {
              textFormat: Text.PlainText
              text: root.filterText || (root.activeType === "all" ? "Suchen…" : "Suchen in " + Types.label(root.activeType) + "…")
              color: root.foreground
              opacity: root.filterText ? 1 : 0.5
              font.family: root.fontFamily
              font.pixelSize: Style.font.heading
              elide: Text.ElideRight
              anchors.verticalCenter: parent.verticalCenter
              width: parent.width - Style.space(30)
            }
          }
        }

        // MRU-Zeile: liegt ueber der Knopfleiste, dezent hinterlegt und mit
        // feiner Linie darunter. Eigene GridView, scrollt nicht mit.
        Item {
          width: parent.width
          height: root.showRecent ? root.cellHeight : 0
          visible: root.showRecent

          Rectangle {
            anchors.fill: parent
            anchors.margins: Style.space(2)
            radius: root.cornerRadius
            color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.05)
          }

          GridView {
            id: recentGrid
            anchors.fill: parent
            model: recentModel
            cellWidth: root.cellWidth
            cellHeight: root.cellHeight
            interactive: false
            boundsBehavior: Flickable.StopAtBounds

            delegate: AppCell {
              required property int index
              required property var model

              label: model.label
              iconSource: model.iconSource
              needsMonogram: model.needsMonogram
              mono: model.mono
              hue: model.hue
              typeColor: model.typeKey ? Types.color(model.typeKey) : "transparent"

              width: root.cellWidth
              height: root.cellHeight
              iconSize: root.iconSize
              iconPad: root.iconPad
              foreground: root.foreground
              selectedBackground: root.selectedBackground
              fontFamily: root.fontFamily
              hasCursor: false
              onActivated: { root.cursorActive = true; root.activateRecent(index) }
            }
          }

          Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            width: parent.width - Style.space(16)
            height: 1
            color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.13)
          }
        }

        // Typ-Knoepfe: gleich breit ueber die ganze Kartenbreite. Farbe je
        // Typ wie im Mesh; der gewaehlte Knopf ist kraeftiger hinterlegt und
        // umrandet.
        Row {
          id: chipRow
          width: parent.width
          height: root.chipHeight
          spacing: Style.space(6)
          // Breite je Knopf = Inhalt + Polster; was an Kartenbreite uebrig
          // bleibt, wird gleichmaessig verteilt. Gleich breite Knoepfe liefen
          // ueber ("Terminals 2" passte nicht).
          //
          // Reicht die Breite auch so nicht (kleiner Schirm, wenige Spalten),
          // entfallen Zahlen und Punkte (compact). Gerechnet wird mit
          // FontMetrics statt mit den angezeigten Texten - sonst haengt die
          // Entscheidung an dem, was sie selbst ausblendet, und kippt hin und her.
          readonly property int chipPad: Style.space(10)
          readonly property int gap: Style.space(5)
          FontMetrics { id: labelFont; font.family: root.fontFamily; font.pixelSize: Style.font.bodySmall; font.bold: true }
          FontMetrics { id: countFont; font.family: root.fontFamily; font.pixelSize: Style.font.caption }
          function sumWidths(withCounts) {
            var vt = root.visibleTypes, sum = 0
            for (var i = 0; i < vt.length; i++) {
              // fett gemessen, damit der gewaehlte Knopf nicht ueberlaeuft
              sum += labelFont.advanceWidth(Types.label(vt[i])) + chipPad * 2
              if (withCounts) sum += countFont.advanceWidth(String(root.typeCounts[vt[i]] || 0)) + gap
              if (withCounts && vt[i] !== "all") sum += Style.space(7) + gap
            }
            return Math.round(sum) + spacing * Math.max(0, vt.length - 1)
          }
          readonly property bool compact: sumWidths(true) > width
          readonly property int extraWidth: {
            var n = root.visibleTypes.length
            return n > 0 ? Math.max(0, Math.floor((width - sumWidths(!compact)) / n)) : 0
          }

          Repeater {
            model: root.visibleTypes
            Rectangle {
              id: chip
              required property string modelData
              required property int index
              readonly property bool active: root.activeType === modelData
              readonly property color tone: modelData === "all" ? root.foreground : Types.color(modelData)
              width: chipContent.implicitWidth + chipRow.chipPad * 2 + chipRow.extraWidth
              height: chipRow.height
              radius: root.cornerRadius
              color: Qt.rgba(tone.r, tone.g, tone.b, active ? 0.28 : (chipMouse.containsMouse ? 0.14 : (chipRow.compact ? 0.12 : 0.07)))
              border.width: active ? Math.max(1, Style.space(1)) : 0
              border.color: Qt.rgba(tone.r, tone.g, tone.b, 0.75)

              Row {
                id: chipContent
                anchors.centerIn: parent
                spacing: chipRow.gap
                Rectangle {
                  visible: chip.modelData !== "all" && !chipRow.compact
                  width: Style.space(7); height: width; radius: width / 2
                  color: chip.tone
                  anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                  textFormat: Text.PlainText
                  text: Types.label(chip.modelData)
                  color: root.foreground
                  opacity: chip.active ? 1 : 0.8
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.bodySmall
                  font.bold: chip.active
                  anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                  visible: !chipRow.compact
                  textFormat: Text.PlainText
                  text: String(root.typeCounts[chip.modelData] || 0)
                  color: root.foreground
                  opacity: 0.45
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  anchors.verticalCenter: parent.verticalCenter
                }
              }

              MouseArea {
                id: chipMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: { root.setType(chip.modelData); keyCatcher.forceActiveFocus() }
              }
            }
          }
        }

        // Raster
        Item {
          width: parent.width
          // Die Column ueberspringt die unsichtbare MRU-Zeile samt Abstand.
          height: parent.height - root.headerHeight - root.chipHeight
            - (root.showRecent ? root.cellHeight + root.contentSpacing : 0) - root.contentSpacing * 2

          GridView {
            id: resultGrid
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: parent.height - root.indicatorHeight
            model: displayModel
            clip: true
            cellWidth: root.cellWidth
            cellHeight: root.cellHeight
            boundsBehavior: Flickable.StopAtBounds

            // Achtung: keine `required property label` usw. hier deklarieren -
            // das wuerde die gleichnamigen AppCell-Properties verschatten und
            // die Zelle bliebe leer. Stattdessen ueber `model` binden.
            delegate: AppCell {
              required property int index
              required property var model

              label: model.label
              iconSource: model.iconSource
              needsMonogram: model.needsMonogram
              mono: model.mono
              hue: model.hue
              typeColor: model.typeKey ? Types.color(model.typeKey) : "transparent"

              width: root.cellWidth
              height: root.cellHeight
              iconSize: root.iconSize
              iconPad: root.iconPad
              foreground: root.foreground
              selectedBackground: root.selectedBackground
              fontFamily: root.fontFamily
              hasCursor: root.cursorActive && index === root.selectedIndex
              onHovered: { root.cursorActive = true; root.selectedIndex = index }
              onActivated: { root.cursorActive = true; root.selectedIndex = index; root.activateIndex(index) }
            }
          }

          Text {
            anchors.horizontalCenter: parent.horizontalCenter
            y: Math.round((resultGrid.height - height) / 2)
            visible: displayModel.count === 0
            textFormat: Text.PlainText
            text: root.filterText
              ? "Keine Treffer für „" + root.filterText + "“" + (root.activeType === "all" ? "" : " in " + Types.label(root.activeType))
              : "Keine Programme vom Typ " + Types.label(root.activeType)
            color: root.foreground
            opacity: 0.7
            font.family: root.fontFamily
            font.pixelSize: Style.font.title
          }

          // Drei Punkte am unteren Rand, solange unterhalb des sichtbaren
          // Ausschnitts noch Apps liegen - wie im macOS-Vorbild. Am Ende der
          // Liste (und wenn alles ohnehin passt) verschwinden sie.
          Row {
            id: moreDots
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Math.round((root.indicatorHeight - height) / 2)
            spacing: Style.space(7)

            readonly property bool hasMore: resultGrid.contentHeight > resultGrid.height + 1
              && !resultGrid.atYEnd
            opacity: hasMore ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: 120 } }

            Repeater {
              model: 3
              Rectangle {
                width: Style.space(5)
                height: width
                radius: width / 2
                color: root.foreground
                opacity: 0.45
              }
            }
          }
        }
      }
    }
  }
}
