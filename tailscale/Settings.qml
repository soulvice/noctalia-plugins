import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

ColumnLayout {
    id: root

    property var pluginApi: null

    spacing: Style.marginM

    // Local state
    property string valueDisplayMode: pluginApi?.pluginSettings?.displayMode !== undefined
        ? pluginApi.pluginSettings.displayMode
        : pluginApi?.manifest?.metadata?.defaultSettings?.displayMode
    property bool valueShowExitNode: pluginApi?.pluginSettings?.showExitNode !== undefined
        ? pluginApi.pluginSettings.showExitNode
        : pluginApi?.manifest?.metadata?.defaultSettings?.showExitNode
    property bool valueShowStatusDot: pluginApi?.pluginSettings?.showStatusDot !== undefined
        ? pluginApi.pluginSettings.showStatusDot
        : pluginApi?.manifest?.metadata?.defaultSettings?.showStatusDot
    property int valueRefreshInterval: pluginApi?.pluginSettings?.refreshInterval !== undefined
        ? pluginApi.pluginSettings.refreshInterval
        : pluginApi?.manifest?.metadata?.defaultSettings?.refreshInterval ?? 30

    function saveSettings() {
        if (!pluginApi) {
            Logger.e("Tailscale", "Cannot save settings: pluginApi is null");
            return;
        }
        pluginApi.pluginSettings.displayMode = root.valueDisplayMode;
        pluginApi.pluginSettings.showExitNode = root.valueShowExitNode;
        pluginApi.pluginSettings.showStatusDot = root.valueShowStatusDot;
        pluginApi.pluginSettings.refreshInterval = root.valueRefreshInterval;
        pluginApi.saveSettings();
    }

    NComboBox {
        label: pluginApi.tr("bar.widget-settings.tailscale.display-mode.label")
        description: pluginApi.tr("bar.widget-settings.tailscale.display-mode.description")
        minimumWidth: 134
        model: [
            { "key": "onhover", "name": pluginApi.tr("options.display-mode.on-hover") },
            { "key": "alwaysShow", "name": pluginApi.tr("options.display-mode.always-show") },
            { "key": "alwaysHide", "name": pluginApi.tr("options.display-mode.always-hide") }
        ]
        currentKey: root.valueDisplayMode
        onSelected: key => {
            root.valueDisplayMode = key;
            saveSettings();
        }
    }

    NToggle {
        label: pluginApi.tr("bar.widget-settings.tailscale.show-exit-node.label")
        description: pluginApi.tr("bar.widget-settings.tailscale.show-exit-node.description")
        checked: root.valueShowExitNode
        onToggled: checked => {
            root.valueShowExitNode = checked;
            saveSettings();
        }
    }

    NToggle {
        label: pluginApi.tr("bar.widget-settings.tailscale.show-status-dot.label")
        description: pluginApi.tr("bar.widget-settings.tailscale.show-status-dot.description")
        checked: root.valueShowStatusDot
        onToggled: checked => {
            root.valueShowStatusDot = checked;
            saveSettings();
        }
    }

    NSlider {
        label: pluginApi.tr("bar.widget-settings.tailscale.refreshInterval.label")
        description: pluginApi.tr("bar.widget-settings.tailscale.refreshInterval.description")
        value: root.valueRefreshInterval
        min: 5
        max: 300
        step: 5
        unit: "s"
        onValueChanged: val => {
            root.valueRefreshInterval = val;
            saveSettings();
        }
    }
}