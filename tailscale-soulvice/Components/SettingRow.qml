import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

Rectangle {
  id: root

  property string icon: ""
  property string label: ""
  property string description: ""
  property bool checked: false

  property var pluginApi: null

  signal toggled(bool checked)

  Layout.fillWidth: true
  implicitHeight: contentRow.implicitHeight + Style.marginS * 2
  radius: Style.radiusS
  color: mouseArea.containsMouse ? Qt.alpha(Color.mOnSurface, 0.05) : Color.transparent

  Behavior on color {
    ColorAnimation { duration: Style.animationFast }
  }

  MouseArea {
    id: mouseArea
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: root.toggled(!root.checked)
  }

  RowLayout {
    id: contentRow
    anchors.fill: parent
    anchors.margins: Style.marginS
    spacing: Style.marginM

    NIcon {
      icon: root.icon
      pointSize: Style.fontSizeL
      color: root.checked ? Color.mPrimary : Color.mOnSurfaceVariant
    }

    ColumnLayout {
      Layout.fillWidth: true
      spacing: 2

      NText {
        text: root.label
        pointSize: Style.fontSizeS
        font.weight: Style.fontWeightMedium
        color: Color.mOnSurface
      }

      NText {
        visible: root.description
        text: root.description
        pointSize: Style.fontSizeXXS
        color: Color.mOnSurfaceVariant
        wrapMode: Text.WordWrap
        Layout.fillWidth: true
      }
    }

    NToggle {
      checked: root.checked
      onToggled: checked => root.toggled(checked)
      baseSize: Style.baseWidgetSize * 0.55
    }
  }
}
