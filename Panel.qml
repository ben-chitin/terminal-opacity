import QtQuick
import QtQuick.Controls
import Quickshell
import qs.Ui
import qs.Commons
import qs.Commons as Commons

// The bar icon and its panel: a slider, and the list of what it applies to.
// Everything it shows and changes belongs to the plugin's service.
Panel {
  id: root
  moduleName: "bhj.terminal-opacity"
  ipcTarget: "bhj.terminal-opacity"

  readonly property var service: bar?.shell?.serviceFor("bhj.terminal-opacity") ?? null
  readonly property var windows: service ? service.windows : []
  readonly property int defaultOpacity: service ? service.defaultOpacity : 100
  readonly property bool defaultSet: service ? service.defaultSet : false
  readonly property bool defaultBlur: service ? service.blur : false
  // The blur of whatever the panel is pointed at.
  readonly property bool blur: selectedWindow ? selectedWindow.blur : defaultBlur
  readonly property bool cells: service ? service.cells : false
  readonly property bool mixedBlur: {
    for (var i = 0; i < windows.length; i++) if (windows[i].blur !== defaultBlur) return true
    return false
  }
  readonly property bool blurAvailable: service ? service.blurAvailable : false
  // Blur is wanted for what the panel points at, but Hyprland blurs nothing.
  readonly property bool needsGlassy: (blur || defaultBlur) && !blurAvailable
  readonly property bool switchingGlassy: service ? service.switchingGlassy : false
  // Foot windows that started before the painted-backgrounds choice last
  // changed, and so still draw the old one.
  readonly property int staleCount: {
    var n = 0
    for (var i = 0; i < windows.length; i++) if (windows[i].stale) n++
    return n
  }

  readonly property string allAddress: "*"
  readonly property string resetAddress: "!reset"

  property string selectedAddress: allAddress
  property int shownPercent: 100
  property real wheelAccumulator: 0

  property string focusSection: "slider"
  property int selectedIndex: -1
  property bool cursorActive: false

  readonly property bool anyOverride: {
    for (var i = 0; i < windows.length; i++) if (windows[i].override) return true
    return false
  }

  readonly property bool mixed: {
    for (var i = 1; i < windows.length; i++) if (windows[i].opacity !== windows[0].opacity) return true
    return false
  }

  readonly property var sortedWindows: {
    var list = windows.slice()
    list.sort(function(a, b) {
      if (a.focused !== b.focused) return a.focused ? -1 : 1
      return a.title < b.title ? -1 : (a.title > b.title ? 1 : 0)
    })
    return list
  }

  readonly property var rows: {
    var list = [{
      address: allAddress,
      title: "All terminals",
      detail: windows.length === 0 ? "What every new terminal opens with"
            : mixed ? "They differ. The slider sets every one, and new ones"
            : "Every open terminal, and every new one",
      opacity: defaultOpacity,
      solidText: true
    }]
    for (var i = 0; i < sortedWindows.length; i++) {
      var w = sortedWindows[i]
      var parts = [w.terminal]
      if (w.stale) parts.push("reopen to apply")
      if (w.workspace !== "") parts.push("workspace " + w.workspace)
      if (w.focused) parts.push("focused")
      if (w.fullscreen) parts.push("fullscreen")
      if (w.blur) parts.push("blurred")
      if (!w.solidText) parts.push("fades text too")
      list.push({
        address: w.address, title: w.title, detail: parts.join(" · "),
        opacity: w.opacity, solidText: w.solidText
      })
    }
    if (defaultSet || anyOverride) {
      list.push({
        address: resetAddress,
        title: "Follow the theme again",
        detail: "Forget the opacity saved here",
        opacity: -1,
        solidText: true
      })
    }
    return list
  }

  readonly property var selectedWindow: {
    for (var i = 0; i < windows.length; i++) {
      if (windows[i].address === selectedAddress) return windows[i]
    }
    return null
  }

  // A terminal that fades as a whole window is never taken to invisible.
  readonly property int minimum: selectedWindow && !selectedWindow.solidText ? 10 : 0

  readonly property string hint: {
    if (service && service.error !== "") return service.error
    if (service && service.note !== "") return service.note
    if (selectedAddress === allAddress) {
      if (windows.length === 0) return "No terminal is open. This sets what new ones open with."
      return "Every terminal, open or new. Text stays solid."
    }
    if (!selectedWindow) return ""
    if (!selectedWindow.solidText)
      return selectedWindow.terminal + " can't fade only its background, so the whole window fades, text too."
    if (selectedWindow.fullscreen && selectedWindow.emulator === "foot")
      return "Foot hides this while the window is fullscreen."
    if (selectedWindow.shared) return "This window and the others its process draws. Text stays solid."
    return "Just this window, until it closes. Text stays solid."
  }

  function opacityOf(address) {
    if (address === allAddress) return defaultOpacity
    for (var i = 0; i < windows.length; i++) {
      if (windows[i].address === address) return windows[i].opacity
    }
    return defaultOpacity
  }

  function target() {
    return selectedAddress === allAddress ? "all" : selectedAddress
  }

  function selectAddress(address) {
    if (address === resetAddress || address === selectedAddress) return
    selectedAddress = address
    if (!opacitySlider.dragging) shownPercent = opacityOf(address)
  }

  // What the service knows replaces what the slider shows, except mid-drag.
  function follow() {
    if (selectedAddress !== allAddress && !selectedWindow) selectedAddress = allAddress
    if (!opacitySlider.dragging) shownPercent = opacityOf(selectedAddress)
    clampCursor()
  }

  function preview(value) {
    shownPercent = Math.max(minimum, Math.min(100, Math.round(value)))
    if (service) service.preview(target(), shownPercent)
  }

  function commit(value) {
    shownPercent = Math.max(minimum, Math.min(100, Math.round(value)))
    if (service) service.commit(target(), shownPercent)
  }

  function adjust(delta) {
    commit(shownPercent + delta)
  }

  function reset() {
    selectedAddress = allAddress
    if (service) service.reset()
  }

  function toggleBlur() {
    if (service) service.setBlur(target(), !blur)
  }

  function toggleCells() {
    if (service) service.setCells(!cells)
  }

  function turnOnGlassy() {
    if (service && !switchingGlassy) service.turnOnGlassy()
  }

  // Top to bottom: the slider, the two switches (with the Glassy button
  // between them while Hyprland's blur is off), then the rows.
  function moveCursor(delta) {
    if (focusSection === "slider") {
      if (delta > 0) focusSection = "blur"
      return
    }
    if (focusSection === "blur") {
      focusSection = delta < 0 ? "slider" : (needsGlassy ? "glassy" : "cells")
      return
    }
    if (focusSection === "glassy") {
      focusSection = delta < 0 ? "blur" : "cells"
      return
    }
    if (focusSection === "cells") {
      if (delta < 0) {
        focusSection = needsGlassy ? "glassy" : "blur"
      } else if (rows.length) {
        focusSection = "rows"
        selectedIndex = 0
        selectAddress(rows[0].address)
      }
      return
    }
    var next = selectedIndex + delta
    if (next < 0) {
      focusSection = "cells"
      selectedIndex = -1
      return
    }
    if (next > rows.length - 1) return
    selectedIndex = next
    selectAddress(rows[next].address)
  }

  function clampCursor() {
    if (focusSection !== "rows") return
    if (!rows.length) {
      focusSection = "slider"
      selectedIndex = -1
      return
    }
    selectedIndex = Math.max(0, Math.min(rows.length - 1, selectedIndex))
  }

  function activate() {
    if (focusSection === "blur") {
      toggleBlur()
      return
    }
    if (focusSection === "cells") {
      toggleCells()
      return
    }
    if (focusSection === "glassy") {
      turnOnGlassy()
      return
    }
    if (focusSection !== "rows" || selectedIndex < 0 || selectedIndex >= rows.length) return
    // Moving up to the switch passes through "All terminals" and picks it, so
    // Enter on a row is how the keyboard flips the blur of that row.
    if (rows[selectedIndex].address === resetAddress) reset()
    else toggleBlur()
  }

  function ensureCursorVisible(item) {
    if (!item || !scrollArea) return
    var flick = scrollArea.contentItem
    if (!flick || flick.contentY === undefined) return
    var top = item.mapToItem(flick.contentItem || flick, 0, 0).y
    var bottom = top + (item.height || 0)
    var margin = 6
    if (top < flick.contentY + margin) flick.contentY = Math.max(0, top - margin)
    else if (bottom > flick.contentY + flick.height - margin) flick.contentY = bottom + margin - flick.height
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onWindowsChanged: follow()
  onNeedsGlassyChanged: if (!needsGlassy && focusSection === "glassy") focusSection = "blur"
  onDefaultOpacityChanged: follow()

  onOpenedChanged: {
    if (service) service.viewers += opened ? 1 : -1
    if (!opened) return
    selectedAddress = allAddress
    focusSection = "slider"
    selectedIndex = -1
    cursorActive = false
    shownPercent = opacityOf(allAddress)
    if (service) service.sync()
  }

  Component.onDestruction: if (opened && service) service.viewers -= 1

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: ""
    tooltipText: "Terminal opacity"
    onPressed: root.toggle()
    onWheelMoved: function(delta) {
      var wheel = Util.wheelSteps(root.wheelAccumulator, delta)
      root.wheelAccumulator = wheel.remainder
      if (wheel.steps !== 0 && root.service) root.service.nudge("focused", wheel.steps * 5)
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(380))
    contentHeight: panel.fittedContentHeight(panelColumn.implicitHeight, Style.space(520))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onMoveRequested: function(dx, dy) {
        if (!root.cursorActive) { root.cursorActive = true; return }
        if (dy !== 0) root.moveCursor(dy)
        else if (dx !== 0) root.adjust(dx * 5)
      }
      onActivateRequested: root.activate()
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      ScrollView {
        id: scrollArea
        anchors.fill: parent
        clip: true
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
        ScrollBar.vertical.policy: panelColumn.implicitHeight > height ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
        Binding {
          target: scrollArea.contentItem
          property: "interactive"
          value: panelColumn.implicitHeight > scrollArea.height
        }

        Column {
          id: panelColumn
          width: scrollArea.availableWidth
          spacing: Style.space(14)

          Item {
            width: parent.width
            implicitHeight: Math.max(heroIcon.implicitHeight, heroLabels.implicitHeight)

            Text {
              id: heroIcon
              textFormat: Text.PlainText
              text: ""
              color: root.bar.foreground
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.display
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
            }

            Column {
              id: heroLabels
              anchors.left: heroIcon.right
              anchors.leftMargin: Style.space(14)
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(2)

              Text {
                textFormat: Text.PlainText
                text: "Terminal opacity"
                color: root.bar.foreground
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.title
                font.bold: true
                elide: Text.ElideRight
                width: parent.width
              }

              Text {
                textFormat: Text.PlainText
                text: root.hint
                color: Qt.darker(root.bar.foreground, 1.4)
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.caption
                font.bold: true
                wrapMode: Text.WordWrap
                width: parent.width
              }
            }
          }

          PanelSeparator { foreground: root.bar.foreground }

          Column {
            width: parent.width
            spacing: Style.space(6)

            Item {
              width: parent.width
              implicitHeight: Math.max(sliderHeader.implicitHeight, percentLabel.implicitHeight)

              PanelSectionHeader {
                id: sliderHeader
                text: "BACKGROUND OPACITY"
                foreground: root.bar.foreground
                fontFamily: root.bar.fontFamily
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
              }

              Text {
                id: percentLabel
                textFormat: Text.PlainText
                text: Math.round(opacitySlider.dragging ? opacitySlider.liveValue : root.shownPercent) + "%"
                color: Qt.darker(root.bar.foreground, 1.4)
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.caption
                font.bold: true
                anchors.right: parent.right
                anchors.rightMargin: Style.space(6)
                anchors.verticalCenter: parent.verticalCenter
              }
            }

            CursorSurface {
              width: parent.width
              height: opacitySlider.implicitHeight + Style.spacing.controlGap
              hasCursor: root.cursorActive && root.focusSection === "slider"
              foreground: root.bar.foreground
              outline: true

              PanelSlider {
                id: opacitySlider
                bar: root.bar
                anchors.fill: parent
                anchors.leftMargin: Style.space(6)
                anchors.rightMargin: Style.space(6)
                minimum: root.minimum
                maximum: 100
                step: 5
                integer: true
                value: root.shownPercent
                onMoved: function(v) { root.preview(v) }
                onReleased: function(v) { root.commit(v) }
              }

              HoverHandler {
                onHoveredChanged: if (hovered) {
                  root.cursorActive = true
                  root.focusSection = "slider"
                  root.selectedIndex = -1
                }
              }
            }

            Text {
              width: parent.width
              textFormat: Text.PlainText
              text: root.minimum + "% clear  ·  100% solid"
              color: Qt.darker(root.bar.foreground, 1.55)
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.caption
              horizontalAlignment: Text.AlignHCenter
            }
          }

          Toggle {
            id: blurToggle
            width: parent.width
            label: "Blur what shows through"
            description: root.blur && !root.blurAvailable
              ? "Hyprland's blur is off, so nothing blurs yet. Turn it on below."
              : root.selectedWindow
                ? (root.blur ? "Frosted glass behind just this window, until it closes"
                             : "Just this window: what is behind shows through sharp")
              : root.mixedBlur
                ? "They differ. This sets every terminal, and new ones"
              : root.blur ? "Frosted glass behind every terminal, open or new"
              : "Every terminal: what is behind shows through sharp"
            checked: root.blur
            hasCursor: root.cursorActive && root.focusSection === "blur"
            foreground: root.bar.foreground
            fontFamily: root.bar.fontFamily
            onHasCursorChanged: if (hasCursor) root.ensureCursorVisible(blurToggle)
            onHovered: function(on) {
              if (!on) return
              root.cursorActive = true
              root.focusSection = "blur"
              root.selectedIndex = -1
            }
            onClicked: root.toggleBlur()
          }

          // Hyprland's blur is off by default in Omarchy, and nothing this
          // widget asks for can blur until it is on.
          BorderSurface {
            id: glassyButton
            readonly property bool hasCursor: root.cursorActive && root.focusSection === "glassy"
            readonly property bool hot: hasCursor || glassyMouse.containsMouse
            visible: root.needsGlassy
            width: parent.width
            implicitHeight: visible ? Math.max(54, glassyText.implicitHeight + Style.spacing.huge) : 0
            radius: Style.cornerRadius
            color: Style.controlFill(false, hot, root.bar.foreground, Commons.Color.accent)
            borderSpec: Border.controlSpec(hot ? "hover-cursor" : "normal", root.bar.foreground, Commons.Color.accent)
            onHasCursorChanged: if (hasCursor) root.ensureCursorVisible(glassyButton)

            Text {
              id: glassyIcon
              textFormat: Text.PlainText
              text: "\udb80\udcb5"
              color: root.bar.foreground
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.title
              anchors.left: parent.left
              anchors.leftMargin: glassyButton.borderLeft + Style.spacing.rowPaddingX
              anchors.verticalCenter: parent.verticalCenter
            }

            Column {
              id: glassyText
              anchors.left: glassyIcon.right
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              anchors.leftMargin: Style.space(10)
              anchors.rightMargin: glassyButton.borderRight + Style.spacing.rowPaddingX
              spacing: Style.space(2)

              Text {
                width: parent.width
                textFormat: Text.PlainText
                text: root.switchingGlassy ? "Turning on Hyprland's blur…" : "Turn on Hyprland's blur"
                color: root.bar.foreground
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.subtitle
                font.bold: true
                elide: Text.ElideRight
              }

              Text {
                width: parent.width
                textFormat: Text.PlainText
                text: "Switches Omarchy to its Glassy look, so the bar and menus blur too"
                color: Qt.darker(root.bar.foreground, 1.5)
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.caption
                wrapMode: Text.WordWrap
              }
            }

            MouseArea {
              id: glassyMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: root.switchingGlassy ? Qt.BusyCursor : Qt.PointingHandCursor
              onContainsMouseChanged: if (containsMouse) {
                root.cursorActive = true
                root.focusSection = "glassy"
                root.selectedIndex = -1
              }
              onClicked: root.turnOnGlassy()
            }
          }

          Toggle {
            id: cellsToggle
            width: parent.width
            label: "Fade painted backgrounds too"
            description: root.staleCount > 0
              ? (root.staleCount === 1 ? "1 Foot window" : root.staleCount + " Foot windows")
                + " opened before this changed. Reopen "
                + (root.staleCount === 1 ? "it" : "them") + " to "
                + (root.cells ? "fade painted backgrounds" : "keep painted backgrounds solid")
              : root.cells
                ? "Every terminal: colours that programs paint fade with the background"
                : "Every terminal: colours that programs paint stay solid"
            checked: root.cells
            hasCursor: root.cursorActive && root.focusSection === "cells"
            foreground: root.bar.foreground
            fontFamily: root.bar.fontFamily
            onHasCursorChanged: if (hasCursor) root.ensureCursorVisible(cellsToggle)
            onHovered: function(on) {
              if (!on) return
              root.cursorActive = true
              root.focusSection = "cells"
              root.selectedIndex = -1
            }
            onClicked: root.toggleCells()
          }

          PanelSeparator { foreground: root.bar.foreground }

          Column {
            width: parent.width
            spacing: Style.space(4)

            PanelSectionHeader {
              text: "APPLIES TO"
              foreground: root.bar.foreground
              fontFamily: root.bar.fontFamily
            }

            Repeater {
              model: root.rows

              CursorSurface {
                id: row
                required property var modelData
                required property int index
                readonly property bool isReset: modelData.address === root.resetAddress
                width: parent.width
                implicitHeight: rowText.implicitHeight + Style.space(12)
                hasCursor: root.cursorActive && root.focusSection === "rows" && root.selectedIndex === index
                current: !isReset && root.selectedAddress === modelData.address
                foreground: root.bar.foreground
                onHasCursorChanged: if (hasCursor) root.ensureCursorVisible(row)

                Column {
                  id: rowText
                  anchors.left: parent.left
                  anchors.right: rowPercent.left
                  anchors.verticalCenter: parent.verticalCenter
                  anchors.leftMargin: Style.space(10)
                  anchors.rightMargin: Style.space(8)
                  spacing: Style.space(1)

                  Text {
                    width: parent.width
                    textFormat: Text.PlainText
                    text: row.modelData.title
                    color: root.bar.foreground
                    font.family: root.bar.fontFamily
                    font.pixelSize: Style.font.body
                    elide: Text.ElideRight
                  }

                  Text {
                    width: parent.width
                    textFormat: Text.PlainText
                    text: row.modelData.detail
                    color: Qt.darker(root.bar.foreground, 1.5)
                    font.family: root.bar.fontFamily
                    font.pixelSize: Style.font.caption
                    elide: Text.ElideRight
                  }
                }

                Text {
                  id: rowPercent
                  textFormat: Text.PlainText
                  visible: !row.isReset
                  text: (row.current ? root.shownPercent : row.modelData.opacity) + "%"
                  width: visible ? implicitWidth : 0
                  color: Qt.darker(root.bar.foreground, 1.4)
                  font.family: root.bar.fontFamily
                  font.pixelSize: Style.font.caption
                  font.bold: true
                  anchors.right: parent.right
                  anchors.rightMargin: Style.space(10)
                  anchors.verticalCenter: parent.verticalCenter
                }

                MouseArea {
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onContainsMouseChanged: if (containsMouse) {
                    root.cursorActive = true
                    root.focusSection = "rows"
                    root.selectedIndex = row.index
                  }
                  onClicked: row.isReset ? root.reset() : root.selectAddress(row.modelData.address)
                }
              }
            }
          }
        }
      }
    }
  }
}
