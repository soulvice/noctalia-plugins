import QtQuick
import QtQuick.Controls
import Quickshell
import qs.Commons
import qs.Modules.Bar.Extras
import qs.Services.Networking
import qs.Services.UI
import qs.Widgets

Item {
  id: root

  property var pluginApi: null
  property var backend: pluginApi?.mainInstance

  property ShellScreen screen

  // Widget properties passed from Bar.qml for per-instance settings
  property string widgetId: ""
  property string section: ""
  property int sectionWidgetIndex: -1
  property int sectionWidgetsCount: 0

  property var widgetSettings: {
    return pluginApi?.pluginSettings ? pluginApi?.pluginSettings : (pluginApi?.manfest?.metadata?.defaultSettings ? pluginApi?.manfest?.metadata?.defaultSettings : {})
  }

  readonly property bool isBarVertical: Settings.data.bar.position === "left" || Settings.data.bar.position === "right"
  readonly property string displayMode: widgetSettings.displayMode !== undefined ? widgetSettings.displayMode : "onhover"
  readonly property bool showExitNode: widgetSettings.showExitNode !== undefined ? widgetSettings.showExitNode : true
  readonly property bool showStatusDot: widgetSettings.showStatusDot !== undefined ? widgetSettings.showStatusDot : true

  implicitWidth: pill.width
  implicitHeight: pill.height
  

  NPopupContextMenu {
    id: contextMenu

    model: {
      const items = [];

      // Toggle Tailscale
      items.push({
        "label": backend.running ? pluginApi.tr("context-menu.disable-tailscale") : pluginApi.tr("context-menu.enable-tailscale"),
        "action": "toggle-tailscale",
        "icon": backend.running ? "world-off" : "world-check"
      });

      // Exit node quick actions (only when running)
      if (backend.running) {
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
        BarService.openWidgetSettings(screen, section, sectionWidgetIndex, widgetId, widgetSettings);
      }
    }
  }

  BarPill {
    id: pill

    screen: root.screen
    //density: Settings.data.bar.density
    oppositeDirection: BarService.getPillDirection(root)

    icon: {
      if (backend.loading) {
        return "loader-2";
      }
      if (!backend.running) {
        return "world-off";
      }
      if (backend.shieldsUp) {
        return "shield-lock";
      }
      if (backend.currentExitNode) {
        return "shield-check";
      }
      return "world-check";
    }

    text: {
      if (!backend.running) {
        return "";
      }
      if (root.showExitNode && backend.currentExitNodeName) {
        return backend.currentExitNodeName;
      }
      return "";
    }

    autoHide: false
    forceOpen: !isBarVertical && root.displayMode === "alwaysShow"
    forceClose: isBarVertical || root.displayMode === "alwaysHide" || (!backend.running && text === "")

    //onClicked: PanelService.getPanel("tailscalePanel", screen)?.toggle(this)
    onClicked: pluginApi.openPanel(root.screen, this)


    onRightClicked: {
      PanelService.showContextMenu(contextMenu, root, screen);
    }

    tooltipText: {
      if (!backend.running) {
        return pluginApi.tr("tooltips.tailscale-disconnected");
      }
      if (backend.currentExitNodeName) {
        return pluginApi.tr("tooltips.tailscale-exit-node", { "node": backend.currentExitNodeName });
      }
      return pluginApi.tr("tooltips.tailscale-connected", { "ip": backend.selfIP });
    }

    // Show loading animation
    Behavior on icon {
      enabled: backend.loading
    }
  }

  // Subtle indicator for shields up or exit node active
  Rectangle {
    visible: root.showStatusDot && backend.running && (backend.shieldsUp || backend.currentExitNode)
    anchors.right: pill.right
    anchors.top: pill.top
    anchors.rightMargin: 4
    anchors.topMargin: 4
    width: 6
    height: 6
    radius: 3
    color: backend.shieldsUp ? Color.mError : Color.mPrimary
  }
}
