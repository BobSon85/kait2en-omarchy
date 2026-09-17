import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import qs.Ui as Ui

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
  property bool eqDirty: false

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
          if (!root.eqDirty && Array.isArray(root.status.eqGains))
            root.eqGains = root.status.eqGains
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
    root.eqDirty = false
    eqProcess.running = true
  }

  function disableEq() {
    eqProcess.command = [root.eqScript, "0", "0", "0", "0", "0", "0", "0", "0", "0"]
    root.eqDirty = false
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
    centerOnBar: false
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(430))
    contentHeight: panel.fittedContentHeight(contentColumn.implicitHeight + Style.space(24))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) {
        if (root.bar && typeof root.bar.switchPanelFrom === "function")
          root.bar.switchPanelFrom(root.barIdentity, direction)
      }
    }

    // Keep the panel legible on bright wallpapers. The stock audio panel gets
    // its surface from KeyboardPanel; this inner surface makes the custom
    // controls equally readable when a theme intentionally uses translucent
    // popup colors.
    Ui.BorderSurface {
      anchors.fill: parent
      z: 0
      color: Color.background
      radius: Style.cornerRadius
    }

    ColumnLayout {
      id: contentColumn
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.margins: Style.space(18)
      z: 1
      spacing: Style.space(10)

      Item {
        Layout.fillWidth: true
        implicitHeight: Math.max(heroIcon.implicitHeight, heroTitle.implicitHeight)

        Text {
          id: heroIcon
          text: "♫"
          color: root.bar ? root.bar.foreground : Color.foreground
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.display
          anchors.left: parent.left
          anchors.verticalCenter: parent.verticalCenter
        }

        Column {
          id: heroTitle
          anchors.left: heroIcon.right
          anchors.leftMargin: Style.space(14)
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          spacing: Style.space(2)

          Text {
            text: "KaiT2en Audio DSP"
            color: root.bar ? root.bar.foreground : Color.foreground
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.title
            font.bold: true
          }

          Text {
            text: "Native Apple T2 audio"
            color: Color.muted
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.caption
          }
        }
      }

      RowLayout {
        Layout.fillWidth: true
        spacing: Style.space(6)
        Ui.Button { text: "STATUS"; active: root.page === "status"; onClicked: root.page = "status" }
        Ui.Button { text: "EQUALIZER"; active: root.page === "eq"; onClicked: root.page = "eq" }
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

      Ui.PanelSeparator {
        visible: root.page === "status"
        foreground: root.bar ? root.bar.foreground : Color.foreground
      }

      GridLayout {
        visible: root.page === "status"
        Layout.fillWidth: true
        columns: 2
        columnSpacing: Style.space(16)
        rowSpacing: Style.space(6)

        Text { text: "Profil"; color: Color.muted; font.family: root.bar ? root.bar.fontFamily : Style.font.family }
        Text { text: value("profileInstalled", false) ? "󰄬" : "󰅖"; color: value("profileInstalled", false) ? Color.accent : Color.urgent; font.family: root.bar ? root.bar.fontFamily : Style.font.family; font.pixelSize: Style.font.body }
        Text { text: "Sink DSP"; color: Color.muted; font.family: root.bar ? root.bar.fontFamily : Style.font.family }
        Text { text: value("dspSink", false) ? "󰄬" : "󰅖"; color: value("dspSink", false) ? Color.accent : Color.urgent; font.family: root.bar ? root.bar.fontFamily : Style.font.family; font.pixelSize: Style.font.body }
        Text { text: "Mikrofon DSP"; color: Color.muted; font.family: root.bar ? root.bar.fontFamily : Style.font.family }
        Text { text: value("dspSource", false) ? "󰄬" : "󰅖"; color: value("dspSource", false) ? Color.accent : Color.urgent; font.family: root.bar ? root.bar.fontFamily : Style.font.family; font.pixelSize: Style.font.body }
        Text { text: "Aktualizacje"; color: Color.muted; font.family: root.bar ? root.bar.fontFamily : Style.font.family }
        Text { text: value("timerEnabled", false) ? "󰚰" : "󰅖"; color: value("timerEnabled", false) ? Color.accent : Color.urgent; font.family: root.bar ? root.bar.fontFamily : Style.font.family; font.pixelSize: Style.font.body }
        Text { text: "Wyjście"; color: Color.muted; font.family: root.bar ? root.bar.fontFamily : Style.font.family }
        Text { text: value("defaultSink", "unknown"); color: root.bar ? root.bar.foreground : Color.foreground; font.family: root.bar ? root.bar.fontFamily : Style.font.family; font.pixelSize: Style.font.caption; elide: Text.ElideRight; Layout.maximumWidth: Style.space(190) }
      }

      RowLayout {
        visible: root.page === "status"
        Layout.fillWidth: true
        Text { text: "VIRTUAL BASS"; color: Color.muted; font.family: root.bar ? root.bar.fontFamily : Style.font.family; font.pixelSize: Style.font.caption; font.bold: true }
        Ui.PanelSlider {
          id: bassSlider
          bar: root.bar
          Layout.fillWidth: true
          minimum: 0; maximum: 8; step: 0.5
          value: root.bassAmount
          onMoved: function(v) { root.bassAmount = v }
        }
        Text { text: Number(root.bassAmount).toFixed(1); Layout.preferredWidth: Style.space(34); color: root.bar ? root.bar.foreground : Color.foreground; font.family: root.bar ? root.bar.fontFamily : Style.font.family }
        Ui.Button { text: "ZASTOSUJ"; onClicked: Quickshell.execDetached(["alacritty", "-e", root.bassScript, Number(root.bassAmount).toFixed(1)]) }
      }

      Text {
        visible: root.page === "status" && value("duplicateBankstown", false)
        Layout.fillWidth: true
        text: "Uwaga: wykryto duplikat Bankstown w ~/.lv2 i /usr/lib/lv2."
        wrapMode: Text.WordWrap
        color: Color.urgent
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
            required property int index
            Layout.fillWidth: true
            Text { text: modelData + " Hz"; Layout.preferredWidth: Style.space(55); color: Color.muted; font.family: root.bar ? root.bar.fontFamily : Style.font.family }
            Ui.PanelSlider {
              bar: root.bar
              Layout.fillWidth: true
              minimum: -6; maximum: 6; step: 0.5
              value: root.eqGains[index]
              onMoved: function(v) {
                var updated = root.eqGains.slice()
                updated[index] = v
                root.eqGains = updated
                root.eqDirty = true
              }
            }
            Text { text: (root.eqGains[index] >= 0 ? "+" : "") + Number(root.eqGains[index]).toFixed(1) + " dB"; Layout.preferredWidth: Style.space(62); color: root.bar ? root.bar.foreground : Color.foreground; font.family: root.bar ? root.bar.fontFamily : Style.font.family }
          }
        }

        RowLayout {
          Layout.fillWidth: true
          spacing: Style.space(6)
          Ui.Button { text: "ZASTOSUJ EQ"; onClicked: root.applyEq() }
          Ui.Button { text: "WYŁĄCZ EQ"; onClicked: root.disableEq() }
          Ui.Button { text: "FLAT"; onClicked: { root.eqGains = [0,0,0,0,0,0,0,0]; root.applyEq() } }
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

      Ui.PanelSeparator {
        foreground: root.bar ? root.bar.foreground : Color.foreground
      }

      RowLayout {
        Layout.fillWidth: true
        spacing: Style.space(6)
        Ui.Button { text: "ODŚWIEŻ"; onClicked: root.refresh() }
        Ui.Button { text: "DIAGNOSTYKA"; onClicked: Quickshell.execDetached(["alacritty", "--class", "TUI.float", "-e", root.diagnoseScript]) }
      }

      RowLayout {
        visible: root.page === "status"
        Layout.fillWidth: true
        spacing: Style.space(6)
        Ui.Button { text: "INSTALUJ / NAPRAW"; onClicked: Quickshell.execDetached(["alacritty", "-e", root.installScript]) }
        Ui.Button { text: "NAPRAW BANKSTOWN"; visible: value("duplicateBankstown", false); onClicked: Quickshell.execDetached(["alacritty", "-e", root.repairScript]) }
      }
    }
  }
}
