pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.Commons
import qs.Ui

// App Dock: a KDE-style task manager living in the bar's left section.
//
// One entry per window on this monitor's active workspace. Entries follow
// first-seen order (browser-tab-like). Left click: focused window minimizes
// to special:minimized (KDE behavior); a background or minimized window
// activates. Middle click closes. Minimized windows show a dot indicator.
BarWidget {
  id: root

  moduleName: "gdeyoung.appdock"

  // ---- Visual settings -----------------------------------------------------
  function clampInt(value, min, max, fallback) {
    var n = Math.round(Number(value))
    return isNaN(n) ? fallback : Math.max(min, Math.min(max, n))
  }

  readonly property var settingDefaults: ({
    iconSize: 18,
    maxWidth: 520,
    spacing: 4
  })

  readonly property int configuredIconSize: clampInt(setting("iconSize", settingDefaults.iconSize), 12, 24, settingDefaults.iconSize)
  readonly property int configuredMaxWidth: clampInt(setting("maxWidth", settingDefaults.maxWidth), 160, 1200, settingDefaults.maxWidth)
  readonly property int configuredSpacing: clampInt(setting("spacing", settingDefaults.spacing), 2, 12, settingDefaults.spacing)

  readonly property int slotSize: configuredIconSize + 12
  readonly property int entrySpacing: configuredSpacing
  readonly property int indicatorSlot: 32
  readonly property int verticalMaxEntries: 10

  readonly property string minimizedWorkspace: "special:minimized"

  // ---- Monitor / workspace resolution ----------------------------------------
  readonly property var barScreen:
    root.QsWindow && root.QsWindow.window
      ? root.QsWindow.window.screen
      : null

  readonly property var hMonitor:
    barScreen ? Hyprland.monitorFor(barScreen) : Hyprland.focusedMonitor

  readonly property var activeWorkspace:
    hMonitor ? hMonitor.activeWorkspace : null

  // ---- Reactive window model ---------------------------------------------------
  // Windows on THIS monitor's active workspace PLUS windows stashed on
  // special:minimized (the dock) THAT CAME FROM this workspace (origin read
  // from the minimizer sidecar; unknown origin shows everywhere so a window
  // is never unreachable). Membership is reactive: workspace moves
  // (minimize/restore) flow straight through toplevels.values reads.
  readonly property var windows: {
    var result = []
    if (!hMonitor || !activeWorkspace || activeWorkspace.id <= 0) return result

    var sidecar = root.sidecarOrigins
    var values = Hyprland.toplevels.values
    for (var i = 0; i < values.length; i++) {
      var t = values[i]
      if (!t || !t.workspace) continue
      var onActive = t.monitor && t.monitor.id === hMonitor.id
        && t.workspace.id === activeWorkspace.id
      if (onActive) {
        result.push(t)
      } else if (t.workspace.name === root.minimizedWorkspace) {
        var addr = root.addressOf(t)
        var origin = addr && sidecar[addr]
          ? String(sidecar[addr].workspace || "") : ""
        if (origin === "" || origin === String(activeWorkspace.name))
          result.push(t)
      }
    }
    return result
  }

  // ---- Minimizer sidecar (origin workspaces) ------------------------------------
  property string sidecarText: ""

  readonly property var sidecarOrigins: {
    var parsed = null
    if (sidecarText.length > 0) {
      try { parsed = JSON.parse(sidecarText) } catch (err) { parsed = null }
    }
    if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) return {}
    return parsed
  }

  FileView {
    path: Quickshell.env("XDG_RUNTIME_DIR") + "/hyprland-minimizer/state.json"
    printErrors: false
    watchChanges: true
    onLoaded: root.sidecarText = text()
    onLoadFailed: root.sidecarText = ""
    onFileChanged: reload()
  }

  // ---- Stable display order -----------------------------------------------------
  property var windowOrder: []

  Component.onCompleted: root.syncWindowOrder()

  function syncWindowOrder() {
    var live = Hyprland.toplevels.values || []
    var order = root.windowOrder
    var next = []
    for (var i = 0; i < order.length; i++) {
      if (live.indexOf(order[i]) !== -1) next.push(order[i])
    }
    for (var j = 0; j < windows.length; j++) {
      if (next.indexOf(windows[j]) === -1) next.push(windows[j])
    }
    var same = next.length === order.length
    for (var k = 0; k < next.length && same; k++) {
      if (next[k] !== order[k]) same = false
    }
    if (!same) root.windowOrder = next
  }

  onWindowsChanged: root.syncWindowOrder()

  // ---- Width budget (deterministic, no feedback loops) ----------------------------
  readonly property var layout: computeLayout(windows.length)

  function computeLayout(count) {
    if (root.vertical) {
      var vVisible = Math.min(count, root.verticalMaxEntries)
      return { visibleCount: vVisible, hidden: count - vVisible }
    }
    if (count === 0) return { visibleCount: 0, hidden: 0 }

    var visible = count
    while (true) {
      var hidden = count - visible
      var slots = visible + (hidden > 0 ? 1 : 0)
      var fixed = slots * root.slotSize + Math.max(0, slots - 1) * root.entrySpacing
      if (fixed <= root.configuredMaxWidth)
        return { visibleCount: visible, hidden: hidden }
      if (visible === 1) return { visibleCount: 1, hidden: count - 1 }
      visible--
    }
  }

  // Rendered entries: stable order, cap at layout.visibleCount.
  readonly property var visibleWindows: {
    var candidates = []
    for (var i = 0; i < root.windowOrder.length; i++) {
      if (windows.indexOf(root.windowOrder[i]) !== -1) candidates.push(root.windowOrder[i])
    }
    var count = Math.min(root.layout.visibleCount, candidates.length)
    return candidates.slice(0, count)
  }

  // ---- Actions --------------------------------------------------------------
  function isMinimized(toplevel) {
    return toplevel && toplevel.workspace
      && String(toplevel.workspace.name) === root.minimizedWorkspace
  }

  function addressOf(toplevel) {
    return toplevel && toplevel.lastIpcObject
      ? String(toplevel.lastIpcObject.address || "") : ""
  }

  // Minimize: use the companion script when possible (it writes the sidecar
  // the restore picker reads); fall back to a direct dispatch.
  function minimizeWindow(toplevel) {
    var addr = root.addressOf(toplevel)
    if (addr === "") return
    minimizeProcess.command = [
      "/home/gdeyoung/.local/bin/omarchy-minimize-window.sh", addr]
    minimizeProcess.running = true
  }

  function restoreWindow(toplevel) {
    var addr = root.addressOf(toplevel)
    if (addr === "") return
    var focused = Hyprland.focusedWorkspace
    var selector = "1"
    if (focused && focused.id > 0 && focused.id === Math.floor(focused.id)) {
      selector = String(focused.id)
    }
    Hyprland.dispatch('hl.dsp.window.move({ window = "address:' + addr
      + '", workspace = "' + selector + '", follow = true })')
    Hyprland.dispatch('hl.dsp.focus({ window = "address:' + addr + '" })')
    Hyprland.refreshToplevels()
  }

  function activateWindow(toplevel) {
    if (toplevel && toplevel.wayland) toplevel.wayland.activate()
  }

  Process {
    id: minimizeProcess
  }

  IpcHandler {
    target: "gdeyoung.appdock"

    function status(): string {
      var wins = []
      for (var i = 0; i < root.windows.length; i++) {
        var t = root.windows[i]
        wins.push({
          title: String(t.title || ""),
          ws: t.workspace ? String(t.workspace.name) : "",
          minimized: root.isMinimized(t),
          iconUrl: root.iconFor(t),
          candidates: root.candidatesFor(t).names
        })
      }
      return JSON.stringify({
        activeWorkspace: root.activeWorkspace
          ? String(root.activeWorkspace.name) : "null",
        monitor: root.hMonitor ? String(root.hMonitor.name) : "null",
        appLibrary: root.appLibrary !== null,
        iconSourceFn: root.appLibrary && typeof root.appLibrary.iconSource === "function",
        entryCount: (DesktopEntries.applications.values || []).length,
        windows: wins,
        layout: root.layout
      })
    }
  }

  // ---- Icon resolution (from ncc.yet-another-active-window, proven) -------------
  readonly property bool debugIcons: Quickshell.env("OMARCHY_DEBUG_APPDOCK") === "1"

  readonly property var appLibrary: bar && bar.shell ? bar.shell.appLibrary : null

  function normalizeCandidate(value) {
    var v = String(value === undefined || value === null ? "" : value).trim()
    if (v.slice(-8) === ".desktop") v = v.slice(0, -8)
    return v
  }

  function candidatesFor(toplevel) {
    var meta = toplevel && toplevel.lastIpcObject ? toplevel.lastIpcObject : {}
    var appId = toplevel && toplevel.wayland ? root.normalizeCandidate(toplevel.wayland.appId) : ""
    var cls = root.normalizeCandidate(meta["class"])
    var initial = root.normalizeCandidate(meta.initialClass)

    var names = []
    var push = function(v) {
      if (v.length > 0 && names.indexOf(v) === -1) names.push(v)
    }
    push(cls)
    push(initial)
    push(appId)
    return { names: names, key: [appId, cls, initial].join("|") }
  }

  property var iconCache: ({})

  function entryById(candidate) {
    if (!candidate || candidate.length === 0) return null
    var e = DesktopEntries.byId(candidate)
    if (e && !e.noDisplay) return e
    return null
  }

  function entryIdEquals(entryId, candidate) {
    var id = String(entryId || "").trim()
    if (id.slice(-8) === ".desktop") id = id.slice(0, -8)
    return id.toLowerCase() === String(candidate).toLowerCase() && id.length > 0
  }

  function execBasename(entry) {
    var cmd = entry && entry.command && entry.command.length > 0 ? String(entry.command[0]) : ""
    var slash = cmd.lastIndexOf("/")
    return slash >= 0 ? cmd.slice(slash + 1) : cmd
  }

  function uniqueEntryByIcon(matches) {
    if (matches.length === 0) return null
    var icon = String(matches[0].icon || "")
    for (var i = 1; i < matches.length; i++) {
      if (String(matches[i].icon || "") !== icon) return null
    }
    return matches[0]
  }

  function resolveEntry(names) {
    var values = DesktopEntries.applications.values || []

    for (var i = 0; i < names.length; i++) {
      var exact = root.entryById(names[i])
      if (exact) return exact
    }

    for (var j = 0; j < values.length; j++) {
      var cand = values[j]
      if (cand.noDisplay) continue
      var sc = String(cand.startupClass || "").toLowerCase()
      if (sc.length === 0) continue
      for (var k = 0; k < names.length; k++) {
        if (sc === names[k].toLowerCase()) return cand
      }
    }

    for (var m = 0; m < names.length; m++) {
      var lower = names[m].toLowerCase()
      for (var n = 0; n < values.length; n++) {
        if (!values[n].noDisplay && root.entryIdEquals(values[n].id, lower)) return values[n]
      }
    }

    for (var p = 0; p < names.length; p++) {
      try {
        var guess = DesktopEntries.heuristicLookup(names[p])
        if (guess && !guess.noDisplay) return guess
      } catch (err) { /* native lookup unavailable */ }
    }

    for (var q = 0; q < names.length; q++) {
      var want = names[q].toLowerCase()
      var matches = []
      for (var r = 0; r < values.length; r++) {
        var entry = values[r]
        if (entry.noDisplay) continue
        var nameHit = String(entry.name || "").toLowerCase() === want
        var execHit = root.execBasename(entry).toLowerCase() === want
        if (nameHit || execHit) {
          if (!matches.some(function(prev) { return prev.id === entry.id })) matches.push(entry)
        }
      }
      var unified = root.uniqueEntryByIcon(matches)
      if (unified) return unified
    }

    return null
  }

  function iconFor(toplevel) {
    var identity = root.candidatesFor(toplevel)
    if (identity.names.length === 0) return ""

    var cached = root.iconCache[identity.key]
    if (cached !== undefined && cached.url !== "") return cached.url

    var entryCount = (DesktopEntries.applications.values || []).length
    var lib = root.appLibrary
    var indexKeys = lib ? Object.keys(lib.iconIndex || {}).length : 0
    var rev = entryCount + "/" + indexKeys + "/" + root.pidCacheRev

    if (cached !== undefined && cached.rev === rev) return ""
    if (entryCount === 0) return ""

    var url = ""
    var entry = null
    var pid = toplevel && toplevel.lastIpcObject ? parseInt(toplevel.lastIpcObject.pid, 10) : 0
    try {
      entry = root.resolveEntry(identity.names)
      if (!entry && pid > 0) {
        var exeName = root.exeForPid(pid)
        if (exeName !== "") {
          entry = root.entryByExe(exeName)
        }
      }
    } catch (err) {
      if (root.debugIcons) console.warn("[appdock] resolve error:", err)
    }
    if (entry) {
      if (lib && typeof lib.iconSource === "function") {
        url = String(lib.iconSource(entry.icon))
      } else {
        // appLibrary not injected: resolve through the freedesktop icon
        // theme directly (same fallback the minimizer-tray picker uses).
        url = Quickshell.iconPath(String(entry.icon), true)
          || Quickshell.iconPath("application-x-executable", true)
          || ""
      }
    }

    if (root.debugIcons) {
      console.warn("[appdock] key=" + identity.key
        + " matchedDesktopId=" + (entry ? String(entry.id) : "<none>")
        + " icon=" + (entry ? String(entry.icon) : "<none>")
        + " url=" + url)
    }
    root.iconCache[identity.key] = {
      url: url,
      entryId: entry ? String(entry.id) : "",
      appName: entry ? String(entry.name || "") : "",
      names: identity.names,
      rev: rev
    }
    return url
  }

  // ---- PID -> executable fallback --------------------------------------------
  // One shared batched Process resolves /proc/<pid>/exe for identities no
  // desktop-entry metadata explains (e.g. unusual window classes). Results
  // land in pidCache (reassigned for real change notifications).
  property var pidCache: ({})
  property var pendingPids: ({})
  property int pidCacheRev: 0

  Process {
    id: exeProbe

    stdout: StdioCollector {
      onStreamFinished: root.finishExeBatch(this.text)
    }
  }

  function exeForPid(pid) {
    var p = parseInt(pid, 10)
    if (!p || p <= 0) return ""
    var v = root.pidCache[p]
    if (v !== undefined) return v
    if (root.pendingPids[p] === undefined) {
      root.pendingPids[p] = true
      root.flushExeQueue()
    }
    return ""
  }

  function flushExeQueue() {
    if (exeProbe.running) return
    var script = ""
    for (var key in root.pendingPids) {
      var pid = parseInt(key, 10)
      if (pid > 0)
        script += 'printf "%s\\t%s\\n" "' + pid + '" "$(readlink /proc/' + pid + '/exe 2>/dev/null)"; '
    }
    if (script.length === 0) { root.pendingPids = ({}); return }
    exeProbe.command = ["bash", "-c", script]
    exeProbe.running = true
  }

  function finishExeBatch(text) {
    var results = {}
    var lines = String(text || "").split("\n")
    for (var i = 0; i < lines.length; i++) {
      var line = lines[i]
      var tab = line.indexOf("\t")
      if (tab <= 0) continue
      var exePath = line.slice(tab + 1)
      var slash = exePath.lastIndexOf("/")
      results[line.slice(0, tab)] = slash >= 0 ? exePath.slice(slash + 1) : exePath
    }
    var merged = Object.assign({}, root.pidCache)
    for (var key in root.pendingPids) {
      merged[key] = results[key] !== undefined ? results[key] : ""
      delete root.pendingPids[key]
    }
    root.pidCache = merged
    root.pidCacheRev++
    if (Object.keys(root.pendingPids).length > 0) Qt.callLater(root.flushExeQueue)
  }

  function entryByExe(exeName) {
    var want = String(exeName || "").toLowerCase()
    if (want.length === 0) return null
    var values = DesktopEntries.applications.values || []
    var matches = []
    for (var i = 0; i < values.length; i++) {
      var e = values[i]
      if (e.noDisplay) continue
      var cmdBase = root.execBasename(e).toLowerCase().replace(/\.[a-z]+$/, "")
      var idLower = String(e.id || "").toLowerCase().replace(/\.desktop$/, "")
      var sc = String(e.startupClass || "").toLowerCase()
      if (cmdBase === want || idLower === want || sc === want) {
        if (!matches.some(function(prev) { return prev.id === e.id })) matches.push(e)
      }
    }
    return root.uniqueEntryByIcon(matches)
  }

  function glyphFor(toplevel) {
    var cls = toplevel && toplevel.lastIpcObject ? String(toplevel.lastIpcObject.class || "") : ""
    return cls.length > 0 ? cls.charAt(0).toUpperCase() : "\u25A1"
  }

  function tooltipFor(toplevel) {
    if (!toplevel) return ""
    var raw = String(toplevel.title || "").replace(/\s+/g, " ").trim()
    var identity = root.candidatesFor(toplevel)
    var cached = root.iconCache[identity.key]
    var app = cached && cached.appName ? String(cached.appName).trim() : ""
    if (root.isMinimized(toplevel)) {
      return (app.length > 0 ? app + " — " : "") + (raw.length > 0 ? raw : "(minimized)")
        + "  ·  click to restore"
    }
    return (app.length > 0 ? app + " — " : "") + raw
  }

  // ---- Layout -----------------------------------------------------------------
  implicitWidth: vertical ? Style.bar.sizeVertical : row.implicitWidth
  implicitHeight: vertical ? column.implicitHeight : barSize

  Item {
    anchors.fill: parent
    clip: true

    Row {
      id: row
      visible: !root.vertical
      spacing: root.entrySpacing

      Repeater {
        model: root.layout.visibleCount
        delegate: Entry {}
      }

      Repeater {
        model: root.layout.hidden > 0 ? 1 : 0
        delegate: Overflow {}
      }
    }

    Column {
      id: column
      visible: root.vertical
      spacing: 2

      Repeater {
        model: root.vertical ? root.layout.visibleCount : 0
        delegate: Entry {}
      }

      Repeater {
        model: root.vertical && root.layout.hidden > 0 ? 1 : 0
        delegate: Overflow {}
      }
    }
  }

  component Entry: Item {
    id: entry

    required property int index

    readonly property var win: index < root.visibleWindows.length ? root.visibleWindows[index] : null
    readonly property bool focused: win !== null && win === Hyprland.activeToplevel
    readonly property bool minimized: root.isMinimized(entry.win)
    readonly property bool hovered: area.containsMouse
    readonly property real glyphSlot: root.vertical ? width : root.slotSize

    readonly property bool interactive: win !== null
    readonly property bool tooltipHovered: entry.interactive && area.containsMouse

    readonly property string iconUrl: entry.win ? root.iconFor(entry.win) : ""

    // Single action path: KDE-style.
    // - Left click on focused running window -> minimize to dock
    // - Left click on any other window -> activate
    // - Left click on minimized icon -> restore
    // - Middle click -> close
    function triggerPress(button) {
      if (root.bar && root.bar.hideTooltip) root.bar.hideTooltip(entry)
      if (!entry.win) return
      if (button === Qt.MiddleButton) {
        if (entry.win.wayland) entry.win.wayland.close()
      } else if (entry.minimized) {
        root.restoreWindow(entry.win)
      } else if (entry.focused) {
        root.minimizeWindow(entry.win)
      } else {
        root.activateWindow(entry.win)
      }
    }

    property var registeredBar: null

    function syncClickRegistration() {
      if (registeredBar && registeredBar.unregisterClickTarget)
        registeredBar.unregisterClickTarget(entry)
      registeredBar = root.bar
      if (registeredBar && registeredBar.registerClickTarget)
        registeredBar.registerClickTarget(entry)
    }

    readonly property var watchedBar: root.bar
    onWatchedBarChanged: syncClickRegistration()
    Component.onCompleted: syncClickRegistration()
    Component.onDestruction: {
      if (registeredBar && registeredBar.unregisterClickTarget)
        registeredBar.unregisterClickTarget(entry)
    }

    width: root.vertical ? root.barSize : root.slotSize
    height: root.vertical ? root.barSize : root.barSize

    Rectangle {
      anchors.fill: parent
      radius: 4
      color: Util.alpha(Color.foreground, entry.hovered ? 0.16
        : (entry.focused ? 0.08 : 0))
    }

    // Icon with minimized dimming.
    Item {
      width: entry.glyphSlot
      height: parent.height
      opacity: entry.minimized ? 0.45 : (entry.focused ? 1.0 : 0.75)

      Image {
        anchors.centerIn: parent
        visible: entry.iconUrl.length > 0
        width: root.configuredIconSize
        height: root.configuredIconSize
        fillMode: Image.PreserveAspectFit
        asynchronous: true
        smooth: true
        mipmap: true
        sourceSize.width: width * Screen.devicePixelRatio
        sourceSize.height: height * Screen.devicePixelRatio
        source: entry.iconUrl.length > 0 ? entry.iconUrl : ""
      }

      Text {
        anchors.fill: parent
        visible: entry.iconUrl.length === 0
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        textFormat: Text.PlainText
        text: root.glyphFor(entry.win)
        color: Color.foreground
        font.pixelSize: Style.font.body
      }
    }

    // Minimized indicator: small dot at the bottom of the slot.
    Rectangle {
      visible: entry.minimized
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.bottom: parent.bottom
      anchors.bottomMargin: 2
      width: 10
      height: 3
      radius: height / 2
      color: Util.alpha(Color.foreground, 0.85)
    }

    MouseArea {
      id: area
      anchors.fill: parent
      acceptedButtons: Qt.LeftButton | Qt.MiddleButton
      enabled: entry.interactive
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor

      onClicked: function(mouse) { entry.triggerPress(mouse.button) }

      onEntered: {
        if (!entry.win || !root.bar || !root.bar.showTooltip) return
        root.bar.showTooltip(entry, root.tooltipFor(entry.win))
      }
      onExited: {
        if (root.bar && root.bar.hideTooltip)
          root.bar.hideTooltip(entry)
      }
    }
  }

  component Overflow: Item {
    id: overflow

    width: root.vertical ? root.barSize : root.indicatorSlot
    height: root.vertical ? root.barSize : root.barSize

    function hiddenList() {
      var out = []
      for (var i = 0; i < root.windowOrder.length; i++) {
        var t = root.windowOrder[i]
        if (root.windows.indexOf(t) !== -1 && root.visibleWindows.indexOf(t) === -1)
          out.push(t)
      }
      return out
    }

    function triggerPress(button) {
      if (button === Qt.LeftButton) {
        var hidden = overflow.hiddenList()
        if (hidden.length > 0) root.activateWindow(hidden[0])
      }
    }

    property var registeredBar: null
    readonly property var watchedBar: root.bar

    function syncClickRegistration() {
      if (overflow.registeredBar && overflow.registeredBar.unregisterClickTarget)
        overflow.registeredBar.unregisterClickTarget(overflow)
      overflow.registeredBar = overflow.watchedBar
      if (overflow.registeredBar && overflow.registeredBar.registerClickTarget)
        overflow.registeredBar.registerClickTarget(overflow)
    }

    onWatchedBarChanged: overflow.syncClickRegistration()
    Component.onCompleted: overflow.syncClickRegistration()

    Text {
      anchors.centerIn: parent
      textFormat: Text.PlainText
      text: "+" + root.layout.hidden
      color: Color.foreground
      opacity: 0.55
      font.pixelSize: Style.font.bodySmall
    }

    MouseArea {
      anchors.fill: parent
      acceptedButtons: Qt.LeftButton
      cursorShape: Qt.PointingHandCursor
      onClicked: function(mouse) { overflow.triggerPress(mouse.button) }
    }
  }
}
