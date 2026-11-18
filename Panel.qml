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
  readonly property bool frost: service ? service.frost : false
  readonly property int frostOpacity: service ? service.frostOpacity : 80
  readonly property bool frostFollow: service ? service.frostFollow : false
  readonly property bool glass: service ? service.glass : false
  readonly property int glassBrightness: service ? service.glassBrightness : 115
  readonly property int glassShown: glassSlider.dragging ? Math.round(glassSlider.liveValue) : glassBrightness
  readonly property int blurStrength: service ? service.blurStrength : 10
  readonly property int strengthShown: strengthSlider.dragging ? Math.round(strengthSlider.liveValue) : blurStrength
  // Some terminal is blurred: every one by default, or one window of its own.
  readonly property bool anyBlur: {
    if (defaultBlur) return true
    for (var i = 0; i < windows.length; i++) if (windows[i].blur) return true
    return false
  }
  readonly property string corners: service ? service.corners : "theme"
  readonly property bool rounded: corners === "rounded"
  readonly property int cornerRadius: service ? service.cornerRadius : 6
  // A window's radius just let go of, until the backend's answer has it.
  property int pendingWindowRadius: -1
  // The corners of whatever the panel points at: one window's, or the
  // global ones for every window.
  readonly property bool cornersOn: selectedWindow ? selectedWindow.radius > 0 : rounded
  readonly property int radiusValue: selectedWindow
    ? (pendingWindowRadius >= 0 ? pendingWindowRadius : Math.max(1, selectedWindow.radius))
    : cornerRadius
  readonly property int radiusShown: radiusSlider.dragging ? Math.round(radiusSlider.liveValue) : radiusValue
  // Settings Hyprland or the bar have one of for everything: while a window
  // is picked, their headers say so.
  readonly property string everyWindow: selectedWindow ? "  ·  EVERY WINDOW" : ""
  // What the dropdowns show now, live while either slider is dragged.
  readonly property int frostShown: {
    if (frostSlider.dragging) return Math.round(frostSlider.liveValue)
    if (frostFollow && selectedAddress === allAddress && opacitySlider.dragging)
      return Math.max(30, Math.round(opacitySlider.liveValue))
    return frostOpacity
  }
  // Where the dropdown slider's knob sits: as frostShown, except for its own
  // drag, which it tracks itself. Following frostShown through its own drag
  // would hand the old value back the moment the slider lets go.
  readonly property int frostSliderValue: {
    if (frostFollow && selectedAddress === allAddress && opacitySlider.dragging)
      return Math.max(30, Math.round(opacitySlider.liveValue))
    return frostOpacity
  }
  readonly property bool mixedBlur: {
    for (var i = 0; i < windows.length; i++) if (windows[i].blur !== defaultBlur) return true
    return false
  }
  readonly property bool blurAvailable: service ? service.blurAvailable : false
  // Blur is wanted for what the panel points at, but Hyprland blurs nothing.
  readonly property bool needsGlassy: (blur || defaultBlur || frost || glass) && !blurAvailable
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
  readonly property bool customized: service ? service.customized : false
  // Whose defaults a reset goes back to: the theme's, where it sets any of
  // what is here, else Omarchy's.
  readonly property string resetName: service && service.themeOwn && service.themeName !== ""
    ? service.themeName : "Omarchy"
  // Resetting undoes every setting here, so it takes a second click.
  property bool confirmingReset: false

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
    if (customized || defaultSet || anyOverride) {
      list.push({
        address: resetAddress,
        title: confirmingReset ? "Reset everything?" : "Reset to " + resetName + "'s defaults",
        detail: confirmingReset
          ? "Click or press Enter again to undo everything"
          : "Opacity, blur, glass, dropdowns and corners",
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
    pendingWindowRadius = -1
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
    if (focusSection === "glassSlider") {
      if (service) service.commitGlass("brightness", glassBrightness + delta)
      return
    }
    if (focusSection === "cornerRadius") {
      commitRadius(radiusValue + Math.sign(delta))
      return
    }
    if (focusSection === "blurStrength") {
      if (service) service.commitGlass("strength", blurStrength + delta)
      return
    }
    if (focusSection === "frostSlider") {
      if (service) service.commitFrost(frostOpacity + delta)
      return
    }
    if (focusSection === "frostMode") {
      if (service && frostFollow !== (delta > 0)) service.setFrostFollow(delta > 0)
      return
    }
    commit(shownPercent + delta)
  }

  function reset() {
    if (!confirmingReset) {
      confirmingReset = true
      resetConfirmTimer.restart()
      return
    }
    confirmingReset = false
    resetConfirmTimer.stop()
    selectedAddress = allAddress
    if (service) service.reset()
  }

  function toggleBlur() {
    if (service) service.setBlur(target(), !blur)
  }

  function toggleCells() {
    if (service) service.setCells(!cells)
  }

  function toggleFrost() {
    if (service) service.setFrost(!frost)
  }

  function toggleGlass() {
    if (service) service.setGlass(!glass)
  }

  function toggleCorners() {
    if (!service) return
    if (selectedWindow) service.setWindowCorners(selectedWindow.address, !cornersOn)
    else service.setRounded(!rounded)
  }

  function previewRadius(v) {
    if (service) service.previewGlass("radius", v, selectedWindow ? selectedWindow.address : "")
  }

  function commitRadius(v) {
    if (!service) return
    if (selectedWindow) pendingWindowRadius = Math.max(1, Math.min(20, Math.round(v)))
    service.commitGlass("radius", v, selectedWindow ? selectedWindow.address : "")
  }

  function turnOnGlassy() {
    if (service && !switchingGlassy) service.turnOnGlassy()
  }

  // Top to bottom: the slider, the switches in panel order (blur and its
  // strength, frosted glass, painted backgrounds, dropdowns, corners and their
  // radius; then the
  // Glassy button while
  // Hyprland's blur is off and something wants it), then the rows.
  readonly property var sections: {
    var list = ["slider", "blur"]
    if (anyBlur) list.push("blurStrength")
    list.push("glass")
    if (glass) list.push("glassSlider")
    list.push("cells", "frost")
    if (frost) list.push("frostSlider", "frostMode")
    list.push("corners")
    if (cornersOn) list.push("cornerRadius")
    if (needsGlassy) list.push("glassy")
    return list
  }

  function moveCursor(delta) {
    if (focusSection !== "rows") {
      var at = sections.indexOf(focusSection)
      var to = at + delta
      if (to < 0) return
      if (to < sections.length) {
        focusSection = sections[to]
      } else if (rows.length) {
        focusSection = "rows"
        selectedIndex = 0
        selectAddress(rows[0].address)
      }
      return
    }
    var next = selectedIndex + delta
    if (next < 0) {
      focusSection = sections[sections.length - 1]
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
    if (focusSection === "frost") {
      toggleFrost()
      return
    }
    if (focusSection === "frostMode") {
      if (service) service.setFrostFollow(!frostFollow)
      return
    }
    if (focusSection === "glass") {
      toggleGlass()
      return
    }
    if (focusSection === "corners") {
      toggleCorners()
      return
    }
    if (focusSection === "frostSlider" || focusSection === "glassSlider" || focusSection === "blurStrength" || focusSection === "cornerRadius") return
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

  // Scrolling over a slider would set it, since Omarchy's slider takes the
  // wheel. A two-finger scroll down the panel that passes over one stops on
  // it, so the wheel scrolls the panel instead whenever the panel scrolls at
  // all; when everything fits, it goes on to the slider as before.
  function scrollPanel(wheel) {
    var flick = scrollArea ? scrollArea.contentItem : null
    if (!flick || flick.contentY === undefined || panelColumn.implicitHeight <= scrollArea.height) {
      wheel.accepted = false
      return
    }
    var dy = wheel.pixelDelta.y !== 0 ? wheel.pixelDelta.y : wheel.angleDelta.y / 120 * Style.space(48)
    var limit = Math.max(0, flick.contentHeight - flick.height)
    flick.contentY = Math.max(0, Math.min(limit, flick.contentY - dy))
    wheel.accepted = true
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onWindowsChanged: {
    pendingWindowRadius = -1
    follow()
  }
  onNeedsGlassyChanged: if (!needsGlassy && focusSection === "glassy") focusSection = cornersOn ? "cornerRadius" : "corners"
  onFrostChanged: if (!frost && (focusSection === "frostSlider" || focusSection === "frostMode")) focusSection = "frost"
  onGlassChanged: if (!glass && focusSection === "glassSlider") focusSection = "glass"
  onAnyBlurChanged: if (!anyBlur && focusSection === "blurStrength") focusSection = "blur"
  onCornersOnChanged: if (!cornersOn && focusSection === "cornerRadius") focusSection = "corners"
  onDefaultOpacityChanged: follow()

  Timer {
    id: resetConfirmTimer
    interval: 5000
    onTriggered: root.confirmingReset = false
  }

  onOpenedChanged: {
    confirmingReset = false
    if (service) service.viewers += opened ? 1 : -1
    if (!opened) return
    selectedAddress = allAddress
    focusSection = "slider"
    selectedIndex = -1
    cursorActive = false
    shownPercent = opacityOf(allAddress)
    // The panel can be taller than fits; open it at the top each time.
    if (scrollArea && scrollArea.contentItem && scrollArea.contentItem.contentY !== undefined)
      scrollArea.contentItem.contentY = 0
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
    // As tall as everything in it, unless the screen is shorter; then it scrolls.
    contentHeight: panel.fittedContentHeight(panelColumn.implicitHeight)

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

              // Takes only the wheel, so presses, drags and hover still reach
              // the slider beneath.
              MouseArea {
                anchors.fill: parent
                z: 10
                acceptedButtons: Qt.NoButton
                onWheel: function(wheel) { root.scrollPanel(wheel) }
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

          // How strongly Hyprland blurs: size and passes together. Only there
          // while some terminal is blurred, since that is when it is in effect.
          Column {
            visible: root.anyBlur
            width: parent.width
            spacing: Style.space(6)

            Item {
              width: parent.width
              implicitHeight: Math.max(strengthHeader.implicitHeight, strengthPercent.implicitHeight)

              PanelSectionHeader {
                id: strengthHeader
                text: "BLUR STRENGTH" + root.everyWindow
                foreground: root.bar.foreground
                fontFamily: root.bar.fontFamily
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
              }

              Text {
                id: strengthPercent
                textFormat: Text.PlainText
                text: root.strengthShown + "%"
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
              id: strengthSliderSurface
              width: parent.width
              height: strengthSlider.implicitHeight + Style.spacing.controlGap
              hasCursor: root.cursorActive && root.focusSection === "blurStrength"
              foreground: root.bar.foreground
              outline: true
              onHasCursorChanged: if (hasCursor) root.ensureCursorVisible(strengthSliderSurface)

              PanelSlider {
                id: strengthSlider
                bar: root.bar
                anchors.fill: parent
                anchors.leftMargin: Style.space(6)
                anchors.rightMargin: Style.space(6)
                minimum: 0
                maximum: 100
                step: 5
                integer: true
                // The saved value only: tying it to the drag would hand the
                // old value back the moment the slider lets go.
                value: root.blurStrength
                onMoved: function(v) { if (root.service) root.service.previewGlass("strength", v) }
                onReleased: function(v) { if (root.service) root.service.commitGlass("strength", v) }
              }

              // Takes only the wheel, so presses, drags and hover still reach
              // the slider beneath.
              MouseArea {
                anchors.fill: parent
                z: 10
                acceptedButtons: Qt.NoButton
                onWheel: function(wheel) { root.scrollPanel(wheel) }
              }

              HoverHandler {
                onHoveredChanged: if (hovered) {
                  root.cursorActive = true
                  root.focusSection = "blurStrength"
                  root.selectedIndex = -1
                }
              }
            }

            Text {
              width: parent.width
              textFormat: Text.PlainText
              text: "0% a light haze  ·  100% heavy frost"
              color: Qt.darker(root.bar.foreground, 1.55)
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.caption
              horizontalAlignment: Text.AlignHCenter
            }
          }

          // How Hyprland blurs, for everything it blurs, not just terminals.
          Toggle {
            id: glassToggle
            width: parent.width
            label: "Frosted glass"
            description: (root.selectedWindow ? "Every window, not just this one. " : "")
              + (root.glass && !root.blurAvailable
                ? "Set, but Hyprland's blur is off, so nothing blurs yet. Turn it on below."
                : root.glass
                  ? "A heavier, lighter blur behind terminals, the bar and menus"
                  : "Omarchy's own blur: softer, and it dims a little")
            checked: root.glass
            hasCursor: root.cursorActive && root.focusSection === "glass"
            foreground: root.bar.foreground
            fontFamily: root.bar.fontFamily
            onHasCursorChanged: if (hasCursor) root.ensureCursorVisible(glassToggle)
            onHovered: function(on) {
              if (!on) return
              root.cursorActive = true
              root.focusSection = "glass"
              root.selectedIndex = -1
            }
            onClicked: root.toggleGlass()
          }

          // How bright what shows through frosted glass is. Only there while
          // frosted glass is on. 100% leaves Hyprland's blur as bright as
          // what is behind it.
          Column {
            visible: root.glass
            width: parent.width
            spacing: Style.space(6)

            Item {
              width: parent.width
              implicitHeight: Math.max(glassHeader.implicitHeight, glassPercent.implicitHeight)

              PanelSectionHeader {
                id: glassHeader
                text: "FROST BRIGHTNESS" + root.everyWindow
                foreground: root.bar.foreground
                fontFamily: root.bar.fontFamily
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
              }

              Text {
                id: glassPercent
                textFormat: Text.PlainText
                text: root.glassShown + "%"
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
              id: glassSliderSurface
              width: parent.width
              height: glassSlider.implicitHeight + Style.spacing.controlGap
              hasCursor: root.cursorActive && root.focusSection === "glassSlider"
              foreground: root.bar.foreground
              outline: true
              onHasCursorChanged: if (hasCursor) root.ensureCursorVisible(glassSliderSurface)

              PanelSlider {
                id: glassSlider
                bar: root.bar
                anchors.fill: parent
                anchors.leftMargin: Style.space(6)
                anchors.rightMargin: Style.space(6)
                minimum: 50
                maximum: 200
                step: 5
                integer: true
                // The saved value only: tying it to the drag would hand the
                // old value back the moment the slider lets go, before it
                // reports where it was let go.
                value: root.glassBrightness
                onMoved: function(v) { if (root.service) root.service.previewGlass("brightness", v) }
                onReleased: function(v) { if (root.service) root.service.commitGlass("brightness", v) }
              }

              // Takes only the wheel, so presses, drags and hover still reach
              // the slider beneath.
              MouseArea {
                anchors.fill: parent
                z: 10
                acceptedButtons: Qt.NoButton
                onWheel: function(wheel) { root.scrollPanel(wheel) }
              }

              HoverHandler {
                onHoveredChanged: if (hovered) {
                  root.cursorActive = true
                  root.focusSection = "glassSlider"
                  root.selectedIndex = -1
                }
              }
            }

            Text {
              width: parent.width
              textFormat: Text.PlainText
              text: "50% dimmer  ·  100% as is  ·  200% brighter"
              color: Qt.darker(root.bar.foreground, 1.55)
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.caption
              horizontalAlignment: Text.AlignHCenter
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

          Toggle {
            id: frostToggle
            width: parent.width
            label: "Frost bar dropdowns"
            description: root.frost && !root.blurAvailable
              ? "See-through, but Hyprland's blur is off, so nothing blurs yet. Turn it on below."
              : root.frost
                ? (root.frostFollow ? "Every bar dropdown matches the terminals, with blur behind"
                                    : "Every bar dropdown, with blur behind")
                : "Every bar dropdown: as solid as the theme makes it"
            checked: root.frost
            hasCursor: root.cursorActive && root.focusSection === "frost"
            foreground: root.bar.foreground
            fontFamily: root.bar.fontFamily
            onHasCursorChanged: if (hasCursor) root.ensureCursorVisible(frostToggle)
            onHovered: function(on) {
              if (!on) return
              root.cursorActive = true
              root.focusSection = "frost"
              root.selectedIndex = -1
            }
            onClicked: root.toggleFrost()
          }

          // The dropdowns' own opacity, or the terminals'. Glassy stops
          // blurring below 30%, so the slider stops there.
          Column {
            visible: root.frost
            width: parent.width
            spacing: Style.space(6)

            Item {
              width: parent.width
              implicitHeight: Math.max(frostHeader.implicitHeight, frostPercent.implicitHeight)

              PanelSectionHeader {
                id: frostHeader
                text: "DROPDOWN OPACITY" + root.everyWindow
                foreground: root.bar.foreground
                fontFamily: root.bar.fontFamily
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
              }

              Text {
                id: frostPercent
                textFormat: Text.PlainText
                text: root.frostShown + "%"
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
              id: frostSliderSurface
              width: parent.width
              height: frostSlider.implicitHeight + Style.spacing.controlGap
              hasCursor: root.cursorActive && root.focusSection === "frostSlider"
              foreground: root.bar.foreground
              outline: true
              onHasCursorChanged: if (hasCursor) root.ensureCursorVisible(frostSliderSurface)

              PanelSlider {
                id: frostSlider
                bar: root.bar
                anchors.fill: parent
                anchors.leftMargin: Style.space(6)
                anchors.rightMargin: Style.space(6)
                minimum: 30
                maximum: 100
                step: 5
                integer: true
                value: root.frostSliderValue
                onMoved: function(v) { if (root.service) root.service.previewFrost(v) }
                onReleased: function(v) { if (root.service) root.service.commitFrost(v) }
              }

              // Takes only the wheel, so presses, drags and hover still reach
              // the slider beneath.
              MouseArea {
                anchors.fill: parent
                z: 10
                acceptedButtons: Qt.NoButton
                onWheel: function(wheel) { root.scrollPanel(wheel) }
              }

              HoverHandler {
                onHoveredChanged: if (hovered) {
                  root.cursorActive = true
                  root.focusSection = "frostSlider"
                  root.selectedIndex = -1
                }
              }
            }

            ButtonGroup {
              id: frostMode
              width: parent.width
              options: [
                { value: "own", label: "Its own" },
                { value: "follow", label: "Match terminals", tooltip: "Follows the All terminals slider" }
              ]
              value: root.frostFollow ? "follow" : "own"
              focusable: false
              foreground: root.bar.foreground
              fontFamily: root.bar.fontFamily
              fontSize: Style.font.caption
              cursorIndex: root.cursorActive && root.focusSection === "frostMode" ? (root.frostFollow ? 0 : 1) : -1
              onChanged: function(v) { if (root.service) root.service.setFrostFollow(v === "follow") }
              onHovered: function(index, isHovered) {
                if (!isHovered) return
                root.cursorActive = true
                root.focusSection = "frostMode"
                root.selectedIndex = -1
              }
            }
          }

          // Omarchy's own corner setting, for every window.
          Toggle {
            id: cornersToggle
            width: parent.width
            label: "Round window corners"
            description: root.selectedWindow
              ? (root.cornersOn ? "Just this window, until it closes"
                                : "Just this window: square corners, until it closes")
              : root.rounded
                ? "Every window, whatever the theme"
                : root.corners === "sharp"
                  ? "Every window is forced square. On rounds them"
                  : "Every window: as the theme draws them"
            checked: root.cornersOn
            hasCursor: root.cursorActive && root.focusSection === "corners"
            foreground: root.bar.foreground
            fontFamily: root.bar.fontFamily
            onHasCursorChanged: if (hasCursor) root.ensureCursorVisible(cornersToggle)
            onHovered: function(on) {
              if (!on) return
              root.cursorActive = true
              root.focusSection = "corners"
              root.selectedIndex = -1
            }
            onClicked: root.toggleCorners()
          }

          // The corners' radius: one window's, or every window's. Only there
          // while those corners are rounded.
          Column {
            visible: root.cornersOn
            width: parent.width
            spacing: Style.space(6)

            Item {
              width: parent.width
              implicitHeight: Math.max(radiusHeader.implicitHeight, radiusLabel.implicitHeight)

              PanelSectionHeader {
                id: radiusHeader
                text: "CORNER RADIUS"
                foreground: root.bar.foreground
                fontFamily: root.bar.fontFamily
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
              }

              Text {
                id: radiusLabel
                textFormat: Text.PlainText
                text: root.radiusShown + " px"
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
              id: radiusSliderSurface
              width: parent.width
              height: radiusSlider.implicitHeight + Style.spacing.controlGap
              hasCursor: root.cursorActive && root.focusSection === "cornerRadius"
              foreground: root.bar.foreground
              outline: true
              onHasCursorChanged: if (hasCursor) root.ensureCursorVisible(radiusSliderSurface)

              PanelSlider {
                id: radiusSlider
                bar: root.bar
                anchors.fill: parent
                anchors.leftMargin: Style.space(6)
                anchors.rightMargin: Style.space(6)
                minimum: 1
                maximum: 20
                step: 1
                integer: true
                // The saved value only: tying it to the drag would hand the
                // old value back the moment the slider lets go.
                value: root.radiusValue
                onMoved: function(v) { root.previewRadius(v) }
                onReleased: function(v) { root.commitRadius(v) }
              }

              // Takes only the wheel, so presses, drags and hover still reach
              // the slider beneath.
              MouseArea {
                anchors.fill: parent
                z: 10
                acceptedButtons: Qt.NoButton
                onWheel: function(wheel) { root.scrollPanel(wheel) }
              }

              HoverHandler {
                onHoveredChanged: if (hovered) {
                  root.cursorActive = true
                  root.focusSection = "cornerRadius"
                  root.selectedIndex = -1
                }
              }
            }

            Text {
              width: parent.width
              textFormat: Text.PlainText
              text: "1 px subtle  ·  6 px Omarchy  ·  20 px round"
              color: Qt.darker(root.bar.foreground, 1.55)
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.caption
              horizontalAlignment: Text.AlignHCenter
            }
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
