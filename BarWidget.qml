import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "kait2en.audio"

  readonly property bool opened: panelItem ? panelItem.opened === true : false
  readonly property var sink: Pipewire.defaultAudioSink
  readonly property bool outputMuted: sink && sink.audio ? sink.audio.muted : false
  readonly property bool dspActive: panelItem && panelItem.status && panelItem.status.dspSink !== undefined
    ? panelItem.status.dspSink === true
    : !!sink
  readonly property bool iconInactive: !root.dspActive || root.outputMuted
  property var panelItem: null

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    panelItem = target
    if ("bar" in target) target.bar = root.bar
    if ("settings" in target) target.settings = root.settings
    if ("anchorItem" in target) target.anchorItem = button
    if ("hostWidget" in target) target.hostWidget = root
  }

  function togglePanel() {
    if (panelItem) panelItem.toggle()
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight
  onBarChanged: injectPanel()
  onSettingsChanged: injectPanel()

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  PwObjectTracker { objects: root.sink ? [root.sink] : [] }

  IpcHandler {
    target: "kait2en.audio"
    function open(): void { if (root.panelItem) root.panelItem.open() }
    function close(): void { if (root.panelItem) root.panelItem.close() }
    function toggle(): void { root.togglePanel() }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "󰓃"
    foreground: "#FFFFFF"
    active: root.iconInactive
    activeColor: Color.urgent
    tooltipText: root.opened ? "Close KaiT2en Audio" : "KaiT2en Audio"
    onPressed: function(b) {
      if (b === Qt.LeftButton) root.togglePanel()
    }
  }
}
