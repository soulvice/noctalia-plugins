import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Modules.MainScreen
import qs.Services.Networking
import qs.Widgets
import "Components" // Required Panel Components

Item {
  id: root

  property var pluginApi: null
  property var backend: pluginApi?.mainInstance

  // SmartPanel properties (required for panel behavior)
  readonly property var geometryPlaceholder: panelContainer
  readonly property bool allowAttach: true
  property real contentPreferredWidth: Math.round(450 * Style.uiScaleRatio)
  //property read contentPreferredHeight: Math.round(600 * Style.uiScaleRatio)
  property real headerHeight: headerRow.implicitHeight + Style.marginM * 2
  property real devicesHeight: devicesList.implicitHeight
  property real calculatedHeight: (devicesHeight !== 0) ? (headerHeight + devicesHeight + Style.marginL * 2 + Style.marginM) : (280 * Style.uiScaleRatio)
  property real contentPreferredeight: backend.connected && backend.devices.length > 0 ? Math.min(600, calculatedHeight) : Math.min(600, 280 * Style.uiScaleRatio)


  property string expandedDeviceId: ""
  property bool showSettings: false
  property bool hasHadDevices: false

  anchors.fill: parent

  Component.onCompleted: {
    hasHadDevices = false;
    backend.refresh();
  }

  //onOpened: {
  //  hasHadDevices = false;
  //  backend.refresh();
  //}

  //onVisibleChanged: {
  //  if (!visible) {
  //    expandedDeviceId = "";
  //    showSettings = false;
  //  }
  //}

  Connections {
    target: backend
    enabled: backend !== null
    function onDevicesChanged() {
        const devicesLen = backend.devices.length || 0; 
        if (devicesLen > 0)
            root.hasHadDevices = true;
        }
  }

  Rectangle {
    id: panelContainer
    color: "transparent"
    anchors.fill: parent

    // Calculate content height
    Rectangle {
      anchors.fill: parent
      color: Color.mSurface
      radius: Style.radiusL
      //border.color: Color.mOutline
      //border.width: Style.borderS
      clip: true  

      ColumnLayout {
        id: mainColumn
        anchors.fill: parent
        anchors.margins: Style.marginL
        spacing: Style.marginM

        // Header
        NBox {
          Layout.fillWidth: true
          Layout.preferredHeight: headerRow.implicitHeight + Style.marginM * 2

          RowLayout {
            id: headerRow
            anchors.fill: parent
            anchors.margins: Style.marginM
            spacing: Style.marginM

            NIcon {
              icon: backend.connected ? "world-check" : "world-off"
              pointSize: Style.fontSizeXXL
              color: backend.connected ? Color.mPrimary : Color.mOnSurfaceVariant
            }

            ColumnLayout {
              Layout.fillWidth: true
              spacing: 2

              NText {
                text: pluginApi.tr("tailscale.panel.title")
                pointSize: Style.fontSizeL
                font.weight: Style.fontWeightBold
                color: Color.mOnSurface
              }

              NText {
                visible: backend.connected && backend.selfIP
                text: backend.selfIP
                pointSize: Style.fontSizeXS
                color: Color.mOnSurfaceVariant
              }
            }

            NToggle {
              checked: backend.connected
              onToggled: checked => backend.toggle()
              baseSize: Style.baseWidgetSize * 0.65
              enabled: !backend.togglingTailscale
            }

            NIconButton {
              icon: "settings"
              tooltipText: pluginApi.tr("tooltips.settings")
              baseSize: Style.baseWidgetSize * 0.8
              onClicked: root.showSettings = !root.showSettings
            }

            NIconButton {
              icon: "refresh"
              tooltipText: pluginApi.tr("tooltips.refresh")
              baseSize: Style.baseWidgetSize * 0.8
              enabled: !backend.refreshing
              onClicked: backend.refresh()
            }

            NIconButton {
              icon: "close"
              tooltipText: pluginApi.tr("tooltips.close")
              baseSize: Style.baseWidgetSize * 0.8
              onClicked: root.close()
            }
          }
        }

        // Error message
        Rectangle {
          visible: backend.lastError.length > 0
          Layout.fillWidth: true
          Layout.preferredHeight: errorRow.implicitHeight + (Style.marginM * 2)
          color: Qt.alpha(Color.mError, 0.1)
          radius: Style.radiusS
          border.width: Style.borderS
          border.color: Color.mError

          RowLayout {
            id: errorRow
            anchors.fill: parent
            anchors.margins: Style.marginM
            spacing: Style.marginS

            NIcon {
              icon: "alert-triangle"
              pointSize: Style.fontSizeL
              color: Color.mError
            }

            NText {
              text: backend.lastError
              color: Color.mError
              pointSize: Style.fontSizeS
              wrapMode: Text.Wrap
              Layout.fillWidth: true
            }

            NIconButton {
              icon: "close"
              baseSize: Style.baseWidgetSize * 0.6
              onClicked: pluginApi.mainInstance.lastError = ""
            }
          }
        }

        // Current exit node banner
        Rectangle {
          visible: backend.connected && backend.currentExitNode !== ""
          Layout.fillWidth: true
          Layout.preferredHeight: exitNodeRow.implicitHeight + (Style.marginM * 2)
          color: Qt.alpha(Color.mPrimary, 0.1)
          radius: Style.radiusS
          border.width: Style.borderS
          border.color: Color.mPrimary

          RowLayout {
            id: exitNodeRow
            anchors.fill: parent
            anchors.margins: Style.marginM
            spacing: Style.marginS

            NIcon {
              icon: "shield-check"
              pointSize: Style.fontSizeL
              color: Color.mPrimary
            }

            ColumnLayout {
              Layout.fillWidth: true
              spacing: 2

              NText {
                text: pluginApi.tr("tailscale.panel.using-exit-node")
                pointSize: Style.fontSizeXS
                color: Color.mPrimary
              }

              NText {
                text: backend.currentExitNodeName
                pointSize: Style.fontSizeM
                font.weight: Style.fontWeightBold
                color: Color.mPrimary
              }
            }

            NButton {
              text: pluginApi.tr("tailscale.panel.disconnect")
              fontSize: Style.fontSizeXS
              outlined: !hovered
              onClicked: backend.clearExitNode()
              enabled: !backend.settingExitNode
            }
          }
        }

        // Settings panel
        NBox {
          visible: root.showSettings && backend.connected
          Layout.fillWidth: true
          Layout.preferredHeight: settingsColumn.implicitHeight + Style.marginM * 2

          ColumnLayout {
            id: settingsColumn
            anchors.fill: parent
            anchors.margins: Style.marginM
            spacing: Style.marginS

            NText {
              text: pluginApi.tr("tailscale.panel.settings")
              pointSize: Style.fontSizeS
              color: Color.mSecondary
              font.weight: Style.fontWeightBold
              Layout.leftMargin: Style.marginS
            }

            SettingRow {
              icon: "shield-lock"
              pluginApi: root.pluginApi
              label: pluginApi.tr("tailscale.panel.shields-up.label")
              description: pluginApi.tr("tailscale.panel.shields-up.description")
              checked: backend.shieldsUp
              onToggled: checked => backend.setShieldsUp(checked)
            }

            SettingRow {
              icon: "route"
              pluginApi: root.pluginApi
              label: pluginApi.tr("tailscale.panel.accept-routes.label")
              description: pluginApi.tr("tailscale.panel.accept-routes.description")
              checked: backend.acceptRoutes
              onToggled: checked => backend.setAcceptRoutes(checked)
            }

            SettingRow {
              icon: "world-cog"
              pluginApi: root.pluginApi
              label: pluginApi.tr("tailscale.panel.accept-dns.label")
              description: pluginApi.tr("tailscale.panel.accept-dns.description")
              checked: backend.acceptDNS
              onToggled: checked => backend.setAcceptDNS(checked)
            }

            SettingRow {
              icon: "network"
              pluginApi: root.pluginApi
              label: pluginApi.tr("tailscale.panel.allow-lan.label")
              description: pluginApi.tr("tailscale.panel.allow-lan.description")
              checked: backend.exitNodeAllowLANAccess
              onToggled: checked => backend.setExitNodeAllowLAN(checked)
            }

            SettingRow {
              icon: "router"
              pluginApi: root.pluginApi
              label: pluginApi.tr("tailscale.panel.advertise-exit-node.label")
              description: pluginApi.tr("tailscale.panel.advertise-exit-node.description")
              checked: backend.advertisingExitNode
              onToggled: checked => backend.advertiseExitNode(checked)
            }
          }
        }

        // Tailscale disabled state
        NBox {
          visible: !backend.connected && !backend.loading
          Layout.fillWidth: true
          Layout.fillHeight: true

          ColumnLayout {
            anchors.fill: parent
            anchors.margins: Style.marginM

            Item { Layout.fillHeight: true }

            NIcon {
              icon: "world-off"
              pointSize: 48
              color: Color.mOnSurfaceVariant
              Layout.alignment: Qt.AlignHCenter
            }

            NText {
              text: pluginApi.tr("tailscale.panel.disabled")
              pointSize: Style.fontSizeL
              color: Color.mOnSurfaceVariant
              Layout.alignment: Qt.AlignHCenter
            }

            NText {
              text: backend.backendState === "NeedsLogin"
                    ? pluginApi.tr("tailscale.panel.needs-login")
                    : pluginApi.tr("tailscale.panel.enable-message")
              pointSize: Style.fontSizeS
              color: Color.mOnSurfaceVariant
              horizontalAlignment: Text.AlignHCenter
              Layout.fillWidth: true
              wrapMode: Text.WordWrap
            }

            Item { Layout.fillHeight: true }
          }
        }

        // Loading state (show when loading and we haven't had devices yet)
        NBox {
          visible: backend.connected && backend.loading && !root.hasHadDevices
          Layout.fillWidth: true
          Layout.fillHeight: true

          ColumnLayout {
            anchors.fill: parent
            anchors.margins: Style.marginM
            spacing: Style.marginL

            Item { Layout.fillHeight: true }

            NBusyIndicator {
              running: true
              color: Color.mPrimary
              size: Style.baseWidgetSize
              Layout.alignment: Qt.AlignHCenter
            }

            NText {
              text: pluginApi.tr("tailscale.panel.loading")
              pointSize: Style.fontSizeM
              color: Color.mOnSurfaceVariant
              Layout.alignment: Qt.AlignHCenter
            }

            Item { Layout.fillHeight: true }
          }
        }

        // Empty state when no devices
        NBox {
          visible: backend.connected && !backend.loading && backend.devices.length === 0 && root.hasHadDevices
          Layout.fillWidth: true
          Layout.fillHeight: true

          ColumnLayout {
            anchors.fill: parent
            spacing: Style.marginL

            Item { Layout.fillHeight: true }

            NIcon {
              icon: "devices-off"
              pointSize: 64
              color: Color.mOnSurfaceVariant
              Layout.alignment: Qt.AlignHCenter
            }

            NText {
              text: pluginApi.tr("tailscale.panel.no-devices")
              pointSize: Style.fontSizeL
              color: Color.mOnSurfaceVariant
              Layout.alignment: Qt.AlignHCenter
            }

            NButton {
              text: pluginApi.tr("tailscale.panel.refresh")
              icon: "refresh"
              Layout.alignment: Qt.AlignHCenter
              onClicked: backend.refresh()
            }

            Item { Layout.fillHeight: true }
          }
        }

        // Devices list container (no NBox wrapper - matches WiFi panel)
        NScrollView {
          visible: backend.connected && backend.devices.length > 0
          Layout.fillWidth: true
          Layout.fillHeight: true
          horizontalPolicy: ScrollBar.AlwaysOff
          verticalPolicy: ScrollBar.AsNeeded
          clip: true

          ColumnLayout {
            id: devicesList
            width: parent.width
            spacing: Style.marginM

            // Exit Nodes section
            DevicesList {
              label: pluginApi.tr("tailscale.panel.exit-nodes")
              model: backend.exitNodes
              pluginApi: root.pluginApi
              isExitNodeList: true
              expandedDeviceId: root.expandedDeviceId
              onDeviceExpanded: id => root.expandedDeviceId = root.expandedDeviceId === id ? "" : id
              onExitNodeSelected: (id, name) => backend.setExitNode(id, name)
            }

            // All Devices section
            DevicesList {
              label: pluginApi.tr("tailscale.panel.devices")
              model: backend.devices
              pluginApi: root.pluginApi
              isExitNodeList: false
              expandedDeviceId: root.expandedDeviceId
              onDeviceExpanded: id => root.expandedDeviceId = root.expandedDeviceId === id ? "" : id
            }
          }
        }
      }
    }
  }
}
