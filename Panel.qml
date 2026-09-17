import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

Panel {
  id: root
  moduleName: "kait2en.audio"
  ipcTarget: "kait2en.audio"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  readonly property var barIdentity: hostWidget || root
  property var status: ({})
  property string statusError: ""
  property string page: "status"
  property var eqGains: [0, 0, 0, 0, 0, 0, 0, 0]
  property real bassAmount: 3.0

  readonly property string statusScript: String(Qt.resolvedUrl("scripts/status.sh")).replace(/^file:\/\//, "")
  readonly property string diagnoseScript: String(Qt.resolvedUrl("scripts/diagnose.sh")).replace(/^file:\/\//, "")
  readonly property string installScript: String(Qt.resolvedUrl("scripts/install.sh")).replace(/^file:\/\//, "")
  readonly property string repairScript: String(Qt.resolvedUrl("scripts/repair-duplicate.sh")).replace(/^file:\/\//, "")
  readonly property string bassScript: String(Qt.resolvedUrl("scripts/set-bass.sh")).replace(/^file:\/\//, "")
  readonly property string eqScript: String(Qt.resolvedUrl("eq/apply.sh")).replace(/^file:\/\//, "")

  property Process statusProcess: Process {
    command: [root.statusScript]
    stdout: StdioCollector { id: statusOutput; waitForEnd: true }
    stderr: StdioCollector { id: statusErrors; waitForEnd: true }
    onExited: function(code) {
      if (code === 0) {
        try {
          root.status = JSON.parse(statusOutput.text)
          root.bassAmount = Number(root.status.bassAmount || 3.0)
          root.statusError = ""
        } catch (error) {
          root.statusError = "Invalid status response"
        }
      } else {
        root.statusError = statusErrors.text || "Could not read KAIT2EN status"
      }
    }
  }

  Timer {
    interval: Math.max(5, Number(root.setting("refreshSeconds", 10))) * 1000
    running: true
    repeat: true
    onTriggered: root.refresh()
  }

  function refresh() {
    if (!statusProcess.running) statusProcess.running = true
  }

  function open() {
    root.controller.show()
    refresh()
  }

  function close() {
    root.controller.hide()
  }

  function toggle() {
    if (root.opened) root.close()
    else root.open()
  }

  function applyEq() {
    eqProcess.command = [root.eqScript, "1"].concat(root.eqGains.map(function(v) { return Number(v).toFixed(2) }))
    eqProcess.running = true
  }

  function disableEq() {
    eqProcess.command = [root.eqScript, "0", "0", "0", "0", "0", "0", "0", "0", "0"]
    eqProcess.running = true
  }

  function value(key, fallback) {
    return root.status && root.status[key] !== undefined ? root.status[key] : fallback
  }

  Component.onCompleted: refresh()

  property Process eqProcess: Process {
    onExited: function(code) {
      if (code !== 0) root.statusError = "Nie udało się zastosować equalizera."
      else root.refresh()
    }
  }

  IpcHandler {
    target: "kait2en.audio"
    function open(): void { root.open() }
    function close(): void { root.close() }
    function toggle(): void { root.toggle() }
    function refresh(): void { root.refresh() }
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    centerOnBar: true
    contentWidth: root.fittedContentWidth(Style.space(430))
      contentHeight: root.fittedContentHeight(contentColumn.implicitHeight + Style.space(24))

    PanelKeyCatcher {
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) {
        if (root.bar && typeof root.bar.switchPanelFrom === "function")
          root.bar.switchPanelFrom(root.barIdentity, direction)
      }
    }

    ColumnLayout {
      id: contentColumn
      anchors.fill: parent
      anchors.margins: Style.space(18)
      spacing: Style.space(10)

      Text {
        text: "KaiT2en Audio DSP"
        color: root.bar ? root.bar.foreground : Color.foreground
        font.family: root.bar ? root.bar.fontFamily : Style.font.family
        font.pixelSize: Style.font.title
        font.bold: true
      }

      RowLayout {
        Layout.fillWidth: true
        Button { text: "Status"; onClicked: root.page = "status" }
        Button { text: "Equalizer"; onClicked: root.page = "eq" }
      }

      Text {
        Layout.fillWidth: true
        text: value("model", "Detecting Mac model…") + "  ·  profile " + value("profile", "—")
        color: root.bar ? root.bar.foreground : Color.foreground
        font.family: root.bar ? root.bar.fontFamily : Style.font.family
        font.pixelSize: Style.font.body
        elide: Text.ElideRight
      }

      Rectangle {
        Layout.fillWidth: true
        implicitHeight: Style.space(1)
        color: Qt.alpha(root.bar ? root.bar.foreground : Color.foreground, 0.2)
      }

      GridLayout {
        visible: root.page === "status"
        Layout.fillWidth: true
        columns: 2
        columnSpacing: Style.space(16)
        rowSpacing: Style.space(6)

        Text { text: "Profil"; color: Color.muted; font.family: root.bar ? root.bar.fontFamily : Style.font.family }
        Text { text: value("profileInstalled", false) ? "zainstalowany" : "brak"; color: value("profileInstalled", false) ? Color.success : Color.warning; font.family: root.bar ? root.bar.fontFamily : Style.font.family }
        Text { text: "Sink DSP"; color: Color.muted; font.family: root.bar ? root.bar.fontFamily : Style.font.family }
        Text { text: value("dspSink", false) ? "aktywny" : "nieaktywny"; color: value("dspSink", false) ? Color.success : Color.warning; font.family: root.bar ? root.bar.fontFamily : Style.font.family }
        Text { text: "Aktualizacje"; color: Color.muted; font.family: root.bar ? root.bar.fontFamily : Style.font.family }
        Text { text: value("timerEnabled", false) ? "timer aktywny" : "timer wyłączony"; color: value("timerEnabled", false) ? Color.success : Color.warning; font.family: root.bar ? root.bar.fontFamily : Style.font.family }
        Text { text: "Wyjście"; color: Color.muted; font.family: root.bar ? root.bar.fontFamily : Style.font.family }
        Text { text: value("defaultSink", "unknown"); color: root.bar ? root.bar.foreground : Color.foreground; font.family: root.bar ? root.bar.fontFamily : Style.font.family; elide: Text.ElideRight; Layout.maximumWidth: Style.space(260) }
      }

      RowLayout {
        visible: root.page === "status"
        Layout.fillWidth: true
        Text { text: "KAIT2EN bass"; color: Color.muted; font.family: root.bar ? root.bar.fontFamily : Style.font.family }
        Slider {
          Layout.fillWidth: true
          from: 0; to: 8; stepSize: 0.5
          value: root.bassAmount
          onMoved: root.bassAmount = value
        }
        Text { text: Number(root.bassAmount).toFixed(1); Layout.preferredWidth: Style.space(34); color: root.bar ? root.bar.foreground : Color.foreground; font.family: root.bar ? root.bar.fontFamily : Style.font.family }
        Button { text: "Zastosuj"; onClicked: Quickshell.execDetached(["alacritty", "-e", root.bassScript, Number(root.bassAmount).toFixed(1)]) }
      }

      Text {
        visible: root.page === "status" && value("duplicateBankstown", false)
        Layout.fillWidth: true
        text: "Uwaga: wykryto duplikat Bankstown w ~/.lv2 i /usr/lib/lv2."
        wrapMode: Text.WordWrap
        color: Color.warning
        font.family: root.bar ? root.bar.fontFamily : Style.font.family
      }

      ColumnLayout {
        visible: root.page === "eq"
        Layout.fillWidth: true
        spacing: Style.space(5)

        Text {
          text: "User Equalizer (±6 dB)"
          color: root.bar ? root.bar.foreground : Color.foreground
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.bold: true
        }

        Repeater {
          model: ["60", "120", "250", "500", "1k", "2k", "4k", "8k"]
          delegate: RowLayout {
            required property string modelData
            Layout.fillWidth: true
            Text { text: modelData + " Hz"; Layout.preferredWidth: Style.space(55); color: Color.muted; font.family: root.bar ? root.bar.fontFamily : Style.font.family }
            Slider {
              Layout.fillWidth: true
              from: -6; to: 6; stepSize: 0.5
              value: root.eqGains[index]
              onMoved: root.eqGains[index] = value
            }
            Text { text: (root.eqGains[index] >= 0 ? "+" : "") + Number(root.eqGains[index]).toFixed(1) + " dB"; Layout.preferredWidth: Style.space(62); color: root.bar ? root.bar.foreground : Color.foreground; font.family: root.bar ? root.bar.fontFamily : Style.font.family }
          }
        }

        RowLayout {
          Layout.fillWidth: true
          Button { text: "Zastosuj EQ"; onClicked: root.applyEq() }
          Button { text: "Wyłącz EQ"; onClicked: root.disableEq() }
          Button { text: "Flat"; onClicked: { root.eqGains = [0,0,0,0,0,0,0,0]; root.applyEq() } }
        }

        Text {
          Layout.fillWidth: true
          text: "EQ jest osobną warstwą za profilem KAIT2EN i nie zmienia plików upstreamu."
          wrapMode: Text.WordWrap
          color: Color.muted
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
        }
      }

      Text {
        visible: root.statusError !== ""
        Layout.fillWidth: true
        text: root.statusError
        wrapMode: Text.WordWrap
        color: Color.urgent
        font.family: root.bar ? root.bar.fontFamily : Style.font.family
      }

        RowLayout {
          Layout.fillWidth: true
          spacing: Style.space(8)
          Button { text: "Odśwież"; onClicked: root.refresh() }
          Button { text: "Diagnostyka"; onClicked: Quickshell.execDetached(["alacritty", "-e", root.diagnoseScript]) }
        }

        RowLayout {
          visible: root.page === "status"
          Layout.fillWidth: true
          Button { text: "Instaluj / napraw"; onClicked: Quickshell.execDetached(["alacritty", "-e", root.installScript]) }
          Button { text: "Napraw Bankstown"; visible: value("duplicateBankstown", false); onClicked: Quickshell.execDetached(["alacritty", "-e", root.repairScript]) }
        }
    }
  }
}
