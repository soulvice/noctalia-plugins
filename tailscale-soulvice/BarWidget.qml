import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Modules.Bar.Extras
import qs.Services.Networking
import qs.Services.UI
import qs.Widgets

Item {
  id: root

  property var pluginApi: null
  property ShellScreen screen
  // Widget properties passed from Bar.qml for per-instance settings
  property string widgetId: ""
  property string section: ""
  property int sectionWidgetIndex: -1
  property int sectionWidgetsCount: 0

  readonly property bool pillDirection: BarService.getPillDirection(root)
  
  property var backend: pluginApi?.mainInstance
  
  readonly property bool isBarVertical: Settings.data.bar.position === "left" || Settings.data.bar.position === "right"
  
  readonly property real contentWidth: {
    if ((backend?.compactMode ?? false) || !(backend?.connected ?? false)) {
      return Style.capsuleHeight
    }
    return contentRow.implicitWidth + Style.marginM * 2
  }
  readonly property real contentHeight: Style.capsuleHeight
  
  // Extra variables
  property var widgetSettings: {
    return pluginApi?.pluginSettings ? pluginApi?.pluginSettings : (pluginApi?.manfest?.metadata?.defaultSettings ? pluginApi?.manfest?.metadata?.defaultSettings : {})
  }
  readonly property string displayMode: widgetSettings.displayMode !== undefined ? widgetSettings.displayMode : "onhover"
  readonly property bool showExitNode: widgetSettings.showExitNode !== undefined ? widgetSettings.showExitNode : true
  readonly property bool showStatusDot: widgetSettings.showStatusDot !== undefined ? widgetSettings.showStatusDot : true

  implicitWidth: contentWidth
  implicitHeight: contentHeight

  Rectangle {
    id: visualCapsule
    x: Style.pixelAlignCenter(parent.width, width)
    y: Style.pixelAlignCenter(parent.height, height)
    width: root.contentWidth
    height: root.contentHeight
    color: mouseArea.containsMouse ? Color.mHover : Style.capsuleColor
    radius: Style.radiusL

    RowLayout {
      id: contentRow
      anchors.centerIn: parent
      spacing: Style.marginS
      layoutDirection: Qt.LeftToRight

      TailscaleIcon {
        pointSize: Style.fontSizeL
        applyUiScale: false
        crossed: !(backend?.connected ?? false)
        color: {
          if (backend?.connected ?? false) return Color.mOnSurface;
          return mouseArea.containsMouse ? Color.mOnHover : Color.mOnSurface
        }
        opacity: 1.0
      }

      // Show details when not in compact mode and there's something to show
      ColumnLayout {
        visible: !(backend?.compactMode ?? false) && (backend?.connected ?? false) && ((backend?.showIpAddress ?? false) || (backend?.showPeerCount ?? false))
        spacing: 2
        Layout.leftMargin: Style.marginXS
        Layout.rightMargin: Style.marginS

        // IP Address
        NText {
          visible: (backend?.showIpAddress ?? false) && (backend?.tailscaleIp ?? false)
          text: backend?.tailscaleIp || ""
          pointSize: Style.fontSizeXS
          color: mouseArea.containsMouse ? Color.mOnHover : Color.mOnSurface
          font.family: Settings.data.ui.fontFixed
        }

        // Peer count
        NText {
          visible: backend?.showPeerCount ?? false
          text: (backend?.peerCount || 0) + " " + pluginApi?.tr("panel.peers")
          pointSize: Style.fontSizeXS
          color: mouseArea.containsMouse ? Color.mOnHover : Color.mOnSurface
        }
      }
    }
  }
  

  NPopupContextMenu {
    id: contextMenu

    model: {
      const items = [];

      // Toggle Tailscale
      items.push({
        "label": backend.connected ? pluginApi.tr("context-menu.disable-tailscale") : pluginApi.tr("context-menu.enable-tailscale"),
        "action": "toggle-tailscale",
        "icon": backend.connected ? "world-off" : "world-check"
      });

      // Exit node quick actions (only when running)
      if (backend.connected) {
        if (backend.currentExitNode) {
          items.push({
            "label": pluginApi.tr("context-menu.disconnect-exit-node"),
            "action": "clear-exit-node",
            "icon": "shield-off"
          });
        }

        // Shields up toggle
        items.push({
          "label": backend.shieldsUp ? pluginApi.tr("context-menu.shields-down") : pluginApi.tr("context-menu.shields-up"),
          "action": "toggle-shields",
          "icon": backend.shieldsUp ? "shield" : "shield-lock"
        });
      }

      // Widget settings
      items.push({
        "label": pluginApi.tr("context-menu.widget-settings"),
        "action": "widget-settings",
        "icon": "settings"
      });

      return items;
    }

    onTriggered: action => {
      var popupMenuWindow = PanelService.getPopupMenuWindow(screen);
      if (popupMenuWindow) {
        popupMenuWindow.close();
      }

      if (action === "toggle-tailscale") {
        backend.toggle();
      } else if (action === "clear-exit-node") {
        backend.clearExitNode();
      } else if (action === "toggle-shields") {
        backend.setShieldsUp(!backend.shieldsUp);
      } else if (action === "widget-settings") {
        BarService.openPluginSettings(screen, pluginApi.manifest);
      }
    }
  }

  MouseArea {
    id: mouseArea
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton | Qt.RightButton

    onClicked: (mouse) => {
      if (mouse.button === Qt.LeftButton) {
        if (pluginApi) {
          pluginApi.openPanel(root.screen, root)
        }
      } else if (mouse.button === Qt.RightButton) {
        PanelService.showContextMenu(contextMenu, root, screen)
      }
    }
  }
}
