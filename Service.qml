import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// One backend process for the whole shell. A bar is created per monitor, so a
// backend owned by the panel would run once per screen; the panel is a view
// over this instead. The backend stays running and takes a command per line,
// which is what lets every step of a slider drag reach the terminals without
// starting a process for it.
Item {
  id: root

  property var shell: null
  property var manifest: null

  readonly property string script: Quickshell.env("HOME") + "/.config/omarchy/plugins/bhj.terminal-opacity/terminal-opacity"

  property var windows: []
  property int defaultOpacity: 100
  property bool defaultSet: false
  // Whether what shows through a terminal is blurred by default (each window
  // carries its own), and whether Hyprland's
  // blur is on at all for that to mean anything.
  property bool blur: false
  property bool blurAvailable: false
  // Whether backgrounds that programs paint fade too. One choice for all.
  property bool cells: false
  // Whether the bar's dropdowns are frosted, and how solid they are then.
  property bool frost: false
  property int frostOpacity: 80
  // Whether that opacity follows the terminals' default instead of its own.
  property bool frostFollow: false
  property int frostPreviewValue: -1
  // Whether Hyprland's blur is the heavier, lighter frosted glass, and
  // Omarchy's window corners: "rounded", "sharp", or "theme".
  property bool glass: false
  property string corners: "theme"
  property string note: ""
  property string error: ""
  property bool ready: false

  // Open panels. Focus and title changes only matter while one is showing.
  property int viewers: 0

  property var queued: []
  property string previewTarget: ""
  property int previewValue: -1

  function send(line) {
    if (ready) {
      daemon.write(line + "\n")
      return
    }
    queued.push(line)
    if (!daemon.running) daemon.running = true
  }

  function sync() { send("sync") }

  // A step of a drag: shown on the terminals, not saved. Steps arriving
  // faster than the terminals can take them collapse into the latest one.
  function preview(target, value) {
    previewTarget = target
    previewValue = Math.max(0, Math.min(100, Math.round(value)))
    if (!previewTimer.running) previewTimer.start()
  }

  function commit(target, value) {
    previewTimer.stop()
    previewValue = -1
    send("commit " + target + " " + Math.max(0, Math.min(100, Math.round(value))))
  }

  function nudge(target, delta) {
    send("nudge " + target + " " + Math.round(delta))
  }

  function reset() { send("reset") }

  function setCells(on) {
    cells = on
    send("cells " + (on ? "on" : "off"))
  }

  function setFrost(on) {
    frost = on
    send("frost " + (on ? "on" : "off"))
  }

  function setFrostFollow(on) {
    frostFollow = on
    send("frost " + (on ? "follow" : Math.round(frostOpacity)))
  }

  // A drag step: the shell rereads its file on every write, so steps are
  // spaced out and only the latest one goes.
  function previewFrost(value) {
    frostPreviewValue = Math.max(30, Math.min(100, Math.round(value)))
    if (!frostTimer.running) frostTimer.start()
  }

  function commitFrost(value) {
    frostTimer.stop()
    frostPreviewValue = -1
    frostFollow = false
    frostOpacity = Math.max(30, Math.min(100, Math.round(value)))
    send("frost " + frostOpacity)
  }

  // Turns on Hyprland's blur through Omarchy's Glassy look. Only on request,
  // since it changes the whole desktop.
  property bool switchingGlassy: false
  function turnOnGlassy() {
    switchingGlassy = true
    send("glassy")
  }

  // Both reload Hyprland, so they are shown at once and the backend's answer
  // confirms them.
  function setGlass(on) {
    glass = on
    send("glass " + (on ? "on" : "off"))
  }

  function setRounded(on) {
    corners = on ? "rounded" : "theme"
    send("corners " + (on ? "on" : "off"))
  }

  // Shown at once; the backend's answer confirms it.
  function setBlur(target, on) {
    if (target === "all") blur = on
    send("blur " + target + " " + (on ? "on" : "off"))
  }

  function ingest(line) {
    var data
    try {
      data = JSON.parse(line)
    } catch (e) {
      return
    }
    if (!data || data.type !== "state") return
    windows = data.windows || []
    defaultOpacity = typeof data.default === "number" ? data.default : 100
    defaultSet = data.defaultSet === true
    blur = data.blur === true
    cells = data.cells === true
    frost = data.frost === true
    frostFollow = data.frostFollow === true
    if (typeof data.frostOpacity === "number") frostOpacity = data.frostOpacity
    blurAvailable = data.blurAvailable === true
    glass = data.glass === true
    if (typeof data.corners === "string") corners = data.corners
    switchingGlassy = false
    note = String(data.note || "")
    error = String(data.error || "")
  }

  Process {
    id: daemon
    command: [root.script, "serve"]
    running: true
    stdinEnabled: true
    stdout: SplitParser {
      onRead: function(line) { root.ingest(line) }
    }
    onStarted: {
      root.ready = true
      var lines = root.queued
      root.queued = []
      for (var i = 0; i < lines.length; i++) daemon.write(lines[i] + "\n")
    }
    onExited: {
      root.ready = false
      restartTimer.start()
    }
  }

  Timer {
    id: restartTimer
    interval: 1000
    onTriggered: daemon.running = true
  }

  Timer {
    id: frostTimer
    interval: 90
    onTriggered: {
      if (root.frostPreviewValue < 0) return
      root.send("frost " + root.frostPreviewValue)
      root.frostPreviewValue = -1
    }
  }

  Timer {
    id: previewTimer
    interval: 25
    onTriggered: {
      if (root.previewValue < 0) return
      root.send("preview " + root.previewTarget + " " + root.previewValue)
      root.previewValue = -1
    }
  }

  // A new terminal is pinned to full compositor opacity, and one with no
  // background control of its own is brought to the default, as it opens.
  Timer {
    id: syncTimer
    interval: 300
    onTriggered: root.sync()
  }

  // A config reload can put terminals back on what their config files say.
  Timer {
    id: reapplyTimer
    interval: 1500
    onTriggered: root.send("reapply")
  }

  Connections {
    target: Hyprland
    function onRawEvent(event) {
      var name = event.name
      if (name === "openwindow" || name === "closewindow") syncTimer.restart()
      else if (name === "configreloaded") reapplyTimer.restart()
      else if (root.viewers > 0 && (name === "activewindowv2" || name === "windowtitlev2" || name === "fullscreen"))
        syncTimer.restart()
    }
  }
}
