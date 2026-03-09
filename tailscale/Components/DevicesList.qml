import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Services.Networking
import qs.Widgets

NBox {
  id: root

  property string label: ""
  property var model: []
  property bool isExitNodeList: false
  property string expandedDeviceId: ""

  property var pluginApi: null

  signal deviceExpanded(string id)
  signal exitNodeSelected(string id, string name)

  Layout.fillWidth: true
  Layout.preferredHeight: column.implicitHeight + Style.marginM * 2
  visible: root.model.length > 0

  ColumnLayout {
    id: column
    anchors.fill: parent
    anchors.margins: Style.marginM
    spacing: Style.marginM

    NText {
      text: root.label
      pointSize: Style.fontSizeS
      color: Color.mSecondary
      font.weight: Style.fontWeightBold
      visible: root.model.length > 0
      Layout.fillWidth: true
      Layout.leftMargin: Style.marginS
    }

    Repeater {
      model: root.model

      Rectangle {
        id: deviceItem

        Layout.fillWidth: true
        Layout.leftMargin: Style.marginXS
        Layout.rightMargin: Style.marginXS
        implicitHeight: deviceColumn.implicitHeight + (Style.marginM * 2)
        radius: Style.radiusM
        border.width: Style.borderS
        border.color: {
          if (modelData.exitNode) return Color.mPrimary;
          if (modelData.online) return Color.mOutline;
          return Qt.alpha(Color.mOutline, 0.5);
        }

        opacity: pluginApi?.mainInstance?.settingExitNode && pluginApi?.mainInstance?.settingExitNodeTo === modelData.hostname ? 0.6 : 1.0

        color: {
          if (modelData.exitNode) return Qt.rgba(Color.mPrimary.r, Color.mPrimary.g, Color.mPrimary.b, 0.05);
          return Color.mSurface;
        }

        Behavior on opacity {
          NumberAnimation { duration: Style.animationNormal }
        }

        ColumnLayout {
          id: deviceColumn
          width: parent.width - (Style.marginM * 2)
          x: Style.marginM
          y: Style.marginM
          spacing: Style.marginS

          // Main row
          RowLayout {
            Layout.fillWidth: true
            spacing: Style.marginS

            NIcon {
              icon: pluginApi?.mainInstance?.osIcon(modelData.os)
              pointSize: Style.fontSizeXXL
              color: modelData.online ? Color.mOnSurface : Color.mOnSurfaceVariant
              opacity: modelData.online ? 1.0 : 0.5
            }

            ColumnLayout {
              Layout.fillWidth: true
              spacing: 2

              RowLayout {
                spacing: Style.marginS

                NText {
                  text: modelData.hostname
                  pointSize: Style.fontSizeM
                  font.weight: modelData.online ? Style.fontWeightMedium : Style.fontWeightRegular
                  color: modelData.online ? Color.mOnSurface : Color.mOnSurfaceVariant
                  elide: Text.ElideRight
                  Layout.fillWidth: true
                }

                // Preferred star
                NIcon {
                  visible: root.isExitNodeList && pluginApi?.mainInstance?.isPreferredExitNode(modelData.id)
                  icon: "star-filled"
                  pointSize: Style.fontSizeS
                  color: Color.mError //mError //mWarning
                }
              }

              RowLayout {
                spacing: Style.marginXS

                NText {
                  text: modelData.ip
                  pointSize: Style.fontSizeXXS
                  color: Color.mOnSurfaceVariant
                }

                NText {
                  visible: modelData.os
                  text: "•"
                  pointSize: Style.fontSizeXXS
                  color: Color.mOnSurfaceVariant
                }

                NText {
                  visible: modelData.os
                  text: modelData.os
                  pointSize: Style.fontSizeXXS
                  color: Color.mOnSurfaceVariant
                }

                Item { Layout.preferredWidth: Style.marginXXS }

                // Status badges
                Rectangle {
                  visible: modelData.online
                  color: Color.mPrimary
                  radius: height * 0.5
                  width: onlineText.implicitWidth + (Style.marginS * 2)
                  height: onlineText.implicitHeight + (Style.marginXXS * 2)

                  NText {
                    id: onlineText
                    anchors.centerIn: parent
                    text: pluginApi.tr("tailscale.panel.online")
                    pointSize: Style.fontSizeXXS
                    color: Color.mOnPrimary
                  }
                }

                Rectangle {
                  visible: !modelData.online
                  color: Color.transparent
                  border.color: Color.mOutline
                  border.width: Style.borderS
                  radius: height * 0.5
                  width: offlineText.implicitWidth + (Style.marginS * 2)
                  height: offlineText.implicitHeight + (Style.marginXXS * 2)

                  NText {
                    id: offlineText
                    anchors.centerIn: parent
                    text: pluginApi?.mainInstance?.formatLastSeen(modelData.lastSeen)
                    pointSize: Style.fontSizeXXS
                    color: Color.mOnSurfaceVariant
                  }
                }

                Rectangle {
                  visible: modelData.exitNode
                  color: Color.mPrimary
                  radius: height * 0.5
                  width: activeExitText.implicitWidth + (Style.marginS * 2)
                  height: activeExitText.implicitHeight + (Style.marginXXS * 2)

                  NText {
                    id: activeExitText
                    anchors.centerIn: parent
                    text: pluginApi.tr("tailscale.panel.active-exit-node")
                    pointSize: Style.fontSizeXXS
                    color: Color.mOnPrimary
                  }
                }

                Rectangle {
                  visible: modelData.exitNodeOption && !modelData.exitNode && root.isExitNodeList
                  color: Color.transparent
                  border.color: Color.mOutline
                  border.width: Style.borderS
                  radius: height * 0.5
                  width: exitNodeText.implicitWidth + (Style.marginS * 2)
                  height: exitNodeText.implicitHeight + (Style.marginXXS * 2)

                  NText {
                    id: exitNodeText
                    anchors.centerIn: parent
                    text: pluginApi.tr("tailscale.panel.exit-node")
                    pointSize: Style.fontSizeXXS
                    color: Color.mOnSurfaceVariant
                  }
                }
              }
            }

            // Action area
            RowLayout {
              spacing: Style.marginS

              NBusyIndicator {
                visible: pluginApi?.mainInstance?.settingExitNode && pluginApi?.mainInstance?.settingExitNodeTo === modelData.hostname
                running: visible
                color: Color.mPrimary
                size: Style.baseWidgetSize * 0.5
              }

              NIconButton {
                visible: !modelData.exitNode && !pluginApi?.mainInstance?.settingExitNode
                icon: "dots-vertical"
                tooltipText: pluginApi.tr("tooltips.more-options")
                baseSize: Style.baseWidgetSize * 0.8
                onClicked: root.deviceExpanded(modelData.id)
              }

              NButton {
                visible: root.isExitNodeList && modelData.exitNodeOption && !modelData.exitNode && modelData.online && !pluginApi?.mainInstance?.settingExitNode
                text: pluginApi.tr("tailscale.panel.use")
                outlined: !hovered
                fontSize: Style.fontSizeXS
                onClicked: root.exitNodeSelected(modelData.id, modelData.hostname)
              }
            }
          }

          // Expanded details
          Rectangle {
            visible: root.expandedDeviceId === modelData.id
            Layout.fillWidth: true
            height: detailsColumn.implicitHeight + Style.marginS * 2
            color: Color.mSurfaceVariant
            border.color: Color.mOutline
            border.width: Style.borderS
            radius: Style.radiusS

            ColumnLayout {
              id: detailsColumn
              anchors.fill: parent
              anchors.margins: Style.marginS
              spacing: Style.marginS

              // IP addresses
              RowLayout {
                spacing: Style.marginM
                Layout.fillWidth: true

                ColumnLayout {
                  spacing: 2
                  Layout.fillWidth: true

                  NText {
                    text: pluginApi.tr("tailscale.panel.ipv4")
                    pointSize: Style.fontSizeXXS
                    color: Color.mOnSurfaceVariant
                  }

                  RowLayout {
                    spacing: Style.marginS

                    NText {
                      text: modelData.ip || "-"
                      pointSize: Style.fontSizeS
                      color: Color.mOnSurface
                      font.family: Settings.data.ui.fontFixed
                    }

                    NIconButton {
                      visible: modelData.ip
                      icon: "clipboard-copy"
                      baseSize: Style.baseWidgetSize * 0.6
                      tooltipText: pluginApi.tr("tooltips.copy")
                      onClicked: {
                        Clipboard.text = modelData.ip;
                        ToastService.showNotice(pluginApi.tr("tailscale.panel.title"), pluginApi.tr("toast.copied"), "copy");
                      }
                    }
                  }
                }

                ColumnLayout {
                  visible: modelData.ipv6 !== ""
                  spacing: 2

                  NText {
                    text: pluginApi.tr("tailscale.panel.ipv6")
                    pointSize: Style.fontSizeXXS
                    color: Color.mOnSurfaceVariant
                  }

                  RowLayout {
                    spacing: Style.marginS

                    NText {
                      text: modelData.ipv6 || "-"
                      pointSize: Style.fontSizeS
                      color: Color.mOnSurface
                      font.family: Settings.data.ui.fontFixed
                      elide: Text.ElideMiddle
                      Layout.maximumWidth: 150
                    }

                    NIconButton {
                      icon: "clipboard-copy"
                      baseSize: Style.baseWidgetSize * 0.6
                      tooltipText: pluginApi.tr("tooltips.copy")
                      onClicked: {
                        Clipboard.text = modelData.ipv6;
                        ToastService.showNotice(pluginApi.tr("tailscale.panel.title"), pluginApi.tr("toast.copied"), "copy");
                      }
                    }
                  }
                }
              }

              // DNS name
              RowLayout {
                visible: modelData.dnsName !== ""
                spacing: Style.marginS
                Layout.fillWidth: true

                ColumnLayout {
                  spacing: 2
                  Layout.fillWidth: true

                  NText {
                    text: pluginApi.tr("tailscale.panel.dns-name")
                    pointSize: Style.fontSizeXXS
                    color: Color.mOnSurfaceVariant
                  }

                  NText {
                    text: modelData.dnsName.replace(/\.$/, "")
                    pointSize: Style.fontSizeS
                    color: Color.mOnSurface
                    font.family: Settings.data.ui.fontFixed
                    elide: Text.ElideMiddle
                    Layout.fillWidth: true
                  }
                }

                NIconButton {
                  icon: "clipboard-copy"
                  baseSize: Style.baseWidgetSize * 0.6
                  tooltipText: pluginApi.tr("tooltips.copy")
                  onClicked: {
                    Clipboard.text = modelData.dnsName.replace(/\.$/, "");
                    ToastService.showNotice(pluginApi.tr("tailscale.panel.title"), pluginApi.tr("toast.copied"), "copy");
                  }
                }
              }

              // Connection info
              RowLayout {
                visible: modelData.online && (modelData.curAddr !== "" || modelData.relay !== "")
                spacing: Style.marginM
                Layout.fillWidth: true

                ColumnLayout {
                  visible: modelData.curAddr !== ""
                  spacing: 2

                  NText {
                    text: pluginApi.tr("tailscale.panel.connection")
                    pointSize: Style.fontSizeXXS
                    color: Color.mOnSurfaceVariant
                  }

                  RowLayout {
                    spacing: Style.marginXS

                    NIcon {
                      icon: "link"
                      pointSize: Style.fontSizeS
                      color: Color.mPrimary
                    }

                    NText {
                      text: pluginApi.tr("tailscale.panel.direct")
                      pointSize: Style.fontSizeS
                      color: Color.mPrimary
                    }
                  }
                }

                ColumnLayout {
                  visible: modelData.curAddr === "" && modelData.relay !== ""
                  spacing: 2

                  NText {
                    text: pluginApi.tr("tailscale.panel.connection")
                    pointSize: Style.fontSizeXXS
                    color: Color.mOnSurfaceVariant
                  }

                  RowLayout {
                    spacing: Style.marginXS

                    NIcon {
                      icon: "cloud"
                      pointSize: Style.fontSizeS
                      color: Color.mError //mWarning
                    }

                    NText {
                      text: pluginApi.tr("tailscale.panel.relayed", { "relay": modelData.relay })
                      pointSize: Style.fontSizeS
                      color: Color.mError //mWarning
                    }
                  }
                }
              }

              // Actions row
              RowLayout {
                Layout.fillWidth: true
                spacing: Style.marginS

                Item { Layout.fillWidth: true }

                // Favorite toggle for exit nodes
                NButton {
                  visible: root.isExitNodeList && modelData.exitNodeOption
                  text: pluginApi?.mainInstance?.isPreferredExitNode(modelData.id)
                        ? pluginApi.tr("tailscale.panel.unfavorite")
                        : pluginApi.tr("tailscale.panel.favorite")
                  icon: pluginApi?.mainInstance?.isPreferredExitNode(modelData.id) ? "star-off" : "star"
                  outlined: true
                  fontSize: Style.fontSizeXXS
                  onClicked: {
                    if (pluginApi?.mainInstance?.isPreferredExitNode(modelData.id)) {
                      pluginApi?.mainInstance?.removePreferredExitNode(modelData.id);
                    } else {
                      pluginApi?.mainInstance?.addPreferredExitNode(modelData.id);
                    }
                  }
                }

                NIconButton {
                  icon: "close"
                  baseSize: Style.baseWidgetSize * 0.8
                  onClicked: root.deviceExpanded("")
                }
              }
            }
          }
        }
      }
    }
  }
}
