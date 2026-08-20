import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

Panel {
  id: root
  moduleName: "spacexrace.screen-mirroring"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  property bool depsInstalled: false
  property bool vaapiAvailable: false
  property bool streaming: false
  property bool connecting: false
  property bool streamActive: false
  property bool busy: false
  property string connectedReceiver: ""
  property string connectedIp: ""
  property string lastReceiver: ""
  property string extraArgs: ""
  property string errorText: ""
  property string credentialTarget: ""
  property string credentialKind: ""
  property string pendingCredential: ""
  property var devices: []
  property bool showSettings: false
  property bool scanning: false
  property bool heroHover: false
  property bool permanentPorts: false
  property bool cleanupRequired: false
  property string missingDependencies: ""
  property bool cursorActive: false
  property string focusSection: "header"
  property int headerIndex: 0
  property int receiverIndex: 0

  readonly property string helper: Quickshell.env("HOME") + "/.config/omarchy/plugins/spacexrace.screen-mirroring/bin/omarchy-screen-mirroring"
  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property color urgent: bar ? bar.urgent : Color.urgent
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  function open() {
    scanning = true
    root.controller.show()
    refreshPanel()
  }
  function close() {
    root.controller.hide()
    if (!root.streaming && !root.connecting && !root.credentialTarget) run(idleProc, ["shutdown-if-idle"])
  }
  function switchPanel(direction) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function") return root.bar.switchPanelFrom(root.hostWidget || root, direction)
    return false
  }
  function run(process, args) {
    if (process.running) return
    process.command = [helper].concat(args)
    process.running = true
  }
  function refreshPanel() {
    if (depsInstalled) scanning = true
    run(depsProc, ["deps"])
    run(statusProc, ["status"])
  }
  function reloadReceivers() {
    if (!depsInstalled) return
    scanning = true
    run(discoverProc, ["discover"])
  }
  function applyStatus(raw) {
    var data = Model.parseJson(raw, { ok: false, error: "Invalid response" })
    if (!data.ok) { errorText = data.error || "Screen mirroring status unavailable"; return }
    cleanupRequired = data.cleanupRequired === true
    errorText = data.error || (cleanupRequired ? "Temporary firewall rules remain after the stream stopped." : "")
    lastReceiver = data.lastReceiver || lastReceiver
    if (!argsInput.activeFocus && !actionProc.running && data.extraArgs !== undefined) extraArgs = data.extraArgs
    permanentPorts = data.permanentPorts === true
    var streams = data.streams || []
    streaming = false
    connecting = false
    connectedReceiver = ""
    connectedIp = ""
    credentialTarget = ""
    credentialKind = ""
    for (var i = 0; i < streams.length; i++) {
      var stream = streams[i]
      if (stream.state === "streaming") {
        streaming = true
        connectedReceiver = stream.device || stream.device_ip || "Receiver"
        connectedIp = stream.device_ip || ""
      }
      if (stream.state === "connecting") connecting = true
      if (stream.state === "connecting" && !connectedReceiver) {
        connectedReceiver = stream.device || stream.device_ip || "Receiver"
        connectedIp = stream.device_ip || ""
      }
      if (stream.state === "pin_required" || stream.credential_kind) {
        connecting = true
        credentialTarget = stream.device_ip || ""
        credentialKind = stream.credential_kind || "pin"
        if (!connectedReceiver) connectedReceiver = stream.device || stream.device_ip || "Receiver"
      }
    }
    streamActive = streaming || connecting || credentialTarget !== ""
  }
  function applyDevices(raw) {
    var data = Model.parseJson(raw, { ok: false, error: "Invalid receiver list" })
    if (!data.ok) { errorText = data.error || "Unable to find receivers"; return }
    devices = data.devices || []
    if (receiverIndex >= devices.length) receiverIndex = Math.max(0, devices.length - 1)
  }
  function installDependencies() {
    Quickshell.execDetached(["xdg-terminal-exec", "--hold", "bash", "-lc", "omarchy pkg add gstreamer gst-plugins-base gst-plugins-good gst-plugins-bad gst-plugins-ugly gst-libav gst-plugin-va libva-utils libpulse pipewire xdg-desktop-portal xdg-desktop-portal-hyprland xdg-terminal-exec ufw polkit python && omarchy pkg aur add doubletake"])
  }
  function connectReceiver(ip, name) {
    if (!ip || busy) return
    busy = true
    run(actionProc, ["connect", ip, name || ""])
  }
  function receiverNameForIp(ip) {
    for (var i = 0; i < devices.length; i++) {
      if (devices[i] && devices[i].ip === ip) return devices[i].name || ""
    }
    return ""
  }
  function disconnect() {
    if (actionProc.running) return
    busy = true
    run(actionProc, ["disconnect"])
  }
  function toggleStream() {
    if (streamActive) disconnect()
    else if (lastReceiver) connectReceiver(lastReceiver, receiverNameForIp(lastReceiver))
    else errorText = "Choose a receiver first"
  }
  function saveExtraArgs() { run(actionProc, ["save-extra-args", extraArgs]) }
  function savePermanentPorts(enabled) { run(actionProc, ["save-permanent-ports", enabled ? "true" : "false"]) }
  function closeLeftoverPorts() { run(actionProc, ["close-ports"]) }
  function submitCredential() {
    if (!credentialTarget || credentialInput.text.length === 0 || actionProc.running) return
    pendingCredential = credentialInput.text
    run(actionProc, ["credential", credentialTarget])
    credentialInput.text = ""
  }
  function moveCursor(dx, dy) {
    cursorActive = true
    if (dy !== 0) {
      if (focusSection === "header" && dy > 0) {
        focusSection = devices.length > 0 ? "receivers" : "settings"
      } else if (focusSection === "receivers") {
        if (dy < 0 && receiverIndex <= 0) focusSection = "header"
        else if (dy > 0 && receiverIndex >= devices.length - 1) focusSection = "settings"
        else receiverIndex = Math.max(0, Math.min(devices.length - 1, receiverIndex + dy))
      } else if (focusSection === "settings" && dy < 0) {
        focusSection = devices.length > 0 ? "receivers" : "header"
      }
    }
    if (dx !== 0 && focusSection === "header") headerIndex = Math.max(0, Math.min(1, headerIndex + dx))
    if (focusSection === "receivers") receiverList.positionViewAtIndex(receiverIndex, ListView.Contain)
  }
  function activateCursor() {
    cursorActive = true
    if (focusSection === "header") {
      if (headerIndex === 0) reloadReceivers()
      else toggleStream()
    } else if (focusSection === "receivers") {
      var receiver = devices[receiverIndex]
      if (streamActive) disconnect()
      else if (receiver) connectReceiver(receiver.ip, receiver.name)
    } else if (focusSection === "settings") {
      showSettings = !showSettings
    }
  }

  onOpenedChanged: if (opened) refreshPanel()
  Component.onCompleted: run(statusProc, ["status"])

  Timer {
    id: statusTimer
    interval: 3000
    running: true
    repeat: true
    onTriggered: root.run(statusProc, ["status"])
  }
  Timer {
    id: refreshTimer
    interval: 1500
    repeat: true
    running: root.busy
    onTriggered: {
      root.run(statusProc, ["status"])
      if (!actionProc.running && !root.streaming && !root.connecting && !root.credentialTarget) root.busy = false
    }
  }
  Process {
    id: depsProc
    stdout: StdioCollector { id: depsOut }
    onExited: {
      var data = Model.parseJson(depsOut.text, {})
      root.depsInstalled = data.installed === true
      root.vaapiAvailable = data.vaapi === true
      root.missingDependencies = (data.missing || []).join(", ")
      if (root.opened && root.depsInstalled) root.reloadReceivers()
      if (!root.depsInstalled) root.scanning = false
    }
  }
  Process {
    id: statusProc
    stdout: StdioCollector { id: statusOut }
    onExited: root.applyStatus(statusOut.text)
  }
  Process {
    id: discoverProc
    stdout: StdioCollector { id: discoverOut }
    onExited: {
      root.scanning = false
      root.applyDevices(discoverOut.text)
    }
  }
  Process {
    id: actionProc
    stdinEnabled: true
    stdout: StdioCollector { id: actionOut }
    onStarted: {
      if (root.pendingCredential !== "") {
        actionProc.write(root.pendingCredential + "\n")
        root.pendingCredential = ""
      }
    }
    onExited: {
      root.pendingCredential = ""
      root.applyStatus(actionOut.text)
      root.run(statusProc, ["status"])
    }
  }
  Process { id: idleProc }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.hostWidget || root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: fittedContentWidth(Style.space(460))
    contentHeight: fittedContentHeight(contentColumn.implicitHeight, Style.space(600))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      blocked: credentialInput.activeFocus || argsInput.activeFocus
      onMoveRequested: function(dx, dy) { root.moveCursor(dx, dy) }
      onActivateRequested: root.activateCursor()
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(text) {
        if (text === "r" || text === "R") root.reloadReceivers()
        else if (text === "w" || text === "W") root.toggleStream()
      }

      Flickable {
        anchors.fill: parent
        contentWidth: width
        contentHeight: contentColumn.implicitHeight
        clip: true
        ColumnLayout {
          id: contentColumn
          width: parent.width
          spacing: Style.space(10)

          RowLayout {
            Layout.fillWidth: true
            spacing: Style.space(12)
            Item {
              Layout.preferredWidth: Style.space(40)
              Layout.preferredHeight: Style.space(40)
              BorderSurface { anchors.fill: parent; color: "transparent"; radius: Style.cornerRadius; visible: root.heroHover; borderSpec: Border.controlSpec("hover-cursor", root.foreground, Color.accent) }
              MirrorIcon { anchors.fill: parent; foreground: root.streaming ? root.foreground : root.dim }
              MouseArea { anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onContainsMouseChanged: root.heroHover = containsMouse; onClicked: root.toggleStream() }
            }
            ColumnLayout {
              Layout.fillWidth: true
              spacing: Style.space(2)
              Text { Layout.fillWidth: true; text: "Screen Mirroring"; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.title; font.bold: true; elide: Text.ElideRight }
              Text { Layout.fillWidth: true; text: root.scanning ? "SCANNING FOR RECEIVERS" : (root.streaming ? "MIRRORING TO " + root.connectedReceiver.toUpperCase() : (root.credentialTarget ? "WAITING FOR " + root.connectedReceiver.toUpperCase() : (root.connecting ? "CONNECTING TO " + root.connectedReceiver.toUpperCase() : (root.devices.length === 0 ? "NO RECEIVERS FOUND" : "NOT CONNECTED")))); color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.bodySmall; elide: Text.ElideRight }
            }
            Button {
              iconText: "󰑐"
              tooltipText: "Reload receivers"
              foreground: root.foreground
              fontFamily: root.fontFamily
              iconSize: Style.font.subtitle * 1.5
              horizontalPadding: Style.space(5)
              verticalPadding: Style.space(2)
              hasCursor: root.cursorActive && root.focusSection === "header" && root.headerIndex === 0
              onHovered: function(on) { if (on) { root.cursorActive = false; root.focusSection = "header"; root.headerIndex = 0 } }
              onClicked: root.reloadReceivers()
            }
            Item {
              implicitWidth: powerSwitch.implicitWidth
              implicitHeight: powerSwitch.implicitHeight
              ToggleSwitch {
                id: powerSwitch
                anchors.fill: parent
                checked: root.streamActive
                interactive: false
                cursorRing: true
                hasCursor: switchMouse.containsMouse || (root.cursorActive && root.focusSection === "header" && root.headerIndex === 1)
                foreground: root.foreground
              }
              MouseArea {
                id: switchMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onContainsMouseChanged: if (containsMouse) { root.cursorActive = false; root.focusSection = "header"; root.headerIndex = 1 }
                onClicked: root.toggleStream()
              }
              PanelToolTip { visible: switchMouse.containsMouse; text: root.streamActive ? "Stop mirroring" : "Mirror to last receiver"; fontFamily: root.fontFamily }
            }
          }

          Text { visible: root.errorText !== ""; Layout.fillWidth: true; text: root.errorText; color: root.urgent; font.family: root.fontFamily; font.pixelSize: Style.font.bodySmall; wrapMode: Text.WordWrap }

          ColumnLayout {
            visible: !root.depsInstalled
            Layout.fillWidth: true
            spacing: Style.space(8)
            PanelSeparator { Layout.fillWidth: true; foreground: root.foreground }
            PanelSectionHeader { text: "DEPENDENCIES"; foreground: root.foreground; fontFamily: root.fontFamily }
            Text { Layout.fillWidth: true; text: "Install GStreamer and VA-API packages from the official repositories, plus doubletake from the AUR. The installer uses Omarchy's package commands."; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.bodySmall; wrapMode: Text.WordWrap }
            Text { visible: root.missingDependencies !== ""; Layout.fillWidth: true; text: "Missing: " + root.missingDependencies; color: root.urgent; font.family: root.fontFamily; font.pixelSize: Style.font.bodySmall; wrapMode: Text.WordWrap }
            Button { Layout.fillWidth: true; text: "Install dependencies (includes AUR)"; bordered: true; foreground: root.foreground; fontFamily: root.fontFamily; onClicked: root.installDependencies() }
          }

          ColumnLayout {
            visible: root.depsInstalled && !root.showSettings
            Layout.fillWidth: true
            spacing: Style.space(8)
            PanelSeparator { Layout.fillWidth: true; foreground: root.foreground }
            PanelSectionHeader { text: "RECEIVERS"; foreground: root.foreground; fontFamily: root.fontFamily }
            ListView {
              id: receiverList
              Layout.fillWidth: true
              Layout.preferredHeight: Math.min(contentHeight, Style.space(260))
              visible: root.devices.length > 0
              clip: true
              spacing: Style.space(4)
              model: root.devices
              delegate: ReceiverRow {
                required property var modelData
                required property int index
                width: ListView.view.width
                receiver: modelData
                listIndex: index
              }
            }

            ColumnLayout {
              visible: root.credentialTarget !== ""
              Layout.fillWidth: true
              spacing: Style.space(6)
              PanelSectionHeader { text: root.credentialKind === "password" ? "RECEIVER PASSWORD" : "PAIRING PIN"; foreground: root.foreground; fontFamily: root.fontFamily }
              Text { Layout.fillWidth: true; text: root.credentialKind === "password" ? "Enter the password configured on the receiver." : "Enter the PIN shown on the receiver."; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.bodySmall; wrapMode: Text.WordWrap }
              TextField { id: credentialInput; Layout.fillWidth: true; placeholderText: root.credentialKind === "password" ? "Password" : "Four-digit PIN"; password: root.credentialKind === "password"; inputMethodHints: root.credentialKind === "password" ? Qt.ImhHiddenText : Qt.ImhDigitsOnly; onAccepted: root.submitCredential() }
              Button { Layout.fillWidth: true; text: "Continue"; bordered: true; foreground: root.foreground; fontFamily: root.fontFamily; onClicked: root.submitCredential() }
            }
            Button { Layout.fillWidth: true; text: "Settings"; bordered: true; hasCursor: root.cursorActive && root.focusSection === "settings"; foreground: root.foreground; fontFamily: root.fontFamily; onHovered: function(on) { if (on) { root.cursorActive = false; root.focusSection = "settings" } }; onClicked: root.showSettings = true }
            Button { visible: root.cleanupRequired; Layout.fillWidth: true; text: "Remove leftover firewall rules"; bordered: true; foreground: root.urgent; fontFamily: root.fontFamily; onClicked: root.closeLeftoverPorts() }
          }

          ColumnLayout {
            visible: root.depsInstalled && root.showSettings
            Layout.fillWidth: true
            spacing: Style.space(8)
            PanelSeparator { Layout.fillWidth: true; foreground: root.foreground }
            RowLayout {
              Layout.fillWidth: true
              PanelSectionHeader { Layout.fillWidth: true; text: "SETTINGS"; foreground: root.foreground; fontFamily: root.fontFamily }
              Button { text: "Back"; bordered: true; foreground: root.foreground; fontFamily: root.fontFamily; onClicked: root.showSettings = false }
            }
            PanelSectionHeader { text: "DOUBLETAKE ARGUMENTS"; foreground: root.foreground; fontFamily: root.fontFamily }
            TextField {
              id: argsInput
              Layout.fillWidth: true
              placeholderText: "For example: -hwaccel vaapi"
              text: root.extraArgs
              onTextEdited: root.extraArgs = text
              onEditingFinished: root.saveExtraArgs()
            }
            Text { Layout.fillWidth: true; text: root.vaapiAvailable ? "VA-API encoder available" : "VA-API encoder not detected"; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.bodySmall }
            ColumnLayout {
              Layout.fillWidth: true
              spacing: Style.space(2)
              RowLayout {
                Layout.fillWidth: true
                Text { Layout.fillWidth: true; text: "Keep receiver ports open"; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.body }
                ToggleSwitch {
                  checked: root.permanentPorts
                  foreground: root.foreground
                  onToggled: {
                    root.permanentPorts = !root.permanentPorts
                    root.savePermanentPorts(root.permanentPorts)
                  }
                }
              }
              Text { Layout.fillWidth: true; text: "Keeps receiver-specific ports open after the first approval, so later connections avoid the password prompt."; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.bodySmall; wrapMode: Text.WordWrap }
            }
          }
        }
      }
    }
  }

  component MirrorIcon: Item {
    property color foreground: "white"
    Rectangle { x: parent.width * 0.24; y: parent.height * 0.16; width: parent.width * 0.68; height: parent.height * 0.46; color: "transparent"; border.color: Qt.darker(parent.foreground, 1.3); border.width: 2; radius: 2 }
    Rectangle { x: parent.width * 0.08; y: parent.height * 0.31; width: parent.width * 0.68; height: parent.height * 0.46; color: "transparent"; border.color: parent.foreground; border.width: 2; radius: 2 }
  }

  component ReceiverRow: CursorSurface {
    id: receiverRow
    required property var receiver
    required property int listIndex
    readonly property bool active: root.connectedIp === (receiver ? receiver.ip : "")
    readonly property bool unavailable: root.busy || root.streaming || root.connecting
    property bool hovered: false
    width: parent ? parent.width : 0
    implicitHeight: rowBody.implicitHeight + Style.space(12)
    foreground: root.foreground
    current: active
    hasCursor: hovered || (root.cursorActive && root.focusSection === "receivers" && root.receiverIndex === listIndex)

    BorderSurface {
      anchors.fill: parent
      visible: receiverRow.hovered
      color: "transparent"
      radius: Style.cornerRadius
      borderSpec: Border.controlSpec("hover-cursor", root.foreground, Color.accent)
    }

    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: unavailable ? Qt.ArrowCursor : Qt.PointingHandCursor
      onContainsMouseChanged: {
        receiverRow.hovered = containsMouse
        if (containsMouse) {
          root.cursorActive = false
          root.focusSection = "receivers"
          root.receiverIndex = listIndex
        }
      }
      onClicked: if (!unavailable && receiver) root.connectReceiver(receiver.ip, receiver.name)
    }

    Item {
      id: rowBody
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.leftMargin: Style.space(10)
      anchors.rightMargin: Style.space(10)
      anchors.topMargin: Style.space(6)
      height: implicitHeight
      implicitHeight: Math.max(receiverIcon.height, receiverInfo.implicitHeight, receiverState.height)
      Text { id: receiverIcon; width: Style.space(20); height: Style.space(20); anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; text: "󰀵"; color: active ? root.foreground : root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.title; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
      Column {
        id: receiverInfo
        anchors.left: receiverIcon.right
        anchors.leftMargin: Style.space(10)
        anchors.right: receiverState.left
        anchors.rightMargin: Style.space(8)
        anchors.verticalCenter: parent.verticalCenter
        spacing: Style.space(1)
        Text { width: parent.width; text: receiver ? receiver.name : ""; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.body; elide: Text.ElideRight }
        Text { width: parent.width; text: Model.deviceSubtitle(receiver); color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.bodySmall; elide: Text.ElideRight }
      }
      Text { id: receiverState; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; text: active ? "Mirroring" : ""; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.bodySmall }
    }
  }
}
