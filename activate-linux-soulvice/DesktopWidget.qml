import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Modules.DesktopWidgets
import qs.Widgets

DraggableDesktopWidget {
  id: root

  // Plugin API (injected by PluginService)
  property var pluginApi: null


  showBackground: false

  property real widgetOpacity: (widgetData && widgetData.opacity) ? widgetData.opacity : 1.0

  implicitWidth: 300
  implicitHeight: 80
  
  ColumnLayout {
    id: contentLayout
    anchors.centerIn: parent
    spacing: Style.marginL

    NText {
        text: pluginApi?.tr("desktop_widget.main")
        color: "#50ffffff"
        pointSize: Style.fontSizeXXXL
    }

    NText {
        text: pluginApi?.tr("desktop_widget.sub")
        color: "#50ffffff"
        pointSize: Style.fontSizeM
    }
  }
}