import QtQuick 2.9
import QtQuick.Controls 2.2
import QtQuick.Layouts 1.3
import QtQuick.Controls.Material 2.2

import Session 1.0
import StreamingPreferences 1.0

Rectangle {
    id: displaySelectorRoot
    property Session session: null
    property int currentTarget: session ? session.displayTarget : StreamingPreferences.targetDisplay

    height: 48
    radius: 8
    color: "#D0202020"
    border.color: Material.accent
    border.width: 1

    RowLayout {
        anchors.fill: parent
        anchors.margins: 4
        spacing: 8

        Button {
            id: p1Button
            Layout.fillWidth: true
            Layout.fillHeight: true
            text: qsTr("1: Pantalla 1")
            font.bold: currentTarget === 0
            highlighted: currentTarget === 0
            onClicked: {
                if (session) {
                    session.setDisplayTarget(0)
                } else {
                    StreamingPreferences.targetDisplay = 0
                }
            }
        }

        Button {
            id: p2Button
            Layout.fillWidth: true
            Layout.fillHeight: true
            text: qsTr("2: Pantalla 2")
            font.bold: currentTarget === 1
            highlighted: currentTarget === 1
            onClicked: {
                if (session) {
                    session.setDisplayTarget(1)
                } else {
                    StreamingPreferences.targetDisplay = 1
                }
            }
        }

        Button {
            id: mosaicButton
            Layout.fillWidth: true
            Layout.fillHeight: true
            text: qsTr("M: Mosaico H")
            font.bold: currentTarget === 2
            highlighted: currentTarget === 2
            onClicked: {
                if (session) {
                    session.setDisplayTarget(2)
                } else {
                    StreamingPreferences.targetDisplay = 2
                }
            }
        }

        Button {
            id: mosaicVButton
            Layout.fillWidth: true
            Layout.fillHeight: true
            text: qsTr("3: Mosaico V")
            font.bold: currentTarget === 3
            highlighted: currentTarget === 3
            onClicked: {
                if (session) {
                    session.setDisplayTarget(3)
                } else {
                    StreamingPreferences.targetDisplay = 3
                }
            }
        }
    }
}
