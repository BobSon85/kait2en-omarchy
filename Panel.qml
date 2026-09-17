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
  readonly property string systemLocale: String(Qt.locale().name || "").trim().toLowerCase()
  readonly property bool isPolishLocale: root.systemLocale === "pl" || root.systemLocale.indexOf("pl_") === 0 || root.systemLocale.indexOf("pl-") === 0
  readonly property bool statusRefreshing: statusProcess.running

  readonly property string statusScript: String(Qt.resolvedUrl("scripts/status.sh")).replace(/^file:\/\//, "")
  readonly property string diagnoseScript: String(Qt.resolvedUrl("scripts/diagnose.sh")).replace(/^file:\/\//, "")
  readonly property string installScript: String(Qt.resolvedUrl("scripts/install.sh")).replace(/^file:\/\//, "")
  readonly property string repairScript: String(Qt.resolvedUrl("scripts/repair-duplicate.sh")).replace(/^file:\/\//, "")
  readonly property string bassScript: String(Qt.resolvedUrl("scripts/set-bass.sh")).replace(/^file:\/\//, "")
  readonly property string eqScript: String(Qt.resolvedUrl("eq/apply.sh")).replace(/^file:\/\//, "")
  readonly property string outputModeScript: String(Qt.resolvedUrl("scripts/set-output-mode.sh")).replace(/^file:\/\//, "")

  function tr(polishText, englishText) {
    return root.isPolishLocale ? polishText : englishText
  }

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
          root.statusError = root.tr("Nieprawidłowa odpowiedź statusu", "Invalid status response")
        }
      } else {
        root.statusError = statusErrors.text || root.tr("Nie można odczytać statusu KAIT2EN", "Could not read KAIT2EN status")
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
    if (!statusProcess.running)
      statusProcess.running = true
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

  function setOutputMode(mode) {
    outputModeProcess.command = [root.outputModeScript, mode]
    outputModeProcess.running = true
  }

  function value(key, fallback) {
    return root.status && root.status[key] !== undefined ? root.status[key] : fallback
  }

  readonly property color panelForeground: root.bar ? root.bar.foreground : Color.foreground
  readonly property color cardFill: Qt.alpha(root.panelForeground, 0.06)

  function statusGlyph(ok) { return ok ? "󰄬" : "󰅖" }
  function statusTone(ok) { return ok ? Color.accent : Color.urgent }

  Component.onCompleted: refresh()

  property Process eqProcess: Process {
    onExited: function(code) {
      if (code !== 0) root.statusError = root.tr("Nie udało się zastosować equalizera.", "Could not apply the equalizer.")
      else root.refresh()
    }
  }

  property Process outputModeProcess: Process {
    onExited: function(code) {
      if (code !== 0)
        root.statusError = root.tr("Nie udało się zmienić wyjścia audio.", "Could not change the audio output.")
      else
        root.refresh()
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    centerOnBar: false
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(400))
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
      color: Color.popups.background
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
          text: "󰓃"
          color: value("dspSink", false) ? Color.accent : Color.urgent
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
            text: value("dspSink", false)
              ? root.tr("DSP aktywny · Apple T2", "DSP active · Apple T2")
              : root.tr("DSP nieaktywny · Apple T2", "DSP inactive · Apple T2")
            color: value("dspSink", false) ? Color.accent : Color.urgent
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.caption
          }
        }
      }

      RowLayout {
        Layout.fillWidth: true
        spacing: Style.space(6)
        Ui.Button { text: root.tr("STATUS", "STATUS"); active: root.page === "status"; onClicked: root.page = "status" }
        Ui.Button { text: root.tr("EQUALIZER", "EQUALIZER"); active: root.page === "eq"; onClicked: root.page = "eq" }
      }

      Text {
        Layout.fillWidth: true
        text: value("model", root.tr("Wykrywanie modelu Maca…", "Detecting Mac model…")) + "  ·  " + root.tr("profil", "profile") + " " + value("profile", "—")
        color: Color.muted
        font.family: root.bar ? root.bar.fontFamily : Style.font.family
        font.pixelSize: Style.font.body
        elide: Text.ElideRight
      }

      Ui.PanelSeparator {
        foreground: root.bar ? root.bar.foreground : Color.foreground
      }

      Ui.PanelSectionHeader {
        visible: root.page === "status"
        text: root.tr("SYSTEM", "SYSTEM")
        foreground: root.bar ? root.bar.foreground : Color.foreground
        fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
      }

      GridLayout {
        visible: root.page === "status"
        Layout.fillWidth: true
        columns: 2
        columnSpacing: Style.space(8)
        rowSpacing: Style.space(8)

        Repeater {
          model: [
            { label: root.tr("Profil", "Profile"), detail: root.tr("zainstalowany", "installed"), ok: value("profileInstalled", false) },
            { label: root.tr("Wyjście DSP", "DSP output"), detail: root.tr("aktywne", "active"), ok: value("dspSink", false) },
            { label: root.tr("Mikrofon DSP", "DSP microphone"), detail: root.tr("aktywne", "active"), ok: value("dspSource", false) },
            { label: root.tr("Aktualizacje", "Updates"), detail: root.tr("codziennie", "daily"), ok: value("timerEnabled", false) },
            { label: root.tr("Bufor PipeWire", "PipeWire buffer"), detail: Number(value("pipewireQuantum", 0)) === 1024 ? "1024 frames" : "check", ok: Number(value("pipewireQuantum", 0)) === 1024 }
          ]

          delegate: Ui.BorderSurface {
            required property var modelData
            Layout.fillWidth: true
            Layout.preferredHeight: Style.space(48)
            color: root.cardFill
            radius: Style.cornerRadius
            borderSpec: Border.none()

            RowLayout {
              anchors.fill: parent
              anchors.leftMargin: Style.space(10)
              anchors.rightMargin: Style.space(10)
              spacing: Style.space(9)

              Text {
                text: root.statusGlyph(modelData.ok)
                color: root.statusTone(modelData.ok)
                font.family: root.bar ? root.bar.fontFamily : Style.font.family
                font.pixelSize: Style.font.title
              }

              ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                Text { text: modelData.label; color: root.panelForeground; font.family: root.bar ? root.bar.fontFamily : Style.font.family; font.pixelSize: Style.font.body; elide: Text.ElideRight; Layout.fillWidth: true }
                Text { text: modelData.detail.toUpperCase(); color: root.statusTone(modelData.ok); font.family: root.bar ? root.bar.fontFamily : Style.font.family; font.pixelSize: Style.font.caption; font.bold: true; font.letterSpacing: 0.8 }
              }
            }
          }
        }
      }

      Ui.BorderSurface {
        visible: root.page === "status"
        Layout.fillWidth: true
        implicitHeight: Style.space(42)
        color: root.cardFill
        radius: Style.cornerRadius
        borderSpec: Border.none()

        RowLayout {
          anchors.fill: parent
          anchors.leftMargin: Style.space(10)
          anchors.rightMargin: Style.space(10)
          spacing: Style.space(8)
          Text { text: "󰓃"; color: root.panelForeground; font.family: root.bar ? root.bar.fontFamily : Style.font.family; font.pixelSize: Style.font.title }
          Text { text: root.tr("Domyślne wyjście", "Default output"); color: Color.muted; font.family: root.bar ? root.bar.fontFamily : Style.font.family; font.pixelSize: Style.font.caption }
          Item { Layout.fillWidth: true }
          Text { text: value("defaultSink", "unknown"); color: root.panelForeground; font.family: root.bar ? root.bar.fontFamily : Style.font.family; font.pixelSize: Style.font.caption; elide: Text.ElideLeft; Layout.maximumWidth: Style.space(190) }
        }
      }

      Ui.PanelSectionHeader {
        visible: root.page === "status"
        text: root.tr("TRYB WYJŚCIA", "OUTPUT MODE")
        foreground: root.panelForeground
        fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
      }

      RowLayout {
        visible: root.page === "status"
        Layout.fillWidth: true
        spacing: Style.space(6)
        Ui.Button {
          text: root.tr("KaiT2en DSP", "KaiT2en DSP")
          iconText: "󰓃"
          active: value("outputMode", "") === "dsp"
          enabled: !outputModeProcess.running
          onClicked: root.setOutputMode("dsp")
        }
        Ui.Button {
          text: root.tr("Natywne", "Native")
          iconText: "󰍹"
          active: value("outputMode", "") === "native"
          enabled: !outputModeProcess.running
          onClicked: root.setOutputMode("native")
        }
        Item { Layout.fillWidth: true }
      }

      RowLayout {
        visible: root.page === "status"
        Layout.fillWidth: true
        spacing: Style.space(8)
        Ui.PanelSectionHeader {
          text: root.tr("DOSTRAJANIE", "TUNING")
          foreground: root.bar ? root.bar.foreground : Color.foreground
          fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
        }
        Item { Layout.fillWidth: true }
      }

      RowLayout {
        visible: root.page === "status"
        Layout.fillWidth: true
        Text { text: root.tr("BAS WIRTUALNY", "VIRTUAL BASS"); color: Color.muted; font.family: root.bar ? root.bar.fontFamily : Style.font.family; font.pixelSize: Style.font.caption; font.bold: true }
        Ui.PanelSlider {
          id: bassSlider
          bar: root.bar
          Layout.fillWidth: true
          minimum: 0; maximum: 8; step: 0.5
          value: root.bassAmount
          onMoved: function(v) { root.bassAmount = v }
        }
        Text { text: Number(root.bassAmount).toFixed(1); Layout.preferredWidth: Style.space(34); color: root.bar ? root.bar.foreground : Color.foreground; font.family: root.bar ? root.bar.fontFamily : Style.font.family }
        Ui.Button { text: root.tr("ZASTOSUJ", "APPLY"); onClicked: Quickshell.execDetached(["alacritty", "-e", root.bassScript, Number(root.bassAmount).toFixed(1)]) }
      }

      Text {
        visible: root.page === "status" && value("duplicateBankstown", false)
        Layout.fillWidth: true
        text: root.tr("Uwaga: wykryto duplikat Bankstown w ~/.lv2 i /usr/lib/lv2.", "Warning: duplicate Bankstown detected in ~/.lv2 and /usr/lib/lv2.")
        wrapMode: Text.WordWrap
        color: Color.urgent
        font.family: root.bar ? root.bar.fontFamily : Style.font.family
      }

      ColumnLayout {
        visible: root.page === "eq"
        Layout.fillWidth: true
        spacing: Style.space(5)

        Ui.PanelSeparator { foreground: root.bar ? root.bar.foreground : Color.foreground }
        Ui.PanelSectionHeader {
          text: root.tr("EQUALIZER UŻYTKOWNIKA", "USER EQUALIZER")
          foreground: root.bar ? root.bar.foreground : Color.foreground
          fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
        }

        Text {
          text: root.tr("8 pasm · zakres ±6 dB", "8 bands · ±6 dB range")
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
          Ui.Button { text: root.tr("ZASTOSUJ", "APPLY"); onClicked: root.applyEq() }
          Ui.Button { text: root.tr("WYŁĄCZ", "DISABLE"); onClicked: root.disableEq() }
          Ui.Button { text: "FLAT"; onClicked: { root.eqGains = [0,0,0,0,0,0,0,0]; root.applyEq() } }
        }

        Text {
          Layout.fillWidth: true
          text: root.tr("EQ jest osobną warstwą za profilem KAIT2EN i nie zmienia plików upstream.", "EQ is a separate layer after the KAIT2EN profile and does not modify upstream files.")
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
        Ui.Button { text: root.tr("ODŚWIEŻ", "REFRESH"); iconText: "󰑐"; iconSpinning: root.statusRefreshing; enabled: !root.statusRefreshing; Layout.preferredWidth: Style.space(96); onClicked: root.refresh() }
        Ui.Button { text: root.tr("DIAGNOSTYKA", "DIAGNOSTICS"); onClicked: Quickshell.execDetached(["alacritty", "--class", "TUI.float", "-e", root.diagnoseScript]) }
      }

      RowLayout {
        visible: root.page === "status"
        Layout.fillWidth: true
        spacing: Style.space(6)
        Ui.Button { text: root.tr("INSTALUJ / NAPRAW", "INSTALL / REPAIR"); onClicked: Quickshell.execDetached(["alacritty", "-e", root.installScript]) }
        Ui.Button { text: root.tr("NAPRAW BANKSTOWN", "REPAIR BANKSTOWN"); visible: value("duplicateBankstown", false); onClicked: Quickshell.execDetached(["alacritty", "-e", root.repairScript]) }
      }
    }
  }
}
