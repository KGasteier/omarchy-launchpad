import QtQuick
import Quickshell
import qs.Commons

// Eine Rasterzelle: Icon (oder Monogramm-Kachel) mit Beschriftung.
// Wird in der Zeile "zuletzt benutzt" und im alphabetischen Raster verwendet.
// Hinter dem Icon liegt eine dezente Flaeche in der Typfarbe des Programms
// (Types.js) - dieselbe Farbe wie seine Karte im Radial Mesh.
Rectangle {
  id: cell

  property string label: ""
  property string iconSource: ""
  property bool needsMonogram: false
  property string mono: ""
  property int hue: 0
  property bool filler: false          // leere Platzhalterzelle, nicht waehlbar
  property bool hasCursor: false
  property int iconSize: 40
  property int iconPad: 8               // Rand der Typflaeche um das Icon
  property color typeColor: "transparent"
  property color foreground: "white"
  property color selectedBackground: "gray"
  property string fontFamily: "sans-serif"

  signal hovered()
  signal activated()

  radius: Style.cornerRadius
  color: hasCursor && !filler ? selectedBackground : "transparent"

  Column {
    anchors.centerIn: parent
    spacing: Style.space(4)
    width: parent.width
    visible: !cell.filler

    Rectangle {
      id: typeTile
      width: cell.iconSize + cell.iconPad * 2
      height: width
      anchors.horizontalCenter: parent.horizontalCenter
      radius: Math.round(width * 0.24)
      // Dezent, aber klar sichtbar: gleichmaessig getoente Flaeche ohne
      // abgesetzte Linie. Unter dem Cursor kraeftiger, damit die Farbe auch
      // auf der Auswahl traegt.
      color: Qt.rgba(cell.typeColor.r, cell.typeColor.g, cell.typeColor.b, cell.hasCursor ? 0.45 : 0.30)

      Item {
        width: cell.iconSize
        height: cell.iconSize
        anchors.centerIn: parent

        Image {
          anchors.fill: parent
          visible: !cell.needsMonogram
          fillMode: Image.PreserveAspectFit
          sourceSize.width: width * Screen.devicePixelRatio
          sourceSize.height: height * Screen.devicePixelRatio
          source: cell.needsMonogram ? "" : cell.iconSource
          asynchronous: true
        }

        // Monogramm-Kachel: Farbverlauf aus dem Icon-Namen, wie die
        // SVG-Platzhalter der rofi-Fassung.
        Rectangle {
          anchors.fill: parent
          anchors.margins: Math.round(parent.width * 0.05)
          visible: cell.needsMonogram
          radius: width * 0.23
          gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.hsla(cell.hue / 360, 0.42, 0.46, 1) }
            GradientStop { position: 1.0; color: Qt.hsla(cell.hue / 360, 0.46, 0.32, 1) }
          }
          border.width: 1
          border.color: Qt.rgba(1, 1, 1, 0.16)

          Text {
            anchors.centerIn: parent
            text: cell.mono
            color: Qt.rgba(1, 1, 1, 0.97)
            font.family: "sans-serif"   // Monogramme in Proportionalschrift wie das SVG-Vorbild
            font.weight: Font.Black
            font.pixelSize: Math.round(parent.height * (cell.mono.length === 1 ? 0.5 : 0.4))
            font.letterSpacing: -0.5
          }
        }
      }
    }

    Text {
      textFormat: Text.PlainText
      text: cell.label
      color: cell.foreground
      font.family: cell.fontFamily
      font.pixelSize: Style.font.bodySmall
      elide: Text.ElideRight
      horizontalAlignment: Text.AlignHCenter
      width: parent.width - Style.space(8)
      anchors.horizontalCenter: parent.horizontalCenter
    }
  }

  MouseArea {
    anchors.fill: parent
    enabled: !cell.filler
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onContainsMouseChanged: if (containsMouse) cell.hovered()
    onClicked: cell.activated()
  }
}
