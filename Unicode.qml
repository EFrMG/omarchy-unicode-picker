import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import qs.Commons
import qs.Ui
import "UnicodeSearch.js" as UnicodeSearch

Item {
  id: root

  property string omarchyPath: Quickshell.env("OMARCHY_PATH")
  property var shell: null
  property var manifest: null
  // Derive the plugin directory from the loaded QML file's own URL rather than from manifest.__sourceDir, which the host strips for third-party plugins
  readonly property url pluginDir: Qt.resolvedUrl(".")

  property bool opened: false
  property string filterText: ""
  property int selectedIndex: 0
  property bool cursorActive: false
  // Hover only owns the selection once the pointer has actually moved
  property bool pointerNavigating: false
  property var characters: []
  property var filteredCharacters: []

  // Entries carry a single searchable "k" field shaped "<name> u+<hex>"
  // Split the codepoint back off so it can be cased like a codepoint
  readonly property string selectedName: {
    if (!root.cursorActive) return ""

    var list = root.filteredCharacters
    if (!list || root.selectedIndex < 0 || root.selectedIndex >= list.length) return ""

    var keywords = String((list[root.selectedIndex] && list[root.selectedIndex].k) || "")
    var cut = keywords.lastIndexOf(" u+")
    if (cut < 0) return keywords

    return keywords.substring(0, cut) + "  " + keywords.substring(cut + 1).toUpperCase()
  }

  // Shares the [menu] surface tokens themes that style the menu
  // Selected-cell colors composed in the singleton so consumers drop them straight into Rectangle bindings
  property color background: Color.menu.background
  property color foreground: Color.menu.text
  property color border: Color.menu.border
  property var borderSpec: Border.surfaceSpec("menu", "border", border, Math.max(1, Style.space(2)))
  property color scrim: Color.menu.scrim
  property color selectedBackground: Color.menu.selectedBackground
  property color selectedText: Color.menu.selectedText
  readonly property int cornerRadius: Style.cornerRadius
  property string fontFamily: Style.font.menuFamily
  property int contentMargin: Style.spacing.panelPadding
  // Header stacks the query on top of the selected character's name; it reserves a line for the name even when nothing is selected keeping the grid below from shifting as the caption comes and goes
  property int nameRowHeight: Math.round(Style.font.bodySmall * 1.5) + Style.spacing.xxs
  property int headerHeight: Math.max(Style.space(34), Style.font.title + Style.spacing.controlPaddingY * 2) + root.nameRowHeight
  property int contentSpacing: Style.spacing.md
  property int cardWidth: Math.min(Style.space(400), panel.width - Style.gapsOut * 2)
  property int cardHeight: Math.min(Style.space(500), panel.height - Style.gapsOut * 2)

  property int cellWidth: Math.max(Style.space(44), Style.font.display + Style.spacing.md)
  property int cellHeight: Math.max(Style.space(44), Style.font.display + Style.spacing.md)
  property int columns: Math.floor((cardWidth - contentMargin * 2) / cellWidth)

  function open(payloadJson) {
    root.opened = true
    root.filterText = ""
    root.selectedIndex = 0
    root.cursorActive = true
    root.pointerNavigating = false
    root.rebuildDisplay()
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  function close() {
    root.opened = false
  }

  function dismiss() {
    root.opened = false
    if (root.shell && typeof root.shell.hide === "function")
      root.shell.hide((root.manifest && root.manifest.id) || "omarchy-unicode-picker")
  }

  function toggle() {
    if (root.opened) root.dismiss()
    else root.open("{}")
  }

  function loadCharacters(raw) {
    root.characters = UnicodeSearch.parseEntries(raw)
    if (root.opened) root.rebuildDisplay()
  }

  function rebuildDisplay() {
    // Capped at 1000: rendering a filtered result set is cheap regardless of its size but populating displayModel below is a plain loop of ListModel.append() calls, one per row, and that cost is not virtualized, it runs in full on every keystroke and every open
    // Search narrows past 1000 almost immediately in practice
    var out = UnicodeSearch.filterEntries(root.characters, root.filterText, 1000)
    root.filteredCharacters = out

    displayModel.clear()
    for (var j = 0; j < out.length; j++) {
      displayModel.append({ char: out[j].e, index: j })
    }

    if (displayModel.count === 0) selectedIndex = 0
    else if (selectedIndex >= displayModel.count) selectedIndex = displayModel.count - 1
    else if (selectedIndex < 0) selectedIndex = 0
    cursorActive = displayModel.count > 0

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

      resultGrid.positionViewAtIndex(selectedIndex, GridView.Contain)
      return
    }

    var newIndex = selectedIndex + delta * columns
    if (newIndex < 0) newIndex = 0

    if (newIndex >= displayModel.count) newIndex = displayModel.count - 1

    selectedIndex = newIndex
    resultGrid.positionViewAtIndex(selectedIndex, GridView.Contain)
  }

  function selectPage(delta) {
    if (displayModel.count === 0) return

    if (!cursorActive) {
      cursorActive = true
      selectedIndex = delta < 0 ? displayModel.count - 1 : 0

      resultGrid.positionViewAtIndex(selectedIndex, GridView.Contain)
      return
    }
    var visibleRows = Math.max(1, Math.floor(resultGrid.height / cellHeight))
    var newIndex = selectedIndex + delta * columns * visibleRows
    if (newIndex < 0) newIndex = 0

    if (newIndex >= displayModel.count) newIndex = displayModel.count - 1

    selectedIndex = newIndex
    resultGrid.positionViewAtIndex(selectedIndex, GridView.Contain)
  }

  function setFilter(nextFilter) {
    root.filterText = nextFilter
    root.selectedIndex = 0
    root.cursorActive = true
    // A new result set invalidates whatever the pointer was resting on
    root.pointerNavigating = false

    root.rebuildDisplay()
  }

  // Hover/click selection, ignoring indices the current model no longer holds
  function selectFromPointer(index) {
    if (index < 0 || index >= displayModel.count) return

    root.cursorActive = true
    root.selectedIndex = index
  }

  function activateIndex(index) {
    if (displayModel.count === 0) return

    // Clamp rather than bail: a stale index must never turn Enter into a no-op
    if (index < 0) index = 0
    else if (index >= displayModel.count) index = displayModel.count - 1

    var row = displayModel.get(index)
    root.applySelected(row.char)
  }

  function applySelected(char) {
    if (!char) return

    root.dismiss()
    // Plugin-local rather than omarchy-clipboard-paste-text: that one pipes to a bare wl-copy, which infers application/octet-stream for a single ASCII byte and leaves the clipboard with no text type for anything to paste
    var scriptUrl = Qt.resolvedUrl("omarchy-unicode-insert")
    var scriptPath = decodeURIComponent(scriptUrl.toString().replace(/^file:\/\//, ""))
    Quickshell.execDetached([scriptPath, char])
  }

  ListModel { id: displayModel }

  FileView {
    // Resolved relative to the QML file
    // It supports % in URL
    path: decodeURIComponent(Qt.resolvedUrl("unicode.json").toString())
    onLoaded: root.loadCharacters(text())
  }
  PanelWindow {
    id: panel
    visible: root.opened
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    WlrLayershell.namespace: "omarchy-unicode"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    exclusionMode: ExclusionMode.Ignore

    Rectangle {
      anchors.fill: parent
      color: root.scrim
    }

    MouseArea {
      anchors.fill: parent
      onClicked: root.dismiss()
    }

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
          } else if (event.key === Qt.Key_Left || (event.key === Qt.Key_H && (event.modifiers & Qt.ControlModifier))) {
            root.select(-1)
            event.accepted = true
          } else if (event.key === Qt.Key_Right || (event.key === Qt.Key_L && (event.modifiers & Qt.ControlModifier))) {
            root.select(1)
            event.accepted = true
          } else if (event.key === Qt.Key_Up || (event.key === Qt.Key_K && (event.modifiers & Qt.ControlModifier))) {
            root.selectRow(-1)
            event.accepted = true
          } else if (event.key === Qt.Key_Down || (event.key === Qt.Key_J && (event.modifiers & Qt.ControlModifier))) {
            root.selectRow(1)
            event.accepted = true
          } else if (event.key === Qt.Key_PageUp) {
            root.selectPage(-1)
            event.accepted = true
          } else if (event.key === Qt.Key_PageDown) {
            root.selectPage(1)
            event.accepted = true
          } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            if (root.cursorActive) root.activateIndex(root.selectedIndex)
            else if (displayModel.count > 0) root.cursorActive = true
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

        Rectangle {
          width: parent.width
          height: root.headerHeight
          radius: root.cornerRadius
          color: "transparent"

          Column {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.spacing.xxs

            Text {
              width: parent.width
              text: root.filterText || "Search Unicode…"
              color: root.foreground
              opacity: root.filterText ? 1 : 0.58
              font.family: root.fontFamily
              font.pixelSize: Style.font.heading // Search input font size
              elide: Text.ElideRight
            }

            Text {
              width: parent.width
              text: root.selectedName
              color: root.foreground
              opacity: 0.62
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall // Char description font size
              elide: Text.ElideRight
            }
          }
        }

        Item {
          width: parent.width
          height: parent.height - root.headerHeight - root.contentSpacing

          GridView {
            id: resultGrid
            anchors.fill: parent
            model: displayModel
            clip: true
            cellWidth: root.cellWidth
            cellHeight: root.cellHeight
            boundsBehavior: Flickable.StopAtBounds

            delegate: Rectangle {
              required property int index
              required property string char

              readonly property bool hasCursor: root.cursorActive && index === root.selectedIndex

              width: root.cellWidth
              height: root.cellHeight
              radius: root.cornerRadius
              color: hasCursor ? root.selectedBackground : "transparent"

              Text {
                text: parent.char
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.display
                anchors.centerIn: parent
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
              }

              MouseArea {
                id: mouseArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                // Real pointer movement hands hover control back to the mouse; a delegate appearing under a still cursor must not
                onPositionChanged: {
                  root.pointerNavigating = true
                  root.selectFromPointer(index)
                }
                onContainsMouseChanged: if (containsMouse && root.pointerNavigating) root.selectFromPointer(index)
                onClicked: {
                  root.selectFromPointer(index)
                  root.activateIndex(index)
                }
              }
            }
          }

          Column {
            anchors.centerIn: parent
            spacing: Style.space(8)
            visible: displayModel.count === 0

            Text {
              text: "󰈉"
              color: root.selectedText
              opacity: 0.8
              font.family: root.fontFamily
              font.pixelSize: Style.font.displayLarge
              horizontalAlignment: Text.AlignHCenter
              width: parent.width
            }

            Text {
              text: root.filterText
                ? "No matches for “" + root.filterText + "”"
                : "No characters loaded"
              color: root.foreground
              opacity: 0.7
              font.family: root.fontFamily
              font.pixelSize: Style.font.title
              horizontalAlignment: Text.AlignHCenter
              width: parent.width
            }
          }
        }
      }
    }
  }
}
