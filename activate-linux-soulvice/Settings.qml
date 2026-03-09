import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

ColumnLayout {
  id: root

  property var pluginApi: null

  property bool valueShowBackground: pluginApi?.pluginSettings?.showBackground !== undefined
                                    ? pluginApi.pluginSettings.showBackground
                                    : pluginApi?.manifest?.metadata?.defaultSettings?.showBackground

  spacing: Style.marginM

  Component.onCompleted: {
    Logger.i("Activate Linux", "Settings UI loaded");
  }

   NToggle {
      Layout.fillWidth: true
      label: pluginApi?.tr("settings.background_color.label")
      description: pluginApi?.tr("settings.background_color.description")
      checked: root.valueShowBackground
      onToggled: function (checked) {
        root.valueShowBackground = checked;
      }
    }

  function saveSettings() {
    if (!pluginApi) {
      Logger.e("Activate Linux", "Cannot save settings: pluginApi is null");
      return;
    }

    pluginApi.pluginSettings.showBackground = root.valueShowBackground;
    pluginApi.saveSettings();

    Logger.i("Activate Linux", "Settings saved successfully");
  }
}