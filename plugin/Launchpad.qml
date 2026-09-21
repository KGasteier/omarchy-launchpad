import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import qs.Commons
import qs.Ui
import "Monogram.js" as Monogram

// Launchpad: App-Raster im Stil des macOS-Launchpads.
//
// Aufbau nach dem Vorbild des Emojis-Overlays: ein Layer-Shell-Fenster ueber
// dem ganzen Bildschirm, darin eine Karte mit Suchfeld und GridView.
// Die App-Liste, Icon-Aufloesung und das Starten uebernimmt der Shell-Dienst
// shell.appLibrary - hier steckt nur Darstellung, Suche und Tastatur.
//
// Zeile 1 zeigt die zuletzt gestarteten Apps (bis zu `columns` Stueck, Luecken
// als leere Zellen), darunter durch eine Linie getrennt alle Apps alphabetisch.
// Sobald gesucht wird, entfaellt die MRU-Zeile. Der MRU-Stand liegt als JSON
// in ~/.local/state/omarchy-launchpad/recent.json.

Item {
  id: root

  property var shell: null
  property var manifest: null
  readonly property var appLibrary: root.shell ? root.shell.appLibrary : null

  property bool opened: false
  property string filterText: ""
  property int selectedIndex: 0
  property bool cursorActive: false

  // Zuletzt gestartete App-IDs, neueste zuerst.
  property var recentIds: []
  readonly property string statePath: Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")
  readonly property string recentPath: statePath + "/omarchy-launchpad/recent.json"
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
      // reload() liefert asynchron - das Raster ggf. nachziehen.
      if (root.opened && root.showRecent) root.rebuildDisplay()
    }
    onLoadFailed: root.recentIds = []
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
  property int iconSize: Style.space(44)
  property int cellHeight: Style.space(78)
  // Streifen unter dem Raster fuer die "mehr da"-Punkte.
  property int indicatorHeight: Style.space(36)
  property int contentMargin: Style.spacing.panelPadding
  property int headerHeight: Math.max(Style.space(34), Style.font.title + Style.spacing.controlPaddingY * 2)
  property int contentSpacing: Style.spacing.md

  property int cardWidth: Math.round(panel.width * 0.615)
  property int cellWidth: Math.floor(resultGrid.width / columns)
  // Hoehe so, dass genau visibleRows Reihen sichtbar sind - kein Rest,
  // kein Anschnitt. contentTopInset/BottomInset der BorderSurface enthalten
  // Rahmen UND Padding bereits.
  property int cardHeight: Math.min(panel.height - Style.gapsOut * 2,
    card.contentTopInset + card.contentBottomInset
    + headerHeight + contentSpacing + visibleRows * cellHeight + indicatorHeight)

  function open(payloadJson) {
    root.opened = true
    root.filterText = ""
    root.selectedIndex = 0
    root.cursorActive = false
    if (root.appLibrary) root.appLibrary.refreshIcons()
    recentFile.reload()
    root.rebuildDisplay()
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  function close() {
    root.opened = false
  }

  function dismiss() {
    root.opened = false
    if (root.shell && typeof root.shell.hide === "function")
      root.shell.hide((root.manifest && root.manifest.id) || "community.launchpad")
  }

  function toggle() {
    if (root.opened) root.dismiss()
    else root.open("{}")
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
      var src = root.appLibrary.iconSource(e.icon)
      items.push({
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

    // MRU-Zeile: Eintraege in Reihenfolge der recentIds, Rest mit leeren
    // Zellen aufgefuellt, damit die alphabetische Liste stets in Zeile 2
    // beginnt.
    if (root.showRecent) {
      var byId = {}
      for (var k = 0; k < items.length; k++) byId[items[k].appId] = items[k]
      var n = 0
      for (var r = 0; r < root.recentIds.length && n < root.columns; r++) {
        var hit = byId[root.recentIds[r]]
        if (!hit) continue   // deinstalliert - stillschweigend ueberspringen
        var copy = JSON.parse(JSON.stringify(hit)); copy.filler = false
        displayModel.append(copy); n++
      }
      for (; n < root.columns; n++)
        displayModel.append({ appId: "", label: "", iconKey: "", iconSource: "", needsMonogram: false, mono: "", hue: 0, filler: true })
    }
    for (var j = 0; j < items.length; j++) { items[j].filler = false; displayModel.append(items[j]) }
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

  function activateIndex(index) {
    if (index < 0 || index >= displayModel.count) return
    var row = displayModel.get(index)
    if (row.filler) return
    root.dismiss()
    root.rememberLaunch(row.appId)
    if (root.appLibrary) root.appLibrary.launch(row.appId, row.label)
  }

  ListModel { id: displayModel }

  Connections {
    target: root.appLibrary
    function onAppsChanged() { if (root.opened) root.rebuildDisplay() }
  }

  PanelWindow {
    id: panel
    visible: root.opened
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    WlrLayershell.namespace: "omarchy-launchpad"
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
            if (root.filterText) root.setFilter("")
            else root.dismiss()
            event.accepted = true
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
              text: root.filterText || "Suchen…"
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

        // Raster
        Item {
          width: parent.width
          height: parent.height - root.headerHeight - root.contentSpacing

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

              width: root.cellWidth
              height: root.cellHeight
              iconSize: root.iconSize
              foreground: root.foreground
              selectedBackground: root.selectedBackground
              fontFamily: root.fontFamily
              hasCursor: root.cursorActive && index === root.selectedIndex
              onHovered: { root.cursorActive = true; root.selectedIndex = index }
              onActivated: { root.cursorActive = true; root.selectedIndex = index; root.activateIndex(index) }
            }
          }

          // Trennlinie unter der MRU-Zeile - scrollt mit dem Raster.
          Rectangle {
            visible: root.showRecent && displayModel.count > root.columns
            x: Style.space(8)
            width: parent.width - Style.space(16)
            height: 1
            y: root.cellHeight - resultGrid.contentY - 1
            color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.13)
          }

          Text {
            anchors.horizontalCenter: parent.horizontalCenter
            y: Math.round((resultGrid.height - height) / 2)
            visible: displayModel.count === 0
            textFormat: Text.PlainText
            text: "Keine Treffer für „" + root.filterText + "“"
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
