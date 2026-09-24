import Quickshell
import Quickshell.Io
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

Item {
  id: root

  property var shell: null
  property var manifest: null
  readonly property var appLibrary: root.shell ? root.shell.appLibrary : null

  property bool opened: false
  property string filterText: ""
  property int selectedIndex: 0
  property bool cursorActive: false

  // Gewaehlter Typ ("all" = keine Einschraenkung) und die Zahl der Programme
  // je Typ - Knoepfe ohne Programme werden ausgeblendet.
  property string activeType: "all"
  property var typeCounts: ({})
  readonly property var visibleTypes: {
    var out = []
    for (var i = 0; i < Types.BUTTONS.length; i++) {
      var t = Types.BUTTONS[i]
      if (t === "all" || (root.typeCounts[t] || 0) > 0) out.push(t)
    }
    return out
  }

  // Klassifikation je Desktop-ID, gilt bis sich die App-Liste aendert. Spart
  // bei jedem Tastendruck das erneute Klassifizieren aller Programme.
  property var typeCache: ({})
  // Zuletzt aufgebaute Zeilen je App-ID - Quelle fuer die MRU-Zeile.
  property var itemsById: ({})

  // Zuletzt gestartete App-IDs, neueste zuerst.
  property var recentIds: []
  readonly property string statePath: Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")
  readonly property string recentPath: statePath + "/radialmesh-launchpad/recent.json"
  // Gilt die erste Rasterzeile als MRU-Zeile? Nur ohne Suchtext.
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
        root.recentIds = v.filter(function(x) { return typeof x === "string" }).slice(0, root.columns)
        recentFile.setText(JSON.stringify(root.recentIds))
        if (root.opened) root.rebuildRecent()
      } catch (e) {}
    }
  }

  function rememberLaunch(appId) {
    var next = [appId]
    for (var i = 0; i < root.recentIds.length && next.length < root.columns; i++)
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

  // Raster: 6 Spalten, 6 sichtbare Zeilen. Die Karte ist so breit wie das
  // rofi-Vorbild (rund 61 % der Bildschirmbreite); die Zellbreite ergibt sich
  // aus dem verfuegbaren Platz, damit die Spaltenzahl garantiert aufgeht -
  // Style.space() skaliert mit der Theme-Schrift, feste Werte gehen nicht auf.
  //
  // Die Karte behaelt die Masse der 7x7-Fassung: 7 * 72 = 504 verteilt sich
  // jetzt auf 6 * 78 Rasterzeilen plus 36 fuer die Punkteleiste. Das Icon
  // waechst mit der Zeilenhoehe (40 * 78/72), die Beschriftung nicht - so
  // entsteht der zusaetzliche Weissraum.
  property int columns: 6
  property int visibleRows: 6
  // Icon kleiner als im Original (44), damit die Typflaeche darum herum
  // in dieselbe Zeilenhoehe passt.
  property int iconSize: Style.space(38)
  property int iconPad: Style.space(8)
  property int cellHeight: Style.space(78)
  // Streifen unter dem Raster fuer die "mehr da"-Punkte.
  property int indicatorHeight: Style.space(36)
  property int contentMargin: Style.spacing.panelPadding
  property int headerHeight: Math.max(Style.space(34), Style.font.title + Style.spacing.controlPaddingY * 2)
  property int contentSpacing: Style.spacing.md
  property int chipHeight: Math.max(Style.space(28), Style.font.body + Style.spacing.controlPaddingY * 2)

  property int cardWidth: Math.round(panel.width * 0.615)
  property int cellWidth: Math.floor(resultGrid.width / columns)
  // Hoehe so, dass genau visibleRows Reihen sichtbar sind - kein Rest,
  // kein Anschnitt. contentTopInset/BottomInset der BorderSurface enthalten
  // Rahmen UND Padding bereits.
  property int cardHeight: Math.min(panel.height - Style.gapsOut * 2,
    card.contentTopInset + card.contentBottomInset
    + headerHeight + contentSpacing + (showRecent ? cellHeight : 0) + contentSpacing
    + chipHeight + contentSpacing
    + visibleRows * cellHeight + indicatorHeight)

  function open(payloadJson) {
    var payload = ({})
    try { payload = JSON.parse(payloadJson || "{}") || ({}) } catch (e) { payload = ({}) }
    root.opened = true
    root.filterText = ""
    root.activeType = (payload.type && Types.LABELS[payload.type]) ? String(payload.type) : "all"
    root.selectedIndex = 0
    root.cursorActive = false
    if (root.appLibrary) root.appLibrary.refreshIcons()
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
      root.shell.hide((root.manifest && root.manifest.id) || "community.radialmesh-launchpad")
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
    if (!root.appLibrary) return
    var all = root.appLibrary.sortedEntries("")
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
    for (var r = 0; r < root.recentIds.length && recentModel.count < root.columns; r++) {
      var hit = root.itemsById[root.recentIds[r]]
      if (hit) recentModel.append(hit)
    }
  }

  function rebuildDisplay() {
    displayModel.clear()
    if (!root.appLibrary) return
    // sortedEntries liefert Wrapper { entry, score, key, name } - der
    // eigentliche Desktop-Eintrag steckt in .entry.
    var rows = root.appLibrary.sortedEntries(root.filterText)
    var items = []
    for (var i = 0; i < rows.length; i++) {
      var e = rows[i].entry
      var types = root.typesOf(e)
      var src = root.appLibrary.iconSource(e.icon)
      items.push({
        typeKey: types[0] || "gui",
        // Mit Kommas umrahmt, damit indexOf(",tui,") eindeutig trifft;
        // ListModel speichert keine Arrays.
        typeList: "," + types.join(",") + ",",
        appId: String(e.id || ""),
        label: root.appLibrary.entryName(e),
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
      for (var k = 0; k < items.length; k++) { items[k].filler = false; byId[items[k].appId] = items[k] }
      root.itemsById = byId
    }
    root.rebuildRecent()

    for (var j = 0; j < items.length; j++) {
      if (root.activeType !== "all" && items[j].typeList.indexOf("," + root.activeType + ",") < 0) continue
      items[j].filler = false
      displayModel.append(items[j])
    }
    if (displayModel.count === 0) selectedIndex = 0
    else if (selectedIndex >= displayModel.count) selectedIndex = displayModel.count - 1
    Qt.callLater(function() {
      if (displayModel.count > 0) resultGrid.positionViewAtIndex(root.selectedIndex, GridView.Contain)
    })
  }

  function isFiller(i) {
    return i >= 0 && i < displayModel.count && displayModel.get(i).filler === true
  }

  // Erster waehlbarer Index (bei leerer MRU-Zeile ist das Zeile 2).
  function firstSelectable() {
    for (var i = 0; i < displayModel.count; i++) if (!isFiller(i)) return i
    return 0
  }

  function select(delta) {
    if (displayModel.count === 0) return
    if (!cursorActive) {
      cursorActive = true
      selectedIndex = delta < 0 ? displayModel.count - 1 : firstSelectable()
    } else {
      var n = selectedIndex
      do { n = (n + delta + displayModel.count) % displayModel.count } while (isFiller(n) && n !== selectedIndex)
      selectedIndex = n
    }
    resultGrid.positionViewAtIndex(selectedIndex, GridView.Contain)
  }

  function selectRow(delta) {
    if (displayModel.count === 0) return
    if (!cursorActive) {
      cursorActive = true
      selectedIndex = delta < 0 ? displayModel.count - 1 : firstSelectable()
    } else {
      var n = selectedIndex + delta * columns
      if (n < 0) n = 0
      if (n >= displayModel.count) n = displayModel.count - 1
      // In der MRU-Zeile auf einer Luecke gelandet: nach links zur letzten
      // belegten Zelle ruecken; ist die Zeile leer, bleibt der Cursor.
      while (n > 0 && isFiller(n)) n--
      if (isFiller(n)) return
      selectedIndex = n
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
    if (row.filler) return
    root.dismiss()
    root.rememberLaunch(row.appId)
    if (root.appLibrary) root.appLibrary.launch(row.appId, row.label)
  }

  function activateRecent(index) {
    if (index < 0 || index >= recentModel.count) return
    var row = recentModel.get(index)
    if (row.filler || !row.appId) return
    root.dismiss()
    root.rememberLaunch(row.appId)
    if (root.appLibrary) root.appLibrary.launch(row.appId, row.label)
  }

  ListModel { id: displayModel }
  ListModel { id: recentModel }

  Connections {
    target: root.appLibrary
    function onAppsChanged() {
      root.typeCache = ({})
      if (root.opened) { root.refreshCounts(); root.rebuildDisplay() }
    }
  }

  PanelWindow {
    id: panel
    visible: root.opened
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
            else if (displayModel.count > 0) root.activateIndex(root.firstSelectable())
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
              filler: model.filler
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
          readonly property int chipPad: Style.space(10)
          property var naturalWidths: []
          readonly property int extraWidth: {
            var n = root.visibleTypes.length, sum = 0
            for (var i = 0; i < n; i++) sum += (naturalWidths[i] || 0) + chipPad * 2
            return n > 0 ? Math.max(0, Math.floor((width - sum - spacing * (n - 1)) / n)) : 0
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
              color: Qt.rgba(tone.r, tone.g, tone.b, active ? 0.28 : (chipMouse.containsMouse ? 0.14 : 0.07))
              border.width: active ? Math.max(1, Style.space(1)) : 0
              border.color: Qt.rgba(tone.r, tone.g, tone.b, 0.75)

              Row {
                id: chipContent
                anchors.centerIn: parent
                spacing: Style.space(5)
                onImplicitWidthChanged: {
                  var w = chipRow.naturalWidths.slice()
                  w[chip.index] = implicitWidth
                  chipRow.naturalWidths = w
                }
                Rectangle {
                  visible: chip.modelData !== "all"
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
          height: parent.height - root.headerHeight - root.chipHeight
            - (root.showRecent ? root.cellHeight : 0) - root.contentSpacing * 3

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
              filler: model.filler
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
